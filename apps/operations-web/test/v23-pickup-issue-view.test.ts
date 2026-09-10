import assert from 'node:assert/strict';
import {test} from 'node:test';
import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {OperationsPickupIssues} from '../src/v23/operations-pickup-issues';
import {OperationsIssueLogin, verifiedIssueLogin} from '../src/v23/operations-issue-login';
import {canSubmitReply, issueTitle, blockedReason, issueErrorText} from '../src/v23/pickup-issue-view';
import {PickupIssueDrawer} from '../src/v23/pickup-issue-drawer';

test('Dispatch cards use the final approved queue values, not superseded base CSS', () => {
  const css = readFileSync(new URL('../src/v23/pickup-issue-drawer.css', import.meta.url), 'utf8');
  const source = readFileSync(new URL('../../../specs/source/Rounds-Complete-Project-v2.3/ui/dispatch/index.html', import.meta.url), 'utf8');
  const rule = (text: string, selector: string) => text.slice(text.lastIndexOf(selector)).split('}')[0].replaceAll(/\s/g, '');
  const card = rule(css, '.pickup-issues .delivery-card {');
  const approved = rule(source, '.delivery-panel .delivery-card,.delivery-panel .plan-delivery-card{');
  for (const value of ['margin:0 0 6px','padding:16px 12px 12px','border-radius:9px','border-bottom-color:#e2e7ed']) {
    assert(card.includes(value.replaceAll(' ', ''))); assert(approved.includes(value.replaceAll(' ', '')));
  }
  assert(rule(css, '.pickup-issues .card-name {').includes('font-weight:650'));
  assert(rule(css, '.pickup-issues .card-address {').includes('font-size:12px'));
  assert(rule(css, '.pickup-issues .card-status {').includes('font-size:11px'));
  assert(rule(css, '.pickup-issues .card-next {').includes('min-height:36px'));
});

class StorageDouble implements Storage {
  entries = new Map<string, string>(); failRemove = false;
  get length() { return this.entries.size; }
  key(i: number) { return [...this.entries.keys()][i] ?? null; }
  getItem(k: string) { return this.entries.get(k) ?? null; }
  setItem(k: string, v: string) { this.entries.set(k, v); }
  removeItem(k: string) { if (this.failRemove) throw new Error('denied'); this.entries.delete(k); }
  clear() { throw new Error('Unrelated data must remain'); }
}
function loginFixture() {
  const storage = new StorageDouble(), subject = randomUUID(), authSessionId = randomUUID();
  return {storage, verified: {subject, authSessionId, bearer: 'test-only-token'},
    open: () => new OperationsIssueLogin(storage, 'https://auth.example', 'https://api.example')};
}
test('verified login metadata rejects mismatched subject, absent session ID and expiry', () => {
  const sub = randomUUID(), session_id = randomUUID();
  const token = (data: object) => 'header.' + Buffer.from(JSON.stringify(data)).toString('base64url') + '.signature';
  const claims = {sub, session_id, exp: Date.now() / 1000 + 60};
  assert.equal(verifiedIssueLogin(token(claims), sub).authSessionId, session_id);
  for (const bad of [{...claims, sub: randomUUID()}, {...claims, session_id: null}, {...claims, exp: 1}]) assert.throws(() => verifiedIssueLogin(token(bad), sub), /AUTH_SESSION_UNAVAILABLE/);
});
test('login ID is stable across token renewal and host reload, never stores bearer', () => {
  const f = loginFixture(), id = f.open().bind(f.verified);
  assert.equal(f.open().bind({...f.verified, bearer: 'renewed-test-token'}), id);
  assert(!JSON.stringify([...f.storage.entries]).includes('token'));
});
test('new authentication even for the same account rotates identity and erases old journals in all scopes', () => {
  const f = loginFixture(), h = f.open(), id = h.bind(f.verified);
  f.storage.setItem('rounds:v23:pickup-reply:city-one', JSON.stringify({loginId: id}));
  f.storage.setItem('rounds:v23:pickup-reply:city-two', JSON.stringify({loginId: id}));
  f.storage.setItem('legacy-photos', 'keep');
  assert.notEqual(h.bind({...f.verified, authSessionId: randomUUID()}), id);
  assert.equal(f.storage.getItem('rounds:v23:pickup-reply:city-one'), null);
  assert.equal(f.storage.getItem('rounds:v23:pickup-reply:city-two'), null);
  assert.equal(f.storage.getItem('legacy-photos'), 'keep');
});
test('logout before a mounted drawer erases the old login but preserves unrelated sessions', () => {
  const f = loginFixture(), h = f.open(), id = h.bind(f.verified);
  f.storage.setItem('rounds:v23:pickup-reply:owned', JSON.stringify({loginId:id}));
  f.storage.setItem('rounds:v23:pickup-reply:other', JSON.stringify({loginId:randomUUID()}));
  f.open().clear(); assert.equal(f.storage.getItem(h.key), null);
  assert.equal(f.storage.getItem('rounds:v23:pickup-reply:owned'), null);
  assert(f.storage.getItem('rounds:v23:pickup-reply:other'));
});
test('failed erasure prevents new login binding and preserves the departing record', () => {
  const f = loginFixture(), h = f.open(), id = h.bind(f.verified);
  f.storage.setItem('rounds:v23:pickup-reply:owned', JSON.stringify({loginId:id})); f.storage.failRemove = true;
  assert.throws(() => h.bind({...f.verified, authSessionId:randomUUID()}), /RECOVERY_UNAVAILABLE/);
  assert.equal(JSON.parse(f.storage.getItem(h.key)!).loginId, id);
});
test('corrupt login binding fails closed without deleting unknown data', () => {
  const f = loginFixture(), h = f.open(); f.storage.setItem(h.key, '{corrupt');
  assert.throws(() => h.bind(f.verified), /RECOVERY_CORRUPT/); assert.equal(f.storage.getItem(h.key), '{corrupt');
});

