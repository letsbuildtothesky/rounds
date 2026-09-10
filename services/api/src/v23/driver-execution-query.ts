import { createHash, randomUUID } from 'node:crypto';
import type { Pool, PoolClient } from 'pg';
import type { Wire_DriverRoundExecutionQueryResult, Wire_DriverRoundPickupQueryResult, Wire_DriverExecutionContext, Wire_ProofPolicy } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { authorizeDeviceSession, requiredBearer, type BearerVerifier } from './authentication.js';
import { deviceSessions, type DeviceSession } from './device-session.js';
import { authorizeTeamPickupCity } from './pickup-authorization.js';
import { beginRestrictedTransaction } from './restricted-transaction.js';
import { CommandRejection } from './transaction-runner.js';
import { canonicalCommandJson } from './command-identity.js';
import { validateExecutionQuery, validatePickupDisplayQuery, validateExecutionProofPolicy } from './pickup-validation.js';
import { pickupHttpError } from './pickup-http.js';
import { projectPickupIssue } from './pickup-issue-query.js';

export const driverRoundPath = '/v1/queries/DriverRound';
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const boundedVersion = (value: unknown): number => {
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n < 1) throw new Error('Invalid stored version');
  return n;
};

/** Coherent R1 own-team execution snapshot, not the complete Driver UI query.
 * Live permission rows are share-locked; domain reads use one MVCC snapshot.
 * No command receipts, physical facts, commercial agreement or demo defaults.
 */
