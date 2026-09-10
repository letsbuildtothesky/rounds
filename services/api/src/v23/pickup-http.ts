import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { authorizeDeviceSession, requiredBearer, type BearerVerifier } from './authentication.js';
import { deviceSessions, type DeviceSession } from './device-session.js';
import { localPickupWork } from './confirm-local-pickup.js';
import { localHandoffWork } from './record-local-handoff.js';
import { localArrivalWork } from './confirm-local-arrival.js';
import { authorizeTeamPickupCity, authorizeTeamPickupJob } from './pickup-authorization.js';
import { validateArrivalRequest, validatePickupRequest, validateHandoffRequest, validateExecutionResult, validatePickupStatus, validateWireError } from './pickup-validation.js';
import { CommandRejection, CommandTransactionRunner, TransactionUnavailable, type CommandAuthority } from './transaction-runner.js';
import type { V23ErrorCode } from '../../../../packages/contracts/src/v23/command-metadata.js';
import { createPodAssets, reserveAssetPath, verifyAssetPath } from './pod-assets.js';
import { validateReserveAssetRequest, validateVerifyAssetRequest } from './pickup-validation.js';
import { localProofWork, submitProofPath, completeDeliveryPath } from './complete-local-delivery.js';
import { validateProofRequest, validateCompleteRequest } from './pickup-validation.js';
import { validateIssueRequest } from './pickup-validation.js';
import { localPickupIssueWork, reportIssuePath } from './report-local-pickup-issue.js';

export const pickupPath='/v1/commands/ConfirmPickup';
export const handoffPath='/v1/commands/RecordHandoff';
export const arrivalPath='/v1/commands/ConfirmArrival';
export const statusPath='/v1/queries/CommandStatus';
export const commandBodyLimit=1024*1024;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const statusFor=(code:V23ErrorCode):number=> {
  if(code==='UNAUTHENTICATED')return 401;
  if(code==='NOT_AUTHORIZED'||code==='FEATURE_NOT_ENABLED')return 403;
  if(code==='NOT_FOUND')return 404;
  if(code==='RATE_LIMITED')return 429;
  if(code==='UNKNOWN_RESULT'||code==='PROVIDER_UNAVAILABLE')return 503;
  if(['STALE_VERSION','IDEMPOTENCY_CONFLICT','EXECUTION_FENCE_CHANGED'].includes(code))return 409;
  if(code==='VALIDATION_FAILED')return 400;
  return 422;
};
function reply(status:number,body:unknown,trace:string,extra:Record<string,string>={}):Response {
  return Response.json(body,{status,headers:{'cache-control':'no-store','x-content-type-options':'nosniff','x-trace-id':trace,...extra}});
}
export function pickupHttpError(code:V23ErrorCode,trace=randomUUID(),status=statusFor(code)):Response {
  const error={code,message_key:`errors.${code.toLowerCase()}`,retryable:['RATE_LIMITED','PROVIDER_UNAVAILABLE','UNKNOWN_RESULT'].includes(code),trace_id:trace};
  validateWireError(error);
  return reply(status,error,trace,code==='RATE_LIMITED'?{'retry-after':'60'}:{});
}
export async function boundedCommandJson(request:Request,limit=commandBodyLimit):Promise<unknown> {
  if(!/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(request.headers.get('content-type')??'') ||
    (request.headers.has('content-encoding') && request.headers.get('content-encoding')!=='identity')) throw new CommandRejection('VALIDATION_FAILED');
  const length=request.headers.get('content-length');
  if(length!==null && (!/^\d+$/.test(length)||Number(length)>limit)) throw new CommandRejection('VALIDATION_FAILED');
  const reader=request.body?.getReader(); if(!reader)throw new CommandRejection('VALIDATION_FAILED');
  let size=0;const chunks:Uint8Array[]=[];
  try {
    for(;;){const {value,done}=await reader.read();if(done)break;size+=value.byteLength;if(size>limit)throw new CommandRejection('VALIDATION_FAILED');chunks.push(value);}
    return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(chunks)));
  } catch {throw new CommandRejection('VALIDATION_FAILED');}
  finally {void reader.cancel().catch(()=>{});reader.releaseLock();}
}

