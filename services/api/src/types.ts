import type {
  ConfirmPickupCommand,
  ConfirmPickupPayload,
  ConfirmPickupResult,
  ConfirmStopArrivalCommand,
  ConfirmStopArrivalPayload,
  ConfirmStopArrivalResult,
  CreateDeliveryCommand,
  CreateDeliveryPayload,
  CreateDeliveryResult,
  DriverSession,
  OperationsSession,
  OperationsPlanningProjection,
  PlanRoundCommand,
  PlanRoundPayload,
  PlanRoundResult,
  ReportPickupProblemCommand,
  ReportPickupProblemPayload,
  ReportPickupProblemResult,
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

export type ReportPickupProblemRequestBody = ReportPickupProblemPayload;
export type ConfirmStopArrivalRequestBody = ConfirmStopArrivalPayload;
