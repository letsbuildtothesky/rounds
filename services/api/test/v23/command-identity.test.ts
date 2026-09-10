import assert from "node:assert/strict";
import { test } from "node:test";
import { canonicalCommandJson as json, commandRequestHash as hash } from "../../src/v23/command-identity.js";

test("canonical identity sorts object keys and preserves arrays, Unicode and finite numbers", () => {
  assert.equal(json({ z: [2, 1], a: { thai: "ไทย", zero: -0, n: 1.2345 } }),
    '{"a":{"n":1.2345,"thai":"ไทย","zero":0},"z":[2,1]}');
  assert.equal(hash("ConfirmPickup", { b: 2, a: 1 }), hash("ConfirmPickup", { a: 1, b: 2 }));
  assert.notEqual(hash("ConfirmPickup", [1, 2]), hash("ConfirmPickup", [2, 1]));
  assert.notEqual(hash("ConfirmPickup", "é"), hash("ConfirmPickup", "e\u0301"));
});
test("identity hashes the entire original envelope, including command kind, context, versions and fence", () => {
  const request = { command_id: "id", context: { tenant_id: "tenant", city_id: "city" }, occurred_at: "time",
    expected_versions: [{ aggregate_type: "rounds", id: "round", version: 1 }],
    execution_fence: { assignment_id: "assignment", assignment_version: 1, observation_id: "observation" }, payload: { quantity: 5 } };
  for (const key of Object.keys(request)) assert.notEqual(hash("ConfirmPickup", request), hash("ConfirmPickup", { ...request, [key]: null }), key);
  assert.notEqual(hash("ConfirmPickup", request), hash("ConfirmHandoff", request));
});
for (const value of [undefined, NaN, Infinity, 1n, new Date(), new Map(), { a: undefined }, [undefined], [, 1], "\ud800"]) {
  test(`rejects lossy non-JSON input ${Object.prototype.toString.call(value)}`, () => assert.throws(() => json(value), TypeError));
}
test("rejects getters and extra/symbol array properties without executing them", () => {
  let calls = 0;
  const getter = { get x() { calls++; return 1; } };
  const a = [1]; Object.defineProperty(a, "0", { get: () => { calls++; return 1; } });
  const b = [1]; Object.defineProperty(b, Symbol("x"), { value: 1 });
  const c = [1]; Object.defineProperty(c, "extra", { value: 1 });
  for (const value of [getter, a, b, c]) assert.throws(() => json(value), TypeError);
  assert.equal(calls, 0);
});
test("cycles and excessive size/depth reject; repeated noncyclic references are valid", () => {
  const cyclic: { self?: unknown } = {}; cyclic.self = cyclic;
  assert.throws(() => json(cyclic), TypeError);
  assert.throws(() => json("a".repeat(1_048_576)), TypeError);
  let deep: unknown = 1; for (let i = 0; i < 66; i++) deep = { deep };
  assert.throws(() => json(deep), TypeError);
  const shared = { a: 1 }; assert.equal(json([shared, shared]), '[{"a":1},{"a":1}]');
});
