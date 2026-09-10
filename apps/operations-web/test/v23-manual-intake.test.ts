import assert from 'node:assert/strict';
import {test} from 'node:test';
import {randomUUID} from 'node:crypto';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {OperationsManualIntake} from '../src/v23/operations-manual-intake';
import {ManualIntakeForm,intakeProducts} from '../src/v23/manual-intake-form';
import {clearOperationsIssueLogin} from '../src/v23/operations-issue-recovery';

function fixture(){
  const scope={principalId:randomUUID(),tenantId:randomUUID(),cityId:randomUUID(),sessionEpoch:1};
  let session:any={principalId:scope.principalId,sessionEpoch:1,bearer:'test-only'},login=randomUUID(),draft:any=null,receipt:any=null;
  let mode='ready',posts=0,writeFails=false;
  const rows=new Map<string,string>(),calls:{path:string;body?:string}[]=[];
  const storage={getItem:(k:string)=>rows.get(k)??null,setItem:(k:string,v:string)=>{if(writeFails)throw Error('disk');rows.set(k,v);},removeItem:(k:string)=>{rows.delete(k);},
    key:(n:number)=>[...rows.keys()][n]??null,get length(){return rows.size;}};
  const projection=()=>({as_of:'2026-09-10T10:00:00Z',next_cursor:null,data:{view:'manual_intake',principal_id:scope.principalId,tenant_id:scope.tenantId,city_id:scope.cityId,
    city:{id:scope.cityId,name:'Test city',version:1,timezone:'Asia/Bangkok',current_service_date:'2026-09-11'},sites:[],draft}});
  const error=(code:string,status=503)=>Response.json({code,message_key:code,retryable:false,trace_id:'test'},{status});
  let override:((input:RequestInfo|URL,init?:RequestInit)=>Promise<Response>)|null=null;
  const transport:typeof fetch=async(input,init)=>{
    const u=new URL(String(input));calls.push({path:u.pathname,body:typeof init?.body==='string'?init.body:undefined});
    if(override)return override(input,init);
    if(mode==='denied')return error('NOT_AUTHORIZED',403);
    if(mode==='offline')return error('PROVIDER_UNAVAILABLE');
    if(u.pathname.endsWith('/Workspace')){
      const p=projection();if(!u.searchParams.has('entity_id'))p.data.draft=null;
      if(mode==='foreign')p.data.city_id=randomUUID();
      return Response.json(p);
    }
    if(u.pathname.endsWith('/CommandStatus'))return receipt?Response.json({as_of:new Date().toISOString(),next_cursor:null,data:{result:receipt}}):error('NOT_FOUND',404);
    assert.equal(u.pathname,'/v1/commands/SaveDeliveryDraft');posts++;
    const r=JSON.parse(String(init?.body));
    if(mode==='drop-before')throw Error('Network lost');
    const root={aggregate_type:'intake_drafts',id:draft?.id??randomUUID(),version:(draft?.version??0)+1};
    draft={id:root.id,version:root.version,review_state:'draft',payload:r.payload.draft};
    receipt={command_type:'SaveDeliveryDraft',command_id:r.command_id,state:'committed',current_versions:[root],resources:[root],data:{resource:root}};
    if(mode==='drop-after')throw Error('Network lost');
    if(mode==='bad-receipt')return Response.json({...receipt,command_id:randomUUID()});
    return Response.json(receipt);
  };
  const make=()=>new OperationsManualIntake({baseUrl:'https://api.example',scope,session:()=>session,fetch:transport,
    recovery:{storage,loginId:login,currentLoginId:()=>login}});
  return {scope,storage,rows,calls,make,projection,get draft(){return draft;},get posts(){return posts;},mode:(v:string)=>mode=v,
    deny:()=>session=null,relogin:()=>login=randomUUID(),writeFails:()=>writeFails=true,override:(f:typeof override)=>override=f,login:()=>login};
}
const fill=(c:OperationsManualIntake)=>c.edit({...c.state.draft!,address_text:'  Original\naddress  ',contacts:[{role:'recipient',name:'Johannes'}],manifest:intakeProducts('2 × Flowers')},'2 × Flowers');

