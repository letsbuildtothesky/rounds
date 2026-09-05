import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { createDeliveryHandler } from "./create-delivery-handler.js";
import { confirmPickupHandler } from "./confirm-pickup-handler.js";
import { confirmStopArrivalHandler } from "./confirm-stop-arrival-handler.js";
import { completeStopPodHandler } from "./complete-stop-pod-handler.js";
import { driverSessionHandler } from "./driver-session-handler.js";
import { driverOperationsThreadHandler } from "./driver-operations-thread-handler.js";
import { sendDriverMessageHandler } from "./send-driver-message-handler.js";
import { prepareMessageMediaHandler, verifyMessageMediaHandler } from "./prepare-message-media-handler.js";
import { operationsPlanningHandler } from "./operations-planning-handler.js";
import { operationsHistoryHandler } from "./operations-history-handler.js";
import { operationsCommunicationsHandler } from "./operations-communications-handler.js";
import { sendOperationsMessageHandler } from "./send-operations-message-handler.js";
import { prepareOperationsMessageMediaHandler, verifyOperationsMessageMediaHandler } from "./prepare-operations-message-media-handler.js";
import { markDriverCommunicationThreadReadHandler, markOperationsCommunicationThreadReadHandler } from "./mark-communication-thread-read-handler.js";
import { readConfig } from "./config.js";
import { operationsSessionHandler } from "./operations-session-handler.js";
import { operationsActionHandler } from "./operations-action-handler.js";
import { operationsLiveMapHandler } from "./operations-live-map-handler.js";
import { operationsDeliveriesHandler } from "./operations-deliveries-handler.js";
import { operationsDriversHandler } from "./operations-drivers-handler.js";
import { setDriverRecurringScheduleHandler } from "./set-driver-recurring-schedule-handler.js";
import { clearDriverShiftExceptionHandler, setDriverShiftExceptionHandler } from "./set-driver-shift-exception-handler.js";
import { operationsRoundDetailHandler } from "./operations-round-detail-handler.js";
import { roundMoveHandler, roundMovePreviewHandler } from "./round-move-handler.js";
import { acknowledgeLiveDeliveryChangeHandler, applyLiveDeliveryChangeHandler, liveDeliveryChangePreviewHandler } from "./live-delivery-change-handler.js";
import { applyPrePickupDeliveryEditHandler, prePickupDeliveryEditPreviewHandler } from "./pre-pickup-delivery-edit-handler.js";
import { resolveOperationsExceptionHandler } from "./resolve-operations-exception-handler.js";
import { confirmDeliveryReturnHandler } from "./confirm-delivery-return-handler.js";
import { planRoundHandler } from "./plan-round-handler.js";
import { planningRouteHandler } from "./planning-route-handler.js";
import { createPlanningRouteService } from "./planning-route-service.js";
import { MapboxRoutingProvider } from "./routing-provider.js";
import { reportPickupProblemHandler } from "./report-pickup-problem-handler.js";
import { preparePodMediaHandler } from "./prepare-pod-media-handler.js";
import { prepareExceptionMediaHandler } from "./prepare-exception-media-handler.js";
import { reportDeliveryProblemHandler } from "./report-delivery-problem-handler.js";
import { reportLocationProblemHandler } from "./report-location-problem-handler.js";
import { reportDriverEmergencyHandler } from "./report-driver-emergency-handler.js";
import { startDriverShiftHandler } from "./start-driver-shift-handler.js";
import { endDriverShiftHandler } from "./end-driver-shift-handler.js";
import { updateDriverPreferredLocaleHandler } from "./update-driver-preferred-locale-handler.js";
import { logContactAttemptHandler } from "./log-contact-attempt-handler.js";
import { SupabaseGateway } from "./supabase-gateway.js";

