import assert from 'node:assert/strict';
import { randomBytes,randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { test } from 'node:test';
import type { Wire_ResolveIssueRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { createDeviceRegistrationHttp } from '../../src/v23/device-registration-http.js';
import { createDriverExecutionHttp,driverRoundPath } from '../../src/v23/driver-execution-query.js';
import { createPickupHttp,statusPath } from '../../src/v23/pickup-http.js';
import { reportIssuePath } from '../../src/v23/report-local-pickup-issue.js';
import { createOperationsIssueHttp,isOperationsIssueRequest } from '../../src/v23/operations-issue-http.js';
import { resolveIssuePath,resolvePickupIssueWork } from '../../src/v23/resolve-pickup-issue.js';
import { createV23NodeBoundary } from '../../src/v23/node-boundary.js';
import { deviceSessions } from '../../src/v23/device-session.js';
import { CommandRejection,CommandTransactionRunner } from '../../src/v23/transaction-runner.js';
import { beginRestrictedTransaction } from '../../src/v23/restricted-transaction.js';
import { operationsBoardPath } from '../../src/v23/operations-issue-query.js';
import { OperationsPickupIssues } from '../../../../apps/operations-web/src/v23/operations-pickup-issues.js';
import { OperationsDeliveryBoard } from '../../../../apps/operations-web/src/v23/operations-delivery-board.js';
import { pickupActionReports } from '../../../../apps/operations-web/src/v23/dispatch-pickup-action.js';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';

test('Operations wait/escalate: real report→restricted decision→Driver query, no goods/readiness shortcut',{timeout:120000},async t=>{
  const db=await startPostgisFixture();t.after(()=>db.close());
  // Identity-provider verification is a test double. Principal resolution,
  // capability checks, transactions, RLS, HTTP and Driver query use real code/PG.
  const subjects=new Map<string,string>();
  const options={pool:db.pool,devices:deviceSessions({id:'decision-test',secret:randomBytes(32)}),origin:'http://localhost:3000',verifyBearer:async(token:string)=>{
    const subject=subjects.get(token);if(!subject)throw new CommandRejection('UNAUTHENTICATED');return subject;
  }};
  const enroll=createDeviceRegistrationHttp(options),driver=createPickupHttp(options),get=createDriverExecutionHttp(options),ops=createOperationsIssueHttp(options);
  const dispatch=(r:Request)=>isOperationsIssueRequest(r)?ops(r):new URL(r.url).pathname===driverRoundPath?get(r):driver(r);
  async function setup(wait=false){
    const ids=await seedWholeOrder(db.admin),driverToken=randomUUID(),subject=randomUUID();subjects.set(driverToken,subject);
    await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1',[ids.actor,subject]);
    await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`,[ids.tenant,ids.delivery,ids.round,ids.unit]);
    const registration=await enroll(new Request('http://rounds.internal/v1/auth/driver-device/session',{method:'POST',headers:{authorization:`Bearer ${driverToken}`,'content-type':'application/json'},body:JSON.stringify({installation_secret:randomBytes(32).toString('hex'),platform:'android'})}));
    assert.equal(registration.status,200);const device=await registration.json();
    const driverHeaders={authorization:`Bearer ${driverToken}`,'x-rounds-device-session':device.device_session,'content-type':'application/json'};
    const reportCommand=randomUUID();
    const report=await driver(new Request('http://rounds.internal'+reportIssuePath,{method:'POST',headers:driverHeaders,body:JSON.stringify({command_id:reportCommand,context:{tenant_id:ids.tenant,city_id:ids.city},occurred_at:'2026-09-10T00:00:00Z',
      execution_fence:{assignment_id:ids.assignment,assignment_version:1,observation_id:randomUUID()},expected_versions:[{aggregate_type:'rounds',id:ids.round,version:1},...(!wait?[{aggregate_type:'deliveries',id:ids.delivery,version:1}]:[])],
      payload:{round_id:ids.round,...(!wait?{delivery_id:ids.delivery}:{}),issue_type:wait?'pickup_wait':'package',reason_code:wait?'awaiting_goods':'missing',affected_lines:[],asset_ids:[]}})}));
    assert.equal(report.status,200,JSON.stringify(await report.clone().json()));const issue=(await report.json()).data.resource.id;
    const actor=randomUUID(),membership=randomUUID(),grant=randomUUID(),token=randomUUID(),authSubject=randomUUID();subjects.set(token,authSubject);
    await db.admin.query(`INSERT INTO rounds.principals(id,auth_subject,display_name) VALUES($1,$2,'Johannes Operations test')`,[actor,authSubject]);
    await db.admin.query(`INSERT INTO rounds.memberships(id,tenant_id,principal_id,role_code,status) VALUES($1,$2,$3,'dispatcher','active')`,[membership,ids.tenant,actor]);
    await db.admin.query(`INSERT INTO rounds.city_grants(id,tenant_id,membership_id,city_id,capabilities) VALUES($1,$2,$3,$4,ARRAY['issues.decide'])`,[grant,ids.tenant,membership,ids.city]);
    const headers={authorization:`Bearer ${token}`,'content-type':'application/json',origin:options.origin};
    const r:Wire_ResolveIssueRequest={command_id:randomUUID(),context:{tenant_id:ids.tenant!,city_id:ids.city!},occurred_at:'2026-09-10T00:01:00Z',expected_versions:[{aggregate_type:'issues',id:issue,version:1}],payload:{issue_id:issue,decision:{action:'wait',instructions:'  Wait here.\nOperations is checking.  ',quantities:[]},reason:'  Internal reason: verify whole order.  '}};
    return {ids,issue,actor,membership,grant,headers,driverHeaders,r,reportCommand,auth:{principalId:actor,tenantId:ids.tenant!,cityId:ids.city!}};
  }
  type S=Awaited<ReturnType<typeof setup>>;
  const post=(s:S,r:unknown=s.r)=>dispatch(new Request('http://rounds.internal'+resolveIssuePath,{method:'POST',headers:s.headers,body:JSON.stringify(r)}));
  const status=(s:S,id=s.r.command_id)=>dispatch(new Request(`http://rounds.internal${statusPath}?entity_id=${id}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}`,{headers:s.headers}));
  const read=(s:S)=>get(new Request(`http://rounds.internal${driverRoundPath}?entity_id=${s.ids.round}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}&view=pickup_issue&issue_id=${s.issue}`,{headers:s.driverHeaders}));
  const board=async(s:S,extra='')=>{
    const date=(await db.admin.query(`SELECT service_date::text AS date FROM rounds.rounds WHERE id=$1`,[s.ids.round])).rows[0].date;
    return dispatch(new Request(`http://rounds.internal${operationsBoardPath}?tenant_id=${s.ids.tenant}&city_id=${s.ids.city}&service_date=${date}&view=pickup_issues${extra}`,{headers:s.headers}));
  };
  const snapshot=async(s:S)=>(await db.admin.query(`SELECT
    (SELECT to_jsonb(d) FROM rounds.deliveries d WHERE id=$2) delivery,
    (SELECT to_jsonb(r) FROM rounds.rounds r WHERE id=$3) round,
    (SELECT count(*) FROM rounds.custody_events WHERE tenant_id=$1) custody,
    (SELECT count(*) FROM rounds.trip_receipts WHERE tenant_id=$1) receipts,
    (SELECT count(*) FROM rounds.delivery_attempts WHERE tenant_id=$1) attempts,
    (SELECT count(*) FROM rounds.issue_decisions WHERE tenant_id=$1) decisions,
    (SELECT count(*) FROM rounds.domain_events WHERE tenant_id=$1) events,
    (SELECT count(*) FROM rounds.outbox_events WHERE tenant_id=$1) outbox`,[s.ids.tenant,s.ids.delivery,s.ids.round])).rows[0];
  async function committed(s:S){const r=await post(s);assert.equal(r.status,200,JSON.stringify(await r.clone().json()));return r.json();}
  async function denied(s:S,code:string,r:unknown=s.r){const before=await snapshot(s),response=await post(s,r);assert.equal((await response.json()).code,code);assert.deepEqual(await snapshot(s),before);}

  await t.test('Operations discovers actual reports and constructs reply only from scoped query output',async()=>{
    const s=await setup(),before=await snapshot(s),response=await board(s);
    assert.equal(response.status,200,JSON.stringify(await response.clone().json()));assert.equal(response.headers.get('cache-control'),'no-store');
    const data=(await response.json()).data;assert.equal(data.principal_id,s.actor);assert.equal(data.issues.length,1);
    const item=data.issues[0];assert.equal(item.issue_id,s.issue);assert.equal(item.delivery_id,s.ids.delivery);
    assert.deepEqual(item.allowed_actions,['wait','escalate']);assert.equal(item.blocked_reason,null);assert.equal(item.report.reason_code,'missing');
    assert.deepEqual(await snapshot(s),before);
    s.r.payload.issue_id=item.issue_id;s.r.expected_versions=[{aggregate_type:'issues',id:item.issue_id,version:item.issue_version}];
    await committed(s);
    const updated=(await (await board(s)).json()).data.issues[0];assert.equal(updated.issue_version,2);
    assert.deepEqual(updated.decisions,(await (await read(s)).json()).data.decisions);
    assert(!JSON.stringify(updated).includes('Internal reason'));assert(!JSON.stringify(updated).includes(s.ids.actor!));
  });
  await t.test('Round-only pickup wait is discoverable without a fabricated delivery',async()=>{
    const s=await setup(true),item=(await (await board(s)).json()).data.issues[0];
    assert.equal(item.delivery_id,null);assert.equal(item.report.issue_type,'pickup_wait');assert.deepEqual(item.allowed_actions,['wait','escalate']);
  });
  for(const action of ['wait','escalate'] as const)await t.test(`Dispatch Action→original report→${action}→Driver: real HTTP/SQL, uncertain reply recovered once`,async()=>{
    const s=await setup();
    await db.admin.query(`UPDATE rounds.city_grants SET capabilities=ARRAY['issues.decide','board.read'] WHERE id=$1`,[s.grant]);
    const date=(await db.admin.query(`SELECT (now() AT TIME ZONE 'Asia/Bangkok')::date::text AS day`)).rows[0].day;
    await db.admin.query(`UPDATE rounds.deliveries SET service_date=$2 WHERE id=$1`,[s.ids.delivery,date]);
    await db.admin.query(`UPDATE rounds.rounds SET service_date=$2 WHERE id=$1`,[s.ids.round,date]);
    const boundary=createV23NodeBoundary({handler:dispatch,origin:options.origin});
    const server=createServer((req,res)=>{void boundary(req,res).then(handled=>{if(!handled)res.writeHead(404).end();});});
    await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));const address=server.address();assert(address&&typeof address!=='string');
    const scope={principalId:s.actor,tenantId:s.ids.tenant!,cityId:s.ids.city!,serviceDate:date,sessionEpoch:1};
    const session=()=>({principalId:s.actor,sessionEpoch:1,bearer:s.headers.authorization.slice(7)});
    const baseUrl=`http://127.0.0.1:${address.port}`;
    let posts=0,statusReads=0;const postBodies:string[]=[];
    const reports=new OperationsPickupIssues({baseUrl,scope,session,includeDisplay:true,fetch:async(input,init)=>{
      if(String(input).includes('/CommandStatus'))statusReads++;
      const response=await fetch(input,init);
      if(init?.method==='POST'){
        posts++;postBodies.push(String(init.body));assert.equal(response.status,200);
        // The actual transaction committed. Only its network result is lost.
        return Response.json({code:'PROVIDER_UNAVAILABLE'},{status:503});
      }return response;
    }});
    const deliveries=new OperationsDeliveryBoard({baseUrl,scope,session,includeNow:true});
    try{
      await Promise.all([reports.refresh(),deliveries.refresh()]);assert.equal(reports.state.phase,'ready');assert.equal(deliveries.state.phase,'ready');
      assert.deepEqual(pickupActionReports(deliveries,reports).get(s.ids.delivery!),[s.issue]);
      const before=await snapshot(s),text='  Exact driver instruction.\nWait for Operations.  ';
      reports.saveDraft(s.issue,action,text,'Private Operations-only reason');await reports.submitDraft();
      assert(reports.state.pendingCommandId);assert.equal(posts,1);const pending=reports.state.pendingCommandId;
      await reports.retry();assert.equal(statusReads,1);assert.equal(posts,1);assert.equal(reports.state.pendingCommandId,null);assert.equal(reports.state.draft,null);
      assert.equal(JSON.parse(postBodies[0]!).command_id,pending);assert.equal(JSON.parse(postBodies[0]!).payload.issue_id,s.issue);
      await deliveries.refresh();assert.equal(deliveries.state.snapshot!.data.now!.entries[0]!.bucket,'action');
      const driverView=await (await read(s)).json(),decision=driverView.data.decisions[0];assert.equal(decision.action,action);assert.equal(decision.instructions,text);
      assert(!JSON.stringify(driverView).includes('Private Operations-only reason'));
      const after=await snapshot(s);for(const key of ['delivery','round','custody','receipts','attempts'])assert.deepEqual(after[key],before[key],key);
      assert.equal(Number(after.decisions)-Number(before.decisions),1);
      await db.admin.query(`UPDATE rounds.city_grants SET capabilities=ARRAY['board.read'] WHERE id=$1`,[s.grant]);await reports.refresh();
      assert.equal(reports.state.phase,'closed');assert.equal(pickupActionReports(deliveries,reports).size,0);assert.equal(deliveries.state.phase,'ready');
    }finally{reports.dispose();deliveries.dispose();await new Promise<void>((resolve,reject)=>server.close(e=>e?reject(e):resolve()));}
  });
  const labels = async(s:S) => {
    const response = await board(s,'&display=labels');
    assert.equal(response.status,200,JSON.stringify(await response.clone().json()));
    return (await response.json()).data.issues[0];
  };
  const recipient = async(s:S,name:string,role='recipient') => db.admin.query(`INSERT INTO rounds.delivery_contacts
    (tenant_id,delivery_id,role,display_name,notification_permissions,contact_secret_reference,masked_contact)
    VALUES($1,$2,$3,$4,'{}','DO-NOT-EXPOSE-contact-secret','DO-NOT-EXPOSE-mask') RETURNING id`,[s.ids.tenant,s.ids.delivery,role,name]);
  await t.test('opt-in labels are actual scoped fields; default wire and all domain records are unchanged',async()=>{
    const s=await setup();await recipient(s,'Siriporn <test>');
    await db.admin.query(`UPDATE rounds.deliveries SET private_access_notes='DO-NOT-EXPOSE-private' WHERE id=$1`,[s.ids.delivery]);
    const before=await snapshot(s),item=await labels(s);
    assert.deepEqual(item.display,{delivery_reference:'TEST-ONLY',recipient_name:'Siriporn <test>',destination_address:'Synthetic destination',pickup_site_name:'Synthetic pickup',reported_driver_name:'Johannes test'});
    const raw=JSON.stringify(item);assert(!raw.includes('DO-NOT-EXPOSE'));assert(!raw.includes(s.ids.actor!));assert(!raw.includes(s.ids.driver!));
    assert.equal((await (await board(s)).json()).data.issues[0].display,undefined);
    assert.deepEqual(await snapshot(s),before);assert.deepEqual(item.allowed_actions,['wait','escalate']);
  });
  await t.test('labels never infer recipient from buyer, alternate, missing or ambiguous contacts',async()=>{
    const s=await setup();await recipient(s,'Buyer must not appear','buyer');await recipient(s,'Alternate must not appear','alternate');
    assert.equal((await labels(s)).display.recipient_name,null);
    const first=await recipient(s,'One recipient');assert.equal((await labels(s)).display.recipient_name,'One recipient');
    const second=await recipient(s,'Other recipient');assert.equal((await labels(s)).display.recipient_name,null);
    await db.admin.query('UPDATE rounds.delivery_contacts SET archived_at=now() WHERE id=$1',[second.rows[0].id]);
    assert.equal((await labels(s)).display.recipient_name,'One recipient');
    await db.admin.query('UPDATE rounds.delivery_contacts SET archived_at=now() WHERE id=$1',[first.rows[0].id]);
    assert.equal((await labels(s)).display.recipient_name,null);
  });
  await t.test('invalid display text is unavailable without hiding a real actionable report',async()=>{
    const s=await setup();const contact=await recipient(s,'😀'.repeat(200));
    assert.equal((await labels(s)).display.recipient_name,'😀'.repeat(200));
    for(const text of [' ', '😀'.repeat(201)]){
      await db.admin.query('UPDATE rounds.delivery_contacts SET display_name=$2 WHERE id=$1',[contact.rows[0].id,text]);
      const item=await labels(s);assert.equal(item.display.recipient_name,null);assert.deepEqual(item.allowed_actions,['wait','escalate']);
    }
    await db.admin.query(`UPDATE rounds.deliveries SET address_text=$2 WHERE id=$1`,[s.ids.delivery,'x'.repeat(2001)]);
    assert.equal((await labels(s)).display.destination_address,null);
  });
  await t.test('Round-only wait never borrows a delivery recipient or address',async()=>{
    const s=await setup(true);await recipient(s,'Not the Round recipient');const item=await labels(s);
    assert.equal(item.delivery_id,null);assert.deepEqual(item.display,{delivery_reference:null,recipient_name:null,destination_address:null,pickup_site_name:'Synthetic pickup',reported_driver_name:'Johannes test'});
  });
  await t.test('changed original assignment suppresses labels instead of presenting revised work as its report',async()=>{
    const s=await setup();await recipient(s,'Original order recipient');assert.equal((await labels(s)).display.recipient_name,'Original order recipient');
    await db.admin.query('UPDATE rounds.assignments SET version=2 WHERE id=$1',[s.ids.assignment]);
    const item=await labels(s);assert(Object.values(item.display).every(x=>x===null));assert.equal(item.blocked_reason,'ORIGINAL_SCOPE_UNAVAILABLE');assert.deepEqual(item.allowed_actions,[]);
  });
  await t.test('labels do not leak a same-name tenant or unauthorized city; revoked rights deny the entire query',async()=>{
    const s=await setup(),foreign=await setup();await recipient(s,'Our recipient');await recipient(foreign,'FOREIGN secret recipient');
    assert(!JSON.stringify(await labels(s)).includes('FOREIGN'));
    // Invalid current source city cannot be used as a cross-city display join.
    await db.admin.query('UPDATE rounds.sites SET city_id=$2 WHERE id=$1',[s.ids.site,s.ids.otherCity]);
    assert.equal((await labels(s)).display.pickup_site_name,null);
    await db.admin.query(`UPDATE rounds.city_grants SET capabilities=ARRAY['board.read'] WHERE id=$1`,[s.grant]);
    assert.equal((await board(s,'&display=labels')).status,403);
  });
  await t.test('label edits do not change original command identity or reply version',async()=>{
    const s=await setup();const contact=await recipient(s,'Before');const item=await labels(s);
    await db.admin.query('UPDATE rounds.delivery_contacts SET display_name=$2 WHERE id=$1',[contact.rows[0].id,'After']);
    const changed=await labels(s);assert.equal(changed.display.recipient_name,'After');assert.equal(changed.issue_version,item.issue_version);
    const sent=await committed(s);assert.equal(sent.data.resource.id,item.issue_id);assert.equal(sent.command_id,s.r.command_id);
  });
  await t.test('display filter rejects invalid/duplicate values and is not accepted on command status',async()=>{
    const s=await setup();for(const extra of ['&display=', '&display=private', '&display=labels&display=labels'])assert.equal((await board(s,extra)).status,400);
    const response=await dispatch(new Request(`http://rounds.internal${statusPath}?entity_id=${s.r.command_id}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}&display=labels`,{headers:s.headers}));assert.equal(response.status,400);
  });
  await t.test('changed assignment remains labelled non-actionable; no new version authorizes its original report',async()=>{
    const s=await setup();await db.admin.query('UPDATE rounds.assignments SET version=2 WHERE id=$1',[s.ids.assignment]);
    const item=(await (await board(s)).json()).data.issues[0];assert.equal(item.assignment_version,1);
    assert.deepEqual(item.allowed_actions,[]);assert.equal(item.blocked_reason,'ORIGINAL_SCOPE_UNAVAILABLE');await denied(s,'NOT_AUTHORIZED');
  });
  await t.test('Operations issue read rejects revoked capability, disabled city, Driver token and foreign tenant',async()=>{
    for(const change of ['grant','city','driver','tenant']){
      const s=await setup();
      if(change==='grant')await db.admin.query(`UPDATE rounds.city_grants SET capabilities=ARRAY['board.read'] WHERE id=$1`,[s.grant]);
      if(change==='city')await db.admin.query('UPDATE rounds.cities SET enabled=false WHERE id=$1',[s.ids.city]);
      if(change==='driver')s.headers.authorization=s.driverHeaders.authorization;
      if(change==='tenant')s.headers=(await setup()).headers;
      assert.equal((await board(s)).status,403,change);
    }
  });
  await t.test('date scope empty is real, extra/duplicate params and invalid dates are rejected',async()=>{
    const s=await setup();for(const extra of ['&view=pickup_issues','&cursor=x','&entity_id='+s.issue,'&limit=50'])assert.equal((await board(s,extra)).status,400);
    const base=`http://rounds.internal${operationsBoardPath}?tenant_id=${s.ids.tenant}&city_id=${s.ids.city}&view=pickup_issues&service_date=`;
    assert.equal((await dispatch(new Request(base+'2026-02-30',{headers:s.headers}))).status,400);
    const empty=await dispatch(new Request(base+'2000-01-01',{headers:s.headers}));assert.equal(empty.status,200);assert.deepEqual((await empty.json()).data.issues,[]);
    s.ids.city=s.ids.otherCity!;assert.equal((await board(s)).status,403);
  });
  await t.test('inconsistent decisions fail the entire view instead of displaying empty/success',async()=>{
    const s=await setup();await db.admin.query(`UPDATE rounds.issues SET state='decided' WHERE id=$1`,[s.issue]);
    const response=await board(s);assert.equal((await response.json()).code,'SOURCE_STALE');
  });
  await t.test('stale view cannot overwrite a newer reply; fresh read supplies the actual supersession',async()=>{
    const s=await setup(),old=structuredClone(s.r);await board(s);await committed(s);
    old.command_id=randomUUID();await denied(s,'STALE_VERSION',old);
    const item=(await (await board(s)).json()).data.issues[0];s.r.command_id=randomUUID();s.r.expected_versions[0]!.version=item.issue_version;s.r.payload.decision.action='escalate';
    await committed(s);const current=(await (await board(s)).json()).data.issues[0];assert.equal(current.decisions.length,1);assert.equal(current.decisions[0].action,'escalate');
  });

  await t.test('actual Operations instruction preserves held goods, exact reason and authenticated actor',async()=>{
    const s=await setup(),before=await snapshot(s),result=await committed(s),after=await snapshot(s);
    assert.equal(result.data.state,'decided');assert.equal(result.data.resource.version,2);
    for(const k of ['delivery','round','custody','receipts','attempts'])assert.deepEqual(after[k],before[k]);
    for(const k of ['decisions','events','outbox'])assert.equal(Number(after[k]),Number(before[k])+1);
    const row=(await db.admin.query('SELECT * FROM rounds.issue_decisions WHERE issue_id=$1',[s.issue])).rows[0];
    assert.equal(row.decided_by,s.actor);assert.equal(row.reason,s.r.payload.reason);assert.deepEqual(row.instruction,s.r.payload.decision);assert.equal(row.supersedes_id,null);
    assert.equal(result.resources[0].id,row.id);
    const response=await read(s);assert.equal(response.status,200);const view=await response.json();
    assert.deepEqual(view.data.decisions,[{id:row.id,decided_at:row.decided_at.toISOString(),action:'wait',instructions:s.r.payload.decision.instructions}]);
    assert.equal(view.data.orders[0].readiness,'held');assert.equal(view.data.departure_gate,'blocked');
    assert(!JSON.stringify(view).includes('Internal reason'));assert(!JSON.stringify(result).includes('Internal reason'));
    const event=(await db.admin.query(`SELECT payload FROM rounds.domain_events WHERE command_id=$1`,[s.r.command_id])).rows[0];assert(!JSON.stringify(event).includes('Wait here'));
    const again=await post(s);assert.equal(again.headers.get('x-rounds-replayed'),'true');assert.equal(again.headers.get('cache-control'),'no-store');assert.deepEqual(await again.json(),result);
    assert.deepEqual((await (await status(s)).json()).data.result,result);assert.deepEqual(await snapshot(s),after);
  });
  await t.test('Round waiting decision has no selected order, quantity or readiness effect',async()=>{
    const s=await setup(true),before=await snapshot(s);s.r.payload.decision.action='escalate';await committed(s);
    const after=await snapshot(s);assert.deepEqual(after.delivery,before.delivery);assert.deepEqual(after.round,before.round);
    const b=await (await read(s)).json();assert.deepEqual(b.data.orders,[]);assert.equal(b.data.decisions[0].action,'escalate');
  });
  await t.test('same-command race commits once; changed bytes conflict',async()=>{
    const s=await setup(),results=await Promise.all([post(s),post(s)]);assert.deepEqual(results.map(r=>r.status),[200,200]);assert.deepEqual(await results[0]!.json(),await results[1]!.json());
    await denied(s,'IDEMPOTENCY_CONFLICT',{...s.r,payload:{...s.r.payload,reason:'Changed reason'}});
  });
  await t.test('different decisions on one version have exactly one winner',async()=>{
    const s=await setup(),other={...s.r,command_id:randomUUID()};const results=await Promise.all([post(s),post(s,other)]);
    assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);assert.equal((await snapshot(s)).decisions,'1');
  });
  await t.test('superseding instruction preserves predecessor; replay retains original decision',async()=>{
    const s=await setup(),first=await committed(s),old=structuredClone(s.r);s.r.command_id=randomUUID();s.r.expected_versions[0]!.version=2;s.r.payload.decision.action='escalate';s.r.payload.decision.instructions='Supervisor is checking.';
    const second=await committed(s);assert.equal(second.data.resource.version,3);
    const rows=(await db.admin.query('SELECT * FROM rounds.issue_decisions WHERE issue_id=$1',[s.issue])).rows;
    assert.equal(rows.find(r=>r.id===second.resources[0].id).supersedes_id,first.resources[0].id);
    assert.equal((await (await read(s)).json()).data.decisions[0].id,second.resources[0].id);
    assert.deepEqual(await (await post(s,old)).json(),first);
  });
  for(const action of ['ready','alternate_handoff','review_address','continue_other_stops','partial_pickup','return','transfer','reschedule','cancel'] as const){
    await t.test('unsupported '+action+' cannot move or release anything',async()=>{const s=await setup();s.r.payload.decision.action=action;await denied(s,'FEATURE_NOT_ENABLED');});
  }
  for(const [name,change] of [
    ['capability',async(s:S)=>db.admin.query(`UPDATE rounds.city_grants SET capabilities=ARRAY['board.read'] WHERE id=$1`,[s.grant])],
    ['membership',async(s:S)=>db.admin.query(`UPDATE rounds.memberships SET archived_at=now() WHERE id=$1`,[s.membership])],
    ['disabled identity',async(s:S)=>db.admin.query(`UPDATE rounds.principals SET disabled_at=now() WHERE id=$1`,[s.actor])],
    ['city',async(s:S)=>{s.r.context.city_id=s.ids.otherCity!;}],
    ['tenant',async(s:S)=>{s.r.context.tenant_id=randomUUID();}],
    ['assignment version',async(s:S)=>db.admin.query(`UPDATE rounds.assignments SET version=2 WHERE id=$1`,[s.ids.assignment])],
    ['withdrawal',async(s:S)=>db.admin.query(`UPDATE rounds.assignments SET state='withdrawn' WHERE id=$1`,[s.ids.assignment])],
    ['pickup completed',async(s:S)=>db.admin.query(`UPDATE rounds.stops SET state='completed' WHERE id=$1`,[s.ids.pickup])],
    ['resolved issue',async(s:S)=>db.admin.query(`UPDATE rounds.issues SET state='resolved' WHERE id=$1`,[s.issue])],
    ['archived driver relationship',async(s:S)=>db.admin.query(`UPDATE rounds.driver_relationships SET archived_at=now() WHERE tenant_id=$1 AND driver_id=$2`,[s.ids.tenant,s.ids.driver])],
  ] as const){await t.test('denies '+name,async()=>{const s=await setup();await change(s);await denied(s,'NOT_AUTHORIZED');});}
  await t.test('other actor/city/tenant cannot decide or read another actor receipt',async()=>{
    const s=await setup(),other=await setup();const result=await committed(s);s.headers=other.headers;await denied(s,'NOT_AUTHORIZED');assert.equal((await status(s)).status,403);
    other.r.payload.issue_id=s.issue;other.r.expected_versions[0]!.id=s.issue;await denied(other,'NOT_AUTHORIZED');assert(result.resources.length);
  });
  await t.test('receipt recovery survives job revision but not capability revocation',async()=>{
    const s=await setup(),result=await committed(s);await db.admin.query('UPDATE rounds.assignments SET version=2 WHERE id=$1',[s.ids.assignment]);
    assert.deepEqual(await (await post(s)).json(),result);assert.deepEqual((await (await status(s)).json()).data.result,result);
    await db.admin.query('UPDATE rounds.city_grants SET archived_at=now() WHERE id=$1',[s.grant]);await denied(s,'NOT_AUTHORIZED');assert.equal((await status(s)).status,403);
  });
  await t.test('driver device/role and forged principal headers are not Operations authority',async()=>{
    const s=await setup();s.headers={...s.headers,authorization:s.driverHeaders.authorization};await denied(s,'NOT_AUTHORIZED');
    const r=await ops(new Request('http://rounds.internal'+resolveIssuePath,{method:'POST',headers:{...s.headers,'x-principal-id':s.actor},body:JSON.stringify(s.r)}));assert.equal(r.status,403);
  });
  await t.test('no-device status routing cannot expose Driver receipts even with Operations capability',async()=>{
    const s=await setup();await db.admin.query(`UPDATE rounds.city_grants SET capabilities=ARRAY['driver.assigned_work','issues.decide'] WHERE id=$1`,[s.ids.grant]);
    s.headers.authorization=s.driverHeaders.authorization;const r=await status(s,s.reportCommand);assert.equal(r.status,403);
    assert(isOperationsIssueRequest(new Request('http://rounds.internal'+statusPath)));
    assert(!isOperationsIssueRequest(new Request('http://rounds.internal'+statusPath,{headers:s.driverHeaders})));
  });
  await t.test('malformed inputs and meaningless quantity/consent selectors never commit',async()=>{
    const s=await setup();for(const change of [
      (r:any)=>r.payload.reason=' ',(r:any)=>r.payload.decision.instructions=' ',(r:any)=>r.payload.decision.instructions='x'.repeat(4001),
      (r:any)=>r.payload.decision.quantities=[{line_id:s.ids.line,quantity:1}],(r:any)=>r.payload.decision.customer_agreement_reference='consent',
      (r:any)=>r.payload.decision.freelance_change_id=randomUUID(),(r:any)=>r.expected_versions.push(r.expected_versions[0]),
      (r:any)=>r.expected_versions[0].id=randomUUID(),(r:any)=>r.expected_versions[0].version=Number.MAX_SAFE_INTEGER+1,(r:any)=>r.principal_id=s.actor,
    ]){const r=structuredClone(s.r);r.command_id=randomUUID();change(r);await denied(s,'VALIDATION_FAILED',r);}
  });
  await t.test('corrupt decision chain is not overwritten',async()=>{
    const s=await setup();await db.admin.query(`UPDATE rounds.issues SET state='decided' WHERE id=$1`,[s.issue]);await denied(s,'SOURCE_STALE');
  });
  await t.test('Operations can reply before arrival without manufacturing an arrival',async()=>{
    const s=await setup(true);await db.admin.query(`UPDATE rounds.stops SET state='en_route' WHERE id=$1`,[s.ids.pickup]);await committed(s);
    const stop=(await db.admin.query('SELECT state,actual_arrival_at FROM rounds.stops WHERE id=$1',[s.ids.pickup])).rows[0];assert.equal(stop.state,'en_route');assert.equal(stop.actual_arrival_at,null);
  });
  await t.test('same-city Operations colleague cannot retrieve the submitter receipt',async()=>{
    const s=await setup(),other=await setup();await committed(s);
    const membership=randomUUID();await db.admin.query(`INSERT INTO rounds.memberships(id,tenant_id,principal_id,role_code,status) VALUES($1,$2,$3,'dispatcher','active')`,[membership,s.ids.tenant,other.actor]);
    await db.admin.query(`INSERT INTO rounds.city_grants(tenant_id,membership_id,city_id,capabilities) VALUES($1,$2,$3,ARRAY['issues.decide'])`,[s.ids.tenant,membership,s.ids.city]);
    s.headers=other.headers;assert.equal((await status(s)).status,404);
  });
  await t.test('new report policy is city-scoped SELECT only, never cross-actor INSERT or driver UPDATE',async()=>{
    const s=await setup();
    async function restricted(auth:S['auth'],run:(c:import('pg').PoolClient)=>Promise<void>){const c=await db.pool.connect();try{await beginRestrictedTransaction(c,auth);await run(c);}finally{await c.query('ROLLBACK');c.release();}}
    await restricted(s.auth,async c=>{assert.equal((await c.query('SELECT * FROM rounds.issue_report_observations WHERE issue_id=$1',[s.issue])).rowCount,1);
      assert.equal((await c.query(`UPDATE rounds.drivers SET network_eligibility='not_requested' WHERE id=$1 RETURNING id`,[s.ids.driver])).rowCount,0);});
    await restricted({...s.auth,cityId:s.ids.otherCity!},async c=>{assert.equal((await c.query('SELECT * FROM rounds.issue_report_observations WHERE issue_id=$1',[s.issue])).rowCount,0);});
    await restricted(s.auth,async c=>{await assert.rejects(c.query(`INSERT INTO rounds.issue_report_observations SELECT * FROM rounds.issue_report_observations WHERE issue_id=$1`,[s.issue]),/row-level security/);});
    await db.admin.query(`UPDATE rounds.city_grants SET capabilities=ARRAY['board.read'] WHERE id=$1`,[s.grant]);
    await restricted(s.auth,async c=>{assert.equal((await c.query('SELECT * FROM rounds.issue_report_observations WHERE issue_id=$1',[s.issue])).rowCount,0);});
  });
  await t.test('SQL/result failure rolls back decision, issue, event, outbox and receipt',async()=>{
    for(const failure of ['result','sql']){
      const s=await setup(),before=await snapshot(s),work=resolvePickupIssueWork(s.auth,s.r),execute=work.execute;
      let reached=false;
      if(failure==='result')work.validateResult=()=>{reached=true;throw new Error('injected result failure');};
      else work.execute=async(...args)=>{await execute(...args);reached=true;await args[0].query('SELECT definitely_missing_column');throw new Error('unreachable');};
      await assert.rejects(new CommandTransactionRunner(db.pool).run(work),/PROVIDER_UNAVAILABLE/);assert.deepEqual(await snapshot(s),before);
      assert(reached,'the injected failure must occur after domain writes, not at authorization');
      assert.equal((await db.admin.query('SELECT count(*) FROM rounds.command_receipts WHERE command_key=$1',[s.r.command_id])).rows[0].count,'0');
      assert.equal((await db.admin.query('SELECT version,state FROM rounds.issues WHERE id=$1',[s.issue])).rows[0].state,'open');
    }
  });
  await t.test('restricted role cannot update/delete original decision or inspect another tenant',async()=>{
    const s=await setup(),other=await setup();await committed(s);const c=await db.pool.connect();
    try{await beginRestrictedTransaction(c,s.auth);assert.equal((await c.query('SELECT * FROM rounds.issue_decisions WHERE tenant_id=$1',[other.ids.tenant])).rowCount,0);
      await assert.rejects(c.query('UPDATE rounds.issue_decisions SET reason=$1 WHERE issue_id=$2',['new',s.issue]));
    }finally{await c.query('ROLLBACK');c.release();}
    const deletion=await db.pool.connect();
    try{await beginRestrictedTransaction(deletion,s.auth);await assert.rejects(deletion.query('DELETE FROM rounds.issue_decisions WHERE issue_id=$1',[s.issue]));}
    finally{await deletion.query('ROLLBACK');deletion.release();}
  });
  await t.test('migration preserves existing decision bytes and null reason',async()=>{
    const s=await setup(),id=randomUUID();await db.admin.query(`INSERT INTO rounds.issue_decisions(id,tenant_id,issue_id,decision_kind,instruction,decided_by,decided_at) VALUES($1,$2,$3,'wait','{"action":"wait","instructions":"Legacy"}',$4,now())`,[id,s.ids.tenant,s.issue,s.actor]);
    const before=(await db.admin.query('SELECT * FROM rounds.issue_decisions WHERE id=$1',[id])).rows[0];
    await db.admin.query(await readFile(new URL('../../migrations/v23/0008-issue-decision-reason.sql',import.meta.url),'utf8'));
    assert.deepEqual((await db.admin.query('SELECT * FROM rounds.issue_decisions WHERE id=$1',[id])).rows[0],before);assert.equal(before.reason,null);
  });
  await t.test('actual Node route/CORS works; wrong origin/auth/query/method fail closed',async()=>{
    const s=await setup(),boundary=createV23NodeBoundary({origin:options.origin,handler:dispatch});
    const server=createServer((req,res)=>{void boundary(req,res).then(handled=>{if(!handled)res.writeHead(404).end();});});
    await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));
    try{const a=server.address();assert(a&&typeof a==='object');const base=`http://127.0.0.1:${a.port}`;
      const pre=await fetch(base+resolveIssuePath,{method:'OPTIONS',headers:{origin:options.origin,'access-control-request-method':'POST','access-control-request-headers':'authorization, content-type'}});assert.equal(pre.status,204);
      const queryPre=await fetch(base+operationsBoardPath,{method:'OPTIONS',headers:{origin:options.origin,'access-control-request-method':'GET','access-control-request-headers':'authorization'}});assert.equal(queryPre.status,204);
      const r=await fetch(base+resolveIssuePath,{method:'POST',headers:s.headers,body:JSON.stringify(s.r)});assert.equal(r.status,200,await r.clone().text());assert.equal(r.headers.get('access-control-allow-origin'),options.origin);
      for(const [path,method,headers,code] of [[resolveIssuePath,'GET',s.headers,405],[resolveIssuePath+'?bad=1','POST',s.headers,400],[resolveIssuePath,'POST',{...s.headers,origin:'https://foreign.invalid'},403],[resolveIssuePath,'POST',{...s.headers,authorization:'Bearer bad'},401]] as const){
        const response=await fetch(base+path,{method,headers,...(method==='POST'?{body:JSON.stringify(s.r)}:{})});assert.equal(response.status,code);
      }
    }finally{await new Promise<void>((resolve,reject)=>server.close(e=>e?reject(e):resolve()));}
  });
  for(const reload of [false,true]) await t.test(`actual Dispatch client → Node → restricted SQL → Driver reply, lost response${reload?' and controller reload':''}`,async()=>{
    const s=await setup(),boundary=createV23NodeBoundary({origin:options.origin,handler:dispatch});
    const server=createServer((req,res)=>{void boundary(req,res).then(handled=>{if(!handled)res.writeHead(404).end();});});
    await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));
    const date=(await db.admin.query(`SELECT service_date::text AS date FROM rounds.rounds WHERE id=$1`,[s.ids.round])).rows[0].date;
    let posts=0;
    try{
      const address=server.address();assert(address&&typeof address==='object');
      // Tab storage is a double; the client, HTTP bytes and SQL writes are real.
      const entries=new Map<string,string>(),loginId=randomUUID();
      const storage={getItem:(key:string)=>entries.get(key)??null,setItem:(key:string,value:string)=>{entries.set(key,value);},removeItem:(key:string)=>{entries.delete(key);}};
      const open=()=>new OperationsPickupIssues({baseUrl:`http://127.0.0.1:${address.port}`,
        scope:{principalId:s.actor,tenantId:s.ids.tenant!,cityId:s.ids.city!,serviceDate:date,sessionEpoch:1},
        session:()=>({principalId:s.actor,sessionEpoch:1,bearer:s.headers.authorization.slice(7)}),
        ...(reload?{recovery:{storage,loginId,currentLoginId:()=>loginId}}:{}),
        fetch:async(url,init)=>{const response=await fetch(url,init);if(init?.method==='POST'){posts++;assert.equal(response.status,200);await response.arrayBuffer();throw new Error('injected loss AFTER real server commit');}return response;}});
      let client=open();
      await client.refresh();assert.equal(client.state.phase,'ready',client.state.errorCode??'');
      const discovered=client.state.snapshot!.data.issues.find(i=>i.issue_id===s.issue)!;
      await client.send(discovered.issue_id,'wait','Stay at pickup. Johannes is checking.','Fixture internal reason');
      assert.equal(client.state.errorCode,'UNKNOWN_RESULT');
      if(reload){const id=client.state.pendingCommandId;client.dispose();client=open();assert.equal(client.state.draft,null);await client.refresh();assert.equal(client.state.pendingCommandId,id);assert.equal(posts,1);}
      await client.retry();
      assert.equal(posts,1);assert.equal(client.state.phase,'ready',client.state.errorCode??'');assert.equal(client.state.pendingCommandId,null);
      assert.equal(client.state.snapshot!.data.issues.find(i=>i.issue_id===s.issue)!.issue_version,2);
      const deviceReply=(await (await read(s)).json()).data.decisions[0];assert.equal(deviceReply.instructions,'Stay at pickup. Johannes is checking.');
      assert.equal((await snapshot(s)).decisions,'1');client.dispose();
    }finally{await new Promise<void>((resolve,reject)=>server.close(e=>e?reject(e):resolve()));}
  });
  await t.test('default-off Node boundary rejects the new command without invoking a handler',async()=>{
    const boundary=createV23NodeBoundary({origin:options.origin});
    const server=createServer((req,res)=>{void boundary(req,res).then(handled=>{if(!handled)res.writeHead(404).end();});});
    await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));
    try{const a=server.address();assert(a&&typeof a==='object');for(const path of [resolveIssuePath,operationsBoardPath]){const r:Response=await fetch(`http://127.0.0.1:${a.port}${path}`);assert.equal((await r.json()).code,'FEATURE_NOT_ENABLED');assert.equal(r.headers.get('cache-control'),'no-store');}}
    finally{await new Promise<void>((resolve,reject)=>server.close(e=>e?reject(e):resolve()));}
  });
});

