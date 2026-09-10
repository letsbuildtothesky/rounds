import { Ajv2020 } from 'ajv/dist/2020.js';
import { fullFormats } from 'ajv-formats/dist/formats.js';
import { pickupWireSchemas, type Wire_ReserveAssetRequest, type Wire_VerifyAssetRequest, type Wire_ConfirmArrivalRequest, type Wire_ConfirmPickupRequest, type Wire_RecordHandoffRequest, type Wire_DriverDeviceSessionRequest, type Wire_DriverDeviceRevokeRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { CommandRejection } from './transaction-runner.js';
import type { Wire_SubmitProofRequest, Wire_CompleteDeliveryRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import type { Wire_ReportIssueRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import type { Wire_ResolveIssueRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import {validateSaveDeliveryDraftResult} from './manual-intake.js';
import {validateReviewAddressResult} from './review-address.js';

// Trusted, build-time schemas only. No coercion/defaults/removal of user fields.
// Source enum/const branches omit redundant type keywords; data validation is
// unchanged by strictTypes=false. Decimal tolerance is backed by exact quanta.
const ajv = new Ajv2020({ strictTypes: false, multipleOfPrecision: 8 });
for (const [name, format] of Object.entries(fullFormats)) ajv.addFormat(name, format);
const compile = (name: string) => ajv.compile({ $defs: pickupWireSchemas, $ref: `#/$defs/${name}` });
const requestShape = compile('ConfirmPickupRequest');
const successShape = compile('ConfirmPickupResult');
const rejectionShape = compile('RejectedCommandStatus');
const eventShape = compile('Event_pickup_confirmed');
const statusShape = compile('CommandStatusQueryResult');
const errorShape = compile('Error');
const deviceSessionRequestShape = compile('DriverDeviceSessionRequest');
const deviceRevokeRequestShape = compile('DriverDeviceRevokeRequest');
const deviceSessionResultShape = compile('DriverDeviceSessionResult');
const deviceRevokeResultShape = compile('DriverDeviceRevokeResult');
const deviceAuditShape = compile('DriverDeviceSecurityAudit');
const executionShape = compile('DriverRoundExecutionQueryResult');
const pickupDisplayShape = compile('DriverRoundPickupQueryResult');
const pickupIssueShape = compile('DriverPickupIssueQueryResult');
const operationsIssuesShape = compile('OperationsPickupIssuesQueryResult');
const deliveryBoardShape = compile('OperationsDeliveryBoardQueryResult');
export function validateDeliveryBoardQuery(value: unknown): void {
  if (!deliveryBoardShape(value)) throw new Error('Invalid delivery board query');
}
export function validateOperationsIssuesQuery(value: unknown): void {
  if (!operationsIssuesShape(value)) throw new Error('Invalid Operations issues query');
}
export function validatePickupIssueQuery(value: unknown): void {
  if (!pickupIssueShape(value)) throw new Error('Invalid pickup issue query');
}
const proofPolicyShape = compile('ProofPolicy');
const handoffRequestShape = compile('RecordHandoffRequest');
const handoffResultShape = compile('RecordHandoffResult');
const handoffEventShape = compile('Event_handoff_recorded');
const arrivalRequestShape = compile('ConfirmArrivalRequest');
const arrivalResultShape = compile('ConfirmArrivalResult');
const arrivalEventShape = compile('Event_stop_arrived');
const reserveRequestShape = compile('ReserveAssetRequest');
const reserveResultShape = compile('ReserveAssetResult');
const verifyRequestShape = compile('VerifyAssetRequest');
const verifyResultShape = compile('VerifyAssetResult');
const assetReservedShape = compile('Event_asset_reserved');
const assetVerifiedShape = compile('Event_asset_verified');
const submitShape=compile('SubmitProofRequest'), completeShape=compile('CompleteDeliveryRequest');
const submitResult=compile('SubmitProofResult'), completeResult=compile('CompleteDeliveryResult');
const proofEvents=['Event_proof_submitted','Event_fulfillment_completed','Event_delivery_completed','Event_round_completed'].map(compile);
const issueRequestShape = compile('ReportIssueRequest'), issueResultShape = compile('ReportIssueResult');
const issueEvents = ['Event_issue_reported', 'Event_round_readiness_changed'].map(compile);
const resolveRequest=compile('ResolveIssueRequest'),resolveResult=compile('ResolveIssueResult'),resolveEvent=compile('Event_issue_decided');
export function validateResolveIssueRequest(value:unknown):asserts value is Wire_ResolveIssueRequest{
  if(!resolveRequest(value))throw new CommandRejection('VALIDATION_FAILED');
  const r=value as Wire_ResolveIssueRequest;
  if(!r.context.tenant_id||!r.context.city_id)throw new CommandRejection('NOT_AUTHORIZED');
  if(!r.payload.reason.trim()||!r.payload.decision.instructions.trim()||r.expected_versions.length!==1||
    r.expected_versions.some(v=>v.aggregate_type!=='issues'||v.id!==r.payload.issue_id||!Number.isSafeInteger(v.version)))throw new CommandRejection('VALIDATION_FAILED');
}
export function validateResolveIssueResult(value:unknown):void{
  if((value as {command_type?:string})?.command_type!=='ResolveIssue'||!resolveResult(value)&&!rejectionShape(value))throw new Error('Invalid issue decision result');
}
export function validateResolveIssueEvent(value:unknown):void{
  if(!resolveEvent(value))throw new Error('Invalid issue decision event');
}
export function validateIssueRequest(value: unknown): asserts value is Wire_ReportIssueRequest {
  if (!issueRequestShape(value)) throw new CommandRejection('VALIDATION_FAILED');
  const r = value as Wire_ReportIssueRequest, p = r.payload;
  if (!r.context.tenant_id || !r.context.city_id) throw new CommandRejection('NOT_AUTHORIZED');
  // R1 adapter is pre-pickup team work only. It cannot treat POD assets as
  // pickup evidence or silently discard attachments/unsupported issue types.
  if (p.trip_id || !['package', 'pickup_wait'].includes(p.issue_type)) throw new CommandRejection('FEATURE_NOT_ENABLED');
  const photoRequired = p.issue_type === 'package' && ['damaged', 'wrong'].includes(p.reason_code);
  if (photoRequired && p.asset_ids.length !== 1) throw new CommandRejection('ASSET_NOT_VERIFIED');
  if (!photoRequired && p.asset_ids.length) throw new CommandRejection('FEATURE_NOT_ENABLED');
  if (!p.round_id || p.issue_type === 'package' && !p.delivery_id || !p.reason_code.trim() ||
      !p.delivery_id && p.affected_lines.length || !Number.isSafeInteger(r.execution_fence.assignment_version) ||
      new Set(p.affected_lines.map(l => l.line_id)).size !== p.affected_lines.length ||
      p.affected_lines.some(l => Math.round(l.quantity * 10000) / 10000 !== l.quantity)) throw new CommandRejection('VALIDATION_FAILED');
  const expected = new Map<string, string>([['rounds', p.round_id]]);
  if (p.delivery_id) expected.set('deliveries', p.delivery_id);
  if (r.expected_versions.length !== expected.size || new Set(r.expected_versions.map(v => v.aggregate_type)).size !== expected.size ||
      r.expected_versions.some(v => expected.get(v.aggregate_type) !== v.id || !Number.isSafeInteger(v.version))) throw new CommandRejection('VALIDATION_FAILED');
}
export function validateIssueResult(value: unknown): void {
  if ((value as {command_type?: string})?.command_type !== 'ReportIssue' || !issueResultShape(value) && !rejectionShape(value)) throw new Error('Invalid issue result');
}
export function validateIssueEvent(value: unknown): void {
  if (!issueEvents.some(validate => validate(value))) throw new Error('Invalid issue fact');
}
export function validateProofRequest(value:unknown):asserts value is Wire_SubmitProofRequest {
  if(!submitShape(value))throw new CommandRejection('VALIDATION_FAILED');
  proofRoot(value as Wire_SubmitProofRequest);
  const refs=(value as Wire_SubmitProofRequest).payload.evidence, ids=new Set<string>();
  for(const r of refs){
    const fields:Record<string,string[]>= {photo:['asset_id'],signature:['asset_id'],manifest:['line_id','quantity'],receiver:['receiver_contact_id'],note:['note'],location:['location_observation_id']};
    const allowed=fields[r.kind]!;
    if(Object.entries(r).some(([k,v])=>k!=='kind'&&v!=null&&!allowed.includes(k))||allowed.some(k=>(r as any)[k]==null))throw new CommandRejection('VALIDATION_FAILED');
    if(r.kind==='note'&&!r.note?.trim()||r.kind==='manifest'&&(!Number.isSafeInteger(Math.round(r.quantity!*10000))||Math.abs(r.quantity!*10000-Math.round(r.quantity!*10000))>0.000001))throw new CommandRejection('VALIDATION_FAILED');
    const key=r.asset_id ? `asset:${r.asset_id}` : `${r.kind}:${r.line_id??''}`;
    if(ids.has(key))throw new CommandRejection('VALIDATION_FAILED');ids.add(key);
  }
}
export function validateCompleteRequest(value:unknown):asserts value is Wire_CompleteDeliveryRequest {
  if(!completeShape(value))throw new CommandRejection('VALIDATION_FAILED');proofRoot(value as Wire_CompleteDeliveryRequest);
}
function proofRoot(r:Wire_SubmitProofRequest|Wire_CompleteDeliveryRequest){
  if(!r.context.tenant_id||!r.context.city_id)throw new CommandRejection('NOT_AUTHORIZED');
  if(!Number.isSafeInteger(r.execution_fence.assignment_version)||r.expected_versions.length!==1||r.expected_versions.some(v=>v.aggregate_type!=='delivery_attempts'||v.id!==r.payload.attempt_id||!Number.isSafeInteger(v.version)))throw new CommandRejection('VALIDATION_FAILED');
}
export function validateProofResult(value:unknown){
  const kind=(value as {command_type:string})?.command_type;
  if(!['SubmitProof','CompleteDelivery'].includes(kind)||(!(kind==='SubmitProof'?submitResult:completeResult)(value)&&!rejectionShape(value)))throw new Error('Invalid proof result');
}
export function validateProofEvent(value:unknown){if(!proofEvents.some(v=>v(value)))throw new Error('Invalid proof event');}
export const podMaxBytes = 20 * 1024 * 1024;
export function validateReserveAssetRequest(value: unknown): asserts value is Wire_ReserveAssetRequest {
  if (!reserveRequestShape(value)) throw new CommandRejection('VALIDATION_FAILED');
  const r = value as Wire_ReserveAssetRequest;
  if (!r.context.tenant_id || !r.context.city_id) throw new CommandRejection('NOT_AUTHORIZED');
  if (!['delivery_photo', 'signature', 'issue_photo'].includes(r.payload.kind)) throw new CommandRejection('FEATURE_NOT_ENABLED');
  if (r.payload.kind === 'issue_photo' ? !r.payload.pickup_context || !Number.isSafeInteger(r.payload.pickup_context.execution_fence.assignment_version) : r.payload.pickup_context !== undefined)
    throw new CommandRejection('VALIDATION_FAILED');
  if (!['image/jpeg', 'image/png'].includes(r.payload.mime_type) || !Number.isSafeInteger(r.payload.byte_size) ||
      r.payload.byte_size < 1 || r.payload.byte_size > podMaxBytes || !/^[a-f0-9]{64}$/.test(r.payload.sha256) || r.expected_versions.length)
    throw new CommandRejection('VALIDATION_FAILED');
}
export function validateVerifyAssetRequest(value: unknown): asserts value is Wire_VerifyAssetRequest {
  if (!verifyRequestShape(value)) throw new CommandRejection('VALIDATION_FAILED');
  const r = value as Wire_VerifyAssetRequest;
  if (!r.context.tenant_id || !r.context.city_id) throw new CommandRejection('NOT_AUTHORIZED');
  if (!/^[a-f0-9]{64}$/.test(r.payload.sha256) || r.expected_versions.length !== 1 ||
      r.expected_versions.some(v => v.aggregate_type !== 'assets' || v.id !== r.payload.asset_id || !Number.isSafeInteger(v.version)))
    throw new CommandRejection('VALIDATION_FAILED');
}
export function validateAssetResult(value: unknown): void {
  const type = (value as {command_type?: string})?.command_type;
  if (!['ReserveAsset', 'VerifyAsset'].includes(type ?? '') ||
      (!(type === 'ReserveAsset' ? reserveResultShape : verifyResultShape)(value) && !rejectionShape(value))) throw new Error('Invalid asset result');
}
export function validateAssetEvent(value: unknown): void {
  if (!assetReservedShape(value) && !assetVerifiedShape(value)) throw new Error('Invalid asset fact');
}

export function validateArrivalRequest(value: unknown): asserts value is Wire_ConfirmArrivalRequest {
  if (!arrivalRequestShape(value)) throw new CommandRejection('VALIDATION_FAILED');
  const r = value as Wire_ConfirmArrivalRequest, p = r.payload;
  if (!r.context.tenant_id || !r.context.city_id) throw new CommandRejection('NOT_AUTHORIZED');
  if (!Number.isSafeInteger(r.execution_fence.assignment_version) || r.expected_versions.some(v => !Number.isSafeInteger(v.version)) ||
      (p.point ? !Number.isFinite(p.accuracy_m) || p.accuracy_m! < 0 || p.override_reason != null :
        p.accuracy_m != null || !p.override_reason?.trim())) throw new CommandRejection('VALIDATION_FAILED');
}
export function validateArrivalResult(value: unknown): void {
  if ((!arrivalResultShape(value) && !rejectionShape(value)) ||
      (value as {command_type:string}).command_type !== 'ConfirmArrival') throw new Error('Invalid arrival result contract');
}
export function validateArrivalEvent(value: unknown): void {
  if (!arrivalEventShape(value)) throw new Error('Invalid arrival event contract');
}

export function validateHandoffRequest(value: unknown): asserts value is Wire_RecordHandoffRequest {
  if (!handoffRequestShape(value)) throw new CommandRejection('VALIDATION_FAILED');
  const r = value as Wire_RecordHandoffRequest;
  if (!r.context.tenant_id || !r.context.city_id) throw new CommandRejection('NOT_AUTHORIZED');
  if (r.payload.quantities.some(q => Math.round(q.quantity * 10_000) / 10_000 !== q.quantity) ||
      !Number.isSafeInteger(r.execution_fence.assignment_version) || r.expected_versions.some(v => !Number.isSafeInteger(v.version))) {
    throw new CommandRejection('VALIDATION_FAILED');
  }
}
export function validateHandoffResult(value: unknown): void {
  if ((!handoffResultShape(value) && !rejectionShape(value)) ||
      (value as {command_type:string}).command_type !== 'RecordHandoff') throw new Error('Invalid handoff result contract');
}
export function validateHandoffEvent(value: unknown): void {
  if (!handoffEventShape(value)) throw new Error('Invalid handoff event contract');
}
export function validateExecutionResult(value: unknown): void {
  if ((value as {command_type?: string})?.command_type === 'ReviewAddress') validateReviewAddressResult(value);
  else if ((value as {command_type?: string})?.command_type === 'SaveDeliveryDraft') validateSaveDeliveryDraftResult(value);
  else if ((value as {command_type?: string})?.command_type === 'ResolveIssue') validateResolveIssueResult(value);
  else if ((value as {command_type?: string})?.command_type === 'ReportIssue') validateIssueResult(value);
  else if (['SubmitProof','CompleteDelivery'].includes((value as {command_type?:string})?.command_type??'')) validateProofResult(value);
  else if (['ReserveAsset', 'VerifyAsset'].includes((value as {command_type?:string})?.command_type ?? '')) validateAssetResult(value);
  else if ((value as {command_type?:string})?.command_type === 'RecordHandoff') validateHandoffResult(value);
  else if ((value as {command_type?:string})?.command_type === 'ConfirmArrival') validateArrivalResult(value);
  else validatePickupResult(value);
}

export function validateExecutionQuery(value: unknown): void {
  if (!executionShape(value)) throw new Error('Invalid execution projection');
}
export function validatePickupDisplayQuery(value: unknown): void {
  if (!pickupDisplayShape(value)) throw new Error('Invalid pickup display projection');
}
export function validateExecutionProofPolicy(value: unknown): void {
  if (!proofPolicyShape(value)) throw new CommandRejection('POLICY_NOT_CONFIGURED');
}

export function validateDeviceSessionRequest(value: unknown): asserts value is Wire_DriverDeviceSessionRequest {
  if(!deviceSessionRequestShape(value)) throw new CommandRejection('VALIDATION_FAILED');
}
export function validateDeviceRevokeRequest(value: unknown): asserts value is Wire_DriverDeviceRevokeRequest {
  if(!deviceRevokeRequestShape(value)) throw new CommandRejection('VALIDATION_FAILED');
}
export function validateDeviceResult(value: unknown, revoke: boolean): void {
  if(!(revoke?deviceRevokeResultShape:deviceSessionResultShape)(value)) throw new Error('Invalid device result contract');
}
export function validateDeviceAudit(value: unknown): void {
  if(!deviceAuditShape(value)) throw new Error('Invalid device audit contract');
}

export function validatePickupRequest(value: unknown): asserts value is Wire_ConfirmPickupRequest {
  if (!requestShape(value)) throw new CommandRejection('VALIDATION_FAILED');
  const r = value as Wire_ConfirmPickupRequest;
  if (!r.context.tenant_id || !r.context.city_id) throw new CommandRejection('NOT_AUTHORIZED');
  for (const q of r.payload.quantities) {
    if (Math.round(q.quantity * 10_000) / 10_000 !== q.quantity) throw new CommandRejection('VALIDATION_FAILED');
  }
  if (!Number.isSafeInteger(r.execution_fence.assignment_version) ||
      r.expected_versions.some(v => !Number.isSafeInteger(v.version))) throw new CommandRejection('VALIDATION_FAILED');
}
export function validatePickupResult(value: unknown): void {
  if ((!successShape(value) && !rejectionShape(value)) ||
      (value as {command_type:string}).command_type !== 'ConfirmPickup') throw new Error('Invalid pickup result contract');
}
export function validatePickupEvent(value: unknown): void {
  if (!eventShape(value)) throw new Error('Invalid pickup event contract');
}
export function validatePickupStatus(value: unknown): void {
  if (!statusShape(value)) throw new Error('Invalid pickup status contract');
  validateExecutionResult((value as {data:{result:unknown}}).data.result);
}
export function validateWireError(value: unknown): void {
  if (!errorShape(value)) throw new Error('Invalid wire error contract');
}
