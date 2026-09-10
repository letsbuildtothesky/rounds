import assert from 'node:assert/strict';
import {test} from 'node:test';
import {randomUUID} from 'node:crypto';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {OperationsDeliveryBoard} from '../src/v23/operations-delivery-board';
import {OperationsPickupIssues,type PickupIssue} from '../src/v23/operations-pickup-issues';
import {DeliveryBoardView,type BoardDelivery} from '../src/v23/delivery-board-view';
import {PickupIssueDrawer} from '../src/v23/pickup-issue-drawer';
import {pickupActionReports,reportsForDelivery} from '../src/v23/dispatch-pickup-action';

async function fixture(){
  const scope={principalId:randomUUID(),tenantId:randomUUID(),cityId:randomUUID(),serviceDate:'2026-09-10',sessionEpoch:1};
  const row:BoardDelivery={id:randomUUID(),version:1,reference:'ORDER-A',recipient_name:'Johannes',address_text:'Synthetic address',brand:null,pickup_site:{id:randomUUID(),name:'Test site'},window:{starts_at:'2026-09-10T03:00:00Z',ends_at:'2026-09-10T05:00:00Z',timezone:'Asia/Bangkok',service_date:scope.serviceDate},readiness:'held',preparation_state:'unknown',outcome:'open',evidence_state:'none',destination_version:1,destination:null,entrance_revision_id:null,planning:null};
  const issue:PickupIssue={issue_id:randomUUID(),issue_version:1,round_id:randomUUID(),assignment_id:randomUUID(),assignment_version:1,delivery_id:row.id,state:'open',reported_at:'2026-09-10T00:00:00Z',report:{issue_type:'package',reason_code:'missing',detail:'Exact original report',asset_ids:[],affected_lines:[]},decisions:[],allowed_actions:['wait','escalate'],blocked_reason:null};
  const base={view:'delivery_board' as const,principal_id:scope.principalId,tenant_id:scope.tenantId,city_id:scope.cityId,service_date:scope.serviceDate,workspace:{name:'Test',version:1},city:{name:'Test',version:1,timezone:'Asia/Bangkok'},delivery_count:1,deliveries:[row],now:{current_service_date:scope.serviceDate,entries:[{delivery_id:row.id,bucket:'action' as const,reason:'issue' as const}]}};
  let issues=[issue],reportStatus=200,boardStatus=200,posts=0;
  const envelope=(data:unknown)=>({as_of:'2026-09-10T06:00:00Z',next_cursor:null,data});
  const session=()=>({principalId:scope.principalId,sessionEpoch:1,bearer:'synthetic-only'});
  const board=new OperationsDeliveryBoard({baseUrl:'https://api.example',scope,session,includeNow:true,fetch:async()=>Response.json(boardStatus===200?envelope(base):{}, {status:boardStatus})});
  const reports=new OperationsPickupIssues({baseUrl:'https://api.example',scope,session,fetch:async(_input,init)=>{if(init?.method==='POST')posts++;return Response.json(reportStatus===200?envelope({view:'pickup_issues',principal_id:scope.principalId,tenant_id:scope.tenantId,city_id:scope.cityId,service_date:scope.serviceDate,issues}):{}, {status:reportStatus});}});
  await Promise.all([board.refresh(),reports.refresh()]);assert.equal(board.state.phase,'ready');assert.equal(reports.state.phase,'ready');
  return {board,reports,row,issue,base,posts:()=>posts,setIssues:(v:PickupIssue[])=>issues=v,setReportStatus:(v:number)=>reportStatus=v,setBoardStatus:(v:number)=>boardStatus=v,dispose:()=>{board.dispose();reports.dispose();}};
}
test('exact authorized Action join exposes only original issue IDs, no writes or name matching',async()=>{
  const f=await fixture();const before=JSON.stringify([f.board.state,f.reports.state]);
  assert.deepEqual(pickupActionReports(f.board,f.reports).get(f.row.id),[f.issue.issue_id]);
  assert.equal(JSON.stringify([f.board.state,f.reports.state]),before);assert.equal(f.posts(),0);
  f.setIssues([{...f.issue,delivery_id:randomUUID(),display:{delivery_reference:'ORDER-A',recipient_name:'Johannes',destination_address:'Synthetic address',pickup_site_name:null,reported_driver_name:null}}]);await f.reports.refresh();
  // The reader itself rejects a changed original association.
  assert.equal(f.reports.state.phase,'failed');assert.equal(pickupActionReports(f.board,f.reports).size,0);f.dispose();
});
for(const key of ['principalId','tenantId','cityId','serviceDate','sessionEpoch'] as const)test('navigation requires the same '+key,async()=>{
  const f=await fixture(),scope={...f.reports.scope,[key]:key==='sessionEpoch'?2:key==='serviceDate'?'2026-09-11':randomUUID()};
  assert.equal(pickupActionReports(f.board,{scope,state:f.reports.state}).size,0);f.dispose();
});
for(const side of ['board','report'] as const)for(const status of [503,403])test(`${side} ${status} hides Action linkage without deleting the other authorized reader`,async()=>{
  const f=await fixture();if(side==='board'){f.setBoardStatus(status);await f.board.refresh();assert.equal(f.reports.state.phase,'ready');}else{f.setReportStatus(status);await f.reports.refresh();assert.equal(f.board.state.phase,'ready');}
  assert.equal(pickupActionReports(f.board,f.reports).size,0);assert.equal(f.posts(),0);f.dispose();
});
test('no opt-in Now, changed city day, or another Action reason cannot manufacture a pickup link',async()=>{
  const f=await fixture(),state=f.board.state,snapshot=state.snapshot!,data=snapshot.data;
  for(const now of [undefined,{...data.now!,current_service_date:'2026-09-11'},{...data.now!,entries:[{delivery_id:f.row.id,bucket:'action' as const,reason:'awaiting_preparation' as const}]}]){
    assert.equal(pickupActionReports({scope:f.board.scope,state:{...state,snapshot:{...snapshot,data:{...data,now}}}},f.reports).size,0);
  }f.dispose();
});
test('multiple direct reports stay selectable; Round-only, resolved and unrelated records are never guessed',async()=>{
  const f=await fixture(),second={...f.issue,issue_id:randomUUID()},unrelated={...f.issue,issue_id:randomUUID(),delivery_id:randomUUID()},roundOnly={...f.issue,issue_id:randomUUID(),delivery_id:null};
  const resolved:PickupIssue={...f.issue,issue_id:randomUUID(),state:'resolved',allowed_actions:[],blocked_reason:'ISSUE_RESOLVED',decisions:[{id:randomUUID(),action:'wait',instructions:'Already checked',decided_at:'2026-09-10T01:00:00Z'}]};
  // Selection operates over the query's typed records; command eligibility is separate.
  assert.deepEqual(reportsForDelivery([f.issue,second,roundOnly,resolved,unrelated],f.row.id),[f.issue,second]);
  f.setIssues([f.issue,second,roundOnly,unrelated]);await f.reports.refresh();assert.equal(f.reports.state.phase,'ready');
  assert.deepEqual(pickupActionReports(f.board,f.reports).get(f.row.id),[f.issue.issue_id,second.issue_id]);
  const html=renderToStaticMarkup(createElement(PickupIssueDrawer,{controller:f.reports,layout:'board',entryDeliveryId:f.row.id}));
  assert(html.includes('2 of 4 pickup reports'));assert(!html.includes('id="pickup-issue-heading"'));assert(html.includes('Show all pickup reports'));assert.equal(f.posts(),0);f.dispose();
});
test('single Action opens review only, preserves another report draft and current original identities',async()=>{
  const f=await fixture(),other={...f.issue,issue_id:randomUUID(),delivery_id:randomUUID()};f.setIssues([f.issue,other]);await f.reports.refresh();
  f.reports.saveDraft(other.issue_id,'wait',' Exact old draft\n ','Internal reason');const draft=f.reports.state.draft;
  const html=renderToStaticMarkup(createElement(PickupIssueDrawer,{controller:f.reports,layout:'board',entryDeliveryId:f.row.id}));
  assert(html.includes('Exact original report'));assert(html.includes(f.issue.assignment_id));assert(html.includes('Review saved draft'));assert(!html.includes('<dialog'));assert.equal(f.reports.state.draft,draft);assert.equal(f.posts(),0);f.dispose();
});
test('changed original job can be reviewed without enabling a reply',async()=>{
  const f=await fixture();f.setIssues([{...f.issue,allowed_actions:[],blocked_reason:'ORIGINAL_SCOPE_UNAVAILABLE'}]);await f.reports.refresh();
  assert.equal(pickupActionReports(f.board,f.reports).size,1);
  const html=renderToStaticMarkup(createElement(PickupIssueDrawer,{controller:f.reports,layout:'board',entryDeliveryId:f.row.id}));
  assert.match(html,/<button class="primary-button" disabled="">Reply to driver/);assert.equal(f.posts(),0);f.dispose();
});
test('card retains approved detail navigation and only a connected Action changes its next-action label',async()=>{
  const f=await fixture(),props={controller:f.board,mode:'now' as const,onMode:()=>{},onReports:()=>{},reportsAvailable:true};
  let html=renderToStaticMarkup(createElement(DeliveryBoardView,props));assert(html.includes('View delivery details'));
  html=renderToStaticMarkup(createElement(DeliveryBoardView,{...props,pickupActions:pickupActionReports(f.board,f.reports),onPickupAction:()=>{}}));
  assert(html.includes('Review pickup report'));assert(!html.includes('id="pickup-issue-heading"'));assert(!html.includes('Send instructions'));assert.equal(f.posts(),0);f.dispose();
});
