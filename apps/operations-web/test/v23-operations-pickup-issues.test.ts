import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { OperationsPickupIssues, type OperationsIssueScope } from '../src/v23/operations-pickup-issues';

function setup() {
  const scope: OperationsIssueScope = {principalId: randomUUID(), tenantId: randomUUID(), cityId: randomUUID(), serviceDate: '2026-09-10', sessionEpoch: 1};
  let session: {principalId: string; sessionEpoch: number; bearer: string} | null = {principalId: scope.principalId, sessionEpoch: 1, bearer: 'test-only'};
  let version = 1; const issue = randomUUID(), round = randomUUID(), assignment = randomUUID();
  const calls: {url: string; init: RequestInit}[] = [];
  const board = () => ({as_of: '2026-09-10T00:00:00Z', next_cursor: null, data: {view: 'pickup_issues', principal_id: scope.principalId,
    tenant_id: scope.tenantId, city_id: scope.cityId, service_date: scope.serviceDate, issues: [{issue_id: issue, issue_version: version,
      round_id: round, assignment_id: assignment, assignment_version: 1, delivery_id: randomUUID(), state: 'open', reported_at: '2026-09-10T00:00:00Z',
      report: {issue_type: 'package', reason_code: 'missing', detail: null, asset_ids: [], affected_lines: []}, decisions: [], allowed_actions: ['wait', 'escalate'], blocked_reason: null}]}});
  // Stable identity across reads; never derive delivery IDs from row positions.
  const delivery = randomUUID(); const snapshot = () => {const b = board(); b.data.issues[0]!.delivery_id = delivery; return b;};
  const error = (code: string, status = 503) => Response.json({code, message_key: code, retryable: status >= 500, trace_id: 'test-only'}, {status});
  const receipt = (request: any) => {const root = {aggregate_type: 'issues', id: request.payload.issue_id, version: request.expected_versions[0].version + 1};
    return {command_id: request.command_id, command_type: 'ResolveIssue', state: 'committed', current_versions: [root], resources: [{aggregate_type: 'issue_decisions', id: randomUUID(), version: 1}], data: {resource: root, state: 'decided'}};};
  let handle: (url: string, init: RequestInit) => Promise<Response> = async () => Response.json(snapshot());
  const client = new OperationsPickupIssues({baseUrl: 'http://127.0.0.1:8080', scope, session: () => session,
    fetch: (async (url: string | URL | Request, init: RequestInit) => {calls.push({url: String(url), init}); return handle(String(url), init);}) as typeof fetch});
  return {client, scope, issue, calls, snapshot, error, receipt, setVersion: (v: number) => version = v,
    setSession: (s: typeof session) => session = s, handle: (h: typeof handle) => handle = h};
}
const deferred = <T>() => {let resolve!: (value: T) => void; const promise = new Promise<T>(r => resolve = r); return {promise, resolve};};

