import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {test} from 'node:test';
import {createServer} from 'node:http';
import {startPostgisFixture} from './postgis-fixture.js';
import {seedWholeOrder} from './whole-order-fixture.js';
import {createDriverExecutionHttp,driverRoundPath} from '../../src/v23/driver-execution-query.js';
import {createDeviceRegistrationHttp} from '../../src/v23/device-registration-http.js';
import {createPickupHttp,pickupPath} from '../../src/v23/pickup-http.js';
import {reportIssuePath} from '../../src/v23/report-local-pickup-issue.js';
import {createV23NodeBoundary} from '../../src/v23/node-boundary.js';
import {deviceSessions} from '../../src/v23/device-session.js';
import {CommandRejection} from '../../src/v23/transaction-runner.js';
import type {Wire_DriverRoundExecutionQueryResult,Wire_DriverRoundPickupQueryResult,Wire_ConfirmPickupRequest} from '../../../../packages/contracts/src/v23/pickup-wire.js';

const proof={kind:'proof',recipient_required:['photo'],alternate_required:['photo','receiver'],unattended_required:['photo','note'],unattended_allowed:false,gps_override_allowed:false};
test('Driver execution view uses authenticated registered device and actual scoped rows',{timeout:120000},async t=>{
  const db=await startPostgisFixture();t.after(()=>db.close());
  const subjects=new Map<string,string>(),devices=deviceSessions({id:'query-test',secret:randomBytes(32)});
  const now=()=>Math.floor(Date.now()/1000);
  const options={pool:db.pool,devices,now,origin:'http://localhost:3000',verifyBearer:async(token:string)=>{
    const subject=subjects.get(token);if(!subject)throw new CommandRejection('UNAUTHENTICATED');return subject;
  }};
  const query=createDriverExecutionHttp(options),registration=createDeviceRegistrationHttp(options),pickup=createPickupHttp(options);
  async function setup(policy:unknown=proof){
    const ids=await seedWholeOrder(db.admin,policy),bearer=randomUUID(),subject=randomUUID();subjects.set(bearer,subject);
    await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1',[ids.actor,subject]);
    await db.admin.query("INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)",[ids.tenant,ids.delivery,ids.round,ids.unit]);
    const enrollment=await registration(new Request('http://rounds.internal/v1/auth/driver-device/session',{method:'POST',headers:{authorization:`Bearer ${bearer}`,'content-type':'application/json'},body:JSON.stringify({installation_secret:randomBytes(32).toString('hex'),platform:'android'})}));
    assert.equal(enrollment.status,200,JSON.stringify(await enrollment.clone().json()));const device=await enrollment.json();
    const headers={authorization:`Bearer ${bearer}`,'x-rounds-device-session':device.device_session};
    const url=`http://rounds.internal${driverRoundPath}?entity_id=${ids.round}&tenant_id=${ids.tenant}&city_id=${ids.city}&view=execution`;
    return{ids,headers,url,device,request:()=>new Request(url,{headers})};
  }
  async function result(s:Awaited<ReturnType<typeof setup>>){const r=await query(s.request());assert.equal(r.status,200,JSON.stringify(await r.clone().json()));assert.equal(r.headers.get('cache-control'),'no-store');return await r.json() as Wire_DriverRoundExecutionQueryResult;}
  const code=async(r:Response,status:number,expected:string)=>{assert.equal(r.status,status,JSON.stringify(await r.clone().json()));assert.equal((await r.json()).code,expected);};
  async function contact(s:Awaited<ReturnType<typeof setup>>,name='Johannes recipient') {
    await db.admin.query(`INSERT INTO rounds.delivery_contacts(tenant_id,delivery_id,role,display_name,contact_secret_reference,masked_contact,notification_permissions)
      VALUES($1,$2,'recipient',$3,'private-contact-secret','private-masked-contact','{}')`,[s.ids.tenant,s.ids.delivery,name]);
  }
  async function parcel(s:Awaited<ReturnType<typeof setup>>,key:string,quantity:number) {
    const id=randomUUID();
    await db.admin.query('INSERT INTO rounds.packages(id,tenant_id,manifest_id,package_key,label) VALUES($1,$2,$3,$4,$5)',[id,s.ids.tenant,s.ids.manifest,key,'Parcel '+key]);
    await db.admin.query('INSERT INTO rounds.package_contents(tenant_id,package_id,line_id,quantity) VALUES($1,$2,$3,$4)',[s.ids.tenant,id,s.ids.line,quantity]);
    return id;
  }
  const displayRequest=(s:Awaited<ReturnType<typeof setup>>)=>new Request(s.url.replace('view=execution','view=pickup'),{headers:s.headers});
  await t.test('query-produced delivery version drives actual ReportIssue without guessed roots or arrival',async()=>{
    const s=await setup();
    await db.admin.query("UPDATE rounds.stops SET state='released' WHERE id=$1",[s.ids.pickup]);
    await db.admin.query('UPDATE rounds.deliveries SET version=7 WHERE id=$1',[s.ids.delivery]);
    const snapshot=await result(s),c=snapshot.data.context;
    assert.deepEqual(c.expected_versions.filter(v=>v.aggregate_type==='deliveries'),[{aggregate_type:'deliveries',id:s.ids.delivery,version:7}]);
    const request={command_id:randomUUID(),context:{tenant_id:s.ids.tenant,city_id:s.ids.city},occurred_at:new Date().toISOString(),
      expected_versions:c.expected_versions.filter(v=>v.aggregate_type==='rounds'||v.aggregate_type==='deliveries'),
      execution_fence:{assignment_id:c.assignment_id,assignment_version:c.assignment_version,observation_id:randomUUID()},
      payload:{round_id:c.round_id,delivery_id:snapshot.data.orders[0]!.delivery_id,issue_type:'package',reason_code:'missing',affected_lines:[],asset_ids:[]}};
    const response=await pickup(new Request('http://rounds.internal'+reportIssuePath,{method:'POST',headers:{...s.headers,'content-type':'application/json'},body:JSON.stringify(request)}));
    assert.equal(response.status,200,JSON.stringify(await response.clone().json()));
    const receipt=await response.json();assert.equal(receipt.state,'committed');
    assert.ok(receipt.current_versions.some((v:{aggregate_type:string;version:number})=>v.aggregate_type==='deliveries'&&v.version===8));
    const after=await result(s);assert.equal(after.data.context.accepted_scope_hash,c.accepted_scope_hash);
    assert.equal(after.data.context.expected_versions.find(v=>v.aggregate_type==='deliveries')!.version,8);
    assert.deepEqual((await db.admin.query('SELECT state,actual_arrival_at FROM rounds.stops WHERE id=$1',[s.ids.pickup])).rows,[{state:'released',actual_arrival_at:null}]);
    assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.custody_events WHERE tenant_id=$1',[s.ids.tenant])).rows[0].n,0);
  });
  async function display(s:Awaited<ReturnType<typeof setup>>) {
    const r=await query(displayRequest(s));assert.equal(r.status,200,JSON.stringify(await r.clone().json()));
    assert.equal(r.headers.get('cache-control'),'no-store');
    return await r.json() as Wire_DriverRoundPickupQueryResult;
  }
  await t.test('pickup display uses actual names, manifest lines and TWO identified parcels for FIVE items',async()=>{
    const s=await setup();await contact(s);const b=await parcel(s,'B',3),a=await parcel(s,'A',2);
    const old=await result(s),r=await display(s),d=r.data,o=d.orders[0]!;
    assert.equal(d.merchant,'Isolated test tenant');assert.equal(d.pickup_site_name,'Synthetic pickup');
    assert.equal(o.delivery_id,s.ids.delivery);assert.equal(o.manifest_id,s.ids.manifest);
    assert.equal(o.recipient_name,'Johannes recipient');assert.equal(o.reference,'TEST-ONLY');assert.equal(o.stop_sequence,1);
    assert.deepEqual(o.lines,[{line_id:s.ids.line,label:'Synthetic items',quantity:5,unit:'item',handling_keys:[]}]);
    assert.deepEqual(o.packages.map(p=>p.package_id),[a,b]);
    assert.deepEqual(o.packages.map(p=>p.contents),[[{line_id:s.ids.line,quantity:2}],[{line_id:s.ids.line,quantity:3}]]);
    assert.deepEqual(d.execution.orders,old.data.orders);assert.equal(d.execution.context.accepted_scope_hash,old.data.context.accepted_scope_hash);
    const encoded=JSON.stringify(r);
    for(const secret of ['private-contact-secret','private-masked-contact','Synthetic destination',s.device.device_session,s.headers.authorization,'contact_secret_reference','private_access_notes'])assert.ok(!encoded.includes(secret));
    assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.command_receipts WHERE tenant_id=$1',[s.ids.tenant])).rows[0].n,0);
    await db.admin.query("UPDATE rounds.delivery_contacts SET display_name='Updated recipient' WHERE delivery_id=$1",[s.ids.delivery]);
    const fresh=await display(s);assert.equal(fresh.data.orders[0]!.recipient_name,'Updated recipient');
    assert.equal(fresh.data.execution.context.accepted_scope_hash,d.execution.context.accepted_scope_hash);
    assert.deepEqual(Object.keys((await result(s)).data).sort(),Object.keys(old.data).sort());
  });
  await t.test('unpacked orders stay explicitly empty, never inferred from quantity',async()=>{
    const s=await setup();await contact(s);assert.deepEqual((await display(s)).data.orders[0]!.packages,[]);
  });
  await t.test('decimal package totals are exact without floating point summation',async()=>{
    const s=await setup();await contact(s);
    await db.admin.query('BEGIN');
    try {
      await db.admin.query('UPDATE rounds.manifest_lines SET quantity=0.3 WHERE id=$1',[s.ids.line]);
      await db.admin.query('UPDATE rounds.fulfillment_unit_lines SET allocated_quantity=0.3 WHERE unit_id=$1',[s.ids.unit]);
      await db.admin.query('COMMIT');
    }catch(e){await db.admin.query('ROLLBACK');throw e;}
    await parcel(s,'A',0.1);await parcel(s,'B',0.2);
    assert.equal((await display(s)).data.orders[0]!.lines[0]!.quantity,0.3);
  });
  for(const quantity of [4,6])await t.test(`incomplete or excess package contents (${quantity}/5) fail closed`,async()=>{
    const s=await setup();await contact(s);await parcel(s,'A',quantity);
    await code(await query(displayRequest(s)),422,'MANIFEST_MISMATCH');
    assert.equal((await result(s)).data.orders.length,1);
  });
  for(const problem of ['missing','ambiguous','blank','long'])await t.test(`invalid display ${problem} does not fabricate recipient`,async()=>{
    const s=await setup();
    if(problem!=='missing')await contact(s,problem==='blank'?'   ':problem==='long'?'X'.repeat(201):'Johannes');
    if(problem==='ambiguous')await contact(s,'Second recipient');
    await code(await query(displayRequest(s)),422,'SOURCE_STALE');
    assert.equal((await result(s)).data.orders.length,1);
  });
  await t.test('query supplies all pickup IDs and quantities; actual pickup succeeds without fixture IDs in command construction',async()=>{
    const s=await setup(),before=await result(s),d=before.data,c=d.context;
    assert.equal(c.principal_id,s.ids.actor);assert.equal(c.assignment_id,s.ids.assignment);
    assert.deepEqual(c.stop_units.find(x=>x.stop_id===d.pickup_stop_id)!.fulfillment_unit_ids,d.orders.map(o=>o.fulfillment_unit_id));
    assert.deepEqual(c.proof_policies[0]!.policy,proof);
    assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.command_receipts WHERE tenant_id=$1',[s.ids.tenant])).rows[0].n,0);
    const request:Wire_ConfirmPickupRequest={command_id:randomUUID(),context:{tenant_id:c.tenant_id,city_id:c.city_id},occurred_at:before.as_of,
      execution_fence:{assignment_id:c.assignment_id,assignment_version:c.assignment_version,observation_id:randomUUID()},
      expected_versions:c.expected_versions.filter(v=>['rounds','manifests','fulfillment_units'].includes(v.aggregate_type)||v.aggregate_type==='stops'&&v.id===d.pickup_stop_id),
      payload:{round_id:c.round_id,pickup_stop_id:d.pickup_stop_id,manifest_ids:d.orders.map(o=>o.manifest_id),fulfillment_unit_ids:d.orders.map(o=>o.fulfillment_unit_id),quantities:d.orders.flatMap(o=>o.quantities)}};
    const committed=await pickup(new Request('http://rounds.internal'+pickupPath,{method:'POST',headers:{...s.headers,'content-type':'application/json'},body:JSON.stringify(request)}));
    assert.equal(committed.status,200,JSON.stringify(await committed.clone().json()));assert.equal((await committed.json()).state,'committed');
    const after=await result(s);assert.equal(after.data.context.accepted_scope_hash,c.accepted_scope_hash);
    assert.notDeepEqual(after.data.context.expected_versions,c.expected_versions);
    for(const secret of [s.device.device_session,s.device.device_id,s.headers.authorization,'Synthetic destination','auth_subject'])assert.ok(!JSON.stringify(before).includes(secret));
  });
  await t.test('new work without proof configuration fails rather than inventing defaults',async()=>{
    const s=await setup({});
    await code(await query(s.request()),422,'POLICY_NOT_CONFIGURED');
  });
  for(const denial of ['device','epoch','identity','membership','city','tenant','assignment','driver','claim','foreign-city','foreign-round','foreign-tenant'])await t.test(`denies ${denial} without data`,async()=>{
    const s=await setup();let request=s.request();
    if(denial==='device')await db.admin.query('UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1',[s.device.device_id]);
    if(denial==='epoch')await db.admin.query('UPDATE rounds.driver_devices SET session_epoch=session_epoch+1 WHERE id=$1',[s.device.device_id]);
    if(denial==='identity')await db.admin.query('UPDATE rounds.principals SET disabled_at=now() WHERE id=$1',[s.ids.actor]);
    if(denial==='membership')await db.admin.query("UPDATE rounds.memberships SET status='revoked' WHERE id=$1",[s.ids.membership]);
    if(denial==='city')await db.admin.query("UPDATE rounds.city_grants SET capabilities='{}' WHERE id=$1",[s.ids.grant]);
    if(denial==='tenant')await db.admin.query("UPDATE rounds.tenants SET status='suspended' WHERE id=$1",[s.ids.tenant]);
    if(denial==='assignment')await db.admin.query("UPDATE rounds.assignments SET state='superseded' WHERE id=$1",[s.ids.assignment]);
    if(denial==='driver')await db.admin.query('UPDATE rounds.rounds SET driver_id=null WHERE id=$1',[s.ids.round]);
    if(denial==='claim')await db.admin.query('UPDATE rounds.active_delivery_claims SET archived_at=now() WHERE round_id=$1',[s.ids.round]);
    if(denial.startsWith('foreign')){const other=await setup(),url=new URL(s.url);url.searchParams.set(denial==='foreign-city'?'city_id':denial==='foreign-round'?'entity_id':'tenant_id',other.ids[denial==='foreign-city'?'city':denial==='foreign-round'?'round':'tenant']!);request=new Request(url,{headers:s.headers});}
    await code(await query(request),403,'NOT_AUTHORIZED');
    await code(await query(new Request(request.url.replace('view=execution','view=pickup'),{headers:request.headers})),403,'NOT_AUTHORIZED');
  });
  await t.test('malformed filters, missing capability and foreign Origin fail closed',async()=>{
    const s=await setup();
    for(const suffix of ['&entity_id='+s.ids.round,'&actor_id='+s.ids.actor])await code(await query(new Request(s.url+suffix,{headers:s.headers})),400,'VALIDATION_FAILED');
    await code(await query(new Request(s.url,{headers:{authorization:s.headers.authorization}})),401,'UNAUTHENTICATED');
    await code(await query(new Request(s.url,{headers:{...s.headers,origin:'https://untrusted.example'}})),403,'NOT_AUTHORIZED');
    await code(await query(new Request(s.url.replace('view=execution','view=full'),{headers:s.headers})),403,'FEATURE_NOT_ENABLED');
  });
  await t.test('actual Node route is default-off and execution GET is not sent to legacy',async()=>{
    const s=await setup();
    for(const enabled of [false,true]){
      const boundary=createV23NodeBoundary({origin:options.origin,...(enabled?{handler:query}:{})});
      const server=createServer((req,res)=>{void boundary(req,res).then(handled=>{if(!handled)res.writeHead(500).end('legacy fallback');});});
      await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));
      try {const a=server.address();assert.ok(a&&typeof a==='object');const u=new URL(s.url);u.host=`127.0.0.1:${a.port}`;
        assert.equal((await fetch(u,{headers:s.headers})).status,enabled?200:403);
        if(enabled)assert.equal((await fetch(u,{method:'OPTIONS',headers:{origin:options.origin,'access-control-request-method':'GET','access-control-request-headers':'authorization, x-rounds-device-session'}})).status,204);
      }finally{server.closeAllConnections();await new Promise<void>(resolve=>server.close(()=>resolve()));}
    }
  });
  await t.test('pooled connection retains no query identity or scope',async()=>{
    const s=await setup();await result(s);const c=await db.pool.connect();try{await c.query('BEGIN');await c.query('SET LOCAL ROLE rounds_api');assert.equal((await c.query('SELECT rounds.api_principal_id() id')).rows[0].id,null);assert.equal((await c.query('SELECT id FROM rounds.deliveries')).rowCount,0);await c.query('ROLLBACK');}finally{c.release();}
  });
  t.diagnostic(JSON.stringify(db.evidence));
});
