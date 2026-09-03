import {
  ContractError,
  validateSetDriverShiftExceptionCommand,
  validateClearDriverShiftExceptionCommand,
  type ClearDriverShiftExceptionCommand,
  type SetDriverShiftExceptionCommand,
} from "@rounds/contracts";
import type {
  SetDriverShiftExceptionDependencies,
  SetDriverShiftExceptionRequestBody,
  ClearDriverShiftExceptionDependencies,
  ClearDriverShiftExceptionRequestBody,
} from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

export async function setDriverShiftExceptionHandler(
  request: Request,
  driverId: string,
  dependencies: SetDriverShiftExceptionDependencies,
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
    return json(403, { error: { code: "NOT_AUTHORIZED", message: "Driver shift exception configuration is not permitted" } }, traceId);
  }
  let body: SetDriverShiftExceptionRequestBody;
  try { body = await request.json() as SetDriverShiftExceptionRequestBody; }
  catch { return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId); }
  const expectedVersion = Number(request.headers.get("if-match-version") ?? "0");
  const command: SetDriverShiftExceptionCommand = {
    schemaVersion: 1,
    commandType: "operations.set_driver_shift_exception",
    commandId: dependencies.uuid(),
    traceId,
    idempotencyKey,
    tenantId,
    aggregateId: driverId,
    expectedVersion,
    payload: body,
  };
  try {
    validateSetDriverShiftExceptionCommand(command);
  } catch (error) {
    return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Driver shift exception is invalid" } }, traceId);
  }
  const result = await dependencies.drivers.setDriverShiftException(command, actor);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(result.deduplicated ? 200 : 201, result, traceId);
}

export async function clearDriverShiftExceptionHandler(request: Request, driverId: string, dependencies: ClearDriverShiftExceptionDependencies): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  if (!tenantId || !idempotencyKey) {
    return json(400, { error: { code: "VALIDATION_FAILED", message: "Tenant and idempotency headers are required" } }, traceId);
  }
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor || actor.role === "viewer") {
    return json(403, { error: { code: "NOT_AUTHORIZED", message: "Driver shift exception configuration is not permitted" } }, traceId);
  }
  let body: ClearDriverShiftExceptionRequestBody;
  try {
    body = await request.json() as ClearDriverShiftExceptionRequestBody;
  } catch {
    return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId);
  }
  const command: ClearDriverShiftExceptionCommand = {
    schemaVersion: 1,
    commandType: "operations.clear_driver_shift_exception",
    commandId: dependencies.uuid(),
    traceId,
    idempotencyKey,
    tenantId,
    aggregateId: driverId,
    expectedVersion: Number(request.headers.get("if-match-version") ?? "0"),
    payload: body,
  };
  try {
    validateClearDriverShiftExceptionCommand(command);
  } catch (error) {
    return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Clear exception is invalid" } }, traceId);
  }
  const result = await dependencies.drivers.clearDriverShiftException(command, actor);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
