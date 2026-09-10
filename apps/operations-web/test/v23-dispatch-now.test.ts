import assert from 'node:assert/strict';
import {test} from 'node:test';
import {randomUUID} from 'node:crypto';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {classifyDeliveryNow,type OperationalFacts} from '../../../services/api/src/v23/delivery-now-projection';
import {nowPoolRows,validNowClosure,nowReasons} from '../src/v23/dispatch-now-pool';
import {OperationsDeliveryBoard} from '../src/v23/operations-delivery-board';
import {DeliveryBoardView,type BoardDelivery} from '../src/v23/delivery-board-view';

function fixture(){
  const scope={principalId:randomUUID(),tenantId:randomUUID(),cityId:randomUUID(),serviceDate:'2026-09-10',sessionEpoch:1};
  const row:BoardDelivery={id:randomUUID(),version:1,reference:'TEST',recipient_name:'Johannes',address_text:'Synthetic only',brand:{id:randomUUID(),name:'Same name'},pickup_site:{id:randomUUID(),name:'Test'},window:{starts_at:'2026-09-10T03:00:00Z',ends_at:'2026-09-10T05:00:00Z',timezone:'Asia/Bangkok',service_date:scope.serviceDate},readiness:'ready',preparation_state:'ready',outcome:'open',evidence_state:'none',destination_version:1,destination:{latitude:13,longitude:100,source:'delivery_destination'},entrance_revision_id:null,planning:null};
  const facts:OperationalFacts={issue:false,unit:{state:'open',collected_at:null},attempt:null,assignment:null};
  const data={view:'delivery_board' as const,principal_id:scope.principalId,tenant_id:scope.tenantId,city_id:scope.cityId,service_date:scope.serviceDate,workspace:{name:'Test',version:1},city:{name:'Test',version:1,timezone:'Asia/Bangkok'},delivery_count:1,deliveries:[row],now:{current_service_date:scope.serviceDate,entries:[classifyDeliveryNow(row,facts)]}};
  let body:any={as_of:'2026-09-10T06:00:00Z',next_cursor:null,data},session:any={principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'},status=200;
  const requests:URL[]=[];
  const board=new OperationsDeliveryBoard({baseUrl:'https://api.example',scope,includeNow:true,session:()=>session,fetch:async input=>{requests.push(new URL(String(input)));return Response.json(status===200?body:{},{status});}});
  return {row,facts,data,body,board,requests,setBody:(v:any)=>body=v,setStatus:(v:number)=>status=v,logout:()=>session=null};
}
test('Ready is finite server classification, missing/unknown facts never become ready',()=>{
  const f=fixture();assert.equal(classifyDeliveryNow(f.row,f.facts).reason,'ready_to_assign');
  for(const changes of [{readiness:'draft'},{destination:null}])assert.equal(classifyDeliveryNow({...f.row,...changes} as BoardDelivery,f.facts).bucket,'planned');
  assert.equal(classifyDeliveryNow(f.row,{...f.facts,unit:null}).bucket,'planned');
  for(const preparation_state of ['unknown','preparing','blocked'] as const)assert.equal(classifyDeliveryNow({...f.row,preparation_state},f.facts).bucket,'action');f.board.dispose();
});
test('collection, handoff and completion are distinct; unresolved issue overrides stale terminal state',()=>{
  const f=fixture(),collected={...f.facts,unit:{state:'collected',collected_at:'2026-09-10T02:00:00Z'}};
  assert.equal(classifyDeliveryNow({...f.row,preparation_state:'blocked'},collected).reason,'collected');
  assert.equal(classifyDeliveryNow(f.row,{...collected,attempt:'handed_over'}).reason,'handed_over');
  assert.equal(classifyDeliveryNow({...f.row,outcome:'delivered'},collected).reason,'delivered');
  assert.equal(classifyDeliveryNow({...f.row,outcome:'delivered'},{...collected,issue:true}).reason,'issue');
  assert.throws(()=>classifyDeliveryNow(f.row,{...collected,unit:{state:'collected',collected_at:null}}),/SOURCE_STALE/);f.board.dispose();
});
test('independent exception/state precedence has no fabricated delivered result',()=>{
  const f=fixture();for(const outcome of ['returned','cancelled','rescheduled'] as const)assert.deepEqual(classifyDeliveryNow({...f.row,outcome},f.facts),{delivery_id:f.row.id,bucket:'done',reason:outcome});
  for(const outcome of ['unresolved','partially_delivered'] as const)assert.equal(classifyDeliveryNow({...f.row,outcome},f.facts).reason,'unresolved');
  assert.equal(classifyDeliveryNow({...f.row,outcome:'delivered',evidence_state:'disputed'},f.facts).reason,'evidence_disputed');
  assert.equal(classifyDeliveryNow(f.row,{...f.facts,assignment:'cannot_comply'}).reason,'assignment_declined');
  assert.equal(classifyDeliveryNow(f.row,{...f.facts,attempt:'failed'}).reason,'execution_failed');
  for(const readiness of ['held','review_needed'] as const)assert.equal(classifyDeliveryNow({...f.row,readiness},f.facts).reason,readiness);f.board.dispose();
});
test('pre-arrival Round gate does not block listing but cannot become Ready',()=>{
  const f=fixture();for(const departure_gate of ['awaiting_receipt','awaiting_preparation','blocked','discrepancy','ready'] as const){
    const row={...f.row,planning:{round_id:randomUUID(),round_version:1,round_state:'staged' as const,departure_gate,stop_id:randomUUID(),stop_version:1,stop_state:'planned' as const}};
    assert.equal(classifyDeliveryNow(row,f.facts).reason,departure_gate==='ready'?'ready_for_pickup':departure_gate);
  }f.board.dispose();
});
test('category counts share exact brand and search predicates; scheduled entries remain in All',()=>{
  const f=fixture(),other={...f.row,id:randomUUID(),brand:{id:randomUUID(),name:'Same name'}},rows=[f.row,other],entries=[classifyDeliveryNow(f.row,f.facts),classifyDeliveryNow(other,{...f.facts,unit:null})];
  const before=JSON.stringify({rows,entries});let p=nowPoolRows(rows,entries,'jOhAnNeS',f.row.brand!.id,'ready');assert.equal(p.rows.length,p.counts.ready);assert.equal(p.counts.all,1);assert.equal(p.rows[0].id,f.row.id);
  p=nowPoolRows(rows,entries,'','','all');assert.equal(p.rows.length,2);assert.equal(p.counts.planned,1);assert.equal(p.counts.ready,1);
  assert.equal(nowPoolRows(rows,entries,'missing','','all').counts.all,0);assert.equal(JSON.stringify({rows,entries}),before);f.board.dispose();
});
for(const corruption of ['missing','duplicate','foreign','mismatch','extra','invalid-day'] as const)test('opt-in reader rejects '+corruption+' operational facts',async()=>{
  const f=fixture();if(corruption==='missing')delete (f.data as any).now;
  if(corruption==='duplicate')f.data.now.entries.push(f.data.now.entries[0]);
  if(corruption==='foreign')f.data.now.entries[0].delivery_id=randomUUID();
  if(corruption==='mismatch')f.data.now.entries[0].bucket='done';
  if(corruption==='extra')(f.data.now.entries[0] as any).private_note='secret';
  if(corruption==='invalid-day')f.data.now.current_service_date='2026-02-30';
  await f.board.refresh();assert.equal(f.board.state.phase,'failed');assert.equal(f.board.state.snapshot,null);f.board.dispose();
});
test('opt-in transport, fresh date reader, network failure and denial preserve existing privacy rules',async()=>{
  const f=fixture();await f.board.refresh();assert.equal(f.board.state.phase,'ready');assert.equal(f.requests[0].searchParams.get('display'),'now');assert(validNowClosure(f.data));
  f.setStatus(503);await f.board.refresh();assert(f.board.state.lastKnown);assert.equal(f.board.state.snapshot!.data.now!.entries.length,1);
  const child=f.board.forServiceDate('2026-09-11');f.setBody({...f.body,data:{...f.data,service_date:'2026-09-11',deliveries:[],delivery_count:0,now:{current_service_date:'2026-09-10',entries:[]}}});f.setStatus(200);await child.refresh();assert.equal(child.state.phase,'ready');assert.equal(f.requests.at(-1)!.searchParams.get('display'),'now');
  f.setStatus(403);await child.refresh();assert.equal(child.state.snapshot,null);assert.equal(f.board.state.snapshot,null);assert.equal(f.board.state.phase,'closed');
});
test('source status tabs and returned reason render; unavailable mutations are not enabled',async()=>{
  const f=fixture();f.data.now.entries=[classifyDeliveryNow(f.row,{...f.facts,issue:true})];await f.board.refresh();
  const html=renderToStaticMarkup(createElement(DeliveryBoardView,{controller:f.board,mode:'now',onMode:()=>{},onReports:()=>{},reportsAvailable:false}));
  for(const label of ['Delivery status','Action','Ready','On road','Done','Issue needs attention','Show all deliveries','View delivery details'])assert(html.includes(label),label);
  for(const label of ['Planned delivery date','Mark ready','Record confirmed handover','Save plan','Release plan'])assert(!html.includes(label),label);
  assert.equal(Object.values(nowReasons).every(r=>!!r.label),true);f.board.dispose();
});
test('different server day does not present the old date as current Now rows',async()=>{
  const f=fixture();f.data.now.current_service_date='2026-09-11';await f.board.refresh();
  const html=renderToStaticMarkup(createElement(DeliveryBoardView,{controller:f.board,mode:'now',onMode:()=>{},onReports:()=>{},reportsAvailable:false}));
  assert(html.includes('current city day has changed'));assert(!html.includes('Johannes'));f.board.dispose();
});
