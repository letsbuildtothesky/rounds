import type { PoolClient } from 'pg';
import type { CommandAuthority } from './transaction-runner.js';

/** Null authority is allowed only while resolving a verified Auth subject.
 * It sets empty scope, never ambient scope inherited from a pooled connection.
 */
export async function beginRestrictedTransaction(client: PoolClient, authority: CommandAuthority | null, snapshot = false): Promise<void> {
  const roles = await client.query('SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname=session_user');
  if (!roles.rows[0] || roles.rows[0].rolsuper || roles.rows[0].rolbypassrls) throw new Error('Restricted connection required');
  await client.query(snapshot ? 'BEGIN ISOLATION LEVEL REPEATABLE READ' : 'BEGIN ISOLATION LEVEL READ COMMITTED');
  await client.query('SET LOCAL ROLE rounds_api');
  await client.query('SET LOCAL search_path = pg_catalog, rounds');
  await client.query("SET LOCAL statement_timeout = '5s'");
  await client.query("SET LOCAL lock_timeout = '2s'");
  await client.query("SET LOCAL idle_in_transaction_session_timeout = '10s'");
  const check = await client.query("SELECT r.rolsuper, r.rolbypassrls, c.relowner = r.oid AS owner FROM pg_roles r JOIN pg_class c ON c.oid='rounds.command_receipts'::regclass WHERE r.rolname=current_user");
  if (!check.rows[0] || check.rows[0].rolsuper || check.rows[0].rolbypassrls || check.rows[0].owner) throw new Error('Restricted non-owner role required');
  await client.query("SELECT set_config('rounds.tenant_id',$1,true),set_config('rounds.principal_id',$2,true),set_config('rounds.city_id',$3,true),set_config('rounds.auth_subject','',true)",
    [authority?.tenantId ?? '', authority?.principalId ?? '', authority?.cityId ?? '']);
}
