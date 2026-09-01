import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { createDeliveryHandler } from "./create-delivery-handler.js";
import { driverSessionHandler } from "./driver-session-handler.js";
import { operationsPlanningHandler } from "./operations-planning-handler.js";
import { readConfig } from "./config.js";
import { operationsSessionHandler } from "./operations-session-handler.js";
import { planRoundHandler } from "./plan-round-handler.js";
import { SupabaseGateway } from "./supabase-gateway.js";

const config = readConfig();
const gateway = new SupabaseGateway(
  config.supabaseUrl,
  config.supabasePublishableKey,
  config.supabaseSecretKey,
);

function authorizedHealth(request: IncomingMessage): boolean {
  return request.headers["x-rounds-health-token"] === config.healthToken;
}

function sendNode(response: ServerResponse, webResponse: Response): void {
  response.statusCode = webResponse.status;
  webResponse.headers.forEach((value, key) => response.setHeader(key, value));
  void webResponse.arrayBuffer().then((body) => response.end(Buffer.from(body)));
}

function addOperationsCors(webResponse: Response, origin: string | undefined): Response {
  if (origin !== config.operationsWebOrigin) return webResponse;
  webResponse.headers.set("access-control-allow-origin", origin);
  webResponse.headers.set("access-control-allow-credentials", "true");
  webResponse.headers.set("vary", "origin");
  return webResponse;
}

async function toWebRequest(request: IncomingMessage): Promise<Request> {
  const chunks: Buffer[] = [];
  for await (const chunk of request) chunks.push(Buffer.from(chunk));
  const headers = new Headers();
  for (const [name, value] of Object.entries(request.headers)) {
    if (Array.isArray(value)) value.forEach((entry) => headers.append(name, entry));
    else if (value !== undefined) headers.set(name, value);
  }
  const url = new URL(request.url ?? "/", `http://${request.headers.host ?? "127.0.0.1"}`);
  const body = chunks.length > 0 ? Buffer.concat(chunks) : undefined;
  return new Request(url, {
    method: request.method ?? "GET",
    headers,
    ...(body ? { body } : {}),
  });
}

const server = createServer(async (request, response) => {
  const startedAt = performance.now();
  const traceId = request.headers["x-trace-id"] ?? crypto.randomUUID();
  try {
    if (!authorizedHealth(request) && request.url?.startsWith("/health/")) {
      response.writeHead(401).end();
      return;
    }
    if (request.method === "GET" && request.url === "/health/live") {
      sendNode(response, Response.json({ status: "live", appEnv: config.appEnv }));
      return;
    }
    if (request.method === "GET" && request.url === "/health/ready") {
      const ready = await gateway.ready();
      sendNode(response, Response.json({ status: ready ? "ready" : "not_ready" }, { status: ready ? 200 : 503 }));
      return;
    }
    if (request.method === "OPTIONS" && request.url?.startsWith("/v1/")) {
      const origin = request.headers.origin;
      if (origin !== config.operationsWebOrigin) {
        response.writeHead(403).end();
        return;
      }
      response.writeHead(204, {
        "access-control-allow-origin": origin,
        "access-control-allow-credentials": "true",
        "access-control-allow-methods": "GET, POST, OPTIONS",
        "access-control-allow-headers": "authorization, content-type, idempotency-key, x-rounds-tenant-id, x-trace-id",
        "access-control-max-age": "600",
        vary: "origin",
      }).end();
      return;
    }
    if (request.method === "GET" && request.url === "/v1/operations/session") {
      const webRequest = await toWebRequest(request);
      const sessionResponse = await operationsSessionHandler(webRequest, {
        identity: gateway,
        uuid: () => crypto.randomUUID(),
      });
      sendNode(response, addOperationsCors(sessionResponse, request.headers.origin));
      return;
    }
    if (request.method === "GET" && request.url === "/v1/operations/planning") {
      const webRequest = await toWebRequest(request);
      const planningResponse = await operationsPlanningHandler(webRequest, {
        identity: gateway,
        planning: gateway,
        uuid: () => crypto.randomUUID(),
      });
      sendNode(response, addOperationsCors(planningResponse, request.headers.origin));
      return;
    }
    if (request.method === "POST" && request.url === "/v1/rounds") {
      const webRequest = await toWebRequest(request);
      const roundResponse = await planRoundHandler(webRequest, {
        identity: gateway,
        planning: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(roundResponse, request.headers.origin));
      return;
    }
    if (request.method === "GET" && request.url === "/v1/driver/session") {
      const webRequest = await toWebRequest(request);
      const driverResponse = await driverSessionHandler(webRequest, {
        identity: gateway,
        uuid: () => crypto.randomUUID(),
      });
      sendNode(response, driverResponse);
      return;
    }
    if (request.method === "POST" && request.url === "/v1/deliveries") {
      const webRequest = await toWebRequest(request);
      const deliveryResponse = await createDeliveryHandler(webRequest, {
        identity: gateway,
        commands: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(deliveryResponse, request.headers.origin));
      return;
    }
    response.writeHead(404, { "content-type": "application/json" });
    response.end(JSON.stringify({ error: { code: "NOT_FOUND", message: "Route not found" } }));
  } catch (error) {
    console.error(JSON.stringify({
      level: "error",
      event: "api.request_failed",
      trace_id: traceId,
      method: request.method,
      path: request.url,
      message: error instanceof Error ? error.message : String(error),
    }));
    if (!response.headersSent) {
      const headers: Record<string, string> = { "content-type": "application/json" };
      if (request.headers.origin === config.operationsWebOrigin) {
        headers["access-control-allow-origin"] = request.headers.origin;
        headers["access-control-allow-credentials"] = "true";
        headers.vary = "origin";
      }
      response.writeHead(500, headers);
    }
    response.end(JSON.stringify({ error: { code: "INTERNAL_ERROR", message: "Request failed" } }));
  } finally {
    console.log(JSON.stringify({
      level: "info",
      event: "api.request",
      trace_id: traceId,
      method: request.method,
      path: request.url,
      status: response.statusCode,
      duration_ms: Math.round(performance.now() - startedAt),
    }));
  }
});

server.listen(config.port, () => {
  console.log(JSON.stringify({
    level: "info",
    event: "api.started",
    app_env: config.appEnv,
    port: config.port,
  }));
});
