import { randomUUID } from 'node:crypto';
import type { PoolClient } from 'pg';
import type { Wire_ReportIssueRequest, Wire_ReportIssueResult, Wire_ResourceVersion, Wire_Event_issue_reported, Wire_Event_round_readiness_changed } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { canonicalCommandJson } from './command-identity.js';
import { validatePickupIssueAttachment } from './pickup-issue-assets.js';
import { lockOriginalRoundAssignment } from './assignment-fence.js';
import { authorizeTeamPickupCity, authorizeTeamPickupJob } from './pickup-authorization.js';
import { validateIssueRequest, validateIssueResult, validateIssueEvent } from './pickup-validation.js';
import { assertExpectedVersions, CommandRejection, type CommandAuthority, type CommandWork, type ReceiptJobScope } from './transaction-runner.js';

export const reportIssuePath = '/v1/commands/ReportIssue';
function reject(code: ConstructorParameters<typeof CommandRejection>[0]): never { throw new CommandRejection(code); }
function resource(aggregate_type: Wire_ResourceVersion['aggregate_type'], id: string, value: string | number): Wire_ResourceVersion {
  const version = Number(value);
  if (!Number.isSafeInteger(version) || version < 1 || version >= Number.MAX_SAFE_INTEGER) throw new Error('Unsafe stored version');
  return { aggregate_type, id, version };
}

/** ADR-T07/M04: actual pre-pickup reports, not a pickup/return decision.
 * Damaged/wrong reports require verified original-purpose pickup evidence.
 */
export function localPickupIssueWork(authority: CommandAuthority, input: Wire_ReportIssueRequest): CommandWork {
  authority = Object.freeze({ ...authority });
  let request: Wire_ReportIssueRequest;
  try { request = JSON.parse(canonicalCommandJson(input)) as Wire_ReportIssueRequest; }
  catch { return reject('VALIDATION_FAILED'); }
  validateIssueRequest(request);
  const roundId = request.payload.round_id!, deliveryId = request.payload.delivery_id, assignmentId = request.execution_fence.assignment_id;
  return {
    commandType: 'ReportIssue', authority, request, validate: validateIssueRequest, validateResult: validateIssueResult,
    authorize: authorizeTeamPickupCity,
    resolveReceiptScope: async (client, auth) => {
      await authorizeTeamPickupJob(client, auth, roundId, assignmentId);
      if (deliveryId) {
        const scope = await client.query(`SELECT s.id FROM rounds.stops s JOIN rounds.deliveries d
          ON d.tenant_id=s.tenant_id AND d.id=s.delivery_id
          WHERE s.tenant_id=$1 AND s.round_id=$2 AND s.delivery_id=$3 AND s.kind='dropoff'
            AND s.archived_at IS NULL AND d.city_id=$4 AND d.archived_at IS NULL`,
        [auth.tenantId, roundId, deliveryId, auth.cityId]);
        if (scope.rowCount !== 1) reject('NOT_AUTHORIZED');
      }
      return { roundId, assignmentId };
    },
    execute: (client, frozen, trace, job) => executeReport(client, authority, frozen as Wire_ReportIssueRequest, trace, job),
  };
}

