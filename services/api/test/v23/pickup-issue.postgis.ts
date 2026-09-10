import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { test } from 'node:test';
import type { PoolClient } from 'pg';
import type { Wire_ReportIssueRequest, Wire_ConfirmPickupRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { createDeviceRegistrationHttp } from '../../src/v23/device-registration-http.js';
import { createPickupHttp, pickupPath, statusPath } from '../../src/v23/pickup-http.js';
import { createV23NodeBoundary } from '../../src/v23/node-boundary.js';
import { deviceSessions } from '../../src/v23/device-session.js';
import { localPickupIssueWork, reportIssuePath } from '../../src/v23/report-local-pickup-issue.js';
import { validateIssueEvent, validateIssueResult } from '../../src/v23/pickup-validation.js';
import { beginRestrictedTransaction } from '../../src/v23/restricted-transaction.js';
import { CommandRejection, CommandTransactionRunner } from '../../src/v23/transaction-runner.js';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';

test('registered pre-pickup issue reports use real restricted transactions and no custody shortcuts', { timeout: 120000 }, async t => {
  const db = await startPostgisFixture(); t.after(() => db.close());
  const subjects = new Map<string, string>(), devices = deviceSessions({ id: 'issue-test', secret: randomBytes(32) });
  const options = { pool: db.pool, devices, origin: 'http://localhost:3000', verifyBearer: async (bearer: string) => {
    const subject = subjects.get(bearer); if (!subject) throw new CommandRejection('UNAUTHENTICATED'); return subject;
  } };
  const http = createPickupHttp(options), enroll = createDeviceRegistrationHttp(options), runner = new CommandTransactionRunner(db.pool);
  async function setup() {
    const ids = await seedWholeOrder(db.admin), subject = randomUUID(), bearer = randomUUID(); subjects.set(bearer, subject);
    await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1', [ids.actor, subject]);
    await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`, [ids.tenant, ids.delivery, ids.round, ids.unit]);
    const registered = await enroll(new Request('http://rounds.internal/v1/auth/driver-device/session', { method: 'POST', headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' }, body: JSON.stringify({ installation_secret: randomBytes(32).toString('hex'), platform: 'android' }) }));
    assert.equal(registered.status, 200); const device = await registered.json();
    const headers = { authorization: `Bearer ${bearer}`, 'x-rounds-device-session': device.device_session, 'content-type': 'application/json' };
    const r: Wire_ReportIssueRequest = { command_id: randomUUID(), context: { tenant_id: ids.tenant!, city_id: ids.city! }, occurred_at: '2026-09-09T00:00:00Z',
      execution_fence: { assignment_id: ids.assignment!, assignment_version: 1, observation_id: randomUUID() },
      expected_versions: [{ aggregate_type: 'rounds', id: ids.round!, version: 1 }, { aggregate_type: 'deliveries', id: ids.delivery!, version: 1 }],
      payload: { round_id: ids.round!, delivery_id: ids.delivery!, issue_type: 'package', reason_code: 'missing', affected_lines: [], asset_ids: [] } };
    return { ids, headers, device, r, auth: { tenantId: ids.tenant!, cityId: ids.city!, principalId: ids.actor! } };
  }
  type Scenario = Awaited<ReturnType<typeof setup>>;
  const post = (s: Scenario, body: unknown = s.r, path = reportIssuePath) => http(new Request('http://rounds.internal' + path, { method: 'POST', headers: s.headers, body: JSON.stringify(body) }));
  const status = (s: Scenario) => http(new Request(`http://rounds.internal${statusPath}?entity_id=${s.r.command_id}&tenant_id=${s.r.context.tenant_id}&city_id=${s.r.context.city_id}`, { headers: s.headers }));
  const snapshot = async (s: Scenario) => (await db.admin.query(`SELECT
    (SELECT count(*)::int FROM rounds.issues WHERE tenant_id=$1) issues,
    (SELECT count(*)::int FROM rounds.issue_report_observations WHERE tenant_id=$1) observations,
    (SELECT count(*)::int FROM rounds.domain_events WHERE tenant_id=$1) events,
    (SELECT count(*)::int FROM rounds.outbox_events WHERE tenant_id=$1) outbox,
    (SELECT count(*)::int FROM rounds.custody_events WHERE tenant_id=$1) custody,
    (SELECT count(*)::int FROM rounds.delivery_attempts WHERE tenant_id=$1) attempts,
    (SELECT count(*)::int FROM rounds.trip_receipts WHERE tenant_id=$1) receipts,
    (SELECT count(*)::int FROM rounds.issue_decisions WHERE tenant_id=$1) decisions,
    (SELECT readiness FROM rounds.deliveries WHERE id=$2) readiness,
    (SELECT preparation_state FROM rounds.deliveries WHERE id=$2) preparation,
    (SELECT outcome FROM rounds.deliveries WHERE id=$2) outcome,
    (SELECT version::int FROM rounds.deliveries WHERE id=$2) delivery_version,
    (SELECT state FROM rounds.rounds WHERE id=$3) round,
    (SELECT departure_gate FROM rounds.rounds WHERE id=$3) gate,
    (SELECT version::int FROM rounds.rounds WHERE id=$3) round_version,
    (SELECT state FROM rounds.stops WHERE id=$4) pickup,
    (SELECT actual_arrival_at FROM rounds.stops WHERE id=$4) arrival,
    (SELECT state FROM rounds.fulfillment_units WHERE id=$5) unit`, [s.ids.tenant, s.ids.delivery, s.ids.round, s.ids.pickup, s.ids.unit])).rows[0];
  async function denied(s: Scenario, code: string, body: unknown = s.r) {
    const before = await snapshot(s), result = await post(s, body);
    assert.equal((await result.json()).code, code); assert.deepEqual(await snapshot(s), before);
  }
  async function committed(s: Scenario) {
    const response = await post(s); assert.equal(response.status, 200, JSON.stringify(await response.clone().json()));
    const result = await response.json(); validateIssueResult(result); return result;
  }
  const waiting = (s: Scenario) => {
    s.r.payload = { round_id: s.ids.round!, issue_type: 'pickup_wait', reason_code: 'awaiting_goods', affected_lines: [], asset_ids: [] };
    s.r.expected_versions = s.r.expected_versions.filter(v => v.aggregate_type === 'rounds');
  };
  async function restricted(s: Scenario, action: (client: PoolClient) => Promise<void>) {
    const client = await db.pool.connect();
    try { await beginRestrictedTransaction(client, s.auth); await action(client); }
    finally { await client.query('ROLLBACK'); client.release(); }
  }
  await t.test('atomic hold + immutable original report + actual changed facts; concurrent replay adds zero', async () => {
    const s = await setup(); s.r.payload.detail = '  Two stems missing\nKeep original wording.  ';
    s.r.payload.point = { longitude: 100.5, latitude: 13.7 };
    s.r.payload.affected_lines = [{ line_id: s.ids.line!, quantity: 2 }];
    const responses = await Promise.all([post(s), post(s)]);
    assert.deepEqual(responses.map(r => r.status), [200, 200]);
    const a = await responses[0]!.json(), b = await responses[1]!.json(); assert.deepEqual(a, b); validateIssueResult(a);
    assert.deepEqual(responses.map(r => r.headers.get('x-rounds-replayed')).sort(), ['false', 'true']);
    assert.deepEqual(await snapshot(s), { issues: 1, observations: 1, events: 2, outbox: 2, custody: 0, attempts: 0, receipts: 0, decisions: 0,
      readiness: 'held', preparation: 'ready', outcome: 'open', delivery_version: 2, round: 'released', gate: 'blocked', round_version: 2,
      pickup: 'arrived', arrival: null, unit: 'open' });
    const original = (await db.admin.query('SELECT * FROM rounds.issue_report_observations WHERE issue_id=$1', [a.data.resource.id])).rows[0];
    assert.deepEqual(original.payload, s.r.payload); assert.deepEqual(original.expected_versions, s.r.expected_versions);
    assert.equal(original.assignment_id, s.ids.assignment); assert.equal(Number(original.assignment_version), 1);
    assert.equal(original.observation_id, s.r.execution_fence.observation_id); assert.equal(original.manifest_id, s.ids.manifest);
    assert.equal(original.actor_id, s.ids.actor); assert.equal(original.observed_at.toISOString(), '2026-09-09T00:00:00.000Z');
    const events = (await db.admin.query('SELECT * FROM rounds.domain_events WHERE command_id=$1', [s.r.command_id])).rows;
    for (const e of events) validateIssueEvent({ event_id: e.id, event_type: e.event_type, schema_version: e.schema_version, tenant_id: e.tenant_id, principal_id: null,
      aggregate: { aggregate_type: e.aggregate_type, id: e.aggregate_id, version: Number(e.aggregate_version) }, occurred_at: e.occurred_at.toISOString(), received_at: e.received_at.toISOString(), actor_id: e.actor_id, command_id: e.command_id, worker_run_id: null, trace_id: e.trace_id, payload: e.payload });
    const recovered = await status(s); assert.equal(recovered.status, 200); assert.deepEqual((await recovered.json()).data.result, a);
    const pickup: Wire_ConfirmPickupRequest = { ...s.r, command_id: randomUUID(), execution_fence: { ...s.r.execution_fence, observation_id: randomUUID() },
      expected_versions: [{ aggregate_type: 'rounds', id: s.ids.round!, version: 2 }, { aggregate_type: 'stops', id: s.ids.pickup!, version: 1 }, { aggregate_type: 'manifests', id: s.ids.manifest!, version: 1 }, { aggregate_type: 'fulfillment_units', id: s.ids.unit!, version: 1 }],
      payload: { round_id: s.ids.round!, pickup_stop_id: s.ids.pickup!, manifest_ids: [s.ids.manifest!], fulfillment_unit_ids: [s.ids.unit!], quantities: [{ line_id: s.ids.line!, quantity: 5 }] } };
    const before = await snapshot(s), blocked = await post(s, pickup, pickupPath);
    assert.equal((await blocked.json()).code, 'PICKUP_NOT_READY'); assert.deepEqual(await snapshot(s), before);
  });
  await t.test('basic missing report needs no invented quantities or photo', async () => {
    const s = await setup(); const result = await committed(s);
    assert.deepEqual((await db.admin.query('SELECT payload FROM rounds.issue_report_observations WHERE issue_id=$1', [result.data.resource.id])).rows[0].payload.affected_lines, []);
  });
  await t.test('holding one complete order does not mark another order short or change its allocation', async () => {
    const s = await setup(), delivery = randomUUID(), manifest = randomUUID(), unit = randomUUID(), line = randomUUID(), stop = randomUUID();
    await db.admin.query('BEGIN');
    try {
      await db.admin.query(`INSERT INTO rounds.deliveries(id,tenant_id,city_id,pickup_site_id,human_reference,service_date,timezone,window_start_at,window_end_at,address_text,readiness,outcome,evidence_state,proof_policy_id,created_by,preparation_state)
        SELECT $2,tenant_id,city_id,pickup_site_id,'SECOND-INDEPENDENT',service_date,timezone,window_start_at,window_end_at,address_text,readiness,outcome,evidence_state,proof_policy_id,created_by,preparation_state FROM rounds.deliveries WHERE id=$1`, [s.ids.delivery, delivery]);
      await db.admin.query(`INSERT INTO rounds.manifests(id,tenant_id,delivery_id,revision,source) VALUES($1,$2,$3,1,'manual')`, [manifest, s.ids.tenant, delivery]);
      await db.admin.query(`INSERT INTO rounds.manifest_lines(id,tenant_id,manifest_id,line_key,label,quantity,unit) VALUES($1,$2,$3,'INDEPENDENT','Second whole order',3,'item')`, [line, s.ids.tenant, manifest]);
      await db.admin.query(`INSERT INTO rounds.fulfillment_units(id,tenant_id,delivery_id,manifest_id,state) VALUES($1,$2,$3,$4,'open')`, [unit, s.ids.tenant, delivery, manifest]);
      await db.admin.query(`INSERT INTO rounds.fulfillment_unit_lines(tenant_id,unit_id,line_id,allocated_quantity) VALUES($1,$2,$3,3)`, [s.ids.tenant, unit, line]);
      await db.admin.query('UPDATE rounds.deliveries SET current_manifest_id=$2 WHERE id=$1', [delivery, manifest]);
      await db.admin.query(`INSERT INTO rounds.stops(id,tenant_id,round_id,delivery_id,kind,sequence,destination_version,state,service_seconds,fulfillment_unit_id) VALUES($1,$2,$3,$4,'dropoff',2,1,'released',60,$5)`, [stop, s.ids.tenant, s.ids.round, delivery, unit]);
      await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`, [s.ids.tenant, delivery, s.ids.round, unit]);
      await db.admin.query('COMMIT');
    } catch (error) { await db.admin.query('ROLLBACK'); throw error; }
    await committed(s);
    const untouched = (await db.admin.query(`SELECT d.readiness,d.outcome,d.version::int,u.state,l.allocated_quantity::float8 quantity
      FROM rounds.deliveries d JOIN rounds.fulfillment_units u ON u.delivery_id=d.id JOIN rounds.fulfillment_unit_lines l ON l.unit_id=u.id WHERE d.id=$1`, [delivery])).rows[0];
    assert.deepEqual(untouched, { readiness: 'ready', outcome: 'open', version: 1, state: 'open', quantity: 3 });
    // Same route still blocked until an explicit adjustment, never auto-skipped.
    assert.equal((await snapshot(s)).gate, 'blocked');
  });
  await t.test('pickup wait before arrival/preparation/receipt preserves those states and records no charge', async () => {
    const s = await setup(); waiting(s); s.r.payload.detail = 'Supplier says 15 minutes; driver observation only';
    await db.admin.query(`UPDATE rounds.stops SET state='en_route' WHERE id=$1`, [s.ids.pickup]);
    await db.admin.query(`UPDATE rounds.deliveries SET preparation_state='preparing' WHERE id=$1`, [s.ids.delivery]);
    await db.admin.query(`UPDATE rounds.rounds SET departure_gate='awaiting_preparation' WHERE id=$1`, [s.ids.round]);
    const before = await snapshot(s), result = await committed(s), after = await snapshot(s);
    assert.deepEqual(after, { ...before, issues: 1, observations: 1, events: 1, outbox: 1 }); assert.deepEqual(result.current_versions, []);
    const row = (await db.admin.query('SELECT delivery_id,manifest_id FROM rounds.issue_report_observations WHERE issue_id=$1', [result.data.resource.id])).rows[0];
    assert.deepEqual(row, { delivery_id: null, manifest_id: null });
  });
  await t.test('a second actual report creates no repeated hold/readiness-change fact', async () => {
    const s = await setup(); await committed(s);
    s.r.command_id = randomUUID(); s.r.execution_fence.observation_id = randomUUID(); s.r.expected_versions.forEach(v => v.version = 2);
    const result = await committed(s); assert.deepEqual(result.current_versions, []);
    const after = await snapshot(s); assert.equal(after.issues, 2); assert.equal(after.events, 3); assert.equal(after.round_version, 2); assert.equal(after.delivery_version, 2);
  });
  await t.test('two different reports racing the same current roots do not bypass stale versions', async () => {
    const s = await setup(), other = structuredClone(s.r); other.command_id = randomUUID(); other.execution_fence.observation_id = randomUUID();
    const results = await Promise.all([post(s), post(s, other)]); assert.deepEqual(results.map(r => r.status).sort(), [200, 409]); assert.equal((await snapshot(s)).issues, 1);
  });
  await t.test('a new command cannot duplicate an original observation identity', async () => {
    const s = await setup(); waiting(s); await committed(s); s.r.command_id = randomUUID(); await denied(s, 'VALIDATION_FAILED');
  });
  await t.test('changing a committed body conflicts and recovers the original receipt', async () => {
    const s = await setup(); const result = await committed(s); s.r.payload.detail = 'different'; await denied(s, 'IDEMPOTENCY_CONFLICT');
    assert.deepEqual((await (await status(s)).json()).data.result, result);
  });
  for (const [label, change] of [
    ['missing fence', (r: any) => { delete r.execution_fence; }],
    ['empty reason', (r: any) => { r.payload.reason_code = '  '; }],
    ['missing Round', (r: any) => { delete r.payload.round_id; }],
    ['unscoped package', (r: any) => { delete r.payload.delivery_id; }],
    ['extra field', (r: any) => { r.payload.approved = true; }],
    ['negative quantity', (r: any) => { r.payload.affected_lines = [{ line_id: randomUUID(), quantity: -1 }]; }],
    ['precision', (r: any) => { r.payload.affected_lines = [{ line_id: randomUUID(), quantity: 0.12345 }]; }],
    ['duplicate line', (r: any) => { const line_id = randomUUID(); r.payload.affected_lines = [{ line_id, quantity: 1 }, { line_id, quantity: 1 }]; }],
    ['extra version root', (r: any) => { r.expected_versions.push({ aggregate_type: 'stops', id: randomUUID(), version: 1 }); }],
    ['missing version root', (r: any) => { r.expected_versions.pop(); }],
    ['duplicate root', (r: any) => { r.expected_versions[1] = r.expected_versions[0]; }],
    ['invalid location', (r: any) => { r.payload.point = { longitude: 190, latitude: 100 }; }],
  ] as const) await t.test(`${label} fails without report/hold/evidence loss`, async () => { const s = await setup(); const body = structuredClone(s.r); change(body); await denied(s, 'VALIDATION_FAILED', body); });
  for (const [label, change, code] of [
    ['foreign line', (s: Scenario) => { s.r.payload.affected_lines = [{ line_id: randomUUID(), quantity: 1 }]; }, 'MANIFEST_MISMATCH'],
    ['excess quantity', (s: Scenario) => { s.r.payload.affected_lines = [{ line_id: s.ids.line!, quantity: 6 }]; }, 'QUANTITY_EXCEEDED'],
    ['unbound photo', (s: Scenario) => { s.r.payload.asset_ids = [randomUUID()]; }, 'FEATURE_NOT_ENABLED'],
    ['trip execution', (s: Scenario) => { s.r.payload.trip_id = randomUUID(); }, 'FEATURE_NOT_ENABLED'],
    ['later recipient branch', (s: Scenario) => { s.r.payload.issue_type = 'recipient_unavailable'; }, 'FEATURE_NOT_ENABLED'],
    ['stale Round', (s: Scenario) => { s.r.expected_versions[0]!.version = 2; }, 'STALE_VERSION'],
    ['stale assignment', (s: Scenario) => { s.r.execution_fence.assignment_version = 2; }, 'EXECUTION_FENCE_CHANGED'],
  ] as const) await t.test(label, async () => { const s = await setup(); change(s); await denied(s, code); });

  await t.test('round-only wait cannot attach guessed line identities', async () => {
    const s = await setup(); waiting(s); s.r.payload.affected_lines = [{ line_id: s.ids.line!, quantity: 1 }]; await denied(s, 'VALIDATION_FAILED');
  });
  for (const flag of ['device', 'epoch', 'capability', 'superseded', 'foreign-account', 'foreign-city', 'foreign-tenant']) await t.test(`${flag} denies replay and original-result access`, async () => {
    const s = await setup(); await committed(s); const before = await snapshot(s);
    if (flag === 'device') await db.admin.query('UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1', [s.device.device_id]);
    if (flag === 'epoch') await db.admin.query('UPDATE rounds.driver_devices SET session_epoch=session_epoch+1 WHERE id=$1', [s.device.device_id]);
    if (flag === 'capability') await db.admin.query(`UPDATE rounds.city_grants SET capabilities='{}' WHERE id=$1`, [s.ids.grant]);
    if (flag === 'superseded') await db.admin.query(`UPDATE rounds.assignments SET state='superseded' WHERE id=$1`, [s.ids.assignment]);
    if (flag === 'foreign-account') s.headers = (await setup()).headers;
    if (flag === 'foreign-city') s.r.context.city_id = s.ids.otherCity!;
    if (flag === 'foreign-tenant') s.r.context.tenant_id = randomUUID();
    assert.equal((await post(s)).status, 403); assert.equal((await status(s)).status, 403); assert.deepEqual(await snapshot(s), before);
  });
  for (const flag of ['foreign-order', 'closed-pickup', 'active-round', 'unacknowledged', 'expired-claim', 'archived-unit']) await t.test(`${flag} cannot create a pre-pickup report`, async () => {
    const s = await setup();
    if (flag === 'foreign-order') { s.r.payload.delivery_id = (await setup()).ids.delivery!; s.r.expected_versions[1]!.id = s.r.payload.delivery_id; }
    if (flag === 'closed-pickup') await db.admin.query(`UPDATE rounds.stops SET state='completed' WHERE id=$1`, [s.ids.pickup]);
    if (flag === 'active-round') await db.admin.query(`UPDATE rounds.rounds SET state='active' WHERE id=$1`, [s.ids.round]);
    if (flag === 'unacknowledged') await db.admin.query(`UPDATE rounds.assignments SET state='issued' WHERE id=$1`, [s.ids.assignment]);
    if (flag === 'expired-claim') await db.admin.query(`UPDATE rounds.active_delivery_claims SET expires_at=now()-interval '1 second' WHERE round_id=$1`, [s.ids.round]);
    if (flag === 'archived-unit') await db.admin.query('UPDATE rounds.fulfillment_units SET archived_at=now() WHERE id=$1', [s.ids.unit]);
    await denied(s, 'NOT_AUTHORIZED');
  });
  await t.test('actual reassignment revision prevents current-state mutation', async () => {
    const s = await setup(); await db.admin.query('UPDATE rounds.assignments SET version=version+1 WHERE id=$1', [s.ids.assignment]);
    await denied(s, 'EXECUTION_FENCE_CHANGED');
  });
  await t.test('SQL failure after every domain write rolls back report, hold, event and departure together', async () => {
    const s = await setup(), before = await snapshot(s), work = localPickupIssueWork(s.auth, s.r), execute = work.execute;
    work.execute = async (...args) => { const result = await execute(...args); await args[0].query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`, [s.ids.tenant, randomUUID()]); return result; };
    const outcome = await runner.run(work); assert.equal((outcome.result.error as {code: string}).code, 'VALIDATION_FAILED');
    assert.deepEqual(await snapshot(s), before); await denied(s, 'VALIDATION_FAILED');
  });
  await t.test('malformed success receipt rolls back even the original receipt; same request can safely retry', async () => {
    const s = await setup(), before = await snapshot(s), work = localPickupIssueWork(s.auth, s.r), execute = work.execute;
    work.execute = async (...args) => ({ ...await execute(...args), data: {} });
    await assert.rejects(runner.run(work), { code: 'PROVIDER_UNAVAILABLE' }); assert.deepEqual(await snapshot(s), before);
    assert.equal((await status(s)).status, 404); await committed(s);
  });
  await t.test('caller mutation during authorization cannot redirect original scope or payload', async () => {
    const s = await setup(), work = localPickupIssueWork(s.auth, s.r), authorize = work.authorize, original = structuredClone(s.r.payload);
    work.authorize = async (...args) => { await authorize(...args); const r = work.request as Wire_ReportIssueRequest; r.payload.delivery_id = randomUUID(); r.payload.round_id = randomUUID(); r.payload.detail = 'mutated'; s.r.payload.reason_code = 'changed'; };
    const result = await runner.run(work); assert.equal(result.result.state, 'committed');
    const stored = (await db.admin.query('SELECT payload FROM rounds.issue_report_observations WHERE tenant_id=$1', [s.ids.tenant])).rows[0]; assert.deepEqual(stored.payload, original);
  });
  await t.test('original observations are immutable even for admin and invisible outside owner/city/tenant', async () => {
    const s = await setup(), other = await setup(); const result = await committed(s), issue = result.data.resource.id;
    await restricted(s, async c => assert.equal((await c.query('SELECT issue_id FROM rounds.issue_report_observations')).rowCount, 1));
    for (const auth of [other.auth, { ...s.auth, cityId: s.ids.otherCity! }, { ...s.auth, principalId: other.ids.actor! }]) {
      await restricted({ ...s, auth }, async c => assert.equal((await c.query('SELECT issue_id FROM rounds.issue_report_observations')).rowCount, 0));
    }
    await assert.rejects(restricted(s, async c => { await c.query(`UPDATE rounds.issue_report_observations SET payload='{}' WHERE issue_id=$1`, [issue]); }), { code: '42501' });
    await assert.rejects(db.admin.query(`UPDATE rounds.issue_report_observations SET payload='{}' WHERE issue_id=$1`, [issue]), { code: '23514' });
    await assert.rejects(db.admin.query('DELETE FROM rounds.issue_report_observations WHERE issue_id=$1', [issue]), { code: '23514' });
  });
  await t.test('Node report route is explicitly default-off, never legacy fallback', async () => {
    for (const enabled of [false, true]) {
      const s = await setup(), boundary = createV23NodeBoundary({ origin: options.origin, ...(enabled ? { handler: http } : {}) });
      const server = createServer((req, res) => { void boundary(req, res).then(handled => { if (!handled) res.writeHead(500).end('legacy fallback'); }); });
      await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
      try {
        const address = server.address(); assert.ok(address && typeof address === 'object');
        const response = await fetch(`http://127.0.0.1:${address.port}${reportIssuePath}`, { method: 'POST', headers: s.headers, body: JSON.stringify(s.r) });
        assert.equal(response.status, enabled ? 200 : 403);
      } finally { server.closeAllConnections(); await new Promise<void>(resolve => server.close(() => resolve())); }
    }
  });

  t.diagnostic('Real isolated PostGIS, enrollment, HTTP, original-report immutability and pickup guard. Auth and GPS are labelled synthetic. No phone, native issue sender, purpose-bound photo upload, decision workflow or configured provider acceptance.');
});

test('issue migration preserves prior issue bytes and does not invent original assignment evidence', { timeout: 120000 }, async t => {
  let original: unknown, issueId = '';
  const db = await startPostgisFixture({ beforeIssueMigration: async admin => {
    const ids = await seedWholeOrder(admin); issueId = randomUUID();
    await admin.query(`INSERT INTO rounds.issues(id,tenant_id,delivery_id,round_id,driver_id,issue_type,reason_code,state,detail,reported_at,reported_by)
      VALUES($1,$2,$3,$4,$5,'package','missing','open',$6,'2026-09-08T13:22:10+07:00',$7)`,
    [issueId, ids.tenant, ids.delivery, ids.round, ids.driver, '  Preserved older report\nUnknown fence  ', ids.actor]);
    original = (await admin.query('SELECT row_to_json(i)::text AS original FROM rounds.issues i WHERE id=$1', [issueId])).rows[0];
  } });
  t.after(() => db.close());
  assert.deepEqual((await db.admin.query('SELECT row_to_json(i)::text AS original FROM rounds.issues i WHERE id=$1', [issueId])).rows[0], original);
  assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.issue_report_observations')).rows[0].n, 0);
});