async function project(client: PoolClient, session: DeviceSession, tenant: string, city: string, roundId: string, now: number): Promise<Wire_DriverRoundExecutionQueryResult> {
  const auth = {principalId: session.principalId, tenantId: tenant, cityId: city};
  await authorizeDeviceSession(client, auth, session, now);
  await authorizeTeamPickupCity(client, auth);
  const jobs = await client.query(`SELECT r.id,r.version,r.pickup_site_id,a.id AS assignment_id,a.version AS assignment_version,a.driver_id
    FROM rounds.rounds r JOIN rounds.assignments a ON a.tenant_id=r.tenant_id AND a.round_id=r.id
    JOIN rounds.drivers d ON d.id=a.driver_id
    WHERE r.tenant_id=$1 AND r.city_id=$2 AND r.id=$3 AND d.principal_id=$4
      AND r.driver_id=a.driver_id AND r.fulfillment_kind='team' AND r.state IN ('released','active')
      AND a.state='acknowledged' AND r.archived_at IS NULL AND a.archived_at IS NULL AND d.archived_at IS NULL
    ORDER BY a.id LIMIT 2`, [tenant,city,roundId,session.principalId]);
  if (jobs.rows.length !== 1) throw new CommandRejection('NOT_AUTHORIZED');
  const job = jobs.rows[0]!;
  const stops = (await client.query(`SELECT id,delivery_id,fulfillment_unit_id,kind,sequence,version FROM rounds.stops
    WHERE tenant_id=$1 AND round_id=$2 AND archived_at IS NULL AND state<>'cancelled' ORDER BY sequence,id LIMIT 1001`, [tenant,roundId])).rows;
  const pickups = stops.filter(s=>s.kind==='pickup'), drops = stops.filter(s=>s.kind==='dropoff');
  if (stops.length > 1000 || pickups.length!==1 || !drops.length || stops.some(s=>!['pickup','dropoff'].includes(s.kind)) ||
      new Set(drops.map(s=>s.delivery_id)).size!==drops.length || new Set(drops.map(s=>s.fulfillment_unit_id)).size!==drops.length) throw new CommandRejection('FEATURE_NOT_ENABLED');
  const orders = (await client.query(`SELECT d.id AS delivery_id,d.version AS delivery_version,d.outcome,d.preparation_state,d.proof_policy_id,u.id AS unit_id,u.version AS unit_version,
      m.id AS manifest_id,m.version AS manifest_version,p.payload AS proof_policy
    FROM rounds.deliveries d JOIN rounds.fulfillment_units u ON u.tenant_id=d.tenant_id AND u.delivery_id=d.id AND u.manifest_id=d.current_manifest_id
    JOIN rounds.manifests m ON m.tenant_id=u.tenant_id AND m.id=u.manifest_id AND m.delivery_id=d.id
    JOIN rounds.policy_versions p ON p.tenant_id=d.tenant_id AND p.id=d.proof_policy_id AND p.policy_kind='proof' AND p.schema_version=1 AND p.effective_at<=now()
    WHERE d.tenant_id=$1 AND d.city_id=$2 AND d.id=ANY($3::uuid[]) AND u.id=ANY($4::uuid[]) AND d.pickup_site_id=$5
      AND d.archived_at IS NULL AND u.archived_at IS NULL AND m.archived_at IS NULL ORDER BY u.id LIMIT 1001`,
    [tenant,city,drops.map(s=>s.delivery_id),drops.map(s=>s.fulfillment_unit_id),job.pickup_site_id])).rows;
  if (orders.length !== drops.length) throw new CommandRejection('POLICY_NOT_CONFIGURED');
  if (orders.some(o=>!drops.some(s=>s.delivery_id===o.delivery_id && s.fulfillment_unit_id===o.unit_id))) throw new CommandRejection('MANIFEST_MISMATCH');
  // Refuse deferred inbound work; don't invent a receiving event to unlock it.
  const inbound = await client.query('SELECT id FROM rounds.inbound_dependencies WHERE tenant_id=$1 AND delivery_id=ANY($2::uuid[]) LIMIT 1',[tenant,orders.map(o=>o.delivery_id)]);
  if (inbound.rowCount) throw new CommandRejection('FEATURE_NOT_ENABLED');
  const lines = (await client.query(`SELECT l.id,l.manifest_id,l.quantity,ul.unit_id,ul.allocated_quantity
    FROM rounds.manifest_lines l LEFT JOIN rounds.fulfillment_unit_lines ul ON ul.tenant_id=l.tenant_id AND ul.line_id=l.id
      AND ul.unit_id=ANY($3::uuid[]) AND ul.archived_at IS NULL
    WHERE l.tenant_id=$1 AND l.manifest_id=ANY($2::uuid[]) AND l.archived_at IS NULL ORDER BY l.id LIMIT 1001`,[tenant,orders.map(o=>o.manifest_id),orders.map(o=>o.unit_id)])).rows;
  if (lines.length>1000) throw new CommandRejection('FEATURE_NOT_ENABLED');
  if(lines.some(l=>!l.unit_id))throw new CommandRejection('MANIFEST_MISMATCH');
  const claims=(await client.query(`SELECT delivery_id,fulfillment_unit_id FROM rounds.active_delivery_claims
    WHERE tenant_id=$1 AND round_id=$2 AND claim_kind='team' AND archived_at IS NULL
      AND (expires_at IS NULL OR expires_at>clock_timestamp()) ORDER BY id LIMIT 1001`,[tenant,roundId])).rows;
  // Completed orders remain in the immutable assignment scope, but their
  // active claims were retired atomically with delivery completion.
  const unfinished=orders.filter(o=>o.outcome!=='delivered');
  if(claims.length!==unfinished.length||unfinished.some(o=>!claims.some(c=>c.delivery_id===o.delivery_id&&c.fulfillment_unit_id===o.unit_id)))throw new CommandRejection('NOT_AUTHORIZED');
  const versions: Wire_DriverExecutionContext['expected_versions'] = [];
  const version = (aggregate_type: typeof versions[number]['aggregate_type'], id: string, v: unknown) => versions.push({aggregate_type,id,version:boundedVersion(v)});
  version('assignments',job.assignment_id,job.assignment_version); version('rounds',roundId,job.version);
  for (const stop of stops) version('stops',stop.id,stop.version);
  const proofPolicies: Wire_DriverExecutionContext['proof_policies'] = [];
  const projectedOrders = orders.map(o=>{
    validateExecutionProofPolicy(o.proof_policy);
    version('manifests',o.manifest_id,o.manifest_version);version('fulfillment_units',o.unit_id,o.unit_version);version('deliveries',o.delivery_id,o.delivery_version);
    proofPolicies.push({fulfillment_unit_id:o.unit_id,policy_version_id:o.proof_policy_id,policy:o.proof_policy as Wire_ProofPolicy});
    const quantities = lines.filter(l=>l.unit_id===o.unit_id && l.manifest_id===o.manifest_id).map(l=>{
      const quantity=Number(l.quantity);
      if (!Number.isFinite(quantity) || quantity<=0 || quantity!==Number(l.allocated_quantity) || !Number.isSafeInteger(Math.round(quantity*10000))) throw new CommandRejection('MANIFEST_MISMATCH');
      return {line_id:l.id as string,quantity};
    });
    if (!quantities.length) throw new CommandRejection('MANIFEST_MISMATCH');
    return {delivery_id:o.delivery_id as string,fulfillment_unit_id:o.unit_id as string,manifest_id:o.manifest_id as string,
      dropoff_stop_id:drops.find(s=>s.fulfillment_unit_id===o.unit_id)!.id as string,quantities,preparation_state:o.preparation_state};
  });
  if (versions.length>1000) throw new CommandRejection('FEATURE_NOT_ENABLED');
  const stopUnits = stops.map(s=>({stop_id:s.id as string,fulfillment_unit_ids:s.kind==='pickup'?orders.map(o=>o.unit_id as string):[s.fulfillment_unit_id as string]}));
  const scope = {principal_id:session.principalId,tenant_id:tenant,city_id:city,round_id:roundId,
    assignment_id:job.assignment_id as string,assignment_version:boundedVersion(job.assignment_version),stop_units:stopUnits,proof_policies:proofPolicies};
  // Team acknowledgement digest, NOT a freelance accepted-fare scope. Exclude
  // mutable state/version counters so a pickup doesn't fabricate reassignment.
  const accepted_scope_hash = createHash('sha256').update(canonicalCommandJson({format:'team_execution_v1',...scope,
    orders:projectedOrders.map(({preparation_state,...o})=>o)})).digest('hex');
  const as_of = new Date(now*1000).toISOString();
  const result: Wire_DriverRoundExecutionQueryResult = {as_of,next_cursor:null,data:{view:'execution',pickup_stop_id:pickups[0]!.id,
    orders:projectedOrders,context:{...scope,accepted_scope_hash,expected_versions:versions,fetched_at:as_of}}};
  validateExecutionQuery(result);
  if (Buffer.byteLength(JSON.stringify(result))>65536) throw new CommandRejection('FEATURE_NOT_ENABLED');
  return result;
}

