import { randomUUID } from 'node:crypto';
import type { PoolClient } from 'pg';
import type { Wire_SubmitProofRequest, Wire_CompleteDeliveryRequest, Wire_proof_ref, Wire_ProofPolicy, Wire_ResourceVersion } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { canonicalCommandJson } from './command-identity.js';
import { lockOriginalRoundAssignment } from './assignment-fence.js';
import { authorizeTeamPickupCity, authorizeTeamPickupJob } from './pickup-authorization.js';
import { loadBoundPodAsset } from './pod-assets.js';
import { validateProofRequest, validateCompleteRequest, validateProofResult, validateProofEvent, validateExecutionProofPolicy } from './pickup-validation.js';
import { assertExpectedVersions, CommandRejection, type CommandAuthority, type CommandWork, type ReceiptJobScope } from './transaction-runner.js';
export const submitProofPath = '/v1/commands/SubmitProof', completeDeliveryPath = '/v1/commands/CompleteDelivery';
type Request = Wire_SubmitProofRequest | Wire_CompleteDeliveryRequest;
type Row = Record<string, any>;
const reject = (code: ConstructorParameters<typeof CommandRejection>[0]): never => { throw new CommandRejection(code); };
const root = (aggregate_type: Wire_ResourceVersion['aggregate_type'], id: string, v: string | number): Wire_ResourceVersion => {
    const n = Number(v);
    if (!Number.isSafeInteger(n) || n < 1 || n >= Number.MAX_SAFE_INTEGER)
        throw new Error('Unsafe stored version');
    return { aggregate_type, id, version: n };
};
type Scope = {
    delivery: Row;
    unit: Row;
    attempt: Row;
    stop: Row;
    round: Row;
    handoff: Row;
    policy: Wire_ProofPolicy;
    lines: Row[];
    job: ReceiptJobScope;
    claim: Row;
};
/** Original job resolution remains reusable for replay after successful closure.
 * It does not turn a fresh request on completed work into executable authority. */
