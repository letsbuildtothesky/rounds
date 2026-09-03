import {
  ContractError,
  validateSetDriverRecurringScheduleCommand,
  type SetDriverRecurringScheduleCommand,
} from "@rounds/contracts";
import type {
  SetDriverRecurringScheduleDependencies,
  SetDriverRecurringScheduleRequestBody,
} from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

export async function setDriverRecurringScheduleHandler(
  request: Request,
  driverId: string,
  dependencies: SetDriverRecurringScheduleDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return json(400, { error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" } }, traceId);
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, { error: { code: "VALIDATION_FAILED", message: "Idempotency-Key header is required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor || actor.role === "viewer") {
    return json(403, { error: { code: "NOT_AUTHORIZED", message: "Driver schedule configuration is not permitted" } }, traceId);
  }
  let body: SetDriverRecurringScheduleRequestBody;
  try { body = await request.json() as SetDriverRecurringScheduleRequestBody; }
  catch { return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId); }
  const expectedVersion = Number(request.headers.get("if-match-version") ?? "0");
  const command: SetDriverRecurringScheduleCommand = {
    schemaVersion: 1,
    commandType: "operations.set_driver_recurring_schedule",
    commandId: dependencies.uuid(),
    traceId,
    idempotencyKey,
    tenantId,
    aggregateId: driverId,
    expectedVersion,
    payload: body,
  };
  try {
    validateSetDriverRecurringScheduleCommand(command);
  } catch (error) {
    return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Driver schedule is invalid" } }, traceId);
  }
  const result = await dependencies.drivers.setDriverRecurringSchedule(command, actor);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
