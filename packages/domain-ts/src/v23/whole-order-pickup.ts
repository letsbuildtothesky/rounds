import type { V23PickupErrorCode } from "../../../contracts/src/v23/pickup-metadata.js";

export type PickupLine = Readonly<{ line_id: string; quantity: number }>;
export type WholePickupOrder = Readonly<{
  delivery_id: string;
  manifest_id: string;
  fulfillment_unit_id: string;
  unit_state: "open" | "collected" | "delivered" | "returned" | "cancelled";
  preparation: "unknown" | "preparing" | "ready" | "blocked";
  inbound: "not_required" | "received" | "awaiting" | "discrepancy";
  lines: readonly Readonly<PickupLine & { available_quantity: number }>[];
}>;
export type WholePickupSelection = Readonly<{
  manifest_ids: readonly string[];
  fulfillment_unit_ids: readonly string[];
  quantities: readonly PickupLine[];
}>;
export type WholePickupCheck = { ok: true } | { ok: false; code: V23PickupErrorCode };

// SQL quantity precision is four decimal places. Integer quanta avoid accepting
// shortages through accumulated floating-point/epsilon comparisons.
function quanta(value: number, allowZero = false): number | null {
  if (!Number.isFinite(value) || value < 0 || (!allowZero && value === 0) || value > 1_000_000) return null;
  const scaled = Math.round(value * 10_000);
  return scaled / 10_000 === value ? scaled : null;
}

function sameUniqueIds(actual: readonly string[], expected: readonly string[]): boolean {
  const ids = new Set(actual);
  return ids.size === actual.length && actual.length === expected.length && expected.every((id) => ids.has(id));
}

/** Pure transaction precondition, not authentication or a command handler.
 * `orders` must be the complete authorized selection resolved under locks from
 * the current route/assignment, NOT filtered to accommodate the submitted map.
 * The caller validates wire schema, scope, original fence and versions first,
 * calls this before ANY custody/attempt writes, and commits the whole batch.
 * Replays resolve the original command receipt before re-evaluating state.
 */
export function checkWholeOrderPickup(
  orders: readonly WholePickupOrder[],
  submitted: WholePickupSelection,
): WholePickupCheck {
  const fail = (code: V23PickupErrorCode): WholePickupCheck => ({ ok: false, code });
  if (orders.length === 0 || orders.length > 1000 || submitted.quantities.length === 0 || submitted.quantities.length > 1000) {
    return fail("VALIDATION_FAILED");
  }
  for (const field of ["delivery_id", "manifest_id", "fulfillment_unit_id"] as const) {
    if (orders.some((order) => !order[field]) || new Set(orders.map((order) => order[field])).size !== orders.length) {
      return fail("MANIFEST_MISMATCH");
    }
  }
  if (!sameUniqueIds(submitted.manifest_ids, orders.map((order) => order.manifest_id)) ||
      !sameUniqueIds(submitted.fulfillment_unit_ids, orders.map((order) => order.fulfillment_unit_id))) {
    return fail("MANIFEST_MISMATCH");
  }
  const required = new Map<string, { expected: number; available: number }>();
  for (const order of orders) {
    if (order.lines.length === 0) return fail("MANIFEST_MISMATCH");
    for (const line of order.lines) {
      const expected = quanta(line.quantity);
      const available = quanta(line.available_quantity, true);
      if (!line.line_id || required.has(line.line_id)) return fail("MANIFEST_MISMATCH");
      if (expected === null || available === null) return fail("VALIDATION_FAILED");
      required.set(line.line_id, { expected, available });
    }
  }
  if (required.size > 1000) return fail("VALIDATION_FAILED");
  const actual = new Map<string, number>();
  for (const line of submitted.quantities) {
    if (!required.has(line.line_id) || actual.has(line.line_id)) return fail("MANIFEST_MISMATCH");
    const quantity = quanta(line.quantity);
    if (quantity === null) return fail("VALIDATION_FAILED");
    actual.set(line.line_id, quantity);
  }
  if (actual.size !== required.size) return fail("COMPLETE_ORDER_REQUIRED");
  for (const [id, quantity] of actual) {
    if (quantity !== required.get(id)!.expected) return fail("COMPLETE_ORDER_REQUIRED");
  }
  // Do not silently select the ready subset of a submitted batch.
  if (orders.some((order) => order.unit_state !== "open")) return fail("IMMUTABLE_RECORD");
  if (orders.some((order) => order.inbound === "discrepancy")) return fail("INBOUND_DISCREPANCY");
  if (orders.some((order) => order.inbound === "awaiting") ||
      [...required.values()].some((line) => line.available < line.expected)) return fail("INBOUND_NOT_RECEIVED");
  if (orders.some((order) => order.preparation !== "ready")) return fail("PICKUP_NOT_READY");
  return { ok: true };
}
