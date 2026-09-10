import assert from 'node:assert/strict';
import {test} from 'node:test';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {randomUUID} from 'node:crypto';
import {DispatchWorkspace} from '../src/v23/dispatch-workspace';
import {DeliveryBoardView,deliveryWindow,filterBoardDeliveries,type BoardDelivery} from '../src/v23/delivery-board-view';
import {OperationsDeliveryBoard} from '../src/v23/operations-delivery-board';
import {OperationsPickupIssues,type PickupIssue} from '../src/v23/operations-pickup-issues';

function fixture(){
  const scope={principalId:randomUUID(),tenantId:randomUUID(),cityId:randomUUID(),serviceDate:'2026-09-10',sessionEpoch:1};
  const row:BoardDelivery={id:randomUUID(),version:1,reference:'ORDER-TEST',recipient_name:'Johannes <script>',address_text:'Synthetic address',brand:{id:randomUUID(),name:'Test brand'},pickup_site:{id:randomUUID(),name:'Test site'},window:{starts_at:'2026-09-10T03:00:00Z',ends_at:'2026-09-10T05:00:00Z',timezone:'Asia/Bangkok',service_date:scope.serviceDate},readiness:'held',preparation_state:'unknown',outcome:'open',evidence_state:'none',destination_version:1,destination:null,entrance_revision_id:null,planning:null};
  let rows=[row], status=200, issueStatus=200, reads=0, posts=0;
  const snapshot=()=>({as_of:'2026-09-10T06:00:00Z',next_cursor:null,data:{view:'delivery_board',principal_id:scope.principalId,tenant_id:scope.tenantId,city_id:scope.cityId,service_date:scope.serviceDate,workspace:{name:'Test workspace',version:1},city:{name:'Test city',version:1,timezone:'Asia/Bangkok'},delivery_count:rows.length,deliveries:rows}});
  const session=()=>({principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'});
  const board=new OperationsDeliveryBoard({baseUrl:'https://api.example',scope,session,fetch:async()=>{reads++;return Response.json(status===200?snapshot():{}, {status});}});
  const issue:PickupIssue={issue_id:randomUUID(),issue_version:1,round_id:randomUUID(),assignment_id:randomUUID(),assignment_version:1,delivery_id:row.id,state:'open',reported_at:'2026-09-10T00:00:00Z',report:{issue_type:'package',reason_code:'missing',detail:'Test report',asset_ids:[],affected_lines:[]},decisions:[],allowed_actions:['wait'],blocked_reason:null};
  const issues=new OperationsPickupIssues({baseUrl:'https://api.example',scope,session,fetch:async(_input,init)=>{if(init?.method==='POST')posts++;return Response.json({as_of:'2026-09-10T06:00:00Z',next_cursor:null,data:{view:'pickup_issues',principal_id:scope.principalId,tenant_id:scope.tenantId,city_id:scope.cityId,service_date:scope.serviceDate,issues:[issue]}},{status:issueStatus});}});
  return {board,issues,row,issue,snapshot,setRows:(v:BoardDelivery[])=>rows=v,setStatus:(v:number)=>status=v,setIssueStatus:(v:number)=>issueStatus=v,counts:()=>({reads,posts}),dispose:()=>{board.dispose();issues.dispose();}};
}
const render=(f:ReturnType<typeof fixture>)=>renderToStaticMarkup(createElement(DispatchWorkspace,{controller:f.issues,deliveryController:f.board}));
test('mounted delivery reader uses actual workspace/city, safe labels, true count and local window without reports',async()=>{
  const f=fixture();await f.board.refresh();const html=render(f);
  for(const text of ['Test workspace','Test city','1 of 1 deliveries','Johannes &lt;script&gt;','10:00–12:00','Readiness: held','View delivery details'])assert(html.includes(text),text);
  for(const text of ['UrbanFlowers','LIVE','Design prototype','Sample shift','Test report','Priority first'])assert(!html.includes(text),text);
  assert.equal(f.counts().posts,0);f.dispose();
});
test('loading never shows zero or all clear; empty requires a successful result',async()=>{
  const f=fixture();let html=render(f);assert(html.includes('Loading deliveries'));assert(!html.includes('0 deliveries'));assert(!html.includes('No deliveries scheduled'));
  f.setRows([]);await f.board.refresh();html=render(f);assert(html.includes('0 of 0 deliveries'));assert(html.includes('No deliveries scheduled'));f.dispose();
});
test('network failure retains visibly last-known counts and workspace without claiming empty',async()=>{
  const f=fixture();await f.board.refresh();f.setStatus(503);await f.board.refresh();const html=render(f);
  assert(html.includes('Workspace · Last known'));assert(html.includes('1 of 1 deliveries · Last known'));assert(html.includes('Could not refresh deliveries'));assert(!html.includes('No deliveries scheduled'));f.dispose();
});
test('initial read failure is not an empty schedule',async()=>{const f=fixture();f.setStatus(503);await f.board.refresh();const html=render(f);assert(html.includes('No delivery count is available'));assert(!html.includes('No deliveries scheduled'));f.dispose();});
test('closed delivery access removes labels, identifiers and counts',async()=>{
  const f=fixture();await f.board.refresh();f.setStatus(403);await f.board.refresh();const html=render(f);
  assert(html.includes('Delivery access is unavailable'));for(const s of ['Test workspace','Test city','Johannes','ORDER-TEST',f.row.id,'1 of 1 deliveries'])assert(!html.includes(s));f.dispose();
});
test('independent issue permission denial leaves authorized delivery read usable',async()=>{
  const f=fixture();f.setIssueStatus(403);await Promise.allSettled([f.board.refresh(),f.issues.refresh()]);const html=render(f);
  assert(html.includes('Johannes'));assert(html.includes('Pickup report access is unavailable'));assert.equal(f.issues.state.phase,'closed');assert.equal(f.board.state.phase,'ready');f.dispose();
});
test('scope mismatch does not expose either private projection',async()=>{
  const f=fixture();await f.board.refresh();const foreign=new OperationsPickupIssues({baseUrl:'https://api.example',scope:{...f.issues.scope,cityId:randomUUID()},session:()=>null});
  const html=renderToStaticMarkup(createElement(DispatchWorkspace,{controller:foreign,deliveryController:f.board}));assert(html.includes('scopes do not match'));assert(!html.includes('Johannes'));f.dispose();foreign.dispose();
});
test('search matches only provided display fields and preserves order, IDs, snapshots and saved replies',async()=>{
  const f=fixture();await Promise.all([f.board.refresh(),f.issues.refresh()]);f.issues.saveDraft(f.issue.issue_id,'wait',' Exact\n instruction ','Reason');const draft=f.issues.state.draft;
  const rows=f.board.state.snapshot!.data.deliveries,before=JSON.stringify(rows);
  for(const q of ['JOHANNES address','ORDER-test','brand','site'])assert.equal(filterBoardDeliveries(rows,q).length,1);
  assert.equal(filterBoardDeliveries(rows,'absent').length,0);assert.equal(filterBoardDeliveries(rows,f.row.id).length,0);assert.equal(filterBoardDeliveries(rows,'  '),rows);
  assert.equal(JSON.stringify(rows),before);assert.equal(f.issues.state.draft,draft);assert.equal(f.counts().posts,0);f.dispose();
});
test('missing names/address are explicit and unplanned does not claim a driver or readiness',async()=>{
  const f=fixture();f.setRows([{...f.row,reference:null,recipient_name:null,address_text:null,pickup_site:{...f.row.pickup_site,name:null},brand:null}]);await f.board.refresh();const html=render(f);
  assert(html.includes('Reference unavailable'));assert(html.includes('Recipient name unavailable'));assert(html.includes('Address unavailable'));assert(!html.includes('Unassigned driver'));f.dispose();
});
test('source Plan/read/filter controls are enabled; Now and mutation controls stay disabled',async()=>{
  const f=fixture();await f.board.refresh();const html=render(f);
  assert.match(html,/<button id="dispatch-now-tab" role="tab" aria-selected="false"[^>]*disabled=""[^>]*>Now<\/button>/);
  assert.match(html,/<button id="dispatch-plan-tab" role="tab" aria-selected="true" aria-controls="dispatch-plan-results">Plan<span>1<\/span><\/button>/);
  assert(html.includes('Read-only plan list'));assert(html.includes('Unplanned'));assert(html.includes('All deliveries'));assert(html.includes('All brands'));assert(html.includes('Planned delivery date'));
  for(const label of ['Save plan','Release plan','Generate plan','Mark ready','On road'])assert(!html.includes(label));assert.equal(f.counts().posts,0);f.dispose();
});
test('historical partial outcome is displayed truthfully but never an enabled partial action',async()=>{
  const f=fixture();f.setRows([{...f.row,outcome:'partially_delivered'}]);await f.board.refresh();const html=render(f);assert(html.includes('Outcome: partially delivered'));assert(!html.includes('Approve partial'));f.dispose();
});
test('window uses server timezone, handles date crossing without assuming just one day',()=>{
  const f=fixture();assert.equal(deliveryWindow(f.row),'10:00–12:00');const text=deliveryWindow({...f.row,window:{...f.row.window,starts_at:'2026-09-10T16:00:00Z',ends_at:'2026-09-12T18:00:00Z'}});assert(text.includes('2026-09-10'));assert(text.includes('2026-09-13'));assert(!text.includes('+1 day'));f.dispose();
});
