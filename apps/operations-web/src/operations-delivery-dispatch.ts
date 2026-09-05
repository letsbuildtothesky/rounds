import type { OperationsDeliveryItem } from "@rounds/contracts";

export type DeliveryQueueTab = "ready" | "live" | "done";
export type DeliveryScope = "all" | "today";

const readyStates = new Set<OperationsDeliveryItem["state"]>([
  "draft",
  "unplanned",
  "planned",
  "assigned",
  "pickup_pending",
]);

const liveStates = new Set<OperationsDeliveryItem["state"]>([
  "in_custody",
  "en_route",
  "arrived",
  "delivered_pending_evidence",
]);

const doneStates = new Set<OperationsDeliveryItem["state"]>([
  "delivered",
  "returned",
  "cancelled",
]);

export function deliveryQueueTab(item: OperationsDeliveryItem): DeliveryQueueTab | null {
  if (readyStates.has(item.state)) return "ready";
  if (liveStates.has(item.state)) return "live";
  if (doneStates.has(item.state)) return "done";
  return null;
}

export function deliveryMatchesScope(item: OperationsDeliveryItem, scope: DeliveryScope, today: string): boolean {
  return scope === "all" || item.serviceDate === today;
}

export function deliveryMatchesSearch(item: OperationsDeliveryItem, query: string): boolean {
  const needle = query.trim().toLowerCase();
  if (!needle) return true;
  return `${item.reference} ${item.recipientName} ${item.rawAddress} ${item.recipientPhone} ${item.round?.reference ?? ""}`
    .toLowerCase()
    .includes(needle);
}

export type DeliveryCommandBoundary = "plan" | "round-pre-custody" | "round-live" | "history" | "exception";

export function deliveryCommandBoundary(item: OperationsDeliveryItem): DeliveryCommandBoundary {
  if (item.state === "exception") return "exception";
  if (doneStates.has(item.state)) return "history";
  if (liveStates.has(item.state)) return "round-live";
  if (item.round) return "round-pre-custody";
  return "plan";
}
