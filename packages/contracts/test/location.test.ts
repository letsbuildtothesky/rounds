import assert from "node:assert/strict";
import test from "node:test";
import { ContractError, validateLocationBatch, type LocationBatch } from "../src/index.js";

const validBatch = (): LocationBatch => ({
  schemaVersion: 1,
  traceId: "trace-1",
  tenantId: "tenant-1",
  driverId: "driver-1",
  deviceId: "device-1",
  sessionId: "session-1",
  firstSequence: 10,
  lastSequence: 11,
  samples: [
    {
      sequence: 10,
      capturedAt: "2026-09-01T07:00:00.000Z",
      latitude: 13.7367,
      longitude: 100.5231,
      accuracyMeters: 8,
      source: "google_nav",
    },
    {
      sequence: 11,
      capturedAt: "2026-09-01T07:00:05.000Z",
      latitude: 13.7368,
      longitude: 100.5232,
      accuracyMeters: 7,
      source: "google_nav",
    },
  ],
});

test("accepts a contiguous Bangkok location batch", () => {
  assert.doesNotThrow(() => validateLocationBatch(validBatch()));
});

test("rejects a sequence gap", () => {
  const batch = validBatch();
  batch.samples[1]!.sequence = 12;
  batch.lastSequence = 12;
  assert.throws(() => validateLocationBatch(batch), ContractError);
});

test("rejects impossible coordinates", () => {
  const batch = validBatch();
  batch.samples[0]!.latitude = 100;
  assert.throws(() => validateLocationBatch(batch), /latitude out of range/);
});

