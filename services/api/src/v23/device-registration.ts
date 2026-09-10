import { createHash, randomUUID } from 'node:crypto';
import type { Pool, PoolClient } from 'pg';
import type { deviceSessions } from './device-session.js';
import { resolvePrincipal } from './authentication.js';
import { beginRestrictedTransaction } from './restricted-transaction.js';
import { CommandRejection, TransactionUnavailable } from './transaction-runner.js';
import { validateDeviceAudit, validateDeviceResult } from './pickup-validation.js';
import type { Wire_DriverDeviceSecurityAudit, Wire_DriverDeviceSessionResult, Wire_DriverDeviceRevokeResult } from '../../../../packages/contracts/src/v23/pickup-wire.js';

type Request = { operation:'session'; installation_secret:string; platform:'android'|'ios' } |
  { operation:'revoke'; installation_secret:string };
type DeviceRow = { id:string; platform:'android'|'ios'; session_epoch:string; version:string; revoked_at:Date|null; archived_at:Date|null };
export const installationKey = (principal:string,secret:string):string =>
  'v23-install-sha256:'+createHash('sha256').update('rounds.device.v1\0'+principal+'\0'+secret).digest('hex');

async function audit(client: PoolClient, principal:string, row:DeviceRow, action:'registered'|'revoked', trace:string):Promise<void> {
  const payload:Wire_DriverDeviceSecurityAudit={device_id:row.id,platform:row.platform,session_epoch:Number(row.session_epoch),action};
  validateDeviceAudit(payload);
  // Private security audit, not a business command/fact or notification.
  await client.query(`INSERT INTO rounds.account_events(principal_id,aggregate_type,aggregate_id,aggregate_version,event_type,
    schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
    VALUES($1,'driver_devices',$2,$3,$4,1,$1,$5,clock_timestamp(),clock_timestamp(),$6::jsonb,$7)`,
    [principal,row.id,row.version,`device.${action}`,randomUUID(),JSON.stringify(payload),trace]);
}

/** Existing driver only. Provider verification happens before acquiring a DB
 * connection. No tenant, principal, driver, device ID or epoch from the body.
 */
export function deviceRegistration(options:{pool:Pool;devices:ReturnType<typeof deviceSessions>;now?:()=>number}) {
  const now=options.now??(()=>Math.floor(Date.now()/1000));
  return async(authSubject:string,input:Request,trace:string):Promise<Wire_DriverDeviceSessionResult|Wire_DriverDeviceRevokeResult>=>{
    // Also guard direct service calls; HTTP already uses exact generated schemas.
    if(!/^[0-9a-f]{64}$/.test(input.installation_secret) || !['session','revoke'].includes(input.operation) ||
       (input.operation==='session'&&!['android','ios'].includes(input.platform))) throw new CommandRejection('VALIDATION_FAILED');
    const snapshot={...input};
    let client:PoolClient;try{client=await options.pool.connect();}catch{throw new TransactionUnavailable('PROVIDER_UNAVAILABLE');}
    let poisoned=false,committing=false;
    try {
      await beginRestrictedTransaction(client,null);
      const principal=await resolvePrincipal(client,authSubject);
      await client.query("SELECT set_config('rounds.principal_id',$1,true)",[principal]);
      // Global self identity, not a membership/job grant or onboarding bypass.
      const driver=(await client.query<{id:string}>('SELECT id FROM rounds.drivers WHERE principal_id=$1 AND archived_at IS NULL',[principal])).rows[0];
      if(!driver)throw new CommandRejection('NOT_AUTHORIZED');
      // Serializes only credential lifecycle/rate admission for this principal.
      // Never takes the global driver row lock ahead of a device permission lock.
      await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1,0))",['device-registration:'+principal]);
      const key=installationKey(principal,snapshot.installation_secret);
      let row=(await client.query<DeviceRow>(`SELECT id,platform,session_epoch,version,revoked_at,archived_at
        FROM rounds.driver_devices WHERE driver_id=$1 AND device_key=$2 FOR UPDATE`,[driver.id,key])).rows[0];
      // Recheck after waiting; device before global driver is the pickup order.
      if(!(await client.query('SELECT id FROM rounds.drivers WHERE id=$1 AND archived_at IS NULL FOR SHARE',[driver.id])).rowCount)
        throw new CommandRejection('NOT_AUTHORIZED');
      let result:Wire_DriverDeviceSessionResult|Wire_DriverDeviceRevokeResult;
      if(snapshot.operation==='revoke') {
        if(!row)throw new CommandRejection('NOT_AUTHORIZED');
        if(!row.revoked_at) {
          if(!Number.isSafeInteger(Number(row.session_epoch)) || Number(row.session_epoch)>=Number.MAX_SAFE_INTEGER)throw new CommandRejection('UPGRADE_REQUIRED');
          row=(await client.query<DeviceRow>(`UPDATE rounds.driver_devices SET revoked_at=clock_timestamp(),session_epoch=session_epoch+1,
            version=version+1,updated_at=clock_timestamp() WHERE id=$1 RETURNING id,platform,session_epoch,version,revoked_at,archived_at`,[row.id])).rows[0]!;
          await audit(client,principal,row,'revoked',trace);
        }
        result={device_id:row.id,revoked:true};
      } else {
        if(row && (row.revoked_at || row.archived_at))throw new CommandRejection('NOT_AUTHORIZED');
        if(row && row.platform!==snapshot.platform)throw new CommandRejection('VALIDATION_FAILED');
        if(!row) {
          const rate=await client.query<{n:number}>(`SELECT count(*)::int n FROM rounds.driver_devices WHERE driver_id=$1
            AND device_key LIKE 'v23-install-sha256:%' AND created_at>clock_timestamp()-interval '1 hour'`,[driver.id]);
          // Engineering abuse bound, not an allowed concurrent-device count.
          if(rate.rows[0]!.n>=10)throw new CommandRejection('RATE_LIMITED');
          row=(await client.query<DeviceRow>(`INSERT INTO rounds.driver_devices(driver_id,platform,device_key,last_seen_at)
            VALUES($1,$2,$3,clock_timestamp()) RETURNING id,platform,session_epoch,version,revoked_at,archived_at`,[driver.id,snapshot.platform,key])).rows[0]!;
          await audit(client,principal,row,'registered',trace);
        } else {
          await client.query('UPDATE rounds.driver_devices SET last_seen_at=clock_timestamp(),updated_at=clock_timestamp(),version=version+1 WHERE id=$1',[row.id]);
        }
        const epoch=Number(row.session_epoch),issuedAt=now();
        if(!Number.isSafeInteger(epoch)||epoch<=0)throw new CommandRejection('UPGRADE_REQUIRED');
        const token=options.devices.issue({principalId:principal,authSubject,deviceId:row.id,epoch},issuedAt);
        result={principal_id:principal,device_id:row.id,session_epoch:epoch,device_session:token,expires_at:new Date((issuedAt+900)*1000).toISOString()};
      }
      validateDeviceResult(result,snapshot.operation==='revoke');
      committing=true;await client.query('COMMIT');return result;
    } catch(error) {
      try{await client.query('ROLLBACK');}catch{poisoned=true;}
      if(committing){poisoned=true;throw new TransactionUnavailable('UNKNOWN_RESULT');}
      if(error instanceof CommandRejection)throw error;
      throw new TransactionUnavailable('PROVIDER_UNAVAILABLE');
    } finally {client.release(poisoned);}
  };
}
