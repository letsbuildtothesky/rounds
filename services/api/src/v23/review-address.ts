import {createHash,randomUUID} from 'node:crypto';
import {Ajv2020} from 'ajv/dist/2020.js';
import {fullFormats} from 'ajv-formats/dist/formats.js';
import type {PoolClient} from 'pg';
import {pickupWireSchemas,type Wire_ReviewAddressRequest,type Wire_ReviewAddressResult,type Wire_Event_address_reviewed,type Wire_delivery_draft} from '../../../../packages/contracts/src/v23/pickup-wire.js';
import {canonicalCommandJson} from './command-identity.js';
import {authorizeIntakeCity,intakeBodyLimit,validateSaveDeliveryDraftRequest} from './manual-intake.js';
import {CommandRejection,assertExpectedVersions,type CommandAuthority,type CommandWork} from './transaction-runner.js';

export const reviewAddressPath='/v1/commands/ReviewAddress';
const ajv=new Ajv2020({strictTypes:false,multipleOfPrecision:8});
for(const [name,format] of Object.entries(fullFormats))ajv.addFormat(name,format);
const compile=(name:string)=>ajv.compile({$defs:pickupWireSchemas,$ref:`#/$defs/${name}`});
const requestShape=compile('ReviewAddressRequest'),resultShape=compile('ReviewAddressResult');
const rejectedShape=compile('RejectedCommandStatus'),eventShape=compile('Event_address_reviewed');
export function validateReviewAddressRequest(value:unknown):asserts value is Wire_ReviewAddressRequest{
  if(!requestShape(value))throw new CommandRejection('VALIDATION_FAILED');
  const r=value as Wire_ReviewAddressRequest,p=r.payload;
  if(!r.context.tenant_id||!r.context.city_id)throw new CommandRejection('NOT_AUTHORIZED');
  if(r.expected_versions.length!==1||r.expected_versions.some(v=>v.aggregate_type!=='intake_drafts'||v.id!==p.draft_id||!Number.isSafeInteger(v.version))||
    !/^[a-f0-9]{64}$/.test(p.input_hash)||!p.address_text.trim()||p.address_text.length>10000||
    p.decision==='reject'&&!p.suggestion_id||Buffer.byteLength(canonicalCommandJson(r))>intakeBodyLimit)
    throw new CommandRejection('VALIDATION_FAILED');
}
export function validateReviewAddressResult(value:unknown):void{
  if((value as {command_type?:string})?.command_type!=='ReviewAddress'||!resultShape(value)&&!rejectedShape(value))throw new Error('Invalid address review result');
}
export const authorizeAddressReview=(client:PoolClient,a:CommandAuthority)=>authorizeIntakeCity(client,a,'deliveries.review');
const address=(d:{address_text:string;point?:Wire_delivery_draft['point']})=>({address_text:d.address_text,point:d.point??null});
const equal=(a:unknown,b:unknown)=>canonicalCommandJson(a)===canonicalCommandJson(b);

/** ADR-T10: review one current manual revision. No geocoding, entrance approval,
 * slot admission, final delivery, physical readiness or provider side effect. */
