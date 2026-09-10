import assert from 'node:assert/strict';
import {createHash,randomUUID} from 'node:crypto';
import {createServer} from 'node:http';
import {test} from 'node:test';
import type {Wire_ReviewAddressRequest,Wire_SaveDeliveryDraftRequest} from '../../../../packages/contracts/src/v23/pickup-wire.js';
import {canonicalCommandJson} from '../../src/v23/command-identity.js';
import {createOperationsIssueHttp,isOperationsIssueRequest} from '../../src/v23/operations-issue-http.js';
import {isV23Path,createV23NodeBoundary} from '../../src/v23/node-boundary.js';
import {reviewAddressPath,reviewAddressWork,validateReviewAddressRequest} from '../../src/v23/review-address.js';
import {saveDeliveryDraftPath} from '../../src/v23/manual-intake.js';
import {CommandRejection,CommandTransactionRunner} from '../../src/v23/transaction-runner.js';
import {beginRestrictedTransaction} from '../../src/v23/restricted-transaction.js';
import {startPostgisFixture} from './postgis-fixture.js';
import {seedWholeOrder} from './whole-order-fixture.js';

test('ReviewAddress: real restricted draft transaction and authenticated HTTP/status',{timeout:120000},async t=>{
  const db=await startPostgisFixture();t.after(()=>db.close());
  const tokens=new Map<string,string>(),origin='http://localhost:3000';
  const http=createOperationsIssueHttp({pool:db.pool,origin,verifyBearer:async token=>{const s=tokens.get(token);if(!s)throw new CommandRejection('UNAUTHENTICATED');return s;}});
  const post=(s:{headers:Record<string,string>},path:string,r:unknown)=>http(new Request('http://rounds.internal'+path,{method:'POST',headers:s.headers,body:JSON.stringify(r)}));
  async function setup(){
    const ids=await seedWholeOrder(db.admin),token=randomUUID(),subject=randomUUID();tokens.set(token,subject);
    await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1',[ids.actor,subject]);
    await db.admin.query("UPDATE rounds.city_grants SET capabilities=ARRAY['deliveries.create','deliveries.review'] WHERE id=$1",[ids.grant]);
    const headers={authorization:`Bearer ${token}`,origin,'content-type':'application/json'};
    const save:Wire_SaveDeliveryDraftRequest={command_id:randomUUID(),context:{tenant_id:ids.tenant!,city_id:ids.city!},occurred_at:'2026-09-10T00:00:00Z',expected_versions:[],payload:{draft:{
      city_id:ids.city!,address_text:'  บ้านเลขที่ 12\nห้อง 5  ',point:{longitude:100.57,latitude:13.73},
      contacts:[{role:'buyer',name:'Johannes buyer'},{role:'recipient',name:'Test recipient'}],manifest:[{line_key:'flowers',label:'Flowers',quantity:5,unit:'item',handling_keys:[]}],instructions:'  Leave text exactly.  ',preparation_state:'preparing'}}};
    const response=await post({headers},saveDeliveryDraftPath,save),result=await response.json();assert.equal(response.status,200,JSON.stringify(result));
    const r:Wire_ReviewAddressRequest={command_id:randomUUID(),context:save.context,occurred_at:save.occurred_at,expected_versions:[result.data.resource],payload:{draft_id:result.data.resource.id,
      input_hash:createHash('sha256').update(canonicalCommandJson(save.payload.draft)).digest('hex'),decision:'accept',address_text:save.payload.draft.address_text,point:save.payload.draft.point??null}};
    return {ids,headers,save,r,auth:{principalId:ids.actor!,tenantId:ids.tenant!,cityId:ids.city!}};
  }
  type S=Awaited<ReturnType<typeof setup>>;
  const status=(s:S,command=s.r.command_id)=>http(new Request(`http://rounds.internal/v1/queries/CommandStatus?entity_id=${command}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}`,{headers:s.headers}));
  const snapshot=async(s:S)=>(await db.admin.query(`SELECT
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM rounds.intake_drafts x WHERE tenant_id=$1) drafts,
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY version) FROM rounds.intake_draft_revisions x WHERE tenant_id=$1) revisions,
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM rounds.intake_address_reviews x WHERE tenant_id=$1) reviews,
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM rounds.address_suggestions x WHERE tenant_id=$1) suggestions,
    (SELECT count(*) FROM rounds.domain_events WHERE tenant_id=$1) events,
    (SELECT count(*) FROM rounds.outbox_events WHERE tenant_id=$1) outbox,
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM rounds.deliveries x WHERE tenant_id=$1) deliveries,
    (SELECT count(*) FROM rounds.entrances WHERE tenant_id=$1) entrances,
    (SELECT count(*) FROM rounds.custody_events WHERE tenant_id=$1) custody,
    (SELECT count(*) FROM rounds.slot_reservations WHERE tenant_id=$1) reservations`,[s.ids.tenant])).rows[0];
  const row=async(s:S)=>(await db.admin.query('SELECT * FROM rounds.intake_drafts WHERE id=$1',[s.r.payload.draft_id])).rows[0];
  const review=async(s:S)=>(await db.admin.query('SELECT * FROM rounds.intake_address_reviews WHERE draft_id=$1 ORDER BY output_version DESC',[s.r.payload.draft_id])).rows[0];
  async function succeed(s:S,r=s.r){const response=await post(s,reviewAddressPath,r),value=await response.json();assert.equal(response.status,200,JSON.stringify(value));return value;}
  async function denied(s:S,code:string,r:unknown=s.r){const before=await snapshot(s),response=await post(s,reviewAddressPath,r);assert.equal((await response.json()).code,code);assert.deepEqual(await snapshot(s),before);}
  async function suggestion(s:S,props:{expired?:boolean;hash?:string;state?:string}={}){
    const id=randomUUID();await db.admin.query(`INSERT INTO rounds.address_suggestions(id,tenant_id,draft_id,input_hash,provider,changed_fields,suggested_text,point,state,expires_at)
      VALUES($1,$2,$3,$4,'labelled-geocoder-fixture','{"house_number":{"before":"12","after":"21"}}','บ้านเลขที่ 21',public.ST_SetSRID(public.ST_MakePoint(100.6,13.8),4326)::public.geography,$5,$6)`,
      [id,s.ids.tenant,s.r.payload.draft_id,props.hash??s.r.payload.input_hash,props.state??'proposed',props.expired?'2020-01-01T00:00:00Z':null]);return id;
  }
  await t.test('manual approval retains original input and independent contacts/quantities without physical/admission/entrance effects',async()=>{
    const s=await setup(),before=await snapshot(s),result=await succeed(s),after=await snapshot(s),record=await review(s),draft=await row(s);
    assert.equal(result.data.resource.version,2);assert.equal(draft.review_state,'review_needed');assert.deepEqual(draft.draft_payload,s.save.payload.draft);
    assert.equal(record.input_hash,s.r.payload.input_hash);assert.equal(record.actor_id,s.ids.actor);assert.equal(record.decision,'accept');
    assert.deepEqual(record.original_address,{address_text:s.r.payload.address_text,point:s.r.payload.point});assert.deepEqual(record.original_address,record.selected_address);
    assert.equal(record.proposed_address,null);assert.equal(record.input_version,'1');assert.equal(record.output_version,'2');
    assert.equal(after.revisions[0].field_provenance.address_text,'manual');assert.equal(after.revisions[1].field_provenance.address_text,'operator_review');
    assert.deepEqual(after.revisions[0],before.revisions[0]);for(const key of ['deliveries','custody','entrances','reservations'])assert.deepEqual(after[key],before[key]);
    assert.equal(Number(after.events),Number(before.events)+1);assert.equal(Number(after.outbox),Number(before.outbox)+1);
    const response=await status(s);assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'no-store');assert.deepEqual((await response.json()).data.result,result);
    assert(!JSON.stringify(result).includes('บ้าน'));assert(!JSON.stringify(result).includes('Johannes'));
  });
  for(const decision of ['accept','edit','reject'] as const)await t.test(`suggestion ${decision} preserves before/proposed/selected facts and original provider text`,async()=>{
    const s=await setup(),id=await suggestion(s);s.r.payload.suggestion_id=id;s.r.payload.decision=decision;
    if(decision==='accept')Object.assign(s.r.payload,{address_text:'บ้านเลขที่ 21',point:{longitude:100.6,latitude:13.8}});
    if(decision==='edit')Object.assign(s.r.payload,{address_text:'บ้านเลขที่ 12 ห้อง 7',point:{longitude:100.58,latitude:13.74}});
    await succeed(s);const record=await review(s),candidate=(await db.admin.query('SELECT * FROM rounds.address_suggestions WHERE id=$1',[id])).rows[0];
    assert.equal(record.original_address.address_text,s.save.payload.draft.address_text);assert.equal(record.proposed_address.address_text,'บ้านเลขที่ 21');
    assert.equal(record.selected_address.address_text,s.r.payload.address_text);assert.deepEqual(record.selected_address.point,s.r.payload.point);
    assert.equal(candidate.suggested_text,'บ้านเลขที่ 21');assert.equal(candidate.state,{accept:'accepted',edit:'edited',reject:'rejected'}[decision]);assert.equal(candidate.reviewed_by,s.ids.actor);
  });
  await t.test('accept/reject cannot smuggle unreviewed content; explicit edit is required',async()=>{
    const s=await setup();await denied(s,'VALIDATION_FAILED',{...s.r,payload:{...s.r.payload,address_text:'21'}});
    const id=await suggestion(s);for(const decision of ['accept','reject'])await denied(s,'VALIDATION_FAILED',{...s.r,command_id:randomUUID(),payload:{...s.r.payload,suggestion_id:id,decision,address_text:'different'}});
    await denied(s,'VALIDATION_FAILED',{...s.r,payload:{...s.r.payload,decision:'reject'}});
  });
  await t.test('text-only review does not invent a point or mark incomplete draft ready',async()=>{
    const s=await setup();s.r.payload.decision='edit';s.r.payload.point=null;await succeed(s);
    const d=await row(s);assert.equal(d.draft_payload.point,null);assert.equal(d.review_state,'review_needed');assert.equal(d.draft_payload.site_id,undefined);
  });
  await t.test('concurrent duplicate and response-loss status preserve one original decision after a later edit',async()=>{
    const s=await setup(),[a,b]=await Promise.all([succeed(s),succeed(s)]);assert.deepEqual(a,b);
    const update={...s.save,command_id:randomUUID(),expected_versions:[a.data.resource],payload:{draft_id:s.r.payload.draft_id,draft:{...s.save.payload.draft,address_text:'Later floor'}}};
    assert.equal((await post(s,saveDeliveryDraftPath,update)).status,200);const before=await snapshot(s);
    assert.deepEqual((await (await status(s)).json()).data.result,a);assert.deepEqual(await succeed(s),a);assert.deepEqual(await snapshot(s),before);
    assert.equal(before.reviews.length,1);assert.equal(before.reviews[0].output_version,2);assert.equal((await row(s)).version,'3');
    await denied(s,'IDEMPOTENCY_CONFLICT',{...s.r,payload:{...s.r.payload,decision:'edit',address_text:'different'}});
  });
  await t.test('review versus manual edit shares draft lock: one winner, no stale overwrite',async()=>{
    const s=await setup(),update={...s.save,command_id:randomUUID(),expected_versions:s.r.expected_versions,payload:{draft_id:s.r.payload.draft_id,draft:{...s.save.payload.draft,address_text:'New floor'}}};
    const responses=await Promise.all([post(s,reviewAddressPath,s.r),post(s,saveDeliveryDraftPath,update)]);
    assert.equal(responses.filter(r=>r.status===200).length,1);const loser=responses.find(r=>r.status!==200)!;assert.equal((await loser.json()).code,'STALE_VERSION');
    assert.equal((await row(s)).version,'2');assert.equal((await snapshot(s)).revisions.length,2);
  });
  await t.test('wrong hash, expired/superseded suggestion and current-version mismatch reject intact',async()=>{
    const s=await setup();await denied(s,'STALE_VERSION',{...s.r,payload:{...s.r.payload,input_hash:'f'.repeat(64)}});
    await denied(s,'STALE_VERSION',{...s.r,command_id:randomUUID(),expected_versions:s.r.expected_versions.map(v=>({...v,version:2}))});
    for(const props of [{expired:true},{hash:'e'.repeat(64)},{state:'superseded'}]){const a=await setup(),id=await suggestion(a,props);await denied(a,'STALE_VERSION',{...a.r,payload:{...a.r.payload,suggestion_id:id,decision:'reject'}});}
  });
  await t.test('review capability is independent from create, board and issue grants; revocation denies replay/status',async()=>{
    const s=await setup();for(const cap of ['deliveries.create','board.read','issues.decide']){await db.admin.query('UPDATE rounds.city_grants SET capabilities=$2 WHERE id=$1',[s.ids.grant,[cap]]);await denied(s,'NOT_AUTHORIZED');}
    await db.admin.query("UPDATE rounds.city_grants SET capabilities=ARRAY['deliveries.review'] WHERE id=$1",[s.ids.grant]);await succeed(s);assert.equal((await status(s)).status,200);
    assert.equal((await status(s,s.save.command_id)).status,403);
    await db.admin.query("UPDATE rounds.city_grants SET capabilities=ARRAY['deliveries.create'] WHERE id=$1",[s.ids.grant]);await denied(s,'NOT_AUTHORIZED');assert.equal((await status(s)).status,403);
  });
  await t.test('other actor/city/tenant and foreign suggestion cannot read or mutate original review',async()=>{
    const a=await setup(),b=await setup(),foreign=await suggestion(b);
    await denied(a,'NOT_AUTHORIZED',{...a.r,command_id:randomUUID(),payload:{...a.r.payload,suggestion_id:foreign,decision:'reject'}});
    await denied(b,'NOT_AUTHORIZED',{...a.r,command_id:randomUUID(),context:b.r.context});await succeed(a);
    assert.equal((await status(b,a.r.command_id)).status,404);
    const city=a.ids.city;a.ids.city=a.ids.otherCity!;assert.equal((await status(a)).status,403);a.ids.city=city!;
    await db.admin.query("UPDATE rounds.principals SET disabled_at=now() WHERE id=$1",[a.ids.actor]);assert.equal((await status(a)).status,403);
  });
  await t.test('closed, extracting, unmapped or corrupt revisions never receive a guessed review',async()=>{
    for(const change of ["review_state='committed'","review_state='extracting'","source_order_key='keep-source'","draft_payload='{}'","version=9"]){
      const s=await setup();await db.admin.query(`UPDATE rounds.intake_drafts SET ${change} WHERE id=$1`,[s.r.payload.draft_id]);
      await denied(s,change==='version=9'?'STALE_VERSION':'VALIDATION_FAILED');
    }
  });
  await t.test('rollback after all domain writes leaves no revision, review, suggestion, event or outbox change',async()=>{
    const s=await setup(),id=await suggestion(s);s.r.payload.suggestion_id=id;s.r.payload.decision='reject';const before=await snapshot(s),runner=new CommandTransactionRunner(db.pool);
    const work=reviewAddressWork(s.auth,s.r),execute=work.execute;work.execute=async(...args)=>{await execute(...args);throw new CommandRejection('VALIDATION_FAILED');};
    const result=await runner.run(work);assert.equal(result.result.state,'rejected');assert.deepEqual(await snapshot(s),before);
    const result2=await status(s);assert.equal((await result2.json()).data.result.state,'rejected');
  });
  await t.test('review history is append-only and RLS denies another city or tenant',async()=>{
    const a=await setup(),b=await setup();await succeed(a);const c=await db.pool.connect();
    try{await beginRestrictedTransaction(c,b.auth);assert.equal((await c.query('SELECT * FROM rounds.intake_address_reviews')).rowCount,0);await c.query('ROLLBACK');
      await beginRestrictedTransaction(c,{...a.auth,cityId:a.ids.otherCity!});assert.equal((await c.query('SELECT * FROM rounds.intake_address_reviews')).rowCount,0);await c.query('ROLLBACK');
      for(const sql of ["UPDATE rounds.intake_address_reviews SET decision='edit'","DELETE FROM rounds.intake_address_reviews"]){await beginRestrictedTransaction(c,a.auth);await assert.rejects(c.query(sql));await c.query('ROLLBACK');}
    }finally{await c.query('ROLLBACK');c.release();}
    await assert.rejects(db.admin.query("UPDATE rounds.intake_address_reviews SET decision='edit' WHERE draft_id=$1",[a.r.payload.draft_id]));
  });
  await t.test('invalid shape/root/body and wrong method/origin rejected; Node path registered',async()=>{
    const s=await setup();for(const r of [{...s.r,expected_versions:[]},{...s.r,payload:{...s.r.payload,input_hash:'bad'}},{...s.r,payload:{...s.r.payload,address_text:' '}},{...s.r,payload:{...s.r.payload,point:{latitude:91,longitude:100}}},{...s.r,payload:{...s.r.payload,entrance_confirmed:true}}])assert.throws(()=>validateReviewAddressRequest(r));
    assert.equal((await http(new Request('http://rounds.internal'+reviewAddressPath,{headers:s.headers}))).status,405);
    assert.equal((await post({...s,headers:{...s.headers,origin:'https://foreign.invalid'}},reviewAddressPath,s.r)).status,403);
    assert.equal((await post(s,reviewAddressPath+'?override=1',s.r)).status,400);
    assert(isV23Path(reviewAddressPath));assert(isOperationsIssueRequest(new Request('http://rounds.internal'+reviewAddressPath)));
  });
  await t.test('actual Node HTTP committed-response loss recovers same review without duplicate POST',async()=>{
    const s=await setup(),boundary=createV23NodeBoundary({handler:http,origin});let posts=0;
    const server=createServer((req,res)=>{if(req.method==='POST')posts++;void boundary(req,res).then(handled=>{if(!handled)res.writeHead(404).end();});});
    await new Promise<void>(r=>server.listen(0,'127.0.0.1',r));t.after(()=>new Promise<void>((r,j)=>server.close(e=>e?j(e):r())));
    const a=server.address();assert(a&&typeof a!=='string');const base=`http://127.0.0.1:${a.port}`;
    const response=await fetch(base+reviewAddressPath,{method:'POST',headers:s.headers,body:JSON.stringify(s.r)});assert.equal(response.status,200);await response.body?.cancel();
    const restored=await fetch(`${base}/v1/queries/CommandStatus?entity_id=${s.r.command_id}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}`,{headers:s.headers});
    assert.equal(restored.status,200);assert.equal((await restored.json()).data.result.command_id,s.r.command_id);assert.equal(posts,1);assert.equal((await snapshot(s)).reviews.length,1);
    const read=await fetch(`${base}/v1/queries/Workspace?view=manual_intake&entity_id=${s.r.payload.draft_id}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}`,{headers:s.headers});
    assert.equal(read.status,200);assert.equal((await read.json()).data.draft.version,2);
    assert.equal((await fetch(base+reviewAddressPath,{method:'OPTIONS',headers:{origin,'access-control-request-method':'POST','access-control-request-headers':'authorization,content-type'}})).status,204);
  });
});
