import type {
  CreateDeliveryCommand,
  CreateDeliveryPayload,
  CreateDeliveryResult,
  OperationsSession,
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
}

export interface DeliveryCommandGateway {
  createDelivery(command: CreateDeliveryCommand, actor: ActorContext): Promise<CreateDeliveryResult>;
  ready(): Promise<boolean>;
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