/** Display-only extension. Run AFTER execution authorization, on its same pinned
 * transaction. Names and package labels must never enter command authority. */
async function pickupDisplay(client: PoolClient, execution: Wire_DriverRoundExecutionQueryResult): Promise<Wire_DriverRoundPickupQueryResult> {
  const {tenant_id: tenant, city_id: city, round_id: round} = execution.data.context;
  const text = (value: unknown): string => {
    if (typeof value !== 'string' || !value.trim() || [...value].length > 200) throw new CommandRejection('SOURCE_STALE');
    return value;
  };
  const quanta = (value: unknown): number => {
    const n = Number(value), q = Math.round(n * 10000);
    if (!Number.isFinite(n) || n <= 0 || n > 1000000 || !Number.isSafeInteger(q) || q / 10000 !== n) throw new CommandRejection('MANIFEST_MISMATCH');
    return q;
  };
  const header = (await client.query(`SELECT t.name AS merchant,s.name AS site FROM rounds.rounds r
    JOIN rounds.tenants t ON t.id=r.tenant_id JOIN rounds.sites s ON s.tenant_id=r.tenant_id AND s.id=r.pickup_site_id AND s.city_id=r.city_id
    WHERE r.tenant_id=$1 AND r.city_id=$2 AND r.id=$3 AND s.archived_at IS NULL AND t.archived_at IS NULL`, [tenant,city,round])).rows;
  if (header.length !== 1) throw new CommandRejection('SOURCE_STALE');
  const original = execution.data.orders, manifests = original.map(o=>o.manifest_id), deliveries = original.map(o=>o.delivery_id);
  const orders = (await client.query(`SELECT d.id,d.human_reference,s.sequence FROM rounds.deliveries d
    JOIN rounds.stops s ON s.tenant_id=d.tenant_id AND s.delivery_id=d.id AND s.round_id=$3 AND s.kind='dropoff'
    WHERE d.tenant_id=$1 AND d.city_id=$2 AND d.id=ANY($4::uuid[]) AND d.archived_at IS NULL AND s.archived_at IS NULL AND s.state<>'cancelled'
    ORDER BY s.sequence,s.id LIMIT 1001`, [tenant,city,round,deliveries])).rows;
  const contacts = (await client.query(`SELECT delivery_id,display_name FROM rounds.delivery_contacts
    WHERE tenant_id=$1 AND delivery_id=ANY($2::uuid[]) AND role='recipient' AND archived_at IS NULL LIMIT 1001`, [tenant,deliveries])).rows;
  const lines = (await client.query(`SELECT id,manifest_id,label,quantity,unit,handling_keys FROM rounds.manifest_lines
    WHERE tenant_id=$1 AND manifest_id=ANY($2::uuid[]) AND archived_at IS NULL ORDER BY line_key,id LIMIT 1001`, [tenant,manifests])).rows;
  const packages = (await client.query(`SELECT id,manifest_id,label FROM rounds.packages
    WHERE tenant_id=$1 AND manifest_id=ANY($2::uuid[]) AND archived_at IS NULL ORDER BY package_key,id LIMIT 1001`, [tenant,manifests])).rows;
  const contents = (await client.query(`SELECT package_id,line_id,quantity FROM rounds.package_contents
    WHERE tenant_id=$1 AND package_id=ANY($2::uuid[]) AND archived_at IS NULL ORDER BY line_id LIMIT 1001`, [tenant,packages.map(p=>p.id)])).rows;
  if ([orders,contacts,lines,packages,contents].some(rows=>rows.length>1000)) throw new CommandRejection('FEATURE_NOT_ENABLED');
  if (orders.length !== original.length) throw new CommandRejection('MANIFEST_MISMATCH');
  const display = orders.map(o=>{
    const base = original.find(x=>x.delivery_id===o.id)!;
    if (!base) throw new CommandRejection('MANIFEST_MISMATCH');
    const recipient = contacts.filter(c=>c.delivery_id===o.id);
    if (recipient.length !== 1) throw new CommandRejection('SOURCE_STALE');
    const expected = new Map(base.quantities.map(q=>[q.line_id,quanta(q.quantity)]));
    const ownLines = lines.filter(l=>l.manifest_id===base.manifest_id);
    if (ownLines.length !== expected.size) throw new CommandRejection('MANIFEST_MISMATCH');
    const mappedLines = ownLines.map(l=>{
      if (quanta(l.quantity)!==expected.get(l.id)) throw new CommandRejection('MANIFEST_MISMATCH');
      if (!Array.isArray(l.handling_keys) || l.handling_keys.length>20) throw new CommandRejection('SOURCE_STALE');
      return {line_id:l.id as string,label:text(l.label),quantity:quanta(l.quantity)/10000,unit:text(l.unit),handling_keys:l.handling_keys.map(text)};
    });
    const totals = new Map<string,number>();
    const parcels = packages.filter(p=>p.manifest_id===base.manifest_id).map(p=>{
      const seen = new Set<string>();
      const items = contents.filter(c=>c.package_id===p.id).map(c=>{
        if (!expected.has(c.line_id) || seen.has(c.line_id)) throw new CommandRejection('MANIFEST_MISMATCH');
        seen.add(c.line_id);
        const q=quanta(c.quantity);totals.set(c.line_id,(totals.get(c.line_id)??0)+q);
        return {line_id:c.line_id as string,quantity:q/10000};
      });
      if (!items.length) throw new CommandRejection('MANIFEST_MISMATCH');
      return {package_id:p.id as string,label:text(p.label),contents:items};
    });
    if (parcels.length && [...expected].some(([id,q])=>totals.get(id)!==q)) throw new CommandRejection('MANIFEST_MISMATCH');
    return {delivery_id:base.delivery_id,manifest_id:base.manifest_id,reference:text(o.human_reference),recipient_name:text(recipient[0]!.display_name),stop_sequence:boundedVersion(o.sequence),lines:mappedLines,packages:parcels};
  });
  const result: Wire_DriverRoundPickupQueryResult = {as_of:execution.as_of,next_cursor:null,data:{view:'pickup',execution:execution.data,
    merchant:text(header[0]!.merchant),pickup_site_name:text(header[0]!.site),orders:display}};
  validatePickupDisplayQuery(result);
  if (Buffer.byteLength(JSON.stringify(result))>65536) throw new CommandRejection('FEATURE_NOT_ENABLED');
  return result;
}

