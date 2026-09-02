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
