import { createHmac, timingSafeEqual } from 'node:crypto';
import { CommandRejection } from './transaction-runner.js';

const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
export type DeviceSession = Readonly<{purpose:'rounds.driver.v23';kid:string;principalId:string;authSubject:string;deviceId:string;epoch:number;iat:number;exp:number}>;
export type DeviceSessionKey = Readonly<{id:string;secret:Buffer}>;
const fields=['purpose','kid','principalId','authSubject','deviceId','epoch','iat','exp'].sort();
const invalid=():never=>{throw new CommandRejection('UNAUTHENTICATED');};
function valid(s:DeviceSession,now:number):boolean {
  return s !== null && typeof s==='object' && JSON.stringify(Object.keys(s).sort())===JSON.stringify(fields) &&
    s.purpose==='rounds.driver.v23' && /^[A-Za-z0-9_-]{1,32}$/.test(s.kid) &&
    [s.principalId,s.authSubject,s.deviceId].every(x=>typeof x==='string' && uuid.test(x)) &&
    [s.epoch,s.iat,s.exp].every(Number.isSafeInteger) && s.epoch>0 && s.iat>=0 && s.iat<=now && s.exp>now && s.exp>s.iat && s.exp-s.iat<=900;
}
export function deviceSessions(key:DeviceSessionKey) {
  if (!/^[A-Za-z0-9_-]{1,32}$/.test(key.id) || key.secret.length<32) throw new Error('Dedicated device session key required');
  const secret=Buffer.from(key.secret),kid=key.id;
  const mac=(payload:string)=>createHmac('sha256',secret).update(payload).digest();
  return {
    /** Trusted enrollment service only. No public or demo issuance endpoint. */
    issue(identity:Pick<DeviceSession,'principalId'|'authSubject'|'deviceId'|'epoch'>,now:number):string {
      const session:DeviceSession={...identity,purpose:'rounds.driver.v23',kid,iat:now,exp:now+900};
      if (!valid(session,now)) return invalid();
      const payload=Buffer.from(JSON.stringify(session)).toString('base64url');
      return `${payload}.${mac(payload).toString('base64url')}`;
    },
    verify(token:string,authSubject:string,now:number):DeviceSession {
      if (token.length>2048 || !/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]{43}$/.test(token)) return invalid();
      const [payload,signature]=token.split('.') as [string,string];
      const bytes=Buffer.from(signature,'base64url');
      if (bytes.toString('base64url')!==signature || !timingSafeEqual(bytes,mac(payload))) return invalid();
      let session:DeviceSession;
      try { session=JSON.parse(Buffer.from(payload,'base64url').toString('utf8')) as DeviceSession; } catch { return invalid(); }
      if (!valid(session,now) || session.kid!==kid || session.authSubject!==authSubject) return invalid();
      return Object.freeze(session);
    },
  };
}
