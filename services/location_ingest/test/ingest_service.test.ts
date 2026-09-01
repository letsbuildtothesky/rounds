import assert from "node:assert/strict";
import test from "node:test";
import type { FleetPosition, LocationBatch } from "@rounds/contracts";
import {
  AuthorizationError,
  LocationIngestService,
  type LocationRepository,
} from "../src/ingest_service.js";

class MemoryRepository implements LocationRepository {
  watermark = 0;
  accepted: number[] = [];
  current?: FleetPosition;

  async loadWatermark(): Promise<number> {
    return this.watermark;
  }

  async insertAccepted(_batch: LocationBatch, sequences: readonly number[]): Promise<void> {
    this.accepted.push(...sequences);
  }

  async saveWatermark(_driverId: string, _sessionId: string, watermark: number): Promise<void> {
    this.watermark = watermark;
  }

  async upsertCurrent(
    _tenantId: string,
    position: FleetPosition,
    _watermark: number,
  ): Promise<void> {
    this.current = position;
  }
}

const batch = (): LocationBatch => ({
  schemaVersion: 1,
  traceId: "trace-1",
  tenantId: "tenant-1",
  driverId: "driver-1",
  deviceId: "device-1",
  sessionId: "session-1",
  firstSequence: 1,
  lastSequence: 2,
  samples: [1, 2].map((sequence) => ({
    sequence,
    capturedAt: `2026-09-01T07:00:0${sequence}.000Z`,
    latitude: 13.73 + sequence / 1000,
    longitude: 100.52,
    accuracyMeters: 8,
    source: "rounds_os",
  })),
});

test("ingest acknowledges a contiguous sequence and updates hot position", async () => {
  const repository = new MemoryRepository();
  const service = new LocationIngestService(
    repository,
    () => new Date("2026-09-01T07:00:05.000Z"),
  );
  const result = await service.ingest(
    { tenantId: "tenant-1", driverId: "driver-1" },
    batch(),
  );

  assert.equal(result.ingestWatermark, 2);
  assert.equal(result.acceptedSamples, 2);
  assert.ok(Math.abs((repository.current?.latitude ?? 0) - 13.732) < 0.000_001);
  assert.equal(repository.current?.freshness, "live");
});

test("a retry is idempotent", async () => {
  const repository = new MemoryRepository();
  const service = new LocationIngestService(repository);
  const auth = { tenantId: "tenant-1", driverId: "driver-1" };
  await service.ingest(auth, batch());
  const retried = await service.ingest(auth, batch());

  assert.equal(retried.acceptedSamples, 0);
  assert.equal(retried.duplicateSamples, 2);
  assert.deepEqual(repository.accepted, [1, 2]);
});

test("tenant or driver mismatch is rejected", async () => {
  const service = new LocationIngestService(new MemoryRepository());
  await assert.rejects(
    service.ingest({ tenantId: "other", driverId: "driver-1" }, batch()),
    AuthorizationError,
  );
});
