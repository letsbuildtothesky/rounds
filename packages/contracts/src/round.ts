import type { CommandEnvelope, CommandResult, DomainEventEnvelope } from "./command.js";
import type { CapacityEvaluation, CargoRequirement } from "./capacity.js";

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
  coordinate?: {
    latitude: number;
    longitude: number;
  };
  windowStart: string;
  windowEnd: string;
  manifestSummary: string;
  cargoRequirements: CargoRequirement[];
};

export type OperationsPlanningProjection = {
  tenantId: string;
  drivers: TeamDriverSummary[];
  unplannedDeliveries: UnplannedDeliverySummary[];
  activeRounds: OperationsRoundSummary[];
};

export type PlanningRouteStop = {
  stopId: string;
  sequence: number;
  eta: string;
  departureAt: string;
  windowStart: string;
  windowEnd: string;
  promiseStatus: "early" | "safe" | "late";
  waitingSeconds: number;
  latenessSeconds: number;
  legDurationSeconds: number;
  legDistanceMeters: number;
};

export type PlanningRouteSnapshot = {
  status: "fits" | "blocked";
  serviceDate: string;
  driverId: string;
  stopIds: string[];
  calculatedAt: string;
  departureAt: string;
  finishAt: string;
  distanceMeters: number;
  durationSeconds: number;
  provider: {
    name: "mapbox";
    profile: "driving-traffic";
    freshness: "live" | "current_snapshot";
  };
  stops: PlanningRouteStop[];
  blockingReasons: string[];
  warnings: string[];
  capacity: CapacityEvaluation;
};

export type PlanningRoutePreviewRequest = {
  serviceDate: string;
  driverId: string;
  stopIds: string[];
};

export type PlanningRoutePreview = PlanningRouteSnapshot & {
  tenantId: string;
  geometry: {
    type: "LineString";
    coordinates: [number, number][];
  };
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
  currentPosition?: {
    latitude: number;
    longitude: number;
    capturedAt: string;
  };
};

export type OperationsRoundStopDetail = {
  stopId: string;
  sequence: number;
  stopState: string;
  stopVersion: number;
  deliveryId: string;
  deliveryReference: string;
  deliveryState: string;
  recipientName: string;
  recipientPhone: string;
  rawAddress: string;
  coordinate?: { latitude: number; longitude: number };
  windowStart: string;
  windowEnd: string;
  manifest: {
    id: string;
    state: string;
    version: number;
    items: Array<{ lineNumber: number; description: string; quantity: number; cargoClass?: string; handlingNote?: string }>;
  };
  pickupConfirmed: boolean;
  arrivedAt?: string;
  completedAt?: string;
  openExceptionCount: number;
  operationsThreadId?: string;
};

export type OperationsRoundDetail = {
  tenantId: string;
  observedAt: string;
  id: string;
  reference: string;
  serviceDate: string;
  state: RoundState;
  version: number;
  driver: TeamDriverSummary;
  pickup: { id: string; displayName: string };
  stops: OperationsRoundStopDetail[];
  custodyStopCount: number;
  openExceptionCount: number;
  currentPosition?: { latitude: number; longitude: number; capturedAt: string };
};

export type PlanRoundPayload = {
  reference: string;
  serviceDate: string;
  driverId: string;
  stopIds: string[];
  routePlan: PlanningRouteSnapshot;
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

export const deliveryProblemCategories = ["damaged_item"] as const;

export type DeliveryProblemCategory = (typeof deliveryProblemCategories)[number];

export type ReportDeliveryProblemPayload = {
  manifestId: string;
  manifestVersion: number;
  category: DeliveryProblemCategory;
  mediaAssetId: string;
  note?: string;
};

export type ReportDeliveryProblemCommand = CommandEnvelope<
  "stop.report_delivery_problem",
  ReportDeliveryProblemPayload
>;

export type DeliveryProblemReportedPayload = {
  exceptionId: string;
  mediaAssetId: string;
  stopId: string;
  deliveryId: string;
  roundId: string;
  category: DeliveryProblemCategory;
};

export type DeliveryProblemReportedEvent = DomainEventEnvelope<
  "stop.delivery_problem_reported",
  DeliveryProblemReportedPayload
>;

export type ReportDeliveryProblemState = DeliveryProblemReportedPayload & {
  stopState: "exception";
  deliveryState: "exception";
};

export type ReportDeliveryProblemResult = CommandResult<
  ReportDeliveryProblemState,
  DeliveryProblemReportedEvent
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

export const podHandoffTypes = [
  "recipient",
  "someone_else",
  "left_at_location",
] as const;

export type PodHandoffType = (typeof podHandoffTypes)[number];

export type PreparePodMediaPayload = {
  sha256: string;
  byteSize: number;
  contentType: "image/jpeg" | "image/png";
};

export type PreparedPodMedia = {
  status: "prepared";
  mediaAssetId: string;
  bucket: "pod-evidence";
  path: string;
  assetState: "staged" | "uploaded_uncommitted" | "committed";
  tusEndpoint: string;
  uploadAuthorization: "driver_session";
  deduplicated?: boolean;
};

export type CompleteStopPodPayload = {
  manifestId: string;
  manifestVersion: number;
  confirmedLineNumbers: number[];
  mediaAssetId: string;
  handoffType: PodHandoffType;
  receiverName?: string;
  receiverRelationship?: string;
  leftAtLocation?: string;
  note?: string;
  position?: ArrivalPositionEvidence;
};

export type CompleteStopPodCommand = CommandEnvelope<
  "stop.complete_pod",
  CompleteStopPodPayload
>;

export type StopDeliveryCompletedPayload = {
  podId: string;
  mediaAssetId: string;
  custodyEventId: string;
  manifestVerificationId: string;
  stopId: string;
  deliveryId: string;
  roundId: string;
  driverId: string;
  handoffType: PodHandoffType;
  deliveredAt: string;
};

export type StopDeliveryCompletedEvent = DomainEventEnvelope<
  "stop.delivery_completed",
  StopDeliveryCompletedPayload
>;

export type CompleteStopPodState = StopDeliveryCompletedPayload & {
  stopState: "completed";
  deliveryState: "delivered";
  roundState: "active" | "complete";
  roundVersion: number;
};

export type CompleteStopPodResult = CommandResult<
  CompleteStopPodState,
  StopDeliveryCompletedEvent
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
