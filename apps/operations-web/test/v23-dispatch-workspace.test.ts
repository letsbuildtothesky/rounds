import assert from 'node:assert/strict';
import {test} from 'node:test';
import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {DispatchWorkspace} from '../src/v23/dispatch-workspace';
import {OperationsPickupIssues, type PickupIssue} from '../src/v23/operations-pickup-issues';
import {filterPickupIssues} from '../src/v23/pickup-issue-search';
import {operationsConnectionConfig} from '../src/v23/operations-connection-config';

function fixture() {
  const scope = {principalId:randomUUID(),tenantId:randomUUID(),cityId:randomUUID(),serviceDate:'2026-09-10',sessionEpoch:1};
  const issue: PickupIssue = {issue_id:randomUUID(),issue_version:1,round_id:randomUUID(),assignment_id:randomUUID(),assignment_version:1,delivery_id:randomUUID(),state:'open',reported_at:'2026-09-10T00:00:00Z',
    display:{delivery_reference:'TEST-A',recipient_name:'Johannes <unsafe>',destination_address:'Synthetic destination',pickup_site_name:'Test site',reported_driver_name:'Test driver'},
    report:{issue_type:'package',reason_code:'missing',detail:'One package missing',asset_ids:[],affected_lines:[]},decisions:[],allowed_actions:['wait','escalate'],blocked_reason:null};
  let status = 200, reads = 0, posts = 0;
  const controller = new OperationsPickupIssues({baseUrl:'https://api.example',scope,includeDisplay:true,session:()=>({principalId:scope.principalId,sessionEpoch:1,bearer:'synthetic-only'}),
    fetch:async(_input, init)=>{if(init?.method === 'POST') posts++; else reads++; return Response.json(status === 200 ? {as_of:'2026-09-10T00:00:00Z',next_cursor:null,data:{view:'pickup_issues',principal_id:scope.principalId,tenant_id:scope.tenantId,city_id:scope.cityId,service_date:scope.serviceDate,issues:[issue]}} : {code:'UNAVAILABLE'}, {status});}});
  return {controller,issue,setStatus:(n:number)=>status=n,counts:()=>({reads,posts})};
}
const render = (controller: OperationsPickupIssues) => renderToStaticMarkup(createElement(DispatchWorkspace,{controller}));

