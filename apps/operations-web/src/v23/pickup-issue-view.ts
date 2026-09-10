import type {OperationsPickupIssues, PickupIssue} from './operations-pickup-issues';

export type IssueState = OperationsPickupIssues['state'];
export const replyActions = [{id: 'wait', label: 'Ask driver to wait'}, {id: 'escalate', label: 'Escalate'}] as const;
export function issueTitle(issue: PickupIssue): string {
  if (issue.report.issue_type === 'pickup_wait') return 'Waiting at pickup';
  return ({damaged: 'Damaged package', missing: 'Missing package', wrong: 'Wrong package'} as Record<string, string>)[issue.report.reason_code] ?? 'Package problem';
}
export function blockedReason(issue: PickupIssue): string | null {
  return issue.blocked_reason === 'ORIGINAL_SCOPE_UNAVAILABLE' ? 'The original assignment has changed. A reply cannot be sent to this work.' :
    issue.blocked_reason === 'ISSUE_RESOLVED' ? 'This issue is resolved.' :
    issue.blocked_reason === 'DECISION_LIMIT' ? 'This issue has reached its decision limit.' : null;
}
export function canSubmitReply(state: IssueState): boolean {
  const d = state.draft;
  return state.phase === 'ready' && !!d && !state.sending && !state.pendingCommandId && !state.draftNeedsReview && !state.recoveryError &&
    !!d.instructions.trim() && !!d.reason.trim() && [...d.instructions].length <= 4000 && [...d.reason].length <= 4000;
}
export function issueErrorText(code: string | null): string | null {
  if (!code) return null;
  if (code.startsWith('RECOVERY_')) return 'The browser could not safely save or recover this reply. Sending is blocked. Keep this tab open and do not clear browser data.';
  return ({SOURCE_STALE: 'The issue has changed. Refresh and review it before replying.',
    VALIDATION_FAILED: 'Enter driver instructions and an internal reason (up to 4,000 characters each).',
    DRAFT_REVIEW_REQUIRED: 'Review the existing draft before starting another reply.',
    RESULT_PENDING: 'The earlier reply still needs its result checked.',
    UNKNOWN_RESULT: 'The reply result is not confirmed. Check its status before trying again.',
    NOT_AUTHORIZED: 'You no longer have permission to view or reply to these issues.',
    SESSION_CHANGED: 'Your sign-in changed. Reopen this workspace after signing in.',
    AUTH_SESSION_UNAVAILABLE: 'A verified sign-in session is required.'} as Record<string, string>)[code] ?? 'Issues could not be refreshed. Any previous information is last known, not current.';
}
