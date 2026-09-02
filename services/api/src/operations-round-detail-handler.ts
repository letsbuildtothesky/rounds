import type { OperationsRoundDetailDependencies } from "./types.js";
import { bearerToken, json } from "./http.js";

export async function operationsRoundDetailHandler(
  request: Request,
  roundId: string,
  dependencies: OperationsRoundDetailDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return json(400, { error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor) return json(403, { error: { code: "NOT_AUTHORIZED", message: "Round access is not permitted" } }, traceId);
  const detail = await dependencies.rounds.getOperationsRoundDetail(roundId, actor, dependencies.now());
  if (!detail) return json(404, { error: { code: "NOT_FOUND", message: "Round was not found" } }, traceId);
  return json(200, detail, traceId);
}
