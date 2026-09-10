import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { test } from 'node:test';
import { createOperationsIssueHttp } from '../../src/v23/operations-issue-http.js';
import { operationsBoardPath } from '../../src/v23/operations-issue-query.js';
import { authorizeDeliveryBoard, projectDeliveryBoard } from '../../src/v23/delivery-board-query.js';
import { beginRestrictedTransaction } from '../../src/v23/restricted-transaction.js';
import { CommandRejection,CommandTransactionRunner } from '../../src/v23/transaction-runner.js';
import {localPickupWork} from '../../src/v23/confirm-local-pickup.js';
import type {Wire_ConfirmPickupRequest} from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { createV23NodeBoundary } from '../../src/v23/node-boundary.js';
import { OperationsDeliveryBoard } from '../../../../apps/operations-web/src/v23/operations-delivery-board.js';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';

test('ADR-Q06 delivery board: real restricted SQL and HTTP, no domain mutations',{timeout:120000},async t=>{
  const db=await startPostgisFixture();t.after(()=>db.close());
  // Only provider bearer verification is a double. Actual principal resolution,
  // city capabilities, RLS, snapshot, projection and HTTP boundary execute.
  const subjects=new Map<string,string>();
  const http=createOperationsIssueHttp({pool:db.pool,origin:'http://localhost:3000',verifyBearer:async token=>{
    const subject=subjects.get(token);if(!subject)throw new CommandRejection('UNAUTHENTICATED');return subject;
  }});
  async function setup(capability='board.read'){
    const ids=await seedWholeOrder(db.admin),actor=randomUUID(),membership=randomUUID(),grant=randomUUID(),subject=randomUUID(),token=randomUUID();
    subjects.set(token,subject);
    await db.admin.query(`INSERT INTO rounds.principals(id,auth_subject,display_name) VALUES($1,$2,'Johannes board test')`,[actor,subject]);
    await db.admin.query(`INSERT INTO rounds.memberships(id,tenant_id,principal_id,role_code,status) VALUES($1,$2,$3,'dispatcher','active')`,[membership,ids.tenant,actor]);
    await db.admin.query(`INSERT INTO rounds.city_grants(id,tenant_id,membership_id,city_id,capabilities) VALUES($1,$2,$3,$4,ARRAY[$5]::text[])`,[grant,ids.tenant,membership,ids.city,capability]);
    const date=(await db.admin.query(`SELECT service_date::text AS date FROM rounds.deliveries WHERE id=$1`,[ids.delivery])).rows[0].date as string;
    return {ids,actor,membership,grant,subject,token,date,auth:{principalId:actor,tenantId:ids.tenant!,cityId:ids.city!}};
  }
  type S=Awaited<ReturnType<typeof setup>>;
  function read(s:S,changes:Record<string,string>={},extra='',headers:Record<string,string>={},method='GET'){
    const params=new URLSearchParams({tenant_id:s.ids.tenant!,city_id:s.ids.city!,service_date:s.date,view:'delivery_board',...changes});
    return http(new Request('http://rounds.internal'+operationsBoardPath+'?'+params+extra,
      {method,headers:{authorization:`Bearer ${s.token}`,origin:'http://localhost:3000',...headers}}));
  }
  async function data(s:S,changes:Record<string,string>={}){
    const response=await read(s,changes);assert.equal(response.status,200,await response.clone().text());
    assert.equal(response.headers.get('cache-control'),'no-store');assert.equal(response.headers.get('x-content-type-options'),'nosniff');
    const body=await response.json();assert.equal(body.next_cursor,null);return body.data;
  }
  async function code(response:Promise<Response>,expected:string){assert.equal((await (await response).json()).code,expected);}
  async function snapshot(s:S){return (await db.admin.query(`SELECT
    (SELECT to_jsonb(d) FROM rounds.deliveries d WHERE id=$2) AS delivery,
    (SELECT to_jsonb(r) FROM rounds.rounds r WHERE id=$3) AS round,
    (SELECT count(*) FROM rounds.custody_events WHERE tenant_id=$1) AS custody,
    (SELECT count(*) FROM rounds.trip_receipts WHERE tenant_id=$1) AS receipts,
    (SELECT count(*) FROM rounds.delivery_attempts WHERE tenant_id=$1) AS attempts,
    (SELECT count(*) FROM rounds.issues WHERE tenant_id=$1) AS issues,
    (SELECT count(*) FROM rounds.issue_decisions WHERE tenant_id=$1) AS decisions,
    (SELECT count(*) FROM rounds.domain_events WHERE tenant_id=$1) AS events,
    (SELECT count(*) FROM rounds.outbox_events WHERE tenant_id=$1) AS outbox`,[s.ids.tenant,s.ids.delivery,s.ids.round])).rows[0];}
  async function contact(s:S,name:string,role='recipient'){
    return (await db.admin.query(`INSERT INTO rounds.delivery_contacts(tenant_id,delivery_id,role,display_name,notification_permissions,contact_secret_reference,masked_contact)
      VALUES($1,$2,$3,$4,'{}','PRIVATE-CONTACT','PRIVATE-MASK') RETURNING id`,[s.ids.tenant,s.ids.delivery,role,name])).rows[0].id;
  }
  async function clone(s:S,count=1){
    return (await db.admin.query(`INSERT INTO rounds.deliveries(tenant_id,city_id,pickup_site_id,human_reference,service_date,timezone,window_start_at,window_end_at,address_text,readiness,outcome,evidence_state,proof_policy_id,created_by,preparation_state)
      SELECT d.tenant_id,d.city_id,d.pickup_site_id,$3||'-'||n,d.service_date,d.timezone,d.window_start_at+interval '1 minute',d.window_end_at,d.address_text,'draft','open','none',d.proof_policy_id,d.created_by,'unknown'
      FROM rounds.deliveries d CROSS JOIN generate_series(1,$2::int) n WHERE d.id=$1 RETURNING id`,[s.ids.delivery,count,randomUUID()])).rows.map(r=>r.id as string);
  }
  const now=async(s:S)=>(await data(s,{display:'now'})).now;
  await t.test('ADR-Q07 opt-in shape, city-local day and no-write ready facts preserve old response',async()=>{
    const s=await setup(),before=await snapshot(s),old=await data(s),v=await data(s,{display:'now'});
    assert.equal(old.now,undefined);const {now:n,...unchanged}=v;assert.deepEqual(unchanged,old);
    assert.deepEqual(n.entries,[{delivery_id:s.ids.delivery,bucket:'ready',reason:'ready_for_pickup'}]);
    const day=(await db.admin.query(`SELECT (now() AT TIME ZONE 'Asia/Bangkok')::date::text AS day`)).rows[0].day;
    assert.equal(n.current_service_date,day);assert.deepEqual(await snapshot(s),before);
    assert(!JSON.stringify(n).includes(s.ids.driver!));assert(!JSON.stringify(n).includes(s.subject));
    await code(read(s,{view:'pickup_issues',display:'now'}),'VALIDATION_FAILED');
  });
  await t.test('ADR-Q07 same-scope issue existence, resolved/archive and Round-only precedence without private details',async()=>{
    const s=await setup(),other=await setup(),issue=randomUUID();
    await db.admin.query(`INSERT INTO rounds.issues(id,tenant_id,delivery_id,round_id,issue_type,reason_code,state,detail,reported_at,reported_by)
      VALUES($1,$2,$3,$4,'package','missing','open','PRIVATE-ISSUE-DETAIL',now(),$5)`,[issue,s.ids.tenant,s.ids.delivery,s.ids.round,s.ids.actor]);
    let n=await now(s);assert.equal(n.entries[0].reason,'issue');assert(!JSON.stringify(n).includes(issue));assert(!JSON.stringify(n).includes('PRIVATE'));
    assert.equal((await now(other)).entries[0].bucket,'ready');
    await db.admin.query(`UPDATE rounds.issues SET state='resolved' WHERE id=$1`,[issue]);assert.equal((await now(s)).entries[0].bucket,'ready');
    await db.admin.query(`UPDATE rounds.issues SET state='open',archived_at=now() WHERE id=$1`,[issue]);assert.equal((await now(s)).entries[0].bucket,'ready');
    await db.admin.query(`UPDATE rounds.issues SET archived_at=NULL,delivery_id=NULL WHERE id=$1`,[issue]);assert.equal((await now(s)).entries[0].bucket,'action');
    await db.admin.query(`UPDATE rounds.deliveries SET outcome='delivered' WHERE id=$1`,[s.ids.delivery]);assert.equal((await now(s)).entries[0].bucket,'action');
  });
  await t.test('ADR-Q07 pre-arrival, declined assignment, missing unit and point do not manufacture Ready',async()=>{
    const s=await setup();await db.admin.query(`UPDATE rounds.rounds SET state='staged',departure_gate='awaiting_receipt' WHERE id=$1`,[s.ids.round]);
    assert.equal((await now(s)).entries[0].reason,'awaiting_receipt');assert.equal((await snapshot(s)).receipts,'0');
    await db.admin.query(`UPDATE rounds.rounds SET departure_gate='ready' WHERE id=$1`,[s.ids.round]);
    await db.admin.query(`UPDATE rounds.assignments SET state='cannot_comply' WHERE id=$1`,[s.ids.assignment]);assert.equal((await now(s)).entries[0].reason,'assignment_declined');
    await db.admin.query(`UPDATE rounds.assignments SET state='acknowledged' WHERE id=$1`,[s.ids.assignment]);
    await db.admin.query(`UPDATE rounds.deliveries SET preparation_state='unknown' WHERE id=$1`,[s.ids.delivery]);assert.equal((await now(s)).entries[0].reason,'awaiting_preparation');
    await db.admin.query(`UPDATE rounds.deliveries SET preparation_state='ready',destination=NULL WHERE id=$1`,[s.ids.delivery]);assert.equal((await now(s)).entries[0].bucket,'planned');
    const [draft]=await clone(s);assert.equal((await now(s)).entries.find((e:any)=>e.delivery_id===draft).bucket,'planned');
  });
  await t.test('ADR-Q07 actual restricted pickup transaction changes Ready to On road, not Done',async()=>{
    const s=await setup(),ids=s.ids;assert.equal((await now(s)).entries[0].bucket,'ready');
    await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`,[ids.tenant,ids.delivery,ids.round,ids.unit]);
    const r:Wire_ConfirmPickupRequest={command_id:randomUUID(),context:{tenant_id:ids.tenant!,city_id:ids.city!},occurred_at:'2026-09-08T00:00:00Z',execution_fence:{assignment_id:ids.assignment!,assignment_version:1,observation_id:randomUUID()},expected_versions:[{aggregate_type:'rounds',id:ids.round!,version:1},{aggregate_type:'stops',id:ids.pickup!,version:1},{aggregate_type:'manifests',id:ids.manifest!,version:1},{aggregate_type:'fulfillment_units',id:ids.unit!,version:1}],payload:{round_id:ids.round!,pickup_stop_id:ids.pickup!,manifest_ids:[ids.manifest!],fulfillment_unit_ids:[ids.unit!],quantities:[{line_id:ids.line!,quantity:5}]}};
    const result=await new CommandTransactionRunner(db.pool).run(localPickupWork({principalId:ids.actor!,tenantId:ids.tenant!,cityId:ids.city!},r));assert.equal(result.result.state,'committed');
    const before=await snapshot(s),n=await now(s);assert.equal(n.entries[0].reason,'collected');assert.deepEqual(await snapshot(s),before);assert.equal(before.custody,'1');
    // Below are labelled reader fixtures, not execution-handler acceptance.
    await db.admin.query(`UPDATE rounds.delivery_attempts SET state='handed_over' WHERE tenant_id=$1`,[ids.tenant]);assert.equal((await now(s)).entries[0].reason,'handed_over');
    await db.admin.query(`UPDATE rounds.deliveries SET outcome='delivered',evidence_state='complete' WHERE id=$1`,[ids.delivery]);assert.equal((await now(s)).entries[0].reason,'delivered');
  });
  await t.test('ADR-Q07 failed current attempt is Action; cancelled and unrelated attempts are not adopted',async()=>{
    const s=await setup(),ids=s.ids;
    await db.admin.query(`INSERT INTO rounds.delivery_attempts(tenant_id,delivery_id,stop_id,driver_id,attempt_number,state,fulfillment_unit_id)
      VALUES($1,$2,$3,$4,1,'failed',$5)`,[ids.tenant,ids.delivery,ids.dropoff,ids.driver,ids.unit]);
    assert.equal((await now(s)).entries[0].reason,'execution_failed');
    await db.admin.query(`UPDATE rounds.delivery_attempts SET state='cancelled' WHERE tenant_id=$1`,[ids.tenant]);assert.equal((await now(s)).entries[0].bucket,'ready');
    await db.admin.query(`UPDATE rounds.delivery_attempts SET state='failed',archived_at=now() WHERE tenant_id=$1`,[ids.tenant]);assert.equal((await now(s)).entries[0].bucket,'ready');
  });
  await t.test('ADR-Q07 collected state without timestamp rejects instead of inventing motion',async()=>{
    const s=await setup();await db.admin.query(`UPDATE rounds.fulfillment_units SET state='collected' WHERE id=$1`,[s.ids.unit]);await code(read(s,{display:'now'}),'SOURCE_STALE');
  });
  await t.test('no issue required; exact facts, context, planning, destination provenance and no writes',async()=>{
    const s=await setup();await contact(s,'Siriporn <test>');
    await db.admin.query(`UPDATE rounds.deliveries SET private_access_notes='PRIVATE-NOTES' WHERE id=$1`,[s.ids.delivery]);
    const before=await snapshot(s),v=await data(s),d=v.deliveries[0];
    assert.equal(v.principal_id,s.actor);assert.equal(v.tenant_id,s.ids.tenant);assert.equal(v.city_id,s.ids.city);assert.equal(v.service_date,s.date);
    assert.deepEqual(v.workspace,{name:'Isolated test tenant',version:1});assert.deepEqual(v.city,{name:'Test city',version:1,timezone:'Asia/Bangkok'});
    assert.equal(v.delivery_count,1);assert.equal(d.id,s.ids.delivery);assert.equal(d.version,1);assert.equal(d.reference,'TEST-ONLY');
    assert.equal(d.recipient_name,'Siriporn <test>');assert.equal(d.address_text,'Synthetic destination');assert.equal(d.brand,null);
    assert.deepEqual(d.pickup_site,{id:s.ids.site,name:'Synthetic pickup'});
    assert.deepEqual(d.destination,{latitude:13.7,longitude:100.5,source:'delivery_destination'});assert.equal(d.destination_version,1);assert.equal(d.entrance_revision_id,null);
    assert.equal(d.readiness,'ready');assert.equal(d.preparation_state,'ready');assert.equal(d.outcome,'open');assert.equal(d.evidence_state,'none');
    assert.deepEqual(d.planning,{round_id:s.ids.round,round_version:1,round_state:'released',departure_gate:'ready',stop_id:s.ids.dropoff,stop_version:1,stop_state:'released'});
    assert(!JSON.stringify(v).includes('PRIVATE'));assert(!JSON.stringify(v).includes(s.ids.driver!));assert(!JSON.stringify(v).includes(s.subject));
    assert.equal(v.fleet,undefined);assert.equal(v.counts,undefined);assert.deepEqual(await snapshot(s),before);
  });
  await t.test('pre-arrival plans and independent unplanned orders are visible without an invented receipt',async()=>{
    const s=await setup();const [other]=await clone(s);
    await db.admin.query(`UPDATE rounds.rounds SET state='staged',departure_gate='awaiting_receipt' WHERE id=$1`,[s.ids.round]);
    await db.admin.query(`UPDATE rounds.deliveries SET preparation_state='unknown',readiness='held' WHERE id=$1`,[s.ids.delivery]);
    const before=await snapshot(s),v=await data(s);assert.equal(v.delivery_count,2);
    assert.equal(v.deliveries[0].planning.round_state,'staged');assert.equal(v.deliveries[0].planning.departure_gate,'awaiting_receipt');
    assert.equal(v.deliveries[0].readiness,'held');assert.equal(v.deliveries[0].preparation_state,'unknown');
    assert.equal(v.deliveries[1].id,other);assert.equal(v.deliveries[1].planning,null);assert.equal(v.deliveries[1].destination,null);
    assert.equal(before.receipts,'0');assert.deepEqual(await snapshot(s),before);
  });
  await t.test('exact city/date/archive scope; genuine empty date is a typed empty success',async()=>{
    const s=await setup();const [foreignCity,archived,differentDate]=await clone(s,3);await setup();
    await db.admin.query('UPDATE rounds.deliveries SET city_id=$2 WHERE id=$1',[foreignCity,s.ids.otherCity]);
    await db.admin.query('UPDATE rounds.deliveries SET archived_at=now() WHERE id=$1',[archived]);
    await db.admin.query(`UPDATE rounds.deliveries SET service_date=service_date+1 WHERE id=$1`,[differentDate]);
    assert.deepEqual((await data(s)).deliveries.map((d:any)=>d.id),[s.ids.delivery]);
    const empty=await data(s,{service_date:'2001-01-01'});assert.equal(empty.delivery_count,0);assert.deepEqual(empty.deliveries,[]);
    await code(read(s,{city_id:s.ids.otherCity!}),'NOT_AUTHORIZED');
    const other=await setup();await code(read(s,{tenant_id:other.ids.tenant!,city_id:other.ids.city!}),'NOT_AUTHORIZED');
  });
  await t.test('board.read and issues.decide do not imply each other',async()=>{
    const s=await setup();assert.equal((await read(s)).status,200);await code(read(s,{view:'pickup_issues'}),'NOT_AUTHORIZED');
    await db.admin.query(`UPDATE rounds.city_grants SET capabilities=ARRAY['issues.decide'] WHERE id=$1`,[s.grant]);
    await code(read(s),'NOT_AUTHORIZED');const issues=await data(s,{view:'pickup_issues'});assert.deepEqual(issues.issues,[]);assert.equal(issues.deliveries,undefined);
  });
  for(const revoke of ['principal','membership','grant','city','tenant'])await t.test('revoked '+revoke+' denies fresh board read',async()=>{
    const s=await setup();assert.equal((await read(s)).status,200);
    const table={principal:'principals',membership:'memberships',grant:'city_grants',city:'cities',tenant:'tenants'}[revoke]!;
    const id={principal:s.actor,membership:s.membership,grant:s.grant,city:s.ids.city,tenant:s.ids.tenant}[revoke];
    await db.admin.query(`UPDATE rounds.${table} SET archived_at=now() WHERE id=$1`,[id]);await code(read(s),'NOT_AUTHORIZED');
  });
  await t.test('display names never infer contacts; ambiguous, archived and overlong labels remain null',async()=>{
    const s=await setup();await contact(s,'Buyer','buyer');await contact(s,'Alternate','alternate');
    assert.equal((await data(s)).deliveries[0].recipient_name,null);
    const one=await contact(s,'😀'.repeat(200));assert.equal((await data(s)).deliveries[0].recipient_name,'😀'.repeat(200));
    const two=await contact(s,'Second');assert.equal((await data(s)).deliveries[0].recipient_name,null);
    await db.admin.query('UPDATE rounds.delivery_contacts SET archived_at=now() WHERE id=$1',[two]);
    for(const value of [' ','😀'.repeat(201)]){await db.admin.query('UPDATE rounds.delivery_contacts SET display_name=$2 WHERE id=$1',[one,value]);assert.equal((await data(s)).deliveries[0].recipient_name,null);}
    await db.admin.query('UPDATE rounds.deliveries SET address_text=$2 WHERE id=$1',[s.ids.delivery,'x'.repeat(2001)]);
    await db.admin.query('UPDATE rounds.sites SET archived_at=now() WHERE id=$1',[s.ids.site]);
    const d=(await data(s)).deliveries[0];assert.equal(d.address_text,null);assert.equal(d.pickup_site.name,null);
  });
  await t.test('stored point is independent from scoped entrance revision; archived/foreign city linkage is not exposed',async()=>{
    const s=await setup(),entrance=randomUUID(),revision=randomUUID();
    await db.admin.query(`INSERT INTO rounds.entrances(id,tenant_id,city_id,label) VALUES($1,$2,$3,'Test entrance')`,[entrance,s.ids.tenant,s.ids.city]);
    await db.admin.query(`INSERT INTO rounds.entrance_revisions(id,tenant_id,entrance_id,revision,point,vehicle_access,provenance,confirmed_by,confirmed_at,access_notes)
      VALUES($1,$2,$3,1,ST_GeogFromText('SRID=4326;POINT(100.6 13.8)'),'{}','{}',$4,now(),'PRIVATE-ENTRANCE')`,[revision,s.ids.tenant,entrance,s.ids.actor]);
    await db.admin.query(`UPDATE rounds.deliveries SET entrance_revision_id=$2,destination=ST_GeogFromText('SRID=4326;POINT(0 0)'),destination_version=2 WHERE id=$1`,[s.ids.delivery,revision]);
    let d=(await data(s)).deliveries[0];assert.equal(d.entrance_revision_id,revision);assert.equal(d.destination_version,2);
    assert.deepEqual(d.destination,{latitude:0,longitude:0,source:'delivery_destination'});assert(!JSON.stringify(d).includes('PRIVATE'));
    await db.admin.query('UPDATE rounds.entrances SET city_id=$2 WHERE id=$1',[entrance,s.ids.otherCity]);assert.equal((await data(s)).deliveries[0].entrance_revision_id,null);
    await db.admin.query('UPDATE rounds.entrances SET city_id=$2,archived_at=now() WHERE id=$1',[entrance,s.ids.city]);assert.equal((await data(s)).deliveries[0].entrance_revision_id,null);
    await db.admin.query('UPDATE rounds.deliveries SET destination=null WHERE id=$1',[s.ids.delivery]);d=(await data(s)).deliveries[0];assert.equal(d.destination,null);
  });
  await t.test('completed/cancelled/archived or obsolete-manifest planning is not an active reference',async()=>{
    const s=await setup();
    for(const state of ['completed','cancelled']){await db.admin.query('UPDATE rounds.rounds SET state=$2 WHERE id=$1',[s.ids.round,state]);assert.equal((await data(s)).deliveries[0].planning,null);}
    await db.admin.query(`UPDATE rounds.rounds SET state='active' WHERE id=$1`,[s.ids.round]);assert.equal((await data(s)).deliveries[0].planning.round_state,'active');
    await db.admin.query(`UPDATE rounds.stops SET state='cancelled' WHERE id=$1`,[s.ids.dropoff]);assert.equal((await data(s)).deliveries[0].planning,null);
    await db.admin.query(`UPDATE rounds.stops SET state='released' WHERE id=$1`,[s.ids.dropoff]);
    await db.admin.query('UPDATE rounds.deliveries SET current_manifest_id=null WHERE id=$1',[s.ids.delivery]);assert.equal((await data(s)).deliveries[0].planning,null);
  });
  await t.test('database rejects a second active dropoff and retains the original planning reference',async()=>{
    const s=await setup();
    await assert.rejects(db.admin.query(`INSERT INTO rounds.stops(tenant_id,round_id,delivery_id,kind,sequence,destination_version,state,service_seconds,fulfillment_unit_id)
      VALUES($1,$2,$3,'dropoff',2,1,'released',60,$4)`,[s.ids.tenant,s.ids.round,s.ids.delivery,s.ids.unit]),{code:'23505',constraint:'one_active_dropoff'});
    assert.equal((await data(s)).deliveries[0].planning.stop_id,s.ids.dropoff);
  });
  await t.test('invalid source versions and timezone fail closed; historical outcome is not rewritten',async()=>{
    const s=await setup();await db.admin.query(`UPDATE rounds.deliveries SET outcome='partially_delivered' WHERE id=$1`,[s.ids.delivery]);
    assert.equal((await data(s)).deliveries[0].outcome,'partially_delivered');
    await db.admin.query(`UPDATE rounds.deliveries SET version=9007199254740992 WHERE id=$1`,[s.ids.delivery]);await code(read(s),'SOURCE_STALE');
    await db.admin.query(`UPDATE rounds.deliveries SET version=1,timezone='Not/AZone' WHERE id=$1`,[s.ids.delivery]);await code(read(s),'SOURCE_STALE');
  });
  await t.test('bounded rows and UTF-8 payload fail explicitly, never silently truncate',async()=>{
    const s=await setup();await clone(s,199);assert.equal((await data(s)).delivery_count,200);
    const [extra]=await clone(s);await code(read(s),'FEATURE_NOT_ENABLED');
    await db.admin.query('UPDATE rounds.deliveries SET archived_at=now() WHERE id=$1',[extra]);
    await db.admin.query('UPDATE rounds.deliveries SET address_text=$2 WHERE tenant_id=$1',[s.ids.tenant,'😀'.repeat(2000)]);await code(read(s),'FEATURE_NOT_ENABLED');
  });
  await t.test('strict filters, methods and same-origin bearer security',async()=>{
    const s=await setup();
    for(const extra of ['&display=labels','&limit=10','&cursor=x','&entity_id='+s.ids.delivery,'&view=delivery_board','&service_date='+s.date,'&actor_id='+s.actor])await code(read(s,{},extra),'VALIDATION_FAILED');
    for(const service_date of ['2026-02-30','today','2026-1-01'])await code(read(s,{service_date}),'VALIDATION_FAILED');
    await code(read(s,{view:'full'}),'FEATURE_NOT_ENABLED');await code(read(s,{city_id:'wrong'}),'VALIDATION_FAILED');
    await code(read(s,{},'',{origin:'https://foreign.invalid'}),'NOT_AUTHORIZED');await code(read(s,{},'',{authorization:''}),'UNAUTHENTICATED');
    const invalidMethod=await read(s,{},'',{},'POST');assert.equal(invalidMethod.status,405);assert.equal(invalidMethod.headers.get('cache-control'),'no-store');
  });
  await t.test('actual Dispatch read adapter→local HTTP→restricted SQL; revocation clears client data',async()=>{
    const s=await setup(),before=await snapshot(s),boundary=createV23NodeBoundary({handler:http,origin:'http://localhost:3000'});
    const server=createServer((req,res)=>{void boundary(req,res).then(handled=>{if(!handled)res.writeHead(404).end();});});
    await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));
    const address=server.address();assert(address&&typeof address!=='string');
    const client=new OperationsDeliveryBoard({baseUrl:`http://127.0.0.1:${address.port}`,scope:{principalId:s.actor,tenantId:s.ids.tenant!,cityId:s.ids.city!,serviceDate:s.date,sessionEpoch:1},session:()=>({principalId:s.actor,sessionEpoch:1,bearer:s.token}),includeNow:true});
    try{
      await client.refresh();assert.equal(client.state.phase,'ready');assert.equal(client.state.snapshot!.data.deliveries[0]!.id,s.ids.delivery);
      assert.equal(client.state.snapshot!.data.now!.entries[0]!.bucket,'ready');
      const dateReader=client.forServiceDate('2001-01-01');await dateReader.refresh();
      assert.equal(dateReader.state.phase,'ready');assert.deepEqual(dateReader.state.snapshot!.data.deliveries,[]);
      assert.equal(client.state.snapshot!.data.deliveries[0]!.id,s.ids.delivery);
      const back=client.forServiceDate(s.date);await back.refresh();
      assert.equal(back.state.snapshot!.data.deliveries[0]!.id,s.ids.delivery);
      assert.deepEqual(await snapshot(s),before);
      await db.admin.query(`UPDATE rounds.city_grants SET capabilities='{}' WHERE id=$1`,[s.grant]);
      await back.refresh();for(const reader of [client,dateReader,back]){assert.equal(reader.state.phase,'closed');assert.equal(reader.state.snapshot,null);}
    }finally{client.dispose();await new Promise<void>((resolve,reject)=>server.close(e=>e?reject(e):resolve()));}
  });
  await t.test('repeatable snapshot keeps context and delivery consistent; pool role/scope does not leak',async()=>{
    const s=await setup(),client=await db.pool.connect();
    try{
      await beginRestrictedTransaction(client,s.auth,true);await authorizeDeliveryBoard(client,s.auth);
      await db.admin.query('BEGIN');await db.admin.query(`UPDATE rounds.cities SET name='Changed city',version=2 WHERE id=$1`,[s.ids.city]);
      await db.admin.query(`UPDATE rounds.deliveries SET human_reference='CHANGED',version=2 WHERE id=$1`,[s.ids.delivery]);await db.admin.query('COMMIT');
      const old=await projectDeliveryBoard(client,s.auth,s.date);assert.equal(old.data.city.name,'Test city');assert.equal(old.data.deliveries[0]!.reference,'TEST-ONLY');
      await client.query('COMMIT');const fresh=await data(s);assert.equal(fresh.city.name,'Changed city');assert.equal(fresh.deliveries[0].reference,'CHANGED');
      const cleared=(await client.query(`SELECT current_user AS role,nullif(current_setting('rounds.tenant_id',true),'') AS tenant`)).rows[0];
      assert.notEqual(cleared.role,'rounds_api');assert.equal(cleared.tenant,null);
    }finally{await client.query('ROLLBACK');client.release();}
  });
});
