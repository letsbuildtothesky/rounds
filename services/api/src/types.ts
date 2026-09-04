import type {
  ConfirmDeliveryReturnCommand,
  ConfirmDeliveryReturnResult,
  ClearDriverShiftExceptionCommand,
  ClearDriverShiftExceptionPayload,
  ClearDriverShiftExceptionResult,
  ConfirmPickupCommand,
  ConfirmPickupPayload,
  ConfirmPickupResult,
  ConfirmStopArrivalCommand,
  ConfirmStopArrivalPayload,
  ConfirmStopArrivalResult,
  CompleteStopPodCommand,
  CompleteStopPodPayload,
  CompleteStopPodResult,
  CreateDeliveryCommand,
  CreateDeliveryPayload,
  CreateDeliveryResult,
  DriverSession,
  DriverOperationsThread,
  LogContactAttemptCommand,
  LogContactAttemptPayload,
  LogContactAttemptResult,
  OperationsSession,
  OperationsHistoryProjection,
  OperationsActionProjection,
  OperationsDeliveriesProjection,
  OperationsDriversProjection,
  OperationsRoundDetail,
  OperationsCommunicationsProjection,
  OperationsCommunicationThread,
  OperationsPlanningProjection,
  MoveRoundStopCommand,
  MoveRoundStopRequest,
  MoveRoundStopResult,
  ApplyLiveDeliveryChangeCommand,
  ApplyLiveDeliveryChangeResult,
  AcknowledgeLiveDeliveryChangeCommand,
  AcknowledgeLiveDeliveryChangeResult,
  LiveDeliveryChangeRequest,
  PlanRoundCommand,
  PlanRoundPayload,
  PlanningRoutePreview,
  PlanningRoutePreviewRequest,
  PlanRoundResult,
  ReportPickupProblemCommand,
  ReportPickupProblemPayload,
  ReportPickupProblemResult,
  ReportDeliveryProblemCommand,
  ReportDeliveryProblemPayload,
  ReportDeliveryProblemResult,
  ReportLocationProblemCommand,
  ReportLocationProblemPayload,
  ReportLocationProblemResult,
  ReportDriverEmergencyCommand,
  ReportDriverEmergencyPayload,
  ReportDriverEmergencyResult,
  ResolveOperationsExceptionCommand,
  ResolveOperationsExceptionResult,
  SendDriverMessageCommand,
  SendDriverMessageResult,
  SendOperationsMessageCommand,
  SendOperationsMessageResult,
  SetDriverRecurringScheduleCommand,
  SetDriverRecurringSchedulePayload,
  SetDriverRecurringScheduleResult,
  SetDriverShiftExceptionCommand,
  SetDriverShiftExceptionPayload,
  SetDriverShiftExceptionResult,
  StartDriverShiftCommand,
  StartDriverShiftPayload,
  StartDriverShiftResult,
  EndDriverShiftCommand,
  EndDriverShiftPayload,
  EndDriverShiftResult,
  UpdateDriverPreferredLocaleCommand,
  UpdateDriverPreferredLocaleResult,
} from "@rounds/contracts";
import type { PlanningRouteContext, PlanningRouteService } from "./planning-route-service.js";

export type { OperationsRole } from "@rounds/contracts";
import type { OperationsRole } from "@rounds/contracts";

export type AuthenticatedIdentity = {
  authUserId: string;
  email?: string;
};

export type ActorContext = {
  authUserId: string;
  personId: string;
  tenantId: string;
  role: OperationsRole;
};

export interface IdentityGateway {
  authenticate(accessToken: string): Promise<AuthenticatedIdentity | null>;
  authorizeTenant(authUserId: string, tenantId: string): Promise<ActorContext | null>;
  getOperationsSession(identity: AuthenticatedIdentity): Promise<OperationsSession | null>;
  getDriverSession(identity: AuthenticatedIdentity): Promise<DriverSession | null>;
}

