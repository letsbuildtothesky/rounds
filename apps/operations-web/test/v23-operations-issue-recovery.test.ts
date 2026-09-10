import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {test} from 'node:test';
import {OperationsPickupIssues, type OperationsIssueScope} from '../src/v23/operations-pickup-issues';
import {clearOperationsIssueLogin} from '../src/v23/operations-issue-recovery';

// Storage and Auth are labelled doubles; the actual journal/controller and HTTP
// byte handling run here. This is not a browser disk/lifecycle acceptance claim.
class MemoryStorage implements Storage {
  entries = new Map<string, string>();
  failRead = false; failWrite = false; failRemove = false; reads = 0;
  get length() { return this.entries.size; }
  key(index: number) { return [...this.entries.keys()][index] ?? null; }
  getItem(key: string) { this.reads++; if (this.failRead) throw new Error('blocked'); return this.entries.get(key) ?? null; }
  setItem(key: string, value: string) { if (this.failWrite) throw new Error('quota'); this.entries.set(key, value); }
  removeItem(key: string) { if (this.failRemove) throw new Error('blocked'); this.entries.delete(key); }
  clear() { throw new Error('Must never clear unrelated browser data'); }
}
function fixture() {
  const storage = new MemoryStorage(), loginId = randomUUID();
  const scope: OperationsIssueScope = {principalId: randomUUID(), tenantId: randomUUID(), cityId: randomUUID(), serviceDate: '2026-09-10', sessionEpoch: 1};
  let session: {principalId: string; sessionEpoch: number; bearer: string} | null = {principalId: scope.principalId, sessionEpoch: 1, bearer: 'test-only-bearer'};
  let currentLoginId: string | null = loginId;
  const issueId = randomUUID(), roundId = randomUUID(), assignmentId = randomUUID(), deliveryId = randomUUID();
  let version = 1, result: any = null;
  const calls: {url: string; init: RequestInit}[] = [];
  const board = () => ({as_of: new Date().toISOString(), next_cursor: null, data: {view: 'pickup_issues', principal_id: scope.principalId,
    tenant_id: scope.tenantId, city_id: scope.cityId, service_date: scope.serviceDate, issues: [{issue_id: issueId, issue_version: version,
      round_id: roundId, assignment_id: assignmentId, assignment_version: 1, delivery_id: deliveryId,
      state: version === 1 ? 'open' : 'decided', reported_at: '2026-09-10T00:00:00Z',
      report: {issue_type: 'package', reason_code: 'missing', detail: null, asset_ids: [], affected_lines: []},
      decisions: version === 1 ? [] : [{id: randomUUID(), decided_at: '2026-09-10T01:00:00Z', action: 'wait', instructions: 'Wait'}],
      allowed_actions: ['wait', 'escalate'], blocked_reason: null}]}});
  const error = (code: string, status: number) => Response.json({code, message_key: code, retryable: status >= 500, trace_id: 'fixture'}, {status});
  const commit = (bytes: string) => {
    const r = JSON.parse(bytes), root = {aggregate_type: 'issues', id: issueId, version: r.expected_versions[0].version + 1};
    version = root.version;
    result = {command_id: r.command_id, command_type: 'ResolveIssue', state: 'committed', current_versions: [root],
      resources: [{aggregate_type: 'issue_decisions', id: randomUUID(), version: 1}], data: {resource: root, state: 'decided'}};
    return result;
  };
  let handler = async (url: string, init: RequestInit): Promise<Response> => {
    if (url.includes('/commands/')) { commit(init.body as string); throw new TypeError('response lost after commit'); }
    if (url.includes('/CommandStatus?')) return result ? Response.json({as_of: new Date().toISOString(), next_cursor: null, data: {result}}) : error('NOT_FOUND', 404);
    return Response.json(board());
  };
  const open = (overrides: Partial<OperationsIssueScope> = {}, id = loginId) => new OperationsPickupIssues({baseUrl: 'http://127.0.0.1:8080',
    scope: {...scope, ...overrides}, session: () => session,
    recovery: {storage, loginId: id, currentLoginId: () => currentLoginId},
    fetch: (async (url: string | URL | Request, init: RequestInit) => {calls.push({url: String(url), init}); return handler(String(url), init);}) as typeof fetch});
  return {storage, scope, loginId, issueId, board, error, commit, open, calls,
    setVersion: (v: number) => version = v, handle: (h: typeof handler) => handler = h,
    auth: (s: typeof session, id: string | null = currentLoginId) => {session = s; currentLoginId = id;},
    posts: () => calls.filter(c => c.init.method === 'POST'),
    corrupt: (change: (v: any) => void) => {const [key, raw] = [...storage.entries][0]!; const v = JSON.parse(raw); change(v); storage.entries.set(key, JSON.stringify(v));}};
}

