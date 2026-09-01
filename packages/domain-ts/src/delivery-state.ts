import type { DeliveryState } from "@rounds/contracts";

const allowedTransitions: Readonly<Record<DeliveryState, ReadonlySet<DeliveryState>>> = {
  draft: new Set(["unplanned", "cancelled"]),
  unplanned: new Set(["planned", "cancelled"]),
  planned: new Set(["assigned", "cancelled"]),
  assigned: new Set(["pickup_pending", "cancelled"]),
  pickup_pending: new Set(["in_custody", "exception", "cancelled"]),
  in_custody: new Set(["en_route", "exception", "returned"]),
  en_route: new Set(["arrived", "exception", "returned"]),
  arrived: new Set(["delivered_pending_evidence", "exception", "returned"]),
  delivered_pending_evidence: new Set(["delivered", "exception"]),
  delivered: new Set(),
  exception: new Set(),
  returned: new Set(),
  cancelled: new Set(),
};

export class InvalidDeliveryTransitionError extends Error {
  readonly code = "INVALID_STATE" as const;

  constructor(readonly from: DeliveryState, readonly to: DeliveryState) {
    super(`INVALID_STATE: ${from} -> ${to}`);
  }
}

export function canTransitionDelivery(from: DeliveryState, to: DeliveryState): boolean {
  return from === to || allowedTransitions[from].has(to);
}

export function assertDeliveryTransition(from: DeliveryState, to: DeliveryState): void {
  if (!canTransitionDelivery(from, to)) {
    throw new InvalidDeliveryTransitionError(from, to);
  }
}