export interface DeliveryCommandGateway {
  createDelivery(command: CreateDeliveryCommand, actor: ActorContext): Promise<CreateDeliveryResult>;
  ready(): Promise<boolean>;
}

export interface RoundGateway {
  getOperationsPlanning(actor: ActorContext): Promise<OperationsPlanningProjection>;
  planRound(command: PlanRoundCommand, actor: ActorContext): Promise<PlanRoundResult>;
}

export interface PlanningRouteContextGateway {
  getPlanningRouteContext(
    actor: ActorContext,
    driverId: string,
    serviceDate: string,
    stopIds: string[],
    observedAt: Date,
  ): Promise<PlanningRouteContext>;
  getAssignedPlanningRouteContext?(
    actor: ActorContext,
    allowedRoundIds: string[],
    driverId: string,
    serviceDate: string,
    stopIds: string[],
    observedAt: Date,
  ): Promise<PlanningRouteContext>;
}

export interface PickupGateway {
  confirmPickup(command: ConfirmPickupCommand, identity: AuthenticatedIdentity): Promise<ConfirmPickupResult>;
}

export interface DriverStopGateway {
  reportPickupProblem(
    command: ReportPickupProblemCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ReportPickupProblemResult>;
  reportLocationProblem(
    command: ReportLocationProblemCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ReportLocationProblemResult>;
  reportDriverEmergency(
    command: ReportDriverEmergencyCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ReportDriverEmergencyResult>;
  confirmStopArrival(
    command: ConfirmStopArrivalCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ConfirmStopArrivalResult>;
}

export interface DriverCommunicationsGateway {
  getDriverOperationsThread(
    roundId: string,
    stopId: string,
    identity: AuthenticatedIdentity,
  ): Promise<DriverOperationsThread | null>;
  sendDriverMessage(
    command: SendDriverMessageCommand,
    identity: AuthenticatedIdentity,
  ): Promise<SendDriverMessageResult>;
  logContactAttempt(
    command: LogContactAttemptCommand,
    identity: AuthenticatedIdentity,
  ): Promise<LogContactAttemptResult>;
}

export interface DriverShiftGateway {
  startDriverShift(
    command: StartDriverShiftCommand,
    identity: AuthenticatedIdentity,
  ): Promise<StartDriverShiftResult>;
  endDriverShift(
    command: EndDriverShiftCommand,
    identity: AuthenticatedIdentity,
  ): Promise<EndDriverShiftResult>;
}

export interface DriverProfileGateway {
  updateDriverPreferredLocale(
    command: UpdateDriverPreferredLocaleCommand,
    identity: AuthenticatedIdentity,
  ): Promise<UpdateDriverPreferredLocaleResult>;
}

export interface OperationsCommunicationsGateway {
  getOperationsCommunications(actor: ActorContext): Promise<OperationsCommunicationsProjection>;
  getOperationsCommunicationThread(threadId: string, actor: ActorContext): Promise<OperationsCommunicationThread | null>;
  sendOperationsMessage(
    command: SendOperationsMessageCommand,
    actor: ActorContext,
  ): Promise<SendOperationsMessageResult>;
}

export interface PodGateway {
  preparePodMedia(
    stopId: string,
    identity: AuthenticatedIdentity,
    assetId: string,
    sha256: string,
    byteSize: number,
    contentType: string,
  ): Promise<Record<string, unknown>>;
  verifyPodMedia(assetId: string, identity: AuthenticatedIdentity): Promise<Record<string, unknown>>;
  prepareExceptionMedia(
    stopId: string,
    identity: AuthenticatedIdentity,
    assetId: string,
    sha256: string,
    byteSize: number,
    contentType: string,
  ): Promise<Record<string, unknown>>;
  reportDeliveryProblem(
    command: ReportDeliveryProblemCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ReportDeliveryProblemResult>;
  completeStopPod(
    command: CompleteStopPodCommand,
    identity: AuthenticatedIdentity,
  ): Promise<CompleteStopPodResult>;
}

export interface OperationsHistoryGateway {
  getOperationsHistory(actor: ActorContext): Promise<OperationsHistoryProjection>;
}

export interface OperationsActionGateway {
  getOperationsAction(actor: ActorContext, observedAt: Date): Promise<OperationsActionProjection>;
  resolveOperationsException(command: ResolveOperationsExceptionCommand, actor: ActorContext): Promise<ResolveOperationsExceptionResult>;
  confirmDeliveryReturn(command: ConfirmDeliveryReturnCommand, actor: ActorContext): Promise<ConfirmDeliveryReturnResult>;
}

export interface OperationsDeliveriesGateway {
  getOperationsDeliveries(actor: ActorContext, observedAt: Date): Promise<OperationsDeliveriesProjection>;
}

export interface OperationsDriversGateway {
  getOperationsDrivers(actor: ActorContext, serviceDate: string, observedAt: Date): Promise<OperationsDriversProjection>;
  setDriverRecurringSchedule(
    command: SetDriverRecurringScheduleCommand,
    actor: ActorContext,
  ): Promise<SetDriverRecurringScheduleResult>;
  setDriverShiftException(
    command: SetDriverShiftExceptionCommand,
    actor: ActorContext,
  ): Promise<SetDriverShiftExceptionResult>;
  clearDriverShiftException(
    command: ClearDriverShiftExceptionCommand,
    actor: ActorContext,
  ): Promise<ClearDriverShiftExceptionResult>;
}

export interface OperationsRoundDetailGateway {
  getOperationsRoundDetail(roundId: string, actor: ActorContext, observedAt: Date): Promise<OperationsRoundDetail | null>;
}

export interface RoundMoveGateway {
  moveRoundStop(command: MoveRoundStopCommand, actor: ActorContext): Promise<MoveRoundStopResult>;
}

export interface LiveDeliveryChangeGateway {
  applyLiveDeliveryChange(command: ApplyLiveDeliveryChangeCommand, actor: ActorContext): Promise<ApplyLiveDeliveryChangeResult>;
  acknowledgeLiveDeliveryChange(command: AcknowledgeLiveDeliveryChangeCommand, identity: AuthenticatedIdentity): Promise<AcknowledgeLiveDeliveryChangeResult>;
}

export type CreateDeliveryDependencies = {
  identity: IdentityGateway;
  commands: DeliveryCommandGateway;
  uuid: () => string;
  now: () => Date;
};

export type CreateDeliveryRequestBody = CreateDeliveryPayload;
export type LogContactAttemptRequestBody = LogContactAttemptPayload;

export type OperationsSessionDependencies = {
  identity: IdentityGateway;
  uuid: () => string;
};

export type OperationsPlanningDependencies = {
  identity: IdentityGateway;
  planning: RoundGateway;
  uuid: () => string;
};

export type OperationsHistoryDependencies = {
  identity: IdentityGateway;
  history: OperationsHistoryGateway;
  uuid: () => string;
};

export type OperationsActionDependencies = {
  identity: IdentityGateway;
  action: OperationsActionGateway;
  uuid: () => string;
  now: () => Date;
};

export type ResolveOperationsExceptionDependencies = OperationsActionDependencies;
export type ConfirmDeliveryReturnDependencies = OperationsActionDependencies;

export type OperationsDeliveriesDependencies = {
  identity: IdentityGateway;
  deliveries: OperationsDeliveriesGateway;
  uuid: () => string;
  now: () => Date;
};

export type OperationsDriversDependencies = {
  identity: IdentityGateway;
  drivers: OperationsDriversGateway;
  uuid: () => string;
  now: () => Date;
};

export type SetDriverRecurringScheduleDependencies = OperationsDriversDependencies;
export type SetDriverRecurringScheduleRequestBody = SetDriverRecurringSchedulePayload;
export type SetDriverShiftExceptionDependencies = OperationsDriversDependencies;
export type SetDriverShiftExceptionRequestBody = SetDriverShiftExceptionPayload;
export type ClearDriverShiftExceptionDependencies = OperationsDriversDependencies;
export type ClearDriverShiftExceptionRequestBody = ClearDriverShiftExceptionPayload;

export type OperationsRoundDetailDependencies = {
  identity: IdentityGateway;
  rounds: OperationsRoundDetailGateway;
  uuid: () => string;
  now: () => Date;
};

export type OperationsCommunicationsDependencies = {
  identity: IdentityGateway;
  communications: OperationsCommunicationsGateway;
  uuid: () => string;
  now: () => Date;
};

export type PlanRoundDependencies = OperationsPlanningDependencies & {
  routes: PlanningRouteService;
  now: () => Date;
};

export type PlanRoundRequestBody = Omit<PlanRoundPayload, "routePlan" | "departureAt"> & {
  departureAt?: string;
};

export type PlanningRouteDependencies = {
  identity: IdentityGateway;
  routes: PlanningRouteService;
  uuid: () => string;
  now: () => Date;
};

export type PlanningRouteResponse = PlanningRoutePreview;
export type PlanningRouteRequestBody = PlanningRoutePreviewRequest;

export type RoundMoveDependencies = {
  identity: IdentityGateway;
  rounds: OperationsRoundDetailGateway & RoundMoveGateway;
  routes: PlanningRouteService;
  uuid: () => string;
  now: () => Date;
};

export type MoveRoundStopRequestBody = MoveRoundStopRequest;

export type LiveDeliveryChangeDependencies = {
  identity: IdentityGateway;
  changes: OperationsRoundDetailGateway & LiveDeliveryChangeGateway;
  routes: PlanningRouteService;
  uuid: () => string;
  now: () => Date;
};

export type LiveDeliveryChangeRequestBody = LiveDeliveryChangeRequest;

export type DriverLiveDeliveryChangeDependencies = {
  identity: IdentityGateway;
  changes: LiveDeliveryChangeGateway;
  uuid: () => string;
  now: () => Date;
};

export type DriverSessionDependencies = {
  identity: IdentityGateway;
  uuid: () => string;
};

export type DriverPreferredLocaleDependencies = DriverSessionDependencies & {
  profiles: DriverProfileGateway;
  now: () => Date;
};

export type UpdateDriverPreferredLocaleRequestBody = {
  expectedVersion: number;
  preferredLocale: "th-TH" | "en";
};

export type DriverShiftDependencies = DriverSessionDependencies & {
  shifts: DriverShiftGateway;
  now: () => Date;
};

export type StartDriverShiftRequestBody = StartDriverShiftPayload;
export type EndDriverShiftRequestBody = EndDriverShiftPayload;

export type ConfirmPickupDependencies = DriverSessionDependencies & {
  pickup: PickupGateway;
  now: () => Date;
};

export type ConfirmPickupRequestBody = ConfirmPickupPayload;

export type DriverStopDependencies = DriverSessionDependencies & {
  stops: DriverStopGateway;
  now: () => Date;
};

export type DriverCommunicationsDependencies = DriverSessionDependencies & {
  communications: DriverCommunicationsGateway;
  now: () => Date;
};

export type PodDependencies = DriverSessionDependencies & {
  stops: PodGateway;
  now: () => Date;
};

export type ReportPickupProblemRequestBody = ReportPickupProblemPayload;
export type ReportLocationProblemRequestBody = ReportLocationProblemPayload;
export type ReportDriverEmergencyRequestBody = ReportDriverEmergencyPayload;
export type ConfirmStopArrivalRequestBody = ConfirmStopArrivalPayload;
export type CompleteStopPodRequestBody = CompleteStopPodPayload;
export type ReportDeliveryProblemRequestBody = ReportDeliveryProblemPayload;