const config = readConfig();
const gateway = new SupabaseGateway(
  config.supabaseUrl,
  config.supabasePublishableKey,
  config.supabaseSecretKey,
);
const routeService = createPlanningRouteService(
  gateway,
  new MapboxRoutingProvider(config.mapboxRoutingAccessToken),
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
        "access-control-allow-methods": "GET, POST, DELETE, OPTIONS",
        "access-control-allow-headers": "authorization, content-type, idempotency-key, if-match-version, x-rounds-tenant-id, x-trace-id",
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
    if (request.method === "GET" && request.url === "/v1/operations/action") {
      const webRequest = await toWebRequest(request);
      const actionResponse = await operationsActionHandler(webRequest, {
        identity: gateway,
        action: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(actionResponse, request.headers.origin));
      return;
    }
    const operationsLiveMapMatch = request.url?.match(/^\/v1\/operations\/rounds\/([0-9a-f-]+)\/live-map$/i);
    if (request.method === "GET" && operationsLiveMapMatch) {
      const webRequest = await toWebRequest(request);
      const liveMapResponse = await operationsLiveMapHandler(webRequest, operationsLiveMapMatch[1]!, {
        identity: gateway,
        rounds: gateway,
        trails: gateway,
        routes: routeService,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(liveMapResponse, request.headers.origin));
      return;
    }
    const operationsExceptionResolveMatch = request.url?.match(/^\/v1\/operations\/exceptions\/([0-9a-f-]+)\/resolve$/i);
    if (request.method === "POST" && operationsExceptionResolveMatch) {
      const webRequest = await toWebRequest(request);
      const resolveResponse = await resolveOperationsExceptionHandler(webRequest, operationsExceptionResolveMatch[1]!, {
        identity: gateway, action: gateway, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, addOperationsCors(resolveResponse, request.headers.origin));
      return;
    }
    const operationsDeliveryReturnMatch = request.url?.match(/^\/v1\/operations\/exceptions\/([0-9a-f-]+)\/confirm-return$/i);
    if (request.method === "POST" && operationsDeliveryReturnMatch) {
      const webRequest = await toWebRequest(request);
      const returnResponse = await confirmDeliveryReturnHandler(webRequest, operationsDeliveryReturnMatch[1]!, {
        identity: gateway, action: gateway, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, addOperationsCors(returnResponse, request.headers.origin));
      return;
    }
    if (request.method === "GET" && request.url === "/v1/operations/deliveries") {
      const webRequest = await toWebRequest(request);
      const deliveriesResponse = await operationsDeliveriesHandler(webRequest, {
        identity: gateway,
        deliveries: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(deliveriesResponse, request.headers.origin));
      return;
    }
    if (request.method === "GET" && new URL(request.url ?? "/", "http://rounds.local").pathname === "/v1/operations/drivers") {
      const webRequest = await toWebRequest(request);
      const driversResponse = await operationsDriversHandler(webRequest, {
        identity: gateway,
        drivers: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(driversResponse, request.headers.origin));
      return;
    }
    const recurringScheduleMatch = request.url?.match(/^\/v1\/operations\/drivers\/([0-9a-f-]+)\/recurring-schedule$/i);
    if (request.method === "POST" && recurringScheduleMatch) {
      const webRequest = await toWebRequest(request);
      const scheduleResponse = await setDriverRecurringScheduleHandler(webRequest, recurringScheduleMatch[1]!, {
        identity: gateway,
        drivers: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(scheduleResponse, request.headers.origin));
      return;
    }
    const shiftExceptionMatch = request.url?.match(/^\/v1\/operations\/drivers\/([0-9a-f-]+)\/shift-exception$/i);
    if (request.method === "POST" && shiftExceptionMatch) {
      const webRequest = await toWebRequest(request);
      const exceptionResponse = await setDriverShiftExceptionHandler(webRequest, shiftExceptionMatch[1]!, {
        identity: gateway,
        drivers: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(exceptionResponse, request.headers.origin));
      return;
    }
    if (request.method === "DELETE" && shiftExceptionMatch) {
      const webRequest = await toWebRequest(request);
      const exceptionResponse = await clearDriverShiftExceptionHandler(webRequest, shiftExceptionMatch[1]!, {
        identity: gateway, drivers: gateway, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, addOperationsCors(exceptionResponse, request.headers.origin));
      return;
    }
    if (request.method === "POST" && request.url === "/v1/operations/rounds/move-preview") {
      const webRequest = await toWebRequest(request);
      const moveResponse = await roundMovePreviewHandler(webRequest, {
        identity: gateway, rounds: gateway, routes: routeService, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, addOperationsCors(moveResponse, request.headers.origin));
      return;
    }
    if (request.method === "POST" && request.url === "/v1/operations/rounds/move") {
      const webRequest = await toWebRequest(request);
      const moveResponse = await roundMoveHandler(webRequest, {
        identity: gateway, rounds: gateway, routes: routeService, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, addOperationsCors(moveResponse, request.headers.origin));
      return;
    }
    if (request.method === "POST" && request.url === "/v1/operations/live-delivery-changes/preview") {
      const webRequest = await toWebRequest(request);
      const changeResponse = await liveDeliveryChangePreviewHandler(webRequest, {
        identity: gateway, changes: gateway, routes: routeService, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, addOperationsCors(changeResponse, request.headers.origin));
      return;
    }
    if (request.method === "POST" && request.url === "/v1/operations/live-delivery-changes") {
      const webRequest = await toWebRequest(request);
      const changeResponse = await applyLiveDeliveryChangeHandler(webRequest, {
        identity: gateway, changes: gateway, routes: routeService, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, addOperationsCors(changeResponse, request.headers.origin));
      return;
    }
    if (request.method === "POST" && request.url === "/v1/operations/delivery-edits/preview") {
      const webRequest = await toWebRequest(request);
      const editResponse = await prePickupDeliveryEditPreviewHandler(webRequest, {
        identity: gateway, deliveries: gateway, routes: routeService, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, addOperationsCors(editResponse, request.headers.origin));
      return;
    }
    if (request.method === "POST" && request.url === "/v1/operations/delivery-edits") {
      const webRequest = await toWebRequest(request);
      const editResponse = await applyPrePickupDeliveryEditHandler(webRequest, {
        identity: gateway, deliveries: gateway, routes: routeService, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, addOperationsCors(editResponse, request.headers.origin));
      return;
    }
    const operationsRoundMatch = request.url?.match(/^\/v1\/operations\/rounds\/([0-9a-f-]+)$/i);
    if (request.method === "GET" && operationsRoundMatch) {
      const webRequest = await toWebRequest(request);
      const roundDetailResponse = await operationsRoundDetailHandler(webRequest, operationsRoundMatch[1]!, {
        identity: gateway,
        rounds: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(roundDetailResponse, request.headers.origin));
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
    if (request.method === "POST" && request.url === "/v1/operations/planning/route-preview") {
      const webRequest = await toWebRequest(request);
      const routeResponse = await planningRouteHandler(webRequest, {
        identity: gateway,
        routes: routeService,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(routeResponse, request.headers.origin));
      return;
    }
    if (request.method === "GET" && request.url === "/v1/operations/history") {
      const webRequest = await toWebRequest(request);
      const historyResponse = await operationsHistoryHandler(webRequest, {
        identity: gateway,
        history: gateway,
        uuid: () => crypto.randomUUID(),
      });
      sendNode(response, addOperationsCors(historyResponse, request.headers.origin));
      return;
    }
    if (request.method === "GET" && request.url === "/v1/operations/communications") {
      const webRequest = await toWebRequest(request);
      const communicationsResponse = await operationsCommunicationsHandler(webRequest, {
        identity: gateway,
        communications: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(communicationsResponse, request.headers.origin));
      return;
    }
    const operationsMessageMatch = request.url?.match(/^\/v1\/operations\/communications\/([0-9a-f-]+)\/messages$/i);
    if (request.method === "POST" && operationsMessageMatch) {
      const webRequest = await toWebRequest(request);
      const messageResponse = await sendOperationsMessageHandler(webRequest, operationsMessageMatch[1]!, {
        identity: gateway,
        communications: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(messageResponse, request.headers.origin));
      return;
    }
    const operationsThreadReadMatch = request.url?.match(/^\/v1\/operations\/communications\/([0-9a-f-]+)\/read$/i);
    if (request.method === "POST" && operationsThreadReadMatch) {
      const webRequest = await toWebRequest(request);
      const readResponse = await markOperationsCommunicationThreadReadHandler(webRequest, operationsThreadReadMatch[1]!, {
        identity: gateway,
        communications: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(readResponse, request.headers.origin));
      return;
    }
    const operationsMessageMediaMatch = request.url?.match(/^\/v1\/operations\/communications\/([0-9a-f-]+)\/message-media$/i);
    if (request.method === "POST" && operationsMessageMediaMatch) {
      const webRequest = await toWebRequest(request);
      const mediaResponse = await prepareOperationsMessageMediaHandler(webRequest, operationsMessageMediaMatch[1]!, {
        identity: gateway,
        communications: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(mediaResponse, request.headers.origin));
      return;
    }
    const operationsMessageMediaVerifyMatch = request.url?.match(/^\/v1\/operations\/message-media\/([0-9a-f-]+)\/verify$/i);
    if (request.method === "POST" && operationsMessageMediaVerifyMatch) {
      const webRequest = await toWebRequest(request);
      const mediaResponse = await verifyOperationsMessageMediaHandler(webRequest, operationsMessageMediaVerifyMatch[1]!, {
        identity: gateway,
        communications: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, addOperationsCors(mediaResponse, request.headers.origin));
      return;
    }
    if (request.method === "POST" && request.url === "/v1/rounds") {
      const webRequest = await toWebRequest(request);
      const roundResponse = await planRoundHandler(webRequest, {
        identity: gateway,
        planning: gateway,
        routes: routeService,
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
    if (request.method === "POST" && request.url === "/v1/driver/preferences/locale") {
      const webRequest = await toWebRequest(request);
      const localeResponse = await updateDriverPreferredLocaleHandler(webRequest, {
        identity: gateway,
        profiles: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, localeResponse);
      return;
    }
    if (request.method === "POST" && request.url === "/v1/driver/shifts/start") {
      const webRequest = await toWebRequest(request);
      const shiftResponse = await startDriverShiftHandler(webRequest, {
        identity: gateway,
        shifts: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, shiftResponse);
      return;
    }
    if (request.method === "POST" && request.url === "/v1/driver/shifts/end") {
      const webRequest = await toWebRequest(request);
      const shiftResponse = await endDriverShiftHandler(webRequest, {
        identity: gateway,
        shifts: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, shiftResponse);
      return;
    }
    const liveChangeAckMatch = request.url?.match(/^\/v1\/driver\/live-delivery-changes\/([0-9a-f-]+)\/acknowledge$/i);
    if (request.method === "POST" && liveChangeAckMatch) {
      const webRequest = await toWebRequest(request);
      const ackResponse = await acknowledgeLiveDeliveryChangeHandler(webRequest, liveChangeAckMatch[1]!, {
        identity: gateway, changes: gateway, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, ackResponse);
      return;
    }
    const driverThreadMatch = request.url?.match(/^\/v1\/driver\/rounds\/([0-9a-f-]+)\/stops\/([0-9a-f-]+)\/thread$/i);
    if (request.method === "GET" && driverThreadMatch) {
      const webRequest = await toWebRequest(request);
      const threadResponse = await driverOperationsThreadHandler(webRequest, driverThreadMatch[1]!, driverThreadMatch[2]!, {
        identity: gateway,
        communications: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, threadResponse);
      return;
    }
    const driverThreadReadMatch = request.url?.match(/^\/v1\/driver\/rounds\/([0-9a-f-]+)\/stops\/([0-9a-f-]+)\/thread\/read$/i);
    if (request.method === "POST" && driverThreadReadMatch) {
      const webRequest = await toWebRequest(request);
      const readResponse = await markDriverCommunicationThreadReadHandler(webRequest, driverThreadReadMatch[1]!, driverThreadReadMatch[2]!, {
        identity: gateway,
        communications: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, readResponse);
      return;
    }
    const driverMessageMatch = request.url?.match(/^\/v1\/driver\/rounds\/([0-9a-f-]+)\/stops\/([0-9a-f-]+)\/messages$/i);
    if (request.method === "POST" && driverMessageMatch) {
      const webRequest = await toWebRequest(request);
      const messageResponse = await sendDriverMessageHandler(webRequest, driverMessageMatch[1]!, driverMessageMatch[2]!, {
        identity: gateway,
        communications: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, messageResponse);
      return;
    }
    const driverMessageMediaMatch = request.url?.match(/^\/v1\/driver\/rounds\/([0-9a-f-]+)\/stops\/([0-9a-f-]+)\/message-media$/i);
    if (request.method === "POST" && driverMessageMediaMatch) {
      const webRequest = await toWebRequest(request);
      const mediaResponse = await prepareMessageMediaHandler(webRequest, driverMessageMediaMatch[1]!, driverMessageMediaMatch[2]!, {
        identity: gateway, communications: gateway, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, mediaResponse);
      return;
    }
    const verifyDriverMessageMediaMatch = request.url?.match(/^\/v1\/driver\/message-media\/([0-9a-f-]+)\/verify$/i);
    if (request.method === "POST" && verifyDriverMessageMediaMatch) {
      const webRequest = await toWebRequest(request);
      const mediaResponse = await verifyMessageMediaHandler(webRequest, verifyDriverMessageMediaMatch[1]!, {
        identity: gateway, communications: gateway, uuid: () => crypto.randomUUID(), now: () => new Date(),
      });
      sendNode(response, mediaResponse);
      return;
    }
    const pickupMatch = request.url?.match(/^\/v1\/driver\/rounds\/([0-9a-f-]+)\/pickup$/i);
    if (request.method === "POST" && pickupMatch) {
      const webRequest = await toWebRequest(request);
      const pickupResponse = await confirmPickupHandler(webRequest, pickupMatch[1]!, {
        identity: gateway,
        pickup: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, pickupResponse);
      return;
    }
    const pickupProblemMatch = request.url?.match(/^\/v1\/driver\/stops\/([0-9a-f-]+)\/pickup-problem$/i);
    if (request.method === "POST" && pickupProblemMatch) {
      const webRequest = await toWebRequest(request);
      const problemResponse = await reportPickupProblemHandler(webRequest, pickupProblemMatch[1]!, {
        identity: gateway,
        stops: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, problemResponse);
      return;
    }
    const locationProblemMatch = request.url?.match(/^\/v1\/driver\/stops\/([0-9a-f-]+)\/location-problem$/i);
    if (request.method === "POST" && locationProblemMatch) {
      const webRequest = await toWebRequest(request);
      const problemResponse = await reportLocationProblemHandler(webRequest, locationProblemMatch[1]!, {
        identity: gateway,
        stops: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, problemResponse);
      return;
    }
    const driverEmergencyMatch = request.url?.match(/^\/v1\/driver\/stops\/([0-9a-f-]+)\/emergency$/i);
    if (request.method === "POST" && driverEmergencyMatch) {
      const webRequest = await toWebRequest(request);
      const emergencyResponse = await reportDriverEmergencyHandler(webRequest, driverEmergencyMatch[1]!, {
        identity: gateway,
        stops: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, emergencyResponse);
      return;
    }
    const contactAttemptMatch = request.url?.match(/^\/v1\/driver\/stops\/([0-9a-f-]+)\/contact-attempts$/i);
    if (request.method === "POST" && contactAttemptMatch) {
      const webRequest = await toWebRequest(request);
      const contactResponse = await logContactAttemptHandler(webRequest, contactAttemptMatch[1]!, {
        identity: gateway,
        communications: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, contactResponse);
      return;
    }
    const arrivalMatch = request.url?.match(/^\/v1\/driver\/stops\/([0-9a-f-]+)\/arrival$/i);
    if (request.method === "POST" && arrivalMatch) {
      const webRequest = await toWebRequest(request);
      const arrivalResponse = await confirmStopArrivalHandler(webRequest, arrivalMatch[1]!, {
        identity: gateway,
        stops: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, arrivalResponse);
      return;
    }
    const podMediaMatch = request.url?.match(/^\/v1\/driver\/stops\/([0-9a-f-]+)\/pod-media$/i);
    if (request.method === "POST" && podMediaMatch) {
      const webRequest = await toWebRequest(request);
      const mediaResponse = await preparePodMediaHandler(webRequest, podMediaMatch[1]!, {
        identity: gateway,
        stops: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, mediaResponse);
      return;
    }
    const exceptionMediaMatch = request.url?.match(/^\/v1\/driver\/stops\/([0-9a-f-]+)\/exception-media$/i);
    if (request.method === "POST" && exceptionMediaMatch) {
      const webRequest = await toWebRequest(request);
      const mediaResponse = await prepareExceptionMediaHandler(webRequest, exceptionMediaMatch[1]!, {
        identity: gateway,
        stops: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, mediaResponse);
      return;
    }
    const deliveryProblemMatch = request.url?.match(/^\/v1\/driver\/stops\/([0-9a-f-]+)\/delivery-problem$/i);
    if (request.method === "POST" && deliveryProblemMatch) {
      const webRequest = await toWebRequest(request);
      const problemResponse = await reportDeliveryProblemHandler(webRequest, deliveryProblemMatch[1]!, {
        identity: gateway,
        stops: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, problemResponse);
      return;
    }
    const podMatch = request.url?.match(/^\/v1\/driver\/stops\/([0-9a-f-]+)\/pod$/i);
    if (request.method === "POST" && podMatch) {
      const webRequest = await toWebRequest(request);
      const podResponse = await completeStopPodHandler(webRequest, podMatch[1]!, {
        identity: gateway,
        stops: gateway,
        uuid: () => crypto.randomUUID(),
        now: () => new Date(),
      });
      sendNode(response, podResponse);
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
    const failure = error && typeof error === "object" ? error as Record<string, unknown> : {};
    console.error(JSON.stringify({
      level: "error",
      event: "api.request_failed",
      trace_id: traceId,
      method: request.method,
      path: request.url,
      message: error instanceof Error ? error.message : typeof failure.message === "string" ? failure.message : String(error),
      ...(typeof failure.code === "string" ? { code: failure.code } : {}),
      ...(typeof failure.details === "string" ? { details: failure.details } : {}),
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
