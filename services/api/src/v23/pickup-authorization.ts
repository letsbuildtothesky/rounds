import type { PoolClient } from 'pg';
import { CommandRejection, type CommandAuthority } from './transaction-runner.js';

/** R1 team scope only. A trusted session resolver must supply the principal;
 * this is not bearer authentication and must never be exposed as a raw route.
 * Capability is rechecked even on receipt replay. Permission locks precede
 * receipt/domain locks; job rows are revalidated under canonical domain locks.
 */
export async function authorizeTeamPickup(client: PoolClient, auth: CommandAuthority, roundId: string, assignmentId: string): Promise<void> {
  await authorizeTeamPickupCity(client,auth);
  await authorizeTeamPickupJob(client,auth,roundId,assignmentId);
}

export async function authorizeTeamPickupCity(client: PoolClient, auth: CommandAuthority): Promise<void> {
  const access = await client.query(`SELECT m.id FROM rounds.memberships m
    JOIN rounds.city_grants g ON g.tenant_id=m.tenant_id AND g.membership_id=m.id
    JOIN rounds.cities c ON c.tenant_id=g.tenant_id AND c.id=g.city_id
    JOIN rounds.tenants t ON t.id=m.tenant_id
    JOIN rounds.drivers d ON d.principal_id=m.principal_id
    JOIN rounds.driver_relationships dr ON dr.tenant_id=m.tenant_id AND dr.driver_id=d.id
    WHERE m.tenant_id=$1 AND m.principal_id=$2 AND m.status='active' AND m.archived_at IS NULL
      AND g.city_id=$3 AND g.archived_at IS NULL AND 'driver.assigned_work'=ANY(g.capabilities)
      AND c.enabled AND c.archived_at IS NULL AND t.status='active' AND t.archived_at IS NULL
      AND d.archived_at IS NULL AND dr.archived_at IS NULL AND dr.status='active' AND dr.relationship_kind='team'
    FOR SHARE OF m,g,c,dr`, [auth.tenantId,auth.principalId,auth.cityId]);
  if (!access.rowCount) throw new CommandRejection('NOT_AUTHORIZED');
}

export async function authorizeTeamPickupJob(client: PoolClient, auth: CommandAuthority, roundId: string, assignmentId: string): Promise<void> {
  const job = await client.query(`SELECT a.id FROM rounds.assignments a
    JOIN rounds.rounds r ON r.tenant_id=a.tenant_id AND r.id=a.round_id
    JOIN rounds.drivers d ON d.id=a.driver_id
    WHERE a.tenant_id=$1 AND r.city_id=$2 AND r.id=$3 AND a.id=$4 AND d.principal_id=$5
      AND r.fulfillment_kind='team' AND r.archived_at IS NULL AND a.archived_at IS NULL
      AND r.driver_id=a.driver_id AND a.state NOT IN ('withdrawn','superseded')`,
    [auth.tenantId,auth.cityId,roundId,assignmentId,auth.principalId]);
  if (!job.rowCount) throw new CommandRejection('NOT_AUTHORIZED');
}
