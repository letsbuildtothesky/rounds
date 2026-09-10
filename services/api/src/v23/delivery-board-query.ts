import type { PoolClient } from 'pg';
import type { Wire_OperationsDeliveryBoardQueryResult } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { validateDeliveryBoardQuery } from './pickup-validation.js';
import { CommandRejection, type CommandAuthority } from './transaction-runner.js';
import {projectDeliveryNow} from './delivery-now-projection.js';

/** ADR-Q06: board.read does not grant issue detail, decisions, messages or GPS. */
export async function authorizeDeliveryBoard(client: PoolClient, auth: CommandAuthority): Promise<void> {
  const result = await client.query(`SELECT m.id FROM rounds.memberships m
    JOIN rounds.city_grants g ON g.tenant_id=m.tenant_id AND g.membership_id=m.id
    JOIN rounds.cities c ON c.tenant_id=g.tenant_id AND c.id=g.city_id
    JOIN rounds.tenants t ON t.id=m.tenant_id
    WHERE m.tenant_id=$1 AND m.principal_id=$2 AND m.status='active' AND m.archived_at IS NULL
      AND g.city_id=$3 AND g.archived_at IS NULL AND 'board.read'=ANY(g.capabilities)
      AND c.enabled AND c.archived_at IS NULL AND t.status='active' AND t.archived_at IS NULL`,
  [auth.tenantId, auth.principalId, auth.cityId]);
  if (!result.rowCount) throw new CommandRejection('NOT_AUTHORIZED');
}

const label = (v: unknown, max=200): string|null => typeof v==='string' && v.trim() && [...v].length<=max ? v : null;
const version = (v: unknown): number => {
  const n=Number(v); if(!Number.isSafeInteger(n)||n<1) throw new CommandRejection('SOURCE_STALE'); return n;
};
const timezone = (v: unknown): string => {
  if(typeof v!=='string'||!v||v.length>100) throw new CommandRejection('SOURCE_STALE');
  try { new Intl.DateTimeFormat('en',{timeZone:v}); } catch { throw new CommandRejection('SOURCE_STALE'); } return v;
};

/** One city/date snapshot. No readiness inference, writes, implicit receipt,
 * driver location, full-fleet claim, default city or pseudo pagination. */
