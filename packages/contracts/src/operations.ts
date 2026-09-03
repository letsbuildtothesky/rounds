import type { OperationsRoundSummary } from "./round.js";
import type { DeliveryState } from "./delivery.js";
import type { CommandEnvelope, CommandResult, DomainEventEnvelope } from "./command.js";
import type { VehicleCargoLimit } from "./capacity.js";

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

type OperationsHistoryItemBase = {
  recordId: string;
  deliveryId: string;
  stopId: string;
  roundId: string;
  deliveryReference: string;
  roundReference: string;
  recipientName: string;
  rawAddress: string;
  driverName: string;
  manifestVersion: number;
  verifiedPhotoCount: 1;
  mediaAssetId: string;
  mediaState: "committed";
};

export type OperationsDeliveredHistoryItem = OperationsHistoryItemBase & {
  outcome: "delivered";
  podId: string;
  handoffType: "recipient" | "someone_else" | "left_at_location";
  receiverLabel: string;
  deliveredAt: string;
  occurredAt: string;
};

export type OperationsReturnedHistoryItem = OperationsHistoryItemBase & {
  outcome: "returned";
  exceptionId: string;
  category: "damaged_item";
  exceptionNote?: string;
  resolutionNote?: string;
  reportedAt: string;
  returnedAt: string;
  occurredAt: string;
};

export type OperationsHistoryItem = OperationsDeliveredHistoryItem | OperationsReturnedHistoryItem;

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
  category:
    | "missing_item"
    | "wrong_item"
    | "damaged_item"
    | "wrong_pin"
    | "wrong_entrance"
    | "wrong_address"
    | "cannot_find_location";
  note?: string;
  expectedCoordinate?: { latitude: number; longitude: number };
  observedCoordinate?: { latitude: number; longitude: number };
  observedAccuracyMeters?: number;
  observedLocationSource?: "google_nav" | "rounds_os" | "unknown";
  originalStopState?: string;
  originalDeliveryState?: DeliveryState;
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

export type ConfirmDeliveryReturnPayload = {
  exceptionId: string;
  note: string;
};

export type ConfirmDeliveryReturnCommand = CommandEnvelope<"operations.confirm_delivery_return", ConfirmDeliveryReturnPayload>;
export type DeliveryReturnConfirmedPayload = {
  exceptionId: string;
  stopId: string;
  deliveryId: string;
  roundId: string;
  resolution: "delivery_returned";
  returnedAt: string;
};
export type DeliveryReturnConfirmedEvent = DomainEventEnvelope<"operations.delivery_return_confirmed", DeliveryReturnConfirmedPayload>;
export type ConfirmDeliveryReturnState = DeliveryReturnConfirmedPayload & {
  stopState: "cancelled";
  deliveryState: "returned";
  roundState: "active" | "complete";
  roundVersion: number;
};
export type ConfirmDeliveryReturnResult = CommandResult<ConfirmDeliveryReturnState, DeliveryReturnConfirmedEvent>;

export type OperationsActionProjection = {
  tenantId: string;
  observedAt: string;
  rounds: OperationsRoundSummary[];
  exceptions: OperationsActionException[];
};

export type OperationsVehicleProfileSummary = {
  id: string;
  code: string;
  displayName: string;
  vehicleGroup: "motorbike" | "car" | "van" | "pickup" | "cargo_bike" | "other";
  departurePattern: "multi_stop" | "return_after_every_delivery" | "return_after_round" | "return_when_capacity_exhausted";
  maxStopsPerDeparture: number;
  planningDeliveriesPerBlock: number;
  pickupTurnaroundMinutes: number;
  requiresReview: boolean;
  version: number;
  cargoLimits: VehicleCargoLimit[];
};

