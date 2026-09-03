import assert from "node:assert/strict";
import test from "node:test";
import { ContractError, validateSetDriverRecurringScheduleCommand, type SetDriverRecurringScheduleCommand } from "../src/index.js";

const command: SetDriverRecurringScheduleCommand = {
  schemaVersion: 1,
  commandType: "operations.set_driver_recurring_schedule",
  commandId: "93000000-0000-4000-8000-000000000001",
  traceId: "93000000-0000-4000-8000-000000000002",
  idempotencyKey: "driver-schedule:1",
  tenantId: "93000000-0000-4000-8000-000000000003",
  aggregateId: "93000000-0000-4000-8000-000000000004",
  expectedVersion: 0,
  payload: {
    weekdays: [1, 2, 3, 4, 5],
    startLocal: "08:00",
    endLocal: "18:00",
    vehicleProfileId: "93000000-0000-4000-8000-000000000005",
    note: "Normal weekday shift",
  },
};

test("accepts a versioned recurring own-team driver schedule", () => {
  assert.doesNotThrow(() => validateSetDriverRecurringScheduleCommand(command));
});

test("rejects duplicate or out-of-range weekdays", () => {
  assert.throws(() => validateSetDriverRecurringScheduleCommand({ ...command, payload: { ...command.payload, weekdays: [1, 1] } }), ContractError);
  assert.throws(() => validateSetDriverRecurringScheduleCommand({ ...command, payload: { ...command.payload, weekdays: [0, 2] } }), ContractError);
});

test("rejects malformed and zero-length shifts", () => {
  assert.throws(() => validateSetDriverRecurringScheduleCommand({ ...command, payload: { ...command.payload, startLocal: "8am" } }), ContractError);
  assert.throws(() => validateSetDriverRecurringScheduleCommand({ ...command, payload: { ...command.payload, endLocal: "08:00" } }), ContractError);
});

test("requires a vehicle profile and bounded note", () => {
  assert.throws(() => validateSetDriverRecurringScheduleCommand({ ...command, payload: { ...command.payload, vehicleProfileId: "vehicle" } }), ContractError);
  assert.throws(() => validateSetDriverRecurringScheduleCommand({ ...command, payload: { ...command.payload, note: "x".repeat(501) } }), ContractError);
});
