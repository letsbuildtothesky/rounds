import { randomUUID } from 'node:crypto';
import type { PoolClient } from 'pg';
import type { Wire_RecordHandoffRequest, Wire_RecordHandoffResult, Wire_ProofPolicy, Wire_Event_handoff_recorded, Wire_ResourceVersion } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { canonicalCommandJson } from './command-identity.js';
import { lockOriginalRoundAssignment } from './assignment-fence.js';
import { authorizeTeamPickupCity, authorizeTeamPickupJob } from './pickup-authorization.js';
import { validateExecutionProofPolicy, validateHandoffRequest, validateHandoffResult, validateHandoffEvent } from './pickup-validation.js';
import { assertExpectedVersions, CommandRejection, type CommandAuthority, type CommandWork, type ReceiptJobScope } from './transaction-runner.js';
function reject(code: ConstructorParameters<typeof CommandRejection>[0]): never { throw new CommandRejection(code); }
const version = (v: string | number): number => {
    const n = Number(v);
    if (!Number.isSafeInteger(n) || n < 1 || n >= Number.MAX_SAFE_INTEGER)
        throw new Error('Unsafe stored version');
    return n;
};
const root = (aggregate_type: Wire_ResourceVersion['aggregate_type'], id: string, v: string | number): Wire_ResourceVersion => ({ aggregate_type, id, version: version(v) });
type Attempt = {
    id: string;
    delivery_id: string;
    stop_id: string;
    driver_id: string;
    fulfillment_unit_id: string;
    state: string;
    arrived_at: Date | null;
    version: string;
};
/** Actual own-team handoff, separate from proof/CompleteDelivery. Caller supplies
 * verified authority; HTTP adds device verification. No caller-selected Round,
 * assumed current assignment, receiver principal, or fabricated verified asset. */