test('Dispatch mounts the same scoped workflow, never all-delivery totals or fake workspace/map data', async()=>{
  const f=fixture();
  const initial=render(f.controller); assert(!initial.includes('dispatch-soft-count')); assert(!initial.includes('No pickup issues'));
  await f.controller.refresh(); const html=render(f.controller);
  assert(html.includes('Not the full delivery board')); assert(html.includes('1 of 1 pickup reports'));
  assert(html.includes('Johannes &lt;unsafe&gt;')); assert(html.includes('The map is not connected.'));
  for(const forbidden of ['UrbanFlowers','Bangkok','mapbox://','NEXT_PUBLIC','Save plan','Release plan','Design prototype']) assert(!html.includes(forbidden));
  assert.equal(f.counts().posts,0); f.controller.dispose();
});
test('unconnected navigation is disabled instead of switching into old demo workflows',()=>{
  const f=fixture(),html=render(f.controller);
  for(const label of ['Drivers','History']) assert.match(html,new RegExp('<button disabled=""[^>]+>.*?</svg>'+label+'</button>'));
  assert(!html.includes('href="/"')); assert(html.includes('Intercity execution is deferred')); f.controller.dispose();
});
test('failed refresh retains explicitly last-known report counts without saying empty or live',async()=>{
  const f=fixture(); await f.controller.refresh(); f.setStatus(503); await f.controller.refresh(); const html=render(f.controller);
  assert(html.includes('1 of 1 pickup reports · Last known')); assert(!html.includes('No pickup issues')); assert(!html.includes('LIVE')); f.controller.dispose();
});
test('authorization loss clears private report text and counts in the mounted board',async()=>{
  const f=fixture(); await f.controller.refresh(); assert(render(f.controller).includes('Johannes'));
  f.setStatus(403); await f.controller.refresh(); const html=render(f.controller);
  assert(html.includes('This session is closed')); assert(!html.includes('Johannes')); assert(!html.includes(f.issue.issue_id)); assert(!html.includes('dispatch-soft-count')); f.controller.dispose();
});
test('search is local, case-insensitive and multi-term, with no field or original-ID mutation',async()=>{
  const f=fixture(); await f.controller.refresh(); const snapshot=f.controller.state.snapshot!,issues=snapshot.data.issues;
  const before=JSON.stringify(snapshot);
  for(const text of [' johannes  DESTINATION ','TEST-A','test driver','missing',f.issue.round_id]) assert.equal(filterPickupIssues(issues,text).length,1);
  assert.equal(filterPickupIssues(issues,'another recipient').length,0); assert.equal(filterPickupIssues(issues,'  '),issues);
  assert.equal(JSON.stringify(snapshot),before); assert.deepEqual(f.counts(),{reads:1,posts:0}); f.controller.dispose();
});
test('search can hide a result without discarding or rebasing its saved reply',async()=>{
  const f=fixture(); await f.controller.refresh(); f.controller.saveDraft(f.issue.issue_id,'wait',' Exact\n instruction ','Internal reason');
  const draft=f.controller.state.draft; assert.equal(filterPickupIssues(f.controller.state.snapshot!.data.issues,'no match').length,0);
  assert.equal(f.controller.state.draft,draft); assert.equal(f.counts().posts,0); f.controller.dispose();
});
test('missing display labels remain searchable by actual report scope, never synthesized recipient identity',()=>{
  const f=fixture(); const issue={...f.issue,display:undefined,delivery_id:null};
  assert.equal(filterPickupIssues([issue],issue.round_id).length,1); assert.equal(filterPickupIssues([issue],'Johannes').length,0); f.controller.dispose();
});
test('both routes use the same default-off allowlisted configuration without propagating service secrets',()=>{
  assert.equal(operationsConnectionConfig({}),null); assert.equal(operationsConnectionConfig({ROUNDS_V23_OPERATIONS_UI:'true'}),null);
  const config=operationsConnectionConfig({ROUNDS_V23_OPERATIONS_UI:'1',ROUNDS_V23_OPERATIONS_API_ORIGIN:'http://127.0.0.1:8080',SUPABASE_SERVICE_ROLE_KEY:'secret-must-not-leak',DATABASE_URL:'private-db',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'public-test-only'});
  assert.equal(config?.apiOrigin,'http://127.0.0.1:8080'); assert.equal(config?.tenantId,''); assert(!JSON.stringify(config).includes('secret')); assert(!JSON.stringify(config).includes('private-db'));
  for(const route of ['dispatch','pickup-issues']) assert(readFileSync(new URL(`../app/${route}/page.tsx`,import.meta.url),'utf8').includes('operationsConnectionConfig(process.env)'));
});
test('shell CSS preserves the approved final desktop/tablet geometry and is isolated from legacy selectors',()=>{
  const css=readFileSync(new URL('../src/v23/dispatch-workspace.css',import.meta.url),'utf8');
  const source=readFileSync(new URL('../../../specs/source/Rounds-Complete-Project-v2.3/ui/dispatch/index.html',import.meta.url),'utf8');
  assert(source.includes('grid-template-rows: 4.75rem 4.75rem auto minmax(0,1fr)')); assert(css.includes('grid-template-rows:76px 76px minmax(0,1fr)'));
  assert(source.includes('.board{--rail:320px}')); assert(css.includes('--rail:320px'));
  assert(source.includes('@media (min-width: 1600px)')); assert(css.includes('@media(min-width:1600px)')); assert(css.includes('minmax(0,1fr) 400px'));
  assert(source.includes('grid-template-rows:64px 64px auto minmax(0,1fr)')); assert(css.includes('grid-template-rows:64px 64px minmax(0,1fr)'));
  assert(!/^\s*\.app-header\s*\{/m.test(css)); assert(!css.includes('@import')); assert(!css.includes('url('));
});
