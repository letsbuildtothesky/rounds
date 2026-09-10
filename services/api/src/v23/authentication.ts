import { createClient } from '@supabase/supabase-js';
import type { PoolClient } from 'pg';
import type { DeviceSession } from './device-session.js';
import { CommandRejection, TransactionUnavailable, type CommandAuthority } from './transaction-runner.js';

export type BearerVerifier = (token:string)=>Promise<string>;
export function requiredBearer(request: Request): string {
  const header=request.headers.get('authorization')??'';
  if(header.length>8192 || !/^Bearer [A-Za-z0-9._~-]+$/i.test(header)) throw new CommandRejection('UNAUTHENTICATED');
  return header.slice(7);
}
export async function resolvePrincipal(client: PoolClient, authSubject: string): Promise<string> {
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(authSubject)) throw new CommandRejection('UNAUTHENTICATED');
  await client.query("SELECT set_config('rounds.auth_subject',$1,true)",[authSubject]);
  const principal=await client.query<{id:string|null}>('SELECT rounds.api_principal_id() AS id');
  if(!principal.rows[0]?.id) throw new CommandRejection('NOT_AUTHORIZED');
  return principal.rows[0].id;
}
/** Never uses the legacy administrative client, stored session or user metadata. */
export function supabaseBearerVerifier(url:string,publishableKey:string,fetcher:typeof fetch=fetch):BearerVerifier {
  const parsed=new URL(url);
  if(parsed.protocol!=='https:' || parsed.username || parsed.password || parsed.search || parsed.hash || parsed.pathname!=='/') throw new Error('HTTPS Auth origin required');
  const client=createClient(url,publishableKey,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
    global:{fetch:(input,init)=>fetcher(input,{...init,signal:AbortSignal.any([AbortSignal.timeout(5000),...(init?.signal?[init.signal]:[])])})}});
  return async token=>{
    try {
      const {data,error}=await client.auth.getUser(token);
      if(error) {
        if(error.status===429) throw new CommandRejection('RATE_LIMITED');
        if(error.status && error.status>=400 && error.status<500) throw new CommandRejection('UNAUTHENTICATED');
        throw new TransactionUnavailable('PROVIDER_UNAVAILABLE');
      }
      if(!data.user || !/^[0-9a-f-]{36}$/i.test(data.user.id)) throw new CommandRejection('UNAUTHENTICATED');
      return data.user.id.toLowerCase();
    } catch(error) {
      if(error instanceof CommandRejection || error instanceof TransactionUnavailable) throw error;
      throw new TransactionUnavailable('PROVIDER_UNAVAILABLE');
    }
  };
}

/** Called on the pinned transaction, including every retry and result lookup. */
export async function authorizeDeviceSession(client:PoolClient,authority:CommandAuthority,session:DeviceSession,now:number):Promise<void> {
  if(session.exp<=now || session.iat>now || session.principalId!==authority.principalId) throw new CommandRejection('UNAUTHENTICATED');
  if(await resolvePrincipal(client,session.authSubject)!==authority.principalId) throw new CommandRejection('NOT_AUTHORIZED');
  // Self-only device RLS; lock revocation/epoch until this transaction finishes.
  const device=await client.query(`SELECT id FROM rounds.driver_devices WHERE id=$1 AND session_epoch=$2
    AND revoked_at IS NULL AND archived_at IS NULL FOR SHARE`,[session.deviceId,session.epoch]);
  if(!device.rowCount) throw new CommandRejection('NOT_AUTHORIZED');
}
