import assert from "node:assert/strict";
import test from "node:test";
import {
  ContractError,
  validateLogContactAttemptCommand,
  validateSendDriverMessageCommand,
  validateSendOperationsMessageCommand,
} from "../src/index.js";

test("accepts a typed native-phone outcome", () => {
  assert.doesNotThrow(() => validateLogContactAttemptCommand({
    schemaVersion: 1,
    commandType: "stop.log_contact_attempt",
    commandId: "10000000-0000-4000-8000-000000000051",
    traceId: "10000000-0000-4000-8000-000000000052",
    idempotencyKey: "contact:one",
    tenantId: "10000000-0000-4000-8000-000000000001",
    aggregateId: "10000000-0000-4000-8000-000000000011",
    expectedVersion: 4,
    occurredFromDeviceAt: "2026-09-03T04:00:00Z",
    payload: { target: "recipient", channel: "native_phone", outcome: "no_answer" },
  }));
  assert.throws(() => validateLogContactAttemptCommand({
    schemaVersion: 1,
    commandType: "stop.log_contact_attempt",
    commandId: "10000000-0000-4000-8000-000000000051",
    traceId: "10000000-0000-4000-8000-000000000052",
    idempotencyKey: "contact:bad",
    tenantId: "10000000-0000-4000-8000-000000000001",
    aggregateId: "10000000-0000-4000-8000-000000000011",
    expectedVersion: 4,
    occurredFromDeviceAt: "2026-09-03T04:00:00Z",
    payload: { target: "recipient", channel: "native_phone", outcome: "connected" as never },
  }), ContractError);
});

const base = {
  schemaVersion: 1 as const,
  commandType: "thread.send_message" as const,
  commandId: "10000000-0000-4000-8000-000000000101",
  traceId: "10000000-0000-4000-8000-000000000102",
  idempotencyKey: "message:thread-1:one",
  tenantId: "10000000-0000-4000-8000-000000000001",
  aggregateId: "10000000-0000-4000-8000-000000000011",
  expectedVersion: 1,
};

test("accepts a bounded versioned driver message", () => {
  assert.doesNotThrow(() => validateSendDriverMessageCommand({
    ...base,
    payload: { body: "Running five minutes late" },
  }));
});

test("accepts a location-only driver message", () => {
  assert.doesNotThrow(() => validateSendDriverMessageCommand({
    ...base,
    payload: {
      body: "",
      attachments: [{
        kind: "location",
        label: "Current location",
        latitude: 13.7306,
        longitude: 100.5697,
        accuracyMeters: 8.5,
        capturedAt: "2026-09-04T03:00:00Z",
      }],
    },
  }));
});

test("rejects invalid location coordinates", () => {
  assert.throws(() => validateSendDriverMessageCommand({
    ...base,
    payload: {
      body: "Here",
      attachments: [{
        kind: "location",
        label: "Current location",
        latitude: 130,
        longitude: 100.5697,
        capturedAt: "2026-09-04T03:00:00Z",
      }],
    },
  }), ContractError);
});

test("accepts verified image, file and voice message attachments", () => {
  assert.doesNotThrow(() => validateSendDriverMessageCommand({
    ...base,
    payload: {
      body: "Evidence attached",
      attachments: [
        { kind: "image", mediaAssetId: "10000000-0000-4000-8000-000000000201", fileName: "gate.jpg", contentType: "image/jpeg", byteSize: 1024 },
        { kind: "file", mediaAssetId: "10000000-0000-4000-8000-000000000202", fileName: "note.pdf", contentType: "application/pdf", byteSize: 2048 },
        { kind: "voice", mediaAssetId: "10000000-0000-4000-8000-000000000203", fileName: "voice.m4a", contentType: "audio/mp4", byteSize: 4096, durationMilliseconds: 1200 },
      ],
    },
  }));
});

test("rejects unverified or malformed media attachment metadata", () => {
  assert.throws(() => validateSendDriverMessageCommand({
    ...base,
    payload: { body: "", attachments: [{ kind: "voice", mediaAssetId: "bad", fileName: "voice.m4a", contentType: "audio/mp4", byteSize: 10, durationMilliseconds: 0 }] },
  }), ContractError);
});

test("rejects empty and oversized message bodies", () => {
  assert.throws(() => validateSendDriverMessageCommand({
    ...base,
    payload: { body: "   " },
  }), ContractError);
  assert.throws(() => validateSendDriverMessageCommand({
    ...base,
    payload: { body: "x".repeat(2001) },
  }), ContractError);
});

test("accepts a bounded versioned Operations reply", () => {
  assert.doesNotThrow(() => validateSendOperationsMessageCommand({
    ...base,
    commandType: "thread.send_operations_message",
    payload: { body: "Please continue to the recipient" },
  }));
});