export function createDriverExecutionHttp(options:{pool:Pool;verifyBearer:BearerVerifier;devices:ReturnType<typeof deviceSessions>;origin:string;now?:()=>number}) {
  const now=options.now??(()=>Math.floor(Date.now()/1000));
  return async(request:Request):Promise<Response>=>{
    const trace=randomUUID(),url=new URL(request.url),origin=request.headers.get('origin');
    if(origin!==null&&origin!==options.origin)return pickupHttpError('NOT_AUTHORIZED',trace);
    let response:Response;
    try {
      if(url.pathname!==driverRoundPath)throw new CommandRejection('NOT_FOUND');
      if(request.method!=='GET')return pickupHttpError('VALIDATION_FAILED',trace,405);
      const bearer=requiredBearer(request),token=request.headers.get('x-rounds-device-session');
      if(!token||token.length>2048)throw new CommandRejection('UNAUTHENTICATED');
      const subject=await options.verifyBearer(bearer),session=options.devices.verify(token,subject,now());
      const p=url.searchParams,keys=['entity_id','tenant_id','city_id','view',...(p.get('view')==='pickup_issue'?['issue_id']:[])];
      if([...p.keys()].some(k=>!keys.includes(k))||keys.some(k=>p.getAll(k).length!==1)||
        keys.filter(k=>k!=='view').some(k=>!uuid.test(p.get(k)!)))throw new CommandRejection('VALIDATION_FAILED');
      if(!['execution','pickup','pickup_issue'].includes(p.get('view')!))throw new CommandRejection('FEATURE_NOT_ENABLED');
      const client=await options.pool.connect();let destroy=false;
      try {
        await beginRestrictedTransaction(client,{principalId:session.principalId,tenantId:p.get('tenant_id')!,cityId:p.get('city_id')!},true);
        const body=await (async()=>{
          if(p.get('view')==='pickup_issue')return projectPickupIssue(client,session,p.get('tenant_id')!,p.get('city_id')!,p.get('entity_id')!,p.get('issue_id')!,now());
          const execution=await project(client,session,p.get('tenant_id')!,p.get('city_id')!,p.get('entity_id')!,now());
          return p.get('view')==='pickup'?await pickupDisplay(client,execution):execution;
        })();
        await client.query('COMMIT');
        response=Response.json(body,{headers:{'cache-control':'no-store','x-content-type-options':'nosniff','x-trace-id':trace}});
      } catch(error) {
        try {await client.query('ROLLBACK');} catch {destroy=true;}
        throw error;
      } finally {client.release(destroy);}
    } catch(error) {response=pickupHttpError(error instanceof CommandRejection?error.code:'PROVIDER_UNAVAILABLE',trace);}
    if(origin===options.origin){response.headers.set('access-control-allow-origin',origin);response.headers.set('vary','origin');}
    return response;
  };
}
