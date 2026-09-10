import { randomUUID } from 'node:crypto';
import type { PoolClient } from 'pg';
import type { Wire_ConfirmArrivalRequest, Wire_ConfirmArrivalResult, Wire_Event_stop_arrived, Wire_ProofPolicy, Wire_ResourceVersion } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { canonicalCommandJson } from './command-identity.js';
import { lockOriginalRoundAssignment } from './assignment-fence.js';
import { authorizeTeamPickupCity, authorizeTeamPickupJob } from './pickup-authorization.js';
import { validateArrivalRequest, validateArrivalResult, validateArrivalEvent, validateExecutionProofPolicy } from './pickup-validation.js';
import { assertExpectedVersions, CommandRejection, type CommandAuthority, type CommandWork, type ReceiptJobScope } from './transaction-runner.js';

function reject(code: ConstructorParameters<typeof CommandRejection>[0]): never { throw new CommandRejection(code); }
const root = (aggregate_type: Wire_ResourceVersion['aggregate_type'], id: string, value: string | number): Wire_ResourceVersion => {
  const version = Number(value);
  if (!Number.isSafeInteger(version) || version < 1 || version >= Number.MAX_SAFE_INTEGER) throw new Error('Unsafe stored version');
  return { aggregate_type, id, version };
};
type Stop = { id: string; round_id: string; delivery_id: string | null; fulfillment_unit_id: string | null; kind: string; state: string; sequence: number; version: string; actual_arrival_at: Date | null };
async function route(client: PoolClient, tenant: string, round: string, locked = false): Promise<Stop[]> {
  return (await client.query<Stop>(`SELECT id,round_id,delivery_id,fulfillment_unit_id,kind,state,sequence,version,actual_arrival_at
    FROM rounds.stops WHERE tenant_id=$1 AND round_id=$2 AND archived_at IS NULL AND state<>'cancelled' ORDER BY id ${locked ? 'FOR UPDATE' : ''}`, [tenant, round])).rows;
}

/** Explicit own-team pickup/dropoff arrival. Observed GPS is not a geofence
 * attestation. No automatic navigation event, custody or preparation mutation. */
export function localArrivalWork(authority: CommandAuthority, request: Wire_ConfirmArrivalRequest): CommandWork {
  authority = Object.freeze({ ...authority });
  try { request = JSON.parse(canonicalCommandJson(request)) as Wire_ConfirmArrivalRequest; }
  catch { return reject('VALIDATION_FAILED'); }
  validateArrivalRequest(request);
  const stopId = request.payload.stop_id, assignmentId = request.execution_fence.assignment_id;
  return {
    commandType: 'ConfirmArrival', authority, request, validate: validateArrivalRequest, validateResult: validateArrivalResult,
    authorize: authorizeTeamPickupCity,
    resolveReceiptScope: async (client, auth) => {
      const rows = await client.query<{ round_id: string }>(`SELECT s.round_id FROM rounds.stops s
        JOIN rounds.rounds r ON r.tenant_id=s.tenant_id AND r.id=s.round_id
        JOIN rounds.assignments a ON a.tenant_id=r.tenant_id AND a.round_id=r.id AND a.id=$3
        JOIN rounds.drivers d ON d.id=a.driver_id
        WHERE s.tenant_id=$1 AND s.id=$2 AND r.city_id=$4 AND d.principal_id=$5 AND s.archived_at IS NULL`,
      [auth.tenantId, stopId, assignmentId, auth.cityId, auth.principalId]);
      if (rows.rowCount !== 1) reject('NOT_AUTHORIZED');
      const roundId = rows.rows[0]!.round_id;
      await authorizeTeamPickupJob(client, auth, roundId, assignmentId);
      return { roundId, assignmentId };
    },
    execute: (client, frozen, trace, job) => executeArrival(client, authority, frozen as Wire_ConfirmArrivalRequest, trace, job),
  };
}