export function reviewAddressWork(authority:CommandAuthority,input:Wire_ReviewAddressRequest):CommandWork{
  authority=Object.freeze({...authority});
  let request:Wire_ReviewAddressRequest;
  try{request=JSON.parse(canonicalCommandJson(input));}catch{throw new CommandRejection('VALIDATION_FAILED');}
  validateReviewAddressRequest(request);
  return {commandType:'ReviewAddress',authority,request,validate:validateReviewAddressRequest,validateResult:validateReviewAddressResult,authorize:authorizeAddressReview,
    execute:async(client,frozen,trace)=>{
      const r=frozen as Wire_ReviewAddressRequest,p=r.payload,id=p.draft_id,tenant=authority.tenantId!,city=authority.cityId!;
      const old=(await client.query(`SELECT d.version,d.review_state,d.draft_payload,d.batch_id,d.connection_id,d.source_order_key,
        d.source_revision,d.original_payload_reference,r.payload revision_payload,r.input_hash,r.field_provenance
        FROM rounds.intake_drafts d LEFT JOIN rounds.intake_draft_revisions r
          ON r.tenant_id=d.tenant_id AND r.city_id=d.city_id AND r.draft_id=d.id AND r.version=d.version
        WHERE d.tenant_id=$1 AND d.city_id=$2 AND d.id=$3 AND d.archived_at IS NULL FOR UPDATE OF d`,[tenant,city,id])).rows[0];
      if(!old)throw new CommandRejection('NOT_AUTHORIZED');
      const priorVersion=Number(old.version),version=priorVersion+1;
      if(!Number.isSafeInteger(priorVersion)||!Number.isSafeInteger(version))throw new CommandRejection('VALIDATION_FAILED');
      assertExpectedVersions(r.expected_versions,[{aggregate_type:'intake_drafts',id,version:priorVersion}]);
      if(!['draft','review_needed','ready'].includes(old.review_state)||
        [old.batch_id,old.connection_id,old.source_order_key,old.source_revision,old.original_payload_reference].some(x=>x!=null)||
        !old.revision_payload||!equal(old.revision_payload,old.draft_payload))throw new CommandRejection('VALIDATION_FAILED');
      const hash=createHash('sha256').update(canonicalCommandJson(old.draft_payload)).digest('hex');
      if(old.input_hash!==hash)throw new CommandRejection('VALIDATION_FAILED');
      if(p.input_hash!==hash)throw new CommandRejection('STALE_VERSION');
      const original=address(old.draft_payload),selected=address(p);
      const at=(await client.query<{at:Date}>('SELECT clock_timestamp() AS at')).rows[0]!.at.toISOString();
      // Lock all suggestions in ID order, after the draft. Decisions retain
      // the exact proposed point/text rather than overwriting provider history.
      const suggestions=(await client.query(`SELECT id,draft_id,delivery_id,input_hash,suggested_text,state,expires_at,archived_at,version,
        CASE WHEN point IS NULL THEN NULL ELSE jsonb_build_object('longitude',public.ST_X(point::public.geometry),'latitude',public.ST_Y(point::public.geometry)) END point
        FROM rounds.address_suggestions WHERE tenant_id=$1 AND draft_id=$2 ORDER BY id FOR UPDATE`,[tenant,id])).rows;
      const suggestion=p.suggestion_id?suggestions.find(s=>s.id===p.suggestion_id):null;
      let proposed:ReturnType<typeof address>|null=null;
      if(p.suggestion_id){
        if(!suggestion||suggestion.delivery_id||suggestion.archived_at)throw new CommandRejection('NOT_AUTHORIZED');
        if(suggestion.state!=='proposed'||suggestion.input_hash!==hash||suggestion.expires_at&&new Date(suggestion.expires_at).getTime()<=Date.parse(at))throw new CommandRejection('STALE_VERSION');
        proposed={address_text:suggestion.suggested_text,point:suggestion.point};
        if(p.decision==='accept'&&!equal(selected,proposed)||p.decision==='reject'&&!equal(selected,original))throw new CommandRejection('VALIDATION_FAILED');
      }else if(p.decision==='accept'&&!equal(selected,original))throw new CommandRejection('VALIDATION_FAILED');
      const draft:Wire_delivery_draft={...old.draft_payload,address_text:selected.address_text,point:selected.point};
      // Same exact typed/quantity constraints as a manual revision, without
      // imposing deliveries.create on the independent review capability.
      validateSaveDeliveryDraftRequest({...r,payload:{draft_id:id,draft}});
      const payload=canonicalCommandJson(draft),outputHash=createHash('sha256').update(payload).digest('hex');
      // Address approval alone never asserts all required fields/admission or
      // entrance confirmation. Future commit must evaluate its own guards.
      await client.query(`UPDATE rounds.intake_drafts SET draft_payload=$4::jsonb,review_state='review_needed',version=$5,updated_at=$6
        WHERE tenant_id=$1 AND city_id=$2 AND id=$3`,[tenant,city,id,payload,version,at]);
      await client.query(`INSERT INTO rounds.intake_draft_revisions(tenant_id,city_id,draft_id,version,schema_version,actor_id,command_id,occurred_at,received_at,payload,input_hash,field_provenance)
        VALUES($1,$2,$3,$4,1,$5,$6,$7,$8,$9::jsonb,$10,$11::jsonb)`,[tenant,city,id,version,authority.principalId,r.command_id,r.occurred_at,at,payload,outputHash,
          JSON.stringify({...old.field_provenance,address_text:'operator_review',point:'operator_review'})]);
      await client.query(`INSERT INTO rounds.intake_address_reviews(id,tenant_id,city_id,draft_id,input_version,output_version,input_hash,suggestion_id,decision,
        original_address,proposed_address,selected_address,actor_id,command_id,occurred_at,reviewed_at)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11::jsonb,$12::jsonb,$13,$14,$15,$16)`,
        [randomUUID(),tenant,city,id,priorVersion,version,hash,p.suggestion_id??null,p.decision,JSON.stringify(original),proposed===null?null:JSON.stringify(proposed),JSON.stringify(selected),authority.principalId,r.command_id,r.occurred_at,at]);
      if(suggestion)await client.query(`UPDATE rounds.address_suggestions SET state=$3,reviewed_by=$4,reviewed_at=$5,updated_at=$5,version=version+1
        WHERE tenant_id=$1 AND id=$2`,[tenant,suggestion.id,{accept:'accepted',edit:'edited',reject:'rejected'}[p.decision],authority.principalId,at]);
      await client.query(`UPDATE rounds.address_suggestions SET state='superseded',version=version+1,updated_at=$4
        WHERE tenant_id=$1 AND draft_id=$2 AND ($3::uuid IS NULL OR id<>$3) AND state<>'superseded'`,[tenant,id,p.suggestion_id??null,at]);
      const subject={aggregate_type:'intake_drafts' as const,id,version};
      const affected=[subject,...suggestions.filter(s=>s.id===p.suggestion_id||s.state!=='superseded').map(s=>({aggregate_type:'address_suggestions' as const,id:s.id,version:Number(s.version)+1}))];
      const changes:Wire_Event_address_reviewed['payload']['changes']=[];
      if(old.review_state!=='review_needed')changes.push({family:'intake_drafts.review_state',resource_id:id,from_state:old.review_state,to_state:'review_needed',version});
      const disposition={accept:'accepted',edit:'edited',reject:'rejected'} as const;
      for(const s of suggestions.filter(s=>s.id===p.suggestion_id||s.state!=='superseded'))changes.push({family:'address_suggestions.state',resource_id:s.id,from_state:s.state,
        to_state:s.id===p.suggestion_id?disposition[p.decision]:'superseded',version:Number(s.version)+1});
      const event:Wire_Event_address_reviewed={event_id:randomUUID(),event_type:'address.reviewed',schema_version:3,tenant_id:tenant,principal_id:null,aggregate:subject,
        occurred_at:r.occurred_at,received_at:at,actor_id:authority.principalId,command_id:r.command_id,worker_run_id:null,trace_id:trace,payload:{subject,affected_resources:affected,changes}};
      if(!eventShape(event))throw new Error('Invalid address reviewed fact');
      await client.query(`INSERT INTO rounds.domain_events(id,tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
        VALUES($1,$2,'intake_drafts',$3,$4,'address.reviewed',3,$5,$6,$7,$8,$9::jsonb,$10)`,[event.event_id,tenant,id,version,authority.principalId,r.command_id,r.occurred_at,at,JSON.stringify(event.payload),trace]);
      await client.query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`,[tenant,event.event_id]);
      const result:Wire_ReviewAddressResult={command_id:r.command_id,command_type:'ReviewAddress',state:'committed',current_versions:affected,resources:affected,data:{resource:subject}};
      return result;
    }};
}
