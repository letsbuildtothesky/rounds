import {createHash,randomUUID} from 'node:crypto';
import type {PoolClient} from 'pg';
import {Ajv2020} from 'ajv/dist/2020.js';
import {fullFormats} from 'ajv-formats/dist/formats.js';
import {pickupWireSchemas,type Wire_SaveDeliveryDraftRequest,type Wire_SaveDeliveryDraftResult,type Wire_Event_intake_draft_saved,type Wire_delivery_draft} from '../../../../packages/contracts/src/v23/pickup-wire.js';
import {canonicalCommandJson} from './command-identity.js';
import {CommandRejection,assertExpectedVersions,type CommandAuthority,type CommandWork} from './transaction-runner.js';

export const saveDeliveryDraftPath='/v1/commands/SaveDeliveryDraft';
export const intakeBodyLimit=256*1024;
const ajv=new Ajv2020({strictTypes:false,multipleOfPrecision:8});
for(const [name,format] of Object.entries(fullFormats))ajv.addFormat(name,format);
const compile=(name:string)=>ajv.compile({$defs:pickupWireSchemas,$ref:`#/$defs/${name}`});
const requestShape=compile('SaveDeliveryDraftRequest'),resultShape=compile('SaveDeliveryDraftResult');
const rejectedShape=compile('RejectedCommandStatus'),eventShape=compile('Event_intake_draft_saved');
export function validateSaveDeliveryDraftRequest(value:unknown):asserts value is Wire_SaveDeliveryDraftRequest{
  if(!requestShape(value))throw new CommandRejection('VALIDATION_FAILED');
  const r=value as Wire_SaveDeliveryDraftRequest,d=r.payload.draft,id=r.payload.draft_id;
  if(!r.context.tenant_id||!r.context.city_id)throw new CommandRejection('NOT_AUTHORIZED');
  if(d.city_id!=null&&d.city_id!==r.context.city_id)throw new CommandRejection('NOT_AUTHORIZED');
  if(r.expected_versions.length!==(id?1:0)||r.expected_versions.some(v=>v.aggregate_type!=='intake_drafts'||v.id!==id||!Number.isSafeInteger(v.version))||
    Buffer.byteLength(canonicalCommandJson(r))>intakeBodyLimit)throw new CommandRejection('VALIDATION_FAILED');
  // Drafts may be incomplete. Do not infer contacts, product lines, dates or
  // coordinates. Supplied quantities still must be representable exactly.
  if(new Set(d.manifest.map(l=>l.line_key)).size!==d.manifest.length||d.manifest.some(l=>
    !l.line_key.trim()||!l.label.trim()||!l.unit.trim()||!Number.isSafeInteger(Math.round(l.quantity*10000))||
    Math.round(l.quantity*10000)/10000!==l.quantity||new Set(l.handling_keys).size!==l.handling_keys.length))throw new CommandRejection('VALIDATION_FAILED');
  if(d.window&&Date.parse(d.window.ends_at)<=Date.parse(d.window.starts_at))throw new CommandRejection('VALIDATION_FAILED');
}
export function validateSaveDeliveryDraftResult(value:unknown):void{
  if((value as {command_type?:string})?.command_type!=='SaveDeliveryDraft'||!resultShape(value)&&!rejectedShape(value))throw new Error('Invalid draft result');
}
export async function authorizeIntakeCity(client:PoolClient,a:CommandAuthority,capability:'deliveries.create'|'deliveries.review'='deliveries.create'):Promise<void>{
  const grant=await client.query(`SELECT m.id FROM rounds.memberships m
    JOIN rounds.city_grants g ON g.tenant_id=m.tenant_id AND g.membership_id=m.id
    JOIN rounds.cities c ON c.tenant_id=g.tenant_id AND c.id=g.city_id
    JOIN rounds.tenants t ON t.id=m.tenant_id
    WHERE m.tenant_id=$1 AND m.principal_id=$2 AND m.status='active' AND m.archived_at IS NULL
      AND g.city_id=$3 AND g.archived_at IS NULL AND $4=ANY(g.capabilities)
      AND c.enabled AND c.archived_at IS NULL AND t.status='active' AND t.archived_at IS NULL
    FOR SHARE OF m,g,c`,[a.tenantId,a.principalId,a.cityId,capability]);
  if(!grant.rowCount)throw new CommandRejection('NOT_AUTHORIZED');
}
async function validateReferences(client:PoolClient,a:CommandAuthority,d:Wire_delivery_draft){
  const city=(await client.query(`SELECT timezone FROM rounds.cities WHERE tenant_id=$1 AND id=$2`,[a.tenantId,a.cityId])).rows[0];
  if(!city)throw new CommandRejection('NOT_AUTHORIZED');
  if(d.site_id&&(await client.query(`SELECT id FROM rounds.sites WHERE tenant_id=$1 AND city_id=$2 AND id=$3 AND archived_at IS NULL FOR SHARE`,[a.tenantId,a.cityId,d.site_id])).rowCount!==1)throw new CommandRejection('NOT_AUTHORIZED');
  if(d.brand_id&&(await client.query(`SELECT id FROM rounds.brands WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR SHARE`,[a.tenantId,d.brand_id])).rowCount!==1)throw new CommandRejection('NOT_AUTHORIZED');
  if(d.slot_occurrence_id&&(await client.query(`SELECT id FROM rounds.slot_occurrences WHERE tenant_id=$1 AND city_id=$2 AND id=$3 AND archived_at IS NULL`,[a.tenantId,a.cityId,d.slot_occurrence_id])).rowCount!==1)throw new CommandRejection('NOT_AUTHORIZED');
  // This is only a draft reference: no hold, capacity guarantee or named-window
  // admission. HoldSlot/CommitDelivery must validate those under their own locks.
  for(const id of [...new Set(d.manifest.map(l=>l.cargo_class_id).filter((id):id is string=>!!id))].sort()){
    const cargo=(await client.query(`SELECT unit,discrete FROM rounds.cargo_classes WHERE tenant_id=$1 AND id=$2 AND archived_at IS NULL FOR SHARE`,[a.tenantId,id])).rows[0];
    if(!cargo)throw new CommandRejection('NOT_AUTHORIZED');
    if(d.manifest.some(l=>l.cargo_class_id===id&&(l.unit!==cargo.unit||cargo.discrete&&!Number.isInteger(l.quantity))))throw new CommandRejection('VALIDATION_FAILED');
  }
  if(d.window){
    if(d.window.timezone!==city.timezone)throw new CommandRejection('VALIDATION_FAILED');
    if(d.service_date){
      const day=(await client.query(`SELECT ($1::timestamptz AT TIME ZONE $2)::date::text AS day`,[d.window.starts_at,city.timezone])).rows[0]!.day;
      if(day!==d.service_date)throw new CommandRejection('VALIDATION_FAILED');
    }
  }
}

