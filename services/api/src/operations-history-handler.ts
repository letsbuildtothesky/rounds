import type { OperationsHistoryDependencies } from "./types.js";
import { bearerToken, json } from "./http.js";

export async function operationsHistoryHandler(
  request: Request,
  dependencies: OperationsHistoryDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return json(400, { error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor) return json(403, { error: { code: "NOT_AUTHORIZED", message: "History access is not permitted" } }, traceId);
  return json(200, await dependencies.history.getOperationsHistory(actor), traceId);
}
