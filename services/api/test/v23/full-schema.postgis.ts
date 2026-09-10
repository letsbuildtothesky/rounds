import assert from "node:assert/strict";
import { test } from "node:test";
import { startPostgisFixture } from "./postgis-fixture.js";
import { seedWholeOrder } from "./whole-order-fixture.js";

test("full PostgreSQL/PostGIS schema installs without stripping constraints or policies", { timeout: 120000 }, async t => {
  const fixture = await startPostgisFixture();
  t.after(() => fixture.close());
  t.diagnostic(JSON.stringify(fixture.evidence));
  const { rows } = await fixture.admin.query("SELECT count(*)::integer AS total, bool_and(relrowsecurity AND relforcerowsecurity) AS protected FROM pg_class WHERE relnamespace='rounds'::regnamespace AND relkind='r'");
  assert.equal(rows[0].total, 136); // 131 reference + POD binding + original issue report + pickup photo binding + intake revisions + address reviews.
  assert.equal((await fixture.admin.query("SELECT count(*)::int n FROM pg_class WHERE relnamespace='rounds'::regnamespace AND relkind='r' AND relname='pod_asset_bindings'")).rows[0].n,1);
  assert.equal((await fixture.admin.query("SELECT count(*)::int n FROM pg_class WHERE relnamespace='rounds'::regnamespace AND relkind='r' AND relname='pickup_issue_asset_bindings'")).rows[0].n,1);
  assert.equal((await fixture.admin.query("SELECT count(*)::int n FROM pg_class WHERE relnamespace='rounds'::regnamespace AND relkind='r' AND relname='intake_draft_revisions'")).rows[0].n,1);
  assert.equal((await fixture.admin.query("SELECT count(*)::int n FROM pg_class WHERE relnamespace='rounds'::regnamespace AND relkind='r' AND relname='intake_address_reviews'")).rows[0].n,1);
  assert.equal(rows[0].protected, true);
  const a = await seedWholeOrder(fixture.admin);
  const b = await seedWholeOrder(fixture.admin);
  const restricted = async (action: (client: import("pg").PoolClient) => Promise<void>) => {
    const client = await fixture.pool.connect();
    try {
      await client.query("BEGIN; SET LOCAL ROLE rounds_api");
      await client.query("SELECT set_config('rounds.tenant_id',$1,true),set_config('rounds.principal_id',$2,true),set_config('rounds.city_id',$3,true)", [a.tenant,a.actor,a.city]);
      await action(client);
      await client.query("SET CONSTRAINTS ALL IMMEDIATE");
    } finally { await client.query("ROLLBACK"); client.release(); }
  };
  const fails = (sql: string, params: unknown[], code: string) => assert.rejects(restricted(client => client.query(sql,params).then(() => {})), (error: unknown) => (error as { code?: string }).code === code);

  await t.test("restricted login is not owner, superuser, bypass-RLS or broker", async () => {
    await restricted(async client => {
      const { rows } = await client.query("SELECT current_user,rolsuper,rolbypassrls,pg_has_role(session_user,'rounds_broker','MEMBER') AS broker FROM pg_roles WHERE rolname=current_user");
      assert.deepEqual(rows[0], {current_user:"rounds_api",rolsuper:false,rolbypassrls:false,broker:false});
    });
    await fails("SET LOCAL ROLE rounds_broker", [], "42501");
  });
  await t.test("actual geographic delivery is readable only in its tenant", async () => {
    await restricted(async client => {
      assert.equal((await client.query("SELECT id FROM rounds.deliveries")).rows.length, 1);
      assert.equal((await client.query("SELECT id FROM rounds.deliveries WHERE id=$1", [b.delivery])).rowCount, 0);
      assert.equal((await client.query("UPDATE rounds.deliveries SET address_text='forbidden' WHERE id=$1", [b.delivery])).rowCount, 0);
    });
  });
  await t.test("cross-tenant inserts and foreign-key relationships reject", async () => {
    await fails("INSERT INTO rounds.manifests(tenant_id,delivery_id,revision,source) VALUES($1,$2,2,'manual')", [b.tenant,b.delivery], "42501");
    await fails("INSERT INTO rounds.manifests(tenant_id,delivery_id,revision,source) VALUES($1,$2,2,'manual')", [a.tenant,b.delivery], "23503");
  });
  await t.test("one customer order cannot acquire a second fulfillment unit", async () => {
    await fails("INSERT INTO rounds.fulfillment_units(tenant_id,delivery_id,manifest_id,state) VALUES($1,$2,$3,'open')", [a.tenant,a.delivery,a.manifest], "23505");
  });
  await t.test("five required items cannot become an allocation of three", async () => {
    await fails("UPDATE rounds.fulfillment_unit_lines SET allocated_quantity=3 WHERE unit_id=$1", [a.unit], "23514");
  });
  await t.test("adding a manifest line without whole-order allocation rejects at transaction end", async () => {
    await fails("INSERT INTO rounds.manifest_lines(tenant_id,manifest_id,line_key,label,quantity,unit) VALUES($1,$2,'MISSING','Unallocated',2,'item')", [a.tenant,a.manifest], "23514");
  });
  await t.test("editing expected quantity cannot bypass allocation conservation", async () => {
    await fails("UPDATE rounds.manifest_lines SET quantity=6 WHERE id=$1", [a.line], "23514");
  });
  await t.test("complete allocation revision is allowed atomically before collection", async () => {
    await restricted(async client => {
      await client.query("UPDATE rounds.manifest_lines SET quantity=6 WHERE id=$1", [a.line]);
      await client.query("UPDATE rounds.fulfillment_unit_lines SET allocated_quantity=6 WHERE unit_id=$1", [a.unit]);
    });
  });
  await t.test("current manifest cannot be replaced with an unallocated revision", async () => {
    await assert.rejects(restricted(async client => {
      const m = await client.query("INSERT INTO rounds.manifests(tenant_id,delivery_id,revision,source) VALUES($1,$2,2,'manual') RETURNING id", [a.tenant,a.delivery]);
      await client.query("UPDATE rounds.deliveries SET current_manifest_id=$1 WHERE id=$2", [m.rows[0].id,a.delivery]);
    }), (error: unknown) => (error as {code:string}).code === "23514");
  });
  await t.test("sealing freezes physical manifest content", async () => {
    await fixture.admin.query("UPDATE rounds.manifests SET sealed_at=now() WHERE id=$1", [a.manifest]);
    await fails("UPDATE rounds.manifest_lines SET label='changed' WHERE id=$1", [a.line], "23514");
    await fails("UPDATE rounds.manifests SET sealed_at=NULL WHERE id=$1", [a.manifest], "23514");
  });
  await t.test("planning/preparation fixture creates no trip receipt or custody movement", async () => {
    for (const table of ["trip_receipts","custody_events","custody_balances","inbound_dependencies"]) {
      assert.equal((await fixture.admin.query(`SELECT count(*)::int AS n FROM rounds.${table}`)).rows[0].n, 0);
    }
  });
});
