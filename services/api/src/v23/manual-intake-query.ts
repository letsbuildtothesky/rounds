import type {PoolClient} from 'pg';
import {Ajv2020} from 'ajv/dist/2020.js';
import {fullFormats} from 'ajv-formats/dist/formats.js';
import {pickupWireSchemas,type Wire_OperationsManualIntakeQueryResult} from '../../../../packages/contracts/src/v23/pickup-wire.js';
import {canonicalCommandJson} from './command-identity.js';
import {CommandRejection,type CommandAuthority} from './transaction-runner.js';
import {validateSaveDeliveryDraftRequest} from './manual-intake.js';

export const manualIntakeWorkspacePath='/v1/queries/Workspace';
const ajv=new Ajv2020({strictTypes:false,multipleOfPrecision:8});
for(const [name,format] of Object.entries(fullFormats))ajv.addFormat(name,format);
const valid=ajv.compile({$defs:pickupWireSchemas,$ref:'#/$defs/OperationsManualIntakeQueryResult'});

/** ADR-Q08. Caller owns one restricted repeatable-read transaction and checks
 * current deliveries.create. No draft list, inferred pickup, slots or grants. */
export async function projectManualIntake(client:PoolClient,a:CommandAuthority,id:string|null):Promise<Wire_OperationsManualIntakeQueryResult>{
  const city=(await client.query(`SELECT id,name,version,timezone,
    (transaction_timestamp() AT TIME ZONE timezone)::date::text current_service_date
    FROM rounds.cities WHERE tenant_id=$1 AND id=$2 AND enabled AND archived_at IS NULL`,[a.tenantId,a.cityId])).rows[0];
  if(!city)throw new CommandRejection('NOT_AUTHORIZED');
  city.version=Number(city.version);
  const sites=(await client.query(`SELECT id,name,version FROM rounds.sites
    WHERE tenant_id=$1 AND city_id=$2 AND archived_at IS NULL ORDER BY name,id LIMIT 1001`,[a.tenantId,a.cityId])).rows.map(r=>({...r,version:Number(r.version)}));
  if(sites.length>1000)throw new CommandRejection('VALIDATION_FAILED');
  let draft:Wire_OperationsManualIntakeQueryResult['data']['draft']=null;
  if(id){
    const r=(await client.query(`SELECT d.version,d.review_state,d.draft_payload,
      d.batch_id,d.connection_id,d.source_order_key,d.source_revision,d.original_payload_reference,
      r.payload revision_payload
      FROM rounds.intake_drafts d LEFT JOIN rounds.intake_draft_revisions r
        ON r.tenant_id=d.tenant_id AND r.city_id=d.city_id AND r.draft_id=d.id AND r.version=d.version
      WHERE d.tenant_id=$1 AND d.city_id=$2 AND d.id=$3 AND d.archived_at IS NULL`,[a.tenantId,a.cityId,id])).rows[0];
    if(!r)throw new CommandRejection('NOT_AUTHORIZED');
    if(!['draft','extracting','review_needed','ready'].includes(r.review_state)||
      [r.batch_id,r.connection_id,r.source_order_key,r.source_revision,r.original_payload_reference].some(x=>x!=null)||
      !r.revision_payload||canonicalCommandJson(r.revision_payload)!==canonicalCommandJson(r.draft_payload))throw new CommandRejection('UPGRADE_REQUIRED');
    const version=Number(r.version);
    validateSaveDeliveryDraftRequest({command_id:id,context:{tenant_id:a.tenantId,city_id:a.cityId},
      occurred_at:new Date().toISOString(),expected_versions:[{aggregate_type:'intake_drafts',id,version}],payload:{draft_id:id,draft:r.draft_payload}});
    draft={id,version,review_state:r.review_state,payload:r.draft_payload};
  }
  const result:Wire_OperationsManualIntakeQueryResult={as_of:new Date().toISOString(),next_cursor:null,
    data:{view:'manual_intake',principal_id:a.principalId,tenant_id:a.tenantId!,city_id:a.cityId!,city,sites,draft}};
  if(!valid(result))throw new CommandRejection('VALIDATION_FAILED');
  return result;
}
