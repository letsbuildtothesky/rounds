import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import type { Client } from 'pg';
import type { Wire_ConfirmPickupRequest, Wire_ConfirmPickupResult } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { localPickupWork } from '../../src/v23/confirm-local-pickup.js';
import { CommandTransactionRunner, CommandRejection } from '../../src/v23/transaction-runner.js';
import { validatePickupResult } from '../../src/v23/pickup-validation.js';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';

type Ids = Awaited<ReturnType<typeof seedWholeOrder>>;
async function claim(admin: Client, ids: Ids) {
  await admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id)
    VALUES($1,$2,'team',$3,$4)`, [ids.tenant,ids.delivery,ids.round,ids.unit]);
}
function request(ids: Ids): Wire_ConfirmPickupRequest {
  return {command_id:randomUUID(),context:{tenant_id:ids.tenant!,city_id:ids.city!},occurred_at:'2026-09-08T00:00:00Z',
    execution_fence:{assignment_id:ids.assignment!,assignment_version:1,observation_id:randomUUID()},
    expected_versions:[{aggregate_type:'rounds',id:ids.round!,version:1},{aggregate_type:'stops',id:ids.pickup!,version:1},
      {aggregate_type:'manifests',id:ids.manifest!,version:1},{aggregate_type:'fulfillment_units',id:ids.unit!,version:1}],
    payload:{round_id:ids.round!,pickup_stop_id:ids.pickup!,manifest_ids:[ids.manifest!],fulfillment_unit_ids:[ids.unit!],quantities:[{line_id:ids.line!,quantity:5}]}};
}
async function secondOrder(admin:Client, ids:Ids) {
  const second = {...ids,delivery:randomUUID(),manifest:randomUUID(),line:randomUUID(),unit:randomUUID(),dropoff:randomUUID()};
  await admin.query('BEGIN');
  try {
    await admin.query(`INSERT INTO rounds.deliveries(id,tenant_id,city_id,pickup_site_id,human_reference,service_date,timezone,window_start_at,window_end_at,address_text,destination,readiness,outcome,evidence_state,proof_policy_id,created_by,preparation_state)
      SELECT $1::uuid,tenant_id,city_id,pickup_site_id,$1::text,service_date,timezone,window_start_at,window_end_at,address_text,destination,readiness,outcome,evidence_state,proof_policy_id,created_by,preparation_state FROM rounds.deliveries WHERE id=$2`, [second.delivery,ids.delivery]);
    await admin.query(`INSERT INTO rounds.manifests(id,tenant_id,delivery_id,revision,source) VALUES($1,$2,$3,1,'manual')`, [second.manifest,ids.tenant,second.delivery]);
    await admin.query(`INSERT INTO rounds.manifest_lines(id,tenant_id,manifest_id,line_key,label,quantity,unit) VALUES($1,$2,$3,'L1','Second whole order',2.0001,'item')`, [second.line,ids.tenant,second.manifest]);
    await admin.query(`INSERT INTO rounds.fulfillment_units(id,tenant_id,delivery_id,manifest_id,state) VALUES($1,$2,$3,$4,'open')`, [second.unit,ids.tenant,second.delivery,second.manifest]);
    await admin.query(`INSERT INTO rounds.fulfillment_unit_lines(tenant_id,unit_id,line_id,allocated_quantity) VALUES($1,$2,$3,2.0001)`, [ids.tenant,second.unit,second.line]);
    await admin.query(`UPDATE rounds.deliveries SET current_manifest_id=$1 WHERE id=$2`, [second.manifest,second.delivery]);
    await admin.query(`INSERT INTO rounds.stops(id,tenant_id,round_id,delivery_id,kind,sequence,destination_version,state,service_seconds,fulfillment_unit_id) VALUES($1,$2,$3,$4,'dropoff',2,1,'released',60,$5)`, [second.dropoff,ids.tenant,ids.round,second.delivery,second.unit]);
    await claim(admin,second);
    await admin.query('COMMIT');
    return second;
  } catch (error) { await admin.query('ROLLBACK'); throw error; }
}

test('real R1 local ConfirmPickup on isolated full schema', {timeout:120000}, async t => {
  const db = await startPostgisFixture(); t.after(() => db.close());
  const runner = new CommandTransactionRunner(db.pool);
  const setup = async () => {
    const ids = await seedWholeOrder(db.admin); await claim(db.admin,ids);
    const auth = {principalId:ids.actor!,tenantId:ids.tenant!,cityId:ids.city!};
    return {ids,auth,r:request(ids)};
  };
  const counts = async (ids:Ids) => (await db.admin.query(`SELECT
    (SELECT count(*)::int FROM rounds.custody_events WHERE tenant_id=$1) AS custody,
    (SELECT count(*)::int FROM rounds.custody_balances WHERE tenant_id=$1) AS balances,
    (SELECT count(*)::int FROM rounds.delivery_attempts WHERE tenant_id=$1) AS attempts,
    (SELECT count(*)::int FROM rounds.domain_events WHERE tenant_id=$1) AS events,
    (SELECT count(*)::int FROM rounds.outbox_events WHERE tenant_id=$1) AS outbox`, [ids.tenant])).rows[0];
  const noWrites = async (ids:Ids) => {
    assert.deepEqual(await counts(ids),{custody:0,balances:0,attempts:0,events:0,outbox:0});
    assert.deepEqual((await db.admin.query(`SELECT u.state,m.sealed_at FROM rounds.fulfillment_units u JOIN rounds.manifests m ON m.id=u.manifest_id WHERE u.id=$1`, [ids.unit])).rows[0],{state:'open',sealed_at:null});
  };
  const errorCode = (r:Record<string,unknown>) => (r.error as {code:string}).code;
  await t.test('full pickup commits actual custody, seals, stable attempts and typed events exactly once', async () => {
    const {ids,auth,r} = await setup(); await noWrites(ids);
    const work=localPickupWork(auth,r),execute=work.execute;
    work.execute=async (...args)=>{try{return await execute(...args);}catch(error){
      // Isolated synthetic data only; no SQL detail/row contents logged.
      t.diagnostic(error instanceof Error ? error.message : 'Pickup failure'); throw error;
    }};
    const replies = await Promise.all([runner.run(work),runner.run(work)]);
    assert.deepEqual(replies.map(r => r.replayed).sort(),[false,true]);
    assert.deepEqual(replies[0]!.result,replies[1]!.result);
    const result = replies[0]!.result as Wire_ConfirmPickupResult;
    assert.equal(result.state,'committed'); validatePickupResult(result);
    assert.deepEqual(await counts(ids),{custody:1,balances:1,attempts:1,events:1,outbox:1});
    assert.equal(result.data.attempts[0]!.fulfillment_unit_id,ids.unit);
    assert.equal(result.data.attempts[0]!.stop_id,ids.dropoff);
    assert.equal(result.data.collected_units[0]!.state,'collected');
    assert.deepEqual(result.data.remaining_units,[]); assert.deepEqual(result.data.obligation_ids,[]);
    assert.equal((await db.admin.query('SELECT quantity FROM rounds.custody_balances WHERE tenant_id=$1',[ids.tenant])).rows[0].quantity,'5.0000');
    assert.deepEqual((await db.admin.query('SELECT from_custodian_id,event_kind FROM rounds.custody_events WHERE tenant_id=$1',[ids.tenant])).rows[0],{from_custodian_id:null,event_kind:'pickup'});
    assert.equal((await db.admin.query('SELECT state FROM rounds.rounds WHERE id=$1',[ids.round])).rows[0].state,'active');
    assert.equal((await db.admin.query('SELECT state FROM rounds.stops WHERE id=$1',[ids.pickup])).rows[0].state,'completed');
    assert.equal((await db.admin.query('SELECT outcome FROM rounds.deliveries WHERE id=$1',[ids.delivery])).rows[0].outcome,'open');
  });
  for (const preparation of ['unknown','preparing','blocked']) await t.test(`preparation ${preparation} rejects all writes`, async () => {
    const {ids,auth,r} = await setup();
    await db.admin.query('UPDATE rounds.deliveries SET preparation_state=$2 WHERE id=$1',[ids.delivery,preparation]);
    const reply = await runner.run(localPickupWork(auth,r)); assert.equal(errorCode(reply.result),'PICKUP_NOT_READY'); await noWrites(ids);
    assert.deepEqual(await runner.run(localPickupWork(auth,r)),{...reply,replayed:true});
  });
  for (const [label,mutate,expected] of [
    ['short quantity',(r:Wire_ConfirmPickupRequest) => {r.payload.quantities[0]!.quantity=3;},'COMPLETE_ORDER_REQUIRED'],
    ['excess quantity',(r:Wire_ConfirmPickupRequest) => {r.payload.quantities[0]!.quantity=6;},'COMPLETE_ORDER_REQUIRED'],
    ['duplicate line',(r:Wire_ConfirmPickupRequest) => {r.payload.quantities.push({...r.payload.quantities[0]!});},'MANIFEST_MISMATCH'],
    ['unknown line',(r:Wire_ConfirmPickupRequest) => {r.payload.quantities[0]!.line_id=randomUUID();},'MANIFEST_MISMATCH'],
    ['duplicate manifest',(r:Wire_ConfirmPickupRequest) => {r.payload.manifest_ids.push(r.payload.manifest_ids[0]!);},'MANIFEST_MISMATCH'],
    ['missing root',(r:Wire_ConfirmPickupRequest) => {r.expected_versions.pop();},'VALIDATION_FAILED'],
    ['extra root',(r:Wire_ConfirmPickupRequest) => {r.expected_versions.push({aggregate_type:'deliveries',id:randomUUID(),version:1});},'VALIDATION_FAILED'],
    ['stale root',(r:Wire_ConfirmPickupRequest) => {r.expected_versions[0]!.version=2;},'STALE_VERSION'],
    ['wrong original version',(r:Wire_ConfirmPickupRequest) => {r.execution_fence.assignment_version=2;},'EXECUTION_FENCE_CHANGED'],
  ] as const) await t.test(label, async () => {
    const {ids,auth,r} = await setup(); mutate(r);
    assert.equal(errorCode((await runner.run(localPickupWork(auth,r))).result),expected); await noWrites(ids);
  });
  await t.test('same command ID with changed valid bytes conflicts instead of another pickup', async () => {
    const {auth,r} = await setup(); await runner.run(localPickupWork(auth,r));
    r.occurred_at='2026-09-08T00:00:01Z';
    await assert.rejects(runner.run(localPickupWork(auth,r)),new CommandRejection('IDEMPOTENCY_CONFLICT'));
  });
  await t.test('two different IDs cannot collect the same order twice', async () => {
    const {ids,auth,r} = await setup(); const other={...r,command_id:randomUUID()};
    const replies=await Promise.all([runner.run(localPickupWork(auth,r)),runner.run(localPickupWork(auth,other))]);
    assert.deepEqual(replies.map(x=>x.result.state).sort(),['committed','rejected']);
    assert.deepEqual(await counts(ids),{custody:1,balances:1,attempts:1,events:1,outbox:1});
  });
  await t.test('revoked city capability blocks replay before receipt disclosure', async () => {
    const {ids,auth,r} = await setup(); await runner.run(localPickupWork(auth,r));
    await db.admin.query("UPDATE rounds.city_grants SET capabilities='{}' WHERE id=$1",[ids.grant]);
    await assert.rejects(runner.run(localPickupWork(auth,r)),new CommandRejection('NOT_AUTHORIZED'));
  });
  await t.test('suspended tenant denies new pickup and replay without granting tenant mutation rights', async () => {
    const {ids,auth,r}=await setup();
    await db.admin.query("UPDATE rounds.tenants SET status='suspended' WHERE id=$1",[ids.tenant]);
    await assert.rejects(runner.run(localPickupWork(auth,r)),new CommandRejection('NOT_AUTHORIZED')); await noWrites(ids);
    const committed=await setup();
    assert.equal((await runner.run(localPickupWork(committed.auth,committed.r))).result.state,'committed');
    const before=await counts(committed.ids);
    await db.admin.query("UPDATE rounds.tenants SET status='suspended' WHERE id=$1",[committed.ids.tenant]);
    await assert.rejects(runner.run(localPickupWork(committed.auth,committed.r)),new CommandRejection('NOT_AUTHORIZED'));
    assert.deepEqual(await counts(committed.ids),before);
  });
  await t.test('reassignment revokes the former driver before receipt access', async () => {
    const first=await setup(),second=await setup();
    await db.admin.query('UPDATE rounds.rounds SET driver_id=$2 WHERE id=$1',[first.ids.round,second.ids.driver]);
    await assert.rejects(runner.run(localPickupWork(first.auth,first.r)),new CommandRejection('NOT_AUTHORIZED')); await noWrites(first.ids);
  });
  for (const state of ['awaiting_receipt','partial','ready','discrepancy','cancelled']) await t.test(`inbound ${state} cannot enter the first-local-custody path`, async () => {
    const {ids,auth,r}=await setup(); const origin=randomUUID(),trip=randomUUID(),booking=randomUUID();
    await db.admin.query("INSERT INTO rounds.sites(id,tenant_id,city_id,name,site_type,address_text,timezone) VALUES($1,$2,$3,'Origin','pickup','Test','Asia/Bangkok')",[origin,ids.tenant,ids.city]);
    await db.admin.query("INSERT INTO rounds.transport_trips(id,tenant_id,origin_site_id,destination_site_id,service_date,planned_departure_at,planned_arrival_at,state,capacity_snapshot) VALUES($1,$2,$3,$4,current_date,now(),now()+interval '1 hour','scheduled','{}')",[trip,ids.tenant,origin,ids.site]);
    await db.admin.query("INSERT INTO rounds.trip_bookings(id,tenant_id,trip_id,delivery_id,manifest_id,state,booked_by,receiver_id) VALUES($1,$2,$3,$4,$5,'booked',$6,$6)",[booking,ids.tenant,trip,ids.delivery,ids.manifest,ids.actor]);
    await db.admin.query('INSERT INTO rounds.inbound_dependencies(tenant_id,delivery_id,booking_id,destination_site_id,state) VALUES($1,$2,$3,$4,$5)',[ids.tenant,ids.delivery,booking,ids.site,state]);
    const reply=(await runner.run(localPickupWork(auth,r))).result;
    assert.equal(errorCode(reply),state==='discrepancy'?'INBOUND_DISCREPANCY':'INBOUND_NOT_RECEIVED'); await noWrites(ids);
    assert.equal((await db.admin.query('SELECT count(*)::int AS n FROM rounds.trip_receipts WHERE tenant_id=$1',[ids.tenant])).rows[0].n,0);
  });
  await t.test('pre-existing custody is never relabelled as a first local pickup', async () => {
    const {ids,auth,r}=await setup(); const custodian=randomUUID(),event=randomUUID();
    await db.admin.query("INSERT INTO rounds.custodians(id,tenant_id,kind,site_id) VALUES($1,$2,'site',$3)",[custodian,ids.tenant,ids.site]);
    await db.admin.query("INSERT INTO rounds.custody_events(id,tenant_id,manifest_id,event_kind,occurred_at,received_at,actor_id,command_id,round_id,to_custodian_id) VALUES($1,$2,$3,'correction',now(),now(),$4,$5,$6,$7)",[event,ids.tenant,ids.manifest,ids.actor,randomUUID(),ids.round,custodian]);
    await db.admin.query("INSERT INTO rounds.custody_event_lines(tenant_id,event_id,line_id,quantity,condition_code) VALUES($1,$2,$3,5,'not_assessed')",[ids.tenant,event,ids.line]);
    await db.admin.query('INSERT INTO rounds.custody_balances(tenant_id,line_id,quantity,last_event_id,custodian_id) VALUES($1,$2,5,$3,$4)',[ids.tenant,ids.line,event,custodian]);
    const before=await counts(ids);
    assert.equal(errorCode((await runner.run(localPickupWork(auth,r))).result),'CUSTODY_MISMATCH');
    assert.deepEqual(await counts(ids),before);
    assert.equal((await db.admin.query('SELECT quantity FROM rounds.custody_balances WHERE tenant_id=$1',[ids.tenant])).rows[0].quantity,'5.0000');
  });
  for (const state of ['pending','en_route','arrived','handed_over']) await t.test(`existing ${state} attempt cannot be duplicated from an open unit`, async () => {
    const {ids,auth,r}=await setup();
    const attempt=(await db.admin.query(`INSERT INTO rounds.delivery_attempts(tenant_id,delivery_id,stop_id,driver_id,attempt_number,state,fulfillment_unit_id)
      VALUES($1,$2,$3,$4,1,$5,$6) RETURNING id`,[ids.tenant,ids.delivery,ids.dropoff,ids.driver,state,ids.unit])).rows[0].id;
    assert.equal(errorCode((await runner.run(localPickupWork(auth,r))).result),'PICKUP_NOT_READY');
    assert.deepEqual(await counts(ids),{custody:0,balances:0,attempts:1,events:0,outbox:0});
    assert.deepEqual((await db.admin.query('SELECT id,state FROM rounds.delivery_attempts WHERE tenant_id=$1',[ids.tenant])).rows,[{id:attempt,state}]);
    assert.deepEqual((await db.admin.query(`SELECT u.state,m.sealed_at FROM rounds.fulfillment_units u JOIN rounds.manifests m ON m.id=u.manifest_id WHERE u.id=$1`,[ids.unit])).rows[0],{state:'open',sealed_at:null});
  });
  await t.test('cross-tenant job, wrong actor and wrong pickup stop cannot mutate', async () => {
    const first=await setup(),second=await setup();
    await assert.rejects(runner.run(localPickupWork(second.auth,{...first.r,context:second.r.context})),new CommandRejection('NOT_AUTHORIZED'));
    await assert.rejects(runner.run(localPickupWork({...first.auth,principalId:second.auth.principalId},first.r)),new CommandRejection('NOT_AUTHORIZED'));
    first.r.payload.pickup_stop_id=second.ids.pickup!;
    assert.equal(errorCode((await runner.run(localPickupWork(first.auth,first.r))).result),'NOT_AUTHORIZED');
    await noWrites(first.ids); await noWrites(second.ids);
  });
  for (const flag of ['not-arrived','hold','not-released','no-claim','wrong-site']) await t.test(flag, async () => {
    const {ids,auth,r}=await setup();
    if(flag==='not-arrived') await db.admin.query("UPDATE rounds.stops SET state='en_route' WHERE id=$1",[ids.pickup]);
    if(flag==='hold') await db.admin.query('UPDATE rounds.rounds SET operational_hold=true WHERE id=$1',[ids.round]);
    if(flag==='not-released') await db.admin.query("UPDATE rounds.rounds SET state='staged' WHERE id=$1",[ids.round]);
    if(flag==='no-claim') await db.admin.query('DELETE FROM rounds.active_delivery_claims WHERE tenant_id=$1',[ids.tenant]);
    if(flag==='wrong-site') {
      const site=randomUUID(); await db.admin.query("INSERT INTO rounds.sites(id,tenant_id,city_id,name,site_type,address_text,timezone) VALUES($1,$2,$3,'Other pickup','pickup','Test','Asia/Bangkok')",[site,ids.tenant,ids.city]);
      await db.admin.query('UPDATE rounds.deliveries SET pickup_site_id=$2 WHERE id=$1',[ids.delivery,site]);
    }
    assert.equal((await runner.run(localPickupWork(auth,r))).result.state,'rejected'); await noWrites(ids);
  });
  await t.test('whole batch cannot silently omit a blocked second order', async () => {
    const {ids,auth,r}=await setup(); const second=await secondOrder(db.admin,ids);
    r.expected_versions.push({aggregate_type:'manifests',id:second.manifest,version:1},{aggregate_type:'fulfillment_units',id:second.unit,version:1});
    await db.admin.query("UPDATE rounds.deliveries SET preparation_state='blocked' WHERE id=$1",[second.delivery]);
    assert.equal(errorCode((await runner.run(localPickupWork(auth,r))).result),'MANIFEST_MISMATCH'); await noWrites(ids);
    r.command_id=randomUUID(); r.payload.manifest_ids.push(second.manifest);r.payload.fulfillment_unit_ids.push(second.unit);r.payload.quantities.push({line_id:second.line,quantity:2.0001});
    assert.equal(errorCode((await runner.run(localPickupWork(auth,r))).result),'PICKUP_NOT_READY'); await noWrites(ids);
    await db.admin.query("UPDATE rounds.deliveries SET preparation_state='ready' WHERE id=$1",[second.delivery]); r.command_id=randomUUID();
    const reply=(await runner.run(localPickupWork(auth,r))).result as Wire_ConfirmPickupResult;
    assert.equal(reply.state,'committed'); assert.equal(reply.data.attempts.length,2);
    assert.equal(reply.resources.filter(x=>x.aggregate_type==='custody_events').length,2);
    assert.deepEqual(await counts(ids),{custody:2,balances:2,attempts:2,events:2,outbox:2});
    assert.deepEqual(reply.data.attempts.map(x=>x.fulfillment_unit_id).sort(),[ids.unit,second.unit].sort());
  });
  await t.test('constraint failure after real pickup writes rolls back custody, attempt, events and seals', async () => {
    const {ids,auth,r}=await setup(); const work=localPickupWork(auth,r),execute=work.execute;
    work.execute=async (...args)=>{
      const result=await execute(...args);
      // Valid SQL, invalid FK: fault after all real handler writes.
      await args[0].query(`INSERT INTO rounds.custody_balances(tenant_id,line_id,quantity,last_event_id,custodian_id) VALUES($1,$2,1,$3,$4)`,[ids.tenant,randomUUID(),randomUUID(),randomUUID()]);
      return result;
    };
    assert.equal(errorCode((await runner.run(work)).result),'VALIDATION_FAILED'); await noWrites(ids);
    assert.equal((await db.admin.query('SELECT count(*)::int AS n FROM rounds.command_receipts WHERE command_key=$1',[r.command_id])).rows[0].n,1);
  });
  t.diagnostic(JSON.stringify(db.evidence));
});