export type OperationsDriverCapacityItem = {
  driverId: string;
  displayName: string;
  initials: string;
  phone?: string;
  vehiclePlate?: string;
  presence: {
    state: "live" | "stale" | "unknown";
    capturedAt?: string;
  };
  availability: {
    state: "on_round" | "loading" | "available" | "off_shift" | "schedule_required";
    label: string;
    nextAvailableAt?: string;
    projectionBasis: string;
  };
  effectiveShift?: {
    source: "recurring" | "exception";
    startAt: string;
    endAt: string;
    crossesMidnight: boolean;
  };
  schedule?: {
    id: string;
    version: number;
    weekdays: number[];
    startLocal: string;
    endLocal: string;
    note?: string;
  };
  dateException?: {
    id: string;
    version: number;
    serviceDate: string;
    kind: "shift" | "off";
    startLocal?: string;
    endLocal?: string;
    vehicleProfileId?: string;
    note?: string;
  };
  vehicleProfile?: OperationsVehicleProfileSummary;
  currentRound?: {
    id: string;
    reference: string;
    state: "approved" | "loading" | "active";
    stopCount: number;
  };
  completedDeliveriesToday: number;
};

export type OperationsDriversProjection = {
  tenantId: string;
  serviceDate: string;
  observedAt: string;
  drivers: OperationsDriverCapacityItem[];
  vehicleProfiles: OperationsVehicleProfileSummary[];
  summary: {
    ownDrivers: number;
    scheduled: number;
    activeRounds: number;
    availableNow: number;
    scheduleRequired: number;
    vehicleGroups: Record<string, number>;
  };
};

export type SetDriverRecurringSchedulePayload = {
  weekdays: number[];
  startLocal: string;
  endLocal: string;
  vehicleProfileId: string;
  note?: string;
};

export type SetDriverRecurringScheduleCommand = CommandEnvelope<
  "operations.set_driver_recurring_schedule",
  SetDriverRecurringSchedulePayload
>;
export type DriverRecurringScheduleSetPayload = {
  scheduleId: string;
  driverId: string;
  weekdays: number[];
  startLocal: string;
  endLocal: string;
  vehicleProfileId: string;
  updatedAt: string;
};
export type DriverRecurringScheduleSetEvent = DomainEventEnvelope<
  "operations.driver_recurring_schedule_set",
  DriverRecurringScheduleSetPayload
>;
export type SetDriverRecurringScheduleResult = CommandResult<
  DriverRecurringScheduleSetPayload,
  DriverRecurringScheduleSetEvent
>;

export type SetDriverShiftExceptionPayload = {
  serviceDate: string;
  kind: "shift" | "off";
  startLocal?: string;
  endLocal?: string;
  vehicleProfileId?: string;
  note?: string;
};

export type SetDriverShiftExceptionCommand = CommandEnvelope<
  "operations.set_driver_shift_exception",
  SetDriverShiftExceptionPayload
>;
export type DriverShiftExceptionSetPayload = {
  exceptionId: string;
  driverId: string;
  serviceDate: string;
  kind: "shift" | "off";
  startLocal?: string;
  endLocal?: string;
  vehicleProfileId?: string;
  updatedAt: string;
};
export type DriverShiftExceptionSetEvent = DomainEventEnvelope<
  "operations.driver_shift_exception_set",
  DriverShiftExceptionSetPayload
>;
export type SetDriverShiftExceptionResult = CommandResult<
  DriverShiftExceptionSetPayload,
  DriverShiftExceptionSetEvent
>;

export type ClearDriverShiftExceptionPayload = { serviceDate: string };
export type ClearDriverShiftExceptionCommand = CommandEnvelope<
  "operations.clear_driver_shift_exception",
  ClearDriverShiftExceptionPayload
>;
export type DriverShiftExceptionClearedPayload = {
  exceptionId: string;
  driverId: string;
  serviceDate: string;
  clearedAt: string;
};
export type DriverShiftExceptionClearedEvent = DomainEventEnvelope<
  "operations.driver_shift_exception_cleared",
  DriverShiftExceptionClearedPayload
>;
export type ClearDriverShiftExceptionResult = CommandResult<
  DriverShiftExceptionClearedPayload,
  DriverShiftExceptionClearedEvent
>;

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
