import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { requiredBearer, resolvePrincipal, type BearerVerifier } from './authentication.js';
import { beginRestrictedTransaction } from './restricted-transaction.js';
import { boundedCommandJson, pickupHttpError, statusPath } from './pickup-http.js';
import { authorizeIssueCity, authorizeIssueJob, resolveIssuePath, resolvePickupIssueWork } from './resolve-pickup-issue.js';
import { validateResolveIssueRequest, validateResolveIssueResult, validatePickupStatus } from './pickup-validation.js';
import { CommandRejection, CommandTransactionRunner, TransactionUnavailable } from './transaction-runner.js';
import { operationsBoardPath, projectOperationsPickupIssues } from './operations-issue-query.js';
import { authorizeDeliveryBoard, projectDeliveryBoard } from './delivery-board-query.js';
import {authorizeIntakeCity,intakeBodyLimit,saveDeliveryDraftPath,saveDeliveryDraftWork,validateSaveDeliveryDraftRequest,validateSaveDeliveryDraftResult} from './manual-intake.js';
import {manualIntakeWorkspacePath,projectManualIntake} from './manual-intake-query.js';
import {reviewAddressPath,reviewAddressWork,authorizeAddressReview,validateReviewAddressRequest,validateReviewAddressResult} from './review-address.js';

