import { createCommandPool } from './command-pool.js';
import { supabaseBearerVerifier } from './authentication.js';
import { deviceSessions } from './device-session.js';
import { createPickupHttp } from './pickup-http.js';
import { createDeviceRegistrationHttp,isDevicePath } from './device-registration-http.js';
import { createDriverExecutionHttp,driverRoundPath } from './driver-execution-query.js';
import { configuredPodStorage } from './supabase-pod-storage.js';
import { createPodAssets } from './pod-assets.js';
import { podUploadPath } from './pod-upload-capability.js';
import { pickupHttpError } from './pickup-http.js';
import { createOperationsIssueHttp,isOperationsIssueRequest } from './operations-issue-http.js';

/** Explicit isolated-local opt-in only. No existing env/legacy secret fallback. */
export function createV23Runtime(env:NodeJS.ProcessEnv,origin:string):{handler:(request:Request)=>Promise<Response>;close:()=>Promise<void>}|undefined {
  const mode=env.ROUNDS_V23_HTTP_MODE;
  if(!mode || mode==='disabled')return undefined;
  if(mode!=='isolated' || env.APP_ENV!=='local')throw new Error('V2.3 HTTP is gated to isolated local development');
  const databaseUrl=env.ROUNDS_V23_COMMAND_DATABASE_URL??'';
  let database:URL;try{database=new URL(databaseUrl);}catch{throw new Error('Explicit isolated command database required');}
  if(!['127.0.0.1','[::1]'].includes(database.hostname))throw new Error('Isolated mode requires a loopback database');
  const secret=env.ROUNDS_V23_DEVICE_SESSION_KEY??'',id=env.ROUNDS_V23_DEVICE_SESSION_KEY_ID??'';
  if(!/^[0-9a-fA-F]{64}$/.test(secret))throw new Error('Dedicated random 32-byte device session key required');
  const devices=deviceSessions({id,secret:Buffer.from(secret,'hex')});
  const verifyBearer=supabaseBearerVerifier(env.SUPABASE_URL??'',env.SUPABASE_PUBLISHABLE_KEY??'');
  const pod=configuredPodStorage(env);
  const pool=createCommandPool({databaseUrl,allowLocalPlaintext:true,onIdleConnectionFailure:()=>{console.error('V23_DB_IDLE_FAILURE');}});
  const pickup=createPickupHttp({pool,verifyBearer,devices,origin,...(pod?{assets:createPodAssets(pool,pod.store,pod.retentionClass)}:{})});
  const registration=createDeviceRegistrationHttp({pool,verifyBearer,devices,origin});
  const execution=createDriverExecutionHttp({pool,verifyBearer,devices,origin});
  const operations=createOperationsIssueHttp({pool,verifyBearer,origin});
  return {handler:request=>isOperationsIssueRequest(request)?operations(request):new URL(request.url).pathname===podUploadPath?pod?pod.upload(request):Promise.resolve(pickupHttpError('FEATURE_NOT_ENABLED')):new URL(request.url).pathname===driverRoundPath?execution(request):isDevicePath(new URL(request.url).pathname)?registration(request):pickup(request),close:()=>pool.end()};
}
