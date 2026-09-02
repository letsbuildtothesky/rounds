import type { OperationsRoundSummary } from "./round.js";
import type { DeliveryState } from "./delivery.js";
import type { CommandEnvelope, CommandResult, DomainEventEnvelope } from "./command.js";

export const operationsRoles = [
  "tenant_owner",
  "operations_admin",
  "dispatcher",
  "viewer",
] as const;

export type OperationsRole = (typeof operationsRoles)[number];

export type OperationsLocation = {
  id: string;
  code: string;
  displayName: string;
  rawAddress: string;
  pickupContactName: string;
  pickupContactPhone: string;
};

export type OperationsTenant = {
  id: string;
  displayName: string;
  timezone: string;
  role: OperationsRole;
  locations: OperationsLocation[];
};

export type OperationsSession = {
  user: {
    id: string;
    email?: string;
    displayName: string;
  };
  tenants: OperationsTenant[];
};

export type OperationsHistoryItem = {
  podId: string;
  deliveryId: string;
  stopId: string;
  roundId: string;
  deliveryReference: string;
  roundReference: string;
  recipientName: string;
  rawAddress: string;
  driverName: string;
  handoffType: "recipient" | "someone_else" | "left_at_location";
  receiverLabel: string;
  deliveredAt: string;
  manifestVersion: number;
  verifiedPhotoCount: 1;
  mediaAssetId: string;
  mediaState: "committed";
};

export type OperationsHistoryProjection = {
  tenantId: string;
  deliveries: OperationsHistoryItem[];
};

export type OperationsActionException = {
  id: string;
  deliveryId: string;
  deliveryReference: string;
  recipientName: string;
  rawAddress: string;
  coordinate?: {
    latitude: number;
    longitude: number;
  };
  stopId: string;
  stopSequence: number;
  stopState: string;
  stopVersion: number;
  roundId: string;
  roundReference: string;
  roundState: string;
  driverId: string;
  driverName: string;
  stage: "pickup" | "delivery";
  category: "missing_item" | "wrong_item" | "damaged_item";
  note?: string;
  status: "open";
  manifestVersion: number;
  reportedAt: string;
  operationsThreadId?: string;
};

export const operationsExceptionResolutions = ["pickup_corrected"] as const;
export type OperationsExceptionResolution = (typeof operationsExceptionResolutions)[number];

export type ResolveOperationsExceptionPayload = {
  exceptionId: string;
  resolution: OperationsExceptionResolution;
  note: string;
};

export type ResolveOperationsExceptionCommand = CommandEnvelope<"operations.resolve_exception", ResolveOperationsExceptionPayload>;
export type OperationsExceptionResolvedPayload = {
  exceptionId: string;
  stopId: string;
  deliveryId: string;
  roundId: string;
  resolution: OperationsExceptionResolution;
  resolvedAt: string;
};
export type OperationsExceptionResolvedEvent = DomainEventEnvelope<"operations.exception_resolved", OperationsExceptionResolvedPayload>;
export type ResolveOperationsExceptionState = OperationsExceptionResolvedPayload & { stopState: "assigned"; deliveryState: "assigned" };
export type ResolveOperationsExceptionResult = CommandResult<ResolveOperationsExceptionState, OperationsExceptionResolvedEvent>;

export type OperationsActionProjection = {
  tenantId: string;
  observedAt: string;
  rounds: OperationsRoundSummary[];
  exceptions: OperationsActionException[];
};

export type OperationsDeliveryItem = {
  deliveryId: string;
  reference: string;
  state: DeliveryState;
  version: number;
  sourceSystem: string;
  serviceDate: string;
  serviceTimezone: string;
  pickupLocationId: string;
  pickupLocationName: string;
  buyerSameAsRecipient: boolean;
  buyerName: string;
  buyerPhone: string;
  recipientName: string;
  recipientPhone: string;
  rawAddress: string;
  coordinate?: { latitude: number; longitude: number };
  accessNote?: string;
  deliveryNote?: string;
  isSurprise: boolean;
  createdAt: string;
  updatedAt: string;
  stop: {
    id: string;
    state: string;
    version: number;
  };
  promise: {
    windowStart: string;
    windowEnd: string;
  };
  manifest: {
    id: string;
    state: string;
    version: number;
    items: Array<{
      lineNumber: number;
      description: string;
      quantity: number;
      handlingNote?: string;
    }>;
  };
  round?: {
    id: string;
    reference: string;
    state: string;
    sequence: number;
    driverName: string;
  };
};

export type OperationsDeliveriesProjection = {
  tenantId: string;
  observedAt: string;
  deliveries: OperationsDeliveryItem[];
};