const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
/** Routing hint only: both branches independently enforce identity/capability. */
export function isOperationsIssueRequest(request:Request):boolean{
  const path=new URL(request.url).pathname;
  return path===reviewAddressPath||path===manualIntakeWorkspacePath||path===operationsBoardPath||path===resolveIssuePath||path===saveDeliveryDraftPath||path===statusPath&&!request.headers.has('x-rounds-device-session');
}
export function createOperationsIssueHttp(options:{pool:Pool;verifyBearer:BearerVerifier;origin:string}){
  const runner=new CommandTransactionRunner(options.pool);
  async function principal(subject:string){
    const c=await options.pool.connect();let poisoned=false;
    try{await beginRestrictedTransaction(c,null);const id=await resolvePrincipal(c,subject);await c.query('COMMIT');return id;}
    catch(e){try{await c.query('ROLLBACK');}catch{poisoned=true;}throw e;}
    finally{c.release(poisoned);}
  }
  return async(request:Request):Promise<Response>=>{
    const url=new URL(request.url),origin=request.headers.get('origin'),trace=randomUUID();let response:Response;
    const secure=(r:Response)=>{
      r.headers.set('cache-control','no-store');r.headers.set('x-content-type-options','nosniff');r.headers.set('x-trace-id',trace);
      if(origin===options.origin){r.headers.set('access-control-allow-origin',origin);r.headers.set('vary','Origin');}
      return r;
    };
    try{
      if(origin!==null&&origin!==options.origin)throw new CommandRejection('NOT_AUTHORIZED');
      const review=url.pathname===reviewAddressPath,intake=url.pathname===saveDeliveryDraftPath,post=review||intake||url.pathname===resolveIssuePath,board=url.pathname===operationsBoardPath,workspace=url.pathname===manualIntakeWorkspacePath;
      if(!post&&!board&&!workspace&&url.pathname!==statusPath)throw new CommandRejection('NOT_FOUND');
      if(request.method!==(post?'POST':'GET'))return secure(pickupHttpError('VALIDATION_FAILED',trace,405));
      // This boundary never treats a Driver device token as Operations authority.
      const bearer=requiredBearer(request);
      const body=post?await boundedCommandJson(request,intake||review?intakeBodyLimit:65536):undefined;
      if(post){if(url.search)throw new CommandRejection('VALIDATION_FAILED');if(review)validateReviewAddressRequest(body);else if(intake)validateSaveDeliveryDraftRequest(body);else validateResolveIssueRequest(body);}
      const params=url.searchParams,ids=board||workspace?['tenant_id','city_id']:['entity_id','tenant_id','city_id'];
      const required=workspace?[...ids,'view']:board?[...ids,'view','service_date']:ids;
      const allowed=workspace?[...required,'entity_id']:board?[...required,'display']:required;
      if(!post&&([...params.keys()].some(k=>!allowed.includes(k))||required.some(k=>params.getAll(k).length!==1)||allowed.some(k=>params.getAll(k).length>1)||ids.some(k=>!uuid.test(params.get(k)!))))throw new CommandRejection('VALIDATION_FAILED');
      if(workspace){
        if(params.get('view')!=='manual_intake')throw new CommandRejection('FEATURE_NOT_ENABLED');
        if(params.has('entity_id')&&!uuid.test(params.get('entity_id')!))throw new CommandRejection('VALIDATION_FAILED');
      }
      if(board){
        const date=params.get('service_date')!;
        if(!['pickup_issues','delivery_board'].includes(params.get('view')!))throw new CommandRejection('FEATURE_NOT_ENABLED');
        if(params.has('display')&&params.get('display')!==(params.get('view')==='delivery_board'?'now':'labels'))throw new CommandRejection('VALIDATION_FAILED');
        if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||!Number.isFinite(Date.parse(date+'T00:00:00Z'))||new Date(date+'T00:00:00Z').toISOString().slice(0,10)!==date)throw new CommandRejection('VALIDATION_FAILED');
      }
      const subject=await options.verifyBearer(bearer),actor=await principal(subject);
      const auth={principalId:actor,tenantId:post?(body as any).context.tenant_id:params.get('tenant_id')!,cityId:post?(body as any).context.city_id:params.get('city_id')!};
      const authorize=async(client:Parameters<typeof resolvePrincipal>[0])=>{
        if(await resolvePrincipal(client,subject)!==actor)throw new CommandRejection('NOT_AUTHORIZED');
        if(board&&params.get('view')==='delivery_board')await authorizeDeliveryBoard(client,auth);
        else if(review)await authorizeAddressReview(client,auth);
        else if(intake||workspace)await authorizeIntakeCity(client,auth);
        else if(board||post)await authorizeIssueCity(client,auth);
        else {
          // Admit a status lookup only with an implemented Operations grant;
          // the actual receipt kind is independently authorized below.
          try{await authorizeIssueCity(client,auth);}catch(e){
            if(!(e instanceof CommandRejection)||e.code!=='NOT_AUTHORIZED')throw e;
            try{await authorizeIntakeCity(client,auth);}catch(e){
              if(!(e instanceof CommandRejection)||e.code!=='NOT_AUTHORIZED')throw e;
              await authorizeAddressReview(client,auth);
            }
          }
        }
      };
      if(board||workspace){
        const client=await options.pool.connect();let poisoned=false;
        try{
          await beginRestrictedTransaction(client,auth,true);await authorize(client);
          const result=workspace?await projectManualIntake(client,auth,params.get('entity_id')):params.get('view')==='delivery_board'?
            await projectDeliveryBoard(client,auth,params.get('service_date')!,params.get('display')==='now'):
            await projectOperationsPickupIssues(client,auth,params.get('service_date')!,params.get('display')==='labels');
          await client.query('COMMIT');response=Response.json(result);
        }catch(e){try{await client.query('ROLLBACK');}catch{poisoned=true;}throw e;}
        finally{client.release(poisoned);}
      }else if(post){
        const work=(()=>{if(review){validateReviewAddressRequest(body);return reviewAddressWork(auth,body);}
          if(intake){validateSaveDeliveryDraftRequest(body);return saveDeliveryDraftWork(auth,body);}
          validateResolveIssueRequest(body);return resolvePickupIssueWork(auth,body);})();work.authorize=authorize;
        const outcome=await runner.run(work);if(review)validateReviewAddressResult(outcome.result);else if(intake)validateSaveDeliveryDraftResult(outcome.result);else validateResolveIssueResult(outcome.result);
        response=outcome.result.state==='rejected'?pickupHttpError((outcome.result.error as CommandRejection).code,trace):
          Response.json(outcome.result,{headers:{'x-rounds-replayed':String(outcome.replayed)}});
      }else{
        const result=await runner.status(params.get('entity_id')!,auth,authorize,async(client,receipt)=>{
          if(receipt.commandType==='ReviewAddress'){
            await authorizeAddressReview(client,auth);
            if(receipt.job)throw new CommandRejection('NOT_AUTHORIZED');
            return;
          }
          if(receipt.commandType==='SaveDeliveryDraft'){
            await authorizeIntakeCity(client,auth);
            if(receipt.job)throw new CommandRejection('NOT_AUTHORIZED');
            return;
          }
          if(receipt.commandType!=='ResolveIssue')throw new CommandRejection('NOT_AUTHORIZED');
          await authorizeIssueCity(client,auth);
          if(!receipt.job)throw new CommandRejection('UPGRADE_REQUIRED');
          await authorizeIssueJob(client,auth,receipt.job);
        });
        if(!result)throw new CommandRejection('NOT_FOUND');
        if(result.command_type==='ReviewAddress')validateReviewAddressResult(result);else if(result.command_type==='SaveDeliveryDraft')validateSaveDeliveryDraftResult(result);else validateResolveIssueResult(result);
        if(result.command_id!==params.get('entity_id'))throw new Error('Receipt identity mismatch');
        const value={as_of:new Date().toISOString(),next_cursor:null,data:{result}};validatePickupStatus(value);response=Response.json(value);
      }
    }catch(e){response=pickupHttpError(e instanceof CommandRejection||e instanceof TransactionUnavailable?e.code:'PROVIDER_UNAVAILABLE',trace);}
    return secure(response);
  };
}
