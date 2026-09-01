import type {
  CreateDeliveryCommand,
  CreateDeliveryPayload,
  CreateDeliveryResult,
} from "@rounds/contracts";

export type OperationsRole = "tenant_owner" | "operations_admin" | "dispatcher" | "viewer";

export type ActorContext = {
  authUserId: string;
  personId: string;
  tenantId: string;
  role: OperationsRole;
};

export interface IdentityGateway {
  authenticate(accessToken: string): Promise<{ authUserId: string } | null>;
  authorizeTenant(authUserId: string, tenantId: string): Promise<ActorContext | null>;
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
