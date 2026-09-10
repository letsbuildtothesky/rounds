/** Local test host for OUR React component, never the blocked original HTML.
 * Synthetic HTTP/Auth data, real React/Storage/controller. First POST records
 * a fixture receipt then returns503, so browser reload/status can be exercised.
 * No external service/DB/phone is touched; production imports none of this. */
import {build} from 'esbuild';
import {createServer} from 'node:http';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const bundle = await build({absWorkingDir:root,entryPoints:['apps/operations-web/test/support/pickup-issue-review.tsx'],bundle:true,write:false,outdir:'component-test',format:'esm',platform:'browser',jsx:'automatic',define:{'process.env.NODE_ENV':'"development"'}});
const js = bundle.outputFiles.find(f=>f.path.endsWith('.js')).contents;
const css = bundle.outputFiles.find(f=>f.path.endsWith('.css')).contents;
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
let version = 1, decision = null, receipt = null, posts = 0;
let intakeDraft=null,intakePosts=0;
const intakeReceipts=new Map();
let deliveryMode = 'ready';
const deliveryReads=[];
const server = createServer(async(req,res)=>{
  res.setHeader('Cache-Control','no-store');
  res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'");
  const url = new URL(req.url,'http://127.0.0.1:3023');
  const json = (data,status=200)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(data));};
  if(url.pathname==='/'){res.writeHead(200,{'Content-Type':'text/html'});res.end('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Rounds pickup component test</title><link rel="stylesheet" href="/review.css"><body style="margin:0"><div id="root"></div><script type="module" src="/review.js"></script></body></html>');return;}
  if(url.pathname==='/review.js'){res.writeHead(200,{'Content-Type':'text/javascript'});res.end(js);return;}
  if(url.pathname==='/review.css'){res.writeHead(200,{'Content-Type':'text/css'});res.end(css);return;}
  if(url.pathname==='/test-evidence'){json({synthetic:true,posts,version,pendingReceipt:!!receipt,deliveryReads,intakePosts,intakeVersion:intakeDraft?.version??null});return;}
  if(url.pathname==='/test-control'&&['ready','offline','empty','removed','denied'].includes(url.searchParams.get('mode'))){deliveryMode=url.searchParams.get('mode');json({synthetic:true,deliveryMode});return;}
  if(req.headers.authorization!=='Bearer component-test-only'){json({code:'NOT_AUTHORIZED'},403);return;}
  if(url.pathname==='/v1/queries/Workspace'){
    json({as_of:new Date().toISOString(),next_cursor:null,data:{view:'manual_intake',principal_id:id(1),tenant_id:id(2),city_id:id(3),
      city:{id:id(3),name:'Bangkok · Synthetic',version:1,timezone:'Asia/Bangkok',current_service_date:'2026-09-10'},
      sites:[{id:id(30),name:'Synthetic pickup',version:1}],draft:url.searchParams.has('entity_id')?intakeDraft:null}});return;
  }
  if(url.pathname==='/v1/commands/SaveDeliveryDraft'&&req.method==='POST'){
    const chunks=[];let size=0;for await(const chunk of req){size+=chunk.length;if(size>262144){json({},413);return;}chunks.push(chunk);}
    const r=JSON.parse(Buffer.concat(chunks).toString());intakePosts++;
    if(intakeReceipts.has(r.command_id)){json(intakeReceipts.get(r.command_id));return;}
    const resource={aggregate_type:'intake_drafts',id:id(901),version:(intakeDraft?.version??0)+1};
    intakeDraft={id:resource.id,version:resource.version,review_state:'review_needed',payload:r.payload.draft};
    const saved={command_type:'SaveDeliveryDraft',command_id:r.command_id,state:'committed',current_versions:[resource],resources:[resource],data:{resource}};
    intakeReceipts.set(r.command_id,saved);json(saved);return;
  }
  if(url.pathname==='/v1/queries/CommandStatus'&&intakeReceipts.has(url.searchParams.get('entity_id'))){
    json({as_of:new Date().toISOString(),next_cursor:null,data:{result:intakeReceipts.get(url.searchParams.get('entity_id'))}});return;
  }
  if(url.pathname==='/v1/queries/Board'){
    if(url.searchParams.get('view')==='delivery_board'){
      const serviceDate=url.searchParams.get('service_date');deliveryReads.push({serviceDate,mode:deliveryMode});
      if(deliveryMode==='denied'){json({},403);return;}
      if(deliveryMode==='offline'){json({code:'SOURCE_UNAVAILABLE',message_key:'SOURCE_UNAVAILABLE',retryable:true,trace_id:'component-test'},503);return;}
      const deliveries = Array.from({length:12},(_,i)=>({id:id(i===0?7:100+i),version:1,reference:`UF-TEST-${String(i+1).padStart(3,'0')}`,recipient_name:i===0?'Siriporn · Component test':i===1?'Johannes · Long recipient name to verify wrapping without shrinking the approved type size':`Synthetic recipient ${i+1}`,address_text:'Synthetic destination · Not a customer address',brand:{id:id(31),name:'Test brand'},pickup_site:{id:id(30),name:'Synthetic pickup site'},window:{starts_at:`2026-09-10T${String(i+1).padStart(2,'0')}:00:00Z`,ends_at:`2026-09-10T${String(i+3).padStart(2,'0')}:00:00Z`,timezone:'Asia/Bangkok',service_date:'2026-09-10'},readiness:i===0?'held':i===1?'draft':'review_needed',preparation_state:'unknown',outcome:'open',evidence_state:'none',destination_version:1,destination:null,entrance_revision_id:null,planning:i===0?{round_id:id(5),round_version:1,round_state:'staged',departure_gate:'awaiting_receipt',stop_id:id(32),stop_version:1,stop_state:'planned'}:null}));
      // Coordinates are explicit synthetic test data, never a production default.
      for(let i=0;i<3;i++)deliveries[i].destination={source:'delivery_destination',longitude:100.55+i*.01,latitude:13.73+i*.01};
      deliveries[1].brand={id:id(33),name:'Second test brand'};
      if(url.searchParams.get('display')==='now'){
        // Coherent synthetic public facts for the read-only Now detail. Unit,
        // issue and attempt authority is tested in PostGIS, not fabricated here.
        const planning=(i,departure_gate='ready',stop_state='released')=>({round_id:id(200+i),round_version:1,round_state:'released',departure_gate,stop_id:id(300+i),stop_version:1,stop_state});
        for(const i of [2,3,4,5,6,7,8,9]){deliveries[i].readiness='ready';deliveries[i].preparation_state='ready';}
        for(const i of [3,4,5,6,7,8,9])deliveries[i].planning=planning(i);
        deliveries[5].outcome='delivered';deliveries[6].outcome='returned';
        deliveries[7].planning.departure_gate='awaiting_receipt';
        deliveries[8].preparation_state='preparing';deliveries[8].planning.departure_gate='awaiting_preparation';
        deliveries[9].destination={source:'delivery_destination',longitude:100.59,latitude:13.76};
        deliveries[11].readiness='draft';
      }
      const datedRows=(serviceDate==='2026-09-10'?deliveries:serviceDate==='2026-09-11'?deliveries.slice(3,5):[])
        .map(d=>({...d,window:{...d.window,service_date:serviceDate,starts_at:serviceDate+d.window.starts_at.slice(10),ends_at:serviceDate+d.window.ends_at.slice(10)}}));
      const resultRows=deliveryMode==='empty'?[]:deliveryMode==='removed'?datedRows.slice(1):datedRows;
      const testCategories=[['action','issue'],['planned','scheduled'],['ready','ready_to_assign'],['road','collected'],['road','handed_over'],['done','delivered'],['done','returned'],['action','awaiting_receipt'],['action','awaiting_preparation'],['ready','ready_for_pickup'],['action','review_needed'],['planned','scheduled']];
      const now=url.searchParams.get('display')==='now'?{current_service_date:'2026-09-10',entries:resultRows.map(d=>{const index=deliveries.findIndex(x=>x.id===d.id),[bucket,reason]=testCategories[index];return {delivery_id:d.id,bucket,reason};})}:undefined;
      json({as_of:new Date().toISOString(),next_cursor:null,data:{view:'delivery_board',principal_id:id(1),tenant_id:id(2),city_id:id(3),service_date:serviceDate,workspace:{name:'Synthetic workspace',version:1},city:{name:'Bangkok · Test',version:1,timezone:'Asia/Bangkok'},delivery_count:resultRows.length,deliveries:resultRows,...(now?{now}:{})}});return;
    }
    json({as_of:new Date().toISOString(),next_cursor:null,data:{view:'pickup_issues',principal_id:id(1),tenant_id:id(2),city_id:id(3),service_date:'2026-09-10',issues:[{
      issue_id:id(4),issue_version:version,round_id:id(5),assignment_id:id(6),assignment_version:1,delivery_id:id(7),state:decision?'decided':'open',reported_at:'2026-09-10T03:30:00Z',
      ...(url.searchParams.get('display')==='labels'?{display:{delivery_reference:'UF-TEST-001',recipient_name:'Siriporn · Component test',destination_address:'Synthetic destination · Not a customer address',pickup_site_name:'Synthetic pickup site',reported_driver_name:'Johannes · Component test'}}:{}),
      report:{issue_type:'package',reason_code:'missing',detail:'One package is missing at pickup. Please advise.',asset_ids:[],affected_lines:[]},decisions:decision?[decision]:[],allowed_actions:['wait','escalate'],blocked_reason:null}]}});return;
  }
  if(url.pathname==='/v1/queries/CommandStatus'){json(receipt?{as_of:new Date().toISOString(),next_cursor:null,data:{result:receipt}}:{code:'NOT_FOUND',message_key:'NOT_FOUND',retryable:false,trace_id:'component-test'},receipt?200:404);return;}
  if(url.pathname==='/v1/commands/ResolveIssue'&&req.method==='POST'){
    const chunks=[];let size=0;for await(const chunk of req){size+=chunk.length;if(size>65536){json({},413);return;}chunks.push(chunk);}
    const request=JSON.parse(Buffer.concat(chunks).toString());posts++;version++;
    decision={id:id(8),action:request.payload.decision.action,instructions:request.payload.decision.instructions,decided_at:new Date().toISOString()};
    const resource={aggregate_type:'issues',id:id(4),version};
    receipt={command_id:request.command_id,command_type:'ResolveIssue',state:'committed',current_versions:[resource],resources:[{aggregate_type:'issue_decisions',id:id(8),version:1}],data:{resource,state:'decided'}};
    json({code:'PROVIDER_UNAVAILABLE',message_key:'PROVIDER_UNAVAILABLE',retryable:true,trace_id:'component-test'},503);return;
  }
  json({},404);
});
const port = Number(process.env.ROUNDS_COMPONENT_TEST_PORT ?? 3023);
server.listen(port,'127.0.0.1',()=>console.log(`Synthetic component test: http://127.0.0.1:${port} (not the original HTML or production board)`));
