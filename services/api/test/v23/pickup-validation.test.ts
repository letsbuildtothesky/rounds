import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { validatePickupRequest, validatePickupResult } from '../../src/v23/pickup-validation.js';
import { CommandRejection } from '../../src/v23/transaction-runner.js';

const request = () => ({command_id:randomUUID(),context:{tenant_id:randomUUID(),city_id:randomUUID()},occurred_at:'2026-09-08T00:00:00Z',
  expected_versions:[{aggregate_type:'rounds',id:randomUUID(),version:1}],
  execution_fence:{assignment_id:randomUUID(),assignment_version:1,observation_id:randomUUID()},
  payload:{round_id:randomUUID(),pickup_stop_id:randomUUID(),manifest_ids:[randomUUID()],fulfillment_unit_ids:[randomUUID()],quantities:[{line_id:randomUUID(),quantity:0.3}]}});
test('exact generated pickup request schema accepts four-place decimals without modifying input', () => {
  for (const quantity of [0.0001,0.3,4.0001,999999.9999,1000000]) {
    const r = request(); r.payload.quantities[0]!.quantity = quantity;
    const before = structuredClone(r); validatePickupRequest(r); assert.deepEqual(r,before);
  }
});
test('wire gate rejects unknown fields, bad identities, times, unsafe versions and partial approval', () => {
  const cases: unknown[] = [ {...request(),actor_id:randomUUID()}, {...request(),occurred_at:'yesterday'},
    {...request(),command_id:'test'}, {...request(),payload:{...request().payload,approval_decision_id:randomUUID()}},
    {...request(),execution_fence:undefined}, {...request(),execution_fence:{assignment_id:randomUUID(),assignment_version:2**53,observation_id:randomUUID()}} ];
  for (const r of cases) assert.throws(() => validatePickupRequest(r), new CommandRejection('VALIDATION_FAILED'));
  for (const q of [0,-1,1.00001,0.30000000000000004,1000001,NaN,Infinity,'5']) {
    const r = request(); (r.payload.quantities[0] as {quantity:unknown}).quantity = q;
    assert.throws(() => validatePickupRequest(r), new CommandRejection('VALIDATION_FAILED'));
  }
});
test('pickup result rejects incomplete success and accepts finite sanitized rejection', () => {
  assert.throws(() => validatePickupResult({command_id:randomUUID(),command_type:'ConfirmPickup',state:'committed'}));
  const r = {command_id:randomUUID(),command_type:'ConfirmPickup',state:'rejected',error:{code:'PICKUP_NOT_READY',message_key:'errors.pickup_not_ready',retryable:false,trace_id:randomUUID()}};
  validatePickupResult(r);
  assert.throws(() => validatePickupResult({...r,data:{}}));
});
