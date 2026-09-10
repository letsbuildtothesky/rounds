import { randomUUID } from 'node:crypto';
import type { PoolClient } from 'pg';
import type { Wire_ConfirmPickupRequest, Wire_ConfirmPickupResult, Wire_AttemptView, Wire_FulfillmentUnitView,
  Wire_Event_pickup_confirmed, Wire_ResourceVersion } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { checkWholeOrderPickup, type WholePickupOrder } from '../../../../packages/domain-ts/src/v23/whole-order-pickup.js';
import { lockOriginalRoundAssignment } from './assignment-fence.js';
import { canonicalCommandJson } from './command-identity.js';
import { authorizeTeamPickup } from './pickup-authorization.js';
import { validatePickupEvent, validatePickupRequest, validatePickupResult } from './pickup-validation.js';
import { assertExpectedVersions, CommandRejection, type CommandAuthority, type CommandWork } from './transaction-runner.js';

function reject(code: ConstructorParameters<typeof CommandRejection>[0]): never { throw new CommandRejection(code); }
const version = (v: string): number => {
  const n = Number(v);
  if (!Number.isSafeInteger(n) || n < 1 || n >= Number.MAX_SAFE_INTEGER) throw new Error('Unsafe stored version');
  return n;
};
const resource = (aggregate_type: Wire_ResourceVersion['aggregate_type'], id: string, v: string | number): Wire_ResourceVersion =>
  ({ aggregate_type, id, version: version(String(v)) });
type Stop = { id: string; delivery_id: string | null; fulfillment_unit_id: string | null; kind: string; state: string; sequence: number; version: string; actual_arrival_at: Date | null };
type Delivery = { id: string; city_id: string; pickup_site_id: string; current_manifest_id: string; preparation_state: WholePickupOrder['preparation']; readiness: string; outcome: string };
type Unit = { id: string; delivery_id: string; manifest_id: string; state: WholePickupOrder['unit_state']; version: string };
type Manifest = { id: string; delivery_id: string; version: string; sealed_at: Date | null };
type Line = { id: string; manifest_id: string; quantity: string };

async function routeStops(client: PoolClient, tenant: string, round: string, lock = false): Promise<Stop[]> {
  return (await client.query<Stop>(`SELECT id,delivery_id,fulfillment_unit_id,kind,state,sequence,version,actual_arrival_at FROM rounds.stops
    WHERE tenant_id=$1 AND round_id=$2 AND archived_at IS NULL AND state<>'cancelled' ORDER BY id ${lock ? 'FOR UPDATE' : ''}`, [tenant,round])).rows;
}

/** First local, team-driver pickup transaction. Not an HTTP endpoint. No switch
 * of legacy writers/queues is allowed yet. Transport receipts, previously held
 * goods, multi-pickup routes and offline-retention execution remain gated.
 * Authentication must be resolved by the trusted server before calling this.
 */
export function localPickupWork(authority: CommandAuthority, request: Wire_ConfirmPickupRequest): CommandWork {
  authority = Object.freeze({...authority});
  // Used only to bind authorization to the same validated original job. The
  // runner snapshots the complete request again before acquiring a connection.
  try { request = JSON.parse(canonicalCommandJson(request)) as Wire_ConfirmPickupRequest; }
  catch { return reject('VALIDATION_FAILED'); }
  validatePickupRequest(request);
  const roundId = request.payload.round_id;
  const assignmentId = request.execution_fence.assignment_id;
  return {
    commandType: 'ConfirmPickup', authority, request, validate: validatePickupRequest,
    receiptScope: {roundId,assignmentId},
    authorize: (client, auth) => authorizeTeamPickup(client, auth, roundId, assignmentId),
    validateResult: validatePickupResult,
    execute: (client, frozen, trace) => executeLocalPickup(client, authority, frozen as Wire_ConfirmPickupRequest, trace),
  };
}

