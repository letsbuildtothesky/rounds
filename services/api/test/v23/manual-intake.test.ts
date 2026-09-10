import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {test} from 'node:test';
import {validateSaveDeliveryDraftRequest,saveDeliveryDraftWork,validateSaveDeliveryDraftResult,saveDeliveryDraftPath} from '../../src/v23/manual-intake.js';
import {isV23Path,createV23NodeBoundary} from '../../src/v23/node-boundary.js';
import {CommandRejection} from '../../src/v23/transaction-runner.js';
import {createServer} from 'node:http';
import type {Wire_SaveDeliveryDraftRequest} from '../../../../packages/contracts/src/v23/pickup-wire.js';
const request=():Wire_SaveDeliveryDraftRequest=>({command_id:randomUUID(),context:{tenant_id:randomUUID(),city_id:randomUUID()},occurred_at:'2026-09-10T00:00:00Z',expected_versions:[],payload:{draft:{address_text:'Original',contacts:[],manifest:[],instructions:''}}});
test('manual draft exact generated envelope admits creation only with zero roots',()=>{
  const r=request();validateSaveDeliveryDraftRequest(r);
  assert.throws(()=>validateSaveDeliveryDraftRequest({...r,expected_versions:[{aggregate_type:'cities',id:r.context.city_id,version:1}]}),CommandRejection);
});
test('update needs exactly the original draft root, never an unrelated or duplicated root',()=>{
  const r=request(),id=randomUUID();r.payload.draft_id=id;
  assert.throws(()=>validateSaveDeliveryDraftRequest(r),CommandRejection);
  r.expected_versions=[{aggregate_type:'intake_drafts',id,version:1}];validateSaveDeliveryDraftRequest(r);
  for(const versions of [[{...r.expected_versions[0]!,id:randomUUID()}],[{...r.expected_versions[0]!,aggregate_type:'deliveries'}],[...r.expected_versions,...r.expected_versions],[{...r.expected_versions[0]!,version:1.2}]])assert.throws(()=>validateSaveDeliveryDraftRequest({...r,expected_versions:versions}),CommandRejection);
});
test('context cannot be global, missing city, or disagree with supplied draft city',()=>{
  const r=request();for(const context of [{tenant_id:null,city_id:r.context.city_id},{tenant_id:r.context.tenant_id}])assert.throws(()=>validateSaveDeliveryDraftRequest({...r,context}),CommandRejection);
  assert.throws(()=>validateSaveDeliveryDraftRequest({...r,payload:{draft:{...r.payload.draft,city_id:randomUUID()}}}),CommandRejection);
});
test('incomplete fields remain absent/null; text and intent are copied without mutation',()=>{
  const r=request();r.payload.draft.address_text=' บ้าน12\nห้อง2 ';r.payload.draft.preparation_state='ready';
  const work=saveDeliveryDraftWork({principalId:randomUUID(),tenantId:r.context.tenant_id!,cityId:r.context.city_id!},r);
  r.payload.draft.address_text='changed later';assert.equal((work.request as Wire_SaveDeliveryDraftRequest).payload.draft.address_text,' บ้าน12\nห้อง2 ');
});
test('unknown/untrusted authority fields are rejected, not removed',()=>{
  const r=request();for(const value of [{...r,actor_id:randomUUID()},{...r,payload:{...r.payload,source_order_key:'pretend'}},{...r,payload:{draft:{...r.payload.draft,review_state:'ready'}}}])assert.throws(()=>validateSaveDeliveryDraftRequest(value),CommandRejection);
});
test('manifest decimal precision, positive quantities and unique line keys',()=>{
  const r=request(),line={line_key:'a',label:'Flowers',unit:'item',handling_keys:[],quantity:0.1234};r.payload.draft.manifest=[line];validateSaveDeliveryDraftRequest(r);
  for(const quantity of [0,-1,0.12345,NaN,Infinity,1e18])assert.throws(()=>validateSaveDeliveryDraftRequest({...r,payload:{draft:{...r.payload.draft,manifest:[{...line,quantity}]}}}),CommandRejection);
  assert.throws(()=>validateSaveDeliveryDraftRequest({...r,payload:{draft:{...r.payload.draft,manifest:[line,line]}}}),CommandRejection);
});
test('windows require valid instants in increasing order and valid dates/points',()=>{
  const r=request();for(const window of [{starts_at:'tomorrow',ends_at:'later',timezone:'Asia/Bangkok'},{starts_at:'2026-09-10T00:00:00Z',ends_at:'2026-09-10T00:00:00Z',timezone:'Asia/Bangkok'}])assert.throws(()=>validateSaveDeliveryDraftRequest({...r,payload:{draft:{...r.payload.draft,window}}}),CommandRejection);
  assert.throws(()=>validateSaveDeliveryDraftRequest({...r,payload:{draft:{...r.payload.draft,service_date:'2026-02-30'}}}),CommandRejection);
  assert.throws(()=>validateSaveDeliveryDraftRequest({...r,payload:{draft:{...r.payload.draft,point:{lat:91,lng:0}}}}),CommandRejection);
});
test('result cannot advertise delivery success or leak extra content',()=>{
  const id=randomUUID(),resource={aggregate_type:'intake_drafts',id,version:1},result={command_id:randomUUID(),command_type:'SaveDeliveryDraft',state:'committed',resources:[resource],current_versions:[resource],data:{resource}};
  validateSaveDeliveryDraftResult(result);
  assert.throws(()=>validateSaveDeliveryDraftResult({...result,command_type:'CommitDelivery'}));
  assert.throws(()=>validateSaveDeliveryDraftResult({...result,data:{...result.data,address:'private'}}));
});
test('draft endpoint remains recognized but disabled without an explicitly configured runtime',async t=>{
  assert(isV23Path(saveDeliveryDraftPath));const boundary=createV23NodeBoundary({origin:'http://localhost:3000'});
  const server=createServer((req,res)=>{void boundary(req,res);});await new Promise<void>(r=>server.listen(0,'127.0.0.1',r));
  t.after(()=>new Promise<void>((r,j)=>server.close(e=>e?j(e):r())));const a=server.address();assert(a&&typeof a!=='string');
  const response=await fetch(`http://127.0.0.1:${a.port}${saveDeliveryDraftPath}`,{method:'POST'});assert.equal(response.status,403);assert.equal((await response.json()).code,'FEATURE_NOT_ENABLED');
});
