import {
  ContractError,
  validateSendDriverMessageCommand,
  type SendDriverMessagePayload,
} from "@rounds/contracts";
import type { DriverCommunicationsDependencies } from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

export async function sendDriverMessageHandler(
  request: Request,
  roundId: string,
  stopId: string,
  dependencies: DriverCommunicationsDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, {
    error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" },
  }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  const stop = session?.currentRound?.id === roundId
    ? session.currentRound.stops.find((candidate) => candidate.id === stopId)
    : undefined;
  if (!session?.currentRound || !stop) return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "Stop is not assigned to this Team driver" },
  }, traceId);
  let payload: SendDriverMessagePayload;
  try {
    payload = await request.json() as SendDriverMessagePayload;
  } catch {
    return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId);
  }
  const thread = await dependencies.communications.getDriverOperationsThread(roundId, stopId, identity);
  if (!thread) return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "Operations thread is unavailable for this assignment" },
  }, traceId);
  const command = {
    schemaVersion: 1 as const,
    commandType: "thread.send_message" as const,
    commandId: dependencies.uuid(),
    traceId,
    idempotencyKey,
    tenantId: session.currentRound.tenant.id,
    aggregateId: thread.id,
    expectedVersion: thread.version,
    occurredFromDeviceAt: dependencies.now().toISOString(),
    payload: {
      body: typeof payload.body === "string" ? payload.body.trim() : "",
      attachments: Array.isArray(payload.attachments) ? payload.attachments : [],
    },
  };
  try {
    validateSendDriverMessageCommand(command);
  } catch (error) {
    return json(422, { error: {
      code: "VALIDATION_FAILED",
      message: error instanceof ContractError ? error.message : "Message command is invalid",
    } }, traceId);
  }
  const result = await dependencies.communications.sendDriverMessage(command, identity);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
