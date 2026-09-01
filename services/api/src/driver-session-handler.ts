import type { DriverSessionDependencies } from "./types.js";
import { bearerToken, json } from "./http.js";

export async function driverSessionHandler(
  request: Request,
  dependencies: DriverSessionDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  if (!session) return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "No active Team-driver relationship is linked to this account" },
  }, traceId);
  return json(200, session, traceId);
}
