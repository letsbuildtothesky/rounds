import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { test } from 'node:test';
import type { Wire_ConfirmPickupRequest, Wire_RecordHandoffRequest, Wire_RecordHandoffResult } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { createDeviceRegistrationHttp } from '../../src/v23/device-registration-http.js';
import { createPickupHttp, pickupPath, handoffPath, arrivalPath, statusPath } from '../../src/v23/pickup-http.js';
import { createV23NodeBoundary } from '../../src/v23/node-boundary.js';
import { deviceSessions } from '../../src/v23/device-session.js';
import { CommandRejection, CommandTransactionRunner } from '../../src/v23/transaction-runner.js';
import { localHandoffWork } from '../../src/v23/record-local-handoff.js';
import { validateHandoffRequest, validateHandoffResult } from '../../src/v23/pickup-validation.js';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';
const proof = { kind: 'proof', recipient_required: ['photo', 'receiver', 'signature'], alternate_required: ['photo', 'receiver', 'signature'],
    unattended_required: ['photo', 'note'], unattended_allowed: true, gps_override_allowed: false };
test('registered own-team device pickup -> handoff with real restricted SQL and HTTP', { timeout: 120000 }, async (t) => {
    const db = await startPostgisFixture();
    t.after(() => db.close());
    const subjects = new Map<string, string>(), devices = deviceSessions({ id: 'handoff-test', secret: randomBytes(32) });
    const options = { pool: db.pool, devices, origin: 'http://localhost:3000', verifyBearer: async (token: string) => {
            const subject = subjects.get(token);
            if (!subject)
                throw new CommandRejection('UNAUTHENTICATED');
            return subject;
        } };
    const http = createPickupHttp(options), enroll = createDeviceRegistrationHttp(options), runner = new CommandTransactionRunner(db.pool);
    async function setup(policy: unknown = proof, arrived = true, beforePickup?: (ids: Record<string, string>) => Promise<void>) {
        const ids = await seedWholeOrder(db.admin, policy), subject = randomUUID(), bearer = randomUUID(), contact = randomUUID();
        subjects.set(bearer, subject);
        await beforePickup?.(ids);
        const quantities = (await db.admin.query<{
            id: string;
            quantity: string;
        }>('SELECT id,quantity FROM rounds.manifest_lines WHERE manifest_id=$1 ORDER BY id', [ids.manifest])).rows.map(l => ({ line_id: l.id, quantity: Number(l.quantity) }));
        await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1', [ids.actor, subject]);
        await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`, [ids.tenant, ids.delivery, ids.round, ids.unit]);
        await db.admin.query(`INSERT INTO rounds.delivery_contacts(id,tenant_id,delivery_id,role,display_name,notification_permissions) VALUES($1,$2,$3,'recipient','Johannes test','{}')`, [contact, ids.tenant, ids.delivery]);
        const registered = await enroll(new Request('http://rounds.internal/v1/auth/driver-device/session', { method: 'POST', headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' }, body: JSON.stringify({ installation_secret: randomBytes(32).toString('hex'), platform: 'android' }) }));
        assert.equal(registered.status, 200);
        const device = await registered.json();
        const headers = { authorization: `Bearer ${bearer}`, 'x-rounds-device-session': device.device_session, 'content-type': 'application/json' };
        const pickup: Wire_ConfirmPickupRequest = { command_id: randomUUID(), context: { tenant_id: ids.tenant!, city_id: ids.city! }, occurred_at: '2026-09-09T00:00:00Z',
            execution_fence: { assignment_id: ids.assignment!, assignment_version: 1, observation_id: randomUUID() },
            expected_versions: [{ aggregate_type: 'rounds', id: ids.round!, version: 1 }, { aggregate_type: 'stops', id: ids.pickup!, version: 1 }, { aggregate_type: 'manifests', id: ids.manifest!, version: 1 }, { aggregate_type: 'fulfillment_units', id: ids.unit!, version: 1 }],
            payload: { round_id: ids.round!, pickup_stop_id: ids.pickup!, manifest_ids: [ids.manifest!], fulfillment_unit_ids: [ids.unit!], quantities } };
        const picked = await http(new Request('http://rounds.internal' + pickupPath, { method: 'POST', headers, body: JSON.stringify(pickup) }));
        assert.equal(picked.status, 200, JSON.stringify(await picked.clone().json()));
        const result = await picked.json();
        const attempt = result.data.attempts.find((a: {
            fulfillment_unit_id: string;
        }) => a.fulfillment_unit_id === ids.unit);
        assert.ok(attempt);
        // Actual arrival endpoint advances pickup's pending attempt; no admin
        // arrival-state writes. The negative case intentionally stays pending.
        if (arrived) {
            const response = await http(new Request('http://rounds.internal' + arrivalPath, { method: 'POST', headers, body: JSON.stringify({
                command_id: randomUUID(), context: pickup.context, occurred_at: '2026-09-09T00:01:00Z',
                execution_fence: { ...pickup.execution_fence, observation_id: randomUUID() },
                expected_versions: [{ aggregate_type: 'stops', id: ids.dropoff, version: 1 }],
                payload: { stop_id: ids.dropoff, point: { longitude: 100.5, latitude: 13.7 }, accuracy_m: 8 }
            }) }));
            assert.equal(response.status, 200, JSON.stringify(await response.clone().json()));
        }
        const r: Wire_RecordHandoffRequest = { command_id: randomUUID(), context: pickup.context, occurred_at: '2026-09-09T00:02:00Z', execution_fence: { ...pickup.execution_fence, observation_id: randomUUID() },
            expected_versions: [{ aggregate_type: 'delivery_attempts', id: attempt.id, version: arrived ? 2 : 1 }],
            payload: { attempt_id: attempt.id, receiver_kind: 'recipient', receiver_contact_id: contact, quantities } };
        return { ids, headers, device, r, contact, auth: { principalId: ids.actor!, tenantId: ids.tenant!, cityId: ids.city! } };
    }
    type Scenario = Awaited<ReturnType<typeof setup>>;
    const post = (s: Scenario, r = s.r, headers = s.headers) => http(new Request('http://rounds.internal' + handoffPath, { method: 'POST', headers, body: JSON.stringify(r) }));
    const status = (s: Scenario) => http(new Request(`http://rounds.internal${statusPath}?entity_id=${s.r.command_id}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}`, { headers: s.headers }));
    const snapshot = async (s: Scenario) => (await db.admin.query(`SELECT
    (SELECT count(*)::int FROM rounds.handoffs WHERE tenant_id=$1) handoffs,
    (SELECT count(*)::int FROM rounds.custody_events WHERE tenant_id=$1) custody,
    (SELECT count(*)::int FROM rounds.domain_events WHERE tenant_id=$1) events,
    (SELECT count(*)::int FROM rounds.outbox_events WHERE tenant_id=$1) outbox,
    (SELECT sum(quantity)::text FROM rounds.custody_balances WHERE tenant_id=$1) held,
    (SELECT state FROM rounds.delivery_attempts WHERE id=$2) attempt,
    (SELECT state FROM rounds.stops WHERE id=$3) stop,
    (SELECT outcome FROM rounds.deliveries WHERE id=$4) outcome,
    (SELECT evidence_state FROM rounds.deliveries WHERE id=$4) evidence,
    (SELECT state FROM rounds.fulfillment_units WHERE id=$5) unit,
    (SELECT sum(delivered_quantity)::text FROM rounds.fulfillment_unit_lines WHERE unit_id=$5) delivered_quantity,
    (SELECT count(*)::int FROM rounds.active_delivery_claims WHERE tenant_id=$1 AND archived_at IS NULL) claims,
    (SELECT state FROM rounds.rounds WHERE id=$6) round,
    (SELECT count(*)::int FROM rounds.proof_submissions WHERE tenant_id=$1) proof,
    (SELECT count(*)::int FROM rounds.assets WHERE tenant_id=$1) assets`, [s.ids.tenant, s.r.payload.attempt_id, s.ids.dropoff, s.ids.delivery, s.ids.unit, s.ids.round])).rows[0];
    async function denied(s: Scenario, code: string, r = s.r) { const before = await snapshot(s), response = await post(s, r); assert.equal((await response.json()).code, code); assert.deepEqual(await snapshot(s), before); }
    await t.test('whole handoff commits once and remains proof-pending, never delivered', async () => {
        const s = await setup();
        const replies = await Promise.all([post(s), post(s)]);
        for (const r of replies)
            assert.equal(r.status, 200, JSON.stringify(await r.clone().json()));
        const a = await replies[0]!.json() as Wire_RecordHandoffResult, b = await replies[1]!.json();
        assert.deepEqual(a, b);
        validateHandoffResult(a);
        assert.deepEqual(replies.map(r => r.headers.get('x-rounds-replayed')).sort(), ['false', 'true']);
        assert.deepEqual(await snapshot(s), { handoffs: 1, custody: 2, events: 3, outbox: 3, held: '0.0000', attempt: 'handed_over', stop: 'handed_over', outcome: 'open', evidence: 'none', unit: 'collected', delivered_quantity: '0.0000', claims: 1, round: 'active', proof: 0, assets: 0 });
        assert.equal(a.data.attempt_id, s.r.payload.attempt_id);
        assert.equal(a.data.proof_policy_version_id, s.ids.policy);
        const stored = (await db.admin.query(`SELECT receiver_contact_id,occurred_at,proof_policy_id,actor_id FROM rounds.handoffs WHERE id=$1`, [a.data.handoff_id])).rows[0];
        assert.equal(stored.receiver_contact_id, s.contact);
        assert.equal(stored.occurred_at.toISOString(), s.r.occurred_at.replace('Z', '.000Z'));
        const custody = (await db.admin.query(`SELECT from_custodian_id,to_custodian_id,event_kind FROM rounds.custody_events WHERE id=$1`, [a.data.custody_event_id])).rows[0];
        assert.ok(custody.from_custodian_id);
        assert.equal(custody.to_custodian_id, null);
        assert.equal(custody.event_kind, 'handoff');
        const recovered = await status(s);
        assert.equal(recovered.status, 200);
        assert.deepEqual((await recovered.json()).data.result, a);
        const receipt = (await db.admin.query(`SELECT authorization_round_id,authorization_assignment_id,result FROM rounds.command_receipts WHERE command_key=$1`, [s.r.command_id])).rows[0];
        assert.equal(receipt.authorization_round_id, s.ids.round);
        assert.equal(receipt.authorization_assignment_id, s.ids.assignment);
        for (const value of [s.headers.authorization, s.device.device_session, s.device.device_id, s.contact])
            assert.ok(!JSON.stringify(receipt.result).includes(value));
    });
    await t.test('real pickup pending attempt cannot hand off before arrival', async () => { await denied(await setup(proof, false), 'CUSTODY_MISMATCH'); });
    for (const [label, mutate, code] of [
        ['short', (r: Wire_RecordHandoffRequest) => { r.payload.quantities[0]!.quantity = 3; }, 'CUSTODY_MISMATCH'],
        ['excess', (r: Wire_RecordHandoffRequest) => { r.payload.quantities[0]!.quantity = 6; }, 'CUSTODY_MISMATCH'],
        ['duplicate line', (r: Wire_RecordHandoffRequest) => { r.payload.quantities.push({ ...r.payload.quantities[0]! }); }, 'CUSTODY_MISMATCH'],
        ['unknown line', (r: Wire_RecordHandoffRequest) => { r.payload.quantities[0]!.line_id = randomUUID(); }, 'CUSTODY_MISMATCH'],
        ['fraction precision', (r: Wire_RecordHandoffRequest) => { r.payload.quantities[0]!.quantity = 4.99999; }, 'VALIDATION_FAILED'],
        ['empty quantities', (r: Wire_RecordHandoffRequest) => { r.payload.quantities = []; }, 'VALIDATION_FAILED'],
        ['wrong version', (r: Wire_RecordHandoffRequest) => { r.expected_versions[0]!.version = 1; }, 'STALE_VERSION'],
        ['extra root', (r: Wire_RecordHandoffRequest) => { r.expected_versions.push({ aggregate_type: 'stops', id: randomUUID(), version: 1 }); }, 'VALIDATION_FAILED'],
        ['changed fence', (r: Wire_RecordHandoffRequest) => { r.execution_fence.assignment_version = 2; }, 'EXECUTION_FENCE_CHANGED'],
        ['before arrival', (r: Wire_RecordHandoffRequest) => { r.occurred_at = '2026-09-09T00:00:00Z'; }, 'CUSTODY_MISMATCH'],
        ['missing receiver', (r: Wire_RecordHandoffRequest) => { delete r.payload.receiver_contact_id; }, 'VALIDATION_FAILED'],
        ['unrelated receiver', (r: Wire_RecordHandoffRequest) => { r.payload.receiver_contact_id = randomUUID(); }, 'NOT_AUTHORIZED'],
        ['mixed receiver fields', (r: Wire_RecordHandoffRequest) => { r.payload.place_code = 'lobby'; }, 'VALIDATION_FAILED'],
    ] as const)
        await t.test(label, async () => { const s = await setup(); mutate(s.r); await denied(s, code); });
    await t.test('alternate must be a current linked alternate contact, not merely same tenant', async () => {
        const s = await setup();
        s.r.payload.receiver_kind = 'alternate';
        await denied(s, 'NOT_AUTHORIZED');
        await db.admin.query(`UPDATE rounds.delivery_contacts SET role='alternate' WHERE id=$1`, [s.contact]);
        s.r.command_id = randomUUID();
        assert.equal((await post(s)).status, 200);
    });
    await t.test('unattended records allowed place/instruction without inventing receiver custody', async () => {
        const s = await setup();
        s.r.payload = { ...s.r.payload, receiver_kind: 'unattended', receiver_contact_id: null, place_code: 'lobby', instruction_reference: 'synthetic-instruction-1' };
        assert.equal((await post(s)).status, 200);
        assert.equal((await snapshot(s)).held, '0.0000');
        assert.equal((await db.admin.query(`SELECT count(*)::int n FROM rounds.custodians WHERE tenant_id=$1`, [s.ids.tenant])).rows[0].n, 1);
    });
    await t.test('unattended forbidden by captured policy cannot move custody', async () => {
        const s = await setup({ ...proof, unattended_allowed: false });
        s.r.payload = { ...s.r.payload, receiver_kind: 'unattended', receiver_contact_id: null, place_code: 'lobby', instruction_reference: 'synthetic-1' };
        await denied(s, 'NOT_AUTHORIZED');
    });
    await t.test('unattended missing instruction is not authorized by a place label alone', async () => {
        const s = await setup();
        s.r.payload = { ...s.r.payload, receiver_kind: 'unattended', receiver_contact_id: null, place_code: 'lobby' };
        await denied(s, 'VALIDATION_FAILED');
    });
    await t.test('invalid proof policy supplies no permissive default', async () => { await denied(await setup({}), 'POLICY_NOT_CONFIGURED'); });
    for (const flag of ['future', 'unsupported-version'])
        await t.test(`${flag} proof policy cannot authorize handoff`, async () => {
            const s = await setup(), policyId = randomUUID();
            await db.admin.query(`INSERT INTO rounds.policy_versions(id,tenant_id,policy_kind,scope_key,revision,schema_version,payload,effective_at,created_by)
      VALUES($1,$2,'proof','handoff-negative',1,$3,$4,now()+$5::interval,$6)`, [policyId, s.ids.tenant, flag === 'unsupported-version' ? 2 : 1, proof, flag === 'future' ? '1 day' : '0 seconds', s.ids.actor]);
            await db.admin.query('UPDATE rounds.deliveries SET proof_policy_id=$2 WHERE id=$1', [s.ids.delivery, policyId]);
            await denied(s, 'POLICY_NOT_CONFIGURED');
        });
    await t.test('complete multiple-line decimal quantities use exact quanta, not order or tolerance', async () => {
        const line = randomUUID(), s = await setup(proof, true, async (ids) => {
            await db.admin.query('BEGIN');
            try {
                await db.admin.query(`UPDATE rounds.manifest_lines SET quantity=1.2345 WHERE id=$1`, [ids.line]);
                await db.admin.query(`UPDATE rounds.fulfillment_unit_lines SET allocated_quantity=1.2345 WHERE line_id=$1`, [ids.line]);
                await db.admin.query(`INSERT INTO rounds.manifest_lines(id,tenant_id,manifest_id,line_key,label,quantity,unit) VALUES($1,$2,$3,'L2','Second synthetic item',0.0001,'item')`, [line, ids.tenant, ids.manifest]);
                await db.admin.query(`INSERT INTO rounds.fulfillment_unit_lines(tenant_id,unit_id,line_id,allocated_quantity) VALUES($1,$2,$3,0.0001)`, [ids.tenant, ids.unit, line]);
                await db.admin.query('COMMIT');
            }
            catch (e) {
                await db.admin.query('ROLLBACK');
                throw e;
            }
        });
        const incomplete = structuredClone(s.r);
        incomplete.payload.quantities = incomplete.payload.quantities.filter(q => q.line_id !== line);
        await denied(s, 'CUSTODY_MISMATCH', incomplete);
        s.r.command_id = randomUUID();
        s.r.payload.quantities.reverse();
        const response = await post(s);
        assert.equal(response.status, 200);
        const result = await response.json();
        assert.deepEqual(result.data.quantities, [...s.r.payload.quantities].sort((a, b) => a.line_id.localeCompare(b.line_id)));
        assert.equal((await snapshot(s)).held, '0.0000');
        const rows = (await db.admin.query('SELECT line_id,quantity FROM rounds.custody_event_lines WHERE event_id=$1 ORDER BY line_id', [result.data.custody_event_id])).rows;
        assert.deepEqual(rows.map(r => ({ line_id: r.line_id, quantity: Number(r.quantity) })), result.data.quantities);
    });
    for (const flag of ['lost-custody', 'archived-contact', 'wrong-contact-delivery', 'hold', 'no-claim'])
        await t.test(flag, async () => {
            const s = await setup();
            if (flag === 'lost-custody')
                await db.admin.query('UPDATE rounds.custody_balances SET quantity=3 WHERE tenant_id=$1', [s.ids.tenant]);
            if (flag === 'archived-contact')
                await db.admin.query('UPDATE rounds.delivery_contacts SET archived_at=now() WHERE id=$1', [s.contact]);
            if (flag === 'wrong-contact-delivery') {
                const other = randomUUID();
                await db.admin.query(`INSERT INTO rounds.deliveries(id,tenant_id,city_id,pickup_site_id,human_reference,service_date,timezone,window_start_at,window_end_at,address_text,readiness,outcome,evidence_state,proof_policy_id,created_by)
        SELECT $2,tenant_id,city_id,pickup_site_id,'OTHER-TEST-ORDER',service_date,timezone,window_start_at,window_end_at,address_text,readiness,outcome,evidence_state,proof_policy_id,created_by FROM rounds.deliveries WHERE id=$1`, [s.ids.delivery, other]);
                await db.admin.query('UPDATE rounds.delivery_contacts SET delivery_id=$2 WHERE id=$1', [s.contact, other]);
            }
            if (flag === 'hold')
                await db.admin.query('UPDATE rounds.rounds SET operational_hold=true WHERE id=$1', [s.ids.round]);
            if (flag === 'no-claim')
                await db.admin.query('UPDATE rounds.active_delivery_claims SET archived_at=now() WHERE round_id=$1', [s.ids.round]);
            await denied(s, flag === 'lost-custody' ? 'CUSTODY_MISMATCH' : 'NOT_AUTHORIZED');
        });
    await t.test('two different commands racing one attempt yield one handoff and no negative balance', async () => {
        const s = await setup(), other = { ...s.r, command_id: randomUUID() };
        const results = await Promise.all([post(s), post(s, other)]);
        assert.deepEqual(results.map(r => r.status).sort(), [200, 409]);
        assert.equal((await snapshot(s)).handoffs, 1);
        assert.equal((await snapshot(s)).held, '0.0000');
    });
    await t.test('changed payload under the same identity cannot replace the original handoff', async () => {
        const s = await setup();
        assert.equal((await post(s)).status, 200);
        s.r.occurred_at = '2026-09-09T00:03:00Z';
        await denied(s, 'IDEMPOTENCY_CONFLICT');
    });
    for (const flag of ['device', 'epoch', 'city', 'reassignment', 'foreign-actor', 'foreign-city'])
        await t.test(`${flag} denies receipt replay and status`, async () => {
            const s = await setup();
            assert.equal((await post(s)).status, 200);
            const before = await snapshot(s);
            if (flag === 'device')
                await db.admin.query('UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1', [s.device.device_id]);
            if (flag === 'epoch')
                await db.admin.query('UPDATE rounds.driver_devices SET session_epoch=session_epoch+1 WHERE id=$1', [s.device.device_id]);
            if (flag === 'city')
                await db.admin.query(`UPDATE rounds.city_grants SET capabilities='{}' WHERE id=$1`, [s.ids.grant]);
            if (flag === 'reassignment')
                await db.admin.query(`UPDATE rounds.assignments SET state='superseded' WHERE id=$1`, [s.ids.assignment]);
            if (flag === 'foreign-actor') {
                const b = await setup();
                s.headers = b.headers;
            }
            if (flag === 'foreign-city') {
                s.r.context.city_id = s.ids.otherCity!;
                s.ids.city = s.ids.otherCity!;
            }
            assert.equal((await post(s)).status, 403);
            assert.equal((await status(s)).status, 403);
            assert.deepEqual(await snapshot(s), before);
        });
    await t.test('SQL failure after real writes rolls back handoff, ledger, event and stop together', async () => {
        const s = await setup(), before = await snapshot(s), work = localHandoffWork(s.auth, s.r), execute = work.execute;
        work.execute = async (...args) => { const result = await execute(...args); await args[0].query(`INSERT INTO rounds.custody_event_lines(tenant_id,event_id,line_id,quantity,condition_code) VALUES($1,$2,$3,1,'not_assessed')`, [s.ids.tenant, randomUUID(), randomUUID()]); return result; };
        const r = await runner.run(work);
        assert.equal((r.result.error as {
            code: string;
        }).code, 'VALIDATION_FAILED');
        assert.deepEqual(await snapshot(s), before);
        const retry = await post(s);
        assert.equal(retry.status, 400);
        assert.deepEqual(await snapshot(s), before);
    });
    await t.test('scope resolution retains the pre-await request identity', async () => {
        const s = await setup(), original = structuredClone(s.r), work = localHandoffWork(s.auth, s.r), authorize = work.authorize;
        work.authorize = async (...args) => {
            await authorize(...args);
            (work.request as Wire_RecordHandoffRequest).payload.attempt_id = randomUUID();
            (work.request as Wire_RecordHandoffRequest).execution_fence.assignment_id = randomUUID();
            s.r.payload.attempt_id = randomUUID();
        };
        const result = (await runner.run(work)).result as Wire_RecordHandoffResult;
        assert.equal(result.state, 'committed');
        assert.equal(result.data.attempt_id, original.payload.attempt_id);
        assert.equal((await db.admin.query('SELECT authorization_assignment_id FROM rounds.command_receipts WHERE command_key=$1', [original.command_id])).rows[0].authorization_assignment_id, s.ids.assignment);
    });
    await t.test('invalid handler result rolls back domain and receipt rather than acknowledge success', async () => {
        const s = await setup(), before = await snapshot(s), work = localHandoffWork(s.auth, s.r), execute = work.execute;
        work.execute = async (...args) => ({ ...await execute(...args), data: { handoff_id: randomUUID() } });
        await assert.rejects(runner.run(work), { code: 'PROVIDER_UNAVAILABLE' });
        assert.deepEqual(await snapshot(s), before);
        assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.command_receipts WHERE command_key=$1', [s.r.command_id])).rows[0].n, 0);
        assert.equal((await post(s)).status, 200);
    });
    await t.test('unknown client fields and actor selectors cannot enter handler', async () => {
        const s = await setup();
        assert.throws(() => validateHandoffRequest({ ...s.r, payload: { ...s.r.payload, round_id: s.ids.round } }), new CommandRejection('VALIDATION_FAILED'));
        assert.throws(() => validateHandoffRequest({ ...s.r, actor_id: s.ids.actor }), new CommandRejection('VALIDATION_FAILED'));
    });
    await t.test('actual Node handoff route remains default-off; enabled fixture uses the same handler', async () => {
        for (const enabled of [false, true]) {
            const s = await setup(), boundary = createV23NodeBoundary({ origin: options.origin, ...(enabled ? { handler: http } : {}) });
            const server = createServer((req, res) => { void boundary(req, res).then(handled => { if (!handled)
                res.writeHead(500).end('legacy fallback'); }); });
            await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
            try {
                const a = server.address();
                assert.ok(a && typeof a === 'object');
                const response = await fetch(`http://127.0.0.1:${a.port}${handoffPath}`, { method: 'POST', headers: s.headers, body: JSON.stringify(s.r) });
                assert.equal(response.status, enabled ? 200 : 403, JSON.stringify(await response.clone().json()));
            }
            finally {
                server.closeAllConnections();
                await new Promise<void>(resolve => server.close(() => resolve()));
            }
        }
    });
    t.diagnostic('Pickup-stop arrival is a setup fixture; dropoff arrival now uses actual ConfirmArrival HTTP. Provider Auth is mocked. Registration, pickup, arrival, handoff, SQL, replay and ledger are actual isolated implementations; no proof submission/phone acceptance.');
});
