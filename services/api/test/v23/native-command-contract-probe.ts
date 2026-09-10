// Called by the native SQLCipher queue test with its actual frozen requests.
// No listener/database/provider. Production Ajv validators + hash implementation.
import assert from 'node:assert/strict';
import { canonicalCommandJson, commandRequestHash } from '../../src/v23/command-identity.js';
import { validateArrivalRequest, validatePickupRequest, validateHandoffRequest, validateExecutionResult, validateReserveAssetRequest, validateVerifyAssetRequest, validateProofRequest, validateCompleteRequest, validateAssetResult, validateProofResult, validateIssueRequest } from '../../src/v23/pickup-validation.js';

const rows = JSON.parse(Buffer.from(process.argv[2]!, 'base64').toString('utf8')) as { command_type: string; payload_json: string; request_hash: string; server_receipt_json: string }[];
assert.ok(rows.length === 4 || rows.length === 8 || rows.length === 1 && rows[0]?.command_type === 'ReportIssue' ||
  rows.length === 3 && ['ReserveAsset', 'VerifyAsset', 'ReportIssue'].every(type => rows.filter(r => r.command_type === type).length === 1));
const validate: Record<string, (v: unknown) => void> = { ConfirmArrival: validateArrivalRequest, ConfirmPickup: validatePickupRequest, RecordHandoff: validateHandoffRequest, ReserveAsset: validateReserveAssetRequest, VerifyAsset: validateVerifyAssetRequest, SubmitProof: validateProofRequest, CompleteDelivery: validateCompleteRequest, ReportIssue: validateIssueRequest };
for (const row of rows) {
  const request = JSON.parse(row.payload_json);
  validate[row.command_type]!(request);
  assert.equal(canonicalCommandJson(request), row.payload_json);
  assert.equal(commandRequestHash(row.command_type, request), row.request_hash);
  const result = JSON.parse(row.server_receipt_json);
  if (row.command_type === 'ReserveAsset') {
    assert.deepEqual(Object.keys(result.data), ['asset_id']);
    validateAssetResult({...result, data: {...result.data, upload_url: 'https://invalid.example/test-only', upload_token: null, upload_method: 'PUT', expires_at: '2026-09-09T00:00:00Z'}});
  } else if (row.command_type === 'VerifyAsset') validateAssetResult(result);
  else if (row.command_type === 'SubmitProof' || row.command_type === 'CompleteDelivery') validateProofResult(result);
  else validateExecutionResult(result);
}
console.log('PASS actual Dart queue bytes/hash and synthetic receipts against production TypeScript validators');