/** R1 manual save only, not CommitDelivery. No guessed migration/provenance. */
export function saveDeliveryDraftWork(authority:CommandAuthority,input:Wire_SaveDeliveryDraftRequest):CommandWork{
  authority=Object.freeze({...authority});
  let request:Wire_SaveDeliveryDraftRequest;
  try{request=JSON.parse(canonicalCommandJson(input));}catch{throw new CommandRejection('VALIDATION_FAILED');}
  validateSaveDeliveryDraftRequest(request);
  return {commandType:'SaveDeliveryDraft',authority,request,validate:validateSaveDeliveryDraftRequest,validateResult:validateSaveDeliveryDraftResult,authorize:authorizeIntakeCity,
    execute:async(client,frozen,trace)=>{
      const r=frozen as Wire_SaveDeliveryDraftRequest,d=r.payload.draft,tenant=authority.tenantId!,id=r.payload.draft_id??randomUUID();
      let version=1,prior:'draft'|'extracting'|'review_needed'|'ready'|null=null;
      // Draft root precedes referenced configuration/suggestions. Future slot
      // writers take admission keys before this root (E04/ADR-T09).
      if(r.payload.draft_id){
        const old=(await client.query(`SELECT version,review_state,batch_id,connection_id,source_order_key,source_revision,original_payload_reference,draft_payload
          FROM rounds.intake_drafts WHERE tenant_id=$1 AND city_id=$2 AND id=$3 AND archived_at IS NULL FOR UPDATE`,[tenant,authority.cityId,id])).rows[0];
        if(!old)throw new CommandRejection('NOT_AUTHORIZED');
        if(!Number.isSafeInteger(Number(old.version))||Number(old.version)>=Number.MAX_SAFE_INTEGER)throw new CommandRejection('VALIDATION_FAILED');
        assertExpectedVersions(r.expected_versions,[{aggregate_type:'intake_drafts',id,version:Number(old.version)}]);
        // No source rewrite, committed-draft resurrection or silent legacy import.
        if(!['draft','extracting','review_needed','ready'].includes(old.review_state)||
          [old.batch_id,old.connection_id,old.source_order_key,old.source_revision,old.original_payload_reference].some(x=>x!=null))throw new CommandRejection('VALIDATION_FAILED');
        const revision=(await client.query(`SELECT payload FROM rounds.intake_draft_revisions WHERE tenant_id=$1 AND city_id=$2 AND draft_id=$3 AND version=$4`,[tenant,authority.cityId,id,old.version])).rows[0];
        if(!revision||canonicalCommandJson(revision.payload)!==canonicalCommandJson(old.draft_payload))throw new CommandRejection('VALIDATION_FAILED');
        version=Number(old.version)+1;prior=old.review_state;
      }else assertExpectedVersions(r.expected_versions,[]);
      await validateReferences(client,authority,d);
      const next=prior?'review_needed':'draft',subject={aggregate_type:'intake_drafts' as const,id,version};
      const at=(await client.query<{at:Date}>('SELECT clock_timestamp() AS at')).rows[0]!.at.toISOString();
      const payload=canonicalCommandJson(d),hash=createHash('sha256').update(payload).digest('hex');
      if(prior){
        await client.query(`UPDATE rounds.intake_drafts SET draft_payload=$4::jsonb,review_state=$5,version=$6,updated_at=$7
          WHERE tenant_id=$1 AND city_id=$2 AND id=$3`,[tenant,authority.cityId,id,payload,next,version,at]);
        // Existing decisions/text/point/actor/time remain as history. No old
        // suggestion can remain current after a new submitted revision.
        await client.query(`SELECT id FROM rounds.address_suggestions WHERE tenant_id=$1 AND draft_id=$2 ORDER BY id FOR UPDATE`,[tenant,id]);
        await client.query(`UPDATE rounds.address_suggestions SET state='superseded',version=version+1,updated_at=$3
          WHERE tenant_id=$1 AND draft_id=$2 AND state<>'superseded'`,[tenant,id,at]);
      }else await client.query(`INSERT INTO rounds.intake_drafts(id,tenant_id,city_id,draft_payload,review_state,created_by,created_at,updated_at)
        VALUES($1,$2,$3,$4::jsonb,'draft',$5,$6,$6)`,[id,tenant,authority.cityId,payload,authority.principalId,at]);
      await client.query(`INSERT INTO rounds.intake_draft_revisions(tenant_id,city_id,draft_id,version,schema_version,actor_id,command_id,occurred_at,received_at,payload,input_hash,field_provenance)
        VALUES($1,$2,$3,$4,1,$5,$6,$7,$8,$9::jsonb,$10,$11::jsonb)`,[tenant,authority.cityId,id,version,authority.principalId,r.command_id,r.occurred_at,at,payload,hash,
          JSON.stringify(Object.fromEntries(Object.keys(d).map(k=>[k,'manual'])))]);
      const event:Wire_Event_intake_draft_saved={event_id:randomUUID(),event_type:'intake.draft_saved',schema_version:3,tenant_id:tenant,principal_id:null,
        aggregate:subject,occurred_at:r.occurred_at,received_at:at,actor_id:authority.principalId,command_id:r.command_id,worker_run_id:null,trace_id:trace,
        payload:{subject,affected_resources:[subject],changes:prior===next?[]:[{family:'intake_drafts.review_state',resource_id:id,from_state:prior,to_state:next,version}]}};
      if(!eventShape(event))throw new Error('Invalid intake draft fact');
      await client.query(`INSERT INTO rounds.domain_events(id,tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
        VALUES($1,$2,'intake_drafts',$3,$4,'intake.draft_saved',3,$5,$6,$7,$8,$9::jsonb,$10)`,[event.event_id,tenant,id,version,authority.principalId,r.command_id,r.occurred_at,at,JSON.stringify(event.payload),trace]);
      await client.query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`,[tenant,event.event_id]);
      const result:Wire_SaveDeliveryDraftResult={command_id:r.command_id,command_type:'SaveDeliveryDraft',state:'committed',current_versions:[subject],resources:[subject],data:{resource:subject}};
      return result;
    }};
}
