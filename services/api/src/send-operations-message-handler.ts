import {
  ContractError,
  validateSendOperationsMessageCommand,
  type SendOperationsMessagePayload,
} from "@rounds/contracts";
import type { OperationsCommunicationsDependencies } from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

export async function sendOperationsMessageHandler(
  request: Request,
  threadId: string,
  dependencies: OperationsCommunicationsDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return json(400, {
    error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" },
  }, traceId);
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, {
    error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" },
  }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor || actor.role === "viewer") return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "Replying to drivers is not permitted" },
  }, traceId);
  let payload: SendOperationsMessagePayload;
  try {
    payload = await request.json() as SendOperationsMessagePayload;
  } catch {
    return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId);
  }
  const thread = await dependencies.communications.getOperationsCommunicationThread(threadId, actor);
  if (!thread) return json(404, {
    error: { code: "NOT_AUTHORIZED", message: "Operations thread is unavailable for this tenant" },
  }, traceId);
  const command = {
    schemaVersion: 1 as const,
    commandType: "thread.send_operations_message" as const,
    commandId: dependencies.uuid(),
    traceId,
    idempotencyKey,
    tenantId: actor.tenantId,
    aggregateId: thread.id,
    expectedVersion: thread.version,
    occurredFromDeviceAt: dependencies.now().toISOString(),
    payload: {
      body: typeof payload.body === "string" ? payload.body.trim() : "",
      attachments: Array.isArray(payload.attachments) ? payload.attachments : [],
    },
  };
  try {
    validateSendOperationsMessageCommand(command);
  } catch (error) {
    return json(422, { error: {
      code: "VALIDATION_FAILED",
      message: error instanceof ContractError ? error.message : "Message command is invalid",
    } }, traceId);
  }
  const result = await dependencies.communications.sendOperationsMessage(command, actor);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
