import type {
  ContactAttempt,
  DriverThreadMessage,
  OperationsCommunicationThread,
  ThreadMessageAttachment,
} from "@rounds/contracts";

export const operationsContactHistoryFilters = ["all", "messages", "calls", "media"] as const;
export type OperationsContactHistoryFilter = (typeof operationsContactHistoryFilters)[number];
export type OperationsContactHistoryGroup = Exclude<OperationsContactHistoryFilter, "all"> | "system";

export type OperationsContactHistoryEvent = {
  id: string;
  occurredAt: string;
  actor: string;
  actorRole: "driver" | "operations" | "system";
  group: OperationsContactHistoryGroup;
  type: string;
  title: string;
  detail: string;
  status: string;
};

export type OperationsContactHistory = {
  events: OperationsContactHistoryEvent[];
  counts: { messages: number; calls: number; media: number };
};

const systemCallPattern = /^(Recipient|Operations) call · (Reached|No answer|Busy|Call failed)$/i;

function outcomeLabel(outcome: ContactAttempt["outcome"]): string {
  return ({ reached: "Reached", no_answer: "No answer", busy: "Busy / declined", call_failed: "Call failed" })[outcome];
}

function attachmentEvent(
  message: DriverThreadMessage,
  attachment: ThreadMessageAttachment,
  index: number,
  actor: string,
  actorRole: "driver" | "operations",
): OperationsContactHistoryEvent {
  if (attachment.kind === "location") return {
    id: `attachment:${message.id}:${index}`,
    occurredAt: message.sentAt,
    actor,
    actorRole,
    group: "media",
    type: "Location",
    title: attachment.label,
    detail: `${attachment.latitude.toFixed(6)}, ${attachment.longitude.toFixed(6)}`,
    status: "Stored",
  };
  if (attachment.kind === "voice") return {
    id: `attachment:${message.id}:${index}`,
    occurredAt: message.sentAt,
    actor,
    actorRole,
    group: "messages",
    type: "Voice note",
    title: actor,
    detail: attachment.fileName,
    status: "Sent",
  };
  return {
    id: `attachment:${message.id}:${index}`,
    occurredAt: message.sentAt,
    actor,
    actorRole,
    group: "media",
    type: attachment.kind === "image" ? "Photo" : "File",
    title: attachment.fileName,
    detail: attachment.contentType,
    status: "Stored",
  };
}

function attemptEvent(attempt: ContactAttempt, driverName: string): OperationsContactHistoryEvent {
  const target = attempt.target === "recipient" ? "Recipient" : "Operations";
  return {
    id: `call:${attempt.id}`,
    occurredAt: attempt.occurredAt,
    actor: driverName,
    actorRole: "driver",
    group: "calls",
    type: "Native call",
    title: `${target} call`,
    detail: `Outcome recorded by ${driverName}`,
    status: outcomeLabel(attempt.outcome),
  };
}

function callSignature(target: string, outcome: string): string {
  return `${target.toLowerCase()}:${outcome.toLowerCase().replaceAll(" / declined", "").replaceAll(" ", "_")}`;
}

export function composeOperationsContactHistory(thread: OperationsCommunicationThread): OperationsContactHistory {
  const events: OperationsContactHistoryEvent[] = [];
  const typedCalls = new Set(thread.contactAttempts.map((attempt) => callSignature(attempt.target, outcomeLabel(attempt.outcome))));

  for (const message of thread.messages) {
    const parsedCall = systemCallPattern.exec(message.body.trim());
    if (message.sender === "system") {
      if (parsedCall && typedCalls.has(callSignature(parsedCall[1]!, parsedCall[2]!))) continue;
      events.push({
        id: `system:${message.id}`,
        occurredAt: message.sentAt,
        actor: "System",
        actorRole: "system",
        group: "system",
        type: "System",
        title: message.body || "Rounds update",
        detail: "Operational record",
        status: "Logged",
      });
      continue;
    }

    const actorRole = message.sender;
    const actor = message.sender === "driver" ? thread.driverName : "Operations";
    if (message.body.trim()) events.push({
      id: `message:${message.id}`,
      occurredAt: message.sentAt,
      actor,
      actorRole,
      group: "messages",
      type: "Message",
      title: actor,
      detail: message.body.trim(),
      status: "Sent",
    });
    for (const [index, attachment] of (message.attachments ?? []).entries()) {
      events.push(attachmentEvent(message, attachment, index, actor, actorRole));
    }
  }

  events.push(...thread.contactAttempts.map((attempt) => attemptEvent(attempt, thread.driverName)));
  events.sort((left, right) => right.occurredAt.localeCompare(left.occurredAt) || right.id.localeCompare(left.id));
  return {
    events,
    counts: {
      messages: events.filter((event) => event.group === "messages").length,
      calls: events.filter((event) => event.group === "calls").length,
      media: events.filter((event) => event.group === "media").length,
    },
  };
}

export function filterOperationsContactHistory(
  events: OperationsContactHistoryEvent[],
  filter: OperationsContactHistoryFilter,
): OperationsContactHistoryEvent[] {
  return filter === "all" ? events : events.filter((event) => event.group === filter);
}
