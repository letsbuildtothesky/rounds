import type { PoolClient } from 'pg';
import type { Wire_PickupIssueAssetContext, Wire_ReportIssueRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { authorizeTeamPickupJob } from './pickup-authorization.js';
import { assertExecutionFence, CommandRejection, type CommandAuthority, type ReceiptJobScope } from './transaction-runner.js';
import { canonicalCommandJson } from './command-identity.js';

export type PickupIssueAssetScope = ReceiptJobScope & {
  delivery_id: string; pickup_stop_id: string; fulfillment_unit_id: string; manifest_id: string;
  assignment_version: string; observation_id: string; observed_at: string;
};
type Binding = {
  delivery_id: string; round_id: string; pickup_stop_id: string; fulfillment_unit_id: string; manifest_id: string;
  assignment_id: string; assignment_version: string; observation_id: string; observed_at: Date; upload_key: string;
};
type StoredAsset = {
  id: string; object_key: string; kind: string; state: string; mime_type: string; byte_size: string; sha256: string; version: string;
};
function reject(code: ConstructorParameters<typeof CommandRejection>[0]): never { throw new CommandRejection(code); }

/** Original pre-pickup order, not a handoff or today's replacement assignment.
 * Arrival and preparation deliberately do not gate observation of a problem.
 */
export async function pickupIssueAssetPurpose(c: PoolClient, auth: CommandAuthority, deliveryId: string,
  context: Wire_PickupIssueAssetContext, observedAt: string, lock = false): Promise<PickupIssueAssetScope> {
  const f = context.execution_fence;
  await authorizeTeamPickupJob(c, auth, context.round_id, f.assignment_id);
  const found = (await c.query<{ claim_id: string; driver_id: string; assignment_version: string }>(`SELECT cl.id AS claim_id,d.id AS driver_id,a.version AS assignment_version
    FROM rounds.deliveries y
    JOIN rounds.active_delivery_claims cl ON cl.tenant_id=y.tenant_id AND cl.delivery_id=y.id AND cl.claim_kind='team'
    JOIN rounds.fulfillment_units u ON u.tenant_id=y.tenant_id AND u.id=cl.fulfillment_unit_id AND u.delivery_id=y.id AND u.manifest_id=y.current_manifest_id
    JOIN rounds.manifests m ON m.tenant_id=y.tenant_id AND m.id=u.manifest_id AND m.delivery_id=y.id
    JOIN rounds.rounds r ON r.tenant_id=y.tenant_id AND r.id=cl.round_id AND r.city_id=y.city_id
    JOIN rounds.assignments a ON a.tenant_id=r.tenant_id AND a.round_id=r.id AND a.id=$8 AND a.driver_id=r.driver_id
    JOIN rounds.drivers d ON d.id=a.driver_id AND d.principal_id=$3
    JOIN rounds.stops s ON s.tenant_id=r.tenant_id AND s.round_id=r.id AND s.id=$6 AND s.kind='pickup'
    WHERE y.tenant_id=$1 AND y.id=$2 AND y.city_id=$4 AND y.current_manifest_id=$7 AND y.outcome='open' AND y.readiness IN ('ready','review_needed','held')
      AND r.id=$5 AND r.state='released' AND r.fulfillment_kind='team' AND a.state='acknowledged'
      AND u.id=$9 AND u.state='open' AND u.collected_at IS NULL AND s.state IN ('released','en_route','arrived')
      AND (cl.expires_at IS NULL OR cl.expires_at>clock_timestamp())
      AND y.archived_at IS NULL AND cl.archived_at IS NULL AND u.archived_at IS NULL AND m.archived_at IS NULL
      AND r.archived_at IS NULL AND a.archived_at IS NULL AND d.archived_at IS NULL AND s.archived_at IS NULL
      AND 1=(SELECT count(*) FROM rounds.stops p WHERE p.tenant_id=r.tenant_id AND p.round_id=r.id AND p.kind='pickup' AND p.state<>'cancelled' AND p.archived_at IS NULL)
      AND 1=(SELECT count(*) FROM rounds.stops t WHERE t.tenant_id=r.tenant_id AND t.round_id=r.id AND t.delivery_id=y.id AND t.fulfillment_unit_id=u.id AND t.kind='dropoff' AND t.state='released' AND t.archived_at IS NULL)
      AND NOT EXISTS(SELECT 1 FROM rounds.stops t WHERE t.tenant_id=r.tenant_id AND t.round_id=r.id AND t.kind NOT IN ('pickup','dropoff') AND t.state<>'cancelled' AND t.archived_at IS NULL)`,
  [auth.tenantId, deliveryId, auth.principalId, auth.cityId, context.round_id, context.pickup_stop_id, context.manifest_id, f.assignment_id, context.fulfillment_unit_id])).rows;
  if (found.length !== 1) reject('NOT_AUTHORIZED');
  const row = found[0]!;
  assertExecutionFence(f, { assignment_id: f.assignment_id, assignment_version: Number(row.assignment_version) });
  if (lock) {
    // Same root order as ReportIssue; no provider calls inside this transaction.
    for (const [table, id] of [['deliveries', deliveryId], ['active_delivery_claims', row.claim_id], ['fulfillment_units', context.fulfillment_unit_id], ['rounds', context.round_id], ['assignments', f.assignment_id]])
      await c.query(`SELECT id FROM rounds.${table} WHERE tenant_id=$1 AND id=$2 FOR UPDATE`, [auth.tenantId, id]);
    await c.query('SELECT id FROM rounds.stops WHERE tenant_id=$1 AND round_id=$2 AND archived_at IS NULL AND state<>\'cancelled\' ORDER BY id FOR UPDATE', [auth.tenantId, context.round_id]);
    await c.query('SELECT id FROM rounds.manifests WHERE tenant_id=$1 AND id=$2 FOR UPDATE', [auth.tenantId, context.manifest_id]);
    await c.query('SELECT id FROM rounds.drivers WHERE id=$1 FOR UPDATE', [row.driver_id]);
    await pickupIssueAssetPurpose(c, auth, deliveryId, context, observedAt);
  }
  return { roundId: context.round_id, assignmentId: f.assignment_id, delivery_id: deliveryId, pickup_stop_id: context.pickup_stop_id,
    fulfillment_unit_id: context.fulfillment_unit_id, manifest_id: context.manifest_id, assignment_version: row.assignment_version,
    observation_id: f.observation_id, observed_at: observedAt };
}

async function binding(c: PoolClient, auth: CommandAuthority, id: string): Promise<Binding> {
  const b = (await c.query<Binding>(`SELECT delivery_id,round_id,pickup_stop_id,fulfillment_unit_id,manifest_id,assignment_id,assignment_version,observation_id,observed_at,upload_key
    FROM rounds.pickup_issue_asset_bindings WHERE tenant_id=$1 AND asset_id=$2 AND actor_id=$3 AND city_id=$4`, [auth.tenantId, id, auth.principalId, auth.cityId])).rows[0];
  if (!b) reject('NOT_AUTHORIZED');
  return b;
}
export async function loadBoundPickupIssueAsset(c: PoolClient, auth: CommandAuthority, id: string, lock = false) {
  const b = await binding(c, auth, id);
  const scope = await pickupIssueAssetPurpose(c, auth, b.delivery_id, { round_id: b.round_id, pickup_stop_id: b.pickup_stop_id,
    fulfillment_unit_id: b.fulfillment_unit_id, manifest_id: b.manifest_id,
    execution_fence: { assignment_id: b.assignment_id, assignment_version: Number(b.assignment_version), observation_id: b.observation_id } }, b.observed_at.toISOString(), lock);
  const a = (await c.query<StoredAsset>(`SELECT id,object_key,kind,state,mime_type,byte_size,sha256,version FROM rounds.assets
    WHERE tenant_id=$1 AND id=$2 AND created_by=$3 AND archived_at IS NULL ${lock ? 'FOR UPDATE' : ''}`, [auth.tenantId, id, auth.principalId])).rows[0];
  if (!a || a.kind !== 'issue_photo') reject('NOT_AUTHORIZED');
  return { ...scope, ...a, upload_key: b.upload_key };
}
export async function bindPickupIssueAsset(c: PoolClient, auth: CommandAuthority, id: string, scope: PickupIssueAssetScope, key: string) {
  await c.query(`INSERT INTO rounds.pickup_issue_asset_bindings(asset_id,tenant_id,city_id,actor_id,delivery_id,round_id,pickup_stop_id,fulfillment_unit_id,manifest_id,assignment_id,assignment_version,observation_id,observed_at,upload_key)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`, [id, auth.tenantId, auth.cityId, auth.principalId, scope.delivery_id, scope.roundId,
    scope.pickup_stop_id, scope.fulfillment_unit_id, scope.manifest_id, scope.assignmentId, scope.assignment_version, scope.observation_id, scope.observed_at, key]);
}

/** Caller already holds delivery/claim/unit/assignment/stops/manifest/driver.
 * Only take the asset lock here: loading the purpose again would invert locks.
 */
export async function validatePickupIssueAttachment(c: PoolClient, auth: CommandAuthority, request: Wire_ReportIssueRequest,
  original: { pickupStopId: string; unitId: string | undefined; manifestId: string | undefined }) {
  if (!request.payload.asset_ids.length) return;
  const id = request.payload.asset_ids[0]!, b = await binding(c, auth, id), f = request.execution_fence;
  const actual = [b.delivery_id, b.round_id, b.pickup_stop_id, b.fulfillment_unit_id, b.manifest_id, b.assignment_id, Number(b.assignment_version), b.observation_id, b.observed_at.toISOString()];
  const expected = [request.payload.delivery_id, request.payload.round_id, original.pickupStopId, original.unitId, original.manifestId, f.assignment_id, f.assignment_version, f.observation_id, new Date(request.occurred_at).toISOString()];
  if (canonicalCommandJson(actual) !== canonicalCommandJson(expected)) reject('NOT_AUTHORIZED');
  const a = (await c.query<{ kind: string; state: string; verified_at: Date | null }>(`SELECT kind,state,verified_at FROM rounds.assets WHERE tenant_id=$1 AND id=$2
    AND created_by=$3 AND archived_at IS NULL
    AND EXISTS(SELECT 1 FROM rounds.pickup_issue_asset_bindings b WHERE b.tenant_id=$1 AND b.asset_id=$2 AND b.observed_at=$4::timestamptz)
    FOR UPDATE`, [auth.tenantId, id, auth.principalId, request.occurred_at])).rows[0];
  if (!a || a.kind !== 'issue_photo') reject('NOT_AUTHORIZED');
  if (a.state !== 'verified' || !a.verified_at) reject('ASSET_NOT_VERIFIED');
}
