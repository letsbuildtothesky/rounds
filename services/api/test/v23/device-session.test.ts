import assert from 'node:assert/strict';
import { randomBytes,randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { deviceSessions } from '../../src/v23/device-session.js';
import { supabaseBearerVerifier } from '../../src/v23/authentication.js';
import { createV23Runtime } from '../../src/v23/runtime.js';
import { ingressLimiter } from '../../src/v23/node-boundary.js';

const identity=()=>({principalId:randomUUID(),authSubject:randomUUID(),deviceId:randomUUID(),epoch:1});
test('device capability authenticates exact identity, expiry and dedicated key',()=>{
  const codec=deviceSessions({id:'test-key',secret:randomBytes(32)}),id=identity(),token=codec.issue(id,1000);
  assert.equal(codec.verify(token,id.authSubject,1001).deviceId,id.deviceId);
  assert.throws(()=>codec.verify(token,randomUUID(),1001),/UNAUTHENTICATED/);
  assert.throws(()=>codec.verify(token,id.authSubject,1900),/UNAUTHENTICATED/);
  assert.throws(()=>codec.verify(token,id.authSubject,999),/UNAUTHENTICATED/);
  assert.throws(()=>deviceSessions({id:'test-key',secret:randomBytes(32)}).verify(token,id.authSubject,1001),/UNAUTHENTICATED/);
  assert.throws(()=>codec.verify(token+'x',id.authSubject,1001),/UNAUTHENTICATED/);
  const [payload,signature]=token.split('.');const claims=JSON.parse(Buffer.from(payload!,'base64url').toString());claims.epoch=2;
  assert.throws(()=>codec.verify(Buffer.from(JSON.stringify(claims)).toString('base64url')+'.'+signature,id.authSubject,1001),/UNAUTHENTICATED/);
  assert.throws(()=>deviceSessions({id:'test-key',secret:Buffer.alloc(16)}),/Dedicated/);
});
test('device issuer rejects invalid epochs and unexpected identity fields',()=>{
  const codec=deviceSessions({id:'test',secret:randomBytes(32)});
  for(const epoch of [0,-1,1.5,Number.MAX_SAFE_INTEGER+1])assert.throws(()=>codec.issue({...identity(),epoch},1000),/UNAUTHENTICATED/);
  assert.throws(()=>codec.issue({...identity(),principalId:'user-name'},1000),/UNAUTHENTICATED/);
  assert.throws(()=>codec.issue({...identity(),extra:true} as ReturnType<typeof identity>,1000),/UNAUTHENTICATED/);
});
test('Supabase SDK verification uses configured Auth server and bearer, not caller metadata',async()=>{
  const subject=randomUUID();let calls=0;
  const verify=supabaseBearerVerifier('https://auth-fixture.example','sb_publishable_test',async(input,init)=>{
    calls++;assert.equal(String(input),'https://auth-fixture.example/auth/v1/user');
    assert.equal(new Headers(init?.headers).get('authorization'),'Bearer fixture-token');
    assert.ok(init?.signal);
    return Response.json({id:subject,user_metadata:{principal_id:randomUUID()},aud:'authenticated'});
  });
  assert.equal(await verify('fixture-token'),subject);assert.equal(calls,1);
});
test('Auth error is fail-closed and does not expose provider detail',async()=>{
  const verify=supabaseBearerVerifier('https://auth-fixture.example','sb_publishable_test',async()=>Response.json({msg:'private provider detail'},{status:401}));
  await assert.rejects(verify('invalid-token'),/^Error: UNAUTHENTICATED$/);
  assert.throws(()=>supabaseBearerVerifier('http://auth-fixture.example','key'),/HTTPS/);
});
test('new runtime stays disabled and cannot use shared/production or legacy admin configuration',()=>{
  assert.equal(createV23Runtime({SUPABASE_SECRET_KEY:'not-a-command-password'},'http://localhost:3000'),undefined);
  assert.throws(()=>createV23Runtime({ROUNDS_V23_HTTP_MODE:'isolated',APP_ENV:'production'},'http://localhost:3000'),/gated/);
  assert.throws(()=>createV23Runtime({ROUNDS_V23_HTTP_MODE:'isolated',APP_ENV:'local',ROUNDS_V23_COMMAND_DATABASE_URL:'postgresql://a:b@shared.example/rounds'},'http://localhost:3000'),/loopback/);
});
test('ingress limiter bounds each window and total tracked keys',()=>{
  const admit=ingressLimiter(2,60,2);
  assert.equal(admit('a',0),true);assert.equal(admit('a',1),true);assert.equal(admit('a',2),false);
  assert.equal(admit('b',2),true);assert.equal(admit('c',2),false);assert.equal(admit('a',60),true);
});
