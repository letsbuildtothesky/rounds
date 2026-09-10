import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { after, before, describe, test } from "node:test";
import pg from "pg";
import type { Pool, PoolClient } from "pg";
import { startPostgresFixture } from "./postgres-fixture.js";
import { CommandTransactionRunner, CommandRejection, TransactionUnavailable, assertExpectedVersions, assertExecutionFence,
  type CommandAuthority, type CommandRequest, type CommandWork } from "../../src/v23/transaction-runner.js";
import { checkWholeOrderPickup, type WholePickupOrder } from "../../../../packages/domain-ts/src/v23/whole-order-pickup.js";

// Real PostgreSQL integration, synthetic handler. Does not certify ConfirmPickup
// endpoint/business writes, full schema/PostGIS, city grant loader, or the phone.
describe("v2.3 pinned transaction foundation (real PostgreSQL, restricted login)", { timeout: 90000 }, () => {
  let db: Awaited<ReturnType<typeof startPostgresFixture>>;
  let runner: CommandTransactionRunner;
  const a: CommandAuthority = { principalId: randomUUID(), tenantId: randomUUID(), cityId: randomUUID() };
  const b = { ...a, tenantId: randomUUID(), cityId: randomUUID() };
  const otherCity = { ...a, cityId: randomUUID() };
  const other = { ...a, principalId: randomUUID() };
  const authorize: CommandWork["authorize"] = async (client, auth) => {
    const access = await client.query(`SELECT allowed FROM v23_test.access
      WHERE principal_id=$1 AND tenant_id IS NOT DISTINCT FROM $2::uuid AND city_id IS NOT DISTINCT FROM $3::uuid`,
      [auth.principalId, auth.tenantId, auth.cityId]);
    if (!access.rows.some((r) => r.allowed)) throw new CommandRejection("NOT_AUTHORIZED");
  };
  before(async () => {
    db = await startPostgresFixture(); runner = new CommandTransactionRunner(db.pool);
    for (const auth of [a, b, other, otherCity]) {
      await db.admin.query(`INSERT INTO rounds.tenants(id,name,country_code,default_timezone,default_currency,status)
        VALUES ($1,'Synthetic test','TH','Asia/Bangkok','THB','active') ON CONFLICT DO NOTHING`, [auth.tenantId]);
      await db.admin.query("INSERT INTO rounds.principals(id,display_name) VALUES ($1,'Synthetic actor') ON CONFLICT DO NOTHING", [auth.principalId]);
      await db.admin.query("INSERT INTO v23_test.access(tenant_id,principal_id,city_id) VALUES ($1,$2,$3)", [auth.tenantId,auth.principalId,auth.cityId]);
    }
  });
  after(async () => { await db?.close(); });
  function work(authority = a): CommandWork {
    const request: CommandRequest = { command_id: randomUUID(), context: { tenant_id: authority.tenantId, city_id: authority.cityId },
      occurred_at: "2026-09-08T00:00:00.000Z", expected_versions: [], payload: { test_only: true } };
    return { commandType: "ConfirmPickup", request, authority, authorize,
      validate: (r) => { assert.deepEqual(r.payload, { test_only: true }); },
      validateResult: (r) => { assert.equal(r.state, "committed"); },
      execute: async (client, req, trace) => {
        await effects(client, req, trace);
        return { command_id: req.command_id, command_type: "ConfirmPickup", state: "committed" };
      } };
  }
  async function effects(client: PoolClient, request: CommandRequest, trace: string) {
    await client.query("INSERT INTO v23_test.effects(id,tenant_id) VALUES ($1,$2)", [request.command_id, request.context.tenant_id]);
    const event = await client.query(`INSERT INTO rounds.domain_events
      (tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,command_id,occurred_at,received_at,payload,trace_id)
      VALUES ($1,'synthetic_probe',$2,1,'SyntheticProbe',1,$2,now(),now(),'{}',$3) RETURNING id`, [request.context.tenant_id,request.command_id,trace]);
    await client.query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at)
      VALUES ($1,$2,'synthetic_test','queued',now())`, [request.context.tenant_id,event.rows[0].id]);
  }
  async function counts(id: string) {
    const result = await db.admin.query(`SELECT
      (SELECT count(*)::int FROM rounds.command_receipts WHERE command_key=$1) AS receipt,
      (SELECT count(*)::int FROM v23_test.effects WHERE id=$1) AS effect,
      (SELECT count(*)::int FROM rounds.domain_events WHERE command_id=$1) AS event,
      (SELECT count(*)::int FROM rounds.outbox_events o JOIN rounds.domain_events e ON e.id=o.event_id WHERE e.command_id=$1) AS outbox`, [id]);
    return result.rows[0];
  }
  const committed = { receipt: 1, effect: 1, event: 1, outbox: 1 };
  const rejected = { receipt: 1, effect: 0, event: 0, outbox: 0 };
  const empty = { receipt: 0, effect: 0, event: 0, outbox: 0 };

  test("commits effects, event, outbox and receipt together, then returns identical replay", async () => {
    const command = work(); const result = await runner.run(command);
    assert.equal(result.replayed, false);
    assert.deepEqual(await counts(command.request.command_id), committed);
    const replay = await runner.run({ ...command, execute: async () => { throw new Error("Must not execute replay"); } });
    assert.deepEqual(replay, { result: result.result, replayed: true });
    assert.deepEqual(await runner.status(command.request.command_id, a, authorize), result.result);
    assert.deepEqual(await counts(command.request.command_id), committed);
  });
  test("concurrent same-ID requests execute once under the receipt lock", async () => {
    const command = work(); let executions = 0;
    const execute = command.execute;
    command.execute = async (...args) => { executions++; await args[0].query("SELECT pg_sleep(0.05)"); return execute(...args); };
    const results = await Promise.all([runner.run(command), runner.run(command)]);
    assert.equal(executions, 1); assert.deepEqual(results[0]!.result, results[1]!.result);
    assert.deepEqual(results.map((r) => r.replayed).sort(), [false, true]);
    assert.deepEqual(await counts(command.request.command_id), committed);
  });
  test("two different command IDs racing the same locked version cannot both win", async () => {
    const root = randomUUID();
    await db.admin.query("INSERT INTO v23_test.effects(id,tenant_id) VALUES ($1,$2)", [root, a.tenantId]);
    const commands = [work(), work()].map((command): CommandWork => ({ ...command,
      request: { ...command.request, expected_versions: [{ aggregate_type: "rounds", id: root, version: 1 }] },
      execute: async (client, request) => {
        const row = await client.query("SELECT version FROM v23_test.effects WHERE id=$1 FOR UPDATE", [root]);
        assertExpectedVersions(request.expected_versions, [{ aggregate_type: "rounds", id: root, version: row.rows[0].version }]);
        await client.query("UPDATE v23_test.effects SET version=version+1 WHERE id=$1", [root]);
        return { command_id: request.command_id, command_type: "ConfirmPickup", state: "committed" };
      } }));
    const results = await Promise.all(commands.map((c) => runner.run(c)));
    assert.deepEqual(results.map((r) => r.result.state).sort(), ["committed", "rejected"]);
    const loser = results.find((r) => r.result.state === "rejected")!;
    assert.equal((loser.result.error as { code: string }).code, "STALE_VERSION");
    assert.equal((await db.admin.query("SELECT version FROM v23_test.effects WHERE id=$1", [root])).rows[0].version, 2);
  });
  test("same ID with changed body or original fence conflicts without replacing the result", async () => {
    const command = work(); const original = await runner.run(command);
    for (const request of [ { ...command.request, occurred_at: "2026-09-08T00:01:00Z" },
      { ...command.request, execution_fence: { assignment_id: randomUUID(), assignment_version: 2, observation_id: randomUUID() } } ]) {
      await assert.rejects(runner.run({ ...command, request }), new CommandRejection("IDEMPOTENCY_CONFLICT"));
    }
    assert.deepEqual(await runner.status(command.request.command_id, a, authorize), original.result);
    assert.deepEqual(await counts(command.request.command_id), committed);
  });
  test("business rejection rolls back all tentative effects but durably replays the rejection", async () => {
    const command = work(); const execute = command.execute;
    command.execute = async (...args) => { await execute(...args); throw new CommandRejection("PICKUP_NOT_READY"); };
    const first = await runner.run(command);
    assert.equal(first.result.state, "rejected"); assert.equal((first.result.error as { code: string }).code, "PICKUP_NOT_READY");
    assert.deepEqual(await counts(command.request.command_id), rejected);
    assert.deepEqual(await runner.run({ ...command, execute }), { ...first, replayed: true });
  });
  test("whole-order guard inside the transaction rejects partial quantity and inbound shortage with zero custody effects", async () => {
    const order: WholePickupOrder = { delivery_id: "D1", manifest_id: "M1", fulfillment_unit_id: "U1",
      unit_state: "open", preparation: "ready", inbound: "received", lines: [{ line_id: "L1", quantity: 5, available_quantity: 3 }] };
    for (const [quantity, code] of [[3, "COMPLETE_ORDER_REQUIRED"], [5, "INBOUND_NOT_RECEIVED"]] as const) {
      const command = work(); const execute = command.execute;
      command.execute = async (...args) => {
        const guard = checkWholeOrderPickup([order], { manifest_ids: ["M1"], fulfillment_unit_ids: ["U1"], quantities: [{ line_id: "L1", quantity }] });
        if (!guard.ok) throw new CommandRejection(guard.code);
        return execute(...args);
      };
      const result = await runner.run(command);
      assert.equal((result.result.error as { code: string }).code, code);
      assert.deepEqual(await counts(command.request.command_id), rejected);
    }
  });
  test("expected root set, version and original assignment fence failures are durable rejections", async () => {
    const root = { aggregate_type: "rounds", id: randomUUID(), version: 1 };
    const fence = { assignment_id: randomUUID(), assignment_version: 1, observation_id: randomUUID() };
    for (const [check, code] of [
      [() => assertExpectedVersions([root], []), "VALIDATION_FAILED"],
      [() => assertExpectedVersions([root], [{ ...root, version: 2 }]), "STALE_VERSION"],
      [() => assertExecutionFence(fence, { ...fence, assignment_version: 2 }), "EXECUTION_FENCE_CHANGED"],
    ] as const) {
      const command = work(); command.execute = async () => { check(); throw new Error("Must reject"); };
      const result = await runner.run(command);
      assert.equal((result.result.error as { code: string }).code, code);
      assert.deepEqual(await counts(command.request.command_id), rejected);
    }
  });
  test("deferred SQL constraints reject before a success receipt and erase the attempted event/outbox", async () => {
    const command = work(); const execute = command.execute;
    command.execute = async (...args) => {
      const result = await execute(...args);
      await args[0].query("INSERT INTO v23_test.deferred_effect(id) VALUES ($1)", [randomUUID()]);
      return result;
    };
    const result = await runner.run(command);
    assert.equal((result.result.error as { code: string }).code, "VALIDATION_FAILED");
    assert.deepEqual(await counts(command.request.command_id), rejected);
  });
  for (const code of ["40001", "40P01"]) test(`retries PostgreSQL ${code} with the same frozen command, then commits once`, async () => {
    const command = work(); let tries = 0; const execute = command.execute;
    command.execute = async (...args) => {
      const result = await execute(...args);
      if (++tries === 1) await args[0].query(`DO $$ BEGIN RAISE EXCEPTION 'synthetic transient' USING ERRCODE='${code}'; END $$`);
      return result;
    };
    await runner.run(command); assert.equal(tries, 2);
    assert.deepEqual(await counts(command.request.command_id), committed);
  });
  test("retry exhaustion is bounded at three and leaves no receipt or partial effects", async () => {
    const command = work(); let tries = 0;
    command.execute = async (client) => { tries++; await client.query("DO $$ BEGIN RAISE EXCEPTION 'synthetic' USING ERRCODE='40001'; END $$"); throw new Error("unreachable"); };
    await assert.rejects(runner.run(command), new TransactionUnavailable("PROVIDER_UNAVAILABLE"));
    assert.equal(tries, 3); assert.deepEqual(await counts(command.request.command_id), empty);
  });
  test("unexpected handler failure is sanitized and rolls back the receipt too", async () => {
    const command = work(); const execute = command.execute;
    command.execute = async (...args) => { await execute(...args); throw new Error("private database detail"); };
    await assert.rejects(runner.run(command), new TransactionUnavailable("PROVIDER_UNAVAILABLE"));
    assert.deepEqual(await counts(command.request.command_id), empty);
  });
  test("the same actor in a different tenant cannot read a receipt, including raw SQL bypassing status filters", async () => {
    const command = work(); await runner.run(command);
    assert.equal(await runner.status(command.request.command_id, b, authorize), null);
    assert.equal(await runner.status(command.request.command_id, other, authorize), null);
    const scoped = work(b); const execute = scoped.execute;
    scoped.execute = async (...args) => {
      const result = await args[0].query("SELECT id FROM rounds.command_receipts WHERE command_key=$1", [command.request.command_id]);
      assert.equal(result.rowCount, 0);
      await assert.rejects(args[0].query(`INSERT INTO rounds.command_receipts(scope_key,actor_id,tenant_id,command_key,command_type,request_hash,state,started_at)
        VALUES ('wrong-tenant',$1,$2,$3,'ConfirmPickup','test','in_progress',now())`, [a.principalId,a.tenantId,randomUUID()]), { code: "42501" });
      // An actual SQL permission error aborts the transaction, not a successful result.
      return execute(...args);
    };
    await assert.rejects(runner.run(scoped), new TransactionUnavailable("PROVIDER_UNAVAILABLE"));
    assert.deepEqual(await counts(scoped.request.command_id), empty);
  });
  test("context must match authenticated authority; revoked city access blocks replay/status", async () => {
    const command = work(); await runner.run(command);
    await assert.rejects(runner.run({ ...command, authority: b }), new CommandRejection("NOT_AUTHORIZED"));
    const noCity = { ...a, cityId: randomUUID() };
    await assert.rejects(runner.status(command.request.command_id, noCity, authorize), new CommandRejection("NOT_AUTHORIZED"));
    await db.admin.query("UPDATE v23_test.access SET allowed=false WHERE tenant_id=$1 AND principal_id=$2", [a.tenantId,a.principalId]);
    try {
      await assert.rejects(runner.run(command), new CommandRejection("NOT_AUTHORIZED"));
      await assert.rejects(runner.status(command.request.command_id, a, authorize), new CommandRejection("NOT_AUTHORIZED"));
    } finally { await db.admin.query("UPDATE v23_test.access SET allowed=true WHERE tenant_id=$1 AND principal_id=$2", [a.tenantId,a.principalId]); }
  });
  test("an authorized second city in the same tenant cannot retrieve original-city receipts", async () => {
    const command = work(); await runner.run(command);
    assert.equal(await runner.status(command.request.command_id, otherCity, authorize), null);
    const scoped = work(otherCity); const execute = scoped.execute;
    scoped.execute = async (...args) => {
      const rows = await args[0].query("SELECT result FROM rounds.command_receipts WHERE command_key=$1", [command.request.command_id]);
      assert.equal(rows.rowCount, 0);
      return execute(...args);
    };
    await runner.run(scoped);
    await assert.rejects(runner.run({ ...scoped, request: { ...scoped.request, command_id: command.request.command_id } }), new CommandRejection("NOT_AUTHORIZED"));
  });
  test("pooled connection resets role and scope after both commit and rollback", async () => {
    const single = new pg.Pool({ ...db.config, max: 1 }); const r = new CommandTransactionRunner(single);
    try {
      await r.run(work(a)); await r.run(work(b));
      const broken = work(); broken.execute = async () => { throw new Error("test failure"); };
      await assert.rejects(r.run(broken));
      const state = await single.query("SELECT current_user, nullif(current_setting('rounds.tenant_id',true),'') AS tenant, nullif(current_setting('rounds.principal_id',true),'') AS actor, nullif(current_setting('rounds.city_id',true),'') AS city");
      assert.deepEqual(state.rows[0], { current_user: "fixture_login", tenant: null, actor: null, city: null });
    } finally { await single.end(); }
  });
  test("mutating the caller envelope after dispatch cannot change request identity or execution", async () => {
    const command = work(); const original = structuredClone(command.request);
    const promise = runner.run(command);
    (command.request.payload as { test_only: boolean }).test_only = false;
    await promise;
    assert.deepEqual(await runner.run({ ...command, request: original }), { result: {
      command_id: original.command_id, command_type: "ConfirmPickup", state: "committed" }, replayed: true });
  });
  test("lost COMMIT acknowledgement returns UNKNOWN_RESULT; status and replay recover the one committed result", async () => {
    const command = work(); let releasedPoisoned = false;
    // Fault injection only at the driver acknowledgement boundary: PostgreSQL
    // really commits first; the runner then sees a lost connection response.
    const transport = { connect: async () => {
      const client = await db.pool.connect();
      return new Proxy(client, { get(target, key) {
        if (key === "query") return async (...args: unknown[]) => {
          const result = await (target.query as (...a: unknown[]) => Promise<unknown>).apply(target, args);
          if (args[0] === "COMMIT") throw Object.assign(new Error("synthetic lost ack"), { code: "ECONNRESET" });
          return result;
        };
        if (key === "release") return (destroy: boolean) => { releasedPoisoned = destroy; target.release(destroy); };
        return Reflect.get(target, key);
      } });
    } } as Pool;
    await assert.rejects(new CommandTransactionRunner(transport).run(command), new TransactionUnavailable("UNKNOWN_RESULT"));
    assert.equal(releasedPoisoned, true);
    assert.deepEqual(await counts(command.request.command_id), committed);
    const status = await runner.status(command.request.command_id, a, authorize);
    assert.deepEqual((await runner.run(command)).result, status);
    assert.deepEqual(await counts(command.request.command_id), committed);
  });
  test("receipt-scope upgrade refuses populated schemas rather than guessing existing scope", async () => {
    const command = work(); await runner.run(command);
    const migration = await readFile(new URL("../../migrations/v23/0001-command-receipt-scope.sql", import.meta.url), "utf8");
    try { await assert.rejects(db.admin.query(migration), /requires empty isolated schema/); }
    finally { await db.admin.query("ROLLBACK"); }
    assert.deepEqual(await counts(command.request.command_id), committed);
    assert.equal(await runner.status(command.request.command_id, otherCity, authorize), null);
  });
  test("superuser sessions are refused even if they could SET ROLE", async () => {
    // Existing fixture connection is superuser; never a production credential.
    const adminPool = { connect: async () => new Proxy(db.admin, { get(target, key) {
      if (key === "release") return () => {};
      const value = Reflect.get(target, key); return typeof value === "function" ? value.bind(target) : value;
    } }) } as unknown as Pool;
    const command = work();
    await assert.rejects(new CommandTransactionRunner(adminPool).run(command), new TransactionUnavailable("PROVIDER_UNAVAILABLE"));
    assert.deepEqual(await counts(command.request.command_id), empty);
  });
});
