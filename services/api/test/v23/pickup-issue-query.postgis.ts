import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { deviceSessions } from '../../src/v23/device-session.js';
import { test } from 'node:test';
import { createDeviceRegistrationHttp } from '../../src/v23/device-registration-http.js';
import { createDriverExecutionHttp, driverRoundPath } from '../../src/v23/driver-execution-query.js';
import { createPickupHttp } from '../../src/v23/pickup-http.js';
import { reportIssuePath } from '../../src/v23/report-local-pickup-issue.js';
import { validatePickupIssueQuery } from '../../src/v23/pickup-validation.js';
import { CommandRejection } from '../../src/v23/transaction-runner.js';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';

test('original pickup report status: actual restricted query, no fabricated decisions or readiness', { timeout: 120000 }, async t => {
  const db = await startPostgisFixture(); t.after(() => db.close());
  const subjects = new Map<string, string>();
  const options = { pool: db.pool, devices: deviceSessions({id:'issue-read-test',secret:randomBytes(32)}), origin: 'http://localhost:3000', verifyBearer: async (bearer: string) => {
    const subject = subjects.get(bearer); if (!subject) throw new CommandRejection('UNAUTHENTICATED'); return subject;
  } };
  const enroll = createDeviceRegistrationHttp(options), post = createPickupHttp(options), get = createDriverExecutionHttp(options);
  async function setup(wait = false) {
    const ids = await seedWholeOrder(db.admin), bearer = randomUUID(), subject = randomUUID(); subjects.set(bearer, subject);
    await db.admin.query('UPDATE rounds.principals SET auth_subject=$2 WHERE id=$1', [ids.actor, subject]);
    await db.admin.query(`INSERT INTO rounds.active_delivery_claims(tenant_id,delivery_id,claim_kind,round_id,fulfillment_unit_id) VALUES($1,$2,'team',$3,$4)`, [ids.tenant,ids.delivery,ids.round,ids.unit]);
    const registration = await enroll(new Request('http://rounds.internal/v1/auth/driver-device/session', { method: 'POST', headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' }, body: JSON.stringify({ installation_secret: randomBytes(32).toString('hex'), platform: 'android' }) }));
    assert.equal(registration.status, 200); const device = await registration.json();
    const headers = { authorization: `Bearer ${bearer}`, 'x-rounds-device-session': device.device_session, 'content-type': 'application/json' };
    const observation = randomUUID();
    const report = await post(new Request('http://rounds.internal'+reportIssuePath, { method: 'POST', headers, body: JSON.stringify({
      command_id: randomUUID(), context: { tenant_id: ids.tenant, city_id: ids.city }, occurred_at: '2026-09-09T00:00:00Z',
      execution_fence: { assignment_id: ids.assignment, assignment_version: 1, observation_id: observation },
      expected_versions: [{ aggregate_type: 'rounds', id: ids.round, version: 1 }, ...(!wait ? [{ aggregate_type: 'deliveries', id: ids.delivery, version: 1 }] : [])],
      payload: { round_id: ids.round, ...(!wait ? { delivery_id: ids.delivery } : {}), issue_type: wait ? 'pickup_wait' : 'package', reason_code: wait ? 'awaiting_goods' : 'missing', affected_lines: [], asset_ids: [], detail: 'Private original report' },
    }) }));
    assert.equal(report.status, 200, JSON.stringify(await report.clone().json()));
    const issue = (await report.json()).data.resource.id;
    const params = new URLSearchParams({ entity_id: ids.round!, tenant_id: ids.tenant!, city_id: ids.city!, view: 'pickup_issue', issue_id: issue });
    return { ids, headers, device, issue, observation, params };
  }
  type Scenario = Awaited<ReturnType<typeof setup>>;
  const read = (s: Scenario) => get(new Request('http://rounds.internal'+driverRoundPath+'?'+s.params, { headers: s.headers }));
  const counts = async () => (await db.admin.query(`SELECT
    (SELECT count(*) FROM rounds.issue_decisions) decisions, (SELECT count(*) FROM rounds.domain_events) events,
    (SELECT count(*) FROM rounds.command_receipts) receipts, (SELECT count(*) FROM rounds.custody_events) custody,
    (SELECT count(*) FROM rounds.outbox_events) outbox`)).rows[0];
  async function body(s: Scenario) { const r=await read(s); assert.equal(r.status,200,JSON.stringify(await r.clone().json())); const b=await r.json();validatePickupIssueQuery(b);return b; }
  // Resolver not implemented in this increment. These immutable Operations
  // records are deliberately seeded; only registration/report/query are real.
  async function decision(s: Scenario, action='wait', supersedes: string|null=null, instructions='Wait at the pickup site.\nOperations is checking.') {
    const id=randomUUID();
    await db.admin.query(`INSERT INTO rounds.issue_decisions(id,tenant_id,issue_id,decision_kind,instruction,decided_by,decided_at,supersedes_id,customer_agreement_reference)
      VALUES($1,$2,$3,$4,$5::jsonb,$6,'2026-09-09T01:00:00Z',$7,'PRIVATE-CONSENT')`,
    [id,s.ids.tenant,s.issue,action,JSON.stringify({action,instructions,quantities:[],customer_agreement_reference:'PRIVATE-CONSENT'}),s.ids.actor,supersedes]);
    await db.admin.query(`UPDATE rounds.issues SET state='decided',version=version+1 WHERE id=$1`,[s.issue]);
    return id;
  }
  await t.test('open is reported, not replied/ready; repeat reads are pure and pooled scope clears',async()=>{
    const s=await setup(),before=await counts(),b=await body(s),d=b.data;
    assert.deepEqual(d,{view:'pickup_issue',principal_id:s.ids.actor,tenant_id:s.ids.tenant,city_id:s.ids.city,round_id:s.ids.round,
      assignment_id:s.ids.assignment,assignment_version:1,observation_id:s.observation,issue_id:s.issue,issue_version:1,state:'open',departure_gate:'blocked',
      orders:[{delivery_id:s.ids.delivery,readiness:'held',preparation_state:'ready',outcome:'open'}],decisions:[]});
    const r=await read(s);assert.equal(r.headers.get('cache-control'),'no-store');assert.equal(r.headers.get('x-content-type-options'),'nosniff');
    assert.deepEqual(await counts(),before);
    assert(!JSON.stringify(b).includes('Private original report'));
    const c=await db.pool.connect();try{assert.equal((await c.query(`SELECT current_setting('rounds.tenant_id',true) AS value`)).rows[0].value??'','');}finally{c.release();}
  });
  await t.test('Round-only waiting invents no selected order or receipt',async()=>{
    const s=await setup(true); const b=await body(s); assert.deepEqual(b.data.orders,[]);assert.deepEqual(b.data.decisions,[]);
  });
  await t.test('actual instruction is separate from a held order; sensitive consent/actor/private data omitted',async()=>{
    const s=await setup(),id=await decision(s),before=await counts(),b=await body(s);
    assert.deepEqual(b.data.decisions,[{id,decided_at:'2026-09-09T01:00:00.000Z',action:'wait',instructions:'Wait at the pickup site.\nOperations is checking.'}]);
    assert.equal(b.data.orders[0].readiness,'held');assert.equal(b.data.departure_gate,'blocked');assert.equal(b.data.state,'decided');
    assert(!JSON.stringify(b).includes('PRIVATE-CONSENT'));assert.deepEqual(await counts(),before);
  });
  await t.test('latest instruction follows explicit supersession, not equal timestamps or UUID sort',async()=>{
    const s=await setup(),first=await decision(s),last=await decision(s,'escalate',first,'Supervisor will contact you.');
    assert.equal((await body(s)).data.decisions[0].id,last);
  });
  await t.test('self-cycle and cross-issue predecessor are not valid decision chains',async()=>{
    for(const kind of ['self','foreign']) {
      const s=await setup();await decision(s);
      const id=randomUUID(); let predecessor=id;
      if(kind==='foreign'){
        const other=randomUUID();predecessor=randomUUID();
        await db.admin.query(`INSERT INTO rounds.issues(id,tenant_id,round_id,driver_id,issue_type,reason_code,state,reported_at,reported_by)
          SELECT $2,tenant_id,round_id,driver_id,issue_type,reason_code,'decided',reported_at,reported_by FROM rounds.issues WHERE id=$1`,[s.issue,other]);
        await db.admin.query(`INSERT INTO rounds.issue_decisions(id,tenant_id,issue_id,decision_kind,instruction,decided_by,decided_at)
          VALUES($1,$2,$3,'wait','{"action":"wait","instructions":"Other issue."}'::jsonb,$4,now())`,[predecessor,s.ids.tenant,other,s.ids.actor]);
      }
      await db.admin.query(`INSERT INTO rounds.issue_decisions(id,tenant_id,issue_id,decision_kind,instruction,decided_by,decided_at,supersedes_id)
        VALUES($1,$2,$3,'wait','{"action":"wait","instructions":"Do not guess."}'::jsonb,$4,now(),$5)`,
      [id,s.ids.tenant,s.issue,s.ids.actor,predecessor]);
      assert.equal((await read(s)).status,422);
    }
  });
  for(const [name,change] of [
    ['missing issue',(s:Scenario)=>{s.params.set('issue_id',randomUUID());}],
    ['wrong tenant',(s:Scenario)=>{s.params.set('tenant_id',randomUUID());}],
    ['wrong city',(s:Scenario)=>{s.params.set('city_id',randomUUID());}],
    ['wrong Round',(s:Scenario)=>{s.params.set('entity_id',randomUUID());}],
    ['assignment revision',(s:Scenario)=>db.admin.query('UPDATE rounds.assignments SET version=2 WHERE id=$1',[s.ids.assignment])],
    ['withdrawn assignment',(s:Scenario)=>db.admin.query("UPDATE rounds.assignments SET state='withdrawn' WHERE id=$1",[s.ids.assignment])],
    ['city revoked',(s:Scenario)=>db.admin.query('UPDATE rounds.city_grants SET archived_at=now() WHERE tenant_id=$1',[s.ids.tenant])],
    ['relationship revoked',(s:Scenario)=>db.admin.query('UPDATE rounds.driver_relationships SET archived_at=now() WHERE tenant_id=$1',[s.ids.tenant])],
    ['device revoked',(s:Scenario)=>db.admin.query('UPDATE rounds.driver_devices SET revoked_at=now() WHERE id=$1',[s.device.device_id])],
  ] as const){
    await t.test('denies '+name,async()=>{const s=await setup();await change(s);const before=await counts(),r=await read(s);assert([401,403].includes(r.status));assert(!(await r.json()).data);assert.deepEqual(await counts(),before);});
  }
  await t.test('other enrolled driver cannot read the issue even with its exact IDs',async()=>{
    const owner=await setup(),other=await setup();owner.headers=other.headers;assert.equal((await read(owner)).status,403);
  });
  await t.test('legacy issue without original observation is not adopted',async()=>{
    const s=await setup(), id=randomUUID();
    await db.admin.query(`INSERT INTO rounds.issues(id,tenant_id,round_id,driver_id,issue_type,reason_code,state,reported_at,reported_by)
      SELECT $2,tenant_id,round_id,driver_id,issue_type,reason_code,state,reported_at,reported_by FROM rounds.issues WHERE id=$1`,[s.issue,id]);
    s.params.set('issue_id',id); assert.equal((await read(s)).status,403);
  });
  for(const malformed of ['fork','two roots','state mismatch','missing decision','partial pickup','blank instruction','kind mismatch','oversize'] as const){
    await t.test('fails closed for '+malformed,async()=>{
      const s=await setup();
      if(malformed==='missing decision')await db.admin.query("UPDATE rounds.issues SET state='decided' WHERE id=$1",[s.issue]);
      else {
        const first=await decision(s,malformed==='partial pickup'?'partial_pickup':'wait',null,malformed==='blank instruction'?' ':malformed==='oversize'?'x'.repeat(4001):'Wait here.');
        if(malformed==='fork'){await decision(s,'wait',first);await decision(s,'escalate',first);}
        if(malformed==='two roots')await decision(s);
        if(malformed==='state mismatch')await db.admin.query("UPDATE rounds.issues SET state='open' WHERE id=$1",[s.issue]);
        if(malformed==='kind mismatch')await decision(s,'unknown',first);
      }
      const before=await counts(),r=await read(s);assert([403,422].includes(r.status),String(r.status));assert(!(await r.json()).data);assert.deepEqual(await counts(),before);
    });
  }
  await t.test('view selector and issue filter stay exact; wrong origin/method denied',async()=>{
    const s=await setup();s.params.append('issue_id',s.issue);assert.equal((await read(s)).status,400);
    s.params.delete('issue_id');assert.equal((await read(s)).status,400);
    s.params.set('issue_id',s.issue);s.params.set('view','pickup');assert.equal((await read(s)).status,400);
    s.params.set('view','pickup_issue');
    assert.equal((await get(new Request('http://rounds.internal'+driverRoundPath+'?'+s.params,{headers:{...s.headers,origin:'https://foreign.invalid'}}))).status,403);
    assert.equal((await get(new Request('http://rounds.internal'+driverRoundPath+'?'+s.params,{headers:s.headers,method:'POST'}))).status,405);
  });
});
