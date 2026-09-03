import type { CommandEnvelope, CommandResult, DomainEventEnvelope } from "./command.js";
import type { ContactAttempt } from "./communications.js";
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
  departureAt?: string;
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
  destinationVersion: number;
  deliveryId: string;
  deliveryReference: string;
  deliveryState: string;
  recipientName: string;
  recipientPhone: string;
  rawAddress: string;
  accessNote?: string;
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
  latestLiveChange?: DriverLiveDeliveryChange;
};

export type OperationsRoundDetail = {
  tenantId: string;
  observedAt: string;
  id: string;
  reference: string;
  serviceDate: string;
  state: RoundState;
  version: number;
  routePlan?: PlanningRouteSnapshot;
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
  departureAt: string;
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

export type MoveRoundStopRequest = {
  sourceRoundId: string;
  targetRoundId: string;
  stopId: string;
  sourceExpectedVersion: number;
  targetExpectedVersion: number;
};

export type RoundMoveImpact = {
  roundId: string;
  reference: string;
  driverId: string;
  driverName: string;
  vehicleLabel?: string;
  stopsBefore: number;
  stopsAfter: number;
  routeBefore?: PlanningRouteSnapshot;
  routeAfter?: PlanningRoutePreview;
  removed: boolean;
};

export type MoveRoundStopPreview = {
  tenantId: string;
  calculatedAt: string;
  stopId: string;
  movable: boolean;
  blockingReasons: string[];
  source: RoundMoveImpact;
  target: RoundMoveImpact;
};

export type MoveRoundStopPayload = MoveRoundStopRequest & {
  sourceStopIds: string[];
  targetStopIds: string[];
  sourceRoutePlan?: PlanningRouteSnapshot;
  targetRoutePlan: PlanningRouteSnapshot;
};

export type MoveRoundStopCommand = CommandEnvelope<"round.move_stop", MoveRoundStopPayload>;

export type RoundStopMovedPayload = {
  stopId: string;
  sourceRoundId: string;
  targetRoundId: string;
  sourceStopIds: string[];
  targetStopIds: string[];
};

export type RoundStopMovedEvent = DomainEventEnvelope<"round.stop_moved", RoundStopMovedPayload>;

export type MoveRoundStopState = RoundStopMovedPayload & {
  sourceRoundVersion: number;
  targetRoundVersion: number;
  sourceRoundRemoved: boolean;
};

export type MoveRoundStopResult = CommandResult<MoveRoundStopState, RoundStopMovedEvent>;

export type LiveDeliveryChangeValues = {
  sequence?: number;
  rawAddress?: string;
  latitude?: number;
  longitude?: number;
  accessNote?: string;
  windowStart?: string;
  windowEnd?: string;
};

export type LiveDeliveryChangeRequest = {
  roundId: string;
  stopId: string;
  expectedRoundVersion: number;
  expectedStopVersion: number;
  expectedDestinationVersion: number;
  changes: LiveDeliveryChangeValues;
};

export type LiveDeliveryChangeImpact = {
  distanceDeltaMeters: number;
  durationDeltaSeconds: number;
  etaBefore?: string;
  etaAfter?: string;
  finishBefore?: string;
  finishAfter?: string;
  downstreamStopCount: number;
  promiseStatus: "safe" | "early" | "late";
  shiftSafe: boolean;
};

export type LiveDeliveryChangePreview = {
  tenantId: string;
  calculatedAt: string;
  roundId: string;
  stopId: string;
  applicable: boolean;
  blockingReasons: string[];
  before: Required<Pick<LiveDeliveryChangeValues, "sequence" | "rawAddress" | "latitude" | "longitude" | "windowStart" | "windowEnd">> & { accessNote?: string };
  after: Required<Pick<LiveDeliveryChangeValues, "sequence" | "rawAddress" | "latitude" | "longitude" | "windowStart" | "windowEnd">> & { accessNote?: string };
  impact?: LiveDeliveryChangeImpact;
  routeAfter?: PlanningRoutePreview;
  custody: { driverId: string; manifestId: string; manifestVersion: number; verified: true };
};

export type ApplyLiveDeliveryChangePayload = LiveDeliveryChangeRequest & {
  before: LiveDeliveryChangePreview["before"];
  after: LiveDeliveryChangePreview["after"];
  impact: LiveDeliveryChangeImpact;
  routePlan: PlanningRouteSnapshot;
  stopOrderAfter: string[];
};

export type ApplyLiveDeliveryChangeCommand = CommandEnvelope<"delivery.apply_live_change", ApplyLiveDeliveryChangePayload>;

export type LiveDeliveryChangedState = {
  changeId: string;
  changeVersion: number;
  roundId: string;
  roundVersion: number;
  stopId: string;
  stopVersion: number;
  destinationVersion: number;
  driverAckStatus: "pending";
};

export type LiveDeliveryChangedEvent = DomainEventEnvelope<"delivery.live_changed", LiveDeliveryChangedState>;
export type ApplyLiveDeliveryChangeResult = CommandResult<LiveDeliveryChangedState, LiveDeliveryChangedEvent>;

export type DriverLiveDeliveryChange = {
  id: string;
  changeVersion: number;
  roundId: string;
  stopId: string;
  appliedAt: string;
  before: LiveDeliveryChangePreview["before"];
  after: LiveDeliveryChangePreview["after"];
  impact: LiveDeliveryChangeImpact;
  driverAckStatus: "pending" | "acknowledged";
  acknowledgedAt?: string;
};

export type AcknowledgeLiveDeliveryChangePayload = {
  changeId: string;
  expectedChangeVersion: number;
};

export type AcknowledgeLiveDeliveryChangeCommand = CommandEnvelope<"driver.acknowledge_live_change", AcknowledgeLiveDeliveryChangePayload>;

export type LiveDeliveryChangeAcknowledgedState = {
  changeId: string;
  changeVersion: number;
  roundId: string;
  stopId: string;
  driverAckStatus: "acknowledged";
  acknowledgedAt: string;
};

export type LiveDeliveryChangeAcknowledgedEvent = DomainEventEnvelope<"delivery.live_change_acknowledged", LiveDeliveryChangeAcknowledgedState>;
export type AcknowledgeLiveDeliveryChangeResult = CommandResult<LiveDeliveryChangeAcknowledgedState, LiveDeliveryChangeAcknowledgedEvent>;

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

export const locationProblemStages = ["pickup", "delivery"] as const;
export type LocationProblemStage = (typeof locationProblemStages)[number];

export const locationProblemCategories = [
  "wrong_pin",
  "wrong_entrance",
  "wrong_address",
  "cannot_find_location",
] as const;
export type LocationProblemCategory = (typeof locationProblemCategories)[number];

export type ReportLocationProblemPayload = {
  manifestId: string;
  manifestVersion: number;
  stage: LocationProblemStage;
  category: LocationProblemCategory;
  detail?: string;
  position?: ArrivalPositionEvidence;
};

export type ReportLocationProblemCommand = CommandEnvelope<
  "stop.report_location_problem",
  ReportLocationProblemPayload
>;

export type LocationProblemReportedPayload = {
  exceptionId: string;
  stopId: string;
  deliveryId: string;
  roundId: string;
  stage: LocationProblemStage;
  category: LocationProblemCategory;
  hasPositionEvidence: boolean;
  operationsThreadId: string;
};

export type LocationProblemReportedEvent = DomainEventEnvelope<
  "stop.location_problem_reported",
  LocationProblemReportedPayload
>;

export type ReportLocationProblemState = LocationProblemReportedPayload & {
  stopState: "exception";
  deliveryState: "exception";
};

export type ReportLocationProblemResult = CommandResult<
  ReportLocationProblemState,
  LocationProblemReportedEvent
>;

export const driverEmergencySafetyStatuses = ["safe", "urgent"] as const;
export type DriverEmergencySafetyStatus =
  (typeof driverEmergencySafetyStatuses)[number];

export type ReportDriverEmergencyPayload = {
  manifestId: string;
  manifestVersion: number;
  safetyStatus: DriverEmergencySafetyStatus;
  position?: ArrivalPositionEvidence;
};

export type ReportDriverEmergencyCommand = CommandEnvelope<
  "stop.report_driver_emergency",
  ReportDriverEmergencyPayload
>;

export type DriverEmergencyReportedPayload = {
  emergencyEventId: string;
  exceptionId: string;
  stopId: string;
  deliveryId: string;
  roundId: string;
  safetyStatus: DriverEmergencySafetyStatus;
  hasPositionEvidence: boolean;
  operationsThreadId: string;
};

export type DriverEmergencyReportedEvent = DomainEventEnvelope<
  "stop.driver_emergency_reported",
  DriverEmergencyReportedPayload
>;

export type ReportDriverEmergencyState = DriverEmergencyReportedPayload & {
  stopState: "exception";
  deliveryState: "exception";
  emergencyHold: true;
};

export type ReportDriverEmergencyResult = CommandResult<
  ReportDriverEmergencyState,
  DriverEmergencyReportedEvent
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
  contactAttempts?: ContactAttempt[];
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
  routePlan?: PlanningRouteSnapshot;
};

export type DriverCompletedRound = {
  id: string;
  reference: string;
  serviceDate: string;
  tenant: { id: string; displayName: string; timezone: string };
  completedAt: string;
  stopCount: number;
  deliveredStopCount: number;
  formallyClosedStopCount: number;
  podCount: number;
  plannedDistanceMeters?: number;
  plannedDurationSeconds?: number;
};

export type DriverSession = {
  user: { id: string; displayName: string };
  driver: { id: string; preferredLocale: string; vehicleLabel?: string; vehiclePlate?: string };
  team?: { tenantId: string; displayName: string; status: "active" };
  currentRound?: DriverRound;
  pendingLiveChange?: DriverLiveDeliveryChange;
  completedRounds?: DriverCompletedRound[];
};