test('browser validator is generated static code, not unsafe-eval compilation', () => {
  const code = readFileSync(new URL('../src/v23/generated/operations-issue-validation.cjs', import.meta.url), 'utf8');
  assert(!/new Function\b|\beval\(/.test(code));
});

test('scoped GET, immutable projection, no legacy/device headers or browser cache', async () => {
  const s = setup(); await s.client.refresh(); const call = s.calls[0]!;
  assert.equal(s.client.state.phase, 'ready'); assert.equal(call.init.cache, 'no-store'); assert.equal(call.init.credentials, 'omit'); assert.equal(call.init.redirect, 'error');
  assert.deepEqual(call.init.headers, {authorization: 'Bearer test-only'}); assert(new URL(call.url).searchParams.get('city_id') === s.scope.cityId);
  assert(Object.isFrozen(s.client.state.snapshot!.data.issues[0]));
  assert.equal(Reflect.set(s.client.state.snapshot!.data.issues[0]!, 'issue_version', 8), false);
  assert.equal(s.client.state.snapshot!.data.issues[0]!.issue_version, 1); s.client.dispose();
});
test('explicit wait command uses displayed issue version and exact untrimmed instructions/reason', async () => {
  const s = setup(); await s.client.refresh(); s.handle(async (url, init) => {
    if (url.includes('/commands/')) {const r = JSON.parse(init.body as string); assert.deepEqual(r.expected_versions, [{aggregate_type: 'issues', id: s.issue, version: 1}]);
      assert.deepEqual(r.payload.decision, {action: 'wait', instructions: '  Wait\nhere  ', quantities: []}); assert.equal(r.payload.reason, ' Private reason ');
      s.setVersion(2); return Response.json(s.receipt(r));} return Response.json(s.snapshot());
  });
  await s.client.send(s.issue, 'wait', '  Wait\nhere  ', ' Private reason ');
  assert.equal(s.client.state.snapshot!.data.issues[0]!.issue_version, 2); assert.equal(s.client.state.pendingCommandId, null); s.client.dispose();
});
test('lost response recovers original receipt without second POST', async () => {
  const s = setup(); await s.client.refresh(); let result: unknown;
  s.handle(async (url, init) => {
    if (url.includes('/commands/')) {result = s.receipt(JSON.parse(init.body as string)); s.setVersion(2); throw new TypeError('connection lost');}
    if (url.includes('/CommandStatus?')) return Response.json({as_of: '2026-09-10T01:00:00Z', next_cursor: null, data: {result}});
    return Response.json(s.snapshot());
  });
  await s.client.send(s.issue, 'escalate', 'Call the shop', 'Reason'); assert.equal(s.client.state.errorCode, 'UNKNOWN_RESULT'); assert(s.client.state.pendingCommandId);
  await assert.rejects(s.client.send(s.issue, 'wait', 'New text', 'Reason'), /RESULT_PENDING/);
  await s.client.retry(); assert.equal(s.calls.filter(c => c.init.method === 'POST').length, 1); assert.equal(s.client.state.phase, 'ready'); s.client.dispose();
});
test('404 status resends identical original bytes; 503 never sends a replacement', async () => {
  const s = setup(); await s.client.refresh(); let unavailable = true;
  s.handle(async (url) => url.includes('/CommandStatus?') ? s.error(unavailable ? 'PROVIDER_UNAVAILABLE' : 'NOT_FOUND', unavailable ? 503 : 404) : s.error('PROVIDER_UNAVAILABLE'));
  await s.client.send(s.issue, 'wait', 'Wait', 'Reason'); await s.client.retry(); assert.equal(s.calls.filter(c => c.init.method === 'POST').length, 1);
  unavailable = false; await s.client.retry(); const posts = s.calls.filter(c => c.init.method === 'POST'); assert.equal(posts.length, 2); assert.equal(posts[0]!.init.body, posts[1]!.init.body); s.client.dispose();
});
test('network read retains last-known information but cannot authorize a new reply', async () => {
  const s = setup(); await s.client.refresh(); s.handle(async () => {throw new Error('offline');}); await s.client.refresh();
  assert.equal(s.client.state.lastKnown, true); await assert.rejects(s.client.send(s.issue, 'wait', 'Wait', 'Reason'), /SOURCE_STALE/); s.client.dispose();
});
test('first failed read is unavailable, not an empty board', async () => {
  const s = setup(); s.handle(async () => s.error('PROVIDER_UNAVAILABLE')); await s.client.refresh(); assert.equal(s.client.state.phase, 'failed'); assert.equal(s.client.state.snapshot, null); s.client.dispose();
});
for (const change of ['account', 'epoch', 'logout', 'dispose']) test(`late response cannot restore data after ${change}`, async () => {
  const s = setup(), d = deferred<Response>(); s.handle(async () => d.promise); const reading = s.client.refresh(); await Promise.resolve();
  if (change === 'dispose') s.client.dispose(); else s.setSession(change === 'logout' ? null : {principalId: change === 'account' ? randomUUID() : s.scope.principalId, sessionEpoch: change === 'epoch' ? 2 : 1, bearer: 'new'});
  d.resolve(Response.json(s.snapshot())); await reading; assert.equal(s.client.state.phase, 'closed'); assert.equal(s.client.state.snapshot, null);
});
test('authorization rejection clears old private data and pending command', async () => {
  const s = setup(); await s.client.refresh(); s.handle(async () => s.error('NOT_AUTHORIZED', 403)); await s.client.send(s.issue, 'wait', 'Wait', 'Reason'); assert.equal(s.client.state.phase, 'closed'); assert.equal(s.client.state.snapshot, null); assert.equal(s.client.state.pendingCommandId, null);
});
for (const wrong of ['tenant', 'city', 'date', 'actor', 'duplicate', 'unsafe-version', 'malformed', 'scope']) test(`rejects ${wrong} projection`, async () => {
  const s = setup(); await s.client.refresh(); const b = s.snapshot();
  if (wrong === 'tenant') b.data.tenant_id = randomUUID(); if (wrong === 'city') b.data.city_id = randomUUID();
  if (wrong === 'date') b.data.service_date = '2026-09-11'; if (wrong === 'actor') b.data.principal_id = randomUUID();
  if (wrong === 'duplicate') b.data.issues.push(b.data.issues[0]!); if (wrong === 'unsafe-version') b.data.issues[0]!.issue_version = Number.MAX_SAFE_INTEGER + 1;
  if (wrong === 'malformed') (b as any).secret = 'not allowed'; if (wrong === 'scope') b.data.issues[0]!.assignment_version = 2;
  s.handle(async () => Response.json(b)); await s.client.refresh(); assert.equal(s.client.state.phase, 'failed'); assert(s.client.state.lastKnown); s.client.dispose();
});
test('regressed issue version and disabled action cannot be submitted', async () => {
  const s = setup(); s.setVersion(3); await s.client.refresh(); s.setVersion(2); await s.client.refresh(); assert.equal(s.client.state.errorCode, 'SOURCE_STALE'); s.client.dispose();
  const z = setup(), b = z.snapshot(); b.data.issues[0]!.allowed_actions = []; (b.data.issues[0] as any).blocked_reason = 'ORIGINAL_SCOPE_UNAVAILABLE'; z.handle(async () => Response.json(b)); await z.client.refresh();
  await assert.rejects(z.client.send(z.issue, 'wait', 'Wait', 'Reason'), /SOURCE_STALE/); z.client.dispose();
});
test('coalesces reads; oversized response never replaces good state', async () => {
  const s = setup(), d = deferred<Response>(); s.handle(async () => d.promise); const a = s.client.refresh(), b = s.client.refresh(); assert.equal(a, b);
  d.resolve(Response.json(s.snapshot())); await a; assert.equal(s.calls.length, 1);
  s.handle(async () => new Response('x'.repeat(65537))); await s.client.refresh(); assert.equal(s.client.state.errorCode, 'INVALID_RESPONSE'); assert(s.client.state.lastKnown); s.client.dispose();
});
test('rejects blank/oversized/unsupported actions before any POST', async () => {
  const s = setup(); await s.client.refresh();
  for (const text of ['', '  ', 'x'.repeat(4001)]) await assert.rejects(s.client.send(s.issue, 'wait', text, 'reason'), /VALIDATION_FAILED/);
  await assert.rejects(s.client.send(s.issue, 'wait', 'Wait', ''), /VALIDATION_FAILED/);
  await assert.rejects(s.client.send(s.issue, 'ready' as any, 'Go', 'reason'), /SOURCE_STALE/); assert.equal(s.calls.length, 1); s.client.dispose();
});
test('mismatched or malformed successful receipt remains unknown, never successful', async () => {
  const s = setup(); await s.client.refresh(); s.handle(async (_url, init) => {const r = s.receipt(JSON.parse(init.body as string)); r.command_id = randomUUID(); return Response.json(r);});
  await s.client.send(s.issue, 'wait', 'Wait', 'reason'); assert.equal(s.client.state.errorCode, 'UNKNOWN_RESULT'); assert(s.client.state.pendingCommandId); s.client.dispose();
});
test('stale-version rejection preserves display but requires explicit refresh/review', async () => {
  const s = setup(); await s.client.refresh(); s.handle(async () => s.error('STALE_VERSION', 409)); await s.client.send(s.issue, 'wait', 'Wait', 'reason');
  assert.equal(s.client.state.errorCode, 'STALE_VERSION'); assert.equal(s.client.state.pendingCommandId, null); assert(s.client.state.lastKnown);
  await assert.rejects(s.client.send(s.issue, 'wait', 'Wait', 'reason'), /SOURCE_STALE/); s.client.dispose();
});

test('successful send waits out an older read and fetches a post-commit snapshot', async () => {
  const s = setup(); await s.client.refresh(); const d = deferred<Response>(), started = deferred<void>();
  const old = s.snapshot(); let oldRead = true, background: Promise<void> | null = null;
  s.client.subscribe(() => {if (s.client.state.sending && !background) {background = Promise.resolve(); background = s.client.refresh();}});
  s.handle(async (url, init) => {
    if (url.includes('/commands/')) {s.setVersion(2); started.resolve(); return Response.json(s.receipt(JSON.parse(init.body as string)));}
    if (oldRead) {oldRead = false; return d.promise;} return Response.json(s.snapshot());
  });
  const sending = s.client.send(s.issue, 'wait', 'Wait', 'reason'); await started.promise; d.resolve(Response.json(old)); await sending;
  assert.equal(s.client.state.snapshot!.data.issues[0]!.issue_version, 2); s.client.dispose();
});
test('post-commit stale server projection is last-known, never new reply authority', async () => {
  const s = setup(); await s.client.refresh();
  s.handle(async (url, init) => Response.json(url.includes('/commands/') ? s.receipt(JSON.parse(init.body as string)) : s.snapshot()));
  await s.client.send(s.issue, 'wait', 'Wait', 'reason'); assert.equal(s.client.state.errorCode, 'SOURCE_STALE');
  assert.equal(s.client.state.pendingCommandId, null); assert(s.client.state.lastKnown); s.client.dispose();
});
test('late send result after same-account reauthentication clears pending content', async () => {
  const s = setup(); await s.client.refresh(); const d = deferred<Response>(); let request: any;
  s.handle(async (_url, init) => {request = JSON.parse(init.body as string); return d.promise;});
  const sending = s.client.send(s.issue, 'wait', 'Private instructions', 'Internal reason');
  s.setSession({principalId: s.scope.principalId, sessionEpoch: 2, bearer: 'new'});
  d.resolve(Response.json(s.receipt(request))); await sending; assert.equal(s.client.state.phase, 'closed'); assert.equal(s.client.state.pendingCommandId, null); assert.equal(s.client.state.snapshot, null);
});