test('0008 upgrades an old schema with existing decisions without rewriting history',{timeout:60000},async t=>{
  const id=randomUUID();let before:Record<string,unknown>;
  const db=await startPostgisFixture({beforeDecisionMigration:async admin=>{
    // Exact pre-0008 shape in this newly-created disposable fixture only.
    await admin.query('ALTER TABLE rounds.issue_decisions DROP COLUMN reason');
    const ids=await seedWholeOrder(admin),issue=randomUUID();
    await admin.query(`INSERT INTO rounds.issues(id,tenant_id,round_id,driver_id,issue_type,reason_code,state,reported_at,reported_by) VALUES($1,$2,$3,$4,'pickup_wait','awaiting_goods','decided',now(),$5)`,[issue,ids.tenant,ids.round,ids.driver,ids.actor]);
    await admin.query(`INSERT INTO rounds.issue_decisions(id,tenant_id,issue_id,decision_kind,instruction,decided_by,decided_at) VALUES($1,$2,$3,'wait','{"action":"wait","instructions":"Original legacy text"}',$4,now())`,[id,ids.tenant,issue,ids.actor]);
    before=(await admin.query('SELECT * FROM rounds.issue_decisions WHERE id=$1',[id])).rows[0];assert(!Object.hasOwn(before!,'reason'));
  }});t.after(()=>db.close());
  const after=(await db.admin.query('SELECT * FROM rounds.issue_decisions WHERE id=$1',[id])).rows[0];
  assert.deepEqual(after,{...before!,reason:null});
  await assert.rejects(db.admin.query('UPDATE rounds.issue_decisions SET reason=$1 WHERE id=$2',['fabricated backfill',id]),/IMMUTABLE_RECORD/);
  const policy=(await db.admin.query(`SELECT cmd,roles::text[] AS roles FROM pg_policies WHERE schemaname='rounds' AND tablename='issue_report_observations' AND policyname='operations_issue_report_read'`)).rows[0];assert.equal(policy.cmd,'SELECT');assert.deepEqual(policy.roles,['rounds_api']);
});
