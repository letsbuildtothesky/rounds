import assert from 'node:assert/strict';
import { randomBytes,randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { test } from 'node:test';
import { createPickupHttp,pickupPath,statusPath,commandBodyLimit } from '../../src/v23/pickup-http.js';
import { createV23NodeBoundary } from '../../src/v23/node-boundary.js';
import { deviceSessions } from '../../src/v23/device-session.js';
import { CommandRejection,CommandTransactionRunner } from '../../src/v23/transaction-runner.js';
import { localPickupWork } from '../../src/v23/confirm-local-pickup.js';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';
import { headerRejection } from './header-rejection-fixture.js';
import type { Wire_ConfirmPickupRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';

test('isolated authenticated pickup HTTP with real restricted PostgreSQL', {timeout:120000},async t=>{
  const db=await startPostgisFixture();t.after(()=>db.close());
  const devices=deviceSessions({id:'fixture-only',secret:randomBytes(32)}),subjects=new Map<string,string>();
  let now=1788861600,authCalls=0;
  // Only provider validation is a test double. Identity mapping, device/job RLS,
  // command execution, receipts and HTTP payloads are the actual implementation.
  const handler=createPickupHttp({pool:db.pool,devices,origin:'http://localhost:3000',now:()=>now,verifyBearer:async token=>{
    authCalls++;const subject=subjects.get(token);if(!subject)throw new CommandRejection('UNAUTHENTICATED');return subject;
  }});
  const setup=async()=>{
    const ids=await seedWholeOrder(db.admin),authSubject=randomUUID(),deviceId=randomUUID(),bearer=randomUUID();subjects.set(bearer,authSubject);
    await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1',[ids.actor,authSubject]);
    await db.admin.query("INSERT INTO rounds.driver_devices(id,driver_id,platform,device_key) VALUES($1,$2,'android',$3)",[deviceId,ids.driver,randomUUID()]);
    await db.admin.query("INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)",[ids.tenant,ids.delivery,ids.round,ids.unit]);
    const credential=devices.issue({principalId:ids.actor!,authSubject,deviceId,epoch:1},now);
    const headers={'authorization':`Bearer ${bearer}`,'x-rounds-device-session':credential,'content-type':'application/json'};
    const command:Wire_ConfirmPickupRequest={command_id:randomUUID(),context:{tenant_id:ids.tenant!,city_id:ids.city!},occurred_at:new Date(now*1000).toISOString(),
      execution_fence:{assignment_id:ids.assignment!,assignment_version:1,observation_id:randomUUID()},
      expected_versions:[{aggregate_type:'rounds',id:ids.round!,version:1},{aggregate_type:'stops',id:ids.pickup!,version:1},{aggregate_type:'manifests',id:ids.manifest!,version:1},{aggregate_type:'fulfillment_units',id:ids.unit!,version:1}],
      payload:{round_id:ids.round!,pickup_stop_id:ids.pickup!,manifest_ids:[ids.manifest!],fulfillment_unit_ids:[ids.unit!],quantities:[{line_id:ids.line!,quantity:5}]}};
    return {ids,deviceId,authSubject,headers,command,
      post:()=>new Request('http://rounds.internal'+pickupPath,{method:'POST',headers,body:JSON.stringify(command)}),
      status:()=>new Request(`http://rounds.internal${statusPath}?entity_id=${command.command_id}&tenant_id=${ids.tenant}&city_id=${ids.city}`,{headers})};
  };
  const expectCode=async(response:Response,status:number,code:string)=>{
    assert.equal(response.status,status,JSON.stringify(await response.clone().json()));assert.equal((await response.json()).code,code);
    assert.equal(response.headers.get('cache-control'),'no-store');
  };
  const noEffects=async(tenant:string)=>assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.custody_events WHERE tenant_id=$1',[tenant])).rows[0].n,0);
  await t.test('post, lost-response lookup and replay return exact original result and one physical effect',async()=>{
    const s=await setup(),reply=await handler(s.post());assert.equal(reply.status,200,JSON.stringify(await reply.clone().json()));
    const original=await reply.json();assert.equal(original.state,'committed');
    const lookup=await handler(s.status());assert.equal(lookup.status,200);assert.deepEqual((await lookup.json()).data.result,original);
    const replay=await handler(s.post());assert.equal(replay.headers.get('x-rounds-replayed'),'true');assert.deepEqual(await replay.json(),original);
    const stored=(await db.admin.query('SELECT authorization_round_id,authorization_assignment_id,result FROM rounds.command_receipts WHERE command_key=$1',[s.command.command_id])).rows[0];
    assert.equal(stored.authorization_round_id,s.ids.round);assert.equal(stored.authorization_assignment_id,s.ids.assignment);
    assert.ok(!JSON.stringify(stored).includes(s.headers['x-rounds-device-session']));
    assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.custody_events WHERE tenant_id=$1',[s.ids.tenant])).rows[0].n,1);
  });
  await t.test('wrong quantity is typed Error over HTTP and durable rejected status without custody',async()=>{
    const s=await setup();s.command.payload.quantities[0]!.quantity=3;
    await expectCode(await handler(s.post()),422,'COMPLETE_ORDER_REQUIRED');
    const status=await handler(s.status());assert.equal(status.status,200);assert.equal((await status.json()).data.result.state,'rejected');await noEffects(s.ids.tenant!);
  });
  for(const kind of ['missing-bearer','invalid-bearer','missing-device','tampered-device','wrong-subject','expired-device'])await t.test(kind,async()=>{
    const s=await setup(),r=s.post();
    if(kind==='missing-bearer')r.headers.delete('authorization');
    if(kind==='invalid-bearer')r.headers.set('authorization','Bearer not-verified');
    if(kind==='missing-device')r.headers.delete('x-rounds-device-session');
    if(kind==='tampered-device')r.headers.set('x-rounds-device-session',s.headers['x-rounds-device-session']+'x');
    if(kind==='wrong-subject'){const other=await setup();r.headers.set('authorization',other.headers.authorization);}
    if(kind==='expired-device')now+=900;
    await expectCode(await handler(r),401,'UNAUTHENTICATED');await noEffects(s.ids.tenant!);
  });
  for(const kind of ['disabled-principal','archived-principal','revoked-device','archived-device','changed-epoch','revoked-membership','revoked-city','suspended-tenant','reassigned-job'])await t.test(`${kind} blocks new command and status/replay`,async()=>{
    const s=await setup();assert.equal((await handler(s.post())).status,200);
    if(kind==='disabled-principal')await db.admin.query('UPDATE rounds.principals SET disabled_at=now() WHERE id=$1',[s.ids.actor]);
    if(kind==='archived-principal')await db.admin.query('UPDATE rounds.principals SET archived_at=now() WHERE id=$1',[s.ids.actor]);
    if(kind==='revoked-device')await db.admin.query('UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1',[s.deviceId]);
    if(kind==='archived-device')await db.admin.query('UPDATE rounds.driver_devices SET archived_at=now() WHERE id=$1',[s.deviceId]);
    if(kind==='changed-epoch')await db.admin.query('UPDATE rounds.driver_devices SET session_epoch=2 WHERE id=$1',[s.deviceId]);
    if(kind==='revoked-membership')await db.admin.query("UPDATE rounds.memberships SET status='revoked' WHERE id=$1",[s.ids.membership]);
    if(kind==='revoked-city')await db.admin.query("UPDATE rounds.city_grants SET capabilities='{}' WHERE id=$1",[s.ids.grant]);
    if(kind==='suspended-tenant')await db.admin.query("UPDATE rounds.tenants SET status='suspended' WHERE id=$1",[s.ids.tenant]);
    if(kind==='reassigned-job'){const other=await setup();await db.admin.query('UPDATE rounds.rounds SET driver_id=$2 WHERE id=$1',[s.ids.round,other.ids.driver]);}
    await expectCode(await handler(s.status()),403,'NOT_AUTHORIZED');await expectCode(await handler(s.post()),403,'NOT_AUTHORIZED');
    s.command.command_id=randomUUID();await expectCode(await handler(s.post()),403,'NOT_AUTHORIZED');
  });
  await t.test('cross-tenant context, forged principal body and another actor result fail closed',async()=>{
    const a=await setup(),b=await setup();assert.equal((await handler(a.post())).status,200);
    b.command.context=a.command.context;await expectCode(await handler(b.post()),403,'NOT_AUTHORIZED');
    const lookup=a.status();lookup.headers.set('authorization',b.headers.authorization);lookup.headers.set('x-rounds-device-session',b.headers['x-rounds-device-session']);
    await expectCode(await handler(lookup),403,'NOT_AUTHORIZED');
    const forged={...b.command,actor_id:a.ids.actor};await expectCode(await handler(new Request('http://rounds.internal'+pickupPath,{method:'POST',headers:b.headers,body:JSON.stringify(forged)})),400,'VALIDATION_FAILED');await noEffects(b.ids.tenant!);
  });
  await t.test('unknown receipt and invalid status filters do not disclose any data',async()=>{
    const s=await setup();await expectCode(await handler(s.status()),404,'NOT_FOUND');
    for(const suffix of ['&tenant_id='+s.ids.tenant,'&round_id='+s.ids.round,'&anything=bad'])await expectCode(await handler(new Request(s.status().url+suffix,{headers:s.headers})),400,'VALIDATION_FAILED');
    const crossCity=new URL(s.status().url);crossCity.searchParams.set('city_id',s.ids.otherCity!);await expectCode(await handler(new Request(crossCity,{headers:s.headers})),403,'NOT_AUTHORIZED');
  });
  await t.test('legacy receipt without original job cannot be backfilled or disclosed',async()=>{
    const s=await setup(),work=localPickupWork({principalId:s.ids.actor!,tenantId:s.ids.tenant!,cityId:s.ids.city!},s.command);delete work.receiptScope;
    await new CommandTransactionRunner(db.pool).run(work);
    await expectCode(await handler(s.status()),422,'UPGRADE_REQUIRED');await expectCode(await handler(s.post()),422,'UPGRADE_REQUIRED');
    await assert.rejects(db.admin.query('UPDATE rounds.command_receipts SET authorization_round_id=$2,authorization_assignment_id=$3 WHERE command_key=$1',[s.command.command_id,s.ids.round,s.ids.assignment]),/IMMUTABLE_RECORD/);
  });
  await t.test('identity resolver reveals no subject/disabled columns and transaction context does not leak',async()=>{
    const s=await setup();await handler(s.post());const client=await db.pool.connect();
    try{
      await client.query('BEGIN');await client.query('SET LOCAL ROLE rounds_api');
      assert.equal((await client.query('SELECT rounds.api_principal_id() id')).rows[0].id,null);
      await assert.rejects(client.query('SELECT auth_subject,disabled_at FROM rounds.principals'),/permission denied/);await client.query('ROLLBACK');
      await client.query('BEGIN');await assert.rejects(client.query('SET LOCAL ROLE rounds_api_auth_resolver'),/permission denied/);await client.query('ROLLBACK');
    }finally{client.release();}
  });
  await t.test('HTTP body and CORS guards reject invalid requests without effects',async()=>{
    const s=await setup();
    for(const value of ['{bad',JSON.stringify({...s.command,unknown:true}),' '.repeat(commandBodyLimit+1)])await expectCode(await handler(new Request('http://rounds.internal'+pickupPath,{method:'POST',headers:s.headers,body:value})),400,'VALIDATION_FAILED');
    const unsupported=s.post();unsupported.headers.set('content-type','text/plain');await expectCode(await handler(unsupported),400,'VALIDATION_FAILED');
    const origin=s.post();origin.headers.set('origin','https://untrusted.example');const before=authCalls;await expectCode(await handler(origin),403,'NOT_AUTHORIZED');assert.equal(authCalls,before);await noEffects(s.ids.tenant!);
  });
  await t.test('real Node boundary routes without legacy fallback and enforces disabled/body/preflight checks',async()=>{
    const s=await setup(),boundary=createV23NodeBoundary({handler,origin:'http://localhost:3000'});
    const server=createServer((req,res)=>{void boundary(req,res).then(handled=>{if(!handled)res.writeHead(404).end();});});
    await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));
    try{
      const address=server.address();assert.ok(address&&typeof address==='object');const base=`http://127.0.0.1:${address.port}`;
      const response=await fetch(base+pickupPath,{method:'POST',headers:s.headers,body:JSON.stringify(s.command)});assert.equal(response.status,200,JSON.stringify(await response.clone().json()));
      const big=await headerRejection(base+pickupPath,{method:'POST',headers:{...s.headers,'content-length':String(commandBodyLimit+1)}});await expectCode(big,400,'VALIDATION_FAILED');
      const preflight=await fetch(base+pickupPath,{method:'OPTIONS',headers:{origin:'http://localhost:3000','access-control-request-method':'POST','access-control-request-headers':'authorization, content-type, x-rounds-device-session'}});assert.equal(preflight.status,204);
    }finally{server.closeAllConnections();await new Promise<void>((resolve,reject)=>server.close(e=>e?reject(e):resolve()));}
    const disabled=createV23NodeBoundary({origin:'http://localhost:3000'}),off=createServer((req,res)=>{void disabled(req,res);});
    await new Promise<void>(resolve=>off.listen(0,'127.0.0.1',resolve));
    try{const a=off.address();assert.ok(a&&typeof a==='object');await expectCode(await fetch(`http://127.0.0.1:${a.port}${pickupPath}`,{method:'POST'}),403,'FEATURE_NOT_ENABLED');}
    finally{off.closeAllConnections();await new Promise<void>((resolve,reject)=>off.close(e=>e?reject(e):resolve()));}
  });
  t.diagnostic(JSON.stringify(db.evidence));
});
