import type { IncomingMessage, ServerResponse } from 'node:http';
import { commandBodyLimit, pickupHttpError, pickupPath, handoffPath, arrivalPath, statusPath } from './pickup-http.js';
import { deviceBodyLimit, isDevicePath } from './device-registration-http.js';
import { driverRoundPath } from './driver-execution-query.js';
import { operationsBoardPath } from './operations-issue-query.js';
import { reserveAssetPath, verifyAssetPath } from './pod-assets.js';
import { submitProofPath, completeDeliveryPath } from './complete-local-delivery.js';
import { podUploadPath } from './pod-upload-capability.js';
import { podMaxBytes } from './pickup-validation.js';
import { reportIssuePath } from './report-local-pickup-issue.js';
import { resolveIssuePath } from './resolve-pickup-issue.js';
import {saveDeliveryDraftPath,intakeBodyLimit} from './manual-intake.js';
import {manualIntakeWorkspacePath} from './manual-intake-query.js';
import {reviewAddressPath} from './review-address.js';

export const isV23Path=(path:string):boolean=>path===reviewAddressPath||path===manualIntakeWorkspacePath||path===saveDeliveryDraftPath||path===operationsBoardPath||path===resolveIssuePath||path===reportIssuePath||path===podUploadPath||path===pickupPath||path===handoffPath||path===arrivalPath||path===reserveAssetPath||path===verifyAssetPath||path===submitProofPath||path===completeDeliveryPath||path===statusPath||path===driverRoundPath||isDevicePath(path);

/** Local-process admission protection. A shared edge limiter is a release gate. */
export function ingressLimiter(limit=120,windowMs=60000,maxKeys=1024) {
  const windows=new Map<string,{count:number;until:number}>();
  return (key:string,now=Date.now()):boolean=>{
    for(const [id,entry]of windows)if(entry.until<=now)windows.delete(id);
    let window=windows.get(key);
    if(!window){if(windows.size>=maxKeys)return false;window={count:0,until:now+windowMs};windows.set(key,window);}
    if(window.count>=limit)return false;
    window.count++;return true;
  };
}
function body(request:IncomingMessage,limit:number,timeout=10000):Promise<Buffer> {
  return new Promise((resolve,reject)=>{
    const chunks:Buffer[]=[];let size=0;
    const cleanup=()=>{clearTimeout(timer);request.off('data',data);request.off('end',end);request.off('error',fail);request.off('aborted',aborted);};
    const fail=()=>{cleanup();request.pause();reject(new Error('Invalid bounded body'));};
    const aborted=()=>fail();
    const data=(chunk:Buffer)=>{size+=chunk.length;if(size>limit){fail();return;}chunks.push(chunk);};
    const end=()=>{cleanup();resolve(Buffer.concat(chunks));};
    const timer=setTimeout(fail,timeout);
    request.on('data',data);request.once('end',end);request.once('error',fail);request.once('aborted',aborted);
  });
}
export function createV23NodeBoundary(options:{handler?:((request:Request)=>Promise<Response>)|undefined;origin:string}) {
  const admit=ingressLimiter();
  let activeUploads=0;
  return async(request:IncomingMessage,response:ServerResponse):Promise<boolean>=>{
    const url=new URL(request.url??'/', 'http://rounds.internal');
    if(!isV23Path(url.pathname))return false;
    const send=async(result:Response,close=false)=>{
      response.statusCode=result.status;result.headers.forEach((value,key)=>response.setHeader(key,value));
      if(close)response.setHeader('connection','close');
      response.end(Buffer.from(await result.arrayBuffer()));
    };
    if(!options.handler){await send(pickupHttpError('FEATURE_NOT_ENABLED'),true);return true;}
    if(!admit(request.socket.remoteAddress??'unknown')){await send(pickupHttpError('RATE_LIMITED'),true);return true;}
    const upload=url.pathname===podUploadPath;
    if(upload && (request.method!=='PUT' || request.headers.origin || request.headers.authorization || request.headers.cookie || request.headers['x-rounds-device-session'] || request.headers['content-encoding'])) {
      await send(pickupHttpError('NOT_AUTHORIZED'),true);return true;
    }
    if(upload && activeUploads>=2){await send(pickupHttpError('RATE_LIMITED'),true);return true;}
    const origin=request.headers.origin;
    if(origin && origin!==options.origin){await send(pickupHttpError('NOT_AUTHORIZED'),true);return true;}
    if(request.method==='OPTIONS'){
      const method=request.headers['access-control-request-method'];
      const headers=(request.headers['access-control-request-headers']??'').toString().toLowerCase().split(',').map(x=>x.trim()).filter(Boolean);
      if(origin!==options.origin || method!==([statusPath,driverRoundPath,operationsBoardPath,manualIntakeWorkspacePath].includes(url.pathname)?'GET':'POST') || headers.some(h=>!['authorization','content-type','x-rounds-device-session'].includes(h))) {
        await send(pickupHttpError('NOT_AUTHORIZED'),true);return true;
      }
      response.writeHead(204,{'access-control-allow-origin':origin,'access-control-allow-methods':'GET, POST, OPTIONS',
        'access-control-allow-headers':'authorization, content-type, x-rounds-device-session','access-control-max-age':'600',vary:'Origin','cache-control':'no-store'}).end();return true;
    }
    if(upload)activeUploads++;
    let data:Buffer|undefined;
    const controller=new AbortController();
    const disconnected=()=>controller.abort();
    response.once('close',disconnected);
    try {
      const singleton=['authorization','x-rounds-device-session','content-type','content-length','origin'];
      for(const header of singleton)if(request.rawHeaders.filter((v,i)=>i%2===0&&v.toLowerCase()===header).length>1)throw new Error('Duplicate header');
      const limit=upload?podMaxBytes:isDevicePath(url.pathname)?deviceBodyLimit:[saveDeliveryDraftPath,reviewAddressPath].includes(url.pathname)?intakeBodyLimit:url.pathname===resolveIssuePath?65536:commandBodyLimit;
      if(request.headers['content-length'] && Number(request.headers['content-length'])>limit)throw new Error('Body limit');
      data=await body(request,limit,upload?30000:10000);
      if((request.method==='GET'||request.method==='HEAD')&&data.length)throw new Error('Unexpected query body');
      const headers=new Headers();for(const [key,value]of Object.entries(request.headers))if(value!==undefined)headers.set(key,Array.isArray(value)?value.join(','):value);
      await send(await options.handler(new Request(url,{method:request.method??'GET',headers,signal:controller.signal,...(data.length?{body:new Uint8Array(data)}:{} )})));
    } catch {await send(pickupHttpError('VALIDATION_FAILED'),true);}
    finally {if(upload){activeUploads--;data?.fill(0);}response.off('close',disconnected);}
    return true;
  };
}
