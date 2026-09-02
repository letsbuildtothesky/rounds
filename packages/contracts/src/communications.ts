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