test('draft close/reopen preserves exact text but reveals nothing until a fresh authorized GET', async () => {
  const s = fixture(), first = s.open(); await first.refresh(); first.saveDraft(s.issueId, 'wait', '  Wait\n here  ', 'Private reason');
  assert(first.state.hasUnsavedWork); first.dispose(); const reads = s.storage.reads;
  const reopened = s.open(); assert.equal(reopened.state.draft, null); assert.equal(s.storage.reads, reads);
  await reopened.refresh(); assert.equal(reopened.state.draft!.instructions, '  Wait\n here  '); assert.equal(reopened.state.draft!.reason, 'Private reason');
  assert.equal(reopened.state.draftNeedsReview, false); assert.equal(s.posts().length, 0); reopened.dispose();
});
test('unknown send survives reload and recovers its receipt without a duplicate POST', async () => {
  const s = fixture(), first = s.open(); await first.refresh(); await first.send(s.issueId, 'wait', 'Wait', 'Reason');
  const id = first.state.pendingCommandId; first.dispose(); const reopened = s.open(); await reopened.refresh();
  assert.equal(reopened.state.pendingCommandId, id); assert(reopened.state.draftNeedsReview);
  await assert.rejects(reopened.send(s.issueId, 'wait', 'Replacement', 'Reason'), /RESULT_PENDING/);
  assert.throws(() => reopened.discardDraft(), /RESULT_PENDING/);
  await reopened.retry(); assert.equal(s.posts().length, 1); assert.equal(reopened.state.pendingCommandId, null); assert.equal(reopened.state.draft, null); reopened.dispose();
  const again = s.open(); await again.refresh(); assert.equal(again.state.hasUnsavedWork, false); again.dispose();
});
test('not-found retry after reload sends byte-identical original ID, time, version and text', async () => {
  const s = fixture(); s.handle(async (url) => url.includes('/Board?') ? Response.json(s.board()) : s.error(url.includes('/CommandStatus?') ? 'NOT_FOUND' : 'PROVIDER_UNAVAILABLE', url.includes('/CommandStatus?') ? 404 : 503));
  const first = s.open(); await first.refresh(); await first.send(s.issueId, 'escalate', ' Call shop\n', ' Internal '); first.dispose();
  const reopened = s.open(); await reopened.refresh(); assert.equal(s.posts().length, 1); await reopened.retry();
  assert.equal(s.posts().length, 2); assert.equal(s.posts()[0]!.init.body, s.posts()[1]!.init.body); reopened.dispose();
});
test('stale draft needs explicit review/discard, never adopts a new issue version', async () => {
  const s = fixture(), first = s.open(); await first.refresh(); first.saveDraft(s.issueId, 'wait', 'Old text', 'Reason'); first.dispose(); s.setVersion(2);
  const next = s.open(); await next.refresh(); assert(next.state.draftNeedsReview); assert.equal(next.state.draft!.issueVersion, 1);
  assert.throws(() => next.saveDraft(s.issueId, 'wait', 'New text', 'Reason'), /DRAFT_REVIEW_REQUIRED/); await assert.rejects(next.submitDraft(), /SOURCE_STALE/);
  next.discardDraft(); next.saveDraft(s.issueId, 'escalate', 'Reviewed text', 'Reason'); assert.equal(next.state.draft!.issueVersion, 2); next.dispose();
});
test('empty editable drafts persist but cannot submit until both fields are nonblank', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', '', '');
  await assert.rejects(c.submitDraft(), /VALIDATION_FAILED/); assert.equal(s.posts().length, 0); c.dispose();
  const n = s.open(); await n.refresh(); assert.equal(n.state.draft!.instructions, ''); n.discardDraft(); n.dispose();
});
test('storage quota failure blocks submission rather than silently falling back to memory', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); s.storage.failWrite = true;
  await assert.rejects(c.send(s.issueId, 'wait', 'Important text', 'Reason'), /RECOVERY_UNAVAILABLE/);
  assert.equal(c.state.draft!.instructions, 'Important text'); assert.equal(c.state.recoveryError, 'RECOVERY_UNAVAILABLE'); assert.equal(s.posts().length, 0); c.dispose();
});
test('failure saving frozen attempt sends zero bytes and disables replacement attempts', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Wait', 'Reason'); s.storage.failWrite = true;
  await assert.rejects(c.submitDraft(), /RECOVERY_UNAVAILABLE/); assert(c.state.pendingCommandId); assert.equal(s.posts().length, 0);
  await assert.rejects(c.retry(), /RECOVERY_UNAVAILABLE/); c.dispose();
});
test('failure saving received commit leaves durable original attempt recoverable', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); s.handle(async (url, init) => {
    if (url.includes('/commands/')) {const result = s.commit(init.body as string); s.storage.failWrite = true; return Response.json(result);}
    if (url.includes('/CommandStatus?')) return Response.json({as_of: new Date().toISOString(), next_cursor: null, data: {result: s.commit(s.posts()[0]!.init.body as string)}});
    return Response.json(s.board());
  });
  await c.send(s.issueId, 'wait', 'Wait', 'Reason'); assert.equal(c.state.recoveryError, 'RECOVERY_UNAVAILABLE'); c.dispose(); s.storage.failWrite = false;
  const n = s.open(); await n.refresh(); assert(n.state.pendingCommandId); await n.retry(); assert.equal(n.state.pendingCommandId, null); assert.equal(s.posts().length, 1); n.dispose();
});
test('two controller writers cannot overwrite each other or send a second independent attempt', async () => {
  const s = fixture(), a = s.open(), b = s.open(); await a.refresh(); await b.refresh(); a.saveDraft(s.issueId, 'wait', 'First', 'Reason');
  assert.throws(() => b.saveDraft(s.issueId, 'wait', 'Second', 'Reason'), /RECOVERY_CONFLICT/); assert.equal(s.posts().length, 0);
  b.dispose(true); a.dispose(); const n = s.open(); await n.refresh(); assert.equal(n.state.draft!.instructions, 'First'); n.dispose();
});
test('server unavailable after reload exposes neither draft nor a fabricated empty board', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Private', 'Reason'); c.dispose();
  s.handle(async () => s.error('PROVIDER_UNAVAILABLE', 503)); const n = s.open(); await n.refresh(); assert.equal(n.state.draft, null); assert.equal(n.state.snapshot, null); assert.equal(n.state.phase, 'failed'); n.dispose();
});
test('logout clears active private journal and cannot restore late content', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Private', 'Reason'); s.auth(null, null);
  assert.equal(c.state.phase, 'closed'); assert.equal(c.state.draft, null); assert.equal(s.storage.length, 0);
});
test('authorization refusal before hydration clears only the matching login journal', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Private', 'Reason'); c.dispose();
  s.storage.setItem('unrelated-draft', 'keep'); s.handle(async () => s.error('NOT_AUTHORIZED', 403)); const n = s.open(); await n.refresh();
  assert.equal(n.state.phase, 'closed'); assert.equal(s.storage.length, 1); assert.equal(s.storage.getItem('unrelated-draft'), 'keep');
});
test('different account/city keys cannot reveal a saved draft', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Private', 'Reason'); c.dispose();
  const n = s.open({cityId: randomUUID()}); await n.refresh(); assert.equal(n.state.draft, null); assert.equal(n.state.phase, 'failed'); n.dispose();
  const other = randomUUID(); s.auth({principalId: other, sessionEpoch: 1, bearer: 'other'}); const a = s.open({principalId: other}); await a.refresh(); assert.equal(a.state.draft, null); a.dispose();
});
test('new login cannot inherit private text even for the same principal', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Private', 'Reason'); c.dispose();
  const id = randomUUID(); s.auth({principalId: s.scope.principalId, sessionEpoch: 1, bearer: 'fresh'}, id); const n = s.open({}, id); await n.refresh(); assert.equal(n.state.draft, null); assert.equal(s.storage.length, 0); n.dispose();
});
test('login-wide teardown preserves other logins and unrelated storage', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Private', 'Reason'); c.dispose();
  s.storage.setItem('unrelated', 'keep'); s.storage.setItem('rounds:v23:pickup-reply:other', JSON.stringify({loginId: 'other'}));
  clearOperationsIssueLogin(s.storage, s.loginId); assert.equal(s.storage.length, 2); assert.equal(s.storage.getItem('unrelated'), 'keep');
});
for (const invalid of ['version', 'binding', 'unknown-field', 'draft', 'request', 'request-scope', 'request-action', 'versions']) test(`corrupt ${invalid} blocks recovery and never sends`, async () => {
  const s = fixture(), c = s.open(); await c.refresh(); await c.send(s.issueId, 'wait', 'Wait', 'Reason'); c.dispose();
  s.corrupt(v => {
    if (invalid === 'version') v.version = 99;
    if (invalid === 'binding') v.binding = 'wrong';
    if (invalid === 'unknown-field') v.value.secret = 'bad';
    if (invalid === 'draft') v.value.draft.issueVersion = 0;
    if (invalid === 'versions') v.value.committed = [['not-an-id', -1]];
    if (invalid.startsWith('request')) {const r = JSON.parse(v.value.pending); if (invalid === 'request') r.command_id = 'invalid';
      if (invalid === 'request-scope') r.context.tenant_id = randomUUID(); if (invalid === 'request-action') r.payload.decision.action = 'ready'; v.value.pending = JSON.stringify(r);}
  });
  const n = s.open(); await n.refresh(); assert.equal(n.state.phase, 'failed'); assert.equal(n.state.draft, null); assert(n.state.recoveryError?.startsWith('RECOVERY_'));
  await assert.rejects(n.retry(), /NO_RETRY_AVAILABLE/); assert.equal(s.posts().length, 1); n.dispose();
});
test('committed version floor survives reload and rejects a regressed server projection', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); await c.send(s.issueId, 'wait', 'Wait', 'Reason'); await c.retry(); c.dispose(); s.setVersion(1);
  const n = s.open(); await n.refresh(); assert.equal(n.state.errorCode, 'SOURCE_STALE'); assert.equal(n.state.snapshot, null); n.dispose();
});
test('journal contains no bearer, report projection or permissions', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); await c.send(s.issueId, 'wait', 'Wait', 'Reason');
  const raw = [...s.storage.entries.values()].join(''); assert(!raw.includes('test-only-bearer')); assert(!raw.includes('allowed_actions')); assert(!raw.includes('reported_at')); assert(!raw.includes('asset_ids')); c.dispose();
});
test('failed discard keeps the visible draft and reports storage failure', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Keep this', 'Reason'); s.storage.failWrite = true;
  assert.throws(() => c.discardDraft(), /RECOVERY_UNAVAILABLE/); assert.equal(c.state.draft!.instructions, 'Keep this'); assert(c.state.hasUnsavedWork); c.dispose();
});
test('blocked reads and oversized journals fail closed without modifying saved bytes', async () => {
  for (const oversized of [false, true]) {
    const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Keep', 'Reason'); c.dispose();
    if (oversized) s.storage.entries.set(s.storage.key(0)!, 'x'.repeat(131073)); else s.storage.failRead = true;
    const raw = [...s.storage.entries.values()][0]; const n = s.open(); await n.refresh(); assert.equal(n.state.phase, 'failed'); assert.equal(n.state.draft, null);
    assert.equal([...s.storage.entries.values()][0], raw); assert.equal(s.posts().length, 0); n.dispose();
  }
});
test('token renewal preserves the login scope, but a changed login closes and clears it', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Keep', 'Reason');
  s.auth({principalId: s.scope.principalId, sessionEpoch: 1, bearer: 'renewed'}); assert.equal(c.state.phase, 'ready'); await c.refresh();
  assert.deepEqual(s.calls.at(-1)!.init.headers, {authorization: 'Bearer renewed'});
  s.auth({principalId: s.scope.principalId, sessionEpoch: 1, bearer: 'renewed'}, randomUUID()); assert.equal(c.state.phase, 'closed'); assert.equal(s.storage.length, 0);
});
test('failed private-journal erasure is surfaced, not silently reported successful', async () => {
  const s = fixture(), c = s.open(); await c.refresh(); c.saveDraft(s.issueId, 'wait', 'Private', 'Reason'); s.storage.failRemove = true; s.auth(null, null);
  assert.equal(c.state.phase, 'closed'); assert.equal(c.state.draft, null); assert.equal(c.state.recoveryError, 'RECOVERY_UNAVAILABLE'); assert.equal(s.storage.length, 1);
});
