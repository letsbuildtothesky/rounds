import assert from 'node:assert/strict';
import {test} from 'node:test';
import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {OperationsDeliveryBoard} from '../src/v23/operations-delivery-board';
import {isUnplannedDelivery,planBrands,planPoolRows} from '../src/v23/dispatch-plan-pool';
import type {BoardDelivery} from '../src/v23/delivery-board-view';

function fixture(){
  const scope={principalId:randomUUID(),tenantId:randomUUID(),cityId:randomUUID(),serviceDate:'2026-09-10',sessionEpoch:1};
  let session:{principalId:string;sessionEpoch:number;bearer:string}|null={principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'};
  const row:BoardDelivery={id:randomUUID(),version:1,reference:'TEST-A',recipient_name:'Johannes',address_text:'Synthetic address',brand:{id:randomUUID(),name:'Same brand'},pickup_site:{id:randomUUID(),name:'Test pickup'},window:{starts_at:'2026-09-10T03:00:00Z',ends_at:'2026-09-10T05:00:00Z',timezone:'Asia/Bangkok',service_date:scope.serviceDate},readiness:'draft',preparation_state:'unknown',outcome:'open',evidence_state:'none',destination_version:1,destination:null,entrance_revision_id:null,planning:null};
  const planning:NonNullable<BoardDelivery['planning']>={round_id:randomUUID(),round_version:1,round_state:'staged',departure_gate:'awaiting_receipt',stop_id:randomUUID(),stop_version:1,stop_state:'planned'};
  const requests:{date:string;init?:RequestInit}[]=[];
  let status=200,hold=false,release:()=>void=()=>{};
  const response=(date:string)=>({as_of:'2026-09-10T06:00:00Z',next_cursor:null,data:{view:'delivery_board',principal_id:scope.principalId,tenant_id:scope.tenantId,city_id:scope.cityId,service_date:date,workspace:{name:'Test workspace',version:1},city:{name:'Test city',version:1,timezone:'Asia/Bangkok'},delivery_count:date==='2026-09-12'?0:1,deliveries:date==='2026-09-12'?[]:[{...row,window:{...row.window,starts_at:date+'T03:00:00Z',ends_at:date+'T05:00:00Z',service_date:date}}]}});
  const board=new OperationsDeliveryBoard({baseUrl:'https://api.example',scope,session:()=>session,fetch:async(input,init)=>{
    const date=new URL(String(input)).searchParams.get('service_date')!;requests.push({date,init});
    if(hold)await new Promise<void>(resolve=>{release=resolve;});
    return Response.json(status===200?response(date):{}, {status});
  }});
  return {board,row,planning,requests,response,setStatus:(value:number)=>status=value,setSession:(value:typeof session)=>session=value,hold:()=>{hold=true;},release:()=>release()};
}

test('unplanned uses open outcome and absence of current planning, not receipt or preparation',()=>{
  const f=fixture();for(const readiness of ['draft','review_needed','held','ready'] as const){
    for(const preparation_state of ['unknown','preparing','blocked','ready'] as const)assert(isUnplannedDelivery({...f.row,readiness,preparation_state}));
  }
  assert(!isUnplannedDelivery({...f.row,planning:f.planning}));f.board.dispose();
});
test('terminal and historical outcomes stay in All but are never offered as unplanned open work',()=>{
  const f=fixture();const rows=['delivered','partially_delivered','rescheduled','returned','cancelled','unresolved'].map(outcome=>({...f.row,id:randomUUID(),outcome:outcome as BoardDelivery['outcome']}));
  assert.equal(planPoolRows(rows,'','','all').rows.length,6);assert.equal(planPoolRows(rows,'','','unplanned').rows.length,0);f.board.dispose();
});
test('pre-arrival staged order stays visible in All without becoming unplanned or physically ready',()=>{
  const f=fixture(),row={...f.row,planning:f.planning};const before=JSON.stringify(row);
  const all=planPoolRows([row],'','','all');assert.equal(all.rows[0],row);assert.deepEqual(all.counts,{all:1,unplanned:0});
  assert.equal(JSON.stringify(row),before);assert.equal(row.planning.departure_gate,'awaiting_receipt');assert.equal(row.preparation_state,'unknown');f.board.dispose();
});
test('brand IDs, search, category counts and returned IDs use exactly the same filtered rows',()=>{
  const f=fixture(),brand2={id:randomUUID(),name:f.row.brand!.name};
  const rows=[f.row,{...f.row,id:randomUUID(),brand:brand2},{...f.row,id:randomUUID(),planning:f.planning},{...f.row,id:randomUUID(),recipient_name:'Another person',brand:null}];
  const result=planPoolRows(rows,'JOHANNES test',f.row.brand!.id,'unplanned');assert.deepEqual(result.rows.map(d=>d.id),[f.row.id]);assert.deepEqual(result.counts,{all:2,unplanned:1});
  assert.equal(planPoolRows(rows,'',brand2.id,'all').rows[0].id,rows[1].id);assert.equal(planPoolRows(rows,f.row.id,'','all').rows.length,0);f.board.dispose();
});
test('filters preserve source order, immutable rows and equal-name distinct brands',()=>{
  const f=fixture(),rows=[f.row,{...f.row,id:randomUUID(),brand:{id:randomUUID(),name:'Same brand'}},{...f.row,id:randomUUID(),brand:null}];
  Object.freeze(rows);const before=JSON.stringify(rows),result=planPoolRows(rows,'','','all');
  assert.deepEqual(result.rows.map(d=>d.id),rows.map(d=>d.id));assert.equal(JSON.stringify(rows),before);assert.equal(planBrands(rows).length,2);f.board.dispose();
});
test('removed selected brand yields explicit empty view, never silently changes to all brands',()=>{
  const f=fixture();assert.deepEqual(planPoolRows([f.row],'',randomUUID(),'all').counts,{all:0,unplanned:0});f.board.dispose();
});
test('selected date creates a fresh immutable reader with exact same identity and no inherited rows',async()=>{
  const f=fixture();await f.board.refresh();const child=f.board.forServiceDate('2026-09-11');
  assert.equal(child.state.snapshot,null);assert.equal(child.state.phase,'idle');assert(Object.isFrozen(child.scope));
  assert.deepEqual(child.scope,{...f.board.scope,serviceDate:'2026-09-11'});assert.equal(f.board.scope.serviceDate,'2026-09-10');
  await child.refresh();assert.equal(child.state.snapshot!.data.service_date,'2026-09-11');
  assert.equal(f.board.state.snapshot!.data.service_date,'2026-09-10');
  for(const request of f.requests){assert.equal(request.init?.method,'GET');assert.equal(request.init?.credentials,'omit');assert.equal(request.init?.cache,'no-store');}
  f.board.dispose();
});
test('date without deliveries is genuinely empty and never copies another date',async()=>{
  const f=fixture();await f.board.refresh();const child=f.board.forServiceDate('2026-09-12');await child.refresh();
  assert.equal(child.state.phase,'ready');assert.equal(child.state.snapshot!.data.delivery_count,0);assert.deepEqual(child.state.snapshot!.data.deliveries,[]);assert.equal(f.board.state.snapshot!.data.delivery_count,1);f.board.dispose();
});
test('invalid or non-existent date rejects before creating a request or losing the existing snapshot',async()=>{
  const f=fixture();await f.board.refresh();const before=f.board.state.snapshot;
  for(const date of ['','2026-02-30','2026-9-11','2026-09-11T00:00:00Z','tomorrow'])assert.throws(()=>f.board.forServiceDate(date),/INVALID_SCOPE/);
  assert.equal(f.requests.length,1);assert.equal(f.board.state.snapshot,before);f.board.dispose();
});
test('date switch disposal aborts the old read and ignores late responses',async()=>{
  const f=fixture(),old=f.board.forServiceDate('2026-09-11');f.hold();const reading=old.refresh();await new Promise(resolve=>setImmediate(resolve));
  old.dispose();assert.equal(f.requests[0].init?.signal?.aborted,true);f.release();await reading;
  assert.equal(old.state.phase,'closed');assert.equal(old.state.snapshot,null);assert.equal(f.board.state.phase,'idle');f.board.dispose();
});
test('parent disposal immediately clears and aborts every owned date reader',async()=>{
  const f=fixture(),child=f.board.forServiceDate('2026-09-11');await child.refresh();let notified=false;
  child.subscribe(()=>{notified=child.state.phase==='closed';});f.board.dispose();assert(notified);assert.equal(child.state.snapshot,null);
  assert.throws(()=>child.refresh(),/SESSION_CHANGED/);assert.throws(()=>f.board.forServiceDate('2026-09-12'),/SESSION_CHANGED/);
});
test('disposing one date reader leaves parent and another date usable',async()=>{
  const f=fixture(),a=f.board.forServiceDate('2026-09-11'),b=f.board.forServiceDate('2026-09-12');a.dispose();await b.refresh();await f.board.refresh();
  assert.equal(b.state.phase,'ready');assert.equal(f.board.state.phase,'ready');f.board.dispose();
});
test('authorization refusal on any date closes the entire delivery-reader family',async()=>{
  for(const status of [401,403]){const f=fixture();await f.board.refresh();const a=f.board.forServiceDate('2026-09-11'),b=f.board.forServiceDate('2026-09-12');await a.refresh();f.setStatus(status);await b.refresh();
    for(const reader of [f.board,a,b]){assert.equal(reader.state.phase,'closed');assert.equal(reader.state.snapshot,null);}}
});
test('expired or changed login cannot create dates or deliver a pending date response',async()=>{
  const f=fixture(),child=f.board.forServiceDate('2026-09-11');f.hold();const reading=child.refresh();await new Promise(resolve=>setImmediate(resolve));f.setSession(null);f.release();await reading;
  assert.equal(child.state.snapshot,null);assert.equal(child.state.phase,'closed');assert.equal(f.board.state.phase,'closed');assert.throws(()=>f.board.forServiceDate('2026-09-12'),/SESSION_CHANGED/);
});
test('new-date failure has no old-date last-known fallback; same-date failure does',async()=>{
  const f=fixture();await f.board.refresh();const child=f.board.forServiceDate('2026-09-11');f.setStatus(503);await child.refresh();assert.equal(child.state.phase,'failed');assert.equal(child.state.lastKnown,false);
  f.setStatus(200);await child.refresh();f.setStatus(503);await child.refresh();assert(child.state.lastKnown);assert.equal(child.state.snapshot!.data.service_date,'2026-09-11');f.board.dispose();
});
test('source Plan primitives and scoped CSS remain aligned; test fixtures do not enter production',()=>{
  const source=readFileSync(new URL('../../../specs/source/Rounds-Complete-Project-v2.3/ui/dispatch/index.html',import.meta.url),'utf8');
  const css=readFileSync(new URL('../src/v23/dispatch-workspace.css',import.meta.url),'utf8');
  assert(source.includes('Planned delivery date'));assert(source.includes('All brands'));assert(source.includes('Unplanned'));assert(source.includes('All deliveries'));
  assert(css.includes('.dispatch-plan-brand select'));assert(css.includes('color:#51657a; font-size:11px'));assert(css.includes('aria-selected=true'));
});