async function executeArrival(client: PoolClient, auth: CommandAuthority, request: Wire_ConfirmArrivalRequest, traceId: string, job?: ReceiptJobScope): Promise<Wire_ConfirmArrivalResult> {
  if (!job || job.assignmentId !== request.execution_fence.assignment_id) throw new Error('Missing original receipt job');
  const tenant = auth.tenantId!, p = request.payload, initial = await route(client, tenant, job.roundId);
  const target = initial.find(s => s.id === p.stop_id);
  if (!target || !['pickup', 'dropoff'].includes(target.kind)) reject('NOT_AUTHORIZED');
  if (initial.filter(s => s.kind === 'pickup').length !== 1 || initial.some(s => !['pickup', 'dropoff'].includes(s.kind))) reject('NOT_AUTHORIZED');
  const dropoffs = initial.filter(s => s.kind === 'dropoff' && (target.kind === 'pickup' || s.id === target.id));
  const deliveryIds = dropoffs.map(s => s.delivery_id!), unitIds = dropoffs.map(s => s.fulfillment_unit_id!);
  if (!dropoffs.length || deliveryIds.some(id => !id) || unitIds.some(id => !id) ||
      new Set(deliveryIds).size !== deliveryIds.length || new Set(unitIds).size !== unitIds.length) reject('CUSTODY_MISMATCH');

  // Same E04 lock classes as pickup/handoff. Discovery is rechecked after Round
  // and stop locks; caller cannot supply a preferred attempt or subset/policy.
  const deliveries = (await client.query<{ id: string; current_manifest_id: string; proof_policy_id: string; outcome: string }>(
    `SELECT id,current_manifest_id,proof_policy_id,outcome FROM rounds.deliveries
     WHERE tenant_id=$1 AND city_id=$2 AND id=ANY($3::uuid[]) AND archived_at IS NULL ORDER BY id FOR UPDATE`, [tenant, auth.cityId, deliveryIds])).rows;
  if (deliveries.length !== deliveryIds.length || deliveries.some(d => d.outcome !== 'open')) reject('NOT_AUTHORIZED');
  const claims = (await client.query<{ round_id: string; delivery_id: string; fulfillment_unit_id: string; claim_kind: string; archived_at: Date | null; expired: boolean }>(
    `SELECT round_id,delivery_id,fulfillment_unit_id,claim_kind,archived_at,expires_at<=clock_timestamp() AS expired
     FROM rounds.active_delivery_claims WHERE tenant_id=$1 AND fulfillment_unit_id=ANY($2::uuid[]) ORDER BY id FOR UPDATE`, [tenant, unitIds])).rows;
  if (claims.length !== unitIds.length || claims.some(c => c.round_id !== job.roundId || c.claim_kind !== 'team' || c.archived_at || c.expired ||
      !dropoffs.some(s => s.delivery_id === c.delivery_id && s.fulfillment_unit_id === c.fulfillment_unit_id))) reject('NOT_AUTHORIZED');
  const units = (await client.query<{ id: string; delivery_id: string; manifest_id: string; state: string; collected_at: Date | null }>(
    `SELECT id,delivery_id,manifest_id,state,collected_at FROM rounds.fulfillment_units
     WHERE tenant_id=$1 AND id=ANY($2::uuid[]) AND archived_at IS NULL ORDER BY id FOR UPDATE`, [tenant, unitIds])).rows;
  if (units.length !== unitIds.length || units.some(u => !deliveries.some(d => d.id === u.delivery_id && d.current_manifest_id === u.manifest_id) ||
      !dropoffs.some(s => s.delivery_id === u.delivery_id && s.fulfillment_unit_id === u.id) ||
      u.state !== (target.kind === 'pickup' ? 'open' : 'collected'))) reject('CUSTODY_MISMATCH');
  const assignment = await lockOriginalRoundAssignment(client, auth, job.roundId, request.execution_fence);
  const round = (await client.query<{ state: string; operational_hold: boolean; fulfillment_kind: string }>(
    `SELECT state,operational_hold,fulfillment_kind FROM rounds.rounds WHERE tenant_id=$1 AND id=$2`, [tenant, job.roundId])).rows[0]!;
  const stops = await route(client, tenant, job.roundId, true);
  if (JSON.stringify(stops) !== JSON.stringify(initial)) reject('STALE_VERSION');
  const stop = stops.find(s => s.id === target.id)!;
  assertExpectedVersions(request.expected_versions, [root('stops', stop.id, stop.version)]);
  if (!['released', 'en_route'].includes(stop.state) || stop.actual_arrival_at) reject('CUSTODY_MISMATCH');
  if (round.state !== (stop.kind === 'pickup' ? 'released' : 'active') || round.operational_hold || round.fulfillment_kind !== 'team' ||
      stops.some(s => s.sequence < stop.sequence && !['completed', 'failed'].includes(s.state))) reject('NOT_AUTHORIZED');

  let attempt: { id: string; delivery_id: string; fulfillment_unit_id: string; driver_id: string; state: string; version: string; arrived_at: Date | null } | undefined;
  if (stop.kind === 'dropoff') {
    const attempts = (await client.query<NonNullable<typeof attempt>>(`SELECT id,delivery_id,fulfillment_unit_id,driver_id,state,version,arrived_at
      FROM rounds.delivery_attempts WHERE tenant_id=$1 AND stop_id=$2 AND archived_at IS NULL
      AND state IN ('pending','en_route','arrived','handed_over') ORDER BY id FOR UPDATE`, [tenant, stop.id])).rows;
    attempt = attempts[0];
    if (attempts.length !== 1 || !attempt || attempt.delivery_id !== stop.delivery_id || attempt.fulfillment_unit_id !== stop.fulfillment_unit_id ||
        attempt.driver_id !== assignment.driverId || !['pending', 'en_route'].includes(attempt.state) || attempt.arrived_at ||
        !units[0]!.collected_at || Date.parse(request.occurred_at) < units[0]!.collected_at.getTime()) reject('CUSTODY_MISMATCH');
  }
  if (!p.point) {
    // Proof policy is the existing owner of GPS outage permission. Pickup has
    // no delivery of its own, so all assigned orders must permit the override.
    const ids = [...new Set(deliveries.map(d => d.proof_policy_id))];
    const policies = (await client.query<{ payload: unknown }>(`SELECT payload FROM rounds.policy_versions
      WHERE tenant_id=$1 AND id=ANY($2::uuid[]) AND policy_kind='proof' AND schema_version=1 AND effective_at<=now()`, [tenant, ids])).rows;
    if (policies.length !== ids.length) reject('POLICY_NOT_CONFIGURED');
    for (const policy of policies) validateExecutionProofPolicy(policy.payload);
    if (policies.some(row => !(row.payload as Wire_ProofPolicy).gps_override_allowed)) reject('NOT_AUTHORIZED');
  }
  const driver = await client.query(`SELECT id FROM rounds.drivers WHERE id=$1 AND principal_id=$2 AND archived_at IS NULL FOR UPDATE`, [assignment.driverId, auth.principalId]);
  if (!driver.rowCount) reject('NOT_AUTHORIZED');

  const observationId = randomUUID(), receivedAt = (await client.query<{ at: Date }>('SELECT clock_timestamp() AS at')).rows[0]!.at.toISOString();
  await client.query(`INSERT INTO rounds.location_observations(id,tenant_id,delivery_id,driver_id,point,accuracy_m,observed_at,kind,note,state)
    VALUES($1,$2,$3,$4,CASE WHEN $5::double precision IS NULL THEN NULL ELSE public.ST_SetSRID(public.ST_MakePoint($5,$6),4326)::public.geography END,$7,$8,'arrival',$9,'proposed')`,
  [observationId, tenant, stop.delivery_id, assignment.driverId, p.point?.longitude ?? null, p.point?.latitude ?? null, p.accuracy_m ?? null, request.occurred_at, p.override_reason ?? null]);
  await client.query(`UPDATE rounds.stops SET state='arrived',actual_arrival_at=$3,version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [tenant, stop.id, request.occurred_at]);
  const current = [root('stops', stop.id, Number(stop.version) + 1)], resources = [root('location_observations', observationId, 1)];
  const changes: Wire_Event_stop_arrived['payload']['changes'] = [{ family: 'stops.state', resource_id: stop.id, from_state: stop.state as 'released' | 'en_route', to_state: 'arrived', version: current[0]!.version }];
  if (attempt) {
    await client.query(`UPDATE rounds.delivery_attempts SET state='arrived',arrived_at=$3,version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [tenant, attempt.id, request.occurred_at]);
    const updated = root('delivery_attempts', attempt.id, Number(attempt.version) + 1);
    current.push(updated);
    changes.push({ family: 'delivery_attempts.state', resource_id: attempt.id, from_state: attempt.state as 'pending' | 'en_route', to_state: 'arrived', version: updated.version });
  }
  const fact: Wire_Event_stop_arrived = { event_id: randomUUID(), event_type: 'stop.arrived', schema_version: 3, tenant_id: tenant, principal_id: null,
    aggregate: current[0]!, occurred_at: request.occurred_at, received_at: receivedAt, actor_id: auth.principalId, command_id: request.command_id, worker_run_id: null, trace_id: traceId,
    payload: { subject: current[0]!, affected_resources: [...current, ...resources], changes } };
  validateArrivalEvent(fact);
  await client.query(`INSERT INTO rounds.domain_events(id,tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::jsonb,$13)`, [fact.event_id, tenant, fact.aggregate.aggregate_type, fact.aggregate.id, fact.aggregate.version, fact.event_type, fact.schema_version,
    auth.principalId, request.command_id, request.occurred_at, receivedAt, JSON.stringify(fact.payload), traceId]);
  await client.query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`, [tenant, fact.event_id]);
  return { command_id: request.command_id, command_type: 'ConfirmArrival', state: 'committed', current_versions: current, resources, data: { resource: { aggregate_type: 'stops', id: stop.id, version: current[0]!.version } } };
}
