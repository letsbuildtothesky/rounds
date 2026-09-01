import assert from "node:assert/strict";
import test from "node:test";
import { TenantPositionAggregator } from "../src/aggregator.js";
import { classifyFreshness } from "../src/freshness.js";
import { SequenceWatermark } from "../src/watermark.js";

test("watermark is idempotent and waits for sequence gaps", () => {
  const watermark = new SequenceWatermark();
  assert.equal(watermark.ingest([1, 2]).highestContiguousSequence, 2);
  assert.equal(watermark.ingest([4]).highestContiguousSequence, 2);
  const filled = watermark.ingest([3, 4]);
  assert.equal(filled.highestContiguousSequence, 4);
  assert.deepEqual(filled.duplicateSequences, [4]);
});

test("freshness never represents an old position as live", () => {
  const now = new Date("2026-09-01T07:10:00.000Z");
  assert.equal(classifyFreshness(undefined, now), "unknown");
  assert.equal(classifyFreshness(new Date("2026-09-01T07:09:50.000Z"), now), "live");
  assert.equal(classifyFreshness(new Date("2026-09-01T07:09:30.000Z"), now), "aging");
  assert.equal(classifyFreshness(new Date("2026-09-01T07:08:00.000Z"), now), "stale");
  assert.equal(classifyFreshness(new Date("2026-09-01T07:00:00.000Z"), now), "unknown");
});

test("aggregator coalesces one latest position per changed driver", () => {
  const aggregator = new TenantPositionAggregator();
  const base = {
    latitude: 13.7,
    longitude: 100.5,
    sourceAt: "2026-09-01T07:00:00.000Z",
    accuracyMeters: 8,
    source: "google_nav" as const,
    freshness: "live" as const,
  };
  aggregator.update("tenant-1", { ...base, driverId: "driver-2" });
  aggregator.update("tenant-1", { ...base, driverId: "driver-1", latitude: 13.71 });
  aggregator.update("tenant-1", { ...base, driverId: "driver-1", latitude: 13.72 });

  const event = aggregator.flush("tenant-1", new Date("2026-09-01T07:00:01.000Z"));
  assert.equal(event?.drivers.length, 2);
  assert.equal(event?.drivers[0]?.driverId, "driver-1");
  assert.equal(event?.drivers[0]?.latitude, 13.72);
  assert.equal(aggregator.flush("tenant-1", new Date()), undefined);
});

