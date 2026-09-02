import type { DriverCommunicationsDependencies } from "./types.js";
import { bearerToken, json } from "./http.js";

export async function driverOperationsThreadHandler(
  request: Request,
  roundId: string,
  stopId: string,
  dependencies: DriverCommunicationsDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  const stop = session?.currentRound?.id === roundId
    ? session.currentRound.stops.find((candidate) => candidate.id === stopId)
    : undefined;
  if (!session?.currentRound || !stop) return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "Stop is not assigned to this Team driver" },
  }, traceId);
  const thread = await dependencies.communications.getDriverOperationsThread(roundId, stopId, identity);
  if (!thread) return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "Operations thread is unavailable for this assignment" },
  }, traceId);
  return json(200, thread, traceId);
}
