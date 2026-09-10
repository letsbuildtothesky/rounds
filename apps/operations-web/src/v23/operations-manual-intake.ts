import type {Wire_delivery_draft,Wire_SaveDeliveryDraftRequest,Wire_OperationsManualIntakeQueryResult} from '../../../../packages/contracts/src/v23/pickup-wire';
import {validIntake,validDraftRequest,validDraftResult,validCommandStatus,validRejected,validError} from './generated/operations-issue-validation.cjs';
import {OperationsIssueRecovery,type TabStorage} from './operations-issue-recovery';

type Scope=Readonly<{principalId:string;tenantId:string;cityId:string;sessionEpoch:number}>;
type Session={principalId:string;sessionEpoch:number;bearer:string};
type Context=Wire_OperationsManualIntakeQueryResult['data'];
type Root={id:string;version:number};
type Journal={version:1;draft:Wire_delivery_draft;productText:string;root:Root|null;saved:Wire_delivery_draft|null;pending:Wire_SaveDeliveryDraftRequest|null};
const copy=<T>(v:T):T=>JSON.parse(JSON.stringify(v));
const equal=(a:unknown,b:unknown):boolean=>{
  const canonical=(x:any):any=>Array.isArray(x)?x.map(canonical):x&&typeof x==='object'?Object.fromEntries(Object.keys(x).sort().map(k=>[k,canonical(x[k])])):x;
  return JSON.stringify(canonical(a))===JSON.stringify(canonical(b));
};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
export class ManualIntakeError extends Error{constructor(readonly code:string){super(code);}}
const fail=(code:string):never=>{throw new ManualIntakeError(code);};

/** One tab/login/city draft, not a created order. Fresh authority before local
 * hydration; journal-before-send; frozen same-ID status/retry; no cached grant. */
