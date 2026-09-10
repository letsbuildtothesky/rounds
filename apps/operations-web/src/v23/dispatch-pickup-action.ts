import type {OperationsDeliveryBoard} from './operations-delivery-board';
import type {OperationsPickupIssues, PickupIssue} from './operations-pickup-issues';

/** A navigation join, never command permission. Names/current assignments are
 * not join keys. Round-only and resolved reports remain in the separate reader. */
export function pickupActionReports(board: Pick<OperationsDeliveryBoard,'scope'|'state'>, reports: Pick<OperationsPickupIssues,'scope'|'state'>): ReadonlyMap<string, readonly string[]> {
  const result = new Map<string, string[]>();
  if (!(['principalId','tenantId','cityId','serviceDate','sessionEpoch'] as const)
    .every(key => board.scope[key] === reports.scope[key])) return result;
  const delivery = board.state, report = reports.state;
  if (delivery.phase !== 'ready' || report.phase !== 'ready' || delivery.lastKnown || report.lastKnown) return result;
  const data = delivery.snapshot?.data, now = data?.now;
  if (!now || now.current_service_date !== board.scope.serviceDate) return result;
  const ids = new Set(data.deliveries.map(d => d.id));
  const actions = new Set(now.entries.filter(e => e.bucket === 'action' && e.reason === 'issue' && ids.has(e.delivery_id)).map(e => e.delivery_id));
  for (const issue of report.snapshot?.data.issues ?? []) {
    if (!issue.delivery_id || issue.state === 'resolved' || !actions.has(issue.delivery_id)) continue;
    const matches = result.get(issue.delivery_id) ?? [];
    matches.push(issue.issue_id); result.set(issue.delivery_id, matches);
  }
  return result;
}

export function reportsForDelivery(issues: readonly PickupIssue[], deliveryId: string | null): readonly PickupIssue[] {
  return deliveryId === null ? issues : issues.filter(i => i.delivery_id === deliveryId && i.state !== 'resolved');
}
