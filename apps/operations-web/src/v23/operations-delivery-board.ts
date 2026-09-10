import type { Wire_OperationsDeliveryBoardQueryResult } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { validDeliveryBoard, validError } from './generated/operations-issue-validation.cjs';
import {validNowClosure} from './dispatch-now-pool';

type Snapshot = Wire_OperationsDeliveryBoardQueryResult;
export type DeliveryBoardScope = Readonly<{principalId:string;tenantId:string;cityId:string;serviceDate:string;sessionEpoch:number}>;
type Session = {principalId:string;sessionEpoch:number;bearer:string};
export class DeliveryBoardError extends Error { constructor(readonly code:string){super(code);} }
const freeze = <T>(value:T):T => {
  if(value&&typeof value==='object'){Object.values(value).forEach(freeze);Object.freeze(value);}return value;
};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const validDate=(v:string)=>/^\d{4}-\d{2}-\d{2}$/.test(v)&&Number.isFinite(Date.parse(v+'T00:00:00Z'))&&new Date(v+'T00:00:00Z').toISOString().slice(0,10)===v;
const validTimezone=(v:string)=>{try{new Intl.DateTimeFormat('en',{timeZone:v});return true;}catch{return false;}};

/** ADR-Q06 read-only browser adapter. No persisted private data, writes, sample
 * fallback, category inference, polling, map rendering or default activation.
 * Host must dispose synchronously on login/tenant/city/date change; every await
 * independently checks the pinned identity epoch to reject late responses. */
