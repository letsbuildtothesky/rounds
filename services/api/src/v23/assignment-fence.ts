import type { PoolClient } from "pg";
import { assertExecutionFence, CommandRejection, type CommandAuthority, type ExecutionFence } from "./transaction-runner.js";

/** Resolve the ORIGINAL job identity, never substitute today's assignment for
 * queued evidence. Caller must authorize current session/capability first and
 * lock delivery/unit roots in E04 order before entering the Round lock class.
 * This is a transaction precondition, not a pickup mutation or HTTP endpoint.
 */
export async function lockOriginalRoundAssignment(client: PoolClient, authority: CommandAuthority, roundId: string, original: ExecutionFence) {
  const result = await client.query(`SELECT a.id, a.version, a.state,
    a.driver_id, r.driver_id AS current_driver_id, r.state AS round_state,
    a.archived_at AS assignment_archived_at, r.archived_at AS round_archived_at
    FROM rounds.rounds r JOIN rounds.assignments a ON a.tenant_id=r.tenant_id AND a.round_id=r.id
    JOIN rounds.drivers d ON d.id=a.driver_id
    WHERE r.tenant_id=$1 AND r.city_id=$2 AND r.id=$3 AND a.id=$4 AND d.principal_id=$5
    FOR UPDATE OF r,a`, [authority.tenantId,authority.cityId,roundId,original.assignment_id,authority.principalId]);
  const assignment = result.rows[0];
  if (!assignment) throw new CommandRejection("NOT_AUTHORIZED");
  assertExecutionFence(original, { assignment_id: assignment.id, assignment_version: Number(assignment.version) });
  if (assignment.assignment_archived_at || assignment.round_archived_at ||
      !["issued","received","acknowledged"].includes(assignment.state) ||
      !["staged","released","active"].includes(assignment.round_state) ||
      assignment.driver_id !== assignment.current_driver_id) throw new CommandRejection("EXECUTION_FENCE_CHANGED");
  return { assignmentId: assignment.id as string, driverId: assignment.driver_id as string };
}
