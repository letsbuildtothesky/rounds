import assert from "node:assert/strict";
import test from "node:test";
import { parseDatabasePoint, selectDriverAssignedRound } from "../src/supabase-gateway.js";

test("decodes the PostGIS EWKB point returned by Supabase REST", () => {
  const coordinate = parseDatabasePoint("0101000020E61000005EBA490C0223594022FDF675E07C2B40");
  assert.ok(coordinate);
  assert.equal(coordinate.longitude, 100.547);
  assert.equal(coordinate.latitude, 13.7439);
});

test("also accepts a GeoJSON point", () => {
  assert.deepEqual(parseDatabasePoint({ type: "Point", coordinates: [100.57, 13.73] }), {
    longitude: 100.57,
    latitude: 13.73,
  });
});

test("selects active work before today's or stale approved Rounds", () => {
  const rounds = [
    { id: "old", reference: "OLD", service_date: "2026-09-01", state: "approved" as const },
    { id: "today", reference: "TODAY", service_date: "2026-09-03", state: "approved" as const },
    { id: "active", reference: "ACTIVE", service_date: "2026-09-02", state: "active" as const },
  ];
  assert.equal(selectDriverAssignedRound(rounds, "2026-09-03")?.id, "active");
});

test("selects today's assignment, then nearest future, then latest past", () => {
  const base = [
    { id: "past-old", reference: "PAST OLD", service_date: "2026-09-01", state: "approved" as const },
    { id: "past-new", reference: "PAST NEW", service_date: "2026-09-02", state: "approved" as const },
    { id: "future-near", reference: "FUTURE NEAR", service_date: "2026-09-04", state: "approved" as const },
    { id: "future-far", reference: "FUTURE FAR", service_date: "2026-09-05", state: "approved" as const },
  ];
  const today = { id: "today", reference: "TODAY", service_date: "2026-09-03", state: "approved" as const };
  assert.equal(selectDriverAssignedRound([...base, today], "2026-09-03")?.id, "today");
  assert.equal(selectDriverAssignedRound(base, "2026-09-03")?.id, "future-near");
  assert.equal(selectDriverAssignedRound(base.slice(0, 2), "2026-09-03")?.id, "past-new");
});