async function viewFixture(empty = false) {
  const id = randomUUID(), scope = {principalId:randomUUID(),tenantId:randomUUID(),cityId:randomUUID(),serviceDate:'2026-09-10',sessionEpoch:1};
  const board = {as_of:'2026-09-10T00:00:00Z',next_cursor:null,data:{view:'pickup_issues',principal_id:scope.principalId,tenant_id:scope.tenantId,city_id:scope.cityId,service_date:scope.serviceDate,
    issues:empty ? [] : [{issue_id:id,issue_version:1,round_id:randomUUID(),assignment_id:randomUUID(),assignment_version:1,delivery_id:null,state:'open',reported_at:'2026-09-10T00:00:00Z',report:{issue_type:'pickup_wait',reason_code:'waiting',detail:'<script>unsafe</script>',asset_ids:[],affected_lines:[]},decisions:[],allowed_actions:['wait','escalate'],blocked_reason:null}]}};
  const controller = new OperationsPickupIssues({baseUrl:'https://api.example',scope,session:()=>({principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'}),fetch:async()=>Response.json(board)});
  return {controller,id,board};
}
test('SSR does not say no issues before the first authorized response', async () => {
  const {controller} = await viewFixture();
  assert(!renderToStaticMarkup(createElement(PickupIssueDrawer,{controller})).includes('No pickup issues'));
});
test('authorized empty state is distinct from failures and never includes demo data', async () => {
  const {controller} = await viewFixture(true); await controller.refresh();
  const markup = renderToStaticMarkup(createElement(PickupIssueDrawer,{controller}));
  assert(markup.includes('No pickup issues')); assert(!markup.includes('Siriporn')); controller.dispose();
});
test('round-only list remains round-only and original root IDs are not invented', async () => {
  const {controller,id} = await viewFixture(); await controller.refresh();
  const markup = renderToStaticMarkup(createElement(PickupIssueDrawer,{controller}));
  assert(markup.includes('Round-only report')); assert(!markup.includes('<script>unsafe'));
  assert.equal(controller.state.snapshot!.data.issues[0]!.issue_id,id);
  assert.equal(issueTitle(controller.state.snapshot!.data.issues[0]!), 'Waiting at pickup');
  assert.equal(controller.state.snapshot!.data.issues[0]!.delivery_id, null); controller.dispose();
});

const displayFixture = () => ({delivery_reference:'UF-TEST-001',recipient_name:'Siriporn <script>test</script>',destination_address:'Test destination\nSecond line',pickup_site_name:'Synthetic pickup',reported_driver_name:'Johannes test'});
test('display opt-in is explicit and source cards escape authorized labels instead of interpreting markup',async()=>{
  const f=await viewFixture(),scope=f.controller.scope;let url='';
  Object.assign(f.board.data.issues[0]!,{delivery_id:randomUUID(),display:displayFixture()});
  const client=new OperationsPickupIssues({baseUrl:'https://api.example',scope,includeDisplay:true,session:()=>({principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'}),fetch:async(input)=>{url=String(input);return Response.json(f.board);}});
  await client.refresh();assert.equal(new URL(url).searchParams.get('display'),'labels');assert.equal(client.state.phase,'ready');
  const markup=renderToStaticMarkup(createElement(PickupIssueDrawer,{controller:client}));
  assert(markup.includes('UF-TEST-001'));assert(markup.includes('Siriporn &lt;script&gt;test&lt;/script&gt;'));assert(!markup.includes('<script>test'));
  assert(markup.includes('Test destination'));assert(markup.includes('delivery-card'));client.dispose();f.controller.dispose();
});
test('requested display missing from an older server fails closed; unavailable individual labels remain valid',async()=>{
  const f=await viewFixture(),scope=f.controller.scope;
  const client=new OperationsPickupIssues({baseUrl:'https://api.example',scope,includeDisplay:true,session:()=>({principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'}),fetch:async()=>Response.json(f.board)});
  await client.refresh();assert.equal(client.state.phase,'failed');assert.equal(client.state.snapshot,null);
  Object.assign(f.board.data.issues[0]!,{display:Object.fromEntries(Object.keys(displayFixture()).map(key=>[key,null]))});
  await client.refresh();assert.equal(client.state.phase,'ready');
  const markup=renderToStaticMarkup(createElement(PickupIssueDrawer,{controller:client}));assert(markup.includes('Waiting at pickup'));assert(!markup.includes('Siriporn'));client.dispose();f.controller.dispose();
});
test('new labels can refresh without rebasing the draft and never enter the recovery journal or command',async()=>{
  const f=await viewFixture(),scope=f.controller.scope,storage=new StorageDouble(),loginId=randomUUID();
  Object.assign(f.board.data.issues[0]!,{display:displayFixture()});
  const client=new OperationsPickupIssues({baseUrl:'https://api.example',scope,includeDisplay:true,session:()=>({principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'}),fetch:async()=>Response.json(f.board),recovery:{storage,loginId,currentLoginId:()=>loginId}});
  await client.refresh();client.saveDraft(f.id,'wait','Stay at pickup','Check order');const draft=structuredClone(client.state.draft);
  Object.assign(f.board.data.issues[0]!,{display:{...displayFixture(),recipient_name:'Updated name'}});await client.refresh();
  assert.deepEqual(client.state.draft,draft);assert(!client.state.draftNeedsReview);
  const bytes=JSON.stringify([...storage.entries]);for(const value of Object.values(displayFixture()))assert(!bytes.includes(value));assert(!bytes.includes('Updated name'));
  client.dispose();f.controller.dispose();
});
test('extra or oversized display fields reject before any labels are exposed',async()=>{
  const f=await viewFixture(),scope=f.controller.scope;
  const client=new OperationsPickupIssues({baseUrl:'https://api.example',scope,includeDisplay:true,session:()=>({principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'}),fetch:async()=>Response.json(f.board)});
  for(const display of [{...displayFixture(),auth_subject:randomUUID()},{...displayFixture(),recipient_name:'x'.repeat(201)}]){
    Object.assign(f.board.data.issues[0]!,{display});await client.refresh();assert.equal(client.state.phase,'failed');assert.equal(client.state.snapshot,null);
  }
  client.dispose();f.controller.dispose();
});
test('submit gate requires both exact-text fields and disallows stale, pending, sending, closed or storage failure', async () => {
  const {controller,id} = await viewFixture(); await controller.refresh();
  controller.saveDraft(id,'wait','',''); assert(!canSubmitReply(controller.state));
  controller.saveDraft(id,'wait',' Wait\n here ',' Internal '); assert(canSubmitReply(controller.state));
  for (const patch of [{phase:'failed' as const},{phase:'closed' as const},{sending:true},{draftNeedsReview:true},{pendingCommandId:randomUUID()},{recoveryError:'RECOVERY_CONFLICT'}]) assert(!canSubmitReply({...controller.state,...patch}));
  assert.equal(controller.state.draft!.instructions,' Wait\n here '); controller.dispose();
});
test('all finite disabled reasons and uncertain-result recovery have truthful copy', async () => {
  const {controller} = await viewFixture(); await controller.refresh(); const issue = controller.state.snapshot!.data.issues[0]!;
  for (const reason of ['ORIGINAL_SCOPE_UNAVAILABLE','ISSUE_RESOLVED','DECISION_LIMIT'] as const) assert(blockedReason({...issue,blocked_reason:reason}));
  assert.match(issueErrorText('UNKNOWN_RESULT')!, /not confirmed/);
  assert.match(issueErrorText('RECOVERY_CONFLICT')!, /blocked/); controller.dispose();
});

test('default transport retains the native fetch receiver (browser regression)', async () => {
  const original = globalThis.fetch;
  let observed: unknown;
  globalThis.fetch = (async function(this: unknown) { observed = this; throw new Error('test transport'); }) as typeof fetch;
  try {
    const scope = {principalId:randomUUID(),tenantId:randomUUID(),cityId:randomUUID(),serviceDate:'2026-09-10',sessionEpoch:1};
    const controller = new OperationsPickupIssues({baseUrl:'https://api.example',scope,session:()=>({principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'})});
    await controller.refresh(); assert.equal(observed,globalThis); controller.dispose();
  } finally { globalThis.fetch = original; }
});
