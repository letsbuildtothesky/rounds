import assert from "node:assert/strict";
import { test } from "node:test";
import { checkWholeOrderPickup, type WholePickupOrder, type WholePickupSelection } from "../src/v23/whole-order-pickup.js";
import { v23PickupErrorCodes, v23PickupRequiredRoots } from "../../contracts/src/v23/pickup-metadata.js";

const order = (id = "1", quantity = 5): WholePickupOrder => ({
  delivery_id: `D${id}`, manifest_id: `M${id}`, fulfillment_unit_id: `U${id}`,
  preparation: "ready", inbound: "received", unit_state: "open",
  lines: [{ line_id: `L${id}`, quantity, available_quantity: quantity }],
});
const selection = (orders: readonly WholePickupOrder[]): WholePickupSelection => ({
  manifest_ids: orders.map((o) => o.manifest_id),
  fulfillment_unit_ids: orders.map((o) => o.fulfillment_unit_id),
  quantities: orders.flatMap((o) => o.lines.map(({ line_id, quantity }) => ({ line_id, quantity }))),
});

test("whole-order metadata includes readiness and whole-unit root", () => {
  assert.ok(v23PickupErrorCodes.includes("PICKUP_NOT_READY"));
  assert.ok(v23PickupRequiredRoots.some((r) => r.payload_field === "fulfillment_unit_ids[]"));
});
test("whole-order accepts the full manifest without mutating source or request", () => {
  const orders = [order()]; const request = selection(orders);
  const before = JSON.stringify({ orders, request });
  assert.deepEqual(checkWholeOrderPickup(orders, request), { ok: true });
  assert.equal(JSON.stringify({ orders, request }), before);
});
for (const quantity of [3, 6]) {
  test(`whole-order rejects ${quantity} of five, including excess`, () => {
    const orders = [order()];
    assert.deepEqual(checkWholeOrderPickup(orders, { ...selection(orders), quantities: [{ line_id: "L1", quantity }] }),
      { ok: false, code: "COMPLETE_ORDER_REQUIRED" });
  });
}
test("whole-order missing line cannot be hidden by equal total quantities", () => {
  const orders = [{ ...order(), lines: [...order().lines, { line_id: "L2", quantity: 1, available_quantity: 1 }] }];
  assert.deepEqual(checkWholeOrderPickup(orders, { ...selection(orders), quantities: [{ line_id: "L1", quantity: 6 }] }),
    { ok: false, code: "COMPLETE_ORDER_REQUIRED" });
});
for (const line_id of ["L1", "foreign-line"]) {
  test(`whole-order rejects duplicate/extra line ${line_id}`, () => {
    const orders = [order()]; const request = selection(orders);
    assert.deepEqual(checkWholeOrderPickup(orders, { ...request, quantities: [...request.quantities, { line_id, quantity: 5 }] }),
      { ok: false, code: "MANIFEST_MISMATCH" });
  });
}
for (const preparation of ["unknown", "preparing", "blocked"] as const) {
  test(`whole-order rejects preparation ${preparation} even with full physically available goods`, () => {
    const orders = [{ ...order(), preparation }];
    assert.deepEqual(checkWholeOrderPickup(orders, selection(orders)), { ok: false, code: "PICKUP_NOT_READY" });
  });
}
test("whole-order batch cannot silently drop an incomplete D1; explicitly adjusted independent D2 succeeds", () => {
  const d1 = { ...order(), lines: [{ line_id: "L1", quantity: 5, available_quantity: 3 }] };
  const d2 = order("2"); const orders = [d1, d2];
  assert.deepEqual(checkWholeOrderPickup(orders, selection(orders)), { ok: false, code: "INBOUND_NOT_RECEIVED" });
  assert.deepEqual(checkWholeOrderPickup(orders, selection([d2])), { ok: false, code: "MANIFEST_MISMATCH" });
  // Caller has separately authorised/locked the explicitly adjusted assignment.
  assert.deepEqual(checkWholeOrderPickup([d2], selection([d2])), { ok: true });
});
for (const inbound of ["awaiting", "discrepancy"] as const) {
  test(`whole-order ${inbound} cannot be overridden by submitted full quantities`, () => {
    const orders = [{ ...order(), inbound }];
    assert.deepEqual(checkWholeOrderPickup(orders, selection(orders)),
      { ok: false, code: inbound === "awaiting" ? "INBOUND_NOT_RECEIVED" : "INBOUND_DISCREPANCY" });
  });
}
for (const quantity of [0, -1, Number.NaN, Number.POSITIVE_INFINITY, 1_000_000.0001, 1.23456, 0.1 + 0.2]) {
  test(`whole-order rejects invalid wire precision/range ${quantity}`, () => {
    const orders = [order()];
    assert.deepEqual(checkWholeOrderPickup(orders, { ...selection(orders), quantities: [{ line_id: "L1", quantity }] }),
      { ok: false, code: "VALIDATION_FAILED" });
  });
}
for (const quantity of [0.0001, 0.1, 0.3, 1.2345, 999999.9999, 1000000]) {
  test(`whole-order exact decimal quantity ${quantity} passes without epsilon`, () => {
    const orders = [order("1", quantity)];
    assert.deepEqual(checkWholeOrderPickup(orders, selection(orders)), { ok: true });
  });
}
test("whole-order shuffled lines/selectors compare by stable identity", () => {
  const orders = [order(), order("2")]; const request = selection(orders);
  assert.deepEqual(checkWholeOrderPickup(orders, { manifest_ids: [...request.manifest_ids].reverse(),
    fulfillment_unit_ids: [...request.fulfillment_unit_ids].reverse(), quantities: [...request.quantities].reverse() }), { ok: true });
});
test("whole-order cannot represent two units of one customer delivery", () => {
  const orders = [order(), { ...order("2"), delivery_id: "D1" }];
  assert.deepEqual(checkWholeOrderPickup(orders, selection(orders)), { ok: false, code: "MANIFEST_MISMATCH" });
});
test("whole-order already collected unit rejects fresh mutation; replay belongs to command receipt runner", () => {
  const orders = [{ ...order(), unit_state: "collected" as const }];
  assert.deepEqual(checkWholeOrderPickup(orders, selection(orders)), { ok: false, code: "IMMUTABLE_RECORD" });
});
test("whole-order empty batch and duplicated manifest selector reject", () => {
  assert.deepEqual(checkWholeOrderPickup([], selection([])), { ok: false, code: "VALIDATION_FAILED" });
  const orders = [order()]; const request = selection(orders);
  assert.deepEqual(checkWholeOrderPickup(orders, { ...request, manifest_ids: ["M1", "M1"] }), { ok: false, code: "MANIFEST_MISMATCH" });
});
