import { randomUUID } from 'node:crypto';
import type { PoolClient } from 'pg';
import type { Wire_ResolveIssueRequest, Wire_ResolveIssueResult, Wire_Event_issue_decided } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { canonicalCommandJson } from './command-identity.js';
import { currentIssueDecision } from './issue-decision-chain.js';
import { validateResolveIssueRequest, validateResolveIssueResult, validateResolveIssueEvent } from './pickup-validation.js';
import { assertExpectedVersions, CommandRejection, type CommandAuthority, type CommandWork, type ReceiptJobScope } from './transaction-runner.js';

export const resolveIssuePath='/v1/commands/ResolveIssue';
export async function authorizeIssueCity(client:PoolClient,auth:CommandAuthority):Promise<void>{
  const rows=await client.query(`SELECT m.id FROM rounds.memberships m
    JOIN rounds.city_grants g ON g.tenant_id=m.tenant_id AND g.membership_id=m.id
    JOIN rounds.cities c ON c.tenant_id=g.tenant_id AND c.id=g.city_id
    JOIN rounds.tenants t ON t.id=m.tenant_id
    WHERE m.tenant_id=$1 AND m.principal_id=$2 AND m.status='active' AND m.archived_at IS NULL
      AND g.city_id=$3 AND g.archived_at IS NULL AND 'issues.decide'=ANY(g.capabilities)
      AND c.enabled AND c.archived_at IS NULL AND t.status='active' AND t.archived_at IS NULL
    FOR SHARE OF m,g,c`,[auth.tenantId,auth.principalId,auth.cityId]);
  if(!rows.rowCount)throw new CommandRejection('NOT_AUTHORIZED');
}
export async function authorizeIssueJob(client:PoolClient,auth:CommandAuthority,job:ReceiptJobScope):Promise<void>{
  const rows=await client.query(`SELECT a.id FROM rounds.assignments a JOIN rounds.rounds r
    ON r.tenant_id=a.tenant_id AND r.id=a.round_id WHERE a.tenant_id=$1 AND r.city_id=$2 AND a.id=$3 AND r.id=$4`,
  [auth.tenantId,auth.cityId,job.assignmentId,job.roundId]);
  if(rows.rowCount!==1)throw new CommandRejection('NOT_AUTHORIZED');
}
type Scope={round_id:string;assignment_id:string;assignment_version:string;delivery_id:string|null;manifest_id:string|null;actor_id:string;driver_id:string};
export async function originalScope(client:PoolClient,auth:CommandAuthority,issue:string):Promise<Scope>{
  const rows=await client.query<Scope>(`SELECT o.round_id,o.assignment_id,o.assignment_version,o.delivery_id,o.manifest_id,o.actor_id,i.driver_id
    FROM rounds.issue_report_observations o JOIN rounds.issues i ON i.tenant_id=o.tenant_id AND i.id=o.issue_id
    JOIN rounds.assignments a ON a.tenant_id=o.tenant_id AND a.id=o.assignment_id AND a.round_id=o.round_id
    JOIN rounds.rounds r ON r.tenant_id=o.tenant_id AND r.id=o.round_id AND r.city_id=o.city_id
    JOIN rounds.drivers d ON d.id=a.driver_id AND d.principal_id=o.actor_id AND d.id=i.driver_id
    WHERE o.tenant_id=$1 AND o.city_id=$2 AND o.issue_id=$3 AND i.round_id=o.round_id
      AND i.reported_by=o.actor_id AND i.delivery_id IS NOT DISTINCT FROM o.delivery_id
      AND i.trip_id IS NULL AND i.attempt_id IS NULL AND i.issue_type IN ('package','pickup_wait')`,[auth.tenantId,auth.cityId,issue]);
  if(rows.rowCount!==1)throw new CommandRejection('NOT_AUTHORIZED');
  return rows.rows[0]!;
}

/** Shared predicates for the snapshot's allowed actions and the locked command.
 * Snapshot checks are informational; mutation always rechecks with locks. */
