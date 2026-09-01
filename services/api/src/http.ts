import type { CommandErrorCode } from "@rounds/contracts";

export function json(status: number, body: unknown, traceId: string): Response {
  return Response.json(body, {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "x-trace-id": traceId,
    },
  });
}

export function bearerToken(request: Request): string | null {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) return null;
  const token = authorization.slice("Bearer ".length).trim();
  return token.length > 0 ? token : null;
}

export function statusForCommandError(code: CommandErrorCode): number {
  switch (code) {
    case "NOT_AUTHORIZED": return 403;
    case "STALE_VERSION":
    case "IDEMPOTENCY_CONFLICT":
    case "CUSTODY_LOCKED":
    case "INVALID_STATE": return 409;
    case "VALIDATION_FAILED":
    case "EVIDENCE_REQUIRED": return 422;
    case "PROVIDER_UNAVAILABLE": return 503;
  }
}
