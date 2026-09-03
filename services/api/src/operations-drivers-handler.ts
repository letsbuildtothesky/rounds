import type { OperationsDriversDependencies } from "./types.js";
import { bearerToken, json } from "./http.js";

function validServiceDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

export async function operationsDriversHandler(
  request: Request,
  dependencies: OperationsDriversDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return json(400, { error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" } }, traceId);
  const serviceDate = new URL(request.url).searchParams.get("serviceDate")?.trim() ?? "";
  if (!validServiceDate(serviceDate)) {
    return json(400, { error: { code: "VALIDATION_FAILED", message: "serviceDate must be a real YYYY-MM-DD date" } }, traceId);
  }
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor) return json(403, { error: { code: "NOT_AUTHORIZED", message: "Driver capacity access is not permitted" } }, traceId);
  return json(200, await dependencies.drivers.getOperationsDrivers(actor, serviceDate, dependencies.now()), traceId);
}

