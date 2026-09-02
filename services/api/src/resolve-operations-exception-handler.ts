import { ContractError, validateResolveOperationsExceptionCommand, type ResolveOperationsExceptionPayload } from "@rounds/contracts";
import type { ResolveOperationsExceptionDependencies } from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

type RequestBody = Omit<ResolveOperationsExceptionPayload, "exceptionId"> & { stopId: string; expectedStopVersion: number };

export async function resolveOperationsExceptionHandler(request: Request, exceptionId: string, dependencies: ResolveOperationsExceptionDependencies): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return json(400, { error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" } }, traceId);
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, { error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor || actor.role === "viewer") return json(403, { error: { code: "NOT_AUTHORIZED", message: "Exception resolution is not permitted" } }, traceId);
  let body: RequestBody;
  try { body = await request.json() as RequestBody; }
  catch { return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId); }
  const command = {
    schemaVersion: 1 as const, commandType: "operations.resolve_exception" as const,
    commandId: dependencies.uuid(), traceId, idempotencyKey, tenantId,
    aggregateId: body.stopId, expectedVersion: body.expectedStopVersion,
    occurredFromDeviceAt: dependencies.now().toISOString(),
    payload: { exceptionId, resolution: body.resolution, note: body.note },
  };
  try { validateResolveOperationsExceptionCommand(command); }
  catch (error) { return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Exception resolution is invalid" } }, traceId); }
  const result = await dependencies.action.resolveOperationsException(command, actor);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
