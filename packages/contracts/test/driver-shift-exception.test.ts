import assert from "node:assert/strict";
import test from "node:test";
import {
  ContractError,
  validateClearDriverShiftExceptionCommand,
  validateSetDriverShiftExceptionCommand,
  type ClearDriverShiftExceptionCommand,
  type SetDriverShiftExceptionCommand,
} from "../src/index.js";

const command: SetDriverShiftExceptionCommand = {
  schemaVersion: 1,
  commandType: "operations.set_driver_shift_exception",
  commandId: "95000000-0000-4000-8000-000000000001",
  traceId: "95000000-0000-4000-8000-000000000002",
  idempotencyKey: "exception-1",
  tenantId: "95000000-0000-4000-8000-000000000003",
  aggregateId: "95000000-0000-4000-8000-000000000004",
  expectedVersion: 0,
  payload: { serviceDate: "2026-09-04", kind: "off", note: "Personal day" },
};

test("accepts an off-day exception", () => assert.doesNotThrow(() => validateSetDriverShiftExceptionCommand(command)));
test("accepts an override shift", () => assert.doesNotThrow(() => validateSetDriverShiftExceptionCommand({
  ...command,
  payload: { serviceDate: "2026-09-04", kind: "shift", startLocal: "10:00", endLocal: "20:00", vehicleProfileId: "95000000-0000-4000-8000-000000000005" },
})));
test("rejects incomplete or contradictory exceptions", () => {
  assert.throws(() => validateSetDriverShiftExceptionCommand({ ...command, payload: { serviceDate: "2026-09-04", kind: "shift" } }), ContractError);
  assert.throws(() => validateSetDriverShiftExceptionCommand({ ...command, payload: { serviceDate: "2026-09-04", kind: "off", startLocal: "10:00" } }), ContractError);
  assert.throws(() => validateSetDriverShiftExceptionCommand({ ...command, payload: { serviceDate: "2026-02-30", kind: "off" } }), ContractError);
});

test("accepts only a versioned clear for a real service date", () => {
  const clearCommand: ClearDriverShiftExceptionCommand = {
    ...command,
    commandType: "operations.clear_driver_shift_exception",
    expectedVersion: 1,
    payload: { serviceDate: "2026-09-04" },
  };
  assert.doesNotThrow(() => validateClearDriverShiftExceptionCommand(clearCommand));
  assert.throws(() => validateClearDriverShiftExceptionCommand({ ...clearCommand, expectedVersion: 0 }), ContractError);
  assert.throws(() => validateClearDriverShiftExceptionCommand({ ...clearCommand, payload: { serviceDate: "2026-02-30" } }), ContractError);
});
