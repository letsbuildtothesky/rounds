import type {
  DriverCommunicationsDependencies,
  OperationsCommunicationsDependencies,
} from "./types.js";
import { bearerToken, json } from "./http.js";

type ReadBody = { lastReadMessageId?: unknown };

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function lastReadMessageId(request: Request): Promise<string | null> {
  try {
    const body = await request.json() as ReadBody;
    return typeof body.lastReadMessageId === "string" && uuidPattern.test(body.lastReadMessageId)
      ? body.lastReadMessageId
      : null;
  } catch {
    return null;
  }
}

export async function markOperationsCommunicationThreadReadHandler(
  request: Request,
  threadId: string,
  dependencies: OperationsCommunicationsDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return json(400, {
    error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" },
  }, traceId);
  const messageId = await lastReadMessageId(request);
  if (!messageId) return json(422, {
    error: { code: "VALIDATION_FAILED", message: "lastReadMessageId must be a UUID" },
  }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor) return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "Communications access is not permitted" },
  }, traceId);
  const state = await dependencies.communications.markOperationsCommunicationThreadRead(threadId, messageId, actor);
  if (!state) return json(404, {
    error: { code: "NOT_AUTHORIZED", message: "Operations thread is unavailable for this tenant" },
  }, traceId);
  return json(200, state, traceId);
}

export async function markDriverCommunicationThreadReadHandler(
  request: Request,
  roundId: string,
  stopId: string,
  dependencies: DriverCommunicationsDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const messageId = await lastReadMessageId(request);
  if (!messageId) return json(422, {
    error: { code: "VALIDATION_FAILED", message: "lastReadMessageId must be a UUID" },
  }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  const stop = session?.currentRound?.id === roundId
    ? session.currentRound.stops.find((candidate) => candidate.id === stopId)
    : undefined;
  if (!session?.currentRound || !stop) return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "Stop is not assigned to this Team driver" },
  }, traceId);
  const state = await dependencies.communications.markDriverOperationsThreadRead(roundId, stopId, messageId, identity);
  if (!state) return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "Operations thread is unavailable for this assignment" },
  }, traceId);
  return json(200, state, traceId);
}