export function localProofWork(authority: CommandAuthority, input: Request, complete = false): CommandWork {
    const auth = Object.freeze({ ...authority });
    const request: Request = (() => { try {
        return JSON.parse(canonicalCommandJson(input));
    }
    catch {
        throw new CommandRejection('VALIDATION_FAILED');
    } })();
    const validate: (value: unknown) => void = complete ? validateCompleteRequest : validateProofRequest;
    validate(request);
    return { commandType: complete ? 'CompleteDelivery' : 'SubmitProof', authority: auth, request, validate, validateResult: validateProofResult, authorize: authorizeTeamPickupCity,
        resolveReceiptScope: async (c) => {
            const rows = await c.query(`SELECT s.round_id FROM rounds.delivery_attempts a JOIN rounds.stops s ON s.tenant_id=a.tenant_id AND s.id=a.stop_id
        JOIN rounds.assignments x ON x.tenant_id=s.tenant_id AND x.round_id=s.round_id AND x.id=$3 AND x.driver_id=a.driver_id
        JOIN rounds.drivers d ON d.id=x.driver_id JOIN rounds.deliveries y ON y.tenant_id=a.tenant_id AND y.id=a.delivery_id
        WHERE a.tenant_id=$1 AND a.id=$2 AND d.principal_id=$4 AND y.city_id=$5 AND a.archived_at IS NULL AND s.archived_at IS NULL
        AND y.archived_at IS NULL AND s.delivery_id=y.id AND s.fulfillment_unit_id=a.fulfillment_unit_id`, [auth.tenantId, request.payload.attempt_id, request.execution_fence.assignment_id, auth.principalId, auth.cityId]);
            if (rows.rowCount !== 1)
                reject('NOT_AUTHORIZED');
            const job = { roundId: rows.rows[0].round_id as string, assignmentId: request.execution_fence.assignment_id };
            await authorizeTeamPickupJob(c, auth, job.roundId, job.assignmentId);
            return job;
        },
        execute: async (c, frozen, trace, job) => {
            const r = frozen as Request;
            if (!job || job.assignmentId !== r.execution_fence.assignment_id)
                throw new Error('Missing original job');
            const scope = await lockScope(c, auth, r, job);
            return complete ? finish(c, auth, r as Wire_CompleteDeliveryRequest, scope, trace) : submit(c, auth, r as Wire_SubmitProofRequest, scope, trace);
        } };
}
async function lockScope(c: PoolClient, auth: CommandAuthority, r: Request, job: ReceiptJobScope): Promise<Scope> {
    const tenant = auth.tenantId;
    const initial = (await c.query(`SELECT * FROM rounds.delivery_attempts WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL`, [tenant, r.payload.attempt_id])).rows[0];
    if (!initial)
        reject('NOT_AUTHORIZED');
    const delivery = (await c.query(`SELECT * FROM rounds.deliveries WHERE tenant_id=$1 AND city_id=$2 AND id=$3 AND archived_at IS NULL FOR UPDATE`, [tenant, auth.cityId, initial.delivery_id])).rows[0];
    if (!delivery)
        reject('NOT_AUTHORIZED');
    const claims = (await c.query(`SELECT *,expires_at<=clock_timestamp() AS expired FROM rounds.active_delivery_claims WHERE tenant_id=$1 AND fulfillment_unit_id=$2 AND archived_at IS NULL ORDER BY id FOR UPDATE`, [tenant, initial.fulfillment_unit_id])).rows;
    if (claims.length !== 1 || claims.some(x => x.round_id !== job.roundId || x.delivery_id !== delivery.id || x.claim_kind !== 'team' || x.expired || x.archived_at))
        reject('NOT_AUTHORIZED');
    const unit = (await c.query(`SELECT * FROM rounds.fulfillment_units WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE`, [tenant, initial.fulfillment_unit_id])).rows[0];
    if (!unit || unit.delivery_id !== delivery.id || unit.manifest_id !== delivery.current_manifest_id || unit.state !== 'collected' || delivery.outcome !== 'open')
        reject('CUSTODY_MISMATCH');
    const assignment = await lockOriginalRoundAssignment(c, auth, job.roundId, r.execution_fence);
    const epoch = (await c.query(`SELECT state FROM rounds.assignments WHERE tenant_id=$1 AND id=$2`, [tenant, job.assignmentId])).rows[0];
    if (epoch?.state !== 'acknowledged')
        reject('EXECUTION_FENCE_CHANGED');
    const round = (await c.query(`SELECT * FROM rounds.rounds WHERE tenant_id=$1 AND id=$2`, [tenant, job.roundId])).rows[0];
    if (round.state !== 'active' || round.operational_hold || round.fulfillment_kind !== 'team')
        reject('NOT_AUTHORIZED');
    const stop = (await c.query(`SELECT * FROM rounds.stops WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE`, [tenant, initial.stop_id])).rows[0];
    const attempt = (await c.query(`SELECT * FROM rounds.delivery_attempts WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE`, [tenant, initial.id])).rows[0];
    if (!stop || !attempt || stop.round_id !== job.roundId || stop.kind !== 'dropoff' || stop.delivery_id !== delivery.id || stop.fulfillment_unit_id !== unit.id || attempt.stop_id !== stop.id || attempt.delivery_id !== delivery.id || attempt.fulfillment_unit_id !== unit.id || attempt.driver_id !== assignment.driverId)
        reject('NOT_AUTHORIZED');
    assertExpectedVersions(r.expected_versions, [root('delivery_attempts', attempt.id, attempt.version)]);
    if (stop.state !== 'handed_over' || attempt.state !== 'handed_over' || !attempt.handoff_at || Date.parse(r.occurred_at) < attempt.handoff_at.getTime())
        reject('CUSTODY_MISMATCH');
    const hands = (await c.query(`SELECT * FROM rounds.handoffs WHERE tenant_id=$1 AND attempt_id=$2 ORDER BY id FOR UPDATE`, [tenant, attempt.id])).rows;
    if (hands.length !== 1 || hands[0].state !== 'recorded' || hands[0].archived_at || hands[0].actor_id !== auth.principalId)
        reject('CUSTODY_MISMATCH');
    const handoff = hands[0];
    if (handoff.proof_policy_id !== delivery.proof_policy_id)
        reject('NOT_AUTHORIZED');
    const receipt = await c.query(`SELECT id FROM rounds.command_receipts WHERE tenant_id=$1 AND actor_id=$2 AND command_type='RecordHandoff' AND state='committed'
    AND authorization_assignment_id=$3 AND authorization_round_id=$4 AND result#>>'{data,handoff_id}'=$5`, [tenant, auth.principalId, job.assignmentId, job.roundId, handoff.id]);
    if (receipt.rowCount !== 1)
        reject('NOT_AUTHORIZED');
    const manifest = (await c.query(`SELECT * FROM rounds.manifests WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE`, [tenant, unit.manifest_id])).rows[0];
    if (!manifest || manifest.delivery_id !== delivery.id || !manifest.sealed_at)
        reject('CUSTODY_MISMATCH');
    const lines = (await c.query(`SELECT l.id,l.quantity,ul.allocated_quantity,ul.delivered_quantity,ul.returned_quantity,ul.cancelled_quantity
    FROM rounds.manifest_lines l JOIN rounds.fulfillment_unit_lines ul ON ul.tenant_id=l.tenant_id AND ul.line_id=l.id AND ul.unit_id=$3 AND ul.archived_at IS NULL
    WHERE l.tenant_id=$1 AND l.manifest_id=$2 AND l.archived_at IS NULL ORDER BY l.id FOR UPDATE OF l,ul`, [tenant, manifest.id, unit.id])).rows;
    const count = (await c.query(`SELECT count(*)::int n FROM rounds.manifest_lines WHERE tenant_id=$1 AND manifest_id=$2 AND archived_at IS NULL`, [tenant, manifest.id])).rows[0].n;
    if (!lines.length || lines.length !== count || lines.some(l => l.quantity !== l.allocated_quantity || Number(l.delivered_quantity) !== 0 || Number(l.returned_quantity) !== 0 || Number(l.cancelled_quantity) !== 0))
        reject('CUSTODY_MISMATCH');
    const custody = (await c.query(`SELECT e.id,el.line_id,el.quantity FROM rounds.custody_events e JOIN rounds.custody_event_lines el ON el.tenant_id=e.tenant_id AND el.event_id=e.id
    JOIN rounds.command_receipts cr ON cr.tenant_id=e.tenant_id AND cr.command_key=e.command_id AND cr.state='committed' AND cr.command_type='RecordHandoff' AND cr.result#>>'{data,handoff_id}'=$5
    WHERE e.tenant_id=$1 AND e.attempt_id=$2 AND e.manifest_id=$3 AND e.actor_id=$4 AND e.event_kind='handoff' AND e.round_id=$6 AND e.stop_id=$7`, [tenant, attempt.id, manifest.id, auth.principalId, handoff.id, job.roundId, stop.id])).rows;
    if (custody.length !== lines.length || new Set(custody.map(x => x.id)).size !== 1 || lines.some(l => custody.filter(x => x.line_id === l.id && x.quantity === l.quantity).length !== 1))
        reject('CUSTODY_MISMATCH');
    const balances = (await c.query(`SELECT quantity FROM rounds.custody_balances WHERE tenant_id=$1 AND line_id=ANY($2::uuid[]) ORDER BY id FOR UPDATE`, [tenant, lines.map(l => l.id)])).rows;
    if (balances.some(b => Number(b.quantity) !== 0))
        reject('CUSTODY_MISMATCH');
    const policyRow = (await c.query(`SELECT payload FROM rounds.policy_versions WHERE tenant_id=$1 AND id=$2 AND policy_kind='proof' AND schema_version=1 AND effective_at<=now()`, [tenant, handoff.proof_policy_id])).rows[0];
    validateExecutionProofPolicy(policyRow?.payload);
    const policy = policyRow.payload as Wire_ProofPolicy;
    if (!['recipient', 'alternate', 'unattended'].includes(handoff.receiver_kind) || handoff.receiver_kind === 'unattended' && !policy.unattended_allowed)
        reject('NOT_AUTHORIZED');
    return { delivery, unit, attempt, stop, round, handoff, policy, lines, job, claim: claims[0] };
}
async function validateRefs(c: PoolClient, auth: CommandAuthority, s: Scope, refs: Wire_proof_ref[], requireAll: boolean) {
    const tenant = auth.tenantId;
    for (const ref of [...refs].sort((a, b) => (a.asset_id ?? a.line_id ?? '').localeCompare(b.asset_id ?? b.line_id ?? ''))) {
        if (ref.kind === 'photo' || ref.kind === 'signature') {
            const asset = await loadBoundPodAsset(c, auth, ref.asset_id!, true);
            if (asset.handoff_id !== s.handoff.id || asset.attempt_id !== s.attempt.id || asset.policy_version_id !== s.handoff.proof_policy_id || asset.assignmentId !== s.job.assignmentId || asset.kind !== (ref.kind === 'photo' ? 'delivery_photo' : 'signature'))
                reject('NOT_AUTHORIZED');
            if (asset.state !== 'verified' || !asset.object_key.startsWith(`pod-verified/${tenant}/${asset.id}/`))
                reject('ASSET_NOT_VERIFIED');
            const receipt = await c.query(`SELECT id FROM rounds.command_receipts WHERE tenant_id=$1 AND actor_id=$2 AND command_type='VerifyAsset' AND state='committed'
        AND authorization_assignment_id=$3 AND authorization_round_id=$4 AND result#>>'{data,resource,id}'=$5 AND result#>>'{data,state}'='verified'`, [tenant, auth.principalId, s.job.assignmentId, s.job.roundId, asset.id]);
            if (receipt.rowCount !== 1)
                reject('ASSET_NOT_VERIFIED');
        }
        else if (ref.kind === 'manifest') {
            if (!s.lines.some(l => l.id === ref.line_id && Math.round(Number(l.quantity) * 10000) === Math.round(ref.quantity! * 10000)))
                reject('CUSTODY_MISMATCH');
        }
        else if (ref.kind === 'receiver') {
            if (ref.receiver_contact_id !== s.handoff.receiver_contact_id || s.handoff.receiver_kind === 'unattended')
                reject('NOT_AUTHORIZED');
            const contact = await c.query(`SELECT id FROM rounds.delivery_contacts WHERE tenant_id=$1 AND id=$2 AND delivery_id=$3 AND role=$4 AND archived_at IS NULL FOR SHARE`, [tenant, ref.receiver_contact_id, s.delivery.id, s.handoff.receiver_kind]);
            if (contact.rowCount !== 1)
                reject('NOT_AUTHORIZED');
        }
        else if (ref.kind === 'location') {
            const loc = await c.query(`SELECT o.id,o.point IS NOT NULL AS has_point,o.note FROM rounds.location_observations o WHERE o.tenant_id=$1 AND o.id=$2 AND o.delivery_id=$3 AND o.driver_id=$4
        AND o.archived_at IS NULL AND o.state<>'rejected' AND EXISTS(SELECT 1 FROM rounds.domain_events e WHERE e.tenant_id=o.tenant_id AND e.event_type='stop.arrived' AND e.aggregate_id=$5 AND e.actor_id=$6
          AND e.payload->'affected_resources' @> jsonb_build_array(jsonb_build_object('aggregate_type','location_observations','id',o.id))) FOR SHARE`, [tenant, ref.location_observation_id, s.delivery.id, s.attempt.driver_id, s.stop.id, auth.principalId]);
            if (loc.rowCount !== 1 || !loc.rows[0].has_point && (!s.policy.gps_override_allowed || !loc.rows[0].note?.trim()))
                reject('NOT_AUTHORIZED');
        }
    }
    if (requireAll) {
        const required = s.policy[`${s.handoff.receiver_kind as 'recipient' | 'alternate' | 'unattended'}_required`];
        if (required.some(kind => kind === 'manifest' ? s.lines.some(l => !refs.some(x => x.kind === 'manifest' && x.line_id === l.id)) : !refs.some(x => x.kind === kind)))
            reject('PROOF_INCOMPLETE');
    }
}
// Every emitted event is validated against its generated discriminated schema.
type Change = {
    family: string;
    resource_id: string;
    from_state: string | null;
    to_state: string;
    version: number;
};
async function fact(c: PoolClient, auth: CommandAuthority, r: Request, trace: string, event: string, subject: Wire_ResourceVersion, affected: Wire_ResourceVersion[], changes: Change[], details: Record<string, unknown> = {}) {
    const received = (await c.query('SELECT clock_timestamp() at')).rows[0].at.toISOString();
    const e = { event_id: randomUUID(), event_type: event, schema_version: 3, tenant_id: auth.tenantId, principal_id: null, aggregate: subject, occurred_at: r.occurred_at, received_at: received, actor_id: auth.principalId, command_id: r.command_id, worker_run_id: null, trace_id: trace, payload: { subject, affected_resources: affected, changes, ...details } };
    validateProofEvent(e);
    await c.query(`INSERT INTO rounds.domain_events(id,tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
    VALUES($1,$2,$3,$4,$5,$6,3,$7,$8,$9,$10,$11,$12)`, [e.event_id, auth.tenantId, subject.aggregate_type, subject.id, subject.version, event, auth.principalId, r.command_id, r.occurred_at, received, JSON.stringify(e.payload), trace]);
    await c.query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`, [auth.tenantId, e.event_id]);
}
const change = (family: string, id: string, from: string | null, to: string, v: number): Change => ({ family, resource_id: id, from_state: from, to_state: to, version: v });
async function submit(c: PoolClient, auth: CommandAuthority, r: Wire_SubmitProofRequest, s: Scope, trace: string) {
    if (r.payload.handoff_id !== s.handoff.id || r.payload.policy_version_id !== s.handoff.proof_policy_id)
        reject('NOT_AUTHORIZED');
    await validateRefs(c, auth, s, r.payload.evidence, false);
    const id = randomUUID(), proof = root('proof_submissions', id, 1), items: Wire_ResourceVersion[] = [];
    await c.query(`INSERT INTO rounds.proof_submissions(id,tenant_id,attempt_id,handoff_id,policy_version_id,submitted_by,state,command_id) VALUES($1,$2,$3,$4,$5,$6,'pending',$7)`, [id, auth.tenantId, s.attempt.id, s.handoff.id, s.handoff.proof_policy_id, auth.principalId, r.command_id]);
    for (const ref of r.payload.evidence) {
        const item = randomUUID();
        await c.query(`INSERT INTO rounds.proof_items(id,tenant_id,submission_id,item_kind,asset_id,line_id,quantity,receiver_contact_id,note,location_observation_id,state,captured_at,received_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'pending',$11,clock_timestamp())`, [item, auth.tenantId, id, ref.kind, ref.asset_id ?? null, ref.line_id ?? null, ref.quantity ?? null, ref.receiver_contact_id ?? null, ref.note ?? null, ref.location_observation_id ?? null, r.occurred_at]);
        items.push(root('proof_items', item, 1));
    }
    await c.query(`UPDATE rounds.delivery_attempts SET version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [auth.tenantId, s.attempt.id]);
    const current = [root('delivery_attempts', s.attempt.id, Number(s.attempt.version) + 1)], changes = [change('proof_submissions.state', id, null, 'pending', 1), ...items.map(i => change('proof_items.state', i.id, null, 'pending', 1))];
    if (['none', 'local_only'].includes(s.delivery.evidence_state)) {
        await c.query(`UPDATE rounds.deliveries SET evidence_state='pending',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [auth.tenantId, s.delivery.id]);
        const v = root('deliveries', s.delivery.id, Number(s.delivery.version) + 1);
        current.push(v);
        changes.push(change('deliveries.evidence_state', v.id, s.delivery.evidence_state, 'pending', v.version));
    }
    else if (s.delivery.evidence_state !== 'pending')
        reject('IMMUTABLE_RECORD');
    await fact(c, auth, r, trace, 'proof.submitted', proof, [proof, ...items, ...current], changes);
    return { command_id: r.command_id, command_type: 'SubmitProof', state: 'committed' as const, current_versions: current, resources: [proof, ...items], data: { resource: proof, state: 'pending' } };
}
async function finish(c: PoolClient, auth: CommandAuthority, r: Wire_CompleteDeliveryRequest, s: Scope, trace: string) {
    const proof = (await c.query(`SELECT * FROM rounds.proof_submissions WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE`, [auth.tenantId, r.payload.proof_submission_id])).rows[0];
    if (!proof || proof.attempt_id !== s.attempt.id || proof.handoff_id !== s.handoff.id || proof.policy_version_id !== s.handoff.proof_policy_id || proof.submitted_by !== auth.principalId)
        reject('NOT_AUTHORIZED');
    if (proof.state !== 'pending')
        reject('EVIDENCE_PENDING');
    const receipt = (await c.query(`SELECT id FROM rounds.command_receipts WHERE tenant_id=$1 AND command_key=$2 AND command_type='SubmitProof' AND state='committed' AND actor_id=$3
    AND authorization_assignment_id=$4 AND authorization_round_id=$5 AND result#>>'{data,resource,id}'=$6`, [auth.tenantId, proof.command_id, auth.principalId, s.job.assignmentId, s.job.roundId, proof.id])).rows[0];
    if (!receipt)
        reject('NOT_AUTHORIZED');
    const items = (await c.query(`SELECT * FROM rounds.proof_items WHERE tenant_id=$1 AND submission_id=$2 ORDER BY id FOR UPDATE`, [auth.tenantId, proof.id])).rows;
    if (items.some(i => i.archived_at || !['pending', 'verified'].includes(i.state) || i.invalidated_at))
        reject('EVIDENCE_PENDING');
    const refs: Wire_proof_ref[] = items.map(i => ({ kind: i.item_kind, asset_id: i.asset_id, line_id: i.line_id, quantity: i.quantity == null ? null : Number(i.quantity), receiver_contact_id: i.receiver_contact_id, note: i.note, location_observation_id: i.location_observation_id }));
    validateProofRequest({ ...r, payload: { attempt_id: s.attempt.id, handoff_id: s.handoff.id, policy_version_id: s.handoff.proof_policy_id, evidence: refs } });
    await validateRefs(c, auth, s, refs, true);
    if (items.some(i => i.captured_at && Date.parse(r.occurred_at) < i.captured_at.getTime()))
        reject('VALIDATION_FAILED');
    const current: Wire_ResourceVersion[] = [], changes: Change[] = [];
    for (const item of items.filter(i => i.state === 'pending')) {
        await c.query(`UPDATE rounds.proof_items SET state='verified',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [auth.tenantId, item.id]);
        const v = root('proof_items', item.id, Number(item.version) + 1);
        current.push(v);
        changes.push(change('proof_items.state', v.id, 'pending', 'verified', v.version));
    }
    for (const [table, row, state, extra] of [
        ['proof_submissions', proof, 'complete', 'committed_at=clock_timestamp(),'], ['delivery_attempts', s.attempt, 'completed', 'closed_at=$3,'],
        ['stops', s.stop, 'completed', ''], ['fulfillment_units', s.unit, 'delivered', 'completed_at=$3,']
    ] as const) {
        await c.query(`UPDATE rounds.${table} SET ${extra} state=$4,version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2 AND $3::timestamptz IS NOT NULL`, [auth.tenantId, row.id, r.occurred_at, state]);
        const v = root(table, row.id, Number(row.version) + 1);
        current.push(v);
        changes.push(change(`${table}.state`, v.id, row.state, state, v.version));
    }
    const allocation = (await c.query(`UPDATE rounds.fulfillment_unit_lines SET delivered_quantity=allocated_quantity,version=version+1,updated_at=now() WHERE tenant_id=$1 AND unit_id=$2 AND archived_at IS NULL RETURNING id,version`, [auth.tenantId, s.unit.id])).rows;
    current.push(...allocation.map(x => root('fulfillment_unit_lines', x.id, x.version)));
    await c.query(`UPDATE rounds.active_delivery_claims SET archived_at=clock_timestamp(),version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [auth.tenantId, s.claim.id]);
    current.push(root('active_delivery_claims', s.claim.id, Number(s.claim.version) + 1));
    await c.query(`UPDATE rounds.deliveries SET outcome='delivered',evidence_state='complete',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [auth.tenantId, s.delivery.id]);
    const delivery = root('deliveries', s.delivery.id, Number(s.delivery.version) + 1);
    current.push(delivery);
    changes.push(change('deliveries.evidence_state', delivery.id, s.delivery.evidence_state, 'complete', delivery.version));
    const attempt = current.find(x => x.aggregate_type === 'delivery_attempts')!;
    await fact(c, auth, r, trace, 'fulfillment.completed', attempt, current, changes, { delivery_id: s.delivery.id, fulfillment_unit_id: s.unit.id, attempt_id: s.attempt.id, handoff_id: s.handoff.id, proof_submission_id: proof.id, quantities: s.lines.map(l => ({ line_id: l.id, quantity: Number(l.quantity) })) });
    await fact(c, auth, r, trace, 'delivery.completed', delivery, [delivery], [change('deliveries.outcome', delivery.id, s.delivery.outcome, 'delivered', delivery.version)], { delivery_id: s.delivery.id, completed_unit_ids: [s.unit.id] });
    await closeRound(c, auth, r, s, trace, current);
    return { command_id: r.command_id, command_type: 'CompleteDelivery', state: 'committed' as const, current_versions: current, resources: [], data: { resource: attempt, state: 'completed' } };
}
async function closeRound(c: PoolClient, auth: CommandAuthority, r: Request, s: Scope, trace: string, current: Wire_ResourceVersion[]) {
    // Round mutex is held. Other completions take this same lock before mutation.
    // Never close around an unfinished stop, return, legacy remainder or custody.
    const stops = (await c.query(`SELECT * FROM rounds.stops WHERE tenant_id=$1 AND round_id=$2 ORDER BY id FOR UPDATE`, [auth.tenantId, s.job.roundId])).rows;
    if (!stops.length || stops.some(x => x.archived_at || x.state !== 'completed'))
        return;
    const deliveries = stops.filter(x => x.kind === 'dropoff').map(x => x.delivery_id);
    const blocked = (await c.query(`SELECT EXISTS(SELECT 1 FROM rounds.return_tasks WHERE tenant_id=$1 AND round_id=$2 AND state NOT IN ('received','cancelled'))
    OR EXISTS(SELECT 1 FROM rounds.deliveries d WHERE d.tenant_id=$1 AND d.id=ANY($3::uuid[]) AND (d.outcome<>'delivered' OR d.evidence_state<>'complete'))
    OR EXISTS(SELECT 1 FROM rounds.remaining_obligations WHERE tenant_id=$1 AND delivery_id=ANY($3::uuid[]) AND state NOT IN ('resolved','cancelled'))
    OR EXISTS(SELECT 1 FROM rounds.active_delivery_claims WHERE tenant_id=$1 AND round_id=$2 AND archived_at IS NULL)
    OR EXISTS(SELECT 1 FROM rounds.custody_transfers t JOIN rounds.manifests m ON m.tenant_id=t.tenant_id AND m.id=t.manifest_id WHERE t.tenant_id=$1 AND m.delivery_id=ANY($3::uuid[]) AND t.state IN ('pending','partially_received')) AS blocked`, [auth.tenantId, s.job.roundId, deliveries])).rows[0].blocked;
    if (blocked)
        return;
    await c.query(`SELECT id FROM rounds.drivers WHERE id=$1 FOR UPDATE`, [s.attempt.driver_id]);
    const commitments = (await c.query(`SELECT * FROM rounds.driver_commitments WHERE tenant_id=$1 AND round_id=$2 ORDER BY id`, [auth.tenantId, s.job.roundId])).rows;
    if (commitments.some(x => x.archived_at || x.driver_id !== s.attempt.driver_id || !['committed', 'completed'].includes(x.state)))
        return;
    await c.query(`UPDATE rounds.rounds SET state='completed',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [auth.tenantId, s.job.roundId]);
    const assignment = (await c.query(`UPDATE rounds.assignments SET state='completed',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2 RETURNING version`, [auth.tenantId, s.job.assignmentId])).rows[0];
    const roots = [root('rounds', s.job.roundId, Number(s.round.version) + 1), root('assignments', s.job.assignmentId, assignment.version)];
    const changes = [change('rounds.state', s.job.roundId, 'active', 'completed', roots[0]!.version), change('assignments.state', s.job.assignmentId, 'acknowledged', 'completed', roots[1]!.version)];
    for (const commitment of commitments.filter(x => x.state === 'committed')) {
        const finished = await c.query(`UPDATE rounds.driver_commitments SET state='completed',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2 AND version=$3 AND state='committed' RETURNING id`, [auth.tenantId, commitment.id, commitment.version]);
        if (finished.rowCount !== 1)
            reject('STALE_VERSION');
        const v = root('driver_commitments', commitment.id, Number(commitment.version) + 1);
        roots.push(v);
        changes.push(change('driver_commitments.state', v.id, 'committed', 'completed', v.version));
    }
    current.push(...roots);
    await fact(c, auth, r, trace, 'round.completed', roots[0]!, roots, changes);
}
