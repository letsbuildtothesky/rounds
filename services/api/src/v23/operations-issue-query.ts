import type { PoolClient } from 'pg';
import type { Wire_OperationsPickupIssuesQueryResult } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { currentIssueDecision } from './issue-decision-chain.js';
import { originalScope, requirePickupDecisionJob } from './resolve-pickup-issue.js';
import { validateOperationsIssuesQuery } from './pickup-validation.js';
import { CommandRejection, type CommandAuthority } from './transaction-runner.js';

export const operationsBoardPath = '/v1/queries/Board';

/** ADR-Q05: finite discovery under the existing Board query, not a replacement
 * board. Caller holds current issues.decide authorization in one restricted
 * repeatable-read transaction. No receipts, writes, asset URLs or driver IDs. */
export async function projectOperationsPickupIssues(client: PoolClient, auth: CommandAuthority, date: string, includeDisplay = false): Promise<Wire_OperationsPickupIssuesQueryResult> {
  const reports = (await client.query(`SELECT i.id,i.version,i.state,i.reported_at,i.issue_type,i.reason_code,i.detail,
      o.round_id,o.assignment_id,o.assignment_version,o.delivery_id,o.payload
    FROM rounds.issue_report_observations o
    JOIN rounds.issues i ON i.tenant_id=o.tenant_id AND i.id=o.issue_id AND i.round_id=o.round_id
    JOIN rounds.rounds r ON r.tenant_id=o.tenant_id AND r.id=o.round_id AND r.city_id=o.city_id
    WHERE o.tenant_id=$1 AND o.city_id=$2 AND r.service_date=$3
      AND i.archived_at IS NULL AND r.archived_at IS NULL AND r.fulfillment_kind='team'
      AND i.reported_by=o.actor_id AND i.delivery_id IS NOT DISTINCT FROM o.delivery_id
      AND i.trip_id IS NULL AND i.attempt_id IS NULL AND i.issue_type IN ('package','pickup_wait')
    ORDER BY i.reported_at,i.id LIMIT 201`, [auth.tenantId, auth.cityId, date])).rows;
  // This first finite view never silently truncates. Full board paging is separate.
  if (reports.length > 200) throw new CommandRejection('FEATURE_NOT_ENABLED');
  const issues: Wire_OperationsPickupIssuesQueryResult['data']['issues'] = [];
  for (const report of reports) {
    const history = (await client.query(`SELECT id,decision_kind,instruction,decided_at,supersedes_id
      FROM rounds.issue_decisions WHERE tenant_id=$1 AND issue_id=$2 ORDER BY id LIMIT 201`, [auth.tenantId, report.id])).rows;
    const tip = currentIssueDecision(history, report.state);
    const decisions: typeof issues[number]['decisions'] = [];
    if (tip) {
      if (tip.decision_kind === 'partial_pickup') throw new CommandRejection('FEATURE_NOT_ENABLED');
      if (tip.instruction?.action !== tip.decision_kind || typeof tip.instruction?.instructions !== 'string' || !tip.instruction.instructions.trim()) throw new CommandRejection('SOURCE_STALE');
      decisions.push({id: tip.id, decided_at: tip.decided_at.toISOString(), action: tip.decision_kind, instructions: tip.instruction.instructions});
    }
    let blocked: typeof issues[number]['blocked_reason'] = report.state === 'resolved' ? 'ISSUE_RESOLVED' : history.length >= 200 ? 'DECISION_LIMIT' : null;
    if (!blocked) {
      try { await requirePickupDecisionJob(client, auth, await originalScope(client, auth, report.id), false); }
      catch (e) {
        if (!(e instanceof CommandRejection) || e.code !== 'NOT_AUTHORIZED') throw e;
        blocked = 'ORIGINAL_SCOPE_UNAVAILABLE';
      }
    }
    issues.push({issue_id: report.id, issue_version: Number(report.version), state: report.state,
      round_id: report.round_id, assignment_id: report.assignment_id, assignment_version: Number(report.assignment_version), delivery_id: report.delivery_id,
      reported_at: report.reported_at.toISOString(), report: {issue_type: report.issue_type, reason_code: report.reason_code,
        detail: report.detail, asset_ids: report.payload?.asset_ids, affected_lines: report.payload?.affected_lines},
      decisions, allowed_actions: blocked ? [] : ['wait', 'escalate'], blocked_reason: blocked,
      ...(includeDisplay ? {display: await issueDisplay(client, auth, report.id, blocked === 'ORIGINAL_SCOPE_UNAVAILABLE')} : {})});
  }
  const result: Wire_OperationsPickupIssuesQueryResult = {as_of: new Date().toISOString(), next_cursor: null,
    data: {view: 'pickup_issues', principal_id: auth.principalId, tenant_id: auth.tenantId!, city_id: auth.cityId!, service_date: date, issues}};
  try { validateOperationsIssuesQuery(result); } catch { throw new CommandRejection('SOURCE_STALE'); }
  if (Buffer.byteLength(JSON.stringify(result)) > 65536) throw new CommandRejection('FEATURE_NOT_ENABLED');
  return result;
}

