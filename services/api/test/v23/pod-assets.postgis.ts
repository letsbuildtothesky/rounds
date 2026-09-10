import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { test } from 'node:test';
import sharp from 'sharp';
import { createPickupHttp, pickupPath, arrivalPath, handoffPath, statusPath } from '../../src/v23/pickup-http.js';
import { createPodAssets, reserveAssetPath, verifyAssetPath, type PodObjectStore, type PodUpload } from '../../src/v23/pod-assets.js';
import { createDeviceRegistrationHttp } from '../../src/v23/device-registration-http.js';
import { deviceSessions } from '../../src/v23/device-session.js';
import { CommandRejection } from '../../src/v23/transaction-runner.js';
import { podHash } from '../../src/v23/pod-byte-verification.js';
import { submitProofPath, completeDeliveryPath } from '../../src/v23/complete-local-delivery.js';
import { createDriverExecutionHttp, driverRoundPath } from '../../src/v23/driver-execution-query.js';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';
import { createSupabasePodStorage } from '../../src/v23/supabase-pod-storage.js';
import { supabaseStorageFixture } from './supabase-storage-fixture.js';
import type { Wire_ReserveAssetRequest, Wire_VerifyAssetRequest, Wire_SubmitProofRequest, Wire_CompleteDeliveryRequest, Wire_proof_ref, Wire_ProofPolicy } from '../../../../packages/contracts/src/v23/pickup-wire.js';
// Synthetic Auth and private storage provider, real image bytes/decoder and
// registered HTTP command chain on an actual restricted PostGIS connection.
test('POD reservation and actual byte verification on isolated own-team work', { timeout: 120000 }, async (t) => {
    const db = await startPostgisFixture();
    t.after(() => db.close());
    const subjects = new Map<string, string>(), objects = new Map<string, Buffer>(), caps = new Map<string, PodUpload>();
    let reads = 0, signs = 0, seals = 0, failSign = false, failSeal = false, corruptSeal = false, concurrent = false;
    let beforeSeal: (() => Promise<void>) | undefined, afterSign: (() => Promise<void>) | undefined;
    const png = await sharp({ create: { width: 4, height: 4, channels: 3, background: '#168048' } }).png().toBuffer();
    const jpeg = await sharp(png).jpeg().toBuffer();
    async function outsideTransaction() {
        if (concurrent)
            return; // Other requests may legitimately hold their own locks.
        const busy = await db.admin.query(`SELECT count(*)::int n FROM pg_stat_activity WHERE usename='fixture_login' AND state='idle in transaction'`);
        assert.equal(busy.rows[0].n, 0, 'no provider IO while a database transaction is held');
    }
    const storage: PodObjectStore = {
        async issueUpload(upload) {
            await outsideTransaction();
            signs++;
            if (failSign)
                throw new Error('Provider unavailable');
            const token = randomUUID();
            caps.set(token, { ...upload });
            await afterSign?.();
            // Provider-added fields must not replace our server-owned asset ID.
            return { asset_id: randomUUID(), upload_url: `https://storage.invalid/${token}`, upload_token: token, expires_at: new Date(Date.now() + 240000).toISOString(), upload_method: 'PUT' };
        },
        async read(key) {
            await outsideTransaction();
            reads++;
            const bytes = objects.get(key);
            if (!bytes)
                throw new Error('Object unavailable');
            return (async function* () { yield Buffer.from(bytes); })();
        },
        async seal(key, bytes) {
            await outsideTransaction();
            seals++;
            await beforeSeal?.();
            if (failSeal)
                throw new Error('Provider unavailable');
            assert.ok(!objects.has(key));
            objects.set(key, corruptSeal ? Buffer.alloc(bytes.length) : Buffer.from(bytes));
        }
    };
    const options = { pool: db.pool, origin: 'http://localhost:3000', devices: deviceSessions({ id: 'asset-test', secret: randomBytes(32) }),
        verifyBearer: async (token: string) => {
            const subject = subjects.get(token);
            if (!subject)
                throw new CommandRejection('UNAUTHENTICATED');
            return subject;
        } };
    const http = createPickupHttp({ ...options, assets: createPodAssets(db.pool, storage, 'isolated-test-pod') }), enroll = createDeviceRegistrationHttp(options);
    const post = (path: string, headers: Record<string, string>, body: unknown) => http(new Request('http://rounds.internal' + path, { method: 'POST', headers, body: JSON.stringify(body) }));
    async function successful(path: string, headers: Record<string, string>, body: unknown) { const r = await post(path, headers, body); assert.equal(r.status, 200, JSON.stringify(await r.clone().json())); return r.json(); }
    async function setup(policy: Wire_ProofPolicy = { kind: 'proof', recipient_required: ['photo'], alternate_required: ['photo', 'receiver'], unattended_required: ['photo', 'note'], unattended_allowed: true, gps_override_allowed: false }) {
        const ids = await seedWholeOrder(db.admin, policy);
        const receiver = randomUUID();
        await db.admin.query(`INSERT INTO rounds.delivery_contacts(id,tenant_id,delivery_id,role,display_name,notification_permissions) VALUES($1,$2,$3,'recipient','Johannes test receiver','{}')`, [receiver, ids.tenant, ids.delivery]);
        const subject = randomUUID(), token = randomUUID();
        subjects.set(token, subject);
        await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1', [ids.actor, subject]);
        await db.admin.query(`UPDATE rounds.stops SET state='released' WHERE id=$1`, [ids.pickup]);
        await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`, [ids.tenant, ids.delivery, ids.round, ids.unit]);
        const registered = await enroll(new Request('http://rounds.internal/v1/auth/driver-device/session', { method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, body: JSON.stringify({ installation_secret: randomBytes(32).toString('hex'), platform: 'android' }) }));
        assert.equal(registered.status, 200);
        const device = await registered.json();
        const headers = { authorization: `Bearer ${token}`, 'x-rounds-device-session': device.device_session, 'content-type': 'application/json' };
        const context = { tenant_id: ids.tenant!, city_id: ids.city! }, fence = { assignment_id: ids.assignment!, assignment_version: 1, observation_id: randomUUID() };
        const base = { command_id: randomUUID(), context, occurred_at: '2026-09-09T00:00:00Z', execution_fence: fence };
        const arrived = await successful(arrivalPath, headers, { ...base, expected_versions: [{ aggregate_type: 'stops', id: ids.pickup, version: 1 }], payload: { stop_id: ids.pickup, point: { longitude: 100.5, latitude: 13.7 }, accuracy_m: 8 } });
        const pickup = await successful(pickupPath, headers, { ...base, command_id: randomUUID(), occurred_at: '2026-09-09T00:01:00Z', execution_fence: { ...fence, observation_id: randomUUID() },
            expected_versions: [{ aggregate_type: 'rounds', id: ids.round, version: 1 }, arrived.current_versions.find((v: any) => v.aggregate_type === 'stops'), { aggregate_type: 'manifests', id: ids.manifest, version: 1 }, { aggregate_type: 'fulfillment_units', id: ids.unit, version: 1 }],
            payload: { round_id: ids.round, pickup_stop_id: ids.pickup, manifest_ids: [ids.manifest], fulfillment_unit_ids: [ids.unit], quantities: [{ line_id: ids.line, quantity: 5 }] } });
        const attempt = pickup.data.attempts.find((a: any) => a.fulfillment_unit_id === ids.unit).id;
        const dropoff = await successful(arrivalPath, headers, { ...base, command_id: randomUUID(), occurred_at: '2026-09-09T00:02:00Z', execution_fence: { ...fence, observation_id: randomUUID() }, expected_versions: [{ aggregate_type: 'stops', id: ids.dropoff, version: 1 }], payload: { stop_id: ids.dropoff, point: { longitude: 100.5, latitude: 13.7 }, accuracy_m: 8 } });
        const handoff = await successful(handoffPath, headers, { ...base, command_id: randomUUID(), occurred_at: '2026-09-09T00:03:00Z', execution_fence: { ...fence, observation_id: randomUUID() }, expected_versions: [dropoff.current_versions.find((v: any) => v.aggregate_type === 'delivery_attempts')], payload: { attempt_id: attempt, receiver_kind: 'recipient', receiver_contact_id: receiver, quantities: [{ line_id: ids.line, quantity: 5 }] } });
        const r: Wire_ReserveAssetRequest = { command_id: randomUUID(), context, occurred_at: '2026-09-09T00:04:00Z', expected_versions: [], payload: { kind: 'delivery_photo', mime_type: 'image/png', byte_size: png.length, sha256: podHash(png), purpose_entity_id: handoff.data.handoff_id } };
        return { ids, headers, device, r, attempt, receiver, handoff: handoff.data.handoff_id, handoffResult: handoff, dropoffResult: dropoff };
    }
    type Scenario = Awaited<ReturnType<typeof setup>>;
    async function reserve(s: Scenario, bytes = png, mime = 'image/png') {
        s.r.payload = { ...s.r.payload, mime_type: mime, byte_size: bytes.length, sha256: podHash(bytes) };
        const result = await successful(reserveAssetPath, s.headers, s.r), upload = caps.get(result.data.upload_token)!;
        assert.ok(upload);
        // Emulate the provider upload, not the application's verification verdict.
        objects.set(upload.key, Buffer.from(bytes));
        const r: Wire_VerifyAssetRequest = { command_id: randomUUID(), context: s.r.context, occurred_at: '2026-09-09T00:05:00Z', expected_versions: [{ aggregate_type: 'assets', id: result.data.asset_id, version: 1 }], payload: { asset_id: result.data.asset_id, sha256: s.r.payload.sha256 } };
        return { result, upload, r };
    }
    const state = async (id: string) => (await db.admin.query('SELECT state,object_key,version,verified_at FROM rounds.assets WHERE id=$1', [id])).rows[0];
    const status = (s: Scenario, id: string) => http(new Request(`http://rounds.internal${statusPath}?entity_id=${id}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}`, { headers: s.headers }));
    async function error(response: Promise<Response>, code: string) { const r = await response; assert.equal((await r.json()).code, code); }
    function proofRequest(s: Scenario, evidence: Wire_proof_ref[], predecessor = s.handoffResult): Wire_SubmitProofRequest {
        return { command_id: randomUUID(), context: s.r.context, occurred_at: '2026-09-09T00:06:00Z', execution_fence: { assignment_id: s.ids.assignment!, assignment_version: 1, observation_id: randomUUID() }, expected_versions: [predecessor.current_versions.find((v: any) => v.aggregate_type === 'delivery_attempts')], payload: { attempt_id: s.attempt, handoff_id: s.handoff, policy_version_id: s.ids.policy!, evidence } };
    }
    function completeRequest(s: Scenario, proof: any): Wire_CompleteDeliveryRequest {
        return { command_id: randomUUID(), context: s.r.context, occurred_at: '2026-09-09T00:07:00Z', execution_fence: { assignment_id: s.ids.assignment!, assignment_version: 1, observation_id: randomUUID() }, expected_versions: [proof.current_versions.find((v: any) => v.aggregate_type === 'delivery_attempts')], payload: { attempt_id: s.attempt, proof_submission_id: proof.data.resource.id } };
    }
    async function evidence(s: Scenario) { const a = await reserve(s); await successful(verifyAssetPath, s.headers, a.r); return { kind: 'photo', asset_id: a.r.payload.asset_id } as Wire_proof_ref; }
    async function submitted(s: Scenario) { const ref = await evidence(s), r = proofRequest(s, [ref]); return { ref, r, proof: await successful(submitProofPath, s.headers, r) }; }
    async function snapshot(s: Scenario) {
        return (await db.admin.query(`SELECT
      (SELECT state FROM rounds.delivery_attempts WHERE id=$1) attempt,
      (SELECT state FROM rounds.stops WHERE id=$2) stop,
      (SELECT outcome FROM rounds.deliveries WHERE id=$3) delivery,
      (SELECT evidence_state FROM rounds.deliveries WHERE id=$3) evidence,
      (SELECT state FROM rounds.fulfillment_units WHERE id=$4) unit,
      (SELECT state FROM rounds.rounds WHERE id=$5) round,
      (SELECT state FROM rounds.assignments WHERE id=$6) assignment,
      (SELECT count(*)::int FROM rounds.active_delivery_claims WHERE round_id=$5 AND archived_at IS NULL) claims,
      (SELECT delivered_quantity FROM rounds.fulfillment_unit_lines WHERE unit_id=$4) delivered`, [s.attempt, s.ids.dropoff, s.ids.delivery, s.ids.unit, s.ids.round, s.ids.assignment])).rows[0];
    }
    await t.test('restricted command chain uses the Supabase REST adapter and signed PUT gateway before proof/completion', async () => {
        const s = await setup(), provider = supabaseStorageFixture();
        provider.intercept(async () => { await outsideTransaction(); return undefined; });
        const storage = createSupabasePodStorage(provider.config, provider.fetcher);
        const wired = createPickupHttp({ ...options, assets: createPodAssets(db.pool, storage.store, 'isolated-test-pod') });
        async function command(path: string, request: unknown) {
            const response = await wired(new Request('http://rounds.internal' + path, { method: 'POST', headers: s.headers, body: JSON.stringify(request) }));
            assert.equal(response.status, 200, JSON.stringify(await response.clone().json())); return response.json();
        }
        const reserved = await command(reserveAssetPath, s.r);
        assert.equal(reserved.data.upload_token, null);
        const uploaded = await storage.upload(new Request(reserved.data.upload_url, { method: 'PUT', headers: { 'content-type': 'image/png' }, body: png }));
        assert.equal(uploaded.status, 204);
        const verified = await command(verifyAssetPath, { command_id: randomUUID(), context: s.r.context, occurred_at: '2026-09-09T00:05:00Z',
            expected_versions: reserved.resources, payload: { asset_id: reserved.data.asset_id, sha256: podHash(png) } });
        assert.equal(verified.data.state, 'verified');
        const proof = await command(submitProofPath, proofRequest(s, [{ kind: 'photo', asset_id: reserved.data.asset_id }]));
        assert.equal((await snapshot(s)).delivery, 'open');
        await command(completeDeliveryPath, completeRequest(s, proof));
        assert.equal((await snapshot(s)).delivery, 'delivered');
        const receipt = JSON.stringify((await db.admin.query('SELECT result FROM rounds.command_receipts WHERE actor_id=$1', [s.ids.actor])).rows);
        assert.ok(!receipt.includes('cap=') && !receipt.includes(provider.config.serviceKey) && !receipt.includes(provider.config.uploadOrigin));
        assert.equal(provider.objects.size, 2, 'staging and separately sealed evidence remain retained');
    });
    await t.test('actual handoff -> verified photo -> pending proof -> atomic complete and receipt replay after closure', async () => {
        const s = await setup(), commitment = randomUUID();
        await db.admin.query(`INSERT INTO rounds.driver_commitments(id,driver_id,tenant_id,round_id,busy_range,state) VALUES($1,$2,$3,$4,tstzrange(now(),now()+interval '1 hour','[)'),'committed')`, [commitment, s.ids.driver, s.ids.tenant, s.ids.round]);
        const { r, proof } = await submitted(s);
        assert.equal((await snapshot(s)).delivery, 'open');
        assert.equal((await snapshot(s)).evidence, 'pending');
        const complete = completeRequest(s, proof), result = await successful(completeDeliveryPath, s.headers, complete);
        assert.deepEqual(await snapshot(s), { attempt: 'completed', stop: 'completed', delivery: 'delivered', evidence: 'complete', unit: 'delivered', round: 'completed', assignment: 'completed', claims: 0, delivered: '5.0000' });
        assert.equal((await db.admin.query('SELECT state FROM rounds.driver_commitments WHERE id=$1', [commitment])).rows[0].state, 'completed');
        assert.deepEqual(await successful(completeDeliveryPath, s.headers, complete), result);
        assert.deepEqual(await successful(submitProofPath, s.headers, r), proof);
        assert.deepEqual((await (await status(s, complete.command_id)).json()).data.result, result);
        assert.deepEqual((await db.admin.query(`SELECT event_type FROM rounds.domain_events WHERE command_id=$1 ORDER BY event_type`, [complete.command_id])).rows.map(x => x.event_type), ['delivery.completed', 'fulfillment.completed', 'round.completed']);
        assert.equal((await db.admin.query(`SELECT count(*)::int n FROM rounds.proof_submissions WHERE tenant_id=$1 AND state='complete'`, [s.ids.tenant])).rows[0].n, 1);
        assert.equal((await db.admin.query(`SELECT count(*)::int n FROM rounds.outbox_events WHERE tenant_id=$1 AND destination<>'audit_realtime'`, [s.ids.tenant])).rows[0].n, 0);
    });
    await t.test('incomplete proof remains pending; genuine new complete submission preserves old candidate', async () => {
        const s = await setup(), empty = await successful(submitProofPath, s.headers, proofRequest(s, []));
        const before = await snapshot(s);
        await error(post(completeDeliveryPath, s.headers, completeRequest(s, empty)), 'PROOF_INCOMPLETE');
        assert.deepEqual(await snapshot(s), before);
        const ref = await evidence(s), full = await successful(submitProofPath, s.headers, proofRequest(s, [ref], empty));
        await successful(completeDeliveryPath, s.headers, completeRequest(s, full));
        assert.equal((await db.admin.query('SELECT state FROM rounds.proof_submissions WHERE id=$1', [empty.data.resource.id])).rows[0].state, 'pending');
        assert.equal((await snapshot(s)).round, 'completed');
    });
    await t.test('all six required proof kinds persist exact note and actual arrival reference', async () => {
        const kinds: Wire_proof_ref['kind'][] = ['photo', 'signature', 'manifest', 'receiver', 'note', 'location'];
        const s = await setup({ kind: 'proof', recipient_required: kinds, alternate_required: kinds, unattended_required: ['photo', 'note', 'location'], unattended_allowed: true, gps_override_allowed: false }), photo = await evidence(s);
        s.r = { ...s.r, command_id: randomUUID(), payload: { ...s.r.payload, kind: 'signature' } };
        const signature = await reserve(s);
        await successful(verifyAssetPath, s.headers, signature.r);
        const location = s.dropoffResult.resources.find((v: any) => v.aggregate_type === 'location_observations').id;
        const refs: Wire_proof_ref[] = [photo, { kind: 'signature', asset_id: signature.r.payload.asset_id }, { kind: 'manifest', line_id: s.ids.line!, quantity: 5 }, { kind: 'receiver', receiver_contact_id: s.receiver }, { kind: 'note', note: '  Left with Johannes.  ' }, { kind: 'location', location_observation_id: location }];
        const proof = await successful(submitProofPath, s.headers, proofRequest(s, refs));
        await successful(completeDeliveryPath, s.headers, completeRequest(s, proof));
        const items = (await db.admin.query('SELECT item_kind,state,note,location_observation_id FROM rounds.proof_items WHERE submission_id=$1', [proof.data.resource.id])).rows;
        assert.equal(items.length, 6);
        assert.ok(items.every(i => i.state === 'verified'));
        assert.equal(items.find(i => i.item_kind === 'note').note, '  Left with Johannes.  ');
        assert.equal(items.find(i => i.item_kind === 'location').location_observation_id, location);
    });
    await t.test('unverified and foreign photo references cannot create submission', async () => {
        const s = await setup(), a = await reserve(s);
        await error(post(submitProofPath, s.headers, proofRequest(s, [{ kind: 'photo', asset_id: a.r.payload.asset_id }])), 'ASSET_NOT_VERIFIED');
        const other = await setup(), ref = await evidence(other);
        await error(post(submitProofPath, s.headers, proofRequest(s, [ref])), 'NOT_AUTHORIZED');
        assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.proof_submissions WHERE tenant_id=$1', [s.ids.tenant])).rows[0].n, 0);
    });
    for (const [label, refs, code] of [
        ['duplicate photos', [{ kind: 'photo', asset_id: '00000000-0000-4000-8000-000000000001' }, { kind: 'photo', asset_id: '00000000-0000-4000-8000-000000000001' }], 'VALIDATION_FAILED'],
        ['blank note', [{ kind: 'note', note: '   ' }], 'VALIDATION_FAILED'],
        ['unrelated proof fields', [{ kind: 'note', note: 'test', asset_id: '00000000-0000-4000-8000-000000000001' }], 'VALIDATION_FAILED'],
        ['unbound location', [{ kind: 'location', location_observation_id: '00000000-0000-4000-8000-000000000001' }], 'NOT_AUTHORIZED'],
    ] as const)
        await t.test(label, async () => { const s = await setup(); await error(post(submitProofPath, s.headers, proofRequest(s, refs as unknown as Wire_proof_ref[])), code); });
    for (const [label, mutate, code] of [
        ['wrong handoff', (r: Wire_SubmitProofRequest) => r.payload.handoff_id = randomUUID(), 'NOT_AUTHORIZED'],
        ['wrong policy', (r: Wire_SubmitProofRequest) => r.payload.policy_version_id = randomUUID(), 'NOT_AUTHORIZED'],
        ['wrong assignment', (r: Wire_SubmitProofRequest) => r.execution_fence.assignment_id = randomUUID(), 'NOT_AUTHORIZED'],
        ['wrong city', (r: Wire_SubmitProofRequest) => r.context.city_id = randomUUID(), 'NOT_AUTHORIZED'],
        ['stale root', (r: Wire_SubmitProofRequest) => r.expected_versions[0]!.version = 999, 'STALE_VERSION'],
    ] as const)
        await t.test(label + ' proof', async () => { const s = await setup(), r = proofRequest(s, [await evidence(s)]); mutate(r); await error(post(submitProofPath, s.headers, r), code); assert.equal((await snapshot(s)).delivery, 'open'); });
    for (const [label, sql, args, code] of [
        ['invalidated proof item', `UPDATE rounds.proof_items SET state='invalidated',invalidated_at=now() WHERE submission_id=$1`, (s: Scenario, p: any) => [p.data.resource.id], 'EVIDENCE_PENDING'],
        ['changed assignment', `UPDATE rounds.assignments SET version=version+1 WHERE id=$1`, (s: Scenario) => [s.ids.assignment], 'EXECUTION_FENCE_CHANGED'],
        ['revoked device', `UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1`, (s: Scenario) => [s.device.device_id], 'NOT_AUTHORIZED'],
        ['revoked membership', `UPDATE rounds.memberships SET status='suspended' WHERE id=$1`, (s: Scenario) => [s.ids.membership], 'NOT_AUTHORIZED'],
    ] as const)
        await t.test(label + ' prevents completion', async () => { const s = await setup(), { proof } = await submitted(s); await db.admin.query(sql, args(s, proof)); const before = await snapshot(s); await error(post(completeDeliveryPath, s.headers, completeRequest(s, proof)), code); assert.deepEqual(await snapshot(s), before); });
    await t.test('database forbids shortening the collected allocation', async () => { const s = await setup(), { proof } = await submitted(s); await assert.rejects(db.admin.query('UPDATE rounds.fulfillment_unit_lines SET allocated_quantity=4 WHERE unit_id=$1', [s.ids.unit]), /IMMUTABLE_RECORD/); await successful(completeDeliveryPath, s.headers, completeRequest(s, proof)); assert.equal((await snapshot(s)).delivered, '5.0000'); });
    await t.test('pending return duty keeps Round open without inventing a receipt', async () => { const s = await setup(), id = randomUUID(); await db.admin.query(`INSERT INTO rounds.return_tasks(id,tenant_id,delivery_id,manifest_id,round_id,destination_site_id,state,receiver_id) VALUES($1,$2,$3,$4,$5,$6,'planned',$7)`, [id, s.ids.tenant, s.ids.delivery, s.ids.manifest, s.ids.round, s.ids.site, s.ids.actor]); const { proof } = await submitted(s); await successful(completeDeliveryPath, s.headers, completeRequest(s, proof)); assert.equal((await snapshot(s)).round, 'active'); assert.equal((await snapshot(s)).delivery, 'delivered'); assert.equal((await db.admin.query('SELECT state FROM rounds.return_tasks WHERE id=$1', [id])).rows[0].state, 'planned'); });
    await t.test('receiver correction invalidates submitted signature at completion, without deleting photo', async () => {
        const s = await setup(), photo = await evidence(s);
        s.r = { ...s.r, command_id: randomUUID(), payload: { ...s.r.payload, kind: 'signature' } };
        const a = await reserve(s);
        await successful(verifyAssetPath, s.headers, a.r);
        const proof = await successful(submitProofPath, s.headers, proofRequest(s, [photo, { kind: 'signature', asset_id: a.r.payload.asset_id }]));
        const contact = randomUUID();
        await db.admin.query(`INSERT INTO rounds.delivery_contacts(id,tenant_id,delivery_id,role,display_name,notification_permissions) VALUES($1,$2,$3,'recipient','Changed test receiver','{}')`, [contact, s.ids.tenant, s.ids.delivery]);
        await db.admin.query('UPDATE rounds.handoffs SET receiver_contact_id=$2 WHERE id=$1', [s.handoff, contact]);
        await error(post(completeDeliveryPath, s.headers, completeRequest(s, proof)), 'NOT_AUTHORIZED');
        assert.equal((await state(photo.asset_id!)).state, 'verified');
        assert.equal((await snapshot(s)).delivery, 'open');
    });
    await t.test('own-team commitment privilege is scoped and cannot create or rewrite reservations', async () => {
        const s = await setup(), other = await setup(), id = randomUUID();
        await db.admin.query(`INSERT INTO rounds.driver_commitments(id,driver_id,tenant_id,round_id,busy_range,state) VALUES($1,$2,$3,$4,tstzrange(now(),now()+interval '1 hour','[)'),'committed')`, [id, s.ids.driver, s.ids.tenant, s.ids.round]);
        const c = await db.pool.connect();
        async function begin(tenant = s.ids.tenant, actor = s.ids.actor, city = s.ids.city) { await c.query('BEGIN'); await c.query('SET LOCAL ROLE rounds_api'); await c.query("SELECT set_config('rounds.tenant_id',$1,true),set_config('rounds.principal_id',$2,true),set_config('rounds.city_id',$3,true)", [tenant, actor, city]); }
        try {
            for (const [tenant, actor, city] of [[other.ids.tenant, s.ids.actor, s.ids.city], [s.ids.tenant, other.ids.actor, s.ids.city], [s.ids.tenant, s.ids.actor, s.ids.otherCity]]) {
                await begin(tenant, actor, city);
                assert.equal((await c.query('SELECT id FROM rounds.driver_commitments WHERE id=$1', [id])).rowCount, 0);
                await c.query('ROLLBACK');
            }
            await begin();
            assert.equal((await c.query('SELECT id FROM rounds.driver_commitments WHERE id=$1', [id])).rowCount, 1);
            assert.equal((await c.query("UPDATE rounds.driver_commitments SET state='completed' WHERE id=$1", [id])).rowCount, 0);
            await c.query('ROLLBACK');
            await begin();
            await assert.rejects(c.query("UPDATE rounds.driver_commitments SET busy_range=tstzrange(now(),now()+interval '2 hours','[)') WHERE id=$1", [id]), /permission denied/);
            await c.query('ROLLBACK');
            await begin();
            await assert.rejects(c.query('DELETE FROM rounds.driver_commitments WHERE id=$1', [id]), /permission denied/);
            await c.query('ROLLBACK');
            await begin();
            await assert.rejects(c.query(`INSERT INTO rounds.driver_commitments(driver_id,tenant_id,round_id,busy_range,state) VALUES($1,$2,$3,tstzrange(now(),now()+interval '1 hour','[)'),'pending')`, [s.ids.driver, s.ids.tenant, s.ids.round]), /permission denied/);
            await c.query('ROLLBACK');
        }
        finally {
            c.release();
        }
    });
    await t.test('proof outbox failure rolls back all completion writes and original ID can retry', async () => {
        const s = await setup(), { proof } = await submitted(s), r = completeRequest(s, proof), before = await snapshot(s);
        await db.admin.query(`CREATE FUNCTION rounds.test_complete_fail() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.tenant_id='${s.ids.tenant}'::uuid THEN RAISE EXCEPTION 'injected completion outbox failure'; END IF; RETURN NEW; END $$; CREATE TRIGGER test_complete_fail BEFORE INSERT ON rounds.outbox_events FOR EACH ROW EXECUTE FUNCTION rounds.test_complete_fail()`);
        try {
            await error(post(completeDeliveryPath, s.headers, r), 'PROVIDER_UNAVAILABLE');
            assert.deepEqual(await snapshot(s), before);
            assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.domain_events WHERE command_id=$1', [r.command_id])).rows[0].n, 0);
            assert.equal((await db.admin.query('SELECT state FROM rounds.proof_submissions WHERE id=$1', [proof.data.resource.id])).rows[0].state, 'pending');
        }
        finally {
            await db.admin.query('DROP TRIGGER test_complete_fail ON rounds.outbox_events; DROP FUNCTION rounds.test_complete_fail()');
        }
        await successful(completeDeliveryPath, s.headers, r);
    });
    for (const stage of ['submit', 'complete'])
        await t.test(stage + ' same-ID concurrency commits only once', async () => {
            const s = await setup(), r = stage === 'submit' ? proofRequest(s, [await evidence(s)]) : completeRequest(s, (await submitted(s)).proof), path = stage === 'submit' ? submitProofPath : completeDeliveryPath;
            const results = await Promise.all([successful(path, s.headers, r), successful(path, s.headers, r)]);
            assert.deepEqual(results[0], results[1]);
            assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.command_receipts WHERE command_key=$1 AND state=\'committed\'', [r.command_id])).rows[0].n, 1);
        });
    await t.test('competing completion IDs cannot complete the same whole order twice', async () => { const s = await setup(), { proof } = await submitted(s), r = completeRequest(s, proof); const responses = await Promise.all([post(completeDeliveryPath, s.headers, r), post(completeDeliveryPath, s.headers, { ...r, command_id: randomUUID() })]); assert.equal(responses.filter(x => x.status === 200).length, 1); assert.equal((await db.admin.query(`SELECT count(*)::int n FROM rounds.domain_events WHERE tenant_id=$1 AND event_type='delivery.completed'`, [s.ids.tenant])).rows[0].n, 1); });
    await t.test('unfinished second order keeps Round active and driver execution query accessible', async () => {
        const s = await setup(), ids = Object.fromEntries(['delivery', 'manifest', 'line', 'unit', 'dropoff'].map(k => [k, randomUUID()]));
        await db.admin.query(`INSERT INTO rounds.deliveries(id,tenant_id,city_id,pickup_site_id,human_reference,service_date,timezone,window_start_at,window_end_at,address_text,destination,readiness,outcome,evidence_state,proof_policy_id,created_by,preparation_state) SELECT $1,tenant_id,city_id,pickup_site_id,'SECOND-TEST',service_date,timezone,window_start_at,window_end_at,address_text,destination,readiness,outcome,evidence_state,proof_policy_id,created_by,preparation_state FROM rounds.deliveries WHERE id=$2`, [ids.delivery, s.ids.delivery]);
        await db.admin.query(`INSERT INTO rounds.manifests(id,tenant_id,delivery_id,revision,source) VALUES($1,$2,$3,1,'manual')`, [ids.manifest, s.ids.tenant, ids.delivery]);
        await db.admin.query(`INSERT INTO rounds.manifest_lines(id,tenant_id,manifest_id,line_key,label,quantity,unit) VALUES($1,$2,$3,'SECOND','Second test order',2,'item')`, [ids.line, s.ids.tenant, ids.manifest]);
        await db.admin.query(`INSERT INTO rounds.fulfillment_units(id,tenant_id,delivery_id,manifest_id,state) VALUES($1,$2,$3,$4,'open')`, [ids.unit, s.ids.tenant, ids.delivery, ids.manifest]);
        await db.admin.query(`INSERT INTO rounds.fulfillment_unit_lines(tenant_id,unit_id,line_id,allocated_quantity) VALUES($1,$2,$3,2)`, [s.ids.tenant, ids.unit, ids.line]);
        await db.admin.query(`UPDATE rounds.deliveries SET current_manifest_id=$2 WHERE id=$1`, [ids.delivery, ids.manifest]);
        await db.admin.query(`INSERT INTO rounds.stops(id,tenant_id,round_id,delivery_id,fulfillment_unit_id,kind,sequence,destination_version,state,service_seconds) VALUES($1,$2,$3,$4,$5,'dropoff',2,1,'released',60)`, [ids.dropoff, s.ids.tenant, s.ids.round, ids.delivery, ids.unit]);
        await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`, [s.ids.tenant, ids.delivery, s.ids.round, ids.unit]);
        const query = () => createDriverExecutionHttp(options)(new Request(`http://rounds.internal${driverRoundPath}?entity_id=${s.ids.round}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}&view=execution`, { headers: s.headers }));
        const before = await query();
        assert.equal(before.status, 200);
        const hash = (await before.json()).data.context.accepted_scope_hash;
        const { proof } = await submitted(s);
        await successful(completeDeliveryPath, s.headers, completeRequest(s, proof));
        assert.equal((await snapshot(s)).round, 'active');
        assert.equal((await snapshot(s)).delivery, 'delivered');
        const after = await query();
        assert.equal(after.status, 200, JSON.stringify(await after.clone().json()));
        assert.equal((await after.json()).data.context.accepted_scope_hash, hash);
    });
    await t.test('pending commitment prevents Round closure and proof content cannot be rewritten', async () => {
        const s = await setup(), id = randomUUID();
        await db.admin.query(`INSERT INTO rounds.driver_commitments(id,driver_id,tenant_id,round_id,busy_range,state) VALUES($1,$2,$3,$4,tstzrange(now(),now()+interval '1 hour','[)'),'pending')`, [id, s.ids.driver, s.ids.tenant, s.ids.round]);
        const { proof } = await submitted(s);
        await assert.rejects(db.admin.query(`UPDATE rounds.proof_items SET note='replacement' WHERE submission_id=$1`, [proof.data.resource.id]), /IMMUTABLE_RECORD/);
        await successful(completeDeliveryPath, s.headers, completeRequest(s, proof));
        assert.equal((await snapshot(s)).round, 'active');
        assert.equal((await snapshot(s)).delivery, 'delivered');
    });
    await t.test('reserve replay/status signs fresh capability without replacing identity; receipt/event never store it', async () => {
        const s = await setup(), a = await reserve(s), b = await successful(reserveAssetPath, s.headers, s.r), c = await status(s, s.r.command_id);
        assert.equal(c.status, 200);
        const recovered = (await c.json()).data.result;
        assert.equal(b.data.asset_id, a.result.data.asset_id);
        assert.equal(recovered.data.asset_id, a.result.data.asset_id);
        assert.notEqual(b.data.upload_token, a.result.data.upload_token);
        assert.notEqual(recovered.data.upload_token, b.data.upload_token);
        const stored = await db.admin.query(`SELECT result FROM rounds.command_receipts WHERE command_key=$1`, [s.r.command_id]);
        assert.deepEqual(stored.rows[0].result.data, { asset_id: a.r.payload.asset_id });
        const events = await db.admin.query(`SELECT payload FROM rounds.domain_events WHERE command_id=$1`, [s.r.command_id]);
        assert.equal(events.rowCount, 1);
        for (const token of [a.result.data.upload_token, b.data.upload_token, recovered.data.upload_token])
            assert.ok(!JSON.stringify([stored.rows, events.rows]).includes(token));
        const binding = (await db.admin.query('SELECT * FROM rounds.pod_asset_bindings WHERE asset_id=$1', [a.r.payload.asset_id])).rows[0];
        assert.equal(binding.handoff_id, s.handoff);
        assert.equal(binding.attempt_id, s.attempt);
        assert.equal(binding.actor_id, s.ids.actor);
        assert.equal(binding.assignment_id, s.ids.assignment);
        assert.equal(binding.policy_version_id, s.ids.policy);
    });
    for (const [label, bytes, mime] of [['PNG', png, 'image/png'], ['JPEG', jpeg, 'image/jpeg']] as const)
        await t.test(label + ' full decoding commits one verified fact, not proof/completion', async () => {
            const s = await setup(), a = await reserve(s, bytes, mime);
            const before = reads;
            const result = await successful(verifyAssetPath, s.headers, a.r), again = await successful(verifyAssetPath, s.headers, a.r);
            assert.deepEqual(result, again);
            assert.equal(reads - before, 2);
            const stored = await state(a.r.payload.asset_id);
            assert.equal(stored.state, 'verified');
            assert.equal(stored.version, '2');
            assert.ok(stored.verified_at);
            assert.notEqual(stored.object_key, a.upload.key);
            assert.equal(podHash(objects.get(stored.object_key)!), a.r.payload.sha256);
            objects.set(a.upload.key, Buffer.from('late malicious overwrite'));
            assert.equal(podHash(objects.get(stored.object_key)!), a.r.payload.sha256);
            const recovered = await status(s, a.r.command_id);
            assert.deepEqual((await recovered.json()).data.result, result);
            const reserveReplay = await successful(reserveAssetPath, s.headers, s.r);
            assert.equal(caps.get(reserveReplay.data.upload_token)!.key, a.upload.key, 'replayed upload never writes the sealed key');
            const rows = (await db.admin.query(`SELECT (SELECT count(*)::int FROM rounds.domain_events WHERE command_id=$1) events,(SELECT count(*)::int FROM rounds.proof_submissions WHERE tenant_id=$2) proof,(SELECT outcome FROM rounds.deliveries WHERE id=$3) outcome,(SELECT state FROM rounds.rounds WHERE id=$4) round`, [a.r.command_id, s.ids.tenant, s.ids.delivery, s.ids.round])).rows[0];
            assert.deepEqual(rows, { events: 1, proof: 0, outcome: 'open', round: 'active' });
        });
    await t.test('signature retains handoff attribution without claiming signature authenticity', async () => { const s = await setup(); s.r.payload.kind = 'signature'; const a = await reserve(s); await successful(verifyAssetPath, s.headers, a.r); assert.equal((await db.admin.query('SELECT kind FROM rounds.assets WHERE id=$1', [a.r.payload.asset_id])).rows[0].kind, 'signature'); });
    for (const [label, mutate, code] of [
        ['unsupported general attachment', (r: Wire_ReserveAssetRequest) => { r.payload.kind = 'document'; }, 'FEATURE_NOT_ENABLED'],
        ['SVG active content', (r: Wire_ReserveAssetRequest) => { r.payload.mime_type = 'image/svg+xml'; }, 'VALIDATION_FAILED'],
        ['oversize', (r: Wire_ReserveAssetRequest) => { r.payload.byte_size = 21 * 1024 * 1024; }, 'VALIDATION_FAILED'],
        ['zero bytes', (r: Wire_ReserveAssetRequest) => { r.payload.byte_size = 0; }, 'VALIDATION_FAILED'],
        ['fraction bytes', (r: Wire_ReserveAssetRequest) => { r.payload.byte_size = 1.5; }, 'VALIDATION_FAILED'],
        ['invalid checksum', (r: Wire_ReserveAssetRequest) => { r.payload.sha256 = 'x'.repeat(64); }, 'VALIDATION_FAILED'],
        ['unknown purpose', (r: Wire_ReserveAssetRequest) => { r.payload.purpose_entity_id = randomUUID(); }, 'NOT_AUTHORIZED'],
        ['extra root', (r: Wire_ReserveAssetRequest) => { r.expected_versions = [{ aggregate_type: 'handoffs', id: r.payload.purpose_entity_id, version: 1 }]; }, 'VALIDATION_FAILED'],
        ['wrong city', (r: Wire_ReserveAssetRequest) => { r.context.city_id = randomUUID(); }, 'NOT_AUTHORIZED'],
    ] as const)
        await t.test(label, async () => { const s = await setup(); mutate(s.r); const before = signs; await error(post(reserveAssetPath, s.headers, s.r), code); assert.equal(signs, before); assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.assets WHERE tenant_id=$1', [s.ids.tenant])).rows[0].n, 0); });
    for (const [label, change] of [
        ['wrong actual hash', (a: any) => objects.set(a.upload.key, Buffer.alloc(png.length))],
        ['short upload', (a: any) => objects.set(a.upload.key, png.subarray(0, -1))],
        ['excess upload', (a: any) => objects.set(a.upload.key, Buffer.concat([png, Buffer.from([0])]))],
    ] as const)
        await t.test(label + ' produces no verification fact', async () => { const s = await setup(), a = await reserve(s); change(a); await error(post(verifyAssetPath, s.headers, a.r), 'ASSET_NOT_VERIFIED'); assert.equal((await state(a.r.payload.asset_id)).state, 'reserved'); assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.domain_events WHERE command_id=$1', [a.r.command_id])).rows[0].n, 0); });
    for (const [label, bytes, mime] of [['truncated PNG', png.subarray(0, 45), 'image/png'], ['mime spoof', png, 'image/jpeg'], ['HTML renamed PNG', Buffer.from('<script>unsafe()</script>'), 'image/png']] as const)
        await t.test(label + ' rejects even with matching client hash/size', async () => { const s = await setup(), a = await reserve(s, bytes, mime); await error(post(verifyAssetPath, s.headers, a.r), 'ASSET_NOT_VERIFIED'); assert.equal((await state(a.r.payload.asset_id)).state, 'reserved'); });
    await t.test('cross-tenant purpose and asset are denied before provider access', async () => { const s = await setup(), other = await setup(), a = await reserve(other); s.r.payload.purpose_entity_id = other.handoff; const before = reads; await error(post(reserveAssetPath, s.headers, s.r), 'NOT_AUTHORIZED'); a.r.context = s.r.context; await error(post(verifyAssetPath, s.headers, a.r), 'NOT_AUTHORIZED'); assert.equal(reads, before); });
    await t.test('changed request identity on replay conflicts', async () => { const s = await setup(), a = await reserve(s); s.r.payload.sha256 = '0'.repeat(64); await error(post(reserveAssetPath, s.headers, s.r), 'IDEMPOTENCY_CONFLICT'); await successful(verifyAssetPath, s.headers, a.r); a.r.payload.sha256 = '0'.repeat(64); await error(post(verifyAssetPath, s.headers, a.r), 'IDEMPOTENCY_CONFLICT'); });
    await t.test('wrong root/version rejected without downloading', async () => { const s = await setup(), a = await reserve(s), before = reads; a.r.expected_versions[0]!.version = 2; await error(post(verifyAssetPath, s.headers, a.r), 'STALE_VERSION'); a.r.expected_versions[0]!.id = randomUUID(); await error(post(verifyAssetPath, s.headers, a.r), 'VALIDATION_FAILED'); assert.equal(reads, before); });
    await t.test('revocation during object IO blocks final transaction without deleting bytes', async () => {
        const s = await setup(), a = await reserve(s);
        beforeSeal = async () => { await db.admin.query('UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1', [s.device.device_id]); };
        try {
            await error(post(verifyAssetPath, s.headers, a.r), 'NOT_AUTHORIZED');
            assert.equal((await state(a.r.payload.asset_id)).state, 'reserved');
            assert.ok(objects.has(a.upload.key));
        }
        finally {
            beforeSeal = undefined;
        }
    });
    await t.test('assignment epoch changes during IO reject instead of refreshing', async () => {
        const s = await setup(), a = await reserve(s);
        beforeSeal = async () => { await db.admin.query('UPDATE rounds.assignments SET version=version+1 WHERE id=$1', [s.ids.assignment]); };
        try {
            await error(post(verifyAssetPath, s.headers, a.r), 'NOT_AUTHORIZED');
            assert.equal((await state(a.r.payload.asset_id)).state, 'reserved');
        }
        finally {
            beforeSeal = undefined;
        }
    });
    await t.test('revocation during capability signing hides capability', async () => {
        const s = await setup();
        afterSign = async () => { await db.admin.query('UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1', [s.device.device_id]); };
        try {
            await error(post(reserveAssetPath, s.headers, s.r), 'NOT_AUTHORIZED');
        }
        finally {
            afterSign = undefined;
        }
    });
    await t.test('signer unavailable preserves committed reservation for same-ID recovery', async () => {
        const s = await setup();
        failSign = true;
        try {
            await error(post(reserveAssetPath, s.headers, s.r), 'PROVIDER_UNAVAILABLE');
        }
        finally {
            failSign = false;
        }
        const response = await post(reserveAssetPath, s.headers, s.r);
        assert.equal(response.status, 200);
        assert.equal(response.headers.get('x-rounds-replayed'), 'true');
        assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.assets WHERE tenant_id=$1', [s.ids.tenant])).rows[0].n, 1);
    });
    await t.test('missing upload can recover the same verification ID later', async () => { const s = await setup(), a = await reserve(s); objects.delete(a.upload.key); await error(post(verifyAssetPath, s.headers, a.r), 'PROVIDER_UNAVAILABLE'); objects.set(a.upload.key, png); await successful(verifyAssetPath, s.headers, a.r); });
    await t.test('seal unavailable never commits verification; original upload retained', async () => {
        const s = await setup(), a = await reserve(s);
        failSeal = true;
        try {
            await error(post(verifyAssetPath, s.headers, a.r), 'PROVIDER_UNAVAILABLE');
            assert.equal((await state(a.r.payload.asset_id)).state, 'reserved');
            assert.ok(objects.has(a.upload.key));
        }
        finally {
            failSeal = false;
        }
        await successful(verifyAssetPath, s.headers, a.r);
    });
    await t.test('provider claims write success but wrong sealed bytes cannot verify', async () => {
        const s = await setup(), a = await reserve(s);
        corruptSeal = true;
        try {
            await error(post(verifyAssetPath, s.headers, a.r), 'ASSET_NOT_VERIFIED');
            assert.equal((await state(a.r.payload.asset_id)).state, 'reserved');
        }
        finally {
            corruptSeal = false;
        }
    });
    await t.test('asset outbox failure rolls back state and event together', async () => {
        const s = await setup(), a = await reserve(s);
        await db.admin.query(`CREATE FUNCTION rounds.test_asset_fail() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.tenant_id='${s.ids.tenant}'::uuid THEN RAISE EXCEPTION 'injected asset outbox failure'; END IF; RETURN NEW; END $$; CREATE TRIGGER test_asset_fail BEFORE INSERT ON rounds.outbox_events FOR EACH ROW EXECUTE FUNCTION rounds.test_asset_fail()`);
        try {
            await error(post(verifyAssetPath, s.headers, a.r), 'PROVIDER_UNAVAILABLE');
            assert.equal((await state(a.r.payload.asset_id)).state, 'reserved');
            assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.domain_events WHERE command_id=$1', [a.r.command_id])).rows[0].n, 0);
        }
        finally {
            await db.admin.query('DROP TRIGGER test_asset_fail ON rounds.outbox_events; DROP FUNCTION rounds.test_asset_fail()');
        }
        await successful(verifyAssetPath, s.headers, a.r);
    });
    await t.test('same-ID concurrency verifies only once', async () => {
        const s = await setup(), a = await reserve(s);
        concurrent = true;
        try {
            const responses = await Promise.all([post(verifyAssetPath, s.headers, a.r), post(verifyAssetPath, s.headers, a.r)]);
            const results = await Promise.all(responses.map(r => r.json()));
            assert.ok(responses.every(r => r.status === 200), JSON.stringify(results));
            assert.deepEqual(results[0], results[1]);
            assert.equal((await state(a.r.payload.asset_id)).version, '2');
        }
        finally {
            concurrent = false;
        }
    });
    await t.test('competing command IDs cannot verify twice', async () => {
        const s = await setup(), a = await reserve(s);
        concurrent = true;
        try {
            const responses = await Promise.all([post(verifyAssetPath, s.headers, a.r), post(verifyAssetPath, s.headers, { ...a.r, command_id: randomUUID() })]);
            assert.deepEqual(responses.map(r => r.status).sort(), [200, 409]);
            assert.equal((await state(a.r.payload.asset_id)).version, '2');
        }
        finally {
            concurrent = false;
        }
    });
    await t.test('current membership alone cannot upload for another driver in the same tenant', async () => {
        const s = await setup(), other = await setup(), membership = randomUUID(), a = await reserve(s);
        await db.admin.query(`INSERT INTO rounds.memberships(id,tenant_id,principal_id,role_code,status) VALUES($1,$2,$3,'driver','active')`, [membership, s.ids.tenant, other.ids.actor]);
        await db.admin.query(`INSERT INTO rounds.city_grants(tenant_id,membership_id,city_id,capabilities) VALUES($1,$2,$3,ARRAY['driver.assigned_work'])`, [s.ids.tenant, membership, s.ids.city]);
        await db.admin.query(`INSERT INTO rounds.driver_relationships(tenant_id,driver_id,relationship_kind,status) VALUES($1,$2,'team','active')`, [s.ids.tenant, other.ids.driver]);
        const before = reads;
        await error(post(reserveAssetPath, other.headers, { ...s.r, command_id: randomUUID() }), 'NOT_AUTHORIZED');
        await error(post(verifyAssetPath, other.headers, a.r), 'NOT_AUTHORIZED');
        assert.equal(reads, before);
    });
    await t.test('receiver changes block attributed signature but preserve a valid photo', async () => {
        const s = await setup(), a = await reserve(s), contact = randomUUID();
        s.r = { ...s.r, command_id: randomUUID(), payload: { ...s.r.payload, kind: 'signature' } };
        const signature = await reserve(s);
        await db.admin.query(`INSERT INTO rounds.delivery_contacts(id,tenant_id,delivery_id,role,display_name,notification_permissions) VALUES($1,$2,$3,'recipient','Changed test receiver','{}')`, [contact, s.ids.tenant, s.ids.delivery]);
        await db.admin.query('UPDATE rounds.handoffs SET receiver_contact_id=$2 WHERE id=$1', [s.handoff, contact]);
        await error(post(verifyAssetPath, s.headers, signature.r), 'NOT_AUTHORIZED');
        assert.equal((await state(signature.r.payload.asset_id)).state, 'reserved');
        assert.ok(objects.has(signature.upload.key));
        await successful(verifyAssetPath, s.headers, a.r);
    });
    await t.test('purpose binding is immutable and cannot be read in another city', async () => {
        const s = await setup(), a = await reserve(s), c = await db.pool.connect();
        try {
            await c.query('BEGIN');
            await c.query('SET LOCAL ROLE rounds_api');
            await c.query("SELECT set_config('rounds.tenant_id',$1,true),set_config('rounds.principal_id',$2,true),set_config('rounds.city_id',$3,true)", [s.ids.tenant, s.ids.actor, s.ids.otherCity]);
            assert.equal((await c.query('SELECT asset_id FROM rounds.pod_asset_bindings WHERE asset_id=$1', [a.r.payload.asset_id])).rowCount, 0);
            await c.query('ROLLBACK');
            await c.query('BEGIN');
            await c.query('SET LOCAL ROLE rounds_api');
            await assert.rejects(c.query('UPDATE rounds.pod_asset_bindings SET handoff_id=$2 WHERE asset_id=$1', [a.r.payload.asset_id, randomUUID()]));
            await c.query('ROLLBACK');
        }
        finally {
            c.release();
        }
    });
    await t.test('existing unbound assets remain unchanged and cannot acquire guessed ownership', async () => {
        const s = await setup(), id = randomUUID();
        await db.admin.query(`INSERT INTO rounds.assets(id,tenant_id,object_key,kind,state,mime_type,byte_size,sha256,created_by,retention_class) VALUES($1,$2,$3,'delivery_photo','uploaded','image/png',$4,$5,$6,'test-preserved')`, [id, s.ids.tenant, `legacy-test/${id}`, png.length, podHash(png), s.ids.actor]);
        const before = await state(id);
        await error(post(verifyAssetPath, s.headers, { command_id: randomUUID(), context: s.r.context, occurred_at: s.r.occurred_at, expected_versions: [{ aggregate_type: 'assets', id, version: 1 }], payload: { asset_id: id, sha256: podHash(png) } }), 'NOT_AUTHORIZED');
        assert.deepEqual(await state(id), before);
    });
    await t.test('no configured provider fails closed, preserving legacy runtime', async () => { const disabled = createPickupHttp(options), s = await setup(); const response = await disabled(new Request('http://rounds.internal' + reserveAssetPath, { method: 'POST', headers: s.headers, body: JSON.stringify(s.r) })); assert.equal((await response.json()).code, 'FEATURE_NOT_ENABLED'); });
});
