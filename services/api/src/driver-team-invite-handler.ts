import type { DriverTeamInviteDependencies } from "./types.js";
import { bearerToken, json } from "./http.js";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function authenticatedIdentity(
  request: Request,
  dependencies: DriverTeamInviteDependencies,
  traceId: string,
) {
  const token = bearerToken(request);
  if (!token) return { response: json(401, {
    error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" },
  }, traceId) };
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return { response: json(401, {
    error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" },
  }, traceId) };
  return { identity };
}

export async function pendingDriverTeamInviteHandler(
  request: Request,
  dependencies: DriverTeamInviteDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const auth = await authenticatedIdentity(request, dependencies, traceId);
  if (auth.response) return auth.response;
  const invite = await dependencies.invites.pendingTeamInvite(auth.identity!);
  return invite ? json(200, invite, traceId) : new Response(null, {
    status: 204,
    headers: { "x-trace-id": traceId },
  });
}

export async function resolveDriverTeamInviteHandler(
  request: Request,
  dependencies: DriverTeamInviteDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const auth = await authenticatedIdentity(request, dependencies, traceId);
  if (auth.response) return auth.response;
  let body: { code?: unknown };
  try {
    body = await request.json() as { code?: unknown };
  } catch {
    return json(400, { error: {
      code: "VALIDATION_FAILED", message: "Request body must be JSON",
    } }, traceId);
  }
  const code = typeof body.code === "string" ? body.code.trim() : "";
  if (!/^\d{6}$/.test(code)) return json(422, { error: {
    code: "VALIDATION_FAILED", message: "Invite code must contain six digits",
  } }, traceId);
  const invite = await dependencies.invites.resolveTeamInvite(code, auth.identity!);
  if (!invite) return json(404, { error: {
    code: "INVITE_NOT_FOUND", message: "Invite is invalid, expired or belongs to another phone number",
  } }, traceId);
  return json(200, invite, traceId);
}

export async function acceptDriverTeamInviteHandler(
  request: Request,
  dependencies: DriverTeamInviteDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const auth = await authenticatedIdentity(request, dependencies, traceId);
  if (auth.response) return auth.response;
  let body: { inviteId?: unknown; code?: unknown; preferredLocale?: unknown };
  try {
    body = await request.json() as typeof body;
  } catch {
    return json(400, { error: {
      code: "VALIDATION_FAILED", message: "Request body must be JSON",
    } }, traceId);
  }
  const inviteId = typeof body.inviteId === "string" ? body.inviteId.trim() : "";
  const code = typeof body.code === "string" ? body.code.trim() : undefined;
  const preferredLocale = body.preferredLocale;
  if (!uuidPattern.test(inviteId) ||
      (code !== undefined && !/^\d{6}$/.test(code)) ||
      (preferredLocale !== "en" && preferredLocale !== "th-TH")) {
    return json(422, { error: {
      code: "VALIDATION_FAILED", message: "Invite acceptance is invalid",
    } }, traceId);
  }
  const accepted = await dependencies.invites.acceptTeamInvite(
    inviteId, code, preferredLocale, auth.identity!,
  );
  if (!accepted) return json(409, { error: {
    code: "INVITE_UNAVAILABLE", message: "Invite is invalid, expired or already used",
  } }, traceId);
  const session = await dependencies.identity.getDriverSession(auth.identity!);
  if (!session) return json(500, { error: {
    code: "SESSION_UNAVAILABLE", message: "Team access was created but the Driver session is unavailable",
  } }, traceId);
  return json(201, { session }, traceId);
}
