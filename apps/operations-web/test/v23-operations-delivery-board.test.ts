import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { OperationsDeliveryBoard, type DeliveryBoardScope } from '../src/v23/operations-delivery-board';

function setup(){
  const scope:DeliveryBoardScope={principalId:randomUUID(),tenantId:randomUUID(),cityId:randomUUID(),serviceDate:'2026-09-10',sessionEpoch:1};
  let session:{principalId:string;sessionEpoch:number;bearer:string}|null={principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'};
  const delivery=randomUUID(),site=randomUUID(),round=randomUUID(),stop=randomUUID();
  const snapshot=()=>({as_of:'2026-09-10T01:00:00Z',next_cursor:null,data:{view:'delivery_board',principal_id:scope.principalId,tenant_id:scope.tenantId,city_id:scope.cityId,service_date:scope.serviceDate,
    workspace:{name:'Fixture workspace',version:2},city:{name:'Fixture city',version:2,timezone:'Asia/Bangkok'},delivery_count:1,deliveries:[{
      id:delivery,version:2,reference:'TEST',recipient_name:'Test recipient',address_text:'Synthetic address',brand:null,pickup_site:{id:site,name:'Test pickup'},
      window:{starts_at:'2026-09-10T02:00:00Z',ends_at:'2026-09-10T04:00:00Z',timezone:'Asia/Bangkok',service_date:scope.serviceDate},
      readiness:'held',preparation_state:'unknown',outcome:'open',evidence_state:'none',destination_version:2,destination:{latitude:0,longitude:0,source:'delivery_destination'},entrance_revision_id:null,
      planning:{round_id:round,round_version:2,round_state:'staged',departure_gate:'awaiting_receipt',stop_id:stop,stop_version:2,stop_state:'planned'}}]}});
  let handle:()=>Promise<Response>=async()=>Response.json(snapshot());const calls:{url:string;init:RequestInit}[]=[];
  const client=new OperationsDeliveryBoard({baseUrl:'http://127.0.0.1:8080',scope,session:()=>session,
    fetch:(async(url,init)=>{calls.push({url:String(url),init:init!});return handle();}) as typeof fetch});
  return {client,scope,calls,snapshot,handle:(h:typeof handle)=>handle=h,session:(s:typeof session)=>session=s};
}
const deferred=<T>()=>{let resolve!:(v:T)=>void;const promise=new Promise<T>(r=>resolve=r);return {promise,resolve};};
test('delivery read pins scope, returns immutable facts and never sends a command/device credential',async()=>{
  const s=setup();await s.client.refresh();assert.equal(s.client.state.phase,'ready');const call=s.calls[0]!;
  assert.equal(call.init.method,'GET');assert.equal(call.init.cache,'no-store');assert.equal(call.init.credentials,'omit');assert.equal(call.init.redirect,'error');
  assert.deepEqual(call.init.headers,{authorization:'Bearer test-only'});assert.equal(call.init.body,undefined);
  assert.deepEqual(Object.fromEntries(new URL(call.url).searchParams),{tenant_id:s.scope.tenantId,city_id:s.scope.cityId,service_date:s.scope.serviceDate,view:'delivery_board'});
  const d=s.client.state.snapshot!.data.deliveries[0]!;assert.equal(d.destination!.latitude,0);assert.equal(d.readiness,'held');assert.equal(d.planning!.departure_gate,'awaiting_receipt');
  assert(Object.isFrozen(d));assert.equal(Reflect.set(d,'readiness','ready'),false);s.client.dispose();
});
test('first failure is unavailable, not empty; later failure retains clearly last-known data',async()=>{
  const s=setup();s.handle(async()=>{throw new TypeError('offline');});await s.client.refresh();assert.equal(s.client.state.snapshot,null);assert.equal(s.client.state.phase,'failed');
  s.handle(async()=>Response.json(s.snapshot()));await s.client.refresh();s.handle(async()=>{throw new Error('offline');});await s.client.refresh();
  assert(s.client.state.lastKnown);assert.equal(s.client.state.errorCode,'SOURCE_UNAVAILABLE');s.client.dispose();
});
test('genuine empty result clears old rows only after a successful scoped read',async()=>{
  const s=setup();await s.client.refresh();const b=s.snapshot();b.data.deliveries=[];b.data.delivery_count=0;s.handle(async()=>Response.json(b));await s.client.refresh();
  assert.equal(s.client.state.phase,'ready');assert.equal(s.client.state.snapshot!.data.delivery_count,0);assert.deepEqual(s.client.state.snapshot!.data.deliveries,[]);s.client.dispose();
});
for(const kind of ['account','epoch','logout','dispose'])test('late delivery data cannot return after '+kind,async()=>{
  const s=setup(),d=deferred<Response>();s.handle(()=>d.promise);const reading=s.client.refresh();await Promise.resolve();
  if(kind==='dispose')s.client.dispose();else s.session(kind==='logout'?null:{principalId:kind==='account'?randomUUID():s.scope.principalId,sessionEpoch:kind==='epoch'?2:1,bearer:'renewed'});
  d.resolve(Response.json(s.snapshot()));await reading;assert.equal(s.client.state.phase,'closed');assert.equal(s.client.state.snapshot,null);
});
for(const status of [401,403])test('HTTP '+status+' immediately clears private projection',async()=>{
  const s=setup();await s.client.refresh();s.handle(async()=>new Response('',{status}));await s.client.refresh();assert.equal(s.client.state.phase,'closed');assert.equal(s.client.state.snapshot,null);
});
for(const kind of ['actor','tenant','city','date','duplicate','count','unknown','unsafe-version','coords','window','timezone','row-date'])test('rejects malformed delivery '+kind,async()=>{
  const s=setup();await s.client.refresh();const b:any=s.snapshot(),d=b.data.deliveries[0];
  if(kind==='actor')b.data.principal_id=randomUUID();if(kind==='tenant')b.data.tenant_id=randomUUID();if(kind==='city')b.data.city_id=randomUUID();if(kind==='date')b.data.service_date='2026-09-11';
  if(kind==='duplicate'){b.data.deliveries.push(d);b.data.delivery_count=2;}if(kind==='count')b.data.delivery_count=0;
  if(kind==='unknown')d.private_notes='No';if(kind==='unsafe-version')d.version=Number.MAX_SAFE_INTEGER+1;if(kind==='coords')d.destination.latitude=91;
  if(kind==='window')d.window.ends_at=d.window.starts_at;if(kind==='timezone')d.window.timezone='Not/AZone';if(kind==='row-date')d.window.service_date='2026-09-11';
  s.handle(async()=>Response.json(b));await s.client.refresh();assert.equal(s.client.state.phase,'failed');assert(s.client.state.lastKnown);assert.equal(s.client.state.errorCode,'INVALID_RESPONSE');s.client.dispose();
});
for(const kind of ['time','city','workspace','delivery','destination','round','stop'])test('rejects regressed '+kind+' without replacing previous facts',async()=>{
  const s=setup();await s.client.refresh();const b=s.snapshot(),d=b.data.deliveries[0]!;
  if(kind==='time')b.as_of='2026-09-10T00:00:00Z';if(kind==='city')b.data.city.version=1;if(kind==='workspace')b.data.workspace.version=1;
  if(kind==='delivery')d.version=1;if(kind==='destination')d.destination_version=1;if(kind==='round')d.planning.round_version=1;if(kind==='stop')d.planning.stop_version=1;
  s.handle(async()=>Response.json(b));await s.client.refresh();assert.equal(s.client.state.errorCode,'SOURCE_STALE');assert(s.client.state.lastKnown);s.client.dispose();
});
test('coalesces refresh even from loading observer; cancellation and oversize are bounded',async()=>{
  const s=setup(),d=deferred<Response>();let nested:Promise<void>|undefined;s.handle(()=>d.promise);
  const off=s.client.subscribe(()=>{if(s.client.state.phase==='loading')nested=s.client.refresh();});const first=s.client.refresh();assert.equal(first,nested);assert.equal(first,s.client.refresh());
  d.resolve(Response.json(s.snapshot()));await first;assert.equal(s.calls.length,1);off();
  s.handle(async()=>new Response('x'.repeat(1024*1024+1)));await s.client.refresh();assert.equal(s.client.state.errorCode,'INVALID_RESPONSE');assert(s.client.state.lastKnown);
  const next=deferred<Response>();s.handle(()=>next.promise);const reading=s.client.refresh();await Promise.resolve();s.client.dispose();assert(s.calls.at(-1)!.init.signal!.aborted);
  next.resolve(Response.json(s.snapshot()));await reading;assert.equal(s.client.state.snapshot,null);
});
test('malformed UTF-8 and typed server capacity failure never become zero deliveries',async()=>{
  const s=setup();s.handle(async()=>new Response(new Uint8Array([0xff])));await s.client.refresh();assert.equal(s.client.state.errorCode,'INVALID_RESPONSE');
  s.handle(async()=>Response.json({code:'FEATURE_NOT_ENABLED',message_key:'FEATURE_NOT_ENABLED',retryable:false,trace_id:'test-only'},{status:422}));
  await s.client.refresh();assert.equal(s.client.state.errorCode,'FEATURE_NOT_ENABLED');assert.equal(s.client.state.snapshot,null);s.client.dispose();
});
test('rejects non-origin endpoints and invalid explicit scope',()=>{
  const s=setup();for(const baseUrl of ['http://example.com','https://user:secret@example.com','https://example.com/path','https://example.com?key=bad'])assert.throws(()=>new OperationsDeliveryBoard({baseUrl,scope:s.scope,session:()=>null}),/INVALID_ORIGIN/);
  assert.throws(()=>new OperationsDeliveryBoard({baseUrl:'https://example.com',scope:{...s.scope,serviceDate:'2026-02-30'},session:()=>null}),/INVALID_SCOPE/);s.client.dispose();
});