type Display = NonNullable<Wire_OperationsPickupIssuesQueryResult['data']['issues'][number]['display']>;
const unavailableDisplay = (): Display => ({delivery_reference: null, recipient_name: null,
  destination_address: null, pickup_site_name: null, reported_driver_name: null});
const label = (value: unknown, max = 200): string | null =>
  typeof value === 'string' && value.trim() && [...value].length <= max ? value : null;

/** Current labels on the SAME original report only. No table-wide profile
 * read, current-driver substitution, name matching or sensitive column SELECT.
 * Null presentation data never conceals the report or grants an action. */
async function issueDisplay(client: PoolClient, auth: CommandAuthority, issueId: string, changedJob: boolean): Promise<Display> {
  if (changedJob) return unavailableDisplay();
  const rows = (await client.query(`SELECT d.human_reference,d.address_text,s.name AS site_name,p.display_name AS driver_name,
      (SELECT array_agg(c.display_name) FROM
        (SELECT c.display_name FROM rounds.delivery_contacts c
         WHERE c.tenant_id=d.tenant_id AND c.delivery_id=d.id AND c.role='recipient' AND c.archived_at IS NULL
         ORDER BY c.id LIMIT 2) c) AS recipients
    FROM rounds.issue_report_observations o
    JOIN rounds.issues i ON i.tenant_id=o.tenant_id AND i.id=o.issue_id AND i.reported_by=o.actor_id
    JOIN rounds.rounds r ON r.tenant_id=o.tenant_id AND r.city_id=o.city_id AND r.id=o.round_id
    LEFT JOIN rounds.deliveries d ON d.tenant_id=o.tenant_id AND d.city_id=o.city_id AND d.id=o.delivery_id AND d.archived_at IS NULL
    LEFT JOIN rounds.sites s ON s.tenant_id=o.tenant_id AND s.city_id=o.city_id AND s.id=r.pickup_site_id AND s.archived_at IS NULL
    LEFT JOIN rounds.drivers dr ON dr.id=i.driver_id AND dr.principal_id=o.actor_id AND dr.archived_at IS NULL
      AND EXISTS(SELECT 1 FROM rounds.driver_relationships rel WHERE rel.tenant_id=o.tenant_id
        AND rel.driver_id=dr.id AND rel.relationship_kind='team' AND rel.status='active' AND rel.archived_at IS NULL)
    LEFT JOIN rounds.principals p ON p.id=dr.principal_id
    WHERE o.tenant_id=$1 AND o.city_id=$2 AND o.issue_id=$3`, [auth.tenantId, auth.cityId, issueId])).rows;
  if (rows.length !== 1) return unavailableDisplay();
  const row = rows[0];
  return {delivery_reference: label(row.human_reference), destination_address: label(row.address_text, 2000),
    recipient_name: row.recipients?.length === 1 ? label(row.recipients[0]) : null,
    pickup_site_name: label(row.site_name), reported_driver_name: label(row.driver_name)};
}
