export const operationsCommunicationsEvent = "communications.changed";

export function operationsDispatchTopic(tenantId: string): string {
  return `tenant:${tenantId}:dispatch`;
}

type BroadcastMessage = {
  event?: unknown;
  payload?: unknown;
};

export function isOperationsCommunicationsHint(
  message: BroadcastMessage,
  tenantId: string,
): boolean {
  if (message.event !== operationsCommunicationsEvent) return false;
  if (!message.payload || typeof message.payload !== "object") return false;

  const payload = message.payload as Record<string, unknown>;
  return payload.schemaVersion === 1
    && payload.event === operationsCommunicationsEvent
    && payload.tenantId === tenantId
    && payload.aggregateType === "operations_thread"
    && typeof payload.aggregateId === "string"
    && typeof payload.aggregateVersion === "number"
    && typeof payload.occurredAt === "string";
}