export class OperationsDeliveryBoard {
  readonly scope:DeliveryBoardScope;
  #base:string;
  #session:()=>Session|null;
  #fetch:typeof fetch;
  #includeNow:boolean;
  #phase:'idle'|'loading'|'ready'|'failed'|'closed'='idle';
  #snapshot:Snapshot|null=null;
  #error:string|null=null;
  #reading:Promise<void>|null=null;
  #controller:AbortController|null=null;
  #listeners=new Set<()=>void>();
  #dateReaders=new Set<OperationsDeliveryBoard>();
  #detach:()=>void=()=>{};
  #deny:()=>void=()=>this.dispose();
  constructor(options:{baseUrl:string;scope:DeliveryBoardScope;session:()=>Session|null;fetch?:typeof fetch;includeNow?:boolean}){
    const u=new URL(options.baseUrl),s=options.scope;
    if(u.username||u.password||u.search||u.hash||u.pathname!=='/'||u.protocol!=='https:'&&!(u.protocol==='http:'&&['localhost','127.0.0.1','[::1]'].includes(u.hostname)))throw new DeliveryBoardError('INVALID_ORIGIN');
    if(![s.principalId,s.tenantId,s.cityId].every(v=>uuid.test(v))||!validDate(s.serviceDate)||!Number.isSafeInteger(s.sessionEpoch)||s.sessionEpoch<0)throw new DeliveryBoardError('INVALID_SCOPE');
    this.scope=Object.freeze({...s});this.#base=u.origin;this.#session=options.session;
    this.#includeNow=options.includeNow??false;
    this.#fetch=options.fetch??((input,init)=>globalThis.fetch(input,init));
  }
  #live():boolean {
    if(this.#phase==='closed')return false;
    let s:Session|null=null;try{s=this.#session();}catch{/* Deny unavailable Auth state. */}
    if(s?.principalId===this.scope.principalId&&s.sessionEpoch===this.scope.sessionEpoch&&typeof s.bearer==='string'&&s.bearer.length<=8192&&/^[A-Za-z0-9._~-]+$/.test(s.bearer))return true;
    this.dispose();return false;
  }
  #requireLive(){if(!this.#live())throw new DeliveryBoardError('SESSION_CHANGED');}
  get state(){this.#live();return Object.freeze({phase:this.#phase,snapshot:this.#snapshot,errorCode:this.#error,lastKnown:this.#snapshot!==null&&this.#phase!=='ready'});}
  subscribe(listener:()=>void){this.#listeners.add(listener);return()=>this.#listeners.delete(listener);}
  #notify(){for(const fn of this.#listeners)fn();}
  /** A fresh immutable date scope, never an in-place rebase of a cached read.
   * The host owns its date reader; this parent owns the shared login lifetime.
   * No bearer, private cache or request callback is exposed to presentation. */
  forServiceDate(serviceDate:string):OperationsDeliveryBoard {
    this.#requireLive();
    const reader=new OperationsDeliveryBoard({baseUrl:this.#base,scope:{...this.scope,serviceDate},
      session:()=>this.#live()?this.#session():null,fetch:this.#fetch,includeNow:this.#includeNow});
    reader.#deny=()=>this.#deny();
    reader.#detach=()=>this.#dateReaders.delete(reader);
    this.#dateReaders.add(reader);
    return reader;
  }
  dispose(){if(this.#phase==='closed')return;this.#phase='closed';this.#snapshot=null;this.#error=null;this.#controller?.abort();
    for(const reader of this.#dateReaders)reader.dispose();this.#dateReaders.clear();this.#detach();this.#notify();this.#listeners.clear();}
  async #read():Promise<Snapshot>{
    this.#requireLive();const bearer=this.#session()!.bearer,controller=new AbortController();this.#controller=controller;
    const timer=setTimeout(()=>controller.abort(),15000);
    try{
      const params=new URLSearchParams({tenant_id:this.scope.tenantId,city_id:this.scope.cityId,service_date:this.scope.serviceDate,view:'delivery_board'});
      if(this.#includeNow)params.set('display','now');
      const response=await this.#fetch(this.#base+'/v1/queries/Board?'+params,{method:'GET',headers:{authorization:`Bearer ${bearer}`},cache:'no-store',credentials:'omit',redirect:'error',signal:controller.signal});
      this.#requireLive();if([401,403].includes(response.status)){this.#deny();throw new DeliveryBoardError('NOT_AUTHORIZED');}
      if(!response.body)throw new DeliveryBoardError('INVALID_RESPONSE');
      const reader=response.body.getReader(),chunks:Uint8Array[]=[];let size=0;
      try{while(true){const part=await reader.read();this.#requireLive();if(part.done)break;size+=part.value.byteLength;
        if(size>1024*1024)throw new DeliveryBoardError('INVALID_RESPONSE');chunks.push(part.value);}}
      finally{await reader.cancel();}
      const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
      let value:any;try{value=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{throw new DeliveryBoardError('INVALID_RESPONSE');}
      this.#requireLive();
      if(response.status!==200)throw new DeliveryBoardError(validError(value)?value.code:'SOURCE_UNAVAILABLE');
      if(!validDeliveryBoard(value))throw new DeliveryBoardError('INVALID_RESPONSE');
      const data=value.data as Snapshot['data'];
      if(this.#includeNow?(!validNowClosure(data)||!validDate(data.now!.current_service_date)):data.now!==undefined)throw new DeliveryBoardError('INVALID_RESPONSE');
      if(data.principal_id!==this.scope.principalId||data.tenant_id!==this.scope.tenantId||data.city_id!==this.scope.cityId||data.service_date!==this.scope.serviceDate||data.delivery_count!==data.deliveries.length||new Set(data.deliveries.map(d=>d.id)).size!==data.deliveries.length||!validTimezone(data.city.timezone))throw new DeliveryBoardError('INVALID_RESPONSE');
      const old=this.#snapshot;
      if(old&&(Date.parse(value.as_of)<Date.parse(old.as_of)||data.workspace.version<old.data.workspace.version||data.city.version<old.data.city.version))throw new DeliveryBoardError('SOURCE_STALE');
      for(const d of data.deliveries){
        if(d.window.service_date!==this.scope.serviceDate||Date.parse(d.window.ends_at)<=Date.parse(d.window.starts_at)||!validTimezone(d.window.timezone))throw new DeliveryBoardError('INVALID_RESPONSE');
        const previous=old?.data.deliveries.find(p=>p.id===d.id);
        if(previous&&(d.version<previous.version||d.destination_version<previous.destination_version||
          d.planning&&previous.planning&&((d.planning.round_id===previous.planning.round_id&&d.planning.round_version<previous.planning.round_version)||(d.planning.stop_id===previous.planning.stop_id&&d.planning.stop_version<previous.planning.stop_version))))throw new DeliveryBoardError('SOURCE_STALE');
      }
      return freeze(value as Snapshot);
    }finally{clearTimeout(timer);if(this.#controller===controller)this.#controller=null;}
  }
  refresh():Promise<void>{
    this.#requireLive();if(this.#reading)return this.#reading;this.#phase='loading';this.#error=null;
    this.#reading=Promise.resolve().then(async()=>{
      try{const value=await this.#read();this.#requireLive();this.#snapshot=value;this.#phase='ready';}
      catch(e){if(this.#live()){this.#phase='failed';this.#error=e instanceof DeliveryBoardError?e.code:'SOURCE_UNAVAILABLE';}}
      finally{this.#reading=null;this.#notify();}
    });
    this.#notify();return this.#reading!;
  }
}