export function createPickupHttp(options:{pool:Pool;verifyBearer:BearerVerifier;devices:ReturnType<typeof deviceSessions>;origin:string;now?:()=>number;assets?:ReturnType<typeof createPodAssets>}) {
  const runner=new CommandTransactionRunner(options.pool),now=options.now??(()=>Math.floor(Date.now()/1000));
  async function session(request:Request):Promise<DeviceSession> {
    const bearer=requiredBearer(request);
    const device=request.headers.get('x-rounds-device-session');
    if(!device || device.length>2048) throw new CommandRejection('UNAUTHENTICATED');
    const subject=await options.verifyBearer(bearer);
    return options.devices.verify(device,subject,now());
  }
  return async(request:Request):Promise<Response>=>{
    const trace=randomUUID(),url=new URL(request.url),origin=request.headers.get('origin');
    if(origin!==null && origin!==options.origin)return pickupHttpError('NOT_AUTHORIZED',trace);
    let result:Response;
    try {
      const pickup=url.pathname===pickupPath;
      const handoff=url.pathname===handoffPath;
      const arrival=url.pathname===arrivalPath;
      const issue=url.pathname===reportIssuePath;
      const reserve=url.pathname===reserveAssetPath,verify=url.pathname===verifyAssetPath;
      const proof=url.pathname===submitProofPath,complete=url.pathname===completeDeliveryPath;
      if(!pickup && !handoff && !arrival && !issue && !reserve && !verify && !proof && !complete && url.pathname!==statusPath)return pickupHttpError('NOT_FOUND',trace);
      if((reserve||verify)&&!options.assets)return pickupHttpError('FEATURE_NOT_ENABLED',trace);
      if(request.method!==((pickup||handoff||arrival||issue||reserve||verify||proof||complete)?'POST':'GET'))return pickupHttpError('VALIDATION_FAILED',trace,405);
      const authenticated=await session(request);
      if(reserve||verify){
        if(url.search)throw new CommandRejection('VALIDATION_FAILED');
        const body=await boundedCommandJson(request);
        const authorize=async(client:Parameters<typeof authorizeDeviceSession>[0],auth:CommandAuthority)=>authorizeDeviceSession(client,auth,authenticated,now());
        const outcome=await (async()=>{
          if(reserve){validateReserveAssetRequest(body);return options.assets!.reserve({principalId:authenticated.principalId,tenantId:body.context.tenant_id,cityId:body.context.city_id!},body,authorize);}
          validateVerifyAssetRequest(body);return options.assets!.verify({principalId:authenticated.principalId,tenantId:body.context.tenant_id,cityId:body.context.city_id!},body,authorize);
        })();
        validateExecutionResult(outcome.result);
        result=outcome.result.state==='rejected'?reply(statusFor((outcome.result.error as {code:V23ErrorCode}).code),outcome.result.error,trace):reply(200,outcome.result,trace,{'x-rounds-replayed':String(outcome.replayed)});
      }else if(pickup||handoff||arrival||issue||proof||complete){
        if(url.search)throw new CommandRejection('VALIDATION_FAILED');
        const body=await boundedCommandJson(request);
        // Each factory validates its own exact generated request contract.
        const work = (()=>{
          if(issue){validateIssueRequest(body);return localPickupIssueWork({principalId:authenticated.principalId,tenantId:body.context.tenant_id,cityId:body.context.city_id!},body);}
          if(proof){validateProofRequest(body);return localProofWork({principalId:authenticated.principalId,tenantId:body.context.tenant_id,cityId:body.context.city_id!},body);}
          if(complete){validateCompleteRequest(body);return localProofWork({principalId:authenticated.principalId,tenantId:body.context.tenant_id,cityId:body.context.city_id!},body,true);}
          if (arrival) {
            validateArrivalRequest(body);
            return localArrivalWork({principalId:authenticated.principalId,tenantId:body.context.tenant_id,cityId:body.context.city_id!},body);
          }
          if (handoff) {
            validateHandoffRequest(body);
            return localHandoffWork({principalId:authenticated.principalId,tenantId:body.context.tenant_id,cityId:body.context.city_id!},body);
          }
          validatePickupRequest(body);
          return localPickupWork({principalId:authenticated.principalId,tenantId:body.context.tenant_id,cityId:body.context.city_id!},body);
        })();
        const authorize=work.authorize;
        work.authorize=async(client,auth)=>{await authorizeDeviceSession(client,auth,authenticated,now());await authorize(client,auth);};
        const {result:receipt,replayed}=await runner.run(work);validateExecutionResult(receipt);
        if(receipt.command_id!==work.request.command_id)throw new Error('Invalid stored result identity');
        result=receipt.state==='rejected'
          ? reply(statusFor((receipt.error as {code:V23ErrorCode}).code),receipt.error,trace)
          : reply(200,receipt,trace,{'x-rounds-replayed':String(replayed)});
      } else {
        const params=url.searchParams,allowed=['entity_id','tenant_id','city_id'];
        if([...params.keys()].some(k=>!allowed.includes(k)) || allowed.some(k=>params.getAll(k).length!==1 || !uuid.test(params.get(k)!))) throw new CommandRejection('VALIDATION_FAILED');
        const authority:CommandAuthority={principalId:authenticated.principalId,tenantId:params.get('tenant_id')!,cityId:params.get('city_id')!};
        const commandId=params.get('entity_id')!;
        let receipt=await runner.status(commandId,authority,async(client,auth)=>{
          await authorizeDeviceSession(client,auth,authenticated,now());await authorizeTeamPickupCity(client,auth);
        },async(client,receipt)=>{
          if(!['ConfirmPickup','ConfirmArrival','RecordHandoff','SubmitProof','CompleteDelivery','ReportIssue',...(options.assets?['ReserveAsset','VerifyAsset']:[])].includes(receipt.commandType))throw new CommandRejection('FEATURE_NOT_ENABLED');
          if(!receipt.job)throw new CommandRejection('UPGRADE_REQUIRED');
          await authorizeTeamPickupJob(client,authority,receipt.job.roundId,receipt.job.assignmentId);
        });
        if(!receipt)throw new CommandRejection('NOT_FOUND');
        if(receipt.command_type==='ReserveAsset')receipt=await options.assets!.hydrate(receipt,authority,async(client,auth)=>authorizeDeviceSession(client,auth,authenticated,now()));
        validateExecutionResult(receipt);
        if(receipt.command_id!==commandId)throw new Error('Invalid stored result identity');
        const body={as_of:new Date(now()*1000).toISOString(),data:{result:receipt},next_cursor:null};validatePickupStatus(body);
        result=reply(200,body,trace);
      }
    } catch(error) {
      result=pickupHttpError(error instanceof CommandRejection || error instanceof TransactionUnavailable ? error.code:'PROVIDER_UNAVAILABLE',trace);
    }
    if(origin===options.origin){result.headers.set('access-control-allow-origin',origin);result.headers.set('vary','origin');}
    return result;
  };
}
