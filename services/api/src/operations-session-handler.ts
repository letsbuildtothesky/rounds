import type { OperationsSessionDependencies } from "./types.js";

function json(status: number, body: unknown, traceId: string): Response {
  return Response.json(body, {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "x-trace-id": traceId,
    },
  });
}

function bearerToken(request: Request): string | null {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) return null;
  const token = authorization.slice("Bearer ".length).trim();
  return token.length > 0 ? token : null;
}

export async function operationsSessionHandler(
  request: Request,
  dependencies: OperationsSessionDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const accessToken = bearerToken(request);
  if (!accessToken) {
    return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  }

  const identity = await dependencies.identity.authenticate(accessToken);
  if (!identity) {
    return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  }

  const session = await dependencies.identity.getOperationsSession(identity);
  if (!session) {
    return json(403, {
      error: {
        code: "NOT_AUTHORIZED",
        message: "No active Operations membership is linked to this account",
      },
    }, traceId);
  }
  return json(200, session, traceId);
}
