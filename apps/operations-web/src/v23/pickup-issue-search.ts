import type {PickupIssue} from './operations-pickup-issues';

/** Local filtering of the currently authorized, bounded report projection.
 * It is not a global delivery search and never changes commands or drafts. */
export function filterPickupIssues(issues: readonly PickupIssue[], query: string): readonly PickupIssue[] {
  const terms = query.trim().toLocaleLowerCase('en').split(/\s+/).filter(Boolean);
  if (!terms.length) return issues;
  return issues.filter(issue => {
    const text = [issue.display?.delivery_reference, issue.display?.recipient_name,
      issue.display?.destination_address, issue.display?.pickup_site_name,
      issue.display?.reported_driver_name, issue.report.reason_code,
      issue.issue_id, issue.delivery_id, issue.round_id].filter(Boolean).join(' ').toLocaleLowerCase('en');
    return terms.every(term => text.includes(term));
  });
}
