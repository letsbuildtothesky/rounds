import {
  ContractError,
  validateEndDriverShiftCommand,
  type EndDriverShiftPayload,
} from "@rounds/contracts";
import type { DriverShiftDependencies } from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

export async function endDriverShiftHandler(
  request: Request,
  dependencies: DriverShiftDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, {
    error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" },
  }, traceId);
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, {
    error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" },
  }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, {
    error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" },
  }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  const attendance = session?.shift?.attendance;
  if (!session?.team || !attendance || attendance.endedAt) return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "No open Team shift is available" },
  }, traceId);

  let payload: EndDriverShiftPayload;
  try {
    payload = await request.json() as EndDriverShiftPayload;
  } catch {
    return json(400, {
      error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" },
    }, traceId);
  }
  const command = {
    schemaVersion: 1 as const,
    commandType: "driver.end_shift" as const,
    commandId: dependencies.uuid(),
    traceId,
    idempotencyKey,
    tenantId: session.team.tenantId,
    aggregateId: attendance.id,
    expectedVersion: attendance.version,
    occurredFromDeviceAt: dependencies.now().toISOString(),
    payload,
  };
  try {
    validateEndDriverShiftCommand(command);
  } catch (error) {
    return json(422, { error: {
      code: "VALIDATION_FAILED",
      message: error instanceof ContractError ? error.message : "Shift end command is invalid",
    } }, traceId);
  }
  const result = await dependencies.shifts.endDriverShift(command, identity);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