async function executeLocalPickup(client: PoolClient, auth: CommandAuthority, request: Wire_ConfirmPickupRequest, traceId: string): Promise<Wire_ConfirmPickupResult> {
  const tenant = auth.tenantId!;
  const p = request.payload;
  // Discover the server-owned route, not just the submitted ready subset.
  const initial = await routeStops(client, tenant, p.round_id);
  const dropoffs = initial.filter(s => s.kind === 'dropoff');
  if (!dropoffs.length || initial.filter(s => s.kind === 'pickup').length !== 1 ||
      initial.some(s => !['pickup','dropoff'].includes(s.kind))) reject('PICKUP_NOT_READY');
  const deliveryIds = dropoffs.map(s => s.delivery_id!);
  const unitIds = dropoffs.map(s => s.fulfillment_unit_id!);
  if (new Set(deliveryIds).size !== deliveryIds.length || new Set(unitIds).size !== unitIds.length) reject('MANIFEST_MISMATCH');

  // Canonical E04 ordering: deliveries -> unit/claim -> Round/assignment/stops
  // -> manifests/lines -> custody dependencies -> global driver guard.
  const deliveries = (await client.query<Delivery>(`SELECT id,city_id,pickup_site_id,current_manifest_id,preparation_state,readiness,outcome
    FROM rounds.deliveries WHERE tenant_id=$1 AND city_id=$2 AND id=ANY($3::uuid[]) AND archived_at IS NULL ORDER BY id FOR UPDATE`,
    [tenant,auth.cityId,deliveryIds])).rows;
  if (deliveries.length !== deliveryIds.length) reject('NOT_AUTHORIZED');
  const claims = (await client.query<{round_id:string;delivery_id:string;fulfillment_unit_id:string;claim_kind:string;archived_at:Date|null;expired:boolean}>(
    `SELECT round_id,delivery_id,fulfillment_unit_id,claim_kind,archived_at,expires_at<=clock_timestamp() AS expired FROM rounds.active_delivery_claims
    WHERE tenant_id=$1 AND fulfillment_unit_id=ANY($2::uuid[]) ORDER BY id FOR UPDATE`, [tenant,unitIds])).rows;
  if (claims.length !== unitIds.length || claims.some(c => c.round_id !== p.round_id || c.claim_kind !== 'team' || c.archived_at || c.expired ||
      !dropoffs.some(s => s.delivery_id === c.delivery_id && s.fulfillment_unit_id === c.fulfillment_unit_id))) reject('NOT_AUTHORIZED');
  const units = (await client.query<Unit>(`SELECT id,delivery_id,manifest_id,state,version FROM rounds.fulfillment_units
    WHERE tenant_id=$1 AND id=ANY($2::uuid[]) AND archived_at IS NULL ORDER BY id FOR UPDATE`, [tenant,unitIds])).rows;
  if (units.length !== unitIds.length) reject('MANIFEST_MISMATCH');
  const assignment = await lockOriginalRoundAssignment(client, auth, p.round_id, request.execution_fence);
  const round = (await client.query<{version:string;pickup_site_id:string;state:string;departure_gate:string;operational_hold:boolean;fulfillment_kind:string}>(
    `SELECT version,pickup_site_id,state,departure_gate,operational_hold,fulfillment_kind FROM rounds.rounds WHERE tenant_id=$1 AND id=$2`, [tenant,p.round_id])).rows[0]!;
  const stops = await routeStops(client, tenant, p.round_id, true);
  if (JSON.stringify(stops) !== JSON.stringify(initial)) reject('STALE_VERSION');
  const pickup = stops.find(s => s.id === p.pickup_stop_id && s.kind === 'pickup');
  if (!pickup) reject('NOT_AUTHORIZED');
  if (pickup.state !== 'arrived' || round.state !== 'released' || round.operational_hold || round.fulfillment_kind !== 'team' ||
      (pickup.actual_arrival_at && Date.parse(request.occurred_at) < pickup.actual_arrival_at.getTime()) ||
      dropoffs.some(s => s.state !== 'released') || deliveries.some(d => d.pickup_site_id !== round.pickup_site_id || d.readiness !== 'ready' || d.outcome !== 'open')) reject('PICKUP_NOT_READY');

  const manifestIds = deliveries.map(d => d.current_manifest_id);
  const manifests = (await client.query<Manifest>(`SELECT id,delivery_id,version,sealed_at FROM rounds.manifests
    WHERE tenant_id=$1 AND id=ANY($2::uuid[]) AND archived_at IS NULL ORDER BY id FOR UPDATE`, [tenant,manifestIds])).rows;
  if (manifests.length !== deliveries.length) reject('MANIFEST_MISMATCH');
  const lines = (await client.query<Line>(`SELECT id,manifest_id,quantity FROM rounds.manifest_lines WHERE tenant_id=$1
    AND manifest_id=ANY($2::uuid[]) AND archived_at IS NULL ORDER BY id FOR UPDATE`, [tenant,manifestIds])).rows;
  const allocations = (await client.query<{unit_id:string;line_id:string;allocated_quantity:string;delivered_quantity:string;returned_quantity:string;cancelled_quantity:string}>(
    `SELECT unit_id,line_id,allocated_quantity,delivered_quantity,returned_quantity,cancelled_quantity FROM rounds.fulfillment_unit_lines
    WHERE tenant_id=$1 AND unit_id=ANY($2::uuid[]) AND archived_at IS NULL ORDER BY id FOR UPDATE`, [tenant,unitIds])).rows;
  assertExpectedVersions(request.expected_versions, [resource('rounds',p.round_id,round.version),resource('stops',pickup.id,pickup.version),
    ...manifests.map(m => resource('manifests',m.id,m.version)),...units.map(u => resource('fulfillment_units',u.id,u.version))]);

  // R1 local first custody is the driver's attestation, not invented stock at
  // planning time. Any inbound/history requires its separately verified path.
  const dependencies = await client.query<{state:string}>(`SELECT state FROM rounds.inbound_dependencies
    WHERE tenant_id=$1 AND delivery_id=ANY($2::uuid[]) ORDER BY id FOR UPDATE`, [tenant,deliveryIds]);
  if (dependencies.rows.some(d => d.state === 'discrepancy')) reject('INBOUND_DISCREPANCY');
  if (dependencies.rowCount) reject('INBOUND_NOT_RECEIVED');
  const balances = await client.query(`SELECT id FROM rounds.custody_balances WHERE tenant_id=$1 AND line_id=ANY($2::uuid[]) ORDER BY id FOR UPDATE`, [tenant,lines.map(l => l.id)]);
  const history = await client.query(`SELECT id FROM rounds.custody_events WHERE tenant_id=$1 AND manifest_id=ANY($2::uuid[]) LIMIT 1`, [tenant,manifestIds]);
  if (balances.rowCount || history.rowCount) reject('CUSTODY_MISMATCH');
  // Attempt writers share the delivery locks held above. Inconsistent legacy
  // state must not create a second live attempt even if the unit is still open.
  const liveAttempts = await client.query(`SELECT id FROM rounds.delivery_attempts WHERE tenant_id=$1
    AND delivery_id=ANY($2::uuid[]) AND state IN ('pending','en_route','arrived','handed_over') LIMIT 1`, [tenant,deliveryIds]);
  if (liveAttempts.rowCount) reject('PICKUP_NOT_READY');
  if (manifests.some(m => m.sealed_at)) reject('IMMUTABLE_RECORD');
  const orders: WholePickupOrder[] = deliveries.map(d => {
    const unit = units.find(u => u.delivery_id === d.id);
    const manifest = manifests.find(m => m.id === d.current_manifest_id && m.delivery_id === d.id);
    if (!unit || !manifest || unit.manifest_id !== manifest.id || !dropoffs.some(s => s.delivery_id === d.id && s.fulfillment_unit_id === unit.id)) return reject('MANIFEST_MISMATCH');
    const orderLines = lines.filter(l => l.manifest_id === manifest.id);
    const allocated = allocations.filter(a => a.unit_id === unit.id);
    if (allocated.length !== orderLines.length || orderLines.some(l => !allocated.some(a => a.line_id === l.id && a.allocated_quantity === l.quantity &&
        Number(a.delivered_quantity) === 0 && Number(a.returned_quantity) === 0 && Number(a.cancelled_quantity) === 0))) reject('MANIFEST_MISMATCH');
    return {delivery_id:d.id,manifest_id:manifest.id,fulfillment_unit_id:unit.id,unit_state:unit.state,preparation:d.preparation_state,inbound:'not_required',
      lines:orderLines.map(l => ({line_id:l.id,quantity:Number(l.quantity),available_quantity:Number(l.quantity)}))};
  });
  const check = checkWholeOrderPickup(orders, p);
  if (!check.ok) reject(check.code);
  // Never let a stale stored gate authorize pickup, or auto-release a held job.
  if (round.departure_gate !== 'ready') reject('PICKUP_NOT_READY');
  const driver = await client.query(`SELECT id FROM rounds.drivers WHERE id=$1 AND principal_id=$2 AND archived_at IS NULL FOR UPDATE`, [assignment.driverId,auth.principalId]);
  if (!driver.rowCount) reject('NOT_AUTHORIZED');

  // Every precondition above completes before the first domain write.
  const custodian = (await client.query<{id:string;archived_at:Date|null}>(`INSERT INTO rounds.custodians(tenant_id,kind,principal_id)
    VALUES($1,'principal',$2) ON CONFLICT(tenant_id,principal_id) DO UPDATE SET principal_id=EXCLUDED.principal_id RETURNING id,archived_at`, [tenant,auth.principalId])).rows[0]!;
  if (custodian.archived_at) reject('CUSTODY_MISMATCH');
  const receivedAt = (await client.query<{at:Date}>('SELECT clock_timestamp() AS at')).rows[0]!.at.toISOString();
  const current = [resource('rounds',p.round_id,version(round.version)+1),resource('stops',pickup.id,version(pickup.version)+1)];
  // Changed roots are in current_versions; resources binds newly created IDs.
  const resources: Wire_ResourceVersion[] = [];
  const collected: Wire_FulfillmentUnitView[] = [];
  const attempts: Wire_AttemptView[] = [];
  const custodyIds: string[] = [];
  for (const order of [...orders].sort((a,b) => a.manifest_id.localeCompare(b.manifest_id))) {
    const manifest = manifests.find(m => m.id === order.manifest_id)!;
    const unit = units.find(u => u.id === order.fulfillment_unit_id)!;
    const stop = dropoffs.find(s => s.fulfillment_unit_id === unit.id)!;
    await client.query(`UPDATE rounds.manifests SET sealed_at=$3,version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [tenant,manifest.id,request.occurred_at]);
    await client.query(`UPDATE rounds.fulfillment_units SET state='collected',collected_at=$3,version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [tenant,unit.id,request.occurred_at]);
    const attempt = (await client.query<{id:string;attempt_number:number}>(`INSERT INTO rounds.delivery_attempts(tenant_id,delivery_id,stop_id,driver_id,attempt_number,state,fulfillment_unit_id)
      SELECT $1,$2,$3,$4,COALESCE(MAX(attempt_number),0)+1,'pending',$5 FROM rounds.delivery_attempts WHERE tenant_id=$1 AND delivery_id=$2
      RETURNING id,attempt_number`, [tenant,order.delivery_id,stop.id,assignment.driverId,unit.id])).rows[0]!;
    const custodyId = randomUUID(); custodyIds.push(custodyId);
    await client.query(`INSERT INTO rounds.custody_events(id,tenant_id,manifest_id,attempt_id,event_kind,occurred_at,received_at,actor_id,command_id,round_id,stop_id,to_custodian_id)
      VALUES($1,$2,$3,$4,'pickup',$5,$6,$7,$8,$9,$10,$11)`,
      [custodyId,tenant,manifest.id,attempt.id,request.occurred_at,receivedAt,auth.principalId,request.command_id,p.round_id,pickup.id,custodian.id]);
    for (const line of order.lines) {
      await client.query(`INSERT INTO rounds.custody_event_lines(tenant_id,event_id,line_id,quantity,condition_code) VALUES($1,$2,$3,$4,'not_assessed')`, [tenant,custodyId,line.line_id,line.quantity]);
      await client.query(`INSERT INTO rounds.custody_balances(tenant_id,line_id,quantity,last_event_id,custodian_id) VALUES($1,$2,$3,$4,$5)`, [tenant,line.line_id,line.quantity,custodyId,custodian.id]);
    }
    current.push(resource('manifests',manifest.id,version(manifest.version)+1),resource('fulfillment_units',unit.id,version(unit.version)+1));
    resources.push(resource('delivery_attempts',attempt.id,1),resource('custody_events',custodyId,1));
    collected.push({id:unit.id,version:version(unit.version)+1,delivery_id:order.delivery_id,manifest_id:manifest.id,parent_unit_id:null,remaining_obligation_id:null,state:'collected',
      allocated_quantities:order.lines.map(l => ({line_id:l.line_id,quantity:l.quantity})),delivered_quantities:[],return_quantities:[],cancelled_quantities:[]});
    attempts.push({id:attempt.id,version:1,delivery_id:order.delivery_id,stop_id:stop.id,driver_id:assignment.driverId,state:'pending',attempt_number:attempt.attempt_number,
      arrived_at:null,handoff_at:null,closed_at:null,handoff_id:null,fulfillment_unit_id:unit.id});
  }
  await client.query(`UPDATE rounds.stops SET state='completed',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [tenant,pickup.id]);
  await client.query(`UPDATE rounds.rounds SET state='active',version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [tenant,p.round_id]);
  // One fact per manifest, with explicit unit/attempt binding, not array-index
  // assumptions in clients. The legacy singular result points at the first
  // stable manifest; resources lists every custody event in the atomic batch.
  for (const [i, unit] of collected.entries()) {
    const attempt = attempts[i]!;
    const subject = resource('manifests',unit.manifest_id,current.find(r => r.id === unit.manifest_id)!.version);
    const fact: Wire_Event_pickup_confirmed = {
      event_id:randomUUID(),event_type:'pickup.confirmed',schema_version:3,tenant_id:tenant,principal_id:null,aggregate:subject,
      occurred_at:request.occurred_at,received_at:receivedAt,actor_id:auth.principalId,command_id:request.command_id,worker_run_id:null,trace_id:traceId,
      payload:{subject,affected_resources:[subject,resource('fulfillment_units',unit.id,unit.version),resource('delivery_attempts',attempt.id,1),
        resource('custody_events',custodyIds[i]!,1),...(i === 0 ? current.slice(0,2) : [])],round_id:p.round_id,collected_units:[unit],attempts:[attempt],residual_units:[],custody_event_id:custodyIds[i]!,
        changes:[{family:'fulfillment_units.state',resource_id:unit.id,from_state:'open',to_state:'collected',version:unit.version},
          {family:'delivery_attempts.state',resource_id:attempt.id,from_state:null,to_state:'pending',version:1},
          ...(i === 0 ? [{family:'rounds.state' as const,resource_id:p.round_id,from_state:'released' as const,to_state:'active' as const,version:version(round.version)+1},
            {family:'stops.state' as const,resource_id:pickup.id,from_state:'arrived' as const,to_state:'completed' as const,version:version(pickup.version)+1}] : [])]}
    };
    validatePickupEvent(fact);
    await client.query(`INSERT INTO rounds.domain_events(id,tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::jsonb,$13)`,
      [fact.event_id,tenant,subject.aggregate_type,subject.id,subject.version,fact.event_type,fact.schema_version,auth.principalId,request.command_id,request.occurred_at,receivedAt,JSON.stringify(fact.payload),fact.trace_id]);
    await client.query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`, [tenant,fact.event_id]);
  }
  return {command_id:request.command_id,command_type:'ConfirmPickup',state:'committed',current_versions:current,resources,
    data:{custody_event_id:custodyIds[0]!,collected_units:collected,attempts,remaining_units:[],obligation_ids:[]}};
}
