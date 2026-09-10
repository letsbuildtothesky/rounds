import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { startPostgisFixture } from "./postgis-fixture.js";
import { seedWholeOrder } from "./whole-order-fixture.js";
import { lockOriginalRoundAssignment } from "../../src/v23/assignment-fence.js";
import { CommandTransactionRunner, CommandRejection, assertExpectedVersions, type CommandWork } from "../../src/v23/transaction-runner.js";

// Explicit transaction probes on actual product rows. Not the ConfirmPickup
// payload/result contract, physical custody handler or public authentication.
test("full-schema transaction probes preserve atomicity and original assignment", { timeout: 120000 }, async t => {
  const db = await startPostgisFixture(); t.after(() => db.close());
  const ids = await seedWholeOrder(db.admin);
  const runner = new CommandTransactionRunner(db.pool);
  const authority = { tenantId: ids.tenant!, cityId: ids.city!, principalId: ids.actor! };
  const authorize: CommandWork["authorize"] = async (client, auth) => {
    const access = await client.query(`SELECT m.id FROM rounds.memberships m
      JOIN rounds.city_grants g ON g.tenant_id=m.tenant_id AND g.membership_id=m.id
      JOIN rounds.cities c ON c.tenant_id=g.tenant_id AND c.id=g.city_id
      WHERE m.tenant_id=$1 AND m.principal_id=$2 AND m.status='active' AND m.archived_at IS NULL
      AND g.city_id=$3 AND g.archived_at IS NULL AND 'driver.assigned_work'=ANY(g.capabilities)
      AND c.enabled AND c.archived_at IS NULL FOR SHARE OF m,g,c`, [auth.tenantId,auth.principalId,auth.cityId]);
    if (!access.rowCount) throw new CommandRejection("NOT_AUTHORIZED");
  };
  function work(): CommandWork {
    return { authority, commandType:"ConfirmPickup", authorize,
      request: { command_id:randomUUID(),context:{tenant_id:authority.tenantId,city_id:authority.cityId},occurred_at:"2026-09-08T00:00:00Z",
        execution_fence:{assignment_id:ids.assignment!,assignment_version:1,observation_id:randomUUID()},
        expected_versions:[{aggregate_type:"deliveries",id:ids.delivery!,version:1}],payload:{probe:true} },
      validate: r => assert.deepEqual(r.payload,{probe:true}), validateResult: r => assert.equal(r.state,"committed"),
      execute: async (client, request, trace) => {
        const locked = await client.query("SELECT version FROM rounds.deliveries WHERE tenant_id=$1 AND city_id=$2 AND id=$3 FOR UPDATE", [authority.tenantId,authority.cityId,ids.delivery]);
        assertExpectedVersions(request.expected_versions, locked.rows.map(row => ({aggregate_type:"deliveries",id:ids.delivery!,version:Number(row.version)})));
        await lockOriginalRoundAssignment(client,authority,ids.round!,request.execution_fence!);
        await client.query("UPDATE rounds.deliveries SET ready_declared_at=now(),version=version+1 WHERE id=$1", [ids.delivery]);
        const event = await client.query(`INSERT INTO rounds.domain_events(tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
          VALUES($1,'deliveries',$2,$6,'isolated.transaction_probe',1,$3,$4,now(),now(),'{}',$5) RETURNING id`, [authority.tenantId,ids.delivery,authority.principalId,request.command_id,trace,Number(locked.rows[0].version)+1]);
        await client.query("INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'test_only','queued',now())", [authority.tenantId,event.rows[0].id]);
        return {command_id:request.command_id,command_type:"ConfirmPickup",state:"committed"};
      }
    };
  }
  const counts = async (id: string) => (await db.admin.query(`SELECT
    (SELECT count(*)::int FROM rounds.command_receipts WHERE command_key=$1) AS receipts,
    (SELECT count(*)::int FROM rounds.domain_events WHERE command_id=$1) AS events,
    (SELECT count(*)::int FROM rounds.outbox_events o JOIN rounds.domain_events e ON e.id=o.event_id WHERE e.command_id=$1) AS outbox`, [id])).rows[0];
  const code = (result: Record<string,unknown>) => (result.error as {code:string}).code;
  await t.test("forced full-schema constraint rejection rolls back domain, event and outbox; rejection replays", async () => {
    const command = work(); const execute = command.execute;
    command.execute = async (...args) => {
      const result = await execute(...args);
      await args[0].query("UPDATE rounds.manifest_lines SET quantity=6 WHERE id=$1", [ids.line]);
      return result;
    };
    const first = await runner.run(command);
    assert.equal(code(first.result),"VALIDATION_FAILED");
    assert.deepEqual(await counts(command.request.command_id),{receipts:1,events:0,outbox:0});
    assert.equal((await db.admin.query("SELECT version FROM rounds.deliveries WHERE id=$1", [ids.delivery])).rows[0].version,"1");
    assert.deepEqual(await runner.run(command),{...first,replayed:true});
  });
  await t.test("changed original assignment version rejects without promoting it to current", async () => {
    await db.admin.query("UPDATE rounds.assignments SET version=2 WHERE id=$1", [ids.assignment]);
    const command = work();
    const result = await runner.run(command);
    assert.equal(code(result.result),"EXECUTION_FENCE_CHANGED");
    assert.equal(command.request.execution_fence?.assignment_version,1);
    assert.deepEqual(await counts(command.request.command_id),{receipts:1,events:0,outbox:0});
    await db.admin.query("UPDATE rounds.assignments SET version=1 WHERE id=$1", [ids.assignment]);
  });
  await t.test("superseded original assignment rejects even if its version was not bumped", async () => {
    await db.admin.query("UPDATE rounds.assignments SET state='superseded' WHERE id=$1", [ids.assignment]);
    const result = await runner.run(work());
    assert.equal(code(result.result),"EXECUTION_FENCE_CHANGED");
    await db.admin.query("UPDATE rounds.assignments SET state='acknowledged' WHERE id=$1", [ids.assignment]);
  });
  await t.test("same tenant but wrong city grant fails before any receipt", async () => {
    const command = work();
    command.authority = {...authority,cityId:ids.otherCity!};
    command.request = {...command.request,context:{tenant_id:authority.tenantId,city_id:ids.otherCity!}};
    await assert.rejects(runner.run(command),new CommandRejection("NOT_AUTHORIZED"));
    assert.deepEqual(await counts(command.request.command_id),{receipts:0,events:0,outbox:0});
  });
  await t.test("knowing an assignment ID does not grant another driver that job", async () => {
    const other = randomUUID();
    await db.admin.query("INSERT INTO rounds.principals(id,display_name) VALUES($1,'Other test driver')", [other]);
    const command = work();
    const execute = command.execute;
    command.execute = async (client,request,trace) => {
      await lockOriginalRoundAssignment(client,{...authority,principalId:other},ids.round!,request.execution_fence!);
      return execute(client,request,trace);
    };
    const result = await runner.run(command);
    assert.equal(code(result.result),"NOT_AUTHORIZED");
    assert.deepEqual(await counts(command.request.command_id),{receipts:1,events:0,outbox:0});
  });
  await t.test("concurrent same command commits one state/event/outbox and returns exact replay", async () => {
    const command = work();
    const results = await Promise.all([runner.run(command),runner.run(command)]);
    assert.deepEqual(results.map(r => r.replayed).sort(),[false,true]);
    assert.deepEqual(results[0]!.result,results[1]!.result);
    assert.equal(results[0]!.result.state,"committed");
    assert.deepEqual(await counts(command.request.command_id),{receipts:1,events:1,outbox:1});
    assert.equal((await db.admin.query("SELECT version FROM rounds.deliveries WHERE id=$1", [ids.delivery])).rows[0].version,"2");
    await db.admin.query("UPDATE rounds.memberships SET status='revoked' WHERE id=$1", [ids.membership]);
    await assert.rejects(runner.run(command),new CommandRejection("NOT_AUTHORIZED"));
    await assert.rejects(runner.status(command.request.command_id,authority,authorize),new CommandRejection("NOT_AUTHORIZED"));
    await db.admin.query("UPDATE rounds.memberships SET status='active' WHERE id=$1", [ids.membership]);
  });
  await t.test("different commands racing the same actual delivery version have one winner", async () => {
    const commands = [work(),work()].map(command => ({...command,request:{...command.request,expected_versions:[{aggregate_type:"deliveries",id:ids.delivery!,version:2}]}}));
    const results = await Promise.all(commands.map(command => runner.run(command)));
    assert.deepEqual(results.map(r => r.result.state).sort(),["committed","rejected"]);
    assert.equal(code(results.find(r => r.result.state === "rejected")!.result),"STALE_VERSION");
    assert.equal((await db.admin.query("SELECT version FROM rounds.deliveries WHERE id=$1", [ids.delivery])).rows[0].version,"3");
  });
});
