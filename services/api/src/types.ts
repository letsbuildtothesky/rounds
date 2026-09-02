import type {
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
  OperationsSession,
  OperationsHistoryProjection,
  OperationsActionProjection,
  OperationsDeliveriesProjection,
  OperationsRoundDetail,
  OperationsCommunicationsProjection,
  OperationsCommunicationThread,
  OperationsPlanningProjection,
  PlanRoundCommand,
  PlanRoundPayload,
  PlanRoundResult,
  ReportPickupProblemCommand,
  ReportPickupProblemPayload,
  ReportPickupProblemResult,
  ResolveOperationsExceptionCommand,
  ResolveOperationsExceptionResult,
  SendDriverMessageCommand,
  SendDriverMessageResult,
  SendOperationsMessageCommand,
  SendOperationsMessageResult,
} from "@rounds/contracts";

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

export interface PickupGateway {
  confirmPickup(command: ConfirmPickupCommand, identity: AuthenticatedIdentity): Promise<ConfirmPickupResult>;
}

export interface DriverStopGateway {
  reportPickupProblem(
    command: ReportPickupProblemCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ReportPickupProblemResult>;
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
}

export interface OperationsDeliveriesGateway {
  getOperationsDeliveries(actor: ActorContext, observedAt: Date): Promise<OperationsDeliveriesProjection>;
}

export interface OperationsRoundDetailGateway {
  getOperationsRoundDetail(roundId: string, actor: ActorContext, observedAt: Date): Promise<OperationsRoundDetail | null>;
}

export type CreateDeliveryDependencies = {
  identity: IdentityGateway;
  commands: DeliveryCommandGateway;
  uuid: () => string;
  now: () => Date;
};

export type CreateDeliveryRequestBody = CreateDeliveryPayload;

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

export type OperationsDeliveriesDependencies = {
  identity: IdentityGateway;
  deliveries: OperationsDeliveriesGateway;
  uuid: () => string;
  now: () => Date;
};

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
  now: () => Date;
};

export type PlanRoundRequestBody = PlanRoundPayload;

export type DriverSessionDependencies = {
  identity: IdentityGateway;
  uuid: () => string;
};

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
export type ConfirmStopArrivalRequestBody = ConfirmStopArrivalPayload;
export type CompleteStopPodRequestBody = CompleteStopPodPayload;