export async function requirePickupDecisionJob(client:PoolClient,authority:CommandAuthority,scope:Scope,lock:boolean):Promise<void>{
  const tenant=authority.tenantId!,update=lock?' FOR UPDATE':'',share=lock?' FOR SHARE':'';
  if(scope.delivery_id){
    const delivery=await client.query(`SELECT id FROM rounds.deliveries WHERE tenant_id=$1 AND city_id=$2 AND id=$3
      AND current_manifest_id=$4 AND outcome='open' AND archived_at IS NULL${update}`,[tenant,authority.cityId,scope.delivery_id,scope.manifest_id]);
    if(delivery.rowCount!==1)throw new CommandRejection('NOT_AUTHORIZED');
    const unit=await client.query(`SELECT id FROM rounds.fulfillment_units WHERE tenant_id=$1 AND delivery_id=$2
      AND manifest_id=$3 AND state='open' AND collected_at IS NULL AND archived_at IS NULL ORDER BY id${update}`,[tenant,scope.delivery_id,scope.manifest_id]);
    if(unit.rowCount!==1)throw new CommandRejection('NOT_AUTHORIZED');
  }
  const round=await client.query(`SELECT id FROM rounds.rounds WHERE tenant_id=$1 AND id=$2 AND city_id=$3
    AND driver_id=$4 AND state='released' AND fulfillment_kind='team' AND archived_at IS NULL${update}`,[tenant,scope.round_id,authority.cityId,scope.driver_id]);
  const assignment=await client.query(`SELECT id FROM rounds.assignments WHERE tenant_id=$1 AND id=$2 AND round_id=$3
    AND driver_id=$4 AND version=$5 AND state='acknowledged' AND archived_at IS NULL${share}`,[tenant,scope.assignment_id,scope.round_id,scope.driver_id,scope.assignment_version]);
  if(round.rowCount!==1||assignment.rowCount!==1)throw new CommandRejection('NOT_AUTHORIZED');
  const stops=(await client.query(`SELECT kind,state,delivery_id FROM rounds.stops WHERE tenant_id=$1 AND round_id=$2
    AND archived_at IS NULL AND state<>'cancelled' ORDER BY id${share}`,[tenant,scope.round_id])).rows;
  const pickups=stops.filter(s=>s.kind==='pickup');
  if(pickups.length!==1||!['released','en_route','arrived'].includes(pickups[0]!.state)||
    !stops.some(s=>s.kind==='dropoff')||stops.some(s=>!['pickup','dropoff'].includes(s.kind)||s.kind==='dropoff'&&s.state!=='released')||
    scope.delivery_id&&!stops.some(s=>s.kind==='dropoff'&&s.delivery_id===scope.delivery_id))throw new CommandRejection('NOT_AUTHORIZED');
  const relationship=await client.query(`SELECT id FROM rounds.driver_relationships WHERE tenant_id=$1 AND driver_id=$2
    AND relationship_kind='team' AND status='active' AND archived_at IS NULL ORDER BY id${share}`,[tenant,scope.driver_id]);
  if(!relationship.rowCount)throw new CommandRejection('NOT_AUTHORIZED');
  const driver=await client.query(`SELECT id FROM rounds.drivers WHERE id=$1 AND principal_id=$2 AND archived_at IS NULL`,[scope.driver_id,scope.actor_id]);
  if(driver.rowCount!==1)throw new CommandRejection('NOT_AUTHORIZED');
}

