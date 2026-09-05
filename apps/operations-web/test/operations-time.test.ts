import assert from "node:assert/strict";
import test from "node:test";
import { tenantLocalDateTimeInput, tenantLocalDateTimeToIso } from "../src/operations-time";

test("round-trips a Bangkok promise independently of the browser timezone", () => {
  const instant = "2026-09-03T05:00:00.000Z";
  const local = tenantLocalDateTimeInput(instant, "Asia/Bangkok");
  assert.equal(local, "2026-09-03T12:00");
  assert.equal(tenantLocalDateTimeToIso(local, "Asia/Bangkok"), instant);
});

test("honors a daylight-saving tenant timezone", () => {
  assert.equal(tenantLocalDateTimeInput("2026-07-01T16:30:00.000Z", "America/New_York"), "2026-07-01T12:30");
  assert.equal(tenantLocalDateTimeToIso("2026-07-01T12:30", "America/New_York"), "2026-07-01T16:30:00.000Z");
});
