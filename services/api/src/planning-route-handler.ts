import { ContractError, validatePlanningRoutePreviewRequest, type PlanningRoutePreviewRequest } from "@rounds/contracts";
import { bearerToken, json } from "./http.js";
import type { PlanningRouteDependencies } from "./types.js";
import { RoutingProviderError } from "./routing-provider.js";

export async function planningRouteHandler(request: Request, dependencies: PlanningRouteDependencies): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return json(400, { error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor) return json(403, { error: { code: "NOT_AUTHORIZED", message: "Planning access is not permitted" } }, traceId);
  let payload: PlanningRoutePreviewRequest;
  try {
    payload = await request.json() as PlanningRoutePreviewRequest;
    validatePlanningRoutePreviewRequest(payload);
  } catch (error) {
    return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Request body is invalid" } }, traceId);
  }
  try {
    return json(200, await dependencies.routes.preview(actor, payload, dependencies.now()), traceId);
  } catch (error) {
    if (error instanceof RoutingProviderError) {
      return json(503, { error: { code: "PROVIDER_UNAVAILABLE", message: error.message } }, traceId);
    }
    return json(409, { error: { code: "INVALID_STATE", message: error instanceof Error ? error.message : "Route cannot be evaluated" } }, traceId);
  }
}
