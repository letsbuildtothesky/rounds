export const commandErrorCodes = [
  "STALE_VERSION",
  "NOT_AUTHORIZED",
  "INVALID_STATE",
  "VALIDATION_FAILED",
  "IDEMPOTENCY_CONFLICT",
  "CUSTODY_LOCKED",
  "EVIDENCE_REQUIRED",
  "PROVIDER_UNAVAILABLE",
] as const;

export type CommandErrorCode = (typeof commandErrorCodes)[number];

export type CommandEnvelope<TType extends string, TPayload> = {
  schemaVersion: 1;
  commandType: TType;
  commandId: string;
  traceId: string;
  idempotencyKey: string;
  tenantId: string;
  aggregateId: string;
  expectedVersion: number;
  occurredFromDeviceAt?: string;
  payload: TPayload;
};

export type DomainEventEnvelope<TEvent extends string, TPayload> = {
  event: TEvent;
  version: 1;
  eventId: string;
  traceId: string;
  tenantId: string;
  aggregateType: string;
  aggregateId: string;
  aggregateVersion: number;
  occurredAt: string;
  payload: TPayload;
};

export type CommandCommitted<TState, TEvent = unknown> = {
  status: "committed";
  aggregateVersion: number;
  state: TState;
  events: TEvent[];
  deduplicated?: boolean;
};

export type CommandRejected = {
  status: "rejected";
  error: {
    code: CommandErrorCode;
    message: string;
  };
};

export type CommandResult<TState, TEvent = unknown> =
  | CommandCommitted<TState, TEvent>
  | CommandRejected;
