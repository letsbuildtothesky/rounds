import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { test } from 'node:test';
import sharp from 'sharp';
import type { Wire_ReportIssueRequest, Wire_ReserveAssetRequest, Wire_VerifyAssetRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { createPickupHttp, statusPath } from '../../src/v23/pickup-http.js';
import { createPodAssets, loadBoundPodAsset, reserveAssetPath, verifyAssetPath, type PodObjectStore, type PodUpload } from '../../src/v23/pod-assets.js';
import { reportIssuePath } from '../../src/v23/report-local-pickup-issue.js';
import { createDeviceRegistrationHttp } from '../../src/v23/device-registration-http.js';
import { deviceSessions } from '../../src/v23/device-session.js';
import { CommandRejection } from '../../src/v23/transaction-runner.js';
import { podHash } from '../../src/v23/pod-byte-verification.js';
import { beginRestrictedTransaction } from '../../src/v23/restricted-transaction.js';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';

// Synthetic Auth/private storage, real registered HTTP handlers, image decoder,
// restricted-role transactions, migration, RLS and concurrent command receipts.
test('pickup issue photos stay bound to the original order and report', { timeout: 120000 }, async t => {
  let oldAsset: string, oldTenant: string;
  const db = await startPostgisFixture({ beforePickupPhotoMigration: async c => {
    const ids = await seedWholeOrder(c); oldAsset = randomUUID(); oldTenant = ids.tenant!;
    await c.query(`INSERT INTO rounds.assets(id,tenant_id,object_key,kind,state,mime_type,byte_size,sha256,created_by,retention_class)
      VALUES($1,$2,'legacy-untouched','issue_photo','reserved','image/png',7,$3,$4,'isolated-test')`, [oldAsset, ids.tenant, 'a'.repeat(64), ids.actor]);
  } }); t.after(() => db.close());
  const subjects = new Map<string, string>(), objects = new Map<string, Buffer>(), caps = new Map<string, PodUpload>();
  let afterSign: (() => Promise<void>) | undefined, beforeSeal: (() => Promise<void>) | undefined, reads = 0, signing = 0, concurrent = false;
  const png = await sharp({ create: { width: 3, height: 3, channels: 3, background: '#234567' } }).png().toBuffer();
  const jpeg = await sharp(png).jpeg().toBuffer();
  async function outsideTransaction() {
    if (!concurrent) assert.equal((await db.admin.query(`SELECT count(*)::int n FROM pg_stat_activity WHERE usename='fixture_login' AND state='idle in transaction'`)).rows[0].n, 0);
  }
  const storage: PodObjectStore = {
    async issueUpload(upload) {
      await outsideTransaction(); signing++; const token = randomUUID(); caps.set(token, { ...upload }); await afterSign?.();
      return { upload_url: `https://storage.invalid/${token}`, upload_token: token, upload_method: 'PUT', expires_at: new Date(Date.now() + 240000).toISOString() };
    },
    async read(key) { await outsideTransaction(); reads++; const bytes = objects.get(key); if (!bytes) throw new Error('Provider unavailable'); return (async function* () { yield Buffer.from(bytes); })(); },
    async seal(key, bytes) { await outsideTransaction(); await beforeSeal?.(); assert.ok(!objects.has(key)); objects.set(key, Buffer.from(bytes)); },
  };
  const options = { pool: db.pool, devices: deviceSessions({ id: 'pickup-photo-test', secret: randomBytes(32) }), origin: 'http://localhost:3000',
    verifyBearer: async (bearer: string) => { const subject = subjects.get(bearer); if (!subject) throw new CommandRejection('UNAUTHENTICATED'); return subject; } };
  const http = createPickupHttp({ ...options, assets: createPodAssets(db.pool, storage, 'isolated-test') }), enroll = createDeviceRegistrationHttp(options);
  async function setup() {
    const ids = await seedWholeOrder(db.admin), subject = randomUUID(), bearer = randomUUID(); subjects.set(bearer, subject);
    await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1', [ids.actor, subject]);
    await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`, [ids.tenant, ids.delivery, ids.round, ids.unit]);
    const response = await enroll(new Request('http://rounds.internal/v1/auth/driver-device/session', { method: 'POST', headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' }, body: JSON.stringify({ installation_secret: randomBytes(32).toString('hex'), platform: 'android' }) }));
    assert.equal(response.status, 200); const device = await response.json();
    const headers = { authorization: `Bearer ${bearer}`, 'x-rounds-device-session': device.device_session, 'content-type': 'application/json' };
    const report: Wire_ReportIssueRequest = { command_id: randomUUID(), context: { tenant_id: ids.tenant!, city_id: ids.city! }, occurred_at: '2026-09-09T01:02:03.456Z',
      execution_fence: { assignment_id: ids.assignment!, assignment_version: 1, observation_id: randomUUID() },
      expected_versions: [{ aggregate_type: 'rounds', id: ids.round!, version: 1 }, { aggregate_type: 'deliveries', id: ids.delivery!, version: 1 }],
      payload: { round_id: ids.round!, delivery_id: ids.delivery!, issue_type: 'package', reason_code: 'damaged', detail: '  Broken vase.  ', affected_lines: [], asset_ids: [] } };
    const reserve: Wire_ReserveAssetRequest = { command_id: randomUUID(), context: report.context, occurred_at: report.occurred_at, expected_versions: [],
      payload: { kind: 'issue_photo', mime_type: 'image/png', byte_size: png.length, sha256: podHash(png), purpose_entity_id: ids.delivery!, pickup_context: {
        round_id: ids.round!, pickup_stop_id: ids.pickup!, fulfillment_unit_id: ids.unit!, manifest_id: ids.manifest!, execution_fence: { ...report.execution_fence } } } };
    return { ids, device, headers, report, reserve, auth: { tenantId: ids.tenant!, cityId: ids.city!, principalId: ids.actor! } };
  }
  type Scenario = Awaited<ReturnType<typeof setup>>;
  const post = (s: Scenario, path: string, body: unknown) => http(new Request('http://rounds.internal' + path, { method: 'POST', headers: s.headers, body: JSON.stringify(body) }));
  async function ok(s: Scenario, path: string, body: unknown) { const r = await post(s, path, body); assert.equal(r.status, 200, JSON.stringify(await r.clone().json())); return r.json(); }
  const status = (s: Scenario, id: string) => http(new Request(`http://rounds.internal${statusPath}?entity_id=${id}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}`, { headers: s.headers }));
  const snapshot = async (s: Scenario) => (await db.admin.query(`SELECT
    (SELECT count(*)::int FROM rounds.assets WHERE tenant_id=$1) assets,
    (SELECT count(*)::int FROM rounds.pickup_issue_asset_bindings WHERE tenant_id=$1) bindings,
    (SELECT count(*)::int FROM rounds.issues WHERE tenant_id=$1) issues,
    (SELECT count(*)::int FROM rounds.domain_events WHERE tenant_id=$1) events,
    (SELECT count(*)::int FROM rounds.outbox_events WHERE tenant_id=$1) outbox,
    (SELECT count(*)::int FROM rounds.custody_events WHERE tenant_id=$1) custody,
    (SELECT count(*)::int FROM rounds.handoffs WHERE tenant_id=$1) handoffs,
    (SELECT count(*)::int FROM rounds.issue_decisions WHERE tenant_id=$1) decisions,
    (SELECT readiness FROM rounds.deliveries WHERE id=$2) readiness,
    (SELECT version::int FROM rounds.deliveries WHERE id=$2) delivery_version,
    (SELECT version::int FROM rounds.rounds WHERE id=$3) round_version`, [s.ids.tenant, s.ids.delivery, s.ids.round])).rows[0];
  async function denied(s: Scenario, path: string, body: unknown, code: string) {
    const before = await snapshot(s), r = await post(s, path, body); assert.equal((await r.json()).code, code); assert.deepEqual(await snapshot(s), before);
  }
  async function reserved(s: Scenario, bytes = png, mime = 'image/png') {
    s.reserve.payload.byte_size = bytes.length; s.reserve.payload.sha256 = podHash(bytes); s.reserve.payload.mime_type = mime;
    const result = await ok(s, reserveAssetPath, s.reserve), id = result.data.asset_id as string, key = caps.get(result.data.upload_token)!.key;
    objects.set(key, Buffer.from(bytes)); s.report.payload.asset_ids = [id];
    const verify: Wire_VerifyAssetRequest = { command_id: randomUUID(), context: s.reserve.context, occurred_at: s.reserve.occurred_at,
      expected_versions: [{ aggregate_type: 'assets', id, version: 1 }], payload: { asset_id: id, sha256: podHash(bytes) } };
    return { result, id, key, verify };
  }
  const verified = async (s: Scenario) => { const a = await reserved(s); await ok(s, verifyAssetPath, a.verify); return a; };
  for (const reason of ['damaged', 'wrong']) await t.test(reason + ': reserve, decode actual bytes, seal, report with exact immutable purpose', async () => {
    const s = await setup(); s.report.payload.reason_code = reason;
    const a = await reserved(s, reason === 'wrong' ? jpeg : png, reason === 'wrong' ? 'image/jpeg' : 'image/png');
    await ok(s, verifyAssetPath, a.verify); const result = await ok(s, reportIssuePath, s.report);
    assert.deepEqual(await snapshot(s), { assets: 1, bindings: 1, issues: 1, events: 4, outbox: 4, custody: 0, handoffs: 0, decisions: 0, readiness: 'held', delivery_version: 2, round_version: 2 });
    const b = (await db.admin.query('SELECT * FROM rounds.pickup_issue_asset_bindings WHERE asset_id=$1', [a.id])).rows[0];
    assert.equal(b.delivery_id, s.ids.delivery); assert.equal(b.manifest_id, s.ids.manifest); assert.equal(b.fulfillment_unit_id, s.ids.unit);
    assert.equal(b.pickup_stop_id, s.ids.pickup); assert.equal(b.observation_id, s.report.execution_fence.observation_id); assert.equal(b.observed_at.toISOString(), s.report.occurred_at);
    const saved = (await db.admin.query('SELECT payload FROM rounds.issue_report_observations WHERE issue_id=$1', [result.data.resource.id])).rows[0].payload;
    assert.deepEqual(saved, s.report.payload);
    const asset = (await db.admin.query('SELECT state,object_key FROM rounds.assets WHERE id=$1', [a.id])).rows[0];
    assert.equal(asset.state, 'verified'); assert.match(asset.object_key, /^pod-verified\//); assert.notEqual(asset.object_key, a.key);
    assert.equal(podHash(objects.get(asset.object_key)!), a.verify.payload.sha256);
    const before = await snapshot(s), readCount = reads;
    assert.deepEqual(await ok(s, reportIssuePath, s.report), result);
    assert.deepEqual((await (await status(s, s.report.command_id)).json()).data.result, result);
    await ok(s, verifyAssetPath, a.verify); assert.equal(reads, readCount); assert.deepEqual(await snapshot(s), before);
  });
  await t.test('pre-arrival/unprepared report observes a problem without inventing receipt or arrival', async () => {
    const s = await setup(); await db.admin.query(`UPDATE rounds.stops SET state='released',actual_arrival_at=NULL WHERE id=$1`, [s.ids.pickup]);
    await db.admin.query(`UPDATE rounds.deliveries SET preparation_state='preparing',readiness='held' WHERE id=$1`, [s.ids.delivery]);
    await verified(s); await ok(s, reportIssuePath, s.report);
    assert.equal((await db.admin.query('SELECT actual_arrival_at FROM rounds.stops WHERE id=$1', [s.ids.pickup])).rows[0].actual_arrival_at, null);
    assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.trip_receipts WHERE tenant_id=$1', [s.ids.tenant])).rows[0].n, 0);
  });
  await t.test('original timestamp precision is retained rather than rounded into a different report', async () => {
    const s = await setup(); s.reserve.occurred_at = s.report.occurred_at = '2026-09-09T01:02:03.456001Z';
    await verified(s); await ok(s, reportIssuePath, s.report);
  });
  for (const reason of ['damaged', 'wrong']) await t.test(reason + ' requires one verified photo', async () => {
    const s = await setup(); s.report.payload.reason_code = reason; await denied(s, reportIssuePath, s.report, 'ASSET_NOT_VERIFIED');
    const a = await reserved(s); await denied(s, reportIssuePath, s.report, 'ASSET_NOT_VERIFIED');
    s.report.payload.asset_ids = [a.id, randomUUID()]; await denied(s, reportIssuePath, s.report, 'ASSET_NOT_VERIFIED');
  });
  await t.test('fresh reserve/status capabilities never enter receipts or facts', async () => {
    const s = await setup(), a = await reserved(s), b = await ok(s, reserveAssetPath, s.reserve), recovered = await (await status(s, s.reserve.command_id)).json();
    assert.equal(a.id, b.data.asset_id); assert.equal(a.id, recovered.data.result.data.asset_id); assert.notEqual(a.result.data.upload_token, b.data.upload_token);
    assert.equal(caps.get(b.data.upload_token)!.key, a.key);
    const receipt = (await db.admin.query('SELECT result FROM rounds.command_receipts WHERE command_key=$1', [s.reserve.command_id])).rows[0].result;
    assert.deepEqual(receipt.data, { asset_id: a.id });
    const facts = JSON.stringify((await db.admin.query('SELECT payload FROM rounds.domain_events WHERE tenant_id=$1', [s.ids.tenant])).rows);
    assert.ok(!facts.includes('upload_token') && !facts.includes(a.result.data.upload_token));
  });
  for (const field of ['round_id', 'pickup_stop_id', 'fulfillment_unit_id', 'manifest_id'] as const) await t.test('foreign ' + field + ' cannot reserve', async () => {
    const s = await setup(); s.reserve.payload.pickup_context![field] = randomUUID(); await denied(s, reserveAssetPath, s.reserve, 'NOT_AUTHORIZED');
  });
  await t.test('required/forbidden context and safe integer fence validated before reservation', async () => {
    const s = await setup(); const context = s.reserve.payload.pickup_context!; delete s.reserve.payload.pickup_context;
    await denied(s, reserveAssetPath, s.reserve, 'VALIDATION_FAILED'); s.reserve.payload.pickup_context = context; s.reserve.payload.kind = 'delivery_photo';
    await denied(s, reserveAssetPath, s.reserve, 'VALIDATION_FAILED'); s.reserve.payload.kind = 'issue_photo'; context.execution_fence.assignment_version = Number.MAX_SAFE_INTEGER + 1;
    await denied(s, reserveAssetPath, s.reserve, 'VALIDATION_FAILED');
  });
  await t.test('original assignment version cannot be refreshed', async () => {
    const s = await setup(); await db.admin.query('UPDATE rounds.assignments SET version=2 WHERE id=$1', [s.ids.assignment]);
    await denied(s, reserveAssetPath, s.reserve, 'EXECUTION_FENCE_CHANGED');
  });
  for (const [label, sql, arg] of [
    ['collected unit', `UPDATE rounds.fulfillment_units SET collected_at=now() WHERE id=$1`, 'unit'],
    ['expired claim', `UPDATE rounds.active_delivery_claims SET expires_at=now()-interval '1 second' WHERE delivery_id=$1`, 'delivery'],
    ['inactive assignment', `UPDATE rounds.assignments SET state='received' WHERE id=$1`, 'assignment'],
    ['revoked device', `UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1`, 'device'],
  ]) await t.test(label + ' prevents reservation', async () => {
    const s = await setup(); await db.admin.query(sql!, [arg === 'device' ? s.device.device_id : s.ids[arg!]]); await denied(s, reserveAssetPath, s.reserve, 'NOT_AUTHORIZED');
  });
  for (const field of ['observation', 'time', 'submillisecond time'] as const) await t.test('verified photo for another ' + field + ' cannot attach', async () => {
    const s = await setup(); await verified(s);
    if (field === 'observation') s.report.execution_fence.observation_id = randomUUID(); else s.report.occurred_at = field === 'time' ? '2026-09-09T01:02:04.456Z' : '2026-09-09T01:02:03.456001Z';
    await denied(s, reportIssuePath, s.report, 'NOT_AUTHORIZED');
  });
  await t.test('foreign tenant/actor photo is neither readable nor attachable', async () => {
    const owner = await setup(), other = await setup(), a = await verified(owner); other.report.payload.asset_ids = [a.id];
    await denied(other, reportIssuePath, other.report, 'NOT_AUTHORIZED');
    await denied(other, verifyAssetPath, { ...a.verify, context: other.reserve.context }, 'NOT_AUTHORIZED');
    const c = await db.pool.connect();
    try { await beginRestrictedTransaction(c, other.auth); assert.equal((await c.query('SELECT asset_id FROM rounds.pickup_issue_asset_bindings WHERE asset_id=$1', [a.id])).rowCount, 0); }
    finally { await c.query('ROLLBACK'); c.release(); }
  });
  await t.test('POD loader refuses a verified pickup photo', async () => {
    const s = await setup(), a = await verified(s), c = await db.pool.connect();
    try { await beginRestrictedTransaction(c, s.auth); await assert.rejects(loadBoundPodAsset(c, s.auth, a.id), (e: unknown) => e instanceof CommandRejection && e.code === 'NOT_AUTHORIZED'); }
    finally { await c.query('ROLLBACK'); c.release(); }
  });
  await t.test('an unbound existing POD photo cannot be relabelled as pickup evidence', async () => {
    const s = await setup(), id = randomUUID();
    await db.admin.query(`INSERT INTO rounds.assets(id,tenant_id,object_key,kind,state,mime_type,byte_size,sha256,created_by,retention_class,verified_at)
      VALUES($1,$2,'prior-pod','delivery_photo','verified','image/png',$3,$4,$5,'isolated-test',now())`, [id, s.ids.tenant, png.length, podHash(png), s.ids.actor]);
    s.report.payload.asset_ids = [id]; await denied(s, reportIssuePath, s.report, 'NOT_AUTHORIZED');
  });
  await t.test('fresh manifest invalidates original photo without rewriting or deleting it', async () => {
    const s = await setup(), a = await verified(s), manifest = randomUUID(), line = randomUUID();
    // A legitimate complete revision is atomic. The DB itself rejects merely
    // repointing the manifest without its complete line/unit allocation.
    await db.admin.query('BEGIN');
    try {
      await db.admin.query(`INSERT INTO rounds.manifests(id,tenant_id,delivery_id,revision,source) VALUES($1,$2,$3,2,'manual')`, [manifest, s.ids.tenant, s.ids.delivery]);
      await db.admin.query(`INSERT INTO rounds.manifest_lines(id,tenant_id,manifest_id,line_key,label,quantity,unit) VALUES($1,$2,$3,'REVISED','Replacement complete order',5,'item')`, [line, s.ids.tenant, manifest]);
      await db.admin.query('UPDATE rounds.fulfillment_unit_lines SET archived_at=now() WHERE unit_id=$1', [s.ids.unit]);
      await db.admin.query('UPDATE rounds.fulfillment_units SET manifest_id=$2 WHERE id=$1', [s.ids.unit, manifest]);
      await db.admin.query('INSERT INTO rounds.fulfillment_unit_lines(tenant_id,unit_id,line_id,allocated_quantity) VALUES($1,$2,$3,5)', [s.ids.tenant, s.ids.unit, line]);
      await db.admin.query('UPDATE rounds.deliveries SET current_manifest_id=$2 WHERE id=$1', [s.ids.delivery, manifest]);
      await db.admin.query('COMMIT');
    } catch (e) { await db.admin.query('ROLLBACK'); throw e; }
    await denied(s, reportIssuePath, s.report, 'NOT_AUTHORIZED');
    assert.equal((await db.admin.query('SELECT manifest_id FROM rounds.pickup_issue_asset_bindings WHERE asset_id=$1', [a.id])).rows[0].manifest_id, s.ids.manifest);
    assert.equal((await db.admin.query('SELECT state FROM rounds.assets WHERE id=$1', [a.id])).rows[0].state, 'verified');
  });
  await t.test('lost upload retries original verification ID; missing provider bytes are not a durable rejection', async () => {
    const s = await setup(), a = await reserved(s); objects.delete(a.key);
    const response = await post(s, verifyAssetPath, a.verify); assert.equal(response.status, 503);
    assert.equal((await status(s, a.verify.command_id)).status, 404);
    objects.set(a.key, Buffer.from(png)); await ok(s, verifyAssetPath, a.verify); await ok(s, reportIssuePath, s.report);
  });
  await t.test('changed reserve replay conflicts rather than redirecting original photo', async () => {
    const s = await setup(), a = await reserved(s); s.reserve.payload.pickup_context!.execution_fence.observation_id = randomUUID();
    await denied(s, reserveAssetPath, s.reserve, 'IDEMPOTENCY_CONFLICT');
    assert.equal((await db.admin.query('SELECT observation_id FROM rounds.pickup_issue_asset_bindings WHERE asset_id=$1', [a.id])).rows[0].observation_id, s.report.execution_fence.observation_id);
  });
  for (const [label, bytes] of [['invalid raster', Buffer.from('not an image')], ['truncated raster', png.subarray(0, 40)]] as const) await t.test(label + ' fails even with matching hash', async () => {
    const s = await setup(), a = await reserved(s, bytes); await denied(s, verifyAssetPath, a.verify, 'ASSET_NOT_VERIFIED');
    assert.equal((await db.admin.query('SELECT state FROM rounds.assets WHERE id=$1', [a.id])).rows[0].state, 'reserved');
  });
  await t.test('changed upload bytes cannot verify', async () => {
    const s = await setup(), a = await reserved(s); objects.set(a.key, Buffer.alloc(png.length)); await denied(s, verifyAssetPath, a.verify, 'ASSET_NOT_VERIFIED');
  });
  await t.test('assignment changes during byte IO reject without destroying original bytes', async () => {
    const s = await setup(), a = await reserved(s); beforeSeal = async () => { await db.admin.query('UPDATE rounds.assignments SET version=2 WHERE id=$1', [s.ids.assignment]); };
    try { await denied(s, verifyAssetPath, a.verify, 'EXECUTION_FENCE_CHANGED'); } finally { beforeSeal = undefined; }
    assert.deepEqual(objects.get(a.key), png);
    assert.equal((await db.admin.query('SELECT state FROM rounds.assets WHERE id=$1', [a.id])).rows[0].state, 'reserved');
  });
  await t.test('revocation during signing withholds capability; committed reservation remains recoverable identity', async () => {
    const s = await setup(); afterSign = async () => { await db.admin.query('UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1', [s.device.device_id]); };
    try { const response = await post(s, reserveAssetPath, s.reserve); const body = await response.json(); assert.equal(body.code, 'NOT_AUTHORIZED'); assert.ok(!JSON.stringify(body).includes('upload_url')); }
    finally { afterSign = undefined; }
    assert.equal((await snapshot(s)).bindings, 1);
  });
  await t.test('concurrent duplicate reserve/verify/report commit each once', async () => {
    const s = await setup(); concurrent = true;
    try {
      const reservations = await Promise.all([ok(s, reserveAssetPath, s.reserve), ok(s, reserveAssetPath, s.reserve)]); assert.equal(reservations[0].data.asset_id, reservations[1].data.asset_id);
      const a = await reserved(s); await Promise.all([ok(s, verifyAssetPath, a.verify), ok(s, verifyAssetPath, a.verify)]);
      const reports = await Promise.all([ok(s, reportIssuePath, s.report), ok(s, reportIssuePath, s.report)]); assert.deepEqual(reports[0], reports[1]);
      const saved = await snapshot(s); assert.equal(saved.assets, 1); assert.equal(saved.bindings, 1); assert.equal(saved.issues, 1); assert.equal(saved.events, 4);
    } finally { concurrent = false; }
  });
  for (const phase of ['reserve', 'report'] as const) await t.test(phase + ' SQL failure rolls back all operational writes', async () => {
    const s = await setup(); if (phase === 'report') await verified(s); const before = await snapshot(s), signs = signing;
    await db.admin.query(`CREATE FUNCTION rounds.pickup_photo_test_fail() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.tenant_id='${s.ids.tenant}'::uuid THEN RAISE EXCEPTION 'injected rollback'; END IF; RETURN NEW; END $$;
      CREATE TRIGGER pickup_photo_test_fail BEFORE INSERT ON rounds.outbox_events FOR EACH ROW EXECUTE FUNCTION rounds.pickup_photo_test_fail()`);
    try {
      const r = await post(s, phase === 'reserve' ? reserveAssetPath : reportIssuePath, phase === 'reserve' ? s.reserve : s.report); assert.equal(r.status, 503);
      assert.deepEqual(await snapshot(s), before); if (phase === 'reserve') assert.equal(signing, signs);
      assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.command_receipts WHERE command_key=$1', [phase === 'reserve' ? s.reserve.command_id : s.report.command_id])).rows[0].n, 0);
    } finally { await db.admin.query('DROP TRIGGER pickup_photo_test_fail ON rounds.outbox_events; DROP FUNCTION rounds.pickup_photo_test_fail()'); }
    await ok(s, phase === 'reserve' ? reserveAssetPath : reportIssuePath, phase === 'reserve' ? s.reserve : s.report);
  });
  await t.test('migration preserves old photo and never invents binding; new binding immutable with forced RLS', async () => {
    assert.equal((await db.admin.query('SELECT object_key FROM rounds.assets WHERE id=$1', [oldAsset!])).rows[0].object_key, 'legacy-untouched');
    assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.pickup_issue_asset_bindings WHERE tenant_id=$1', [oldTenant!])).rows[0].n, 0);
    const s = await setup(), a = await reserved(s);
    await assert.rejects(db.admin.query('UPDATE rounds.pickup_issue_asset_bindings SET observation_id=$2 WHERE asset_id=$1', [a.id, randomUUID()]), /IMMUTABLE_RECORD/);
    await assert.rejects(db.admin.query('DELETE FROM rounds.pickup_issue_asset_bindings WHERE asset_id=$1', [a.id]), /IMMUTABLE_RECORD/);
    const policy = (await db.admin.query(`SELECT relrowsecurity,relforcerowsecurity FROM pg_class WHERE oid='rounds.pickup_issue_asset_bindings'::regclass`)).rows[0];
    assert.deepEqual(policy, { relrowsecurity: true, relforcerowsecurity: true });
  });
});
