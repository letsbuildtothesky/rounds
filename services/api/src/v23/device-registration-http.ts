import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { requiredBearer, type BearerVerifier } from './authentication.js';
import type { deviceSessions } from './device-session.js';
import { deviceRegistration } from './device-registration.js';
import { boundedCommandJson, pickupHttpError } from './pickup-http.js';
import { validateDeviceRevokeRequest, validateDeviceSessionRequest } from './pickup-validation.js';
import { CommandRejection, TransactionUnavailable } from './transaction-runner.js';

export const deviceSessionPath='/v1/auth/driver-device/session';
export const deviceRevokePath='/v1/auth/driver-device/revoke';
export const deviceBodyLimit=4096;
export const isDevicePath=(path:string):boolean=>path===deviceSessionPath||path===deviceRevokePath;

export function createDeviceRegistrationHttp(options:{pool:Pool;verifyBearer:BearerVerifier;devices:ReturnType<typeof deviceSessions>;origin:string;now?:()=>number}) {
  const execute=deviceRegistration(options);
  return async(request:Request):Promise<Response>=>{
    const trace=randomUUID(),url=new URL(request.url),origin=request.headers.get('origin');
    let response:Response;
    try {
      if(origin!==null&&origin!==options.origin)throw new CommandRejection('NOT_AUTHORIZED');
      if(!isDevicePath(url.pathname))throw new CommandRejection('NOT_FOUND');
      if(request.method!=='POST')return pickupHttpError('VALIDATION_FAILED',trace,405);
      if(url.search)throw new CommandRejection('VALIDATION_FAILED');
      const bearer=requiredBearer(request),body=await boundedCommandJson(request,deviceBodyLimit);
      // Validate before provider work; subject still comes only from verification.
      const revoke=url.pathname===deviceRevokePath;
      if(revoke)validateDeviceRevokeRequest(body);else validateDeviceSessionRequest(body);
      const subject=await options.verifyBearer(bearer);
      const result=await execute(subject,revoke?{operation:'revoke',...(body as {installation_secret:string})}:
        {operation:'session',...(body as {installation_secret:string;platform:'ios'|'android'})},trace);
      response=Response.json(result,{headers:{'cache-control':'no-store','x-content-type-options':'nosniff','x-trace-id':trace}});
    }catch(error){response=pickupHttpError(error instanceof CommandRejection||error instanceof TransactionUnavailable?error.code:'PROVIDER_UNAVAILABLE',trace);}
    if(origin===options.origin){response.headers.set('access-control-allow-origin',origin);response.headers.set('vary','Origin');}
    return response;
  };
}
