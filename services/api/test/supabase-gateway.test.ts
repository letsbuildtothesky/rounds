import assert from "node:assert/strict";
import test from "node:test";
import { parseDatabasePoint } from "../src/supabase-gateway.js";

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