test('new form reads current city day, no fabricated pickup/window/order; saves only on explicit controller save',async()=>{
  const f=fixture(),c=f.make();const initial=c.state;assert.equal(initial.draft,null);await c.open();assert.equal(c.state.phase,'ready');
  assert.equal(c.state.draft?.service_date,'2026-09-11');assert.equal(c.state.draft?.site_id,undefined);assert.equal(c.state.draft?.window,undefined);
  fill(c);assert.equal(f.posts,0);assert(c.state.dirty);await c.save();assert.equal(c.state.phase,'ready');assert(!c.state.dirty);assert.equal(f.posts,1);
  assert.equal(f.draft.payload.manifest[0].quantity,2);assert.equal(f.draft.payload.address_text,'  Original\naddress  ');
  await c.save();assert.equal(f.posts,1);c.dispose();
});
test('journal before send, original receipt after restart and changed text after save',async()=>{
  const f=fixture();let c=f.make();await c.open();fill(c);f.mode('drop-after');await c.save();assert(c.state.pending);assert.equal(f.posts,1);
  c.dispose();c=f.make();assert.equal(c.state.draft,null);f.mode('ready');await c.open();assert.equal(c.state.phase,'ready',c.state.errorCode??'');
  assert(!c.state.pending);assert(!c.state.dirty);assert.equal(f.posts,1);assert.equal(c.state.productText,'2 × Flowers');
  c.edit({...c.state.draft!,instructions:'new'});await c.save();assert.equal(f.draft.version,2);c.dispose();
});
test('404 status permits only exact frozen resend; 503 does not send a new ID',async()=>{
  const f=fixture(),c=f.make();await c.open();fill(c);f.mode('drop-before');await c.save();assert(c.state.pending);
  const bytes=f.calls.find(x=>x.body)!.body;
  f.mode('offline');await c.save();assert.equal(f.posts,1);
  f.mode('ready');await c.save();assert.equal(f.posts,2);assert.equal(f.calls.filter(x=>x.body).at(-1)!.body,bytes);assert(!c.state.pending);c.dispose();
});
test('storage failure blocks the POST and preserves earlier journal',async()=>{
  const f=fixture(),c=f.make();await c.open();fill(c);const before=[...f.rows.values()][0];f.writeFails();await c.save();
  assert.equal(f.posts,0);assert.equal(c.state.errorCode,'RECOVERY_UNAVAILABLE');assert.equal([...f.rows.values()][0],before);c.dispose();
});
test('corrupt journal and foreign projection cannot expose or send the cached private form',async()=>{
  for(const kind of ['corrupt','foreign','denied']){
    const f=fixture();let c=f.make();await c.open();fill(c);c.dispose();
    if(kind==='corrupt')f.rows.set([...f.rows.keys()][0]!,JSON.stringify({oops:true}));else f.mode(kind);
    c=f.make();await c.open();assert.equal(c.state.draft,null);assert.equal(f.posts,0);c.dispose();
  }
});
test('a stale remote revision cannot silently overwrite another edit or discard local input',async()=>{
  const f=fixture(),c=f.make();await c.open();fill(c);await c.save();c.edit({...c.state.draft!,instructions:'keep my edit'});
  f.draft.version++;await c.save();assert.equal(c.state.errorCode,'STALE_VERSION');assert.equal(c.state.draft?.instructions,'keep my edit');assert.equal(f.posts,1);c.dispose();
});
test('late response after logout cannot restore form data',async()=>{
  const f=fixture(),c=f.make();let finish!:(v:Response)=>void;
  f.override(()=>new Promise(r=>{finish=r;}));const opening=c.open();await new Promise(r=>setImmediate(r));f.deny();
  finish(Response.json(f.projection()));await opening;assert.equal(c.state.phase,'closed');assert.equal(c.state.draft,null);
});
test('receipt mismatch remains pending rather than saying saved',async()=>{
  const f=fixture(),c=f.make();await c.open();fill(c);f.mode('bad-receipt');await c.save();assert(c.state.pending);assert(c.state.dirty);assert.equal(c.state.errorCode,'INVALID_RESPONSE');c.dispose();
});
test('logout erases only this login manual/issue journals, not unrelated data',async()=>{
  const f=fixture(),c=f.make();await c.open();fill(c);f.rows.set('other','preserve');
  clearOperationsIssueLogin(f.storage as Storage,f.login());assert.deepEqual([...f.rows],[['other','preserve']]);c.dispose();
});
test('source product grammar supports explicit quantity proposals, never independent order creation',()=>{
  assert.deepEqual(intakeProducts('2 × Flowers + Cake x3; Card').map(x=>[x.label,x.quantity]),[['Flowers',2],['Cake',3],['Card',1]]);
});
test('source form grouping is retained, optional helpers disabled and Create is never draft success',async()=>{
  const f=fixture(),c=f.make();await c.open();fill(c);
  const html=renderToStaticMarkup(createElement(ManualIntakeForm,{controller:c,open:true,onClose:()=>{}}));
  const labels=['>Recipient<','>Delivery address<','>Product<','>Delivery day<','>Delivery window<','>Phone &amp; delivery instructions<','Ready for pickup'];
  let previous=-1;for(const label of labels){const at=html.indexOf(label);assert(at>previous,label);previous=at;}
  assert.match(html,/<button type="submit"[^>]*disabled=""[^>]*>Create delivery<\/button>/);
  assert(!html.includes('delivery-intake.tsx'));assert(!html.includes('Draft saved.'));
  assert(html.includes('Create delivery is not connected yet.'));c.dispose();
});
