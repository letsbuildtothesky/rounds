import type { PoolClient } from 'pg';
import type { Wire_DriverPickupIssueQueryResult } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { authorizeDeviceSession } from './authentication.js';
import type { DeviceSession } from './device-session.js';
import { authorizeTeamPickupCity } from './pickup-authorization.js';
import { validatePickupIssueQuery } from './pickup-validation.js';
import { CommandRejection } from './transaction-runner.js';
import { currentIssueDecision } from './issue-decision-chain.js';

/** ADR-Q04: a read of an original report, NOT a release/decision command.
 * Called inside the existing repeatable-read restricted transaction. This does
 * not call the execution projection: no new fence/policy can rebase evidence.
 */
export async function projectPickupIssue(client: PoolClient, session: DeviceSession, tenant: string, city: string, round: string, issue: string, now: number): Promise<Wire_DriverPickupIssueQueryResult> {
  const auth = { principalId: session.principalId, tenantId: tenant, cityId: city };
  await authorizeDeviceSession(client, auth, session, now);
  await authorizeTeamPickupCity(client, auth);
  const rows = (await client.query(`SELECT o.assignment_id,o.assignment_version,o.observation_id,o.delivery_id,
      i.version AS issue_version,i.state,r.departure_gate,d.readiness,d.preparation_state,d.outcome
    FROM rounds.issue_report_observations o
    JOIN rounds.issues i ON i.tenant_id=o.tenant_id AND i.id=o.issue_id AND i.round_id=o.round_id
    JOIN rounds.assignments a ON a.tenant_id=o.tenant_id AND a.id=o.assignment_id AND a.round_id=o.round_id
    JOIN rounds.rounds r ON r.tenant_id=o.tenant_id AND r.id=o.round_id AND r.city_id=o.city_id
    JOIN rounds.drivers driver ON driver.id=a.driver_id AND driver.principal_id=o.actor_id
    LEFT JOIN rounds.deliveries d ON d.tenant_id=o.tenant_id AND d.id=o.delivery_id AND d.city_id=o.city_id AND d.archived_at IS NULL
    WHERE o.tenant_id=$1 AND o.city_id=$2 AND o.round_id=$3 AND o.issue_id=$4 AND o.actor_id=$5
      AND i.reported_by=o.actor_id AND i.driver_id=driver.id AND i.delivery_id IS NOT DISTINCT FROM o.delivery_id
      AND i.trip_id IS NULL AND i.attempt_id IS NULL AND i.issue_type IN ('package','pickup_wait')
      AND i.archived_at IS NULL AND a.archived_at IS NULL AND driver.archived_at IS NULL AND r.archived_at IS NULL
      AND r.fulfillment_kind='team' AND r.driver_id=a.driver_id AND a.state='acknowledged'
      AND a.version=o.assignment_version AND (o.delivery_id IS NULL OR d.id IS NOT NULL)`,
    [tenant, city, round, issue, session.principalId])).rows;
  // Same denial for missing, foreign, legacy-unbound or reassigned reports.
  if (rows.length !== 1) throw new CommandRejection('NOT_AUTHORIZED');
  const row = rows[0]!;
  const decisions = (await client.query(`SELECT id,decision_kind,instruction,decided_at,supersedes_id
    FROM rounds.issue_decisions WHERE tenant_id=$1 AND issue_id=$2 ORDER BY id LIMIT 201`, [tenant, issue])).rows;
  const latest = currentIssueDecision(decisions, row.state);
  const projected: Wire_DriverPickupIssueQueryResult['data']['decisions'] = [];
  if (latest) {
    if (latest.decision_kind === 'partial_pickup') throw new CommandRejection('FEATURE_NOT_ENABLED');
    const instruction = latest.instruction;
    if (!instruction || typeof instruction !== 'object' || Array.isArray(instruction) ||
        instruction.action !== latest.decision_kind || typeof instruction.instructions !== 'string' || !instruction.instructions.trim()) {
      throw new CommandRejection('SOURCE_STALE');
    }
    projected.push({ id: latest.id, decided_at: latest.decided_at.toISOString(), action: latest.decision_kind, instructions: instruction.instructions });
  }
  const result: Wire_DriverPickupIssueQueryResult = {
    as_of: new Date(now * 1000).toISOString(), next_cursor: null,
    data: { view: 'pickup_issue', principal_id: session.principalId, tenant_id: tenant, city_id: city, round_id: round,
      assignment_id: row.assignment_id, assignment_version: Number(row.assignment_version), observation_id: row.observation_id,
      issue_id: issue, issue_version: Number(row.issue_version), state: row.state, departure_gate: row.departure_gate,
      orders: row.delivery_id ? [{ delivery_id: row.delivery_id, readiness: row.readiness, preparation_state: row.preparation_state, outcome: row.outcome }] : [],
      decisions: projected },
  };
  // Stored malformed values are a stale projection, not partial success/ready.
  try { validatePickupIssueQuery(result); } catch { throw new CommandRejection('SOURCE_STALE'); }
  if (!Number.isSafeInteger(result.data.assignment_version) || !Number.isSafeInteger(result.data.issue_version) || Buffer.byteLength(JSON.stringify(result)) > 65536) throw new CommandRejection('SOURCE_STALE');
  return result;
}
