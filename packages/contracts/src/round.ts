import type { CommandEnvelope, CommandResult, DomainEventEnvelope } from "./command.js";

export const roundStates = [
  "proposed",
  "approved",
  "loading",
  "active",
  "complete",
  "cancelled",
] as const;

export type RoundState = (typeof roundStates)[number];

export type TeamDriverSummary = {
  id: string;
  displayName: string;
  vehicleLabel?: string;
  vehiclePlate?: string;
};

export type UnplannedDeliverySummary = {
  deliveryId: string;
  stopId: string;
  reference: string;
  serviceDate: string;
  pickupLocationId: string;
  recipientName: string;
  rawAddress: string;
  windowStart: string;
  windowEnd: string;
  manifestSummary: string;
};

export type OperationsPlanningProjection = {
  tenantId: string;
  drivers: TeamDriverSummary[];
  unplannedDeliveries: UnplannedDeliverySummary[];
  activeRounds: OperationsRoundSummary[];
};

export type OperationsRoundSummary = {
  id: string;
  reference: string;
  serviceDate: string;
  state: RoundState;
  driverId: string;
  driverName: string;
  stopCount: number;
  custodyStopCount: number;
  openExceptionCount: number;
};

export type PlanRoundPayload = {
  reference: string;
  serviceDate: string;
  driverId: string;
  stopIds: string[];
};

export type PlanRoundCommand = CommandEnvelope<"round.plan_and_approve", PlanRoundPayload>;

export type RoundApprovedPayload = {
  roundId: string;
  driverId: string;
  stopIds: string[];
  deliveryIds: string[];
};

export type RoundApprovedEvent = DomainEventEnvelope<"round.approved", RoundApprovedPayload>;

export type PlanRoundState = {
  roundId: string;
  reference: string;
  roundState: "approved";
  driverId: string;
  stopIds: string[];
  deliveryIds: string[];
};

export type PlanRoundResult = CommandResult<PlanRoundState, RoundApprovedEvent>;

export type PickupStopVerification = {
  stopId: string;
  manifestId: string;
  manifestVersion: number;
  confirmedLineNumbers: number[];
};

export type ConfirmPickupPayload = {
  stops: PickupStopVerification[];
};

export type ConfirmPickupCommand = CommandEnvelope<"round.confirm_pickup", ConfirmPickupPayload>;

export type PickupConfirmedStop = {
  stopId: string;
  deliveryId: string;
  manifestId: string;
  manifestVersion: number;
  verificationId: string;
  custodyEventId: string;
  verifiedUnits: number;
};

export type PickupConfirmedPayload = {
  roundId: string;
  driverId: string;
  stops: PickupConfirmedStop[];
};

export type PickupConfirmedEvent = DomainEventEnvelope<"round.pickup_confirmed", PickupConfirmedPayload>;

export type ConfirmPickupState = {
  roundId: string;
  roundState: "active";
  driverId: string;
  stops: PickupConfirmedStop[];
};

export type ConfirmPickupResult = CommandResult<ConfirmPickupState, PickupConfirmedEvent>;

export const pickupProblemCategories = [
  "missing_item",
  "wrong_item",
  "damaged_item",
] as const;

export type PickupProblemCategory = (typeof pickupProblemCategories)[number];

export type ReportPickupProblemPayload = {
  manifestId: string;
  manifestVersion: number;
  category: PickupProblemCategory;
  note?: string;
};

export type ReportPickupProblemCommand = CommandEnvelope<
  "stop.report_pickup_problem",
  ReportPickupProblemPayload
>;

export type PickupProblemReportedPayload = {
  exceptionId: string;
  stopId: string;
  deliveryId: string;
  roundId: string;
  category: PickupProblemCategory;
};

export type PickupProblemReportedEvent = DomainEventEnvelope<
  "stop.pickup_problem_reported",
  PickupProblemReportedPayload
>;

export type ReportPickupProblemState = PickupProblemReportedPayload & {
  stopState: "exception";
  deliveryState: "exception";
};

export type ReportPickupProblemResult = CommandResult<
  ReportPickupProblemState,
  PickupProblemReportedEvent
>;

export type ArrivalPositionEvidence = {
  latitude: number;
  longitude: number;
  accuracyMeters: number;
  source: "google_nav" | "rounds_os" | "unknown";
};

export type ConfirmStopArrivalPayload = {
  position?: ArrivalPositionEvidence;
  overrideReason?: string;
};

export type ConfirmStopArrivalCommand = CommandEnvelope<
  "stop.confirm_arrival",
  ConfirmStopArrivalPayload
>;

export type StopArrivalConfirmedPayload = {
  arrivalId: string;
  stopId: string;
  deliveryId: string;
  roundId: string;
  driverId: string;
  arrivedAt: string;
};

export type StopArrivalConfirmedEvent = DomainEventEnvelope<
  "stop.arrival_confirmed",
  StopArrivalConfirmedPayload
>;

export type ConfirmStopArrivalState = StopArrivalConfirmedPayload & {
  stopState: "arrived";
  deliveryState: "arrived";
};

export type ConfirmStopArrivalResult = CommandResult<
  ConfirmStopArrivalState,
  StopArrivalConfirmedEvent
>;

export type DriverManifestItem = {
  lineNumber: number;
  description: string;
  quantity: number;
  handlingNote?: string;
};

export type DriverRoundStop = {
  id: string;
  sequence: number;
  state: string;
  version: number;
  destinationVersion: number;
  deliveryId: string;
  deliveryReference: string;
  recipientName: string;
  recipientPhone: string;
  rawAddress: string;
  latitude: number;
  longitude: number;
  accessNote?: string;
  deliveryNote?: string;
  isSurprise: boolean;
  windowStart: string;
  windowEnd: string;
  manifestId: string;
  manifestVersion: number;
  manifestItems: DriverManifestItem[];
};

export type DriverRound = {
  id: string;
  reference: string;
  serviceDate: string;
  state: RoundState;
  version: number;
  tenant: { id: string; displayName: string; timezone: string };
  pickup: {
    id: string;
    displayName: string;
    rawAddress: string;
    contactName: string;
    contactPhone: string;
    latitude?: number;
    longitude?: number;
  };
  stops: DriverRoundStop[];
};

export type DriverSession = {
  user: { id: string; displayName: string };
  driver: { id: string; preferredLocale: string; vehicleLabel?: string; vehiclePlate?: string };
  currentRound?: DriverRound;
};
