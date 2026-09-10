import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { test } from 'node:test';
import type { Pool } from 'pg';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';
import { createDeviceRegistrationHttp, deviceSessionPath, deviceRevokePath } from '../../src/v23/device-registration-http.js';
import { createV23NodeBoundary } from '../../src/v23/node-boundary.js';
import { deviceSessions } from '../../src/v23/device-session.js';
import { deviceRegistration, installationKey } from '../../src/v23/device-registration.js';
import { createPickupHttp, pickupPath, statusPath } from '../../src/v23/pickup-http.js';
import { CommandRejection, TransactionUnavailable } from '../../src/v23/transaction-runner.js';

test('real restricted device registration, refresh, revocation and pickup integration',{timeout:120000},async t=>{
  const db=await startPostgisFixture();t.after(()=>db.close());
  const devices=deviceSessions({id:'fixture-only',secret:randomBytes(32)}),subjects=new Map<string,string>();
  let now=1788861600;
  // Only upstream Auth is mocked. No device row or capability is fixture-issued:
  // every successful enrollment below goes through the actual new service.
  const verifyBearer=async(token:string)=>{const subject=subjects.get(token);if(!subject)throw new CommandRejection('UNAUTHENTICATED');return subject;};
  const options={pool:db.pool,devices,verifyBearer,origin:'http://localhost:3000',now:()=>now};
  const handler=createDeviceRegistrationHttp(options),pickup=createPickupHttp(options);
  const setup=async()=>{
    const ids=await seedWholeOrder(db.admin),subject=randomUUID(),bearer=randomUUID(),secret=randomBytes(32).toString('hex');
    await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1',[ids.actor,subject]);subjects.set(bearer,subject);
    const request=(path=deviceSessionPath,body:unknown={installation_secret:secret,platform:'android'})=>new Request('http://rounds.internal'+path,
      {method:'POST',headers:{authorization:`Bearer ${bearer}`,'content-type':'application/json'},body:JSON.stringify(body)});
    return {ids,subject,bearer,secret,request,revoke:()=>request(deviceRevokePath,{installation_secret:secret})};
  };
  const ok=async(response:Response)=>{assert.equal(response.status,200,JSON.stringify(await response.clone().json()));assert.equal(response.headers.get('cache-control'),'no-store');return response.json();};
  const error=async(response:Response,status:number,code:string)=>{assert.equal(response.status,status,JSON.stringify(await response.clone().json()));assert.equal((await response.json()).code,code);};
  const count=async(driver:string)=>(await db.admin.query('SELECT count(*)::int n FROM rounds.driver_devices WHERE driver_id=$1',[driver])).rows[0].n;
  const audits=async(principal:string)=>(await db.admin.query('SELECT event_type,payload FROM rounds.account_events WHERE principal_id=$1 ORDER BY created_at,id',[principal])).rows;

  await t.test('register/retry/refresh preserve identity, store only hashed secret and emit one private audit',async()=>{
    const s=await setup(),a=await ok(await handler(s.request()));
    assert.equal(a.principal_id,s.ids.actor);assert.equal(a.session_epoch,1);
    const claims=devices.verify(a.device_session,s.subject,now);assert.equal(claims.deviceId,a.device_id);
    assert.equal(claims.exp-now,900);assert.ok(!JSON.stringify(a).includes(s.secret));
    const b=await ok(await handler(s.request()));assert.equal(a.device_id,b.device_id);assert.equal(await count(s.ids.driver!),1);
    now+=901;assert.throws(()=>devices.verify(a.device_session,s.subject,now));
    const c=await ok(await handler(s.request()));assert.equal(c.device_id,a.device_id);devices.verify(c.device_session,s.subject,now);
    const row=(await db.admin.query('SELECT device_key,push_secret_reference FROM rounds.driver_devices WHERE id=$1',[a.device_id])).rows[0];
    assert.equal(row.device_key,installationKey(s.ids.actor!,s.secret));assert.equal(row.push_secret_reference,null);
    const facts=await audits(s.ids.actor!);assert.equal(facts.length,1);assert.equal(facts[0].event_type,'device.registered');
    assert.ok(!JSON.stringify(facts).includes(s.secret));assert.ok(!JSON.stringify(facts).includes(a.device_session));
    assert.ok(!JSON.stringify(facts).includes(row.device_key));
    assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.command_receipts WHERE actor_id=$1',[s.ids.actor])).rows[0].n,0);
  });
  await t.test('concurrent identical registration has one device/audit, not duplicate installs',async()=>{
    const s=await setup(),results=await Promise.all(Array.from({length:4},()=>handler(s.request()).then(ok)));
    assert.equal(new Set(results.map(r=>r.device_id)).size,1);assert.equal(await count(s.ids.driver!),1);assert.equal((await audits(s.ids.actor!)).length,1);
  });
  await t.test('revocation replay is stable, bumps epoch once, and cannot reactivate',async()=>{
    const s=await setup(),a=await ok(await handler(s.request())),b=await ok(await handler(s.revoke()));
    assert.deepEqual(b,{device_id:a.device_id,revoked:true});assert.deepEqual(await ok(await handler(s.revoke())),b);
    await error(await handler(s.request()),403,'NOT_AUTHORIZED');
    const row=(await db.admin.query('SELECT session_epoch FROM rounds.driver_devices WHERE id=$1',[a.device_id])).rows[0];assert.equal(row.session_epoch,'2');
    assert.equal((await audits(s.ids.actor!)).length,2);
    await assert.rejects(db.admin.query('UPDATE rounds.driver_devices SET revoked_at=NULL WHERE id=$1',[a.device_id]),/IMMUTABLE_RECORD/);
    await assert.rejects(db.admin.query('UPDATE rounds.driver_devices SET session_epoch=1 WHERE id=$1',[a.device_id]),/IMMUTABLE_RECORD/);
  });
  for(const kind of ['disabled-principal','archived-principal','archived-driver','no-driver'])await t.test(`${kind} cannot register`,async()=>{
    const s=await setup();
    if(kind==='disabled-principal')await db.admin.query('UPDATE rounds.principals SET disabled_at=now() WHERE id=$1',[s.ids.actor]);
    if(kind==='archived-principal')await db.admin.query('UPDATE rounds.principals SET archived_at=now() WHERE id=$1',[s.ids.actor]);
    if(kind==='archived-driver')await db.admin.query('UPDATE rounds.drivers SET archived_at=now() WHERE id=$1',[s.ids.driver]);
    if(kind==='no-driver'){const subject=randomUUID();await db.admin.query("INSERT INTO rounds.principals(auth_subject,display_name) VALUES($1,'Synthetic non-driver')",[subject]);subjects.set(s.bearer,subject);}
    await error(await handler(s.request()),403,'NOT_AUTHORIZED');assert.equal(await count(s.ids.driver!),0);
  });
  await t.test('wrong bearer, unknown identity and supplied actor/device IDs grant nothing',async()=>{
    const s=await setup(),missing=s.request();missing.headers.delete('authorization');await error(await handler(missing),401,'UNAUTHENTICATED');
    const bad=s.request();bad.headers.set('authorization','Bearer invalid');await error(await handler(bad),401,'UNAUTHENTICATED');
    subjects.set(s.bearer,randomUUID());await error(await handler(s.request()),403,'NOT_AUTHORIZED');subjects.set(s.bearer,s.subject);
    for(const extra of [{principal_id:s.ids.actor},{driver_id:s.ids.driver},{device_id:randomUUID()},{session_epoch:2}])
      await error(await handler(s.request(deviceSessionPath,{installation_secret:s.secret,platform:'android',...extra})),400,'VALIDATION_FAILED');
    assert.equal(await count(s.ids.driver!),0);
  });
  await t.test('another account cannot refresh/revoke a victim installation even knowing its secret',async()=>{
    const a=await setup(),b=await setup(),first=await ok(await handler(a.request()));
    await error(await handler(b.request(deviceRevokePath,{installation_secret:a.secret})),403,'NOT_AUTHORIZED');
    const own=await ok(await handler(b.request(deviceSessionPath,{installation_secret:a.secret,platform:'android'})));
    assert.notEqual(own.device_id,first.device_id);assert.equal(own.principal_id,b.ids.actor);
    assert.throws(()=>devices.verify(first.device_session,b.subject,now));
    assert.equal((await ok(await handler(a.request()))).device_id,first.device_id);
  });
  await t.test('platform identity and archived installation are immutable; legacy device rows remain unchanged',async()=>{
    const s=await setup(),a=await ok(await handler(s.request()));
    await error(await handler(s.request(deviceSessionPath,{installation_secret:s.secret,platform:'ios'})),400,'VALIDATION_FAILED');
    await assert.rejects(db.admin.query("UPDATE rounds.driver_devices SET device_key='replacement' WHERE id=$1",[a.device_id]),/IMMUTABLE_RECORD/);
    await db.admin.query('UPDATE rounds.driver_devices SET archived_at=now() WHERE id=$1',[a.device_id]);await error(await handler(s.request()),403,'NOT_AUTHORIZED');
    const legacy=randomUUID();await db.admin.query("INSERT INTO rounds.driver_devices(id,driver_id,platform,device_key) VALUES($1,$2,'android','legacy-key')",[legacy,s.ids.driver]);
    const fresh=randomBytes(32).toString('hex');await ok(await handler(s.request(deviceSessionPath,{installation_secret:fresh,platform:'android'})));
    assert.equal((await db.admin.query('SELECT device_key FROM rounds.driver_devices WHERE id=$1',[legacy])).rows[0].device_key,'legacy-key');
  });
  await t.test('new-registration rate limit is per principal, concurrent-safe, and does not block refresh/revoke',async()=>{
    const s=await setup();await ok(await handler(s.request()));
    for(let i=0;i<9;i++)await ok(await handler(s.request(deviceSessionPath,{installation_secret:randomBytes(32).toString('hex'),platform:'android'})));
    const responses=await Promise.all([1,2].map(()=>handler(s.request(deviceSessionPath,{installation_secret:randomBytes(32).toString('hex'),platform:'android'}))));
    for(const r of responses){assert.equal(r.headers.get('retry-after'),'60');await error(r,429,'RATE_LIMITED');}
    assert.equal(await count(s.ids.driver!),10);await ok(await handler(s.request()));await ok(await handler(s.revoke()));
    const other=await setup();await ok(await handler(other.request()));
  });
  await t.test('audit write failure rolls back registration, rather than returning a credential',async()=>{
    const s=await setup();
    await db.admin.query(`CREATE FUNCTION rounds.fixture_reject_device_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'fixture audit failure'; END $$;
      CREATE TRIGGER fixture_reject_device_audit BEFORE INSERT ON rounds.account_events FOR EACH ROW EXECUTE FUNCTION rounds.fixture_reject_device_audit()`);
    try{await error(await handler(s.request()),503,'PROVIDER_UNAVAILABLE');assert.equal(await count(s.ids.driver!),0);}
    finally{await db.admin.query('DROP TRIGGER fixture_reject_device_audit ON rounds.account_events; DROP FUNCTION rounds.fixture_reject_device_audit()');}
    await ok(await handler(s.request()));assert.equal((await audits(s.ids.actor!)).length,1);
  });
  await t.test('lost COMMIT acknowledgement preserves one installation and returns no credential until retry',async()=>{
    const s=await setup();let poisoned=false;
    // PostgreSQL commits for real; only the returned acknowledgement is lost.
    const transport={connect:async()=>{
      const c=await db.pool.connect();return new Proxy(c,{get(target,key){
        if(key==='query')return async(...args:unknown[])=>{const result=await (target.query as (...a:unknown[])=>Promise<unknown>).apply(target,args);if(args[0]==='COMMIT')throw new Error('fixture lost ack');return result;};
        if(key==='release')return (destroy:boolean)=>{poisoned=destroy;target.release(destroy);};return Reflect.get(target,key);
      }});
    }} as Pool;
    await assert.rejects(deviceRegistration({pool:transport,devices,now:()=>now})(s.subject,{operation:'session',installation_secret:s.secret,platform:'android'},randomUUID()),new TransactionUnavailable('UNKNOWN_RESULT'));
    assert.equal(poisoned,true);assert.equal(await count(s.ids.driver!),1);
    await ok(await handler(s.request()));assert.equal(await count(s.ids.driver!),1);assert.equal((await audits(s.ids.actor!)).length,1);
  });
  await t.test('enrolled capability drives real pickup/status; self-revocation blocks both afterward',async()=>{
    const s=await setup(),enrolled=await ok(await handler(s.request()));
    await db.admin.query("INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)",[s.ids.tenant,s.ids.delivery,s.ids.round,s.ids.unit]);
    const headers={authorization:`Bearer ${s.bearer}`,'content-type':'application/json','x-rounds-device-session':enrolled.device_session};
    const command={command_id:randomUUID(),context:{tenant_id:s.ids.tenant,city_id:s.ids.city},occurred_at:new Date(now*1000).toISOString(),
      execution_fence:{assignment_id:s.ids.assignment,assignment_version:1,observation_id:randomUUID()},
      expected_versions:[{aggregate_type:'rounds',id:s.ids.round,version:1},{aggregate_type:'stops',id:s.ids.pickup,version:1},{aggregate_type:'manifests',id:s.ids.manifest,version:1},{aggregate_type:'fulfillment_units',id:s.ids.unit,version:1}],
      payload:{round_id:s.ids.round,pickup_stop_id:s.ids.pickup,manifest_ids:[s.ids.manifest],fulfillment_unit_ids:[s.ids.unit],quantities:[{line_id:s.ids.line,quantity:5}]}};
    const post=()=>new Request('http://rounds.internal'+pickupPath,{method:'POST',headers,body:JSON.stringify(command)});
    const status=()=>new Request(`http://rounds.internal${statusPath}?entity_id=${command.command_id}&tenant_id=${s.ids.tenant}&city_id=${s.ids.city}`,{headers});
    const committed=await ok(await pickup(post()));assert.equal(committed.state,'committed');assert.deepEqual((await ok(await pickup(status()))).data.result,committed);
    await ok(await handler(s.revoke()));await error(await pickup(post()),403,'NOT_AUTHORIZED');await error(await pickup(status()),403,'NOT_AUTHORIZED');
    assert.equal((await db.admin.query('SELECT count(*)::int n FROM rounds.custody_events WHERE tenant_id=$1',[s.ids.tenant])).rows[0].n,1);
  });
  await t.test('refresh/revoke race cannot resurrect device or grant current epoch after revoke',async()=>{
    const s=await setup();await ok(await handler(s.request()));
    const [refresh,revoke]=await Promise.all([handler(s.request()),handler(s.revoke())]);await ok(revoke);
    assert.ok([200,403].includes(refresh.status));await error(await handler(s.request()),403,'NOT_AUTHORIZED');
    assert.equal((await db.admin.query('SELECT session_epoch FROM rounds.driver_devices WHERE driver_id=$1',[s.ids.driver])).rows[0].session_epoch,'2');
    assert.equal((await audits(s.ids.actor!)).length,2);
  });
  await t.test('transport shape/size/origin/paths and default-off behavior are enforced over localhost',async()=>{
    const s=await setup();for(const input of [{},{installation_secret:'short',platform:'android'},{installation_secret:s.secret,platform:'web'}])await error(await handler(s.request(deviceSessionPath,input)),400,'VALIDATION_FAILED');
    const cors=s.request();cors.headers.set('origin','https://evil.example');await error(await handler(cors),403,'NOT_AUTHORIZED');
    await error(await handler(s.request(deviceSessionPath+'?actor_id='+s.ids.actor)),400,'VALIDATION_FAILED');
    for(const enabled of [false,true]){
      const boundary=createV23NodeBoundary({...(enabled?{handler}:{}),origin:options.origin});
      const server=createServer((req,res)=>{void boundary(req,res).then(found=>{if(!found)res.writeHead(404).end();});});
      await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));
      try{const a=server.address();assert.ok(a&&typeof a==='object');const base=`http://127.0.0.1:${a.port}`;
        const req=s.request(),response=await fetch(base+deviceSessionPath,{method:'POST',headers:req.headers,body:await req.text()});
        if(enabled){await ok(response);await error(await fetch(base+deviceSessionPath,{method:'POST',headers:s.request().headers,body:' '.repeat(4097)}),400,'VALIDATION_FAILED');}
        else{await error(response,403,'FEATURE_NOT_ENABLED');assert.equal(await count(s.ids.driver!),0);}
      }finally{server.closeAllConnections();await new Promise<void>((resolve,reject)=>server.close(e=>e?reject(e):resolve()));}
    }
  });
  t.diagnostic(JSON.stringify(db.evidence));
});
