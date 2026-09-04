import {
  ContractError,
  validateReportDeliveryProblemCommand,
  type ReportDeliveryProblemPayload,
} from "@rounds/contracts";
import type { PodDependencies } from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

export async function reportDeliveryProblemHandler(
  request: Request,
  stopId: string,
  dependencies: PodDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, { error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  const stop = session?.currentRound?.stops.find((candidate) => candidate.id === stopId);
  if (!session?.currentRound || !stop) return json(403, { error: { code: "NOT_AUTHORIZED", message: "Stop is not assigned to this Team driver" } }, traceId);
  let payload: ReportDeliveryProblemPayload;
  try {
    payload = await request.json() as ReportDeliveryProblemPayload;
  } catch {
    return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId);
  }
  const command = {
    schemaVersion: 1 as const,
    commandType: "stop.report_delivery_problem" as const,
    commandId: dependencies.uuid(),
    traceId,
    idempotencyKey,
    tenantId: session.currentRound.tenant.id,
    aggregateId: stopId,
    expectedVersion: stop.version,
    occurredFromDeviceAt: dependencies.now().toISOString(),
    payload,
  };
  try {
    validateReportDeliveryProblemCommand(command);
  } catch (error) {
    return json(422, { error: {
      code: "VALIDATION_FAILED",
      message: error instanceof ContractError ? error.message : "Delivery problem command is invalid",
    } }, traceId);
  }
  if (payload.mediaAssetId) {
    const verification = await dependencies.stops.verifyPodMedia(payload.mediaAssetId, identity);
    if (verification.status === "rejected") {
      const error = verification.error as { code: Parameters<typeof statusForCommandError>[0]; message: string };
      return json(statusForCommandError(error.code), verification, traceId);
    }
  }
  const result = await dependencies.stops.reportDeliveryProblem(command, identity);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