type Delivery = { id: string; current_manifest_id: string; readiness: 'ready' | 'review_needed' | 'held'; outcome: string; version: string };
async function executeReport(client: PoolClient, auth: CommandAuthority, request: Wire_ReportIssueRequest, traceId: string, job?: ReceiptJobScope): Promise<Wire_ReportIssueResult> {
  const p = request.payload, tenant = auth.tenantId!;
  if (!job || job.roundId !== p.round_id || job.assignmentId !== request.execution_fence.assignment_id) throw new Error('Missing original issue job');
  // Delivery -> claims/units -> Round/assignment -> stops -> manifest/lines -> driver.
  let delivery: Delivery | undefined, unitId: string | undefined;
  if (p.delivery_id) {
    delivery = (await client.query<Delivery>(`SELECT id,current_manifest_id,readiness,outcome,version FROM rounds.deliveries
      WHERE tenant_id=$1 AND city_id=$2 AND id=$3 AND archived_at IS NULL FOR UPDATE`, [tenant, auth.cityId, p.delivery_id])).rows[0];
    if (!delivery || delivery.outcome !== 'open' || !['ready', 'review_needed', 'held'].includes(delivery.readiness)) reject('NOT_AUTHORIZED');
    const claims = (await client.query<{ fulfillment_unit_id: string }>(`SELECT fulfillment_unit_id FROM rounds.active_delivery_claims
      WHERE tenant_id=$1 AND delivery_id=$2 AND round_id=$3 AND claim_kind='team' AND archived_at IS NULL
        AND (expires_at IS NULL OR expires_at>clock_timestamp()) ORDER BY id FOR UPDATE`, [tenant, delivery.id, job.roundId])).rows;
    if (claims.length !== 1 || !claims[0]!.fulfillment_unit_id) reject('NOT_AUTHORIZED');
    unitId = claims[0]!.fulfillment_unit_id;
    const unit = await client.query(`SELECT id FROM rounds.fulfillment_units WHERE tenant_id=$1 AND id=$2
      AND delivery_id=$3 AND manifest_id=$4 AND state='open' AND collected_at IS NULL AND archived_at IS NULL FOR UPDATE`,
    [tenant, unitId, delivery.id, delivery.current_manifest_id]);
    if (unit.rowCount !== 1) reject('NOT_AUTHORIZED');
  }
  const assignment = await lockOriginalRoundAssignment(client, auth, job.roundId, request.execution_fence);
  const round = (await client.query<{ version: string; state: string; departure_gate: Wire_Event_round_readiness_changed['payload']['changes'][number]['from_state']; assignment_state: string }>(
    `SELECT r.version,r.state,r.departure_gate,a.state AS assignment_state FROM rounds.rounds r
     JOIN rounds.assignments a ON a.tenant_id=r.tenant_id AND a.round_id=r.id AND a.id=$3
     WHERE r.tenant_id=$1 AND r.id=$2`, [tenant, job.roundId, job.assignmentId])).rows[0]!;
  if (round.state !== 'released' || round.assignment_state !== 'acknowledged') reject('NOT_AUTHORIZED');
  const stops = (await client.query<{ id: string; kind: string; state: string; delivery_id: string | null; fulfillment_unit_id: string | null }>(
    `SELECT id,kind,state,delivery_id,fulfillment_unit_id FROM rounds.stops WHERE tenant_id=$1 AND round_id=$2
     AND archived_at IS NULL AND state<>'cancelled' ORDER BY id FOR UPDATE`, [tenant, job.roundId])).rows;
  const pickups = stops.filter(s => s.kind === 'pickup');
  if (pickups.length !== 1 || !['released', 'en_route', 'arrived'].includes(pickups[0]!.state) ||
      !stops.some(s => s.kind === 'dropoff') || stops.some(s => !['pickup', 'dropoff'].includes(s.kind)) ||
      delivery && !stops.some(s => s.kind === 'dropoff' && s.delivery_id === delivery.id && s.fulfillment_unit_id === unitId && s.state === 'released')) reject('NOT_AUTHORIZED');
  assertExpectedVersions(request.expected_versions, [resource('rounds', job.roundId, round.version), ...(delivery ? [resource('deliveries', delivery.id, delivery.version)] : [])]);
  if (delivery) {
    const manifest = await client.query(`SELECT id FROM rounds.manifests WHERE tenant_id=$1 AND id=$2 AND delivery_id=$3 AND archived_at IS NULL FOR UPDATE`,
    [tenant, delivery.current_manifest_id, delivery.id]);
    if (manifest.rowCount !== 1) reject('MANIFEST_MISMATCH');
    const lines = (await client.query<{ id: string; quantity: string }>(`SELECT id,quantity FROM rounds.manifest_lines
      WHERE tenant_id=$1 AND manifest_id=$2 AND archived_at IS NULL ORDER BY id FOR SHARE`, [tenant, delivery.current_manifest_id])).rows;
    for (const affected of p.affected_lines) {
      const line = lines.find(l => l.id === affected.line_id);
      if (!line) reject('MANIFEST_MISMATCH');
      if (Math.round(affected.quantity * 10000) > Math.round(Number(line.quantity) * 10000)) reject('QUANTITY_EXCEEDED');
    }
  }
  const driver = await client.query('SELECT id FROM rounds.drivers WHERE id=$1 AND principal_id=$2 AND archived_at IS NULL FOR UPDATE', [assignment.driverId, auth.principalId]);
  if (driver.rowCount !== 1) reject('NOT_AUTHORIZED');
  await validatePickupIssueAttachment(client, auth, request, { pickupStopId: pickups[0]!.id, unitId, manifestId: delivery?.current_manifest_id });

  const issueId = randomUUID(), subject = resource('issues', issueId, 1), current: Wire_ResourceVersion[] = [];
  const changes: Wire_Event_issue_reported['payload']['changes'] = [{ family: 'issues.state', resource_id: issueId, from_state: null, to_state: 'open', version: 1 }];
  await client.query(`INSERT INTO rounds.issues(id,tenant_id,delivery_id,round_id,driver_id,issue_type,reason_code,state,detail,reported_at,reported_by)
    VALUES($1,$2,$3,$4,$5,$6,$7,'open',$8,$9,$10)`, [issueId, tenant, delivery?.id ?? null, job.roundId, assignment.driverId, p.issue_type, p.reason_code, p.detail ?? null, request.occurred_at, auth.principalId]);
  await client.query(`INSERT INTO rounds.issue_report_observations(issue_id,tenant_id,city_id,actor_id,round_id,assignment_id,assignment_version,observation_id,delivery_id,manifest_id,observed_at,expected_versions,payload)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::jsonb,$13::jsonb)`,
  [issueId, tenant, auth.cityId, auth.principalId, job.roundId, job.assignmentId, request.execution_fence.assignment_version, request.execution_fence.observation_id,
    delivery?.id ?? null, delivery?.current_manifest_id ?? null, request.occurred_at, JSON.stringify(request.expected_versions), JSON.stringify(p)]);
  if (p.issue_type === 'package' && delivery && delivery.readiness !== 'held') {
    await client.query(`UPDATE rounds.deliveries SET readiness='held',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [tenant, delivery.id]);
    const updated = resource('deliveries', delivery.id, Number(delivery.version) + 1); current.push(updated);
    changes.push({ family: 'deliveries.readiness', resource_id: delivery.id, from_state: delivery.readiness, to_state: 'held', version: updated.version });
  }
  const receivedAt = (await client.query<{ at: Date }>('SELECT clock_timestamp() AS at')).rows[0]!.at.toISOString();
  async function fact(event: Wire_Event_issue_reported | Wire_Event_round_readiness_changed) {
    validateIssueEvent(event);
    await client.query(`INSERT INTO rounds.domain_events(id,tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::jsonb,$13)`, [event.event_id, tenant, event.aggregate.aggregate_type, event.aggregate.id, event.aggregate.version,
      event.event_type, event.schema_version, auth.principalId, request.command_id, request.occurred_at, receivedAt, JSON.stringify(event.payload), traceId]);
    await client.query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`, [tenant, event.event_id]);
  }
  const envelope = { schema_version: 3 as const, tenant_id: tenant, principal_id: null, occurred_at: request.occurred_at, received_at: receivedAt,
    actor_id: auth.principalId, command_id: request.command_id, worker_run_id: null, trace_id: traceId };
  await fact({ ...envelope, event_id: randomUUID(), event_type: 'issue.reported', aggregate: subject, payload: { subject, affected_resources: [subject, ...current], changes } });
  // A hold dominates other departure predicates. Do not recalculate a waiting
  // report into ready, create a transport receipt, or emit an unchanged fact.
  if (p.issue_type === 'package' && round.departure_gate !== 'blocked') {
    await client.query(`UPDATE rounds.rounds SET departure_gate='blocked',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [tenant, job.roundId]);
    const updated = resource('rounds', job.roundId, Number(round.version) + 1); current.push(updated);
    await fact({ ...envelope, event_id: randomUUID(), event_type: 'round.readiness_changed', aggregate: updated,
      payload: { subject: updated, affected_resources: [updated], changes: [{ family: 'rounds.departure_gate', resource_id: job.roundId,
        from_state: round.departure_gate, to_state: 'blocked', version: updated.version }] } });
  }
  return { command_id: request.command_id, command_type: 'ReportIssue', state: 'committed', current_versions: current, resources: [subject], data: { resource: subject as Wire_ReportIssueResult['data']['resource'], state: 'open' } };
}
