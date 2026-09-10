import type {PoolClient} from 'pg';
import type {Wire_OperationsDeliveryBoardQueryResult} from '../../../../packages/contracts/src/v23/pickup-wire.js';
import {CommandRejection,type CommandAuthority} from './transaction-runner.js';

type Delivery=Wire_OperationsDeliveryBoardQueryResult['data']['deliveries'][number];
export type NowEntry=NonNullable<Wire_OperationsDeliveryBoardQueryResult['data']['now']>['entries'][number];
export type OperationalFacts={issue:boolean;unit:{state:string;collected_at:string|null}|null;attempt:string|null;assignment:string|null};

/** ADR-Q07 is a queue classification, never a mutation predicate. Raw physical
 * state remains authoritative; release, readiness and custody are not merged. */
export function classifyDeliveryNow(d:Delivery,f:OperationalFacts):NowEntry {
  const entry=(bucket:NowEntry['bucket'],reason:NowEntry['reason']):NowEntry=>({delivery_id:d.id,bucket,reason});
  if(f.issue)return entry('action','issue');
  if(d.evidence_state==='disputed')return entry('action','evidence_disputed');
  if(['unresolved','partially_delivered'].includes(d.outcome))return entry('action','unresolved');
  if(d.outcome!=='open')return entry('done',d.outcome as 'delivered'|'returned'|'cancelled'|'rescheduled');
  if(d.planning?.stop_state==='failed'||f.attempt==='failed')return entry('action','execution_failed');
  if(f.assignment==='cannot_comply')return entry('action','assignment_declined');
  if(f.unit?.state==='collected'){
    if(!f.unit.collected_at||!Number.isFinite(Date.parse(f.unit.collected_at)))throw new CommandRejection('SOURCE_STALE');
    return entry('road',f.attempt==='handed_over'?'handed_over':'collected');
  }
  if(d.readiness==='review_needed')return entry('action','review_needed');
  if(d.readiness==='held')return entry('action','held');
  const gate=d.planning?.departure_gate;
  if(gate&&gate!=='ready')return entry('action',gate);
  if(d.readiness==='draft'||!f.unit||f.unit.state!=='open'||!d.destination)return entry('planned','scheduled');
  if(d.preparation_state!=='ready')return entry('action',d.preparation_state==='blocked'?'blocked':'awaiting_preparation');
  return entry('ready',d.planning?'ready_for_pickup':'ready_to_assign');
}

/** Read within the caller's restricted repeatable-read transaction. Only finite
 * reasons leave this function, not issue details or driver/assignment identities. */
export async function projectDeliveryNow(client:PoolClient,auth:CommandAuthority,deliveries:Delivery[]):Promise<NowEntry[]> {
  if(!deliveries.length)return [];
  const rows=(await client.query(`SELECT d.id,
      EXISTS(SELECT 1 FROM rounds.issues i WHERE i.tenant_id=d.tenant_id AND i.archived_at IS NULL
        AND i.state IN ('open','investigating','decided') AND
        (i.delivery_id=d.id OR (i.delivery_id IS NULL AND i.round_id=p.round_id))) AS issue,
      (SELECT jsonb_agg(x) FROM (SELECT u.state,u.collected_at FROM rounds.fulfillment_units u
        JOIN rounds.manifests m ON m.tenant_id=u.tenant_id AND m.id=u.manifest_id AND m.delivery_id=d.id AND m.archived_at IS NULL
        WHERE u.tenant_id=d.tenant_id AND u.delivery_id=d.id AND u.manifest_id=d.current_manifest_id AND u.archived_at IS NULL LIMIT 2) x) AS units,
      (SELECT jsonb_agg(x) FROM (SELECT a.state FROM rounds.delivery_attempts a
        JOIN rounds.fulfillment_units u ON u.tenant_id=a.tenant_id AND u.id=a.fulfillment_unit_id AND u.delivery_id=d.id
          AND u.manifest_id=d.current_manifest_id AND u.archived_at IS NULL
        WHERE a.tenant_id=d.tenant_id AND a.delivery_id=d.id AND a.stop_id=p.stop_id AND a.archived_at IS NULL
          AND a.state<>'cancelled' ORDER BY a.attempt_number DESC LIMIT 1) x) AS attempts,
      (SELECT jsonb_agg(x) FROM (SELECT a.state FROM rounds.assignments a
        WHERE a.tenant_id=d.tenant_id AND a.round_id=p.round_id AND a.archived_at IS NULL
          AND a.state IN ('issued','received','acknowledged','cannot_comply') LIMIT 2) x) AS assignments
    FROM rounds.deliveries d
    LEFT JOIN jsonb_to_recordset($4::jsonb) AS p(delivery_id uuid,round_id uuid,stop_id uuid) ON p.delivery_id=d.id
    WHERE d.tenant_id=$1 AND d.city_id=$2 AND d.id=ANY($3::uuid[]) AND d.archived_at IS NULL`,
    [auth.tenantId,auth.cityId,deliveries.map(d=>d.id),JSON.stringify(deliveries.map(d=>({delivery_id:d.id,round_id:d.planning?.round_id??null,stop_id:d.planning?.stop_id??null})))])).rows;
  const facts=new Map(rows.map(r=>[r.id,r]));
  return deliveries.map(d=>{
    const f=facts.get(d.id);if(!f||f.units?.length>1||f.assignments?.length>1)throw new CommandRejection('SOURCE_STALE');
    return classifyDeliveryNow(d,{issue:f.issue,unit:f.units?.[0]??null,attempt:f.attempts?.[0]?.state??null,assignment:f.assignments?.[0]?.state??null});
  });
}
