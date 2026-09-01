import assert from "node:assert/strict";
import test from "node:test";
import {
  ContractError,
  validateCreateDeliveryCommand,
  type CreateDeliveryCommand,
} from "../src/index.js";

const validCommand = (): CreateDeliveryCommand => ({
  schemaVersion: 1,
  commandType: "delivery.create",
  commandId: "10000000-0000-4000-8000-000000000101",
  traceId: "10000000-0000-4000-8000-000000000102",
  idempotencyKey: "manual:UF-001",
  tenantId: "10000000-0000-4000-8000-000000000001",
  aggregateId: "10000000-0000-4000-8000-000000000100",
  expectedVersion: 0,
  payload: {
    sourceSystem: "manual",
    externalId: "UF-001",
    serviceDate: "2026-09-02",
    serviceTimezone: "Asia/Bangkok",
    pickupLocationId: "10000000-0000-4000-8000-000000000020",
    recipient: {
      name: "Siriporn",
      phone: "+66999999999",
      rawAddress: "Park Hyatt Bangkok",
      coordinate: {
        latitude: 13.7439,
        longitude: 100.547,
        provenance: "dispatcher_pin",
      },
    },
    buyer: { sameAsRecipient: true },
    promise: {
      windowStart: "2026-09-02T02:00:00.000Z",
      windowEnd: "2026-09-02T04:00:00.000Z",
    },
    manifest: {
      items: [{ description: "Flower bouquet", quantity: 1, cargoClass: "fragile" }],
    },
  },
});

test("accepts a complete manual UrbanFlowers delivery command", () => {
  assert.doesNotThrow(() => validateCreateDeliveryCommand(validCommand()));
});

test("requires a zero expected version for aggregate creation", () => {
  const command = validCommand();
  command.expectedVersion = 1;
  assert.throws(() => validateCreateDeliveryCommand(command), /expectedVersion must be 0/);
});

test("requires buyer identity when buyer differs from recipient", () => {
  const command = validCommand();
  command.payload.buyer = { sameAsRecipient: false, name: "", phone: "" };
  assert.throws(() => validateCreateDeliveryCommand(command), ContractError);
});

test("rejects an impossible destination coordinate", () => {
  const command = validCommand();
  command.payload.recipient.coordinate.latitude = 100;
  assert.throws(() => validateCreateDeliveryCommand(command), /latitude out of range/);
});

test("requires a positive manifest quantity", () => {
  const command = validCommand();
  command.payload.manifest.items[0]!.quantity = 0;
  assert.throws(() => validateCreateDeliveryCommand(command), /positive integer/);
});

test("requires promise end after promise start", () => {
  const command = validCommand();
  command.payload.promise.windowEnd = command.payload.promise.windowStart;
  assert.throws(() => validateCreateDeliveryCommand(command), /end must be after start/);
});