export async function projectDeliveryBoard(client:PoolClient,auth:CommandAuthority,date:string,includeNow=false):Promise<Wire_OperationsDeliveryBoardQueryResult> {
  const context=(await client.query(`SELECT t.name AS tenant_name,t.version AS tenant_version,
      c.name AS city_name,c.version AS city_version,c.timezone,transaction_timestamp() AS as_of
    FROM rounds.tenants t JOIN rounds.cities c ON c.tenant_id=t.id
    WHERE t.id=$1 AND c.id=$2 AND t.archived_at IS NULL AND c.archived_at IS NULL`,[auth.tenantId,auth.cityId])).rows[0];
  if(!context) throw new CommandRejection('NOT_AUTHORIZED');
  const rows=(await client.query(`SELECT d.id,d.version,d.human_reference,d.address_text,d.timezone,
      d.service_date::text,d.window_start_at,d.window_end_at,d.readiness,d.preparation_state,d.outcome,d.evidence_state,
      d.destination_version,(SELECT er.id FROM rounds.entrance_revisions er
        JOIN rounds.entrances e ON e.tenant_id=er.tenant_id AND e.id=er.entrance_id
        WHERE er.tenant_id=d.tenant_id AND er.id=d.entrance_revision_id AND e.city_id=d.city_id
          AND e.archived_at IS NULL) AS entrance_revision_id,
      d.pickup_site_id,s.name AS pickup_name,b.id AS brand_id,b.name AS brand_name,
      public.ST_Y(d.destination::public.geometry) AS latitude,public.ST_X(d.destination::public.geometry) AS longitude,
      (SELECT array_agg(c.display_name) FROM (SELECT c.display_name FROM rounds.delivery_contacts c
        WHERE c.tenant_id=d.tenant_id AND c.delivery_id=d.id AND c.role='recipient' AND c.archived_at IS NULL
        ORDER BY c.id LIMIT 2) c) AS recipients,
      (SELECT jsonb_agg(p) FROM (SELECT r.id AS round_id,r.version AS round_version,r.state AS round_state,r.departure_gate,
          st.id AS stop_id,st.version AS stop_version,st.state AS stop_state
        FROM rounds.stops st JOIN rounds.rounds r ON r.tenant_id=st.tenant_id AND r.id=st.round_id
        JOIN rounds.fulfillment_units u ON u.tenant_id=st.tenant_id AND u.id=st.fulfillment_unit_id
          AND u.delivery_id=d.id AND u.manifest_id=d.current_manifest_id AND u.archived_at IS NULL AND u.state<>'cancelled'
        WHERE st.tenant_id=d.tenant_id AND st.delivery_id=d.id AND st.kind='dropoff' AND st.archived_at IS NULL
          AND st.state<>'cancelled' AND r.city_id=d.city_id AND r.service_date=d.service_date AND r.archived_at IS NULL
          AND r.state NOT IN ('completed','cancelled') ORDER BY r.id,st.id LIMIT 2) p) AS planning
    FROM rounds.deliveries d
    LEFT JOIN rounds.sites s ON s.tenant_id=d.tenant_id AND s.city_id=d.city_id AND s.id=d.pickup_site_id AND s.archived_at IS NULL
    LEFT JOIN rounds.brands b ON b.tenant_id=d.tenant_id AND b.id=d.brand_id AND b.archived_at IS NULL
    WHERE d.tenant_id=$1 AND d.city_id=$2 AND d.service_date=$3 AND d.archived_at IS NULL
    ORDER BY d.window_start_at,d.id LIMIT 201`,[auth.tenantId,auth.cityId,date])).rows;
  if(rows.length>200) throw new CommandRejection('FEATURE_NOT_ENABLED');
  const deliveries:Wire_OperationsDeliveryBoardQueryResult['data']['deliveries']=rows.map(d=>{
    if(d.planning?.length>1) throw new CommandRejection('SOURCE_STALE');
    const p=d.planning?.[0];
    if(d.window_end_at<=d.window_start_at) throw new CommandRejection('SOURCE_STALE');
    return {id:d.id,version:version(d.version),reference:label(d.human_reference),recipient_name:d.recipients?.length===1?label(d.recipients[0]):null,
      address_text:label(d.address_text,2000),brand:d.brand_id?{id:d.brand_id,name:label(d.brand_name)}:null,
      pickup_site:{id:d.pickup_site_id,name:label(d.pickup_name)},
      window:{starts_at:d.window_start_at.toISOString(),ends_at:d.window_end_at.toISOString(),timezone:timezone(d.timezone),service_date:d.service_date},
      readiness:d.readiness,preparation_state:d.preparation_state,outcome:d.outcome,evidence_state:d.evidence_state,
      destination_version:version(d.destination_version),destination:d.latitude==null&&d.longitude==null?null:
        {latitude:d.latitude,longitude:d.longitude,source:'delivery_destination' as const},entrance_revision_id:d.entrance_revision_id,
      planning:p?{...p,round_version:version(p.round_version),stop_version:version(p.stop_version)}:null};
  });
  const result:Wire_OperationsDeliveryBoardQueryResult={as_of:context.as_of.toISOString(),next_cursor:null,data:{view:'delivery_board',
    principal_id:auth.principalId,tenant_id:auth.tenantId!,city_id:auth.cityId!,service_date:date,
    workspace:{name:label(context.tenant_name),version:version(context.tenant_version)},
    city:{name:label(context.city_name),version:version(context.city_version),timezone:timezone(context.timezone)},
    delivery_count:deliveries.length,deliveries}};
  if(includeNow){
    const parts=new Intl.DateTimeFormat('en',{timeZone:result.data.city.timezone,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(context.as_of);
    const get=(type:string)=>parts.find(p=>p.type===type)!.value;
    result.data.now={current_service_date:`${get('year')}-${get('month')}-${get('day')}`,entries:await projectDeliveryNow(client,auth,deliveries)};
  }
  try { validateDeliveryBoardQuery(result); } catch { throw new CommandRejection('SOURCE_STALE'); }
  if(Buffer.byteLength(JSON.stringify(result))>1024*1024) throw new CommandRejection('FEATURE_NOT_ENABLED');
  return result;
}