export function localHandoffWork(authority: CommandAuthority, request: Wire_RecordHandoffRequest): CommandWork {
    authority = Object.freeze({ ...authority });
    try {
        request = JSON.parse(canonicalCommandJson(request)) as Wire_RecordHandoffRequest;
    }
    catch {
        return reject('VALIDATION_FAILED');
    }
    validateHandoffRequest(request);
    const assignmentId = request.execution_fence.assignment_id;
    const attemptId = request.payload.attempt_id;
    return {
        commandType: 'RecordHandoff', authority, request, validate: validateHandoffRequest, validateResult: validateHandoffResult,
        authorize: authorizeTeamPickupCity,
        resolveReceiptScope: async (client, auth) => {
            const rows = await client.query<{
                round_id: string;
            }>(`SELECT s.round_id FROM rounds.delivery_attempts a
        JOIN rounds.stops s ON s.tenant_id=a.tenant_id AND s.id=a.stop_id
        JOIN rounds.assignments x ON x.tenant_id=s.tenant_id AND x.round_id=s.round_id AND x.id=$3
        JOIN rounds.drivers d ON d.id=a.driver_id AND d.id=x.driver_id
        JOIN rounds.deliveries y ON y.tenant_id=a.tenant_id AND y.id=a.delivery_id
        WHERE a.tenant_id=$1 AND a.id=$2 AND d.principal_id=$4 AND y.city_id=$5
          AND s.delivery_id=a.delivery_id AND s.fulfillment_unit_id=a.fulfillment_unit_id
          AND a.archived_at IS NULL AND s.archived_at IS NULL AND y.archived_at IS NULL`, [auth.tenantId, attemptId, assignmentId, auth.principalId, auth.cityId]);
            if (rows.rowCount !== 1)
                reject('NOT_AUTHORIZED');
            const roundId = rows.rows[0]!.round_id;
            await authorizeTeamPickupJob(client, auth, roundId, assignmentId);
            return { roundId, assignmentId };
        },
        execute: (client, frozen, trace, job) => executeHandoff(client, authority, frozen as Wire_RecordHandoffRequest, trace, job),
    };
}
async function executeHandoff(client: PoolClient, auth: CommandAuthority, request: Wire_RecordHandoffRequest, traceId: string, job?: ReceiptJobScope): Promise<Wire_RecordHandoffResult> {
    if (!job || job.assignmentId !== request.execution_fence.assignment_id)
        throw new Error('Missing original receipt job');
    const tenant = auth.tenantId!, p = request.payload;
    const initial = (await client.query<Attempt>(`SELECT id,delivery_id,stop_id,driver_id,fulfillment_unit_id,state,arrived_at,version
    FROM rounds.delivery_attempts WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL`, [tenant, p.attempt_id])).rows[0];
    if (!initial)
        reject('NOT_AUTHORIZED');
    // E04: delivery -> claim/unit -> Round/assignment -> stops/attempt -> manifest
    // and custody -> global driver. Recheck every discovered association locked.
    const delivery = (await client.query<{
        id: string;
        current_manifest_id: string;
        proof_policy_id: string;
        outcome: string;
        readiness: string;
    }>(`SELECT id,current_manifest_id,proof_policy_id,outcome,readiness
    FROM rounds.deliveries WHERE tenant_id=$1 AND city_id=$2 AND id=$3 AND archived_at IS NULL FOR UPDATE`, [tenant, auth.cityId, initial.delivery_id])).rows[0];
    if (!delivery)
        reject('NOT_AUTHORIZED');
    const claims = await client.query<{
        round_id: string;
        delivery_id: string;
        claim_kind: string;
        expired: boolean;
        archived_at: Date | null;
    }>(`SELECT round_id,delivery_id,claim_kind,expires_at<=clock_timestamp() AS expired,archived_at
    FROM rounds.active_delivery_claims WHERE tenant_id=$1 AND fulfillment_unit_id=$2 ORDER BY id FOR UPDATE`, [tenant, initial.fulfillment_unit_id]);
    if (claims.rowCount !== 1 || claims.rows.some(c => c.round_id !== job.roundId || c.delivery_id !== delivery.id || c.claim_kind !== 'team' || c.expired || c.archived_at))
        reject('NOT_AUTHORIZED');
    const unit = (await client.query<{
        id: string;
        delivery_id: string;
        manifest_id: string;
        state: string;
    }>(`SELECT id,delivery_id,manifest_id,state FROM rounds.fulfillment_units
    WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE`, [tenant, initial.fulfillment_unit_id])).rows[0];
    if (!unit || unit.delivery_id !== delivery.id || unit.manifest_id !== delivery.current_manifest_id || unit.state !== 'collected')
        reject('CUSTODY_MISMATCH');
    const assignment = await lockOriginalRoundAssignment(client, auth, job.roundId, request.execution_fence);
    const round = (await client.query<{
        state: string;
        operational_hold: boolean;
        fulfillment_kind: string;
    }>(`SELECT state,operational_hold,fulfillment_kind FROM rounds.rounds WHERE tenant_id=$1 AND id=$2`, [tenant, job.roundId])).rows[0]!;
    if (round.state !== 'active' || round.operational_hold || round.fulfillment_kind !== 'team' || delivery.outcome !== 'open' || delivery.readiness !== 'ready')
        reject('NOT_AUTHORIZED');
    const stop = (await client.query<{
        id: string;
        round_id: string;
        delivery_id: string;
        fulfillment_unit_id: string;
        kind: string;
        state: string;
        version: string;
    }>(`SELECT id,round_id,delivery_id,fulfillment_unit_id,kind,state,version
    FROM rounds.stops WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE`, [tenant, initial.stop_id])).rows[0];
    const attempt = (await client.query<Attempt>(`SELECT id,delivery_id,stop_id,driver_id,fulfillment_unit_id,state,arrived_at,version
    FROM rounds.delivery_attempts WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE`, [tenant, p.attempt_id])).rows[0];
    if (!stop || !attempt || stop.round_id !== job.roundId || stop.kind !== 'dropoff' || stop.delivery_id !== delivery.id || stop.fulfillment_unit_id !== unit.id ||
        attempt.delivery_id !== delivery.id || attempt.stop_id !== stop.id || attempt.fulfillment_unit_id !== unit.id || attempt.driver_id !== assignment.driverId)
        reject('NOT_AUTHORIZED');
    assertExpectedVersions(request.expected_versions, [root('delivery_attempts', attempt.id, attempt.version)]);
    if (attempt.state !== 'arrived' || stop.state !== 'arrived' || !attempt.arrived_at || Date.parse(request.occurred_at) < attempt.arrived_at.getTime())
        reject('CUSTODY_MISMATCH');
    const prior = await client.query(`SELECT id FROM rounds.handoffs WHERE tenant_id=$1 AND attempt_id=$2 LIMIT 1`, [tenant, attempt.id]);
    if (prior.rowCount)
        reject('IMMUTABLE_RECORD');
    const manifest = (await client.query<{
        id: string;
        delivery_id: string;
        sealed_at: Date | null;
    }>(`SELECT id,delivery_id,sealed_at FROM rounds.manifests WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE`, [tenant, unit.manifest_id])).rows[0];
    if (!manifest || manifest.delivery_id !== delivery.id || !manifest.sealed_at)
        reject('CUSTODY_MISMATCH');
    const lines = (await client.query<{
        id: string;
        quantity: string;
    }>(`SELECT id,quantity FROM rounds.manifest_lines WHERE tenant_id=$1 AND manifest_id=$2 AND archived_at IS NULL ORDER BY id FOR UPDATE`, [tenant, manifest.id])).rows;
    const allocations = (await client.query<{
        line_id: string;
        allocated_quantity: string;
        delivered_quantity: string;
        returned_quantity: string;
        cancelled_quantity: string;
    }>(`SELECT line_id,allocated_quantity,delivered_quantity,returned_quantity,cancelled_quantity
    FROM rounds.fulfillment_unit_lines WHERE tenant_id=$1 AND unit_id=$2 AND archived_at IS NULL ORDER BY id FOR UPDATE`, [tenant, unit.id])).rows;
    const actual = new Map(p.quantities.map(q => [q.line_id, Math.round(q.quantity * 10000)]));
    if (!lines.length || actual.size !== p.quantities.length || actual.size !== lines.length || allocations.length !== lines.length || lines.some(l => {
        const a = allocations.find(a => a.line_id === l.id);
        return !a || a.allocated_quantity !== l.quantity || Number(a.delivered_quantity) !== 0 || Number(a.returned_quantity) !== 0 || Number(a.cancelled_quantity) !== 0 || actual.get(l.id) !== Math.round(Number(l.quantity) * 10000);
    }))
        reject('CUSTODY_MISMATCH');
    // Immutable policy version captured on the delivery. Missing/malformed policy
    // grants no permission; no permissive default or current-settings substitution.
    const policyRow = (await client.query<{
        payload: unknown;
    }>(`SELECT payload FROM rounds.policy_versions WHERE tenant_id=$1 AND id=$2 AND policy_kind='proof' AND schema_version=1 AND effective_at<=now()`, [tenant, delivery.proof_policy_id])).rows[0];
    validateExecutionProofPolicy(policyRow?.payload);
    const policy = policyRow!.payload as Wire_ProofPolicy;
    const required = policy[`${p.receiver_kind}_required`];
    if (p.receiver_kind === 'unattended') {
        if (!policy.unattended_allowed)
            reject('NOT_AUTHORIZED');
        if (p.receiver_contact_id || !p.place_code?.trim() || !p.instruction_reference?.trim() || required.includes('receiver'))
            reject('VALIDATION_FAILED');
    }
    else {
        if (p.place_code || p.instruction_reference)
            reject('VALIDATION_FAILED');
        if ((p.receiver_kind === 'alternate' || required.includes('receiver')) && !p.receiver_contact_id)
            reject('VALIDATION_FAILED');
        if (p.receiver_contact_id) {
            const contact = await client.query(`SELECT id FROM rounds.delivery_contacts WHERE tenant_id=$1 AND delivery_id=$2 AND id=$3 AND role=$4 AND archived_at IS NULL FOR SHARE`, [tenant, delivery.id, p.receiver_contact_id, p.receiver_kind]);
            if (contact.rowCount !== 1)
                reject('NOT_AUTHORIZED');
        }
    }
    const custodian = (await client.query<{
        id: string;
    }>(`SELECT id FROM rounds.custodians WHERE tenant_id=$1 AND kind='principal' AND principal_id=$2 AND archived_at IS NULL FOR UPDATE`, [tenant, auth.principalId])).rows[0];
    if (!custodian)
        reject('CUSTODY_MISMATCH');
    const balances = (await client.query<{
        id: string;
        line_id: string;
        custodian_id: string;
        quantity: string;
        archived_at: Date | null;
    }>(`SELECT id,line_id,custodian_id,quantity,archived_at FROM rounds.custody_balances
    WHERE tenant_id=$1 AND line_id=ANY($2::uuid[]) ORDER BY id FOR UPDATE`, [tenant, lines.map(l => l.id)])).rows;
    if (balances.some(b => b.archived_at || b.custodian_id !== custodian.id && Number(b.quantity) > 0) || lines.some(l => {
        const own = balances.filter(b => b.line_id === l.id && b.custodian_id === custodian.id);
        return own.length !== 1 || own[0]!.quantity !== l.quantity;
    }))
        reject('CUSTODY_MISMATCH');
    const driver = await client.query(`SELECT id FROM rounds.drivers WHERE id=$1 AND principal_id=$2 AND archived_at IS NULL FOR UPDATE`, [assignment.driverId, auth.principalId]);
    if (!driver.rowCount)
        reject('NOT_AUTHORIZED');
    const handoffId = randomUUID(), custodyId = randomUUID(), receivedAt = (await client.query<{
        at: Date;
    }>('SELECT clock_timestamp() AS at')).rows[0]!.at.toISOString();
    // Customer/approved location is outside tracked principal/site custody. Debit
    // driver custody without creating a fictional recipient account or balance.
    await client.query(`INSERT INTO rounds.handoffs(id,tenant_id,attempt_id,receiver_kind,receiver_contact_id,place_code,instruction_reference,occurred_at,actor_id,proof_policy_id,state)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'recorded')`, [handoffId, tenant, attempt.id, p.receiver_kind, p.receiver_contact_id ?? null, p.place_code ?? null, p.instruction_reference ?? null, request.occurred_at, auth.principalId, delivery.proof_policy_id]);
    await client.query(`INSERT INTO rounds.custody_events(id,tenant_id,manifest_id,attempt_id,event_kind,occurred_at,received_at,actor_id,command_id,round_id,stop_id,from_custodian_id)
    VALUES($1,$2,$3,$4,'handoff',$5,$6,$7,$8,$9,$10,$11)`, [custodyId, tenant, manifest.id, attempt.id, request.occurred_at, receivedAt, auth.principalId, request.command_id, job.roundId, stop.id, custodian.id]);
    for (const l of lines) {
        await client.query(`INSERT INTO rounds.custody_event_lines(tenant_id,event_id,line_id,quantity,condition_code) VALUES($1,$2,$3,$4,'not_assessed')`, [tenant, custodyId, l.id, l.quantity]);
        await client.query(`UPDATE rounds.custody_balances SET quantity=0,last_event_id=$4,version=version+1,updated_at=now() WHERE tenant_id=$1 AND line_id=$2 AND custodian_id=$3`, [tenant, l.id, custodian.id, custodyId]);
    }
    await client.query(`UPDATE rounds.delivery_attempts SET state='handed_over',handoff_at=$3,version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [tenant, attempt.id, request.occurred_at]);
    await client.query(`UPDATE rounds.stops SET state='handed_over',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [tenant, stop.id]);
    const current = [root('delivery_attempts', attempt.id, version(attempt.version) + 1), root('stops', stop.id, version(stop.version) + 1)];
    const resources = [root('handoffs', handoffId, 1), root('custody_events', custodyId, 1)];
    const fact: Wire_Event_handoff_recorded = { event_id: randomUUID(), event_type: 'handoff.recorded', schema_version: 3, tenant_id: tenant, principal_id: null, aggregate: current[0]!,
        occurred_at: request.occurred_at, received_at: receivedAt, actor_id: auth.principalId, command_id: request.command_id, worker_run_id: null, trace_id: traceId,
        payload: { subject: current[0]!, affected_resources: [...current, ...resources], changes: [
                { family: 'delivery_attempts.state', resource_id: attempt.id, from_state: 'arrived', to_state: 'handed_over', version: current[0]!.version },
                { family: 'stops.state', resource_id: stop.id, from_state: 'arrived', to_state: 'handed_over', version: current[1]!.version },
                { family: 'handoffs.state', resource_id: handoffId, from_state: null, to_state: 'recorded', version: 1 }
            ] } };
    validateHandoffEvent(fact);
    await client.query(`INSERT INTO rounds.domain_events(id,tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::jsonb,$13)`, [fact.event_id, tenant, fact.aggregate.aggregate_type, fact.aggregate.id, fact.aggregate.version, fact.event_type, 3, auth.principalId, request.command_id, request.occurred_at, receivedAt, JSON.stringify(fact.payload), traceId]);
    await client.query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`, [tenant, fact.event_id]);
    return { command_id: request.command_id, command_type: 'RecordHandoff', state: 'committed', current_versions: current, resources,
        data: { handoff_id: handoffId, attempt_id: attempt.id, custody_event_id: custodyId, quantities: lines.map(l => ({ line_id: l.id, quantity: Number(l.quantity) })), proof_policy_version_id: delivery.proof_policy_id } };
}
