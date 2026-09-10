import assert from 'node:assert/strict';
import {createHash,randomUUID} from 'node:crypto';
import {createServer} from 'node:http';
import {test} from 'node:test';
import type {Wire_SaveDeliveryDraftRequest} from '../../../../packages/contracts/src/v23/pickup-wire.js';
import {canonicalCommandJson} from '../../src/v23/command-identity.js';
import {createOperationsIssueHttp,isOperationsIssueRequest} from '../../src/v23/operations-issue-http.js';
import {createV23NodeBoundary} from '../../src/v23/node-boundary.js';
import {beginRestrictedTransaction} from '../../src/v23/restricted-transaction.js';
import {saveDeliveryDraftPath,saveDeliveryDraftWork,intakeBodyLimit} from '../../src/v23/manual-intake.js';
import {statusPath} from '../../src/v23/pickup-http.js';
import {CommandRejection,CommandTransactionRunner,TransactionUnavailable} from '../../src/v23/transaction-runner.js';
import {startPostgisFixture} from './postgis-fixture.js';
import {seedWholeOrder} from './whole-order-fixture.js';
import {OperationsManualIntake} from '../../../../apps/operations-web/src/v23/operations-manual-intake.js';

test('manual intake: authenticated restricted SQL save/replay/update, without delivery creation',{timeout:120000},async t=>{
  const db=await startPostgisFixture();t.after(()=>db.close());
  const tokens=new Map<string,string>(),origin='http://localhost:3000';
  const dispatch=createOperationsIssueHttp({pool:db.pool,origin,verifyBearer:async token=>{const s=tokens.get(token);if(!s)throw new CommandRejection('UNAUTHENTICATED');return s;}});
  const runner=new CommandTransactionRunner(db.pool);
  async function setup(){
    const ids=await seedWholeOrder(db.admin),token=randomUUID(),subject=randomUUID();tokens.set(token,subject);
    await db.admin.query(`UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1`,[ids.actor,subject]);
    await db.admin.query(`UPDATE rounds.memberships SET role_code='dispatcher' WHERE id=$1`,[ids.membership]);
    await db.admin.query(`UPDATE rounds.city_grants SET capabilities=ARRAY['deliveries.create'] WHERE id=$1`,[ids.grant]);
    const r:Wire_SaveDeliveryDraftRequest={command_id:randomUUID(),context:{tenant_id:ids.tenant!,city_id:ids.city!},occurred_at:'2026-09-10T00:00:00Z',expected_versions:[],payload:{draft:{
      city_id:ids.city!,site_id:ids.site!,service_date:'2026-09-11',window:{starts_at:'2026-09-11T02:00:00Z',ends_at:'2026-09-11T04:00:00Z',timezone:'Asia/Bangkok'},
      address_text:'  บ้านเลขที่ 12 ซอย 39\nชั้น 2 ห้อง 5  ',instructions:'  Keep upright.\nCall at entrance.  ',
      contacts:[{role:'buyer',name:'Johannes buyer',email:'buyer@example.invalid'},{role:'recipient',name:'Siriporn test',phone:'+66000000000'}],
      manifest:[{line_key:'flowers',label:'Test flowers',quantity:5,unit:'item',handling_keys:['fragile']}],preparation_state:'preparing',ready_by:'2026-09-11T02:00:00Z'}}};
    return {ids,r,headers:{authorization:`Bearer ${token}`,origin,'content-type':'application/json'},auth:{principalId:ids.actor!,tenantId:ids.tenant!,cityId:ids.city!}};
  }
  type S=Awaited<ReturnType<typeof setup>>;
  const read=(s:S,id?:string,extra='')=>dispatch(new Request(`http://rounds.internal/v1/queries/Workspace?view=manual_intake&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}${id?'&entity_id='+id:''}${extra}`,{headers:s.headers}));
  const post=(s:S,r:unknown=s.r,headers=s.headers)=>dispatch(new Request('http://rounds.internal'+saveDeliveryDraftPath,{method:'POST',headers,body:JSON.stringify(r)}));
  const status=(s:S,id=s.r.command_id,city=s.ids.city)=>dispatch(new Request(`http://rounds.internal${statusPath}?entity_id=${id}&tenant_id=${s.ids.tenant}&city_id=${city}`,{headers:s.headers}));
  const snapshot=async(s:S)=>(await db.admin.query(`SELECT
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM rounds.deliveries x WHERE tenant_id=$1) deliveries,
    (SELECT count(*) FROM rounds.intake_drafts WHERE tenant_id=$1) drafts,
    (SELECT count(*) FROM rounds.intake_draft_revisions WHERE tenant_id=$1) revisions,
    (SELECT count(*) FROM rounds.domain_events WHERE tenant_id=$1) events,
    (SELECT count(*) FROM rounds.outbox_events WHERE tenant_id=$1) outbox,
    (SELECT count(*) FROM rounds.custody_events WHERE tenant_id=$1) custody,
    (SELECT count(*) FROM rounds.slot_reservations WHERE tenant_id=$1) holds,
    (SELECT count(*) FROM rounds.delivery_attempts WHERE tenant_id=$1) attempts,
    (SELECT count(*) FROM rounds.assignments WHERE tenant_id=$1) assignments`,[s.ids.tenant])).rows[0];
  async function saved(s:S,r=s.r){const response=await post(s,r);assert.equal(response.status,200,JSON.stringify(await response.clone().json()));return response.json();}
  async function update(s:S){const first=await saved(s);return {...s.r,command_id:randomUUID(),expected_versions:[first.data.resource],payload:{...s.r.payload,draft_id:first.data.resource.id}};}
  async function denied(s:S,code:string,r:unknown=s.r){const before=await snapshot(s),response=await post(s,r);assert.equal((await response.json()).code,code);assert.deepEqual(await snapshot(s),before);}

  await t.test('manual context reads actual city/day/sites with no implicit draft or operational write',async()=>{
    const s=await setup(),before=await snapshot(s),response=await read(s),value=await response.json();
    assert.equal(response.status,200,JSON.stringify(value));assert.equal(response.headers.get('cache-control'),'no-store');
    assert.equal(value.data.principal_id,s.ids.actor);assert.equal(value.data.city.id,s.ids.city);
    assert.equal(value.data.city.timezone,'Asia/Bangkok');assert.equal(value.data.draft,null);
    assert.deepEqual(value.data.sites.map((x:any)=>x.id),[s.ids.site]);
    const day=(await db.admin.query("SELECT (now() AT TIME ZONE 'Asia/Bangkok')::date::text AS day")).rows[0].day;
    assert.equal(value.data.city.current_service_date,day);assert.deepEqual(await snapshot(s),before);
  });
  await t.test('draft read returns exact latest revision, not a delivery or an invented pickup',async()=>{
    const s=await setup(),r=await update(s);r.payload.draft.instructions='  changed\n';await saved(s,r);
    const before=await snapshot(s),response=await read(s,r.payload.draft_id!),v=await response.json();
    assert.equal(response.status,200,JSON.stringify(v));assert.equal(v.data.draft.version,2);
    assert.deepEqual(v.data.draft.payload,r.payload.draft);assert.deepEqual(await snapshot(s),before);
    assert.equal((await read(s,s.ids.delivery)).status,403);
  });
  await t.test('draft reads deny foreign/missing IDs, other city, and revoked create capability',async()=>{
    const a=await setup(),b=await setup(),result=await saved(a),id=result.data.resource.id;
    assert.equal((await read(b,id)).status,403);assert.equal((await read(b,randomUUID())).status,403);
    const old=a.ids.city;a.ids.city=a.ids.otherCity!;assert.equal((await read(a,id)).status,403);a.ids.city=old!;
    await db.admin.query("UPDATE rounds.city_grants SET capabilities=ARRAY['board.read','issues.decide'] WHERE id=$1",[a.ids.grant]);
    assert.equal((await read(a,id)).status,403);assert.equal((await read(a)).status,403);
  });
  await t.test('unmapped, closed or changed-root drafts fail closed without data loss',async()=>{
    for(const change of ["draft_payload='{}'","review_state='committed'","source_order_key='preserve-source'","version=2"]){
      const s=await setup(),result=await saved(s),id=result.data.resource.id;
      await db.admin.query(`UPDATE rounds.intake_drafts SET ${change} WHERE id=$1`,[id]);
      const before=await snapshot(s),response=await read(s,id);assert.equal((await response.json()).code,'UPGRADE_REQUIRED');
      assert.deepEqual(await snapshot(s),before);
    }
  });
  await t.test('strict manual-view parameters reject duplicate IDs, foreign filters and implicit workspace',async()=>{
    const s=await setup();
    for(const suffix of ['&entity_id=bad','&entity_id='+randomUUID()+'&entity_id='+randomUUID(),'&view=manual_intake','&limit=1','&service_date=2026-09-10'])
      assert.equal((await (await read(s,undefined,suffix)).json()).code,'VALIDATION_FAILED');
    assert.ok(isOperationsIssueRequest(new Request('http://localhost/v1/queries/Workspace')));
  });
  await t.test('real browser controller saves and recovers a lost SQL receipt after controller restart, without a second POST',async()=>{
    const s=await setup(),rows=new Map<string,string>(),loginId=randomUUID();let posts=0,drop=true;
    const storage={getItem:(k:string)=>rows.get(k)??null,setItem:(k:string,v:string)=>{rows.set(k,v);},removeItem:(k:string)=>{rows.delete(k);}};
    const make=()=>new OperationsManualIntake({baseUrl:'http://localhost:3000',scope:{principalId:s.ids.actor!,tenantId:s.ids.tenant!,cityId:s.ids.city!,sessionEpoch:1},
      session:()=>({principalId:s.ids.actor!,sessionEpoch:1,bearer:s.headers.authorization.slice(7)}),recovery:{storage,loginId,currentLoginId:()=>loginId},
      fetch:async(input,init)=>{if(init?.method==='POST')posts++;const response=await dispatch(new Request(String(input),init));
        if(init?.method==='POST'&&drop){drop=false;throw new Error('Response lost after real SQL commit');}return response;}});
    let c=make();await c.open();assert.equal(c.state.phase,'ready');
    c.edit(s.r.payload.draft,'5 × Test flowers');await c.save();assert(c.state.pending);assert.equal(posts,1);
    c.dispose();c=make();const unopened=c.state;assert.equal(unopened.draft,null);await c.open();
    assert.equal(c.state.phase,'ready',c.state.errorCode??'');assert(!c.state.pending);assert(!c.state.dirty);
    assert.deepEqual(c.state.draft,s.r.payload.draft);assert.equal(c.state.productText,'5 × Test flowers');assert.equal(posts,1);
    c.edit({...c.state.draft!,instructions:'Edit after recovered save'});await c.save();assert.equal(c.state.phase,'ready');
    assert.equal(posts,2);assert.equal((await snapshot(s)).revisions,'2');assert.equal((await snapshot(s)).drafts,'1');c.dispose();
  });

  await t.test('creation stores exact buyer/recipient/Thai/quantity/ready_by with immutable manual provenance; no operational effects',async()=>{
    const s=await setup(),before=await snapshot(s),result=await saved(s),id=result.data.resource.id,after=await snapshot(s);
    const row=(await db.admin.query(`SELECT * FROM rounds.intake_drafts WHERE id=$1`,[id])).rows[0];
    assert.deepEqual(row.draft_payload,s.r.payload.draft);assert.equal(row.review_state,'draft');assert.equal(row.created_by,s.ids.actor);
    const rev=(await db.admin.query(`SELECT * FROM rounds.intake_draft_revisions WHERE draft_id=$1`,[id])).rows[0];
    assert.deepEqual(rev.payload,s.r.payload.draft);assert.equal(rev.input_hash,createHash('sha256').update(canonicalCommandJson(s.r.payload.draft)).digest('hex'));
    assert.equal(rev.field_provenance.contacts,'manual');assert.equal(rev.command_id,s.r.command_id);assert.equal(rev.version,'1');assert.equal(rev.actor_id,s.ids.actor);
    for(const k of ['deliveries','custody','holds','attempts','assignments'])assert.deepEqual(after[k],before[k]);
    for(const k of ['drafts','revisions','events','outbox'])assert.equal(Number(after[k])-Number(before[k]),1);
    const event=(await db.admin.query(`SELECT payload FROM rounds.domain_events WHERE command_id=$1`,[s.r.command_id])).rows[0].payload;
    assert.deepEqual(event.changes,[{family:'intake_drafts.review_state',resource_id:id,from_state:null,to_state:'draft',version:1}]);
    assert(!JSON.stringify(event).includes('บ้าน'));assert(!JSON.stringify(result).includes('Siriporn'));
    const state=await status(s);assert.equal(state.status,200);assert.deepEqual((await state.json()).data.result,result);
    assert.equal(state.headers.get('cache-control'),'no-store');assert.equal(state.headers.get('access-control-allow-origin'),origin);
  });
  await t.test('an incomplete manual draft may save without fabricated required fields',async()=>{
    const s=await setup();s.r.payload.draft={address_text:'',instructions:'',contacts:[],manifest:[]};
    const result=await saved(s),row=(await db.admin.query(`SELECT city_id,draft_payload FROM rounds.intake_drafts WHERE id=$1`,[result.data.resource.id])).rows[0];
    assert.equal(row.city_id,s.ids.city);assert.deepEqual(row.draft_payload,s.r.payload.draft);
  });
  await t.test('concurrent identical creation and replay after edit return original ID/version, exactly once',async()=>{
    const s=await setup(),[a,b]=await Promise.all([saved(s),saved(s)]);assert.deepEqual(a,b);
    const r={...s.r,command_id:randomUUID(),expected_versions:[a.data.resource],payload:{draft_id:a.data.resource.id,draft:{...s.r.payload.draft,instructions:'Changed'}}};
    await saved(s,r);const before=await snapshot(s);assert.deepEqual(await saved(s),a);assert.deepEqual(await snapshot(s),before);
    assert.deepEqual((await (await status(s)).json()).data.result,a);
  });
  await t.test('same command ID changed text rejects rather than creating another draft',async()=>{
    const s=await setup();await saved(s);await denied(s,'IDEMPOTENCY_CONFLICT',{...s.r,payload:{draft:{...s.r.payload.draft,address_text:'21'}}});
  });
  await t.test('update invalidates dependent reviews, preserves older submitted content and decision evidence',async()=>{
    const s=await setup(),r=await update(s),id=r.payload.draft_id!;
    await db.admin.query(`UPDATE rounds.intake_drafts SET review_state='ready' WHERE id=$1`,[id]);
    const suggestion=randomUUID();await db.admin.query(`INSERT INTO rounds.address_suggestions(id,tenant_id,draft_id,input_hash,provider,changed_fields,suggested_text,state,reviewed_by,reviewed_at)
      VALUES($1,$2,$3,'old','synthetic', '{}','21','accepted',$4,now())`,[suggestion,s.ids.tenant,id,s.ids.actor]);
    r.payload.draft={...r.payload.draft,address_text:'12 unchanged house, new floor'};const result=await saved(s,r);
    assert.equal(result.data.resource.version,2);
    const rows=(await db.admin.query(`SELECT payload FROM rounds.intake_draft_revisions WHERE draft_id=$1 ORDER BY version`,[id])).rows;
    assert.deepEqual(rows.map(x=>x.payload.address_text),[s.r.payload.draft.address_text,r.payload.draft.address_text]);
    const suggestionRow=(await db.admin.query(`SELECT state,reviewed_by,suggested_text FROM rounds.address_suggestions WHERE id=$1`,[suggestion])).rows[0];
    assert.deepEqual(suggestionRow,{state:'superseded',reviewed_by:s.ids.actor,suggested_text:'21'});
    assert.equal((await db.admin.query(`SELECT review_state FROM rounds.intake_drafts WHERE id=$1`,[id])).rows[0].review_state,'review_needed');
    const second={...r,command_id:randomUUID(),expected_versions:[result.data.resource]};await saved(s,second);
    assert.equal((await db.admin.query(`SELECT count(*) FROM rounds.intake_draft_revisions WHERE draft_id=$1`,[id])).rows[0].count,'3');
    await denied(s,'STALE_VERSION',{...r,command_id:randomUUID()});
  });
  await t.test('two different edits to one version: one winner, no overwrite or duplicate fact',async()=>{
    const s=await setup(),r=await update(s),other={...r,command_id:randomUUID(),payload:{...r.payload,draft:{...r.payload.draft,instructions:'other edit'}}};
    const responses=await Promise.all([post(s,r),post(s,other)]);assert.equal(responses.filter(r=>r.status===200).length,1);
    assert.equal((await responses.find(r=>r.status!==200)!.json()).code,'STALE_VERSION');
    assert.equal((await snapshot(s)).revisions,'2');
  });
  for(const state of ['committed','discarded'])await t.test(`${state} draft cannot be resurrected`,async()=>{
    const s=await setup(),r=await update(s);await db.admin.query(`UPDATE rounds.intake_drafts SET review_state=$2 WHERE id=$1`,[r.payload.draft_id,state]);await denied(s,'VALIDATION_FAILED',r);
  });
  await t.test('a supplied missing ID is update-only, not another creation',async()=>{
    const s=await setup(),id=randomUUID();await denied(s,'NOT_AUTHORIZED',{...s.r,expected_versions:[{aggregate_type:'intake_drafts',id,version:1}],payload:{...s.r.payload,draft_id:id}});
  });
  await t.test('unmapped or corrupted current draft is preserved, never silently adopted',async()=>{
    const s=await setup(),r=await update(s),id=r.payload.draft_id!;
    await db.admin.query(`UPDATE rounds.intake_drafts SET draft_payload='{"unknown":"preserve"}' WHERE id=$1`,[id]);
    await denied(s,'VALIDATION_FAILED',r);
    assert.deepEqual((await db.admin.query(`SELECT draft_payload FROM rounds.intake_drafts WHERE id=$1`,[id])).rows[0].draft_payload,{unknown:'preserve'});
    const old=(await db.admin.query(`INSERT INTO rounds.intake_drafts(tenant_id,city_id,draft_payload,review_state,created_by)
      VALUES($1,$2,$3,'draft',$4) RETURNING id`,[s.ids.tenant,s.ids.city,JSON.stringify(s.r.payload.draft),s.ids.actor])).rows[0].id;
    await denied(s,'VALIDATION_FAILED',{...r,command_id:randomUUID(),expected_versions:[{aggregate_type:'intake_drafts',id:old,version:1}],payload:{...r.payload,draft_id:old}});
  });
  await t.test('editing during extraction invalidates the original revision without applying a late suggestion',async()=>{
    const s=await setup(),r=await update(s);await db.admin.query(`UPDATE rounds.intake_drafts SET review_state='extracting' WHERE id=$1`,[r.payload.draft_id]);
    await saved(s,r);assert.equal((await db.admin.query(`SELECT review_state FROM rounds.intake_drafts WHERE id=$1`,[r.payload.draft_id])).rows[0].review_state,'review_needed');
    await denied(s,'STALE_VERSION',{...r,command_id:randomUUID()}); // no OCR worker is enabled
  });
  await t.test('explicit city-local overnight window is retained, wrong timezone or service day rejects',async()=>{
    const s=await setup();s.r.payload.draft.window={starts_at:'2026-09-11T23:00:00+07:00',ends_at:'2026-09-12T02:00:00+07:00',timezone:'Asia/Bangkok'};
    await saved(s);
    for(const change of [{service_date:'2026-09-12'},{window:{...s.r.payload.draft.window,timezone:'UTC'}}])await denied(s,'VALIDATION_FAILED',{...s.r,command_id:randomUUID(),payload:{draft:{...s.r.payload.draft,...change}}});
  });
  await t.test('present pickup must be in this city and unarchived; cargo class enforces declared units/discreteness',async()=>{
    const s=await setup();await db.admin.query(`UPDATE rounds.sites SET city_id=$2 WHERE id=$1`,[s.ids.site,s.ids.otherCity]);await denied(s,'NOT_AUTHORIZED');
    await db.admin.query(`UPDATE rounds.sites SET city_id=$2,archived_at=now() WHERE id=$1`,[s.ids.site,s.ids.city]);s.r.command_id=randomUUID();await denied(s,'NOT_AUTHORIZED');
    await db.admin.query(`UPDATE rounds.sites SET archived_at=NULL WHERE id=$1`,[s.ids.site]);
    const cargo=randomUUID();await db.admin.query(`INSERT INTO rounds.cargo_classes(id,tenant_id,code,name,unit,discrete) VALUES($1,$2,'flowers','Test flowers','item',true)`,[cargo,s.ids.tenant]);
    s.r.payload.draft.manifest[0]!.cargo_class_id=cargo;s.r.command_id=randomUUID();
    await saved(s);
    for(const change of [{quantity:0.5},{unit:'kg'}])await denied(s,'VALIDATION_FAILED',{...s.r,command_id:randomUUID(),payload:{draft:{...s.r.payload.draft,manifest:[{...s.r.payload.draft.manifest[0]!,...change}]}}});
  });
  await t.test('rollback after all writes leaves no draft, revision, event, outbox or receipt',async()=>{
    const s=await setup(),work=saveDeliveryDraftWork(s.auth,s.r),execute=work.execute,before=await snapshot(s);
    work.execute=async(...args)=>{await execute(...args);throw new Error('Injected rollback after writes');};
    await assert.rejects(runner.run(work),e=>e instanceof TransactionUnavailable&&e.code==='PROVIDER_UNAVAILABLE');assert.deepEqual(await snapshot(s),before);
    assert.equal((await status(s)).status,404);await saved(s);
  });
  await t.test('typed rejection after writes rolls back domain data, keeps only rejected receipt',async()=>{
    const s=await setup(),work=saveDeliveryDraftWork(s.auth,s.r),execute=work.execute,before=await snapshot(s);
    work.execute=async(...args)=>{await execute(...args);throw new CommandRejection('VALIDATION_FAILED');};
    const rejected=await runner.run(work);assert.equal(rejected.result.state,'rejected');assert.deepEqual(await snapshot(s),before);
    assert.deepEqual((await (await status(s)).json()).data.result,rejected.result);
  });
  for(const column of ['source_order_key','original_payload_reference'])await t.test(`source-backed ${column} cannot be relabelled manual`,async()=>{
    const s=await setup(),r=await update(s);await db.admin.query(`UPDATE rounds.intake_drafts SET ${column}='original' WHERE id=$1`,[r.payload.draft_id]);await denied(s,'VALIDATION_FAILED',r);
  });
  await t.test('cross-city and cross-tenant draft IDs cannot be read or edited',async()=>{
    const a=await setup(),b=await setup(),r=await update(a);await denied(b,'NOT_AUTHORIZED',{...r,context:b.r.context,payload:{...r.payload,draft:b.r.payload.draft}});
    const c=db.pool;const client=await c.connect();
    try{await beginRestrictedTransaction(client,{...a.auth,cityId:a.ids.otherCity!});
      assert.equal((await client.query(`SELECT id FROM rounds.intake_drafts WHERE id=$1`,[r.payload.draft_id])).rowCount,0);
      assert.equal((await client.query(`SELECT draft_id FROM rounds.intake_draft_revisions WHERE draft_id=$1`,[r.payload.draft_id])).rowCount,0);await client.query('ROLLBACK');
    }finally{client.release();}
    assert.equal((await status(a,a.r.command_id,a.ids.otherCity)).status,403);
    assert.equal((await status(b,a.r.command_id)).status,404);
  });
  await t.test('same tenant, different actor cannot retrieve another actor receipt',async()=>{
    const s=await setup();await saved(s);const actor=randomUUID(),subject=randomUUID(),token=randomUUID(),membership=randomUUID();tokens.set(token,subject);
    await db.admin.query(`INSERT INTO rounds.principals(id,auth_subject,display_name) VALUES($1,$2,'Second operator')`,[actor,subject]);
    await db.admin.query(`INSERT INTO rounds.memberships(id,tenant_id,principal_id,role_code,status) VALUES($1,$2,$3,'dispatcher','active')`,[membership,s.ids.tenant,actor]);
    await db.admin.query(`INSERT INTO rounds.city_grants(tenant_id,membership_id,city_id,capabilities) VALUES($1,$2,$3,ARRAY['deliveries.create'])`,[s.ids.tenant,membership,s.ids.city]);
    assert.equal((await status({...s,headers:{...s.headers,authorization:`Bearer ${token}`}})).status,404);
  });
  for(const capabilities of [[],['board.read'],['issues.decide'],['driver.assigned_work']])await t.test(`grant ${capabilities.join(',')||'none'} cannot save or recover draft receipts`,async()=>{
    const s=await setup();await saved(s);await db.admin.query(`UPDATE rounds.city_grants SET capabilities=$2 WHERE id=$1`,[s.ids.grant,capabilities]);
    await denied(s,'NOT_AUTHORIZED');assert.equal((await status(s)).status,403);
  });
  for(const mutation of ['membership','city','tenant','principal'])await t.test(`${mutation} revocation denies save, replay and status`,async()=>{
    const s=await setup();await saved(s);
    if(mutation==='membership')await db.admin.query(`UPDATE rounds.memberships SET archived_at=now() WHERE id=$1`,[s.ids.membership]);
    if(mutation==='city')await db.admin.query(`UPDATE rounds.cities SET enabled=false WHERE id=$1`,[s.ids.city]);
    if(mutation==='tenant')await db.admin.query(`UPDATE rounds.tenants SET status='suspended' WHERE id=$1`,[s.ids.tenant]);
    if(mutation==='principal')await db.admin.query(`UPDATE rounds.principals SET disabled_at=now() WHERE id=$1`,[s.ids.actor]);
    await denied(s,'NOT_AUTHORIZED');assert.equal((await status(s)).status,403);
  });
  for(const field of ['site_id','brand_id','slot_occurrence_id'])await t.test(`unknown ${field} cannot become draft authority`,async()=>{
    const s=await setup();await denied(s,'NOT_AUTHORIZED',{...s.r,payload:{draft:{...s.r.payload.draft,[field]:randomUUID()}}});
  });
  await t.test('API role cannot update/delete immutable revision evidence',async()=>{
    const s=await setup();await saved(s);const client=await db.pool.connect();
    try{for(const sql of [`UPDATE rounds.intake_draft_revisions SET payload='{}'`,`DELETE FROM rounds.intake_draft_revisions`]){
      await beginRestrictedTransaction(client,s.auth);await assert.rejects(client.query(sql),/permission denied/);await client.query('ROLLBACK');
    }}finally{client.release();}
  });
  await t.test('actual Node HTTP response loss recovers original status without duplicate POST',async()=>{
    const s=await setup(),boundary=createV23NodeBoundary({handler:dispatch,origin}),server=createServer((req,res)=>{void boundary(req,res).then(handled=>{if(!handled)res.writeHead(404).end();});});
    await new Promise<void>(r=>server.listen(0,'127.0.0.1',r));t.after(()=>new Promise<void>((r,j)=>server.close(e=>e?j(e):r())));
    const address=server.address();assert(address&&typeof address!=='string');const base=`http://127.0.0.1:${address.port}`;
    const request=new Request(base+saveDeliveryDraftPath,{method:'POST',headers:s.headers,body:JSON.stringify(s.r)});assert(isOperationsIssueRequest(request));
    const response=await fetch(request);assert.equal(response.status,200);await response.body?.cancel(); // discard a real committed response
    const result=await fetch(`${base}${statusPath}?entity_id=${s.r.command_id}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}`,{headers:s.headers});
    assert.equal(result.status,200);assert.equal((await result.json()).data.result.command_id,s.r.command_id);assert.equal((await snapshot(s)).drafts,'1');
    const preflight=await fetch(base+saveDeliveryDraftPath,{method:'OPTIONS',headers:{origin,'access-control-request-method':'POST','access-control-request-headers':'authorization,content-type'}});assert.equal(preflight.status,204);
  });
  await t.test('HTTP rejects wrong method/origin, extra selectors and oversized draft before writes',async()=>{
    const s=await setup(),before=await snapshot(s);
    assert.equal((await dispatch(new Request('http://rounds.internal'+saveDeliveryDraftPath,{headers:s.headers}))).status,405);
    assert.equal((await post(s,s.r,{...s.headers,origin:'https://foreign.invalid'})).status,403);
    assert.equal((await dispatch(new Request('http://rounds.internal'+saveDeliveryDraftPath+'?demo=true',{method:'POST',headers:s.headers,body:JSON.stringify(s.r)}))).status,400);
    assert.equal((await post(s,{...s.r,payload:{draft:{...s.r.payload.draft,address_text:'x'.repeat(intakeBodyLimit+1)}}})).status,400);
    assert.deepEqual(await snapshot(s),before);
  });
});

test('intake migration preserves unmapped old rows byte-for-byte and does not invent revisions',{timeout:60000},async t=>{
  let old:any,ids:Record<string,string>;
  const db=await startPostgisFixture({beforeIntakeMigration:async admin=>{
    ids=await seedWholeOrder(admin);old=(await admin.query(`INSERT INTO rounds.intake_drafts(tenant_id,city_id,draft_payload,original_payload_reference,review_state,created_by)
      VALUES($1,$2,'{"original":"do not erase"}','private-source','review_needed',$3) RETURNING *`,[ids.tenant,ids.city,ids.actor])).rows[0];
  }});t.after(()=>db.close());
  assert.deepEqual((await db.admin.query(`SELECT * FROM rounds.intake_drafts WHERE id=$1`,[old.id])).rows[0],old);
  assert.equal((await db.admin.query(`SELECT count(*) FROM rounds.intake_draft_revisions`)).rows[0].count,'0');
});
