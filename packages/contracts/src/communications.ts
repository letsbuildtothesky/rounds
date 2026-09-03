import type { CommandEnvelope, CommandResult, DomainEventEnvelope } from "./command.js";

export type DriverMessageSender = "driver" | "operations" | "system";

export type DriverThreadMessage = {
  id: string;
  sender: DriverMessageSender;
  body: string;
  sentAt: string;
};

export type DriverOperationsThread = {
  id: string;
  roundId: string;
  stopId: string;
  version: number;
  messages: DriverThreadMessage[];
};

export type SendDriverMessagePayload = {
  body: string;
};

export type SendDriverMessageCommand = CommandEnvelope<
  "thread.send_message",
  SendDriverMessagePayload
>;

export type DriverMessageSentPayload = {
  threadId: string;
  message: DriverThreadMessage;
};

export type DriverMessageSentEvent = DomainEventEnvelope<
  "thread.message_sent",
  DriverMessageSentPayload
>;

export type SendDriverMessageResult = CommandResult<
  DriverMessageSentPayload,
  DriverMessageSentEvent
>;

export type OperationsCommunicationThread = DriverOperationsThread & {
  priority: "normal" | "emergency";
  roundReference: string;
  stopSequence: number;
  deliveryId: string;
  deliveryReference: string;
  recipientName: string;
  rawAddress: string;
  driverId: string;
  driverName: string;
  updatedAt: string;
};

export type OperationsCommunicationsProjection = {
  tenantId: string;
  threads: OperationsCommunicationThread[];
};

export type SendOperationsMessagePayload = {
  body: string;
};

export type SendOperationsMessageCommand = CommandEnvelope<
  "thread.send_operations_message",
  SendOperationsMessagePayload
>;

export type SendOperationsMessageResult = CommandResult<
  DriverMessageSentPayload,
  DriverMessageSentEvent
>;

export const contactTargets = ["recipient", "operations"] as const;
export type ContactTarget = (typeof contactTargets)[number];

export const contactOutcomes = ["reached", "no_answer", "busy", "call_failed"] as const;
export type ContactOutcome = (typeof contactOutcomes)[number];

export type ContactAttempt = {
  id: string;
  target: ContactTarget;
  channel: "native_phone";
  outcome: ContactOutcome;
  occurredAt: string;
};

export type LogContactAttemptPayload = {
  target: ContactTarget;
  channel: "native_phone";
  outcome: ContactOutcome;
};

export type LogContactAttemptCommand = CommandEnvelope<
  "stop.log_contact_attempt",
  LogContactAttemptPayload
>;

export type ContactAttemptRecordedPayload = {
  stopId: string;
  deliveryId: string;
  roundId: string;
  operationsThreadId: string;
  attempt: ContactAttempt;
};

export type ContactAttemptRecordedEvent = DomainEventEnvelope<
  "stop.contact_attempt_recorded",
  ContactAttemptRecordedPayload
>;

export type LogContactAttemptResult = CommandResult<
  ContactAttemptRecordedPayload,
  ContactAttemptRecordedEvent
>;
