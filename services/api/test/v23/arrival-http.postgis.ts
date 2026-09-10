import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { test } from 'node:test';
import type { Wire_ConfirmArrivalRequest, Wire_ConfirmArrivalResult, Wire_ConfirmPickupRequest, Wire_DriverRoundExecutionQueryResult, Wire_RecordHandoffRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { createDeviceRegistrationHttp } from '../../src/v23/device-registration-http.js';
import { createPickupHttp, arrivalPath, pickupPath, handoffPath, statusPath } from '../../src/v23/pickup-http.js';
import { createDriverExecutionHttp, driverRoundPath } from '../../src/v23/driver-execution-query.js';
import { createV23NodeBoundary } from '../../src/v23/node-boundary.js';
import { deviceSessions } from '../../src/v23/device-session.js';
import { localArrivalWork } from '../../src/v23/confirm-local-arrival.js';
import { validateArrivalRequest, validateArrivalResult } from '../../src/v23/pickup-validation.js';
import { CommandRejection, CommandTransactionRunner } from '../../src/v23/transaction-runner.js';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';

const proof = { kind: 'proof', recipient_required: ['photo'], alternate_required: ['photo', 'receiver'], unattended_required: ['photo', 'note'], unattended_allowed: false, gps_override_allowed: false };
const point = { longitude: 100.5, latitude: 13.7 };
test('explicit arrival uses actual registered own-team HTTP and restricted PostGIS transactions', { timeout: 120000 }, async t => {
  const db = await startPostgisFixture(); t.after(() => db.close());
  const subjects = new Map<string, string>(), devices = deviceSessions({ id: 'arrival-test', secret: randomBytes(32) });
  const options = { pool: db.pool, devices, origin: 'http://localhost:3000', verifyBearer: async (token: string) => {
    const subject = subjects.get(token); if (!subject) throw new CommandRejection('UNAUTHENTICATED'); return subject;
  } };
  const http = createPickupHttp(options), query = createDriverExecutionHttp(options), enroll = createDeviceRegistrationHttp(options), runner = new CommandTransactionRunner(db.pool);
  async function setup(policy: unknown = proof) {
    const ids = await seedWholeOrder(db.admin, policy), subject = randomUUID(), bearer = randomUUID(); subjects.set(bearer, subject);
    await db.admin.query(`UPDATE rounds.stops SET state='released' WHERE id=$1`, [ids.pickup]);
    await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1', [ids.actor, subject]);
    await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`, [ids.tenant, ids.delivery, ids.round, ids.unit]);
    const registered = await enroll(new Request('http://rounds.internal/v1/auth/driver-device/session', { method: 'POST', headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' }, body: JSON.stringify({ installation_secret: randomBytes(32).toString('hex'), platform: 'android' }) }));
    assert.equal(registered.status, 200); const device = await registered.json();
    const headers = { authorization: `Bearer ${bearer}`, 'x-rounds-device-session': device.device_session, 'content-type': 'application/json' };
    const r: Wire_ConfirmArrivalRequest = { command_id: randomUUID(), context: { tenant_id: ids.tenant!, city_id: ids.city! }, occurred_at: '2026-09-09T00:00:00Z',
      execution_fence: { assignment_id: ids.assignment!, assignment_version: 1, observation_id: randomUUID() },
      expected_versions: [{ aggregate_type: 'stops', id: ids.pickup!, version: 1 }], payload: { stop_id: ids.pickup!, point, accuracy_m: 8 } };
    return { ids, headers, device, r, auth: { principalId: ids.actor!, tenantId: ids.tenant!, cityId: ids.city! } };
  }
  type Scenario = Awaited<ReturnType<typeof setup>>;
  const post = (s: Scenario, r: unknown = s.r, path = arrivalPath) => http(new Request('http://rounds.internal' + path, { method: 'POST', headers: s.headers, body: JSON.stringify(r) }));
  const status = (s: Scenario) => http(new Request(`http://rounds.internal${statusPath}?entity_id=${s.r.command_id}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}`, { headers: s.headers }));
  const snapshot = async (s: Scenario) => (await db.admin.query(`SELECT
    (SELECT count(*)::int FROM rounds.location_observations WHERE tenant_id=$1) observations,
    (SELECT count(*)::int FROM rounds.domain_events WHERE tenant_id=$1) events,
    (SELECT count(*)::int FROM rounds.outbox_events WHERE tenant_id=$1) outbox,
    (SELECT count(*)::int FROM rounds.custody_events WHERE tenant_id=$1) custody,
    (SELECT count(*)::int FROM rounds.delivery_attempts WHERE tenant_id=$1) attempts,
    (SELECT count(*)::int FROM rounds.location_samples WHERE driver_id=$6) samples,
    (SELECT state FROM rounds.stops WHERE id=$2) stop,
    (SELECT version::int FROM rounds.stops WHERE id=$2) version,
    (SELECT actual_arrival_at FROM rounds.stops WHERE id=$2) arrival,
    (SELECT preparation_state FROM rounds.deliveries WHERE id=$3) preparation,
    (SELECT readiness FROM rounds.deliveries WHERE id=$3) readiness,
    (SELECT outcome FROM rounds.deliveries WHERE id=$3) outcome,
    (SELECT state FROM rounds.rounds WHERE id=$4) round,
    (SELECT state FROM rounds.fulfillment_units WHERE id=$5) unit`, [s.ids.tenant, s.r.payload.stop_id, s.ids.delivery, s.ids.round, s.ids.unit, s.ids.driver])).rows[0];
  async function denied(s: Scenario, code: string, r: unknown = s.r) {
    const before = await snapshot(s), response = await post(s, r);
    assert.equal((await response.json()).code, code); assert.deepEqual(await snapshot(s), before);
  }
  async function committed(s: Scenario, r: unknown = s.r, path = arrivalPath) {
    const response = await post(s, r, path); assert.equal(response.status, 200, JSON.stringify(await response.clone().json())); return response.json();
  }
  async function secondOrder(s: Scenario, policy: unknown = proof) {
    const delivery = randomUUID(), manifest = randomUUID(), line = randomUUID(), unit = randomUUID(), stop = randomUUID(), policyId = randomUUID();
    await db.admin.query('BEGIN');
    try {
      await db.admin.query(`INSERT INTO rounds.policy_versions(id,tenant_id,policy_kind,scope_key,revision,schema_version,payload,effective_at,created_by)
        VALUES($1,$2,'proof','second-order',1,1,$3,now(),$4)`, [policyId, s.ids.tenant, policy, s.ids.actor]);
      await db.admin.query(`INSERT INTO rounds.deliveries(id,tenant_id,city_id,pickup_site_id,human_reference,service_date,timezone,window_start_at,window_end_at,address_text,readiness,outcome,evidence_state,proof_policy_id,created_by,preparation_state)
        SELECT $2,tenant_id,city_id,pickup_site_id,'SECOND-TEST',service_date,timezone,window_start_at,window_end_at,address_text,readiness,outcome,evidence_state,$3,created_by,preparation_state FROM rounds.deliveries WHERE id=$1`, [s.ids.delivery, delivery, policyId]);
      await db.admin.query(`INSERT INTO rounds.manifests(id,tenant_id,delivery_id,revision,source) VALUES($1,$2,$3,1,'manual')`, [manifest, s.ids.tenant, delivery]);
      await db.admin.query(`INSERT INTO rounds.manifest_lines(id,tenant_id,manifest_id,line_key,label,quantity,unit) VALUES($1,$2,$3,'SECOND','Synthetic second order',1,'item')`, [line, s.ids.tenant, manifest]);
      await db.admin.query(`INSERT INTO rounds.fulfillment_units(id,tenant_id,delivery_id,manifest_id,state) VALUES($1,$2,$3,$4,'open')`, [unit, s.ids.tenant, delivery, manifest]);
      await db.admin.query(`INSERT INTO rounds.fulfillment_unit_lines(tenant_id,unit_id,line_id,allocated_quantity) VALUES($1,$2,$3,1)`, [s.ids.tenant, unit, line]);
      await db.admin.query('UPDATE rounds.deliveries SET current_manifest_id=$2 WHERE id=$1', [delivery, manifest]);
      await db.admin.query(`INSERT INTO rounds.stops(id,tenant_id,round_id,delivery_id,kind,sequence,destination_version,state,service_seconds,fulfillment_unit_id)
        VALUES($1,$2,$3,$4,'dropoff',2,1,'released',60,$5)`, [stop, s.ids.tenant, s.ids.round, delivery, unit]);
      await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`, [s.ids.tenant, delivery, s.ids.round, unit]);
      await db.admin.query('COMMIT');
      return { delivery, unit, stop };
    } catch (error) { await db.admin.query('ROLLBACK'); throw error; }
  }
  async function picked(s: Scenario, pickupOccurredAt = '2026-09-09T00:01:00Z') {
    const response = await query(new Request(`http://rounds.internal${driverRoundPath}?entity_id=${s.ids.round}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}&view=execution`, { headers: s.headers }));
    assert.equal(response.status, 200); const view = await response.json() as Wire_DriverRoundExecutionQueryResult, d = view.data, c = d.context;
    const arrival: Wire_ConfirmArrivalRequest = { ...s.r, context: { tenant_id: c.tenant_id, city_id: c.city_id },
      execution_fence: { assignment_id: c.assignment_id, assignment_version: c.assignment_version, observation_id: randomUUID() },
      payload: { stop_id: d.pickup_stop_id, point, accuracy_m: 8 }, expected_versions: c.expected_versions.filter(v => v.aggregate_type === 'stops' && v.id === d.pickup_stop_id) };
    const arrived = await committed(s, arrival) as Wire_ConfirmArrivalResult;
    const request: Wire_ConfirmPickupRequest = { command_id: randomUUID(), context: arrival.context, occurred_at: pickupOccurredAt, execution_fence: { ...arrival.execution_fence, observation_id: randomUUID() },
      expected_versions: [...c.expected_versions.filter(v => ['rounds', 'manifests', 'fulfillment_units'].includes(v.aggregate_type)), arrived.data.resource],
      payload: { round_id: c.round_id, pickup_stop_id: d.pickup_stop_id, manifest_ids: d.orders.map(o => o.manifest_id), fulfillment_unit_ids: d.orders.map(o => o.fulfillment_unit_id), quantities: d.orders.flatMap(o => o.quantities) } };
    const result = await committed(s, request, pickupPath);
    const drop = c.stop_units.find(x => x.stop_id === d.orders[0]!.dropoff_stop_id);
    assert.ok(drop);
    s.r = { ...arrival, command_id: randomUUID(), occurred_at: '2026-09-09T00:02:00Z', execution_fence: { ...arrival.execution_fence, observation_id: randomUUID() },
      payload: { stop_id: drop.stop_id, point, accuracy_m: 9 }, expected_versions: c.expected_versions.filter(v => v.aggregate_type === 'stops' && v.id === drop.stop_id) };
    return result;
  }
  await t.test('pickup arrival is atomic, once-only and not custody, readiness or GPS tracking', async () => {
    const s = await setup(), replies = await Promise.all([post(s), post(s)]);
    for (const r of replies) assert.equal(r.status, 200, JSON.stringify(await r.clone().json()));
    const a = await replies[0]!.json(), b = await replies[1]!.json(); validateArrivalResult(a); assert.deepEqual(a, b);
    assert.deepEqual(replies.map(r => r.headers.get('x-rounds-replayed')).sort(), ['false', 'true']);
    assert.deepEqual(await snapshot(s), { observations: 1, events: 1, outbox: 1, custody: 0, attempts: 0, samples: 0,
      stop: 'arrived', version: 2, arrival: new Date(s.r.occurred_at), preparation: 'ready', readiness: 'ready', outcome: 'open', round: 'released', unit: 'open' });
    const observation = (await db.admin.query(`SELECT driver_id,delivery_id,ST_X(point::geometry) lon,ST_Y(point::geometry) lat,accuracy_m::float8 accuracy,observed_at,kind,note,state,reviewed_revision_id FROM rounds.location_observations WHERE id=$1`, [a.resources[0].id])).rows[0];
    assert.deepEqual(observation, { driver_id: s.ids.driver, delivery_id: null, lon: 100.5, lat: 13.7, accuracy: 8, observed_at: new Date(s.r.occurred_at), kind: 'arrival', note: null, state: 'proposed', reviewed_revision_id: null });
    const stored = (await db.admin.query('SELECT payload FROM rounds.domain_events WHERE command_id=$1', [s.r.command_id])).rows[0].payload;
    assert.deepEqual(stored.affected_resources, [...a.current_versions, ...a.resources]);
    const recovered = await status(s); assert.equal(recovered.status, 200); assert.deepEqual((await recovered.json()).data.result, a);
  });
  await t.test('query -> pickup arrival -> pickup -> dropoff arrival -> handoff uses real commands and predecessor versions', async () => {
    const s = await setup(), pickup = await picked(s), arrival = await committed(s) as Wire_ConfirmArrivalResult;
    const attempt = pickup.data.attempts[0], updated = arrival.current_versions.find(v => v.aggregate_type === 'delivery_attempts');
    assert.ok(updated); assert.equal(updated.id, attempt.id); assert.equal(updated.version, 2);
    const handoff: Wire_RecordHandoffRequest = { command_id: randomUUID(), context: s.r.context, occurred_at: '2026-09-09T00:03:00Z', execution_fence: { ...s.r.execution_fence, observation_id: randomUUID() },
      expected_versions: [updated], payload: { attempt_id: attempt.id, receiver_kind: 'recipient', quantities: pickup.data.collected_units[0].allocated_quantities } };
    await committed(s, handoff, handoffPath);
    const state = await snapshot(s);
    assert.equal(state.events, 4); assert.equal(state.observations, 2); assert.equal(state.custody, 2); assert.equal(state.attempts, 1);
    assert.equal(state.stop, 'handed_over'); assert.equal(state.outcome, 'open'); assert.equal(state.unit, 'collected');
    const a = (await db.admin.query('SELECT arrived_at,handoff_at,state FROM rounds.delivery_attempts WHERE id=$1', [attempt.id])).rows[0];
    assert.equal(a.arrived_at.toISOString(), '2026-09-09T00:02:00.000Z'); assert.equal(a.state, 'handed_over');
  });
  await t.test('pickup arrival before preparation/inbound completion does not fabricate either', async () => {
    const s = await setup();
    await db.admin.query(`UPDATE rounds.deliveries SET preparation_state='preparing' WHERE id=$1`, [s.ids.delivery]);
    await db.admin.query(`UPDATE rounds.rounds SET departure_gate='blocked' WHERE id=$1`, [s.ids.round]);
    await committed(s); const state = await snapshot(s);
    assert.equal(state.preparation, 'preparing'); assert.equal(state.custody, 0); assert.equal(state.unit, 'open');
    assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.inbound_dependencies WHERE tenant_id=$1', [s.ids.tenant])).rows[0].n, 0);
  });
  for (const kind of ['pickup', 'dropoff']) await t.test(`${kind} allowed GPS override records null location and exact reason`, async () => {
    const s = await setup({ ...proof, gps_override_allowed: true }); if (kind === 'dropoff') await picked(s);
    s.r.payload = { stop_id: s.r.payload.stop_id, point: null, accuracy_m: null, override_reason: '  GPS unavailable indoors  ' };
    const result = await committed(s);
    const obs = (await db.admin.query('SELECT point,accuracy_m,note,state FROM rounds.location_observations WHERE id=$1', [result.resources[0].id])).rows[0];
    assert.deepEqual(obs, { point: null, accuracy_m: null, note: '  GPS unavailable indoors  ', state: 'proposed' });
  });
  for (const [label, policy, code] of [['forbidden', proof, 'NOT_AUTHORIZED'], ['missing', {}, 'POLICY_NOT_CONFIGURED']] as const)
    await t.test(`${label} GPS override policy rejects without arrival`, async () => { const s = await setup(policy); s.r.payload = { stop_id: s.ids.pickup!, override_reason: 'No GPS' }; await denied(s, code); });
  await t.test('shared pickup requires every order policy, not only one permissive policy', async () => {
    const s = await setup({ ...proof, gps_override_allowed: true }); await secondOrder(s);
    s.r.payload = { stop_id: s.ids.pickup!, override_reason: 'GPS unavailable' }; await denied(s, 'NOT_AUTHORIZED');
    const b = await setup({ ...proof, gps_override_allowed: true }); await secondOrder(b, { ...proof, gps_override_allowed: true });
    b.r.payload = { stop_id: b.ids.pickup!, override_reason: 'GPS unavailable' }; await committed(b);
    assert.equal((await snapshot(b)).observations, 1);
  });
  for (const flag of ['future', 'schema']) await t.test(`${flag} policy cannot grant GPS override`, async () => {
    const s = await setup(), id = randomUUID();
    await db.admin.query(`INSERT INTO rounds.policy_versions(id,tenant_id,policy_kind,scope_key,revision,schema_version,payload,effective_at,created_by)
      VALUES($1,$2,'proof','override',1,$3,$4,now()+$5::interval,$6)`, [id, s.ids.tenant, flag === 'schema' ? 2 : 1, { ...proof, gps_override_allowed: true }, flag === 'future' ? '1 day' : '0 seconds', s.ids.actor]);
    await db.admin.query('UPDATE rounds.deliveries SET proof_policy_id=$2 WHERE id=$1', [s.ids.delivery, id]);
    s.r.payload = { stop_id: s.ids.pickup!, override_reason: 'No GPS' }; await denied(s, 'POLICY_NOT_CONFIGURED');
  });
  await t.test('reported poor accuracy is retained without claiming an invented geofence threshold', async () => {
    const s = await setup(); s.r.payload.accuracy_m = 5000; const result = await committed(s);
    assert.equal((await db.admin.query('SELECT accuracy_m::float8 accuracy,state FROM rounds.location_observations WHERE id=$1', [result.resources[0].id])).rows[0].accuracy, 5000);
  });
  for (const [label, mutate] of [
    ['missing accuracy', (r: Wire_ConfirmArrivalRequest) => { delete r.payload.accuracy_m; }],
    ['null accuracy', (r: Wire_ConfirmArrivalRequest) => { r.payload.accuracy_m = null; }],
    ['negative accuracy', (r: Wire_ConfirmArrivalRequest) => { r.payload.accuracy_m = -1; }],
    ['accuracy without point', (r: Wire_ConfirmArrivalRequest) => { delete r.payload.point; }],
    ['GPS mixed with override', (r: Wire_ConfirmArrivalRequest) => { r.payload.override_reason = 'No GPS'; }],
    ['neither GPS nor reason', (r: Wire_ConfirmArrivalRequest) => { r.payload = { stop_id: r.payload.stop_id }; }],
    ['blank override', (r: Wire_ConfirmArrivalRequest) => { r.payload = { stop_id: r.payload.stop_id, override_reason: '  ' }; }],
    ['invalid coordinate', (r: Wire_ConfirmArrivalRequest) => { r.payload.point = { longitude: 181, latitude: 0 }; }],
    ['unrelated extra root', (r: Wire_ConfirmArrivalRequest) => { r.expected_versions.push({ aggregate_type: 'rounds', id: randomUUID(), version: 1 }); }],
  ] as const) await t.test(label, async () => { const s = await setup(); mutate(s.r); await denied(s, 'VALIDATION_FAILED'); });
  await t.test('nonfinite accuracy and caller authority/attempt selectors fail exact validation', async () => {
    const s = await setup();
    for (const r of [{ ...s.r, payload: { ...s.r.payload, accuracy_m: Infinity } }, { ...s.r, payload: { ...s.r.payload, attempt_id: randomUUID() } }, { ...s.r, actor_id: s.ids.actor }])
      assert.throws(() => validateArrivalRequest(r), new CommandRejection('VALIDATION_FAILED'));
  });
  for (const flag of ['planned', 'already-arrived', 'completed', 'return', 'hold', 'no-claim', 'stale-version', 'stale-fence', 'wrong-stop']) await t.test(flag, async () => {
    const s = await setup(); let code = 'NOT_AUTHORIZED';
    if (['planned', 'already-arrived', 'completed'].includes(flag)) { await db.admin.query('UPDATE rounds.stops SET state=$2 WHERE id=$1', [s.ids.pickup, flag === 'already-arrived' ? 'arrived' : flag]); code = 'CUSTODY_MISMATCH'; }
    if (flag === 'return') await db.admin.query(`UPDATE rounds.stops SET kind='return' WHERE id=$1`, [s.ids.pickup]);
    if (flag === 'hold') await db.admin.query('UPDATE rounds.rounds SET operational_hold=true WHERE id=$1', [s.ids.round]);
    if (flag === 'no-claim') await db.admin.query('UPDATE rounds.active_delivery_claims SET archived_at=now() WHERE round_id=$1', [s.ids.round]);
    if (flag === 'stale-version') { s.r.expected_versions[0]!.version = 2; code = 'STALE_VERSION'; }
    if (flag === 'stale-fence') { s.r.execution_fence.assignment_version = 2; code = 'EXECUTION_FENCE_CHANGED'; }
    if (flag === 'wrong-stop') s.r.payload.stop_id = randomUUID();
    await denied(s, code);
  });
  await t.test('dropoff cannot arrive without actual pickup or before its collection time', async () => {
    const s = await setup(); s.r.payload.stop_id = s.ids.dropoff!; s.r.expected_versions[0]!.id = s.ids.dropoff!;
    await denied(s, 'CUSTODY_MISMATCH');
    const b = await setup(); await picked(b); b.r.occurred_at = '2026-09-09T00:00:00Z'; await denied(b, 'CUSTODY_MISMATCH');
  });
  await t.test('pickup cannot be backdated before the real arrival predecessor', async () => {
    const s = await setup(); await assert.rejects(picked(s, '2026-09-08T23:59:00Z'), /PICKUP_NOT_READY/);
    const state = await snapshot(s); assert.equal(state.custody, 0); assert.equal(state.attempts, 0); assert.equal(state.stop, 'arrived');
  });
  await t.test('later dropoff cannot silently bypass the current unfinished stop', async () => {
    const s = await setup(), later = await secondOrder(s); await picked(s);
    s.r.payload.stop_id = later.stop; s.r.expected_versions = [{ aggregate_type: 'stops', id: later.stop, version: 1 }];
    await denied(s, 'NOT_AUTHORIZED');
  });
  await t.test('an attempt belonging to another driver cannot be arrived by the Round driver', async () => {
    const s = await setup(), other = await setup(); await picked(s);
    await db.admin.query('UPDATE rounds.delivery_attempts SET driver_id=$2 WHERE stop_id=$1', [s.ids.dropoff, other.ids.driver]);
    await denied(s, 'CUSTODY_MISMATCH');
  });
  await t.test('en_route pickup and dropoff attempts are accepted without duplicate attempts', async () => {
    const s = await setup(); await db.admin.query(`UPDATE rounds.stops SET state='en_route' WHERE id=$1`, [s.ids.pickup]); await picked(s);
    await db.admin.query(`UPDATE rounds.stops SET state='en_route' WHERE id=$1`, [s.ids.dropoff]);
    await db.admin.query(`UPDATE rounds.delivery_attempts SET state='en_route' WHERE stop_id=$1`, [s.ids.dropoff]); await committed(s);
    assert.equal((await snapshot(s)).attempts, 1);
  });
  await t.test('two commands racing one arrival yield exactly one transition', async () => {
    const s = await setup(), results = await Promise.all([post(s), post(s, { ...s.r, command_id: randomUUID() })]);
    assert.deepEqual(results.map(r => r.status).sort(), [200, 409]); assert.equal((await snapshot(s)).observations, 1);
  });
  await t.test('same identity cannot change observation after commit', async () => {
    const s = await setup(); await committed(s); s.r.payload.accuracy_m = 20; await denied(s, 'IDEMPOTENCY_CONFLICT');
  });
  for (const flag of ['device', 'epoch', 'city', 'assignment', 'foreign-account', 'foreign-city', 'foreign-tenant']) await t.test(`${flag} revokes replay and status access`, async () => {
    const s = await setup(); await committed(s); const before = await snapshot(s);
    if (flag === 'device') await db.admin.query('UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1', [s.device.device_id]);
    if (flag === 'epoch') await db.admin.query('UPDATE rounds.driver_devices SET session_epoch=session_epoch+1 WHERE id=$1', [s.device.device_id]);
    if (flag === 'city') await db.admin.query(`UPDATE rounds.city_grants SET capabilities='{}' WHERE id=$1`, [s.ids.grant]);
    if (flag === 'assignment') await db.admin.query(`UPDATE rounds.assignments SET state='superseded' WHERE id=$1`, [s.ids.assignment]);
    if (flag === 'foreign-account') s.headers = (await setup()).headers;
    if (flag === 'foreign-city') { s.r.context.city_id = s.ids.otherCity!; s.ids.city = s.ids.otherCity!; }
    if (flag === 'foreign-tenant') { s.r.context.tenant_id = randomUUID(); s.ids.tenant = s.r.context.tenant_id; }
    assert.equal((await post(s)).status, 403); assert.equal((await status(s)).status, 403);
    if (flag !== 'foreign-tenant') assert.deepEqual(await snapshot(s), before);
  });
  await t.test('SQL failure after arrival writes rolls everything back, preserving rejected receipt', async () => {
    const s = await setup(), before = await snapshot(s), work = localArrivalWork(s.auth, s.r), execute = work.execute;
    work.execute = async (...args) => { const result = await execute(...args); await args[0].query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`, [s.ids.tenant, randomUUID()]); return result; };
    const r = await runner.run(work); assert.equal((r.result.error as { code: string }).code, 'VALIDATION_FAILED'); assert.deepEqual(await snapshot(s), before);
    await denied(s, 'VALIDATION_FAILED');
  });
  await t.test('dropoff arrival SQL failure also rolls back the real pending attempt timestamp/version', async () => {
    const s = await setup(); await picked(s);
    const before = await snapshot(s), attemptBefore = (await db.admin.query('SELECT state,arrived_at,version FROM rounds.delivery_attempts WHERE stop_id=$1', [s.ids.dropoff])).rows;
    const work = localArrivalWork(s.auth, s.r), execute = work.execute;
    work.execute = async (...args) => { const result = await execute(...args); await args[0].query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`, [s.ids.tenant, randomUUID()]); return result; };
    const r = await runner.run(work); assert.equal((r.result.error as { code: string }).code, 'VALIDATION_FAILED');
    assert.deepEqual(await snapshot(s), before);
    assert.deepEqual((await db.admin.query('SELECT state,arrived_at,version FROM rounds.delivery_attempts WHERE stop_id=$1', [s.ids.dropoff])).rows, attemptBefore);
  });
  await t.test('invalid result cannot commit observation/arrival or a success receipt', async () => {
    const s = await setup(), before = await snapshot(s), work = localArrivalWork(s.auth, s.r), execute = work.execute;
    work.execute = async (...args) => ({ ...await execute(...args), data: {} });
    await assert.rejects(runner.run(work), { code: 'PROVIDER_UNAVAILABLE' }); assert.deepEqual(await snapshot(s), before);
    assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.command_receipts WHERE command_key=$1', [s.r.command_id])).rows[0].n, 0);
    await committed(s);
  });
  await t.test('scope resolver cannot be redirected by mutation during authorization', async () => {
    const s = await setup(), work = localArrivalWork(s.auth, s.r), authorize = work.authorize, original = s.r.payload.stop_id;
    work.authorize = async (...args) => { await authorize(...args); (work.request as Wire_ConfirmArrivalRequest).payload.stop_id = randomUUID(); (work.request as Wire_ConfirmArrivalRequest).execution_fence.assignment_id = randomUUID(); s.r.payload.stop_id = randomUUID(); };
    const result = (await runner.run(work)).result as Wire_ConfirmArrivalResult; assert.equal(result.data.resource.id, original);
  });
  await t.test('direct handler returns the contract after actual restricted writes', async () => {
    const s = await setup(), work = localArrivalWork(s.auth, s.r), execute = work.execute;
    let cause: unknown;
    work.execute = async (...args) => { try { return await execute(...args); } catch (error) { cause = error; throw error; } };
    const result = await runner.run(work).catch(error => { throw cause ?? error; });
    assert.equal(result.result.state, 'committed');
  });
  await t.test('Node arrival route is default-off and never falls through to the old API', async () => {
    for (const enabled of [false, true]) {
      const s = await setup(), boundary = createV23NodeBoundary({ origin: options.origin, ...(enabled ? { handler: http } : {}) });
      const server = createServer((req, res) => { void boundary(req, res).then(handled => { if (!handled) res.writeHead(500).end('legacy fallback'); }); });
      await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
      try { const address = server.address(); assert.ok(address && typeof address === 'object');
        const response = await fetch(`http://127.0.0.1:${address.port}${arrivalPath}`, { method: 'POST', headers: s.headers, body: JSON.stringify(s.r) }); assert.equal(response.status, enabled ? 200 : 403);
      } finally { server.closeAllConnections(); await new Promise<void>(resolve => server.close(() => resolve())); }
    }
  });
  t.diagnostic('Actual registered-device HTTP/SQL arrival and query -> arrival -> pickup -> arrival -> handoff; Auth and GPS are synthetic. No provider geofence, proof/completion, stale retention or phone activation acceptance.');
});