/** ADR-T08 wait/escalate only. Never reuses Driver authority or moves goods. */
export function resolvePickupIssueWork(authority:CommandAuthority,input:Wire_ResolveIssueRequest):CommandWork{
  authority=Object.freeze({...authority});
  let request:Wire_ResolveIssueRequest;
  try{request=JSON.parse(canonicalCommandJson(input));}catch{throw new CommandRejection('VALIDATION_FAILED');}
  validateResolveIssueRequest(request);
  return {commandType:'ResolveIssue',authority,request,validate:validateResolveIssueRequest,validateResult:validateResolveIssueResult,
    authorize:authorizeIssueCity,
    resolveReceiptScope:async(client,auth)=>{const s=await originalScope(client,auth,request.payload.issue_id);return {roundId:s.round_id,assignmentId:s.assignment_id};},
    execute:async(client,frozen,trace,job)=>{
      const r=frozen as Wire_ResolveIssueRequest,p=r.payload,decision=p.decision,tenant=authority.tenantId!;
      const scope=await originalScope(client,authority,p.issue_id);
      if(!job||job.roundId!==scope.round_id||job.assignmentId!==scope.assignment_id)throw new CommandRejection('NOT_AUTHORIZED');
      // Unsupported actions reject only after the current actor and issue scope
      // were authorized. In particular, owner privileges cannot enable splitting.
      if(!['wait','escalate'].includes(decision.action))throw new CommandRejection('FEATURE_NOT_ENABLED');
      if(decision.quantities.length||decision.customer_agreement_reference!=null||decision.freelance_change_id!=null)throw new CommandRejection('VALIDATION_FAILED');
      await requirePickupDecisionJob(client,authority,scope,true);
      const issue=(await client.query(`SELECT version,state FROM rounds.issues WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE`,[tenant,p.issue_id])).rows[0];
      if(!issue||issue.state==='resolved')throw new CommandRejection('NOT_AUTHORIZED');
      if(canonicalCommandJson(await originalScope(client,authority,p.issue_id))!==canonicalCommandJson(scope))throw new CommandRejection('NOT_AUTHORIZED');
      const version=Number(issue.version);
      if(!Number.isSafeInteger(version)||version<1||version>=Number.MAX_SAFE_INTEGER)throw new CommandRejection('SOURCE_STALE');
      assertExpectedVersions(r.expected_versions,[{aggregate_type:'issues',id:p.issue_id,version}]);
      const prior=(await client.query(`SELECT id,supersedes_id FROM rounds.issue_decisions WHERE tenant_id=$1 AND issue_id=$2 ORDER BY id LIMIT 201`,[tenant,p.issue_id])).rows;
      const tip=currentIssueDecision(prior,issue.state);
      if(prior.length>=200)throw new CommandRejection('FEATURE_NOT_ENABLED');
      const at=(await client.query<{at:Date}>('SELECT clock_timestamp() AS at')).rows[0]!.at.toISOString();
      const id=randomUUID(),subject={aggregate_type:'issues' as const,id:p.issue_id,version:version+1};
      const created={aggregate_type:'issue_decisions' as const,id,version:1};
      await client.query(`INSERT INTO rounds.issue_decisions(id,tenant_id,issue_id,decision_kind,instruction,reason,decided_by,decided_at,supersedes_id)
        VALUES($1,$2,$3,$4,$5::jsonb,$6,$7,$8,$9)`,[id,tenant,p.issue_id,decision.action,JSON.stringify(decision),p.reason,authority.principalId,at,tip?.id??null]);
      await client.query(`UPDATE rounds.issues SET state='decided',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`,[tenant,p.issue_id]);
      const event:Wire_Event_issue_decided={event_id:randomUUID(),event_type:'issue.decided',schema_version:3,tenant_id:tenant,principal_id:null,
        aggregate:subject,occurred_at:r.occurred_at,received_at:at,actor_id:authority.principalId,command_id:r.command_id,worker_run_id:null,trace_id:trace,
        payload:{subject,affected_resources:[subject,created],changes:issue.state==='decided'?[]:[{family:'issues.state',resource_id:p.issue_id,from_state:issue.state,to_state:'decided',version:subject.version}]}};
      validateResolveIssueEvent(event);
      await client.query(`INSERT INTO rounds.domain_events(id,tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
        VALUES($1,$2,'issues',$3,$4,'issue.decided',3,$5,$6,$7,$8,$9::jsonb,$10)`,[event.event_id,tenant,p.issue_id,subject.version,authority.principalId,r.command_id,r.occurred_at,at,JSON.stringify(event.payload),trace]);
      await client.query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`,[tenant,event.event_id]);
      const result:Wire_ResolveIssueResult={command_id:r.command_id,command_type:'ResolveIssue',state:'committed',current_versions:[subject],resources:[created],data:{resource:subject,state:'decided'}};
      return result;
    }};
}