export class OperationsManualIntake{
  readonly scope:Scope;
  #origin:string;#session:()=>Session|null;#fetch:typeof fetch;#login:()=>string|null;#loginId:string;
  #journal:OperationsIssueRecovery;#value:Journal|null=null;#loaded=false;
  #phase:'idle'|'loading'|'ready'|'saving'|'failed'|'closed'='idle';#error:string|null=null;
  #context:Context|null=null;#busy:Promise<void>|null=null;#abort:AbortController|null=null;
  #listeners=new Set<()=>void>();
  constructor(o:{baseUrl:string;scope:Scope;session:()=>Session|null;fetch?:typeof fetch;recovery:{storage:TabStorage;loginId:string;currentLoginId:()=>string|null}}){
    const u=new URL(o.baseUrl);
    if(u.username||u.password||u.search||u.hash||u.pathname!=='/'||u.protocol!=='https:'&&!(u.protocol==='http:'&&['localhost','127.0.0.1','[::1]'].includes(u.hostname)))fail('INVALID_ORIGIN');
    if(![o.scope.principalId,o.scope.tenantId,o.scope.cityId].every(x=>uuid.test(x))||!Number.isSafeInteger(o.scope.sessionEpoch)||o.scope.sessionEpoch<0)fail('INVALID_SCOPE');
    this.scope=Object.freeze({...o.scope});this.#origin=u.origin;this.#session=o.session;this.#fetch=o.fetch??((...a)=>fetch(...a));
    this.#loginId=o.recovery.loginId;this.#login=o.recovery.currentLoginId;
    this.#journal=new OperationsIssueRecovery(o.recovery.storage,JSON.stringify([u.origin,o.scope.principalId,o.scope.tenantId,o.scope.cityId]),this.#loginId,'manual-intake');
  }
  #live(){
    let s:Session|null=null;try{s=this.#session();}catch{/* Failed Auth is closed. */}
    if(this.#phase==='closed'||this.#login()!==this.#loginId||s?.principalId!==this.scope.principalId||s.sessionEpoch!==this.scope.sessionEpoch||!s.bearer||s.bearer.length>8192||!/^[A-Za-z0-9._~-]+$/.test(s.bearer)){
      this.dispose();fail('SESSION_CHANGED');
    }
    return s!;
  }
  get state(){try{this.#live();}catch{/* Expose only the cleared closed state. */}return copy({phase:this.#phase,errorCode:this.#error,context:this.#context,draft:this.#value?.draft??null,
    productText:this.#value?.productText??'',pending:!!this.#value?.pending,dirty:!!this.#value&&!equal(this.#value.draft,this.#value.saved)});}
  subscribe(fn:()=>void){this.#listeners.add(fn);return()=>{this.#listeners.delete(fn);};}
  #notify(){for(const fn of this.#listeners)fn();}
  dispose(){if(this.#phase==='closed')return;this.#phase='closed';this.#context=null;this.#value=null;this.#abort?.abort();this.#notify();this.#listeners.clear();}
  #write(v:Journal){this.#live();this.#journal.write(v);this.#value=copy(v);}
  #request(draft:Wire_delivery_draft,root:Root|null):Wire_SaveDeliveryDraftRequest{return {command_id:crypto.randomUUID(),
    context:{tenant_id:this.scope.tenantId,city_id:this.scope.cityId},occurred_at:new Date().toISOString(),
    expected_versions:root?[{aggregate_type:'intake_drafts',...root}]:[],payload:{draft_id:root?.id??null,draft}};}
  #validateDraft(d:Wire_delivery_draft){if(!validDraftRequest(this.#request(d,null))||d.city_id!=null&&d.city_id!==this.scope.cityId)fail('VALIDATION_FAILED');}
  async #http(path:string,body?:unknown){
    const s=this.#live(),a=new AbortController();this.#abort=a;const timer=setTimeout(()=>a.abort(),15000);
    try{
      const r=await this.#fetch(this.#origin+path,{method:body?'POST':'GET',headers:{authorization:'Bearer '+s.bearer,...(body?{'content-type':'application/json'}:{})},
        ...(body?{body:JSON.stringify(body)}:{}),credentials:'omit',redirect:'error',cache:'no-store',signal:a.signal});
      this.#live();if([401,403].includes(r.status)){this.dispose();fail('NOT_AUTHORIZED');}
      if(!r.body)fail('INVALID_RESPONSE');const reader=r.body!.getReader(),chunks:Uint8Array[]=[];let length=0;
      try{while(true){const p=await reader.read();this.#live();if(p.done)break;length+=p.value.length;if(length>1024*1024)fail('INVALID_RESPONSE');chunks.push(p.value);}}finally{await reader.cancel();}
      const bytes=new Uint8Array(length);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}
      let value:any;try{value=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{fail('INVALID_RESPONSE');}
      this.#live();return {status:r.status,value};
    }finally{clearTimeout(timer);if(this.#abort===a)this.#abort=null;}
  }
  async #read(id:string|null){
    const q=new URLSearchParams({view:'manual_intake',tenant_id:this.scope.tenantId,city_id:this.scope.cityId});
    if(id)q.set('entity_id',id);
    const r=await this.#http('/v1/queries/Workspace?'+q);
    if(r.status!==200)fail(validError(r.value)?r.value.code:'SOURCE_UNAVAILABLE');
    if(!validIntake(r.value))fail('INVALID_RESPONSE');
    const d=r.value.data as Context;
    if(d.principal_id!==this.scope.principalId||d.tenant_id!==this.scope.tenantId||d.city_id!==this.scope.cityId||d.city.id!==this.scope.cityId||
      (id?d.draft?.id!==id:d.draft!==null)||new Set(d.sites.map(x=>x.id)).size!==d.sites.length)fail('INVALID_RESPONSE');
    try{new Intl.DateTimeFormat('en',{timeZone:d.city.timezone});}catch{fail('INVALID_RESPONSE');}
    return d;
  }
  #run(phase:'loading'|'saving',fn:()=>Promise<void>):Promise<void>{
    this.#live();if(this.#busy)return this.#busy;this.#phase=phase;this.#error=null;
    this.#busy=Promise.resolve().then(fn).then(()=>{this.#live();this.#phase='ready';}).catch(e=>{
      if(this.#phase!=='closed'){this.#phase='failed';this.#error=e instanceof Error?e.message:'SOURCE_UNAVAILABLE';}
    }).finally(()=>{this.#busy=null;this.#notify();});this.#notify();return this.#busy;
  }
  open(){return this.#run('loading',async()=>{
    // Never reveal a cached private form before a fresh permitted context.
    this.#context=await this.#read(null);
    if(!this.#loaded){
      const v=this.#journal.read() as Journal|null;
      if(v){
        if(Object.keys(v).sort().join(',')!=='draft,pending,productText,root,saved,version'||v.version!==1||typeof v.productText!=='string'||v.productText.length>500)fail('RECOVERY_CORRUPT');
        this.#validateDraft(v.draft);if(v.saved)this.#validateDraft(v.saved);
        if(v.root&&(Object.keys(v.root).sort().join(',')!=='id,version'||!uuid.test(v.root.id)||!Number.isSafeInteger(v.root.version)||v.root.version<1))fail('RECOVERY_CORRUPT');
        if(v.pending&&(!validDraftRequest(v.pending)||v.pending.context.tenant_id!==this.scope.tenantId||v.pending.context.city_id!==this.scope.cityId||
          v.pending.payload.draft_id!==(v.root?.id??null)||!equal(v.pending.expected_versions,v.root?[{aggregate_type:'intake_drafts',...v.root}]:[])))fail('RECOVERY_CORRUPT');
        this.#value=copy(v);
      }else this.#value={version:1,draft:{city_id:this.scope.cityId,address_text:'',instructions:'',contacts:[],manifest:[],service_date:this.#context.city.current_service_date},
        productText:'',root:null,saved:null,pending:null};
      this.#loaded=true;
    }
    if(this.#value!.pending)await this.#recover(false);
    if(this.#value!.root){
      const fresh=await this.#read(this.#value!.root.id);
      if(fresh.draft!.version!==this.#value!.root.version||!equal(fresh.draft!.payload,this.#value!.saved))fail('STALE_VERSION');
      this.#context=fresh;
    }
  });}
  edit(draft:Wire_delivery_draft,productText=this.#value?.productText??''){
    this.#live();if(!this.#loaded||!this.#context||!this.#value||this.#phase==='loading'||this.#error)fail('FORM_UNAVAILABLE');
    if(productText.length>500)fail('VALIDATION_FAILED');this.#validateDraft(draft);
    try{this.#write({...this.#value!,draft:copy(draft),productText});}catch(e){this.#phase='failed';this.#error=e instanceof Error?e.message:'RECOVERY_UNAVAILABLE';this.#notify();throw e;}
    this.#notify();
  }
  #receipt(result:any){
    const v=this.#value!,pending=v.pending!;
    if(result?.command_id!==pending.command_id||result.command_type!=='SaveDeliveryDraft')fail('INVALID_RESPONSE');
    if(validRejected(result)){this.#write({...v,pending:null});fail(result.error.code);}
    if(!validDraftResult(result))fail('INVALID_RESPONSE');
    const root=result.data.resource;
    if(root.aggregate_type!=='intake_drafts'||!uuid.test(root.id)||!Number.isSafeInteger(root.version)||root.version!==(v.root?v.root.version+1:1)||
      v.root&&root.id!==v.root.id||!equal(result.current_versions,[root])||!equal(result.resources,[root]))fail('INVALID_RESPONSE');
    this.#write({...v,root:{id:root.id,version:root.version},saved:pending.payload.draft,pending:null});
  }
  async #post(){
    const pending=this.#value!.pending!,r=await this.#http('/v1/commands/SaveDeliveryDraft',pending);
    if(r.status===200){this.#receipt(r.value);return;}
    // HTTP error is not evidence of a rejected receipt. Keep exact bytes.
    fail(validError(r.value)?r.value.code:'SOURCE_UNAVAILABLE');
  }
  async #recover(resend:boolean){
    const p=this.#value!.pending!,q=new URLSearchParams({tenant_id:this.scope.tenantId,city_id:this.scope.cityId,entity_id:p.command_id});
    const r=await this.#http('/v1/queries/CommandStatus?'+q);
    if(r.status===200){if(!validCommandStatus(r.value))fail('INVALID_RESPONSE');this.#receipt(r.value.data.result);return;}
    if(r.status===404&&validError(r.value)&&r.value.code==='NOT_FOUND'){if(resend)await this.#post();else fail('PENDING_NOT_RECORDED');return;}
    fail(validError(r.value)?r.value.code:'SOURCE_UNAVAILABLE');
  }
  save(){return this.#run('saving',async()=>{
    if(!this.#loaded||!this.#value||!this.#context)fail('FORM_UNAVAILABLE');
    if(this.#value!.pending){await this.#recover(true);return;}
    const v=this.#value!;
    if(equal(v.draft,v.saved)||!v.root&&!v.draft.contacts.length&&!v.draft.manifest.length&&!v.draft.address_text&&!v.draft.instructions)return;
    const fresh=await this.#read(v.root?.id??null);
    if(v.root&&(fresh.draft!.version!==v.root.version||!equal(fresh.draft!.payload,v.saved)))fail('STALE_VERSION');
    this.#context=fresh;
    const current=this.#value!;
    const pending=this.#request(copy(current.draft),current.root);if(!validDraftRequest(pending))fail('VALIDATION_FAILED');
    this.#write({...current,pending});await this.#post();
  });}
}
