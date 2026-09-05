"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import type {
  OperationsActionException,
  OperationsActionProjection,
  OperationsDeliveriesProjection,
  OperationsPlanningProjection,
  OperationsDeliveryItem,
  OperationsDriverCapacityItem,
  OperationsDriversProjection,
  OperationsLiveRoundMapProjection,
  OperationsRoundSummary,
  OperationsTenant,
  PlanRoundResult,
  PlanningRoutePreview,
  PrePickupDeliveryEditPreview,
  PrePickupDeliveryEditRequest,
  PrePickupDeliveryManifestItem,
  UnplannedDeliverySummary,
} from "@rounds/contracts";
import { OperationsMap, type OperationsMapCamera, type OperationsMapHandle, type OperationsMapMode } from "./operations-map";
import { DriversWorkspace } from "./drivers-workspace";
import { HistoryPanel } from "./history-panel";
import { ContactHistoryDrawer } from "./contact-history-drawer";
import { RoundsOverviewDrawer } from "./rounds-overview-drawer";
import { RoundDetailWorkspace } from "./round-detail-workspace";
import { DestinationPinPicker } from "./destination-pin-picker";
import { CommunicationsPanel } from "./communications-panel";
import { useOperationsCommunications } from "./use-operations-communications";
import { communicationUnreadByRound } from "../src/operations-communications-state";
import { operationsMapLegendEntries } from "../src/operations-map-legend";
import { tenantLocalDateTimeInput, tenantLocalDateTimeToIso } from "../src/operations-time";
import {
  deliveryCommandBoundary,
  deliveryMatchesScope,
  deliveryMatchesSearch,
  deliveryQueueTab,
  type DeliveryScope,
} from "../src/operations-delivery-dispatch";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";

type QueueTab = "action" | "ready" | "live" | "done";
type Selection =
  | { kind: "exception"; item: OperationsActionException }
  | { kind: "round"; item: OperationsRoundSummary }
  | { kind: "planning-delivery"; item: UnplannedDeliverySummary }
  | { kind: "delivery-record"; item: OperationsDeliveryItem }
  | null;
type DriverMapMenu = { round: OperationsRoundSummary; position: { latitude: number; longitude: number }; x: number; y: number };
type ApiError = { error?: { message?: string } };

type Props = {
  accessToken?: string;
  realtimeClient?: SupabaseClient;
  tenant: OperationsTenant;
  userName: string;
  demoMode?: boolean;
  deliveryIntake?: ReactNode;
  deliveryIntakeOpen?: boolean;
  driversOpen?: boolean;
  historyOpen?: boolean;
  deliveryRefreshKey?: number;
  communicationRequest?: { threadId: string; nonce: number; startVoice?: boolean };
  onCloseDeliveryIntake?: () => void;
  onDrivers?: () => void;
  onCloseDrivers?: () => void;
  onCloseHistory?: () => void;
  onAddDelivery: () => void;
  onHistory: () => void;
  onCommunications: (threadId?: string, options?: { startVoice?: boolean }) => void;
  onSignOut: () => void;
};

function demoProjection(tenantId: string): OperationsActionProjection {
  const reportedAt = new Date().toISOString();
  return {
    tenantId,
    observedAt: reportedAt,
    rounds: [
      { id: "demo-round-18", reference: "Round 18", serviceDate: "2026-09-02", state: "active", driverId: "demo-somchai", driverName: "Somchai K.", stopCount: 3, custodyStopCount: 2, openExceptionCount: 1, currentPosition: { latitude: 13.7298, longitude: 100.5487, capturedAt: reportedAt } },
      { id: "demo-round-19", reference: "Round 19", serviceDate: "2026-09-02", state: "active", driverId: "demo-nattawut", driverName: "Nattawut P.", stopCount: 2, custodyStopCount: 1, openExceptionCount: 0, currentPosition: { latitude: 13.7338, longitude: 100.5766, capturedAt: reportedAt } },
      { id: "demo-round-20", reference: "Round 20", serviceDate: "2026-09-02", state: "approved", driverId: "demo-pim", driverName: "Pim T.", stopCount: 3, custodyStopCount: 0, openExceptionCount: 0 },
    ],
    mapStops: [
      { roundId: "demo-round-18", stopId: "demo-stop-1", sequence: 1, stopState: "exception", deliveryId: "demo-delivery-10432", deliveryReference: "10432", recipientName: "K. Nattaporn", rawAddress: "The Emporio Place · Sukhumvit 24", coordinate: { latitude: 13.7274, longitude: 100.5663 } },
      { roundId: "demo-round-18", stopId: "demo-stop-2", sequence: 2, stopState: "arrived", deliveryId: "demo-delivery-10439", deliveryReference: "10439", recipientName: "Pullman Bangkok Hotel G", rawAddress: "Silom Road · Bang Rak", coordinate: { latitude: 13.7215, longitude: 100.5298 } },
      { roundId: "demo-round-18", stopId: "demo-stop-4", sequence: 3, stopState: "active", deliveryId: "demo-delivery-10421", deliveryReference: "10421", recipientName: "Pullman G", rawAddress: "Pullman Bangkok Hotel G", coordinate: { latitude: 13.7244, longitude: 100.5336 } },
      { roundId: "demo-round-19", stopId: "demo-stop-3", sequence: 1, stopState: "exception", deliveryId: "demo-delivery-10444", deliveryReference: "10444", recipientName: "Anantara Siam", rawAddress: "Ratchadamri Road · Pathum Wan", coordinate: { latitude: 13.7402, longitude: 100.5417 } },
      { roundId: "demo-round-19", stopId: "demo-stop-5", sequence: 2, stopState: "active", deliveryId: "demo-delivery-10423", deliveryReference: "10423", recipientName: "Park Hyatt Bangkok", rawAddress: "Wireless Road", coordinate: { latitude: 13.7362, longitude: 100.5612 } },
    ],
    exceptions: [
      { id: "demo-exception-1", deliveryId: "demo-delivery-10432", deliveryReference: "10432", recipientName: "K. Nattaporn", rawAddress: "The Emporio Place · Sukhumvit 24", coordinate: { latitude: 13.7274, longitude: 100.5663 }, stopId: "demo-stop-1", stopSequence: 1, stopState: "exception", stopVersion: 3, roundId: "demo-round-18", roundReference: "Round 18", roundState: "loading", driverId: "demo-somchai", driverName: "Somchai K.", stage: "pickup", category: "missing_item", note: "One manifest item is not physically present at pickup.", status: "open", manifestVersion: 1, reportedAt, operationsThreadId: "demo-thread-1" },
      { id: "demo-exception-2", deliveryId: "demo-delivery-10439", deliveryReference: "10439", recipientName: "Pullman Bangkok Hotel G", rawAddress: "Silom Road · Bang Rak", coordinate: { latitude: 13.7215, longitude: 100.5298 }, stopId: "demo-stop-2", stopSequence: 2, stopState: "arrived", stopVersion: 6, roundId: "demo-round-18", roundReference: "Round 18", roundState: "active", driverId: "demo-somchai", driverName: "Somchai K.", stage: "delivery", category: "damaged_item", note: "Packaging damage requires an Operations decision before handoff.", status: "open", manifestVersion: 2, reportedAt, operationsThreadId: "demo-thread-2" },
      { id: "demo-exception-3", deliveryId: "demo-delivery-10444", deliveryReference: "10444", recipientName: "Anantara Siam", rawAddress: "Ratchadamri Road · Pathum Wan", coordinate: { latitude: 13.7402, longitude: 100.5417 }, stopId: "demo-stop-3", stopSequence: 1, stopState: "exception", stopVersion: 2, roundId: "demo-round-19", roundReference: "Round 19", roundState: "loading", driverId: "demo-nattawut", driverName: "Nattawut P.", stage: "pickup", category: "wrong_item", note: "The physical package does not match the current manifest.", status: "open", manifestVersion: 1, reportedAt, operationsThreadId: "demo-thread-3" },
    ],
  };
}

function demoPlanningProjection(tenantId: string): OperationsPlanningProjection {
  return {
    tenantId,
    drivers: [
      { id: "demo-somchai", displayName: "Somchai K.", vehicleLabel: "Motorbike + box", vehiclePlate: "1GX 1042" },
      { id: "demo-pim", displayName: "Pim T.", vehicleLabel: "Car", vehiclePlate: "8KT 3318" },
    ],
    unplannedDeliveries: [
      { deliveryId: "demo-ready-10435", stopId: "demo-ready-stop-1", reference: "10435", serviceDate: "2026-09-02", pickupLocationId: "urbanflowers", recipientName: "James T.", rawAddress: "Sathorn Square · Sathorn", coordinate: { latitude: 13.7215, longitude: 100.5298 }, windowStart: "2026-09-02T06:00:00.000Z", windowEnd: "2026-09-02T08:30:00.000Z", manifestSummary: "1× Signature hamper", cargoRequirements: [{ cargoClassCode: "unclassified", displayName: "Unclassified cargo", quantity: 1, classificationStatus: "unclassified" } as const] },
      { deliveryId: "demo-ready-10441", stopId: "demo-ready-stop-2", reference: "10441", serviceDate: "2026-09-02", pickupLocationId: "urbanflowers", recipientName: "Marriott Sukhumvit", rawAddress: "Thonglor · Sukhumvit", coordinate: { latitude: 13.7308, longitude: 100.5828 }, windowStart: "2026-09-02T07:00:00.000Z", windowEnd: "2026-09-02T09:00:00.000Z", manifestSummary: "2× Lobby arrangement", cargoRequirements: [{ cargoClassCode: "unclassified", displayName: "Unclassified cargo", quantity: 2, classificationStatus: "unclassified" } as const] },
      { deliveryId: "demo-ready-10446", stopId: "demo-ready-stop-3", reference: "10446", serviceDate: "2026-09-02", pickupLocationId: "urbanflowers", recipientName: "Bangkok Hospital", rawAddress: "Phetchaburi Road", coordinate: { latitude: 13.7487, longitude: 100.5846 }, windowStart: "2026-09-02T08:00:00.000Z", windowEnd: "2026-09-02T11:00:00.000Z", manifestSummary: "1× Get well bouquet", cargoRequirements: [{ cargoClassCode: "unclassified", displayName: "Unclassified cargo", quantity: 1, classificationStatus: "unclassified" } as const] },
    ],
    activeRounds: demoProjection(tenantId).rounds,
  };
}

function demoDeliveriesProjection(tenantId: string): OperationsDeliveriesProjection {
  const observedAt = new Date().toISOString();
  const planning = demoPlanningProjection(tenantId);
  const action = demoProjection(tenantId);
  const planned: OperationsDeliveryItem[] = action.mapStops.map((stop) => {
    const round = action.rounds.find((item) => item.id === stop.roundId)!;
    const state: OperationsDeliveryItem["state"] = stop.stopState === "arrived" ? "arrived" : stop.stopState === "exception" ? "exception" : "en_route";
    return {
      deliveryId: stop.deliveryId, reference: stop.deliveryReference, state, version: 1, sourceSystem: "preview",
      serviceDate: round.serviceDate, serviceTimezone: "Asia/Bangkok", pickupLocationId: "urbanflowers", pickupLocationName: "UrbanFlowers",
      buyerSameAsRecipient: true, buyerName: stop.recipientName, buyerPhone: "+66000000000", recipientName: stop.recipientName,
      recipientPhone: "+66000000000", rawAddress: stop.rawAddress, coordinate: stop.coordinate, isSurprise: false,
      createdAt: observedAt, updatedAt: observedAt, stop: { id: stop.stopId, state: stop.stopState, version: 1, destinationVersion: 1 },
      promise: { windowStart: `${round.serviceDate}T02:00:00.000Z`, windowEnd: `${round.serviceDate}T10:00:00.000Z` },
      manifest: { id: `manifest-${stop.deliveryId}`, state: state === "en_route" || state === "arrived" ? "locked" : "draft", version: 1, items: [{ lineNumber: 1, description: "Flower delivery", quantity: 1 }] },
      round: { id: round.id, reference: round.reference, state: round.state, version: 1, sequence: stop.sequence, driverName: round.driverName },
    };
  });
  const unplanned: OperationsDeliveryItem[] = planning.unplannedDeliveries.map((item) => ({
    deliveryId: item.deliveryId, reference: item.reference, state: "unplanned", version: 1, sourceSystem: "preview",
    serviceDate: item.serviceDate, serviceTimezone: "Asia/Bangkok", pickupLocationId: item.pickupLocationId, pickupLocationName: "UrbanFlowers",
    buyerSameAsRecipient: true, buyerName: item.recipientName, buyerPhone: "+66000000000", recipientName: item.recipientName,
    recipientPhone: "+66000000000", rawAddress: item.rawAddress, coordinate: item.coordinate, isSurprise: false,
    createdAt: observedAt, updatedAt: observedAt, stop: { id: item.stopId, state: "draft", version: 1, destinationVersion: 1 },
    promise: { windowStart: item.windowStart, windowEnd: item.windowEnd },
    manifest: { id: `manifest-${item.deliveryId}`, state: "draft", version: 1, items: [{ lineNumber: 1, description: item.manifestSummary, quantity: 1 }] },
  }));
  return { tenantId, observedAt, deliveries: [...unplanned, ...planned] };
}

function demoCapacityProjection(tenantId: string, serviceDate: string): OperationsDriversProjection {
  const startAt = `${serviceDate}T01:00:00.000Z`;
  const endAt = `${serviceDate}T11:00:00.000Z`;
  const demoCargoLimits = [{ cargoClassCode: "demo", displayName: "Demo cargo", allowed: true, maxQuantity: 8 }];
  return {
    tenantId, serviceDate, observedAt: new Date().toISOString(),
    vehicleProfiles: [
      { id: "demo-bike", code: "bike-box", displayName: "Motorbike + box", vehicleGroup: "motorbike", departurePattern: "return_after_round", maxStopsPerDeparture: 4, planningDeliveriesPerBlock: 4, pickupTurnaroundMinutes: 15, requiresReview: false, version: 1, cargoLimits: demoCargoLimits },
      { id: "demo-car", code: "car", displayName: "Car", vehicleGroup: "car", departurePattern: "return_after_round", maxStopsPerDeparture: 8, planningDeliveriesPerBlock: 8, pickupTurnaroundMinutes: 20, requiresReview: false, version: 1, cargoLimits: demoCargoLimits },
    ],
    drivers: [
      { driverId: "demo-somchai", displayName: "Somchai K.", initials: "SK", vehiclePlate: "1GX 1042", presence: { state: "live", capturedAt: new Date().toISOString() }, availability: { state: "available", label: "Available", projectionBasis: "Inside effective shift" }, effectiveShift: { source: "recurring", startAt, endAt, crossesMidnight: false }, vehicleProfile: { id: "demo-bike", code: "bike-box", displayName: "Motorbike + box", vehicleGroup: "motorbike", departurePattern: "return_after_round", maxStopsPerDeparture: 4, planningDeliveriesPerBlock: 4, pickupTurnaroundMinutes: 15, requiresReview: false, version: 1, cargoLimits: demoCargoLimits }, completedDeliveriesToday: 3 },
      { driverId: "demo-pim", displayName: "Pim T.", initials: "PT", vehiclePlate: "8KT 3318", presence: { state: "unknown" }, availability: { state: "available", label: "Available", projectionBasis: "Inside effective shift" }, effectiveShift: { source: "recurring", startAt, endAt, crossesMidnight: false }, vehicleProfile: { id: "demo-car", code: "car", displayName: "Car", vehicleGroup: "car", departurePattern: "return_after_round", maxStopsPerDeparture: 8, planningDeliveriesPerBlock: 8, pickupTurnaroundMinutes: 20, requiresReview: false, version: 1, cargoLimits: demoCargoLimits }, completedDeliveriesToday: 2 },
    ],
    summary: { ownDrivers: 2, scheduled: 2, activeRounds: 0, availableNow: 2, scheduleRequired: 0, vehicleGroups: { motorbike: 1, car: 1 } },
  };
}

function shiftCalendarDate(value: string, days: number): string {
  const date = new Date(`${value}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

const exceptionLabels: Record<OperationsActionException["category"], string> = {
  missing_item: "Missing item",
  wrong_item: "Wrong item",
  damaged_item: "Damaged item",
  wrong_pin: "Wrong pin",
  wrong_entrance: "Wrong entrance / access",
  wrong_address: "Wrong address",
  cannot_find_location: "Cannot find location",
  emergency: "Driver emergency",
};

const mapModeCopy: Record<OperationsMapMode, { label: string; description: string; hint: string }> = {
  operations: { label: "Operations", description: "Quiet map · routes and decisions first", hint: "routes and decisions first" },
  satellite: { label: "Satellite", description: "Real-world aerial imagery for access and site checks", hint: "inspect real-world access" },
  site: { label: "3D Site", description: "Close building-level view · approach + handoff", hint: "building + approach + handoff" },
  street: { label: "Street", description: "Street-level imagery · Google preferred / Mapillary fallback", hint: "street imagery provider view" },
};

function shortTime(value: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: timezone }).format(new Date(value));
}

function localHour(value: string, timezone: string): number {
  const parts = new Intl.DateTimeFormat("en-GB", { timeZone: timezone, hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
    .formatToParts(new Date(value));
  const hour = Number(parts.find((part) => part.type === "hour")?.value ?? 0);
  const minute = Number(parts.find((part) => part.type === "minute")?.value ?? 0);
  return hour + minute / 60;
}

function hourLabel(value: number): string {
  const normalized = ((Math.round(value * 60) % 1440) + 1440) % 1440;
  return `${String(Math.floor(normalized / 60)).padStart(2, "0")}:${String(normalized % 60).padStart(2, "0")}`;
}

function nextRoundReference(deliveries: UnplannedDeliverySummary[]): string {
  const serviceDate = deliveries[0]?.serviceDate ?? new Date().toISOString().slice(0, 10);
  const time = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Bangkok",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).format(new Date()).replaceAll(":", "");
  return `ROUND-${serviceDate.replaceAll("-", "")}-${time}`;
}

export function OperationsWorkstation({ accessToken, realtimeClient, tenant, userName, demoMode = false, deliveryIntake, deliveryIntakeOpen = false, driversOpen = false, historyOpen = false, deliveryRefreshKey = 0, communicationRequest, onCloseDeliveryIntake, onDrivers, onCloseDrivers, onCloseHistory, onAddDelivery, onHistory, onCommunications, onSignOut }: Props) {
  const communications = useOperationsCommunications(accessToken, tenant, realtimeClient);
  const roundUnread = useMemo(() => communicationUnreadByRound(communications.projection), [communications.projection]);
  const [projection, setProjection] = useState<OperationsActionProjection | null>(null);
  const [deliveryProjection, setDeliveryProjection] = useState<OperationsDeliveriesProjection | null>(null);
  const [planning, setPlanning] = useState<OperationsPlanningProjection | null>(null);
  const [driverCapacity, setDriverCapacity] = useState<OperationsDriversProjection | null>(null);
  const [planningDate, setPlanningDate] = useState(() => new Intl.DateTimeFormat("en-CA", { timeZone: tenant.timezone }).format(new Date()));
  const [selectedStops, setSelectedStops] = useState<string[]>([]);
  const [planningDriverId, setPlanningDriverId] = useState("");
  const [roundReference, setRoundReference] = useState("");
  const [roundSubmitting, setRoundSubmitting] = useState(false);
  const [roundError, setRoundError] = useState("");
  const [roundSuccess, setRoundSuccess] = useState<Extract<PlanRoundResult, { status: "committed" }> | null>(null);
  const [roundIdempotencyKey, setRoundIdempotencyKey] = useState(() => crypto.randomUUID());
  const [routePreview, setRoutePreview] = useState<PlanningRoutePreview | null>(null);
  const [liveMapProjections, setLiveMapProjections] = useState<Record<string, OperationsLiveRoundMapProjection>>({});
  const [requestedDepartureAt, setRequestedDepartureAt] = useState("");
  const [routeLoading, setRouteLoading] = useState(false);
  const [routeError, setRouteError] = useState("");
  const [dispatchMode, setDispatchMode] = useState<"live" | "plan">("live");
  const [tab, setTab] = useState<QueueTab>("action");
  const [query, setQuery] = useState("");
  const [deliveryScope, setDeliveryScope] = useState<DeliveryScope>("all");
  const [selection, setSelection] = useState<Selection>(null);
  const [loading, setLoading] = useState(true);
  const [stale, setStale] = useState(false);
  const [error, setError] = useState("");
  const [profileOpen, setProfileOpen] = useState(false);
  const [mapMode, setMapMode] = useState<OperationsMapMode>("operations");
  const [mapMenuOpen, setMapMenuOpen] = useState(false);
  const [mapCamera, setMapCamera] = useState<OperationsMapCamera>({ bearing: 0, pitch: 0 });
  const operationsMapRef = useRef<OperationsMapHandle>(null);
  const [mapHint, setMapHint] = useState("");
  const [roundDetailId, setRoundDetailId] = useState("");
  const [roundDetailStopId, setRoundDetailStopId] = useState("");
  const [contactHistoryThreadId, setContactHistoryThreadId] = useState("");
  const [roundsOverviewOpen, setRoundsOverviewOpen] = useState(false);
  const [driverMapMenu, setDriverMapMenu] = useState<DriverMapMenu | null>(null);
  const contactHistoryThread = communications.projection?.threads.find((thread) => thread.id === contactHistoryThreadId) ?? null;
  const driverMapThread = driverMapMenu
    ? communications.projection?.threads.find((thread) => thread.roundId === driverMapMenu.round.id)
      ?? null
    : null;
  const driverMapVehicle = driverMapMenu
    ? driverCapacity?.drivers.find((driver) => driver.driverId === driverMapMenu.round.driverId)?.vehicleProfile?.displayName
      ?? driverCapacity?.drivers.find((driver) => driver.driverId === driverMapMenu.round.driverId)?.vehiclePlate
      ?? "Vehicle not recorded"
    : "";

  useEffect(() => {
    if (selection) {
      setContactHistoryThreadId("");
      setRoundsOverviewOpen(false);
    }
  }, [selection]);

  useEffect(() => {
    if (driversOpen || historyOpen || deliveryIntakeOpen) {
      setContactHistoryThreadId("");
      setRoundsOverviewOpen(false);
    }
  }, [deliveryIntakeOpen, driversOpen, historyOpen]);

  useEffect(() => {
    if (contactHistoryThreadId) setRoundsOverviewOpen(false);
  }, [contactHistoryThreadId]);

  useEffect(() => {
    if (!driverMapMenu) return;
    const close = (event: KeyboardEvent) => { if (event.key === "Escape") setDriverMapMenu(null); };
    window.addEventListener("keydown", close);
    return () => window.removeEventListener("keydown", close);
  }, [driverMapMenu]);

  const load = useCallback(async (quiet = false) => {
    if (!quiet) setLoading(true);
    if (demoMode) {
      setProjection(demoProjection(tenant.id));
      setDeliveryProjection(demoDeliveriesProjection(tenant.id));
      setError("");
      setStale(false);
      setLoading(false);
      return;
    }
    try {
      const headers = { authorization: `Bearer ${accessToken}`, "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() };
      const [actionResponse, deliveriesResponse] = await Promise.all([
        fetch(`${roundsApiUrl}/v1/operations/action`, { headers }),
        fetch(`${roundsApiUrl}/v1/operations/deliveries`, { headers: { ...headers, "x-trace-id": crypto.randomUUID() } }),
      ]);
      const [actionBody, deliveriesBody] = await Promise.all([
        actionResponse.json() as Promise<OperationsActionProjection | ApiError>,
        deliveriesResponse.json() as Promise<OperationsDeliveriesProjection | ApiError>,
      ]);
      if (!actionResponse.ok) throw new Error((actionBody as ApiError).error?.message ?? `Action HTTP ${actionResponse.status}`);
      if (!deliveriesResponse.ok) throw new Error((deliveriesBody as ApiError).error?.message ?? `Deliveries HTTP ${deliveriesResponse.status}`);
      setProjection(actionBody as OperationsActionProjection);
      setDeliveryProjection(deliveriesBody as OperationsDeliveriesProjection);
      setError("");
      setStale(false);
    } catch (caught) {
      if (quiet) setStale(true);
      else setError(caught instanceof Error ? caught.message : "Dispatch could not be loaded");
    } finally {
      if (!quiet) setLoading(false);
    }
  }, [accessToken, deliveryRefreshKey, demoMode, tenant.id]);

  const loadPlanning = useCallback(async () => {
    if (demoMode) {
      const data = demoPlanningProjection(tenant.id);
      setPlanning(data);
      setPlanningDate((current) => data.unplannedDeliveries.some((delivery) => delivery.serviceDate === current) ? current : data.unplannedDeliveries[0]?.serviceDate ?? current);
      setPlanningDriverId((current) => current || data.drivers[0]?.id || "");
      setRoundReference((current) => current || nextRoundReference(data.unplannedDeliveries));
      return;
    }
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/planning`, {
        headers: {
          authorization: `Bearer ${accessToken}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
      });
      const body = await response.json() as OperationsPlanningProjection | ApiError;
      if (!response.ok) throw new Error((body as ApiError).error?.message ?? `Planning HTTP ${response.status}`);
      const data = body as OperationsPlanningProjection;
      setPlanning(data);
      setPlanningDate((current) => data.unplannedDeliveries.some((delivery) => delivery.serviceDate === current) ? current : data.unplannedDeliveries[0]?.serviceDate ?? current);
      setPlanningDriverId((current) => current || data.drivers[0]?.id || "");
      setRoundReference((current) => current || nextRoundReference(data.unplannedDeliveries));
      setError("");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Planning could not be loaded");
    }
  }, [accessToken, demoMode, tenant.id]);

  const loadDriverCapacity = useCallback(async () => {
    if (demoMode) { setDriverCapacity(demoCapacityProjection(tenant.id, planningDate)); return; }
    if (!accessToken) return;
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/drivers?serviceDate=${encodeURIComponent(planningDate)}`, {
        headers: { authorization: `Bearer ${accessToken}`, "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() },
      });
      const body = await response.json() as OperationsDriversProjection | ApiError;
      if (!response.ok) throw new Error((body as ApiError).error?.message ?? `Capacity HTTP ${response.status}`);
      const data = body as OperationsDriversProjection;
      setDriverCapacity(data);
      setPlanningDriverId((current) => data.drivers.some((driver) => driver.driverId === current) ? current : data.drivers.find((driver) => driver.effectiveShift)?.driverId ?? data.drivers[0]?.driverId ?? "");
    } catch (caught) {
      setDriverCapacity(null);
      setRoundError(caught instanceof Error ? caught.message : "Driver capacity could not be loaded");
    }
  }, [accessToken, demoMode, planningDate, tenant.id]);

  const activeRoundKey = useMemo(
    () => projection?.rounds.filter((round) => round.state === "active").map((round) => round.id).sort().join(",") ?? "",
    [projection?.rounds],
  );

  const loadLiveMapEvidence = useCallback(async () => {
    if (demoMode || dispatchMode !== "live" || !accessToken || !activeRoundKey) {
      setLiveMapProjections({});
      return;
    }
    const roundIds = activeRoundKey.split(",").filter(Boolean);
    const entries = await Promise.all(roundIds.map(async (roundId) => {
      try {
        const response = await fetch(`${roundsApiUrl}/v1/operations/rounds/${roundId}/live-map`, {
          headers: { authorization: `Bearer ${accessToken}`, "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() },
        });
        if (!response.ok) return null;
        return [roundId, await response.json() as OperationsLiveRoundMapProjection] as const;
      } catch {
        return null;
      }
    }));
    setLiveMapProjections(Object.fromEntries(entries.filter((entry): entry is readonly [string, OperationsLiveRoundMapProjection] => entry !== null)));
  }, [accessToken, activeRoundKey, demoMode, dispatchMode, tenant.id]);

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(true), 5000);
    return () => window.clearInterval(timer);
  }, [load]);

  useEffect(() => {
    if (dispatchMode === "plan") void loadPlanning();
  }, [dispatchMode, loadPlanning]);

  useEffect(() => {
    if (dispatchMode === "plan") void loadDriverCapacity();
  }, [dispatchMode, loadDriverCapacity]);

  useEffect(() => {
    void loadLiveMapEvidence();
    if (demoMode || dispatchMode !== "live" || !activeRoundKey) return;
    const timer = window.setInterval(() => void loadLiveMapEvidence(), 30_000);
    return () => window.clearInterval(timer);
  }, [activeRoundKey, demoMode, dispatchMode, loadLiveMapEvidence]);

  useEffect(() => {
    setMapHint(`${mapModeCopy[mapMode].label} · ${mapModeCopy[mapMode].hint}`);
    const timer = window.setTimeout(() => setMapHint(""), 1800);
    return () => window.clearTimeout(timer);
  }, [mapMode]);

  const today = new Intl.DateTimeFormat("en-CA", { timeZone: tenant.timezone }).format(new Date());
  const buckets = useMemo(() => {
    const scopedDeliveries = deliveryProjection?.deliveries.filter((item) => deliveryMatchesScope(item, deliveryScope, today)) ?? [];
    const scopedDeliveryIds = new Set(scopedDeliveries.map((item) => item.deliveryId));
    return {
      action: projection?.exceptions.filter((item) => deliveryScope === "all" || scopedDeliveryIds.has(item.deliveryId)) ?? [],
      ready: scopedDeliveries.filter((item) => deliveryQueueTab(item) === "ready"),
      live: scopedDeliveries.filter((item) => deliveryQueueTab(item) === "live"),
      done: scopedDeliveries.filter((item) => deliveryQueueTab(item) === "done"),
    };
  }, [deliveryProjection, deliveryScope, projection?.exceptions, today]);

  const visible = useMemo(() => {
    const needle = query.trim().toLowerCase();
    if (tab === "action") return buckets.action.filter((item) => !needle || `${item.deliveryReference} ${item.recipientName} ${item.rawAddress}`.toLowerCase().includes(needle));
    return buckets[tab].filter((item) => deliveryMatchesSearch(item, needle));
  }, [buckets, query, tab]);

  const mapPlanningDeliveries = useMemo(
    () => planning?.unplannedDeliveries.filter((delivery) => delivery.serviceDate === planningDate) ?? [],
    [planning, planningDate],
  );
  const mapLegend = useMemo(() => operationsMapLegendEntries({
    mode: dispatchMode,
    hasOwnDriverPositions: Boolean(projection?.rounds.some((round) => round.currentPosition)),
    hasActionStops: Boolean(projection?.exceptions.some((item) => item.coordinate)),
    hasUnplannedStops: mapPlanningDeliveries.some((item) => item.coordinate),
    hasProposedRoute: Boolean(routePreview?.geometry.coordinates.length && routePreview.geometry.coordinates.length > 1),
    hasRemainingRoute: Object.values(liveMapProjections).some((item) => Boolean(item.remainingRoute)),
    hasActualTrail: Object.values(liveMapProjections).some((item) => Boolean(item.actualTrail)),
  }), [dispatchMode, liveMapProjections, mapPlanningDeliveries, projection?.exceptions, projection?.rounds, routePreview?.geometry.coordinates.length]);
  const liveMapRouteWarning = Object.values(liveMapProjections).find((item) => item.routeStatus === "unavailable")?.routeUnavailableReason;

  const handleMapCameraChange = useCallback((camera: OperationsMapCamera) => {
    setMapCamera((current) => Math.abs(current.bearing - camera.bearing) < 0.01 && Math.abs(current.pitch - camera.pitch) < 0.01 ? current : camera);
  }, []);

  const streetContext = useMemo(() => {
    if (selection?.kind === "exception") {
      return { title: `${selection.item.deliveryReference} · ${selection.item.recipientName}`, address: selection.item.rawAddress, coordinate: selection.item.coordinate ?? { latitude: 13.735, longitude: 100.5598 } };
    }
    if (selection?.kind === "planning-delivery" || selection?.kind === "delivery-record") {
      return { title: `${selection.item.reference} · ${selection.item.recipientName}`, address: selection.item.rawAddress, coordinate: selection.item.coordinate ?? { latitude: 13.735, longitude: 100.5598 } };
    }
    if (selection?.kind === "round" && selection.item.currentPosition) {
      return { title: `${selection.item.reference} · ${selection.item.driverName}`, address: "Current server-reported driver position", coordinate: selection.item.currentPosition };
    }
    const fallback = projection?.exceptions.find((item) => item.coordinate);
    return {
      title: fallback ? `${fallback.deliveryReference} · ${fallback.recipientName}` : "Bangkok operations area",
      address: fallback?.rawAddress ?? "Select a delivery or driver marker for a precise street viewpoint.",
      coordinate: fallback?.coordinate ?? { latitude: 13.735, longitude: 100.5598 },
    };
  }, [projection, selection]);

  const activeRounds = projection?.rounds.filter((round) => round.state === "active").length ?? 0;
  const chosenDeliveries = useMemo(() => planning?.unplannedDeliveries.filter((delivery) => selectedStops.includes(delivery.stopId)) ?? [], [planning, selectedStops]);
  const planningAnchor = chosenDeliveries[0];
  const chosenDriver = driverCapacity?.drivers.find((driver) => driver.driverId === planningDriverId);
  const capacityIssue = !planningDriverId ? "Choose an own-team driver."
    : !chosenDriver ? "Driver capacity is not loaded for this date."
    : !chosenDriver.effectiveShift ? chosenDriver.dateException?.kind === "off" ? "Driver has a day-off exception for this date." : "Driver is not scheduled for this date."
    : !chosenDriver.vehicleProfile ? "Driver has no active vehicle profile for this date."
    : selectedStops.length > chosenDriver.vehicleProfile.maxStopsPerDeparture ? `${chosenDriver.vehicleProfile.displayName} allows ${chosenDriver.vehicleProfile.maxStopsPerDeparture} Stop${chosenDriver.vehicleProfile.maxStopsPerDeparture === 1 ? "" : "s"} per departure.`
    : chosenDriver.vehicleProfile.departurePattern === "return_after_every_delivery" && selectedStops.length > 1 ? "Vehicle rules require returning to pickup after every delivery."
    : "";

  useEffect(() => {
    setRoutePreview(null);
    setRouteError("");
    if (dispatchMode !== "plan" || demoMode || capacityIssue || !planningDriverId || selectedStops.length === 0) {
      setRouteLoading(false);
      return;
    }
    const controller = new AbortController();
    const timer = window.setTimeout(async () => {
      setRouteLoading(true);
      try {
        const response = await fetch(`${roundsApiUrl}/v1/operations/planning/route-preview`, {
          method: "POST",
          signal: controller.signal,
          headers: {
            authorization: `Bearer ${accessToken}`,
            "content-type": "application/json",
            "x-rounds-tenant-id": tenant.id,
            "x-trace-id": crypto.randomUUID(),
          },
          body: JSON.stringify({
            serviceDate: planningDate,
            driverId: planningDriverId,
            stopIds: selectedStops,
            ...(requestedDepartureAt ? { departureAt: requestedDepartureAt } : {}),
          }),
        });
        const body = await response.json() as PlanningRoutePreview | ApiError;
        if (!response.ok) throw new Error((body as ApiError).error?.message ?? `Route preview HTTP ${response.status}`);
        setRoutePreview(body as PlanningRoutePreview);
      } catch (caught) {
        if (!controller.signal.aborted) setRouteError(caught instanceof Error ? caught.message : "Route could not be calculated");
      } finally {
        if (!controller.signal.aborted) setRouteLoading(false);
      }
    }, 250);
    return () => { window.clearTimeout(timer); controller.abort(); };
  }, [accessToken, capacityIssue, demoMode, dispatchMode, planningDate, planningDriverId, requestedDepartureAt, selectedStops, tenant.id]);

  function togglePlanningDelivery(delivery: UnplannedDeliverySummary) {
    if (planningAnchor && !selectedStops.includes(delivery.stopId) && (planningAnchor.serviceDate !== delivery.serviceDate || planningAnchor.pickupLocationId !== delivery.pickupLocationId)) return;
    setRoundError("");
    setRoundSuccess(null);
    setSelectedStops((current) => current.includes(delivery.stopId) ? current.filter((stopId) => stopId !== delivery.stopId) : [...current, delivery.stopId]);
  }

  function movePlanningStop(stopId: string, delta: -1 | 1) {
    setRoundError("");
    setRoundSuccess(null);
    setSelectedStops((current) => {
      const from = current.indexOf(stopId);
      const target = from + delta;
      if (from < 0 || target < 0 || target >= current.length) return current;
      const next = [...current];
      const [moved] = next.splice(from, 1);
      next.splice(target, 0, moved!);
      return next;
    });
  }

  function nudgePlanningDeparture(minutes: number) {
    const base = requestedDepartureAt || routePreview?.departureAt;
    if (!base) return;
    setRoundError("");
    setRoundSuccess(null);
    setRequestedDepartureAt(new Date(Date.parse(base) + minutes * 60_000).toISOString());
  }

  async function approveRound() {
    if (!planning || !planningDriverId || !roundReference.trim() || !chosenDeliveries.length) return;
    setRoundSubmitting(true);
    setRoundError("");
    setRoundSuccess(null);
    try {
      const response = await fetch(`${roundsApiUrl}/v1/rounds`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
          "idempotency-key": `operations:${roundIdempotencyKey}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
        body: JSON.stringify({
          reference: roundReference.trim(),
          serviceDate: chosenDeliveries[0]!.serviceDate,
          driverId: planningDriverId,
          stopIds: selectedStops,
          ...(requestedDepartureAt ? { departureAt: requestedDepartureAt } : {}),
        }),
      });
      const body = await response.json() as PlanRoundResult | ApiError;
      if (!response.ok || !("status" in body) || body.status !== "committed") throw new Error((body as ApiError).error?.message ?? `Round command HTTP ${response.status}`);
      setRoundSuccess(body);
      setSelectedStops([]);
      setRoundReference("");
      setRoundIdempotencyKey(crypto.randomUUID());
      await Promise.all([loadPlanning(), load(true)]);
    } catch (caught) {
      setRoundError(caught instanceof Error ? caught.message : "Round could not be approved");
    } finally {
      setRoundSubmitting(false);
    }
  }

  function openCommunications(threadId?: string, startVoice = false) {
    if (typeof window !== "undefined" && window.innerWidth <= 1180) setSelection(null);
    onCommunications(threadId, startVoice ? { startVoice: true } : undefined);
  }

  function openRoundDetail(roundId: string, stopId = "") {
    setRoundDetailStopId(stopId);
    setRoundDetailId(roundId);
  }

  function closeRoundDetail() {
    setRoundDetailId("");
    setRoundDetailStopId("");
  }

  return <main className="v45-app">
    <header className="v45-topbar">
      <div className="v45-wordmark">Rounds<i /></div>
      <div className="v45-workspace"><b>{tenant.displayName}</b><span>Bangkok · Own-team dispatch</span></div>
      <nav className="v45-nav" aria-label="Operations sections">
        <button className={!driversOpen && !historyOpen ? "on" : ""} type="button" onClick={() => { onCloseDrivers?.(); onCloseHistory?.(); }}>Dispatch</button>
        <button className={driversOpen ? "on" : ""} type="button" onClick={onDrivers}>Drivers</button>
        <button className={historyOpen ? "on" : ""} type="button" onClick={onHistory}>History</button>
        <button type="button" disabled title="Settings workspace is not connected yet">Settings</button>
      </nav>
      <div className="v45-spacer" />
      <button className="v45-network" type="button" disabled title="Network dispatch is outside the connected Own-Team slice"><i /><span>Own Team</span><ChevronIcon /></button>
      <button className="v45-util" type="button" title="Driver communications" onClick={() => openCommunications()}><MessageIcon />{!!communications.projection?.totalUnreadCount && <b>{communications.projection.totalUnreadCount}</b>}</button>
      <button className="v45-util" type="button" title="Operational alerts" onClick={() => setTab("action")}><BellIcon /></button>
      <div className="v45-profile-wrap"><button className="v45-util" type="button" title="Business settings" onClick={() => setProfileOpen((open) => !open)}><UserIcon /></button>{profileOpen && <div className="v45-profile-menu"><strong>{userName}</strong><span>{tenant.displayName}</span><button type="button" onClick={onSignOut}>Sign out</button></div>}</div>
    </header>

    {stale && <div className="v45-system-strip"><i /><b>Last-known operational view</b><span>Live refresh is paused. Decisions are withheld until current truth returns.</span><button onClick={() => void load()}>Retry</button></div>}

    <div className="v45-board">
      <aside className="v45-rail">
        <div className="v45-rail-head">
          <div className="v45-rail-title"><div><h1>Dispatch</h1><p>{dispatchMode === "plan" ? "Build today’s Rounds." : "What needs attention now."}</p></div><button type="button" className="v45-add" onClick={onAddDelivery}>+ Deliveries</button></div>
          <div className={`v45-mode ${dispatchMode === "plan" ? "plan" : ""}`}><button className={dispatchMode === "live" ? "on" : ""} type="button" onClick={() => { setDispatchMode("live"); setSelection(null); }}>Live</button><button className={dispatchMode === "plan" ? "on" : ""} type="button" onClick={() => { setDispatchMode("plan"); setSelection(null); }}>Plan <span>{planning?.unplannedDeliveries.length ?? buckets.ready.length}</span></button></div>
          {dispatchMode === "plan" ? <div className="v45-plan-controls"><div className="v45-plan-calendar"><div className="v45-plan-date"><button type="button" aria-label="Previous date" onClick={() => { setPlanningDate((date) => shiftCalendarDate(date, -1)); setSelectedStops([]); setRequestedDepartureAt(""); }}>‹</button><input aria-label="Planning date" type="date" value={planningDate} onChange={(event) => { setPlanningDate(event.target.value); setSelectedStops([]); setRequestedDepartureAt(""); setRoundError(""); setRoundSuccess(null); }} /><button type="button" aria-label="Next date" onClick={() => { setPlanningDate((date) => shiftCalendarDate(date, 1)); setSelectedStops([]); setRequestedDepartureAt(""); }}>›</button></div><button type="button" className="v45-plan-today" onClick={() => { setPlanningDate(new Intl.DateTimeFormat("en-CA", { timeZone: tenant.timezone }).format(new Date())); setSelectedStops([]); setRequestedDepartureAt(""); }}>Today</button></div><p><span>Unplanned deliveries waiting</span><b>{planning?.unplannedDeliveries.filter((delivery) => delivery.serviceDate === planningDate).length ?? "—"}</b></p><button type="button" onClick={() => { void loadPlanning(); void loadDriverCapacity(); }}>Refresh planning truth</button><small>Select Stops in visit order. Nothing is assigned until explicit approval.</small></div> : <div className="v45-scope"><label>Delivery view<select value={deliveryScope} onChange={(event) => { setDeliveryScope(event.target.value as DeliveryScope); setSelection(null); }}><option value="all">All deliveries</option><option value="today">Today</option></select></label><p><b>{buckets.action.length} action</b><span>·</span><b>{buckets.live.length} live</b><span>·</span><span>{buckets.done.length} done</span></p></div>}
          {dispatchMode === "live" && <div className="v45-tabs" role="tablist">
            {(["action", "ready", "live", "done"] as QueueTab[]).map((item) => <button key={item} type="button" role="tab" aria-selected={tab === item} className={tab === item ? "on" : ""} onClick={() => { setTab(item); setSelection(null); }}><b>{buckets[item].length}</b>{item[0]!.toUpperCase() + item.slice(1)}</button>)}
          </div>}
          <label className="v45-search"><SearchIcon /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search order, customer or area" /></label>
        </div>
        <div className="v45-queue">
          {dispatchMode === "plan" ? <PlanningQueue planning={planning} planningDate={planningDate} query={query} selection={selection} selectedStops={selectedStops} anchor={planningAnchor} setSelection={setSelection} onToggle={togglePlanningDelivery} onMove={movePlanningStop} timezone={tenant.timezone} /> : <><div className={`v45-group ${tab === "action" ? "action" : ""}`}><b>{tab === "action" ? "Needs action" : tab === "ready" ? "Ready" : tab === "live" ? "Live deliveries" : "Recently completed"}</b><span>{visible.length}</span></div>
          {loading ? <div className="v45-empty">Checking live Operations truth…</div> : error ? <div className="v45-empty error"><b>Couldn&apos;t load Dispatch</b><span>{error}</span><button onClick={() => void load()}>Retry</button></div> : visible.length === 0 ? <div className="v45-empty"><b>{tab === "action" ? "Nothing needs attention." : `No ${tab} work right now.`}</b><span>{tab === "action" ? "The exception queue is clear." : "Canonical deliveries appear here automatically."}</span></div> : tab === "action" ? (visible as OperationsActionException[]).map((item) => <ExceptionRow key={item.id} item={item} selected={selection?.kind === "exception" && selection.item.id === item.id} onSelect={() => setSelection({ kind: "exception", item })} timezone={tenant.timezone} />) : (visible as OperationsDeliveryItem[]).map((item) => <DeliveryRow key={item.deliveryId} item={item} selected={selection?.kind === "delivery-record" && selection.item.deliveryId === item.deliveryId} onSelect={() => setSelection({ kind: "delivery-record", item })} timezone={tenant.timezone} />)}</>}
        </div>
      </aside>

      <section className="v45-map-wrap">
        <div className="v45-map-header"><strong>Bangkok · {dispatchMode === "live" ? "Live" : "Plan"}</strong><span className="v45-map-context">{dispatchMode === "plan" ? `${planning?.unplannedDeliveries.filter((delivery) => delivery.serviceDate === planningDate).length ?? 0} unplanned · ${selectedStops.length} selected` : `${buckets.action.length} Action · ${buckets.live.length} Live · ${activeRounds} active Rounds · ${buckets.ready.length} planned`}</span><button className="v45-rounds-map-link" type="button" aria-haspopup="dialog" aria-expanded={roundsOverviewOpen} onClick={() => { setSelection(null); setContactHistoryThreadId(""); setRoundsOverviewOpen(true); }}>Rounds</button><button className="v45-map-automation" type="button" disabled title="Automatic planning is not connected yet"><i /><span>Manual</span></button><div className="v45-spacer" /><em className="v45-map-health"><i />{stale ? "Connection delayed" : dispatchMode === "plan" ? "Draft only" : "Connected"}</em><span>{dispatchMode === "plan" ? `${selectedStops.length} selected · not approved` : <>Live rounds <b>{activeRounds}</b></>}</span></div>
        <div className="v45-map-body" onClick={() => { setMapMenuOpen(false); setDriverMapMenu(null); }}>
          <OperationsMap
            ref={operationsMapRef}
            mode={dispatchMode}
            mapMode={mapMode}
            rounds={projection?.rounds ?? []}
            mapStops={projection?.mapStops ?? []}
            exceptions={projection?.exceptions ?? []}
            planningDeliveries={mapPlanningDeliveries}
            routeGeometry={routePreview?.geometry}
            liveMapProjections={Object.values(liveMapProjections)}
            communicationUnreadByRound={roundUnread}
            onCameraChange={handleMapCameraChange}
            onSelectRound={(round) => { setDispatchMode("live"); setTab(round.state === "complete" ? "done" : round.state === "active" ? "live" : "ready"); setSelection({ kind: "round", item: round }); }}
            onSelectStop={(round, stop) => { setSelection(null); openRoundDetail(round.id, stop.stopId); }}
            onOpenDriverMenu={(round, position, point) => { setSelection(null); setDriverMapMenu({ round, position, ...point }); }}
            onSelectException={(item) => { setDispatchMode("live"); setTab("action"); setSelection({ kind: "exception", item }); }}
            onSelectDelivery={(item) => { setDispatchMode("plan"); setSelection({ kind: "planning-delivery", item }); }}
          />
          <div className="v45-map-mode" onClick={(event) => event.stopPropagation()}>
            <button type="button" aria-haspopup="menu" aria-expanded={mapMenuOpen} onClick={() => setMapMenuOpen((open) => !open)}>{mapModeCopy[mapMode].label}<span>▾</span></button>
            <div className={`v45-map-mode-menu ${mapMenuOpen ? "open" : ""}`} role="menu">
              {(["operations", "satellite", "site", "street"] as OperationsMapMode[]).map((item) => <button key={item} type="button" role="menuitemradio" aria-checked={mapMode === item} className={mapMode === item ? "on" : ""} onClick={() => { setMapMode(item); setMapMenuOpen(false); }}><b>{mapModeCopy[item].label}</b><span>{mapModeCopy[item].description}</span></button>)}
              <button className="v45-map-layer" type="button" disabled><span><b>Weather layer</b><small>Requires a live weather feed</small></span><em>NOT CONNECTED</em></button>
              <button className="v45-map-layer" type="button" disabled><span><b>Network supply</b><small>Requires approved network-capacity data</small></span><em>NOT CONNECTED</em></button>
            </div>
          </div>
          {driverMapMenu && <div className="v45-driver-context-menu" style={{ left: `min(calc(100% - 256px), max(10px, ${driverMapMenu.x + 8}px))`, top: `min(calc(100% - 304px), max(10px, ${driverMapMenu.y}px))` }} onClick={(event) => event.stopPropagation()}>
            <header><small>OWN DRIVER</small><strong>{driverMapMenu.round.driverName}</strong><span>{driverMapMenu.round.reference} · {driverMapVehicle} · {driverMapMenu.round.state}</span></header>
            <div><button className="primary" type="button" disabled={!driverMapThread} onClick={() => { openCommunications(driverMapThread?.id); setDriverMapMenu(null); }}>Message driver <kbd>M</kbd></button><button type="button" disabled title="In-app calling is not connected yet">Call driver <kbd>C</kbd></button><button type="button" disabled={!driverMapThread} onClick={() => { openCommunications(driverMapThread?.id, true); setDriverMapMenu(null); }}>Voice note <kbd>V</kbd></button><i /><button type="button" onClick={() => { operationsMapRef.current?.focusPosition(driverMapMenu.position); setDriverMapMenu(null); }}>Center on driver</button><button type="button" onClick={() => { const round = driverMapMenu.round; setDispatchMode("live"); setTab(round.state === "complete" ? "done" : round.state === "active" ? "live" : "ready"); setSelection({ kind: "round", item: round }); setDriverMapMenu(null); }}>Show full Round</button></div>
          </div>}
          {demoMode && <div className="v45-preview-badge"><b>PREVIEW DATA</b><span>Positions shown here are UX samples, not live drivers.</span></div>}
          {!demoMode && dispatchMode === "live" && liveMapRouteWarning && <div className="v45-map-truth"><b>REMAINING ROUTE WITHHELD</b><span>{liveMapRouteWarning}</span></div>}
          {mapHint && <div className="v45-map-hint"><strong>{mapHint.split(" · ")[0]}</strong> · {mapHint.split(" · ").slice(1).join(" · ")}</div>}
          {mapMode !== "street" && <>{mapLegend.length > 0 && <div className="v45-legend" aria-label="Visible map evidence">{mapLegend.map((entry) => <span key={entry.key}><i className={entry.tone} />{entry.label}</span>)}</div>}
          <button className="v45-focus" type="button" onClick={() => operationsMapRef.current?.control("focus")}><FocusIcon />Focus map</button>
          <div className="v45-camera">
            <button type="button" title="Zoom in" onClick={() => operationsMapRef.current?.control("zoom-in")}>+</button>
            <button type="button" title="Zoom out" onClick={() => operationsMapRef.current?.control("zoom-out")}>−</button>
            <button type="button" title="Rotate left" onClick={() => operationsMapRef.current?.control("rotate-left")}>↶</button>
            <button type="button" className="compass" title="Return North" onClick={() => operationsMapRef.current?.control("north")}><span style={{ transform: `rotate(${-mapCamera.bearing}deg)` }}>↑</span><small>{Math.round((mapCamera.bearing % 360 + 360) % 360)}°</small></button>
            <button type="button" title="Rotate right" onClick={() => operationsMapRef.current?.control("rotate-right")}>↷</button>
            <button type="button" className={mapCamera.pitch >= 20 ? "on" : ""} title="Toggle 2D / 3D" onClick={() => {
              operationsMapRef.current?.control(mapCamera.pitch >= 20 ? "pitch-2d" : "pitch-3d");
            }}>{mapCamera.pitch >= 20 ? "2D" : "3D"}</button>
          </div></>}
          {mapMode === "street" && <div className="v45-street-panel">
            <section><div><small>STREET IMAGERY</small><h2>See the entrance before the driver arrives.</h2><p>Street imagery is supplied by a separate provider from the Rounds Mapbox map. Open the selected, real coordinate in Google Street View; Mapillary remains the fallback when coverage is missing.</p><article><span><b>Google Street View</b><small>Preferred provider · consistent Bangkok coverage</small></span><em>RECOMMENDED</em></article><article><span><b>Mapillary</b><small>Free crowdsourced imagery · coverage varies by street</small></span><em>FALLBACK</em></article></div></section>
            <aside><small>SELECTED SITE</small><h3>{streetContext.title}</h3><p>{streetContext.address}</p><dl><div><dt>Latitude</dt><dd>{streetContext.coordinate.latitude.toFixed(6)}</dd></div><div><dt>Longitude</dt><dd>{streetContext.coordinate.longitude.toFixed(6)}</dd></div><div><dt>Source</dt><dd>Saved operational coordinate</dd></div></dl><button className="primary" type="button" onClick={() => window.open(`https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${streetContext.coordinate.latitude},${streetContext.coordinate.longitude}`, "_blank", "noopener,noreferrer")}>Open Google Street View</button><button type="button" onClick={() => setMapMode("operations")}>Back to Operations map</button></aside>
          </div>}
        </div>

        {dispatchMode === "plan" && <PlanningTimeline
          projection={driverCapacity}
          selectedDriverId={planningDriverId}
          onSelectDriver={(driverId) => { setPlanningDriverId(driverId); setRequestedDepartureAt(""); }}
          selectedStopCount={selectedStops.length}
          unplannedCount={planning?.unplannedDeliveries.filter((delivery) => delivery.serviceDate === planningDate).length ?? 0}
          serviceDate={planningDate}
          timezone={tenant.timezone}
          roundReference={roundReference}
          setRoundReference={setRoundReference}
          capacityIssue={capacityIssue}
          routePreview={routePreview}
          departureAdjusted={Boolean(requestedDepartureAt)}
          routeLoading={routeLoading}
          routeError={routeError}
          roundError={roundError}
          roundSuccess={roundSuccess}
          submitting={roundSubmitting}
          viewer={tenant.role === "viewer"}
          onClear={() => { setSelectedStops([]); setRequestedDepartureAt(""); }}
          onNudgeDeparture={nudgePlanningDeparture}
          onApprove={() => void approveRound()}
        />}

        <aside className={`v45-drawer ${selection ? "open" : ""}`} aria-hidden={!selection}>
          <header><div><small>{selection?.kind === "exception" ? "ORDER DECISION" : selection?.kind === "planning-delivery" ? "PLANNING DELIVERY" : selection?.kind === "delivery-record" ? "DELIVERY RECORD" : "LIVE ROUND"}</small><h2>{selection?.kind === "exception" || selection?.kind === "planning-delivery" || selection?.kind === "delivery-record" ? selection.item.recipientName : selection?.kind === "round" ? selection.item.reference : ""}</h2><p>{selection?.kind === "exception" ? `#${selection.item.deliveryReference} · ${selection.item.rawAddress}` : selection?.kind === "round" ? `${selection.item.driverName} · ${selection.item.stopCount} Stops` : selection?.kind === "planning-delivery" || selection?.kind === "delivery-record" ? `#${selection.item.reference} · ${selection.item.rawAddress}` : ""}</p></div><button type="button" onClick={() => setSelection(null)} aria-label="Close drawer"><CloseIcon /></button></header>
          <div className="v45-drawer-body">{selection?.kind === "exception" ? <ExceptionDrawer item={selection.item} accessToken={accessToken} tenant={tenant} onCommunications={openCommunications} onResolved={() => { setSelection(null); void load(); }} /> : selection?.kind === "round" ? <RoundDrawer item={selection.item} onCommunications={openCommunications} onOpen={() => openRoundDetail(selection.item.id)} /> : selection?.kind === "planning-delivery" ? <PlanningDrawer item={selection.item} timezone={tenant.timezone} selected={selectedStops.includes(selection.item.stopId)} onToggle={() => togglePlanningDelivery(selection.item)} onInspect={() => selection.item.coordinate && operationsMapRef.current?.focusPosition(selection.item.coordinate)} /> : selection?.kind === "delivery-record" ? <DeliveryRecordDrawer item={selection.item} accessToken={accessToken} tenant={tenant} onPlan={() => { setDispatchMode("plan"); setPlanningDate(selection.item.serviceDate); setQuery(selection.item.reference); setSelection(null); }} onOpenRound={() => selection.item.round && openRoundDetail(selection.item.round.id, selection.item.stop.id)} onHistory={() => { setSelection(null); onHistory(); }} onInspect={() => selection.item.coordinate && operationsMapRef.current?.focusPosition(selection.item.coordinate)} onUpdated={() => { setSelection(null); void load(); }} /> : null}</div>
        </aside>

        {contactHistoryThread && <ContactHistoryDrawer
          thread={contactHistoryThread}
          timezone={tenant.timezone}
          onClose={() => setContactHistoryThreadId("")}
          onMessage={(threadId) => openCommunications(threadId)}
          onOpenRound={(roundId) => { setContactHistoryThreadId(""); openRoundDetail(roundId); }}
        />}

        {roundsOverviewOpen && <RoundsOverviewDrawer
          accessToken={accessToken}
          tenant={tenant}
          rounds={projection?.rounds ?? []}
          onClose={() => setRoundsOverviewOpen(false)}
          onOpenRound={(roundId) => { setRoundsOverviewOpen(false); openRoundDetail(roundId); }}
          onPlanNext={() => { setRoundsOverviewOpen(false); setDispatchMode("plan"); setSelection(null); }}
        />}

        {accessToken && <CommunicationsPanel
          accessToken={accessToken}
          tenant={tenant}
          communications={communications}
          request={communicationRequest}
          drawerOpen={Boolean(selection || contactHistoryThread || roundsOverviewOpen)}
          onContactHistory={(threadId) => { setSelection(null); setRoundsOverviewOpen(false); setContactHistoryThreadId(threadId); }}
          onOpenRound={(roundId) => { setRoundsOverviewOpen(false); openRoundDetail(roundId); }}
        />}
      </section>

      {roundDetailId && accessToken && <RoundDetailWorkspace accessToken={accessToken} tenant={tenant} roundId={roundDetailId} initialStopId={roundDetailStopId} onClose={closeRoundDetail} onCommunications={(threadId) => { closeRoundDetail(); openCommunications(threadId); }} />}

      {driversOpen && accessToken && <DriversWorkspace
        accessToken={accessToken}
        tenant={tenant}
        onBackToDispatch={() => { onCloseDrivers?.(); }}
        onHistory={onHistory}
        onOpenRound={(roundId) => { onCloseDrivers?.(); openRoundDetail(roundId); }}
        onCommunications={() => openCommunications()}
      />}

      {historyOpen && accessToken && <HistoryPanel accessToken={accessToken} tenant={tenant} />}

      {deliveryIntakeOpen && <>
        <button className="v45-intake-scrim" type="button" aria-label="Close delivery intake" onClick={onCloseDeliveryIntake} />
        <aside className="v45-intake-drawer" role="dialog" aria-modal="true" aria-labelledby="v45-intake-title">
          <header><div><small>DELIVERY INTAKE</small><h2 id="v45-intake-title">Add delivery</h2><p>Manual single delivery · type and verify operational details</p></div><button type="button" onClick={onCloseDeliveryIntake} aria-label="Close delivery intake"><CloseIcon /></button></header>
          <div className="v45-intake-body">{deliveryIntake}</div>
        </aside>
      </>}
    </div>
  </main>;
}

function ExceptionRow({ item, selected, onSelect, timezone }: { item: OperationsActionException; selected: boolean; onSelect: () => void; timezone: string }) {
  return <button type="button" className={`v45-order ${selected ? "selected" : ""}`} onClick={onSelect}><span className="v45-order-line"><span><b>{item.recipientName}</b><small>{item.rawAddress}</small></span><em>#{item.deliveryReference}</em></span><span className="v45-order-foot"><span>{shortTime(item.reportedAt, timezone)}</span><span>{item.stage}</span><b>{exceptionLabels[item.category]}</b></span></button>;
}

function RoundRow({ item, selected, onSelect }: { item: OperationsRoundSummary; selected: boolean; onSelect: () => void }) {
  return <button type="button" className={`v45-order round ${selected ? "selected" : ""}`} onClick={onSelect}><span className="v45-order-line"><span><b>{item.reference}</b><small>{item.driverName}</small></span><em>{item.stopCount} Stops</em></span><span className="v45-order-foot"><span>{item.custodyStopCount} custody</span><span>{item.openExceptionCount} action</span><b>{item.state}</b></span></button>;
}

function deliveryStateLabel(state: OperationsDeliveryItem["state"]): string {
  return state.split("_").map((word) => word[0]!.toUpperCase() + word.slice(1)).join(" ");
}

function DeliveryRow({ item, selected, onSelect, timezone }: { item: OperationsDeliveryItem; selected: boolean; onSelect: () => void; timezone: string }) {
  return <button type="button" className={`v45-order delivery state-${item.state} ${selected ? "selected" : ""}`} onClick={onSelect}><span className="v45-order-line"><span><b>{item.recipientName}</b><small>{item.rawAddress}</small></span><em>#{item.reference}</em></span><span className="v45-order-foot"><span>{shortTime(item.promise.windowStart, timezone)}–{shortTime(item.promise.windowEnd, timezone)}</span><span>{item.round ? `${item.round.reference} · Stop ${item.round.sequence}` : item.pickupLocationName}</span><b>{deliveryStateLabel(item.state)}</b></span></button>;
}

function PlanningQueue({ planning, planningDate, query, selection, selectedStops, anchor, setSelection, onToggle, onMove, timezone }: { planning: OperationsPlanningProjection | null; planningDate: string; query: string; selection: Selection; selectedStops: string[]; anchor?: UnplannedDeliverySummary; setSelection: (selection: Selection) => void; onToggle: (item: UnplannedDeliverySummary) => void; onMove: (stopId: string, delta: -1 | 1) => void; timezone: string }) {
  const deliveries = planning?.unplannedDeliveries.filter((item) => item.serviceDate === planningDate && (!query.trim() || `${item.reference} ${item.recipientName} ${item.rawAddress}`.toLowerCase().includes(query.trim().toLowerCase()))) ?? [];
  return <><div className="v45-group"><b>Unplanned deliveries</b><span>{deliveries.length}</span></div>{!planning ? <div className="v45-empty">Loading the delivery pool…</div> : deliveries.length === 0 ? <div className="v45-empty"><b>No unplanned deliveries for this date.</b><span>Add a delivery or choose another planning date.</span></div> : deliveries.map((item) => <PlanningRow key={item.stopId} item={item} inspected={selection?.kind === "planning-delivery" && selection.item.stopId === item.stopId} selectedOrder={selectedStops.includes(item.stopId) ? selectedStops.indexOf(item.stopId) + 1 : 0} selectedCount={selectedStops.length} disabled={Boolean(anchor && !selectedStops.includes(item.stopId) && (anchor.serviceDate !== item.serviceDate || anchor.pickupLocationId !== item.pickupLocationId))} onInspect={() => setSelection({ kind: "planning-delivery", item })} onToggle={() => onToggle(item)} onMove={(delta) => onMove(item.stopId, delta)} timezone={timezone} />)}</>;
}

function PlanningRow({ item, inspected, selectedOrder, selectedCount, disabled, onInspect, onToggle, onMove, timezone }: { item: UnplannedDeliverySummary; inspected: boolean; selectedOrder: number; selectedCount: number; disabled: boolean; onInspect: () => void; onToggle: () => void; onMove: (delta: -1 | 1) => void; timezone: string }) {
  return <article className={`v45-order round planning ${inspected ? "selected" : ""} ${selectedOrder ? "proposed" : ""} ${disabled ? "disabled" : ""}`}><button type="button" className="v45-order-inspect" onClick={onInspect}><span className="v45-order-line"><span><b>{item.recipientName}</b><small>{item.rawAddress}</small></span><em>#{item.reference}</em></span><span className="v45-order-foot"><span>{shortTime(item.windowStart, timezone)}–{shortTime(item.windowEnd, timezone)}</span><span>{item.manifestSummary}</span><b>Ready</b></span></button><button className="v45-plan-toggle" type="button" disabled={disabled} aria-label={selectedOrder ? `Remove ${item.reference} from proposed Round` : `Add ${item.reference} to proposed Round`} onClick={onToggle}>{selectedOrder || "+"}</button>{selectedOrder > 0 && selectedCount > 1 && <span className="v45-plan-order-controls"><button type="button" disabled={selectedOrder === 1} aria-label={`Move ${item.reference} earlier`} onClick={() => onMove(-1)}>↑</button><button type="button" disabled={selectedOrder === selectedCount} aria-label={`Move ${item.reference} later`} onClick={() => onMove(1)}>↓</button></span>}</article>;
}

function PlanningTimeline({ projection, selectedDriverId, onSelectDriver, selectedStopCount, unplannedCount, serviceDate, timezone, roundReference, setRoundReference, capacityIssue, routePreview, departureAdjusted, routeLoading, routeError, roundError, roundSuccess, submitting, viewer, onClear, onNudgeDeparture, onApprove }: { projection: OperationsDriversProjection | null; selectedDriverId: string; onSelectDriver: (driverId: string) => void; selectedStopCount: number; unplannedCount: number; serviceDate: string; timezone: string; roundReference: string; setRoundReference: (reference: string) => void; capacityIssue: string; routePreview: PlanningRoutePreview | null; departureAdjusted: boolean; routeLoading: boolean; routeError: string; roundError: string; roundSuccess: Extract<PlanRoundResult, { status: "committed" }> | null; submitting: boolean; viewer: boolean; onClear: () => void; onNudgeDeparture: (minutes: number) => void; onApprove: () => void }) {
  const driver = projection?.drivers.find((item) => item.driverId === selectedDriverId);
  const routeBlocked = routePreview?.status === "blocked";
  const capacityBlocked = routePreview?.capacity.status === "blocked" || routePreview?.capacity.status === "review_required";
  const routeReady = routePreview?.status === "fits";
  const routeMinutes = routePreview ? Math.ceil(routePreview.durationSeconds / 60) : 0;
  const routeKm = routePreview ? (routePreview.distanceMeters / 1000).toFixed(1) : "0";
  const explainKind = capacityIssue || routeBlocked || routeError ? "risk" : routeReady ? "good" : "";
  const explainLabel = capacityIssue ? "CAPACITY CHECK" : routeLoading ? "ROUTING" : routeError ? "ROUTE UNAVAILABLE" : capacityBlocked ? "CAPACITY CONFLICT" : routeBlocked ? "PROMISE CONFLICT" : routeReady ? "ROUTE + WINDOW FIT" : selectedStopCount ? "ROUTE REQUIRED" : "PLANNING TRUTH";
  const explainText = capacityIssue || routeError || routePreview?.blockingReasons[0]
    || (routeLoading ? "Calculating live road time and each promised-window arrival…"
      : routeReady ? `${driver?.displayName ?? "Driver"} · ${routeKm} km · ${routeMinutes} min road time · finishes ${shortTime(routePreview.finishAt, timezone)}. ${routePreview.warnings[0] ?? "All promised windows fit."}`
        : selectedStopCount ? "Waiting for a server-calculated route before approval." : "Select deliveries, then choose the driver lane. No assignment occurs before approval.");
  const shifts = projection?.drivers.flatMap((item) => item.effectiveShift ? [item.effectiveShift] : []) ?? [];
  const startHour = shifts.length ? Math.max(0, Math.floor(Math.min(...shifts.map((shift) => localHour(shift.startAt, timezone))))) : 8;
  const endHour = shifts.length ? Math.min(30, Math.ceil(Math.max(...shifts.map((shift) => {
    const start = localHour(shift.startAt, timezone);
    const end = localHour(shift.endAt, timezone);
    return end <= start ? end + 24 : end;
  })))) : 20;
  const horizonEnd = Math.max(startHour + 4, endHour);
  const axisLabels = Array.from({ length: 4 }, (_, index) => hourLabel(startHour + (horizonEnd - startHour) * index / 3));
  return <section className="v45-planning-timeline" aria-label="Driver and vehicle planning timeline">
    <div className="v45-plan-resize"><span /></div>
    <header>
      <div className="v45-plan-title"><small>{departureAdjusted ? "ADJUSTED PLAN" : selectedStopCount ? "PROPOSED PLAN" : "PLAN ROUNDS"}</small><b>{selectedStopCount ? `${selectedStopCount} Stop${selectedStopCount === 1 ? "" : "s"} selected` : "Turn the unplanned pool into physical Rounds."}</b><span>{serviceDate} · Own-team capacity only</span></div>
      <div className="v45-plan-summary"><div><span>Unplanned</span><b>{unplannedCount}</b></div><div><span>Own drivers</span><b>{projection?.summary.ownDrivers ?? "—"}</b></div><div><span>Scheduled</span><b>{projection?.summary.scheduled ?? "—"}</b></div><div><span>Selected</span><b>{selectedStopCount}</b></div></div>
      <div className="v45-plan-head-actions"><label>Round reference<input value={roundReference} onChange={(event) => setRoundReference(event.target.value)} placeholder="ROUND-YYYYMMDD-01" /></label><label>Departure<span className="v45-plan-departure"><button type="button" disabled={!routePreview} onClick={() => onNudgeDeparture(-15)}>−15</button><b>{routePreview ? shortTime(routePreview.departureAt, timezone) : "Auto"}</b><button type="button" disabled={!routePreview} onClick={() => onNudgeDeparture(15)}>+15</button></span></label>{selectedStopCount > 0 && <button type="button" onClick={onClear}>Clear</button>}<button className="primary" type="button" disabled={submitting || viewer || !selectedStopCount || !selectedDriverId || !roundReference.trim() || Boolean(capacityIssue) || !routeReady} onClick={onApprove}>{submitting ? "Approving…" : viewer ? "Viewer cannot approve" : routeLoading ? "Calculating route…" : "Approve plan"}</button></div>
    </header>
    <div className={`v45-plan-explain ${explainKind}`}><i /><b>{explainLabel}</b><span>{explainText}</span>{roundError && <em>{roundError}</em>}{roundSuccess && <em className="success">{roundSuccess.state.reference} assigned</em>}</div>
    <div className="v45-plan-lanes">
      <div className="v45-plan-axis"><b>Driver · vehicle</b>{axisLabels.map((label) => <span key={label}>{label}</span>)}</div>
      {!projection ? <div className="v45-plan-empty">Loading effective shifts and vehicle rules…</div> : projection.drivers.length === 0 ? <div className="v45-plan-empty">No own-team drivers are configured.</div> : projection.drivers.map((item) => <PlanningDriverLane key={item.driverId} driver={item} selected={item.driverId === selectedDriverId} selectedStopCount={selectedStopCount} timezone={timezone} horizonStart={startHour} horizonEnd={horizonEnd} routePreview={item.driverId === selectedDriverId ? routePreview : null} onSelect={() => onSelectDriver(item.driverId)} />)}
    </div>
  </section>;
}

function PlanningDriverLane({ driver, selected, selectedStopCount, timezone, horizonStart, horizonEnd, routePreview, onSelect }: { driver: OperationsDriverCapacityItem; selected: boolean; selectedStopCount: number; timezone: string; horizonStart: number; horizonEnd: number; routePreview: PlanningRoutePreview | null; onSelect: () => void }) {
  const maxStops = driver.vehicleProfile?.maxStopsPerDeparture;
  const fits = Boolean(driver.effectiveShift && maxStops && selectedStopCount <= maxStops && !(driver.vehicleProfile?.departurePattern === "return_after_every_delivery" && selectedStopCount > 1));
  const horizon = horizonEnd - horizonStart;
  const start = driver.effectiveShift ? localHour(driver.effectiveShift.startAt, timezone) : horizonStart;
  const rawEnd = driver.effectiveShift ? localHour(driver.effectiveShift.endAt, timezone) : start;
  const end = rawEnd <= start ? rawEnd + 24 : rawEnd;
  const left = Math.max(0, Math.min(100, ((start - horizonStart) / horizon) * 100));
  const width = Math.max(0, Math.min(100 - left, (end - start) / horizon * 100));
  const routeStart = routePreview ? localHour(routePreview.departureAt, timezone) : start;
  const rawRouteEnd = routePreview ? localHour(routePreview.finishAt, timezone) : routeStart;
  const routeEnd = rawRouteEnd < routeStart ? rawRouteEnd + 24 : rawRouteEnd;
  const routeLeft = Math.max(0, Math.min(96, ((routeStart - horizonStart) / horizon) * 100));
  const routeWidth = Math.max(4, Math.min(100 - routeLeft, (routeEnd - routeStart) / horizon * 100));
  return <button type="button" className={`v45-plan-lane ${selected ? "selected" : ""} ${driver.effectiveShift ? "" : "off"}`} onClick={onSelect}>
    <span className="v45-plan-driver"><i>{driver.initials}</i><span><b>{driver.displayName}</b><em>{driver.vehicleProfile?.displayName ?? "Vehicle required"} · {maxStops ?? 0} Stop max</em><small>{driver.dateException ? `Date exception · ${driver.dateException.kind}` : driver.effectiveShift ? `${shortTime(driver.effectiveShift.startAt, timezone)}–${shortTime(driver.effectiveShift.endAt, timezone)}` : "Off shift"}</small></span></span>
    <span className="v45-plan-track"><i className="shift" style={{ left: `${left}%`, width: `${width}%` }} />{selected && selectedStopCount > 0 && <strong className={routePreview?.status === "blocked" || !fits ? "risk" : "fit"} style={routePreview ? { left: `${routeLeft}%`, width: `${routeWidth}%` } : undefined}>{selectedStopCount} Stop{selectedStopCount === 1 ? "" : "s"} · {routePreview ? routePreview.status === "fits" ? "routed fit" : "blocked" : fits ? "checking route" : "blocked"}</strong>}{driver.currentRound && <em className="current">{driver.currentRound.reference}</em>}</span>
  </button>;
}

function ExceptionDrawer({ item, accessToken, tenant, onCommunications, onResolved }: { item: OperationsActionException; accessToken?: string; tenant: OperationsTenant; onCommunications: (threadId?: string) => void; onResolved: () => void }) {
  const [resolving, setResolving] = useState(false);
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [resolutionError, setResolutionError] = useState("");
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const isLocationProblem = ["wrong_pin", "wrong_entrance", "wrong_address", "cannot_find_location"].includes(item.category);
  const isEmergency = item.category === "emergency";
  const isPickupCorrection = item.stage === "pickup" && !isLocationProblem && !isEmergency;
  const canResolve = Boolean(accessToken && tenant.role !== "viewer" && item.stopState === "exception" && (
    isPickupCorrection
      ? item.roundState === "approved" || item.roundState === "loading"
      : item.category === "damaged_item" && item.roundState === "active"
  ));

  async function resolveException() {
    if (!accessToken || !canResolve || !note.trim()) return;
    setSubmitting(true); setResolutionError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/exceptions/${item.id}/${isPickupCorrection ? "resolve" : "confirm-return"}`, {
        method: "POST",
        headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json", "idempotency-key": `operations-exception:${idempotencyKey}`, "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() },
        body: JSON.stringify({ stopId: item.stopId, expectedStopVersion: item.stopVersion, ...(isPickupCorrection ? { resolution: "pickup_corrected" } : {}), note: note.trim() }),
      });
      const body = await response.json() as { status?: string; error?: { message?: string } };
      if (!response.ok || body.status !== "committed") throw new Error(body.error?.message ?? `Resolution HTTP ${response.status}`);
      onResolved();
    } catch (caught) { setResolutionError(caught instanceof Error ? caught.message : "Exception could not be resolved"); }
    finally { setSubmitting(false); }
  }

  return <><section className="v45-decision"><small>{isEmergency ? "PRIORITY SAFETY EVENT" : "NEXT DECISION"}</small><h3>Review {exceptionLabels[item.category].toLowerCase()} report.</h3><p>{item.note || (isLocationProblem ? "The driver reported a location problem without an additional note." : "The driver reported an item problem without an additional note.")}</p><div><span><small>Stage</small><b>{item.stage}</b></span><span><small>Reported</small><b>{shortTime(item.reportedAt, tenant.timezone)}</b></span><span><small>{isEmergency ? "Safety" : "State"}</small><b>{isEmergency ? item.emergencySafetyStatus ?? "unknown" : "Action"}</b></span></div></section><section className="v45-detail"><h4>Delivery truth <span>realtime</span></h4><dl><div><dt>Round</dt><dd>{item.roundReference}</dd></div><div><dt>Driver</dt><dd>{item.driverName}</dd></div><div><dt>Stop</dt><dd>{item.stopSequence} · {item.stopState} · v{item.stopVersion}</dd></div><div><dt>Manifest</dt><dd>Version {item.manifestVersion}</dd></div>{(isLocationProblem || isEmergency) && <><div><dt>{isEmergency ? "Emergency location" : item.stage === "pickup" ? "Authoritative pickup location" : "Authoritative destination"}</dt><dd>{item.observedCoordinate ? `${item.observedCoordinate.latitude.toFixed(6)}, ${item.observedCoordinate.longitude.toFixed(6)}${item.observedAccuracyMeters != null ? ` · ±${Math.round(item.observedAccuracyMeters)} m` : ""}` : isEmergency ? "No GPS evidence attached" : item.rawAddress}</dd></div>{isLocationProblem && <div><dt>Driver observation</dt><dd>{item.observedCoordinate ? `${item.observedCoordinate.latitude.toFixed(6)}, ${item.observedCoordinate.longitude.toFixed(6)}${item.observedAccuracyMeters != null ? ` · ±${Math.round(item.observedAccuracyMeters)} m` : ""}` : "No GPS evidence attached"}</dd></div>}</>}</dl></section>{resolving && <section className="v45-resolution"><small>AUDITED RESOLUTION</small><h4>{isPickupCorrection ? "Confirm the pickup issue is corrected" : "Confirm the damaged item was returned"}</h4><p>{isPickupCorrection ? <>This releases the Stop back to <b>Assigned</b>. The driver must physically re-check the manifest before custody transfers.</> : <>Use this only after UrbanFlowers physically receives the item. The original delivery becomes <b>Returned</b> and its delivery Stop closes without POD.</>}</p><label>Operations evidence note<textarea autoFocus value={note} maxLength={500} onChange={(event) => setNote(event.target.value)} placeholder={isPickupCorrection ? "What was corrected, checked, and by whom?" : "Who returned the item, who received it, and where?"} /></label>{resolutionError && <div role="alert">{resolutionError}</div>}<div><button type="button" onClick={() => { setResolving(false); setResolutionError(""); }}>Cancel</button><button type="button" className="primary" disabled={submitting || !note.trim()} onClick={() => void resolveException()}>{submitting ? "Committing…" : isPickupCorrection ? "Confirm corrected & resume pickup" : "Confirm physical return"}</button></div></section>}<div className="v45-drawer-actions">{!resolving && canResolve && <button className="primary" type="button" onClick={() => setResolving(true)}>{isPickupCorrection ? "Resolve corrected pickup" : "Confirm returned item"}</button>}<button disabled={!item.operationsThreadId} onClick={() => onCommunications(item.operationsThreadId)}>Message driver</button>{!canResolve && <small>{tenant.role === "viewer" ? "Viewer access is read-only." : isEmergency ? "Emergency hold is protected. Resolution and reassignment require the approved safety escalation policy." : isLocationProblem ? "Location changes remain blocked until Operations correction and Driver acknowledgement policy is approved." : item.stage === "delivery" && item.category !== "damaged_item" ? "This delivery exception needs a different explicit outcome." : "Refresh before resolving this Stop."}</small>}</div></>;
}

function RoundDrawer({ item, onCommunications, onOpen }: { item: OperationsRoundSummary; onCommunications: (threadId?: string) => void; onOpen: () => void }) {
  return <><section className="v45-decision"><small>ROUND STATUS</small><h3>{item.state === "active" ? "Round is moving." : item.state === "complete" ? "Round completed." : "Round is ready for execution."}</h3><p>Dispatch sees the same server-authoritative operational state produced by the driver app.</p><div><span><small>Stops</small><b>{item.stopCount}</b></span><span><small>Custody</small><b>{item.custodyStopCount}</b></span><span><small>Action</small><b>{item.openExceptionCount}</b></span></div></section><section className="v45-detail"><h4>Assignment <span>live</span></h4><dl><div><dt>Driver</dt><dd>{item.driverName}</dd></div><div><dt>Service date</dt><dd>{item.serviceDate}</dd></div><div><dt>State</dt><dd>{item.state}</dd></div></dl></section><div className="v45-drawer-actions"><button className="primary" onClick={onOpen}>Open Round details</button><button onClick={() => onCommunications()}>Open communications</button></div></>;
}

function PlanningDrawer({ item, timezone, selected, onToggle, onInspect }: { item: UnplannedDeliverySummary; timezone: string; selected: boolean; onToggle: () => void; onInspect: () => void }) {
  return <><section className="v45-decision"><small>PLAN INPUT</small><h3>Ready to place into a physical Round.</h3><p>Rounds will compare the delivery window, pickup, driver shift, vehicle and cargo limits before approval.</p><div><span><small>Window</small><b>{shortTime(item.windowStart, timezone)}</b></span><span><small>Service</small><b>{item.serviceDate}</b></span><span><small>State</small><b>{selected ? "Proposed" : "Ready"}</b></span></div></section><section className="v45-detail"><h4>Delivery <span>unplanned</span></h4><dl><div><dt>Reference</dt><dd>#{item.reference}</dd></div><div><dt>Destination</dt><dd>{item.rawAddress}</dd></div><div><dt>Manifest</dt><dd>{item.manifestSummary}</dd></div></dl></section><div className="v45-drawer-actions"><button className="primary" type="button" onClick={onToggle}>{selected ? "Remove from proposed Round" : "Add to proposed Round"}</button>{item.coordinate && <button type="button" onClick={onInspect}>Inspect destination on map</button>}</div></>;
}

type DeliveryEditDraft = {
  recipientName: string;
  recipientPhone: string;
  rawAddress: string;
  latitude: string;
  longitude: string;
  accessNote: string;
  deliveryNote: string;
  windowStart: string;
  windowEnd: string;
  manifestItems: Array<PrePickupDeliveryManifestItem & { quantityText: string }>;
};

function deliveryEditDraft(item: OperationsDeliveryItem, timezone: string): DeliveryEditDraft {
  return {
    recipientName: item.recipientName,
    recipientPhone: item.recipientPhone,
    rawAddress: item.rawAddress,
    latitude: item.coordinate ? String(item.coordinate.latitude) : "",
    longitude: item.coordinate ? String(item.coordinate.longitude) : "",
    accessNote: item.accessNote ?? "",
    deliveryNote: item.deliveryNote ?? "",
    windowStart: tenantLocalDateTimeInput(item.promise.windowStart, timezone),
    windowEnd: tenantLocalDateTimeInput(item.promise.windowEnd, timezone),
    manifestItems: item.manifest.items.map((manifestItem) => ({ ...manifestItem, quantityText: String(manifestItem.quantity) })),
  };
}

function DeliveryRecordDrawer({ item, accessToken, tenant, onPlan, onOpenRound, onHistory, onInspect, onUpdated }: { item: OperationsDeliveryItem; accessToken?: string; tenant: OperationsTenant; onPlan: () => void; onOpenRound: () => void; onHistory: () => void; onInspect: () => void; onUpdated: () => void }) {
  const boundary = deliveryCommandBoundary(item);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState<DeliveryEditDraft>(() => deliveryEditDraft(item, tenant.timezone));
  const [preview, setPreview] = useState<PrePickupDeliveryEditPreview | null>(null);
  const [busy, setBusy] = useState(false);
  const [editError, setEditError] = useState("");
  const [pinPickerOpen, setPinPickerOpen] = useState(false);
  const idempotencyKey = useRef(crypto.randomUUID());
  const canEdit = Boolean(accessToken && tenant.role !== "viewer" && item.coordinate && item.manifest.state === "draft" && (boundary === "plan" || boundary === "round-pre-custody"));

  function updateDraft<K extends keyof DeliveryEditDraft>(key: K, value: DeliveryEditDraft[K]) {
    setDraft((current) => ({ ...current, [key]: value }));
    setPreview(null); setEditError("");
  }

  function editRequest(): PrePickupDeliveryEditRequest {
    const latitude = Number(draft.latitude);
    const longitude = Number(draft.longitude);
    if (!draft.recipientName.trim() || !draft.recipientPhone.trim()) throw new Error("Recipient name and phone are required.");
    if (!draft.rawAddress.trim()) throw new Error("Delivery address is required.");
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) throw new Error("Confirm a valid destination pin on the map.");
    const windowStart = tenantLocalDateTimeToIso(draft.windowStart, tenant.timezone);
    const windowEnd = tenantLocalDateTimeToIso(draft.windowEnd, tenant.timezone);
    if (Date.parse(windowEnd) <= Date.parse(windowStart)) throw new Error("Enter a valid promised delivery window.");
    const manifestItems = draft.manifestItems.map((manifestItem, index) => {
      const quantity = Number(manifestItem.quantityText);
      if (!manifestItem.description.trim()) throw new Error(`Manifest line ${index + 1} needs an item name.`);
      if (!Number.isInteger(quantity) || quantity < 1) throw new Error(`Manifest line ${index + 1} needs a positive whole quantity.`);
      return { lineNumber: index + 1, description: manifestItem.description.trim(), quantity, ...(manifestItem.cargoClass ? { cargoClass: manifestItem.cargoClass } : {}), ...(manifestItem.handlingNote?.trim() ? { handlingNote: manifestItem.handlingNote.trim() } : {}) };
    });
    return {
      deliveryId: item.deliveryId,
      expectedDeliveryVersion: item.version,
      expectedStopVersion: item.stop.version,
      expectedDestinationVersion: item.stop.destinationVersion,
      expectedManifestVersion: item.manifest.version,
      ...(item.round ? { expectedRoundVersion: item.round.version } : {}),
      changes: {
        recipientName: draft.recipientName.trim(), recipientPhone: draft.recipientPhone.trim(), rawAddress: draft.rawAddress.trim(), latitude, longitude,
        accessNote: draft.accessNote.trim(), deliveryNote: draft.deliveryNote.trim(), windowStart, windowEnd, manifestItems,
      },
    };
  }

  async function previewEdit() {
    if (!accessToken) return;
    setBusy(true); setEditError(""); setPreview(null);
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/delivery-edits/preview`, {
        method: "POST", headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json", "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() }, body: JSON.stringify(editRequest()),
      });
      const body = await response.json() as PrePickupDeliveryEditPreview | ApiError;
      if (!response.ok) throw new Error((body as ApiError).error?.message ?? `Preview HTTP ${response.status}`);
      setPreview(body as PrePickupDeliveryEditPreview);
    } catch (caught) { setEditError(caught instanceof Error ? caught.message : "Delivery edit could not be reviewed"); }
    finally { setBusy(false); }
  }

  async function applyEdit() {
    if (!accessToken || !preview?.applicable) return;
    setBusy(true); setEditError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/delivery-edits`, {
        method: "POST", headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json", "idempotency-key": `delivery-edit:${idempotencyKey.current}`, "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() }, body: JSON.stringify(editRequest()),
      });
      const body = await response.json() as { status?: string; error?: { message?: string } };
      if (!response.ok || body.status !== "committed") throw new Error(body.error?.message ?? `Apply HTTP ${response.status}`);
      onUpdated();
    } catch (caught) { setEditError(caught instanceof Error ? caught.message : "Delivery edit could not be committed"); }
    finally { setBusy(false); }
  }

  if (editing) return <><section className="v45-delivery-editor">
    <div className="v45-editor-heading"><small>BEFORE PICKUP · AUDITED EDIT</small><h3>Edit delivery</h3><p>{item.round ? "Rounds checks the assigned route, promised arrivals and vehicle capacity before any affected plan can be saved." : "This delivery is not assigned. The saved truth will be used by the route and capacity check when it enters a Round."}</p></div>
    <div className="v45-editor-grid"><label>Recipient name<input autoFocus value={draft.recipientName} onChange={(event) => updateDraft("recipientName", event.target.value)} /></label><label>Recipient phone<input type="tel" value={draft.recipientPhone} onChange={(event) => updateDraft("recipientPhone", event.target.value)} /></label></div>
    <label>Delivery address<textarea rows={3} value={draft.rawAddress} onChange={(event) => updateDraft("rawAddress", event.target.value)} /></label>
    <div className="v45-editor-pin"><span><b>Operational destination pin</b><small>{draft.latitude && draft.longitude ? `${Number(draft.latitude).toFixed(5)}, ${Number(draft.longitude).toFixed(5)}` : "A confirmed pin is required"}</small></span><button type="button" onClick={() => setPinPickerOpen(true)}>Adjust pin</button></div>
    <label>Entrance / access note<input value={draft.accessNote} onChange={(event) => updateDraft("accessNote", event.target.value)} /></label>
    <div className="v45-editor-grid"><label>Window starts<input type="datetime-local" value={draft.windowStart} onChange={(event) => updateDraft("windowStart", event.target.value)} /></label><label>Window ends<input type="datetime-local" value={draft.windowEnd} onChange={(event) => updateDraft("windowEnd", event.target.value)} /></label></div>
    <div className="v45-editor-manifest"><header><span><small>PHYSICAL MANIFEST</small><b>Items carried by the Driver</b></span><button type="button" onClick={() => updateDraft("manifestItems", [...draft.manifestItems, { lineNumber: draft.manifestItems.length + 1, description: "", quantity: 1, quantityText: "1" }])}>+ Add item</button></header>{draft.manifestItems.map((manifestItem, index) => <article key={index}><b>{String(index + 1).padStart(2, "0")}</b><label>Item<input value={manifestItem.description} onChange={(event) => updateDraft("manifestItems", draft.manifestItems.map((entry, entryIndex) => entryIndex === index ? { ...entry, description: event.target.value } : entry))} /></label><label>Qty<input type="number" min="1" value={manifestItem.quantityText} onChange={(event) => updateDraft("manifestItems", draft.manifestItems.map((entry, entryIndex) => entryIndex === index ? { ...entry, quantityText: event.target.value } : entry))} /></label><label>Handling<input value={manifestItem.handlingNote ?? ""} onChange={(event) => updateDraft("manifestItems", draft.manifestItems.map((entry, entryIndex) => entryIndex === index ? { ...entry, handlingNote: event.target.value } : entry))} /></label><button type="button" disabled={draft.manifestItems.length === 1} aria-label={`Remove manifest line ${index + 1}`} onClick={() => updateDraft("manifestItems", draft.manifestItems.filter((_, entryIndex) => entryIndex !== index))}>×</button></article>)}</div>
    <label>Delivery instruction<textarea rows={2} value={draft.deliveryNote} onChange={(event) => updateDraft("deliveryNote", event.target.value)} /></label>
    {editError && <div className="v45-editor-error" role="alert">{editError}</div>}
    {preview && <section className={`v45-editor-preview ${preview.applicable ? "fit" : "blocked"}`}><small>{preview.applicable ? "SAFE TO COMMIT" : "EDIT BLOCKED"}</small><h4>{preview.changedFields.length} field group{preview.changedFields.length === 1 ? "" : "s"} changed</h4><p>{preview.changedFields.map((field) => ({ recipientName: "recipient name", recipientPhone: "recipient phone", rawAddress: "address", latitude: "map pin", longitude: "map pin", accessNote: "access note", deliveryNote: "delivery instruction", windowStart: "window start", windowEnd: "window end", manifestItems: "physical manifest" })[field as "recipientName"] ?? field).filter((field, index, list) => list.indexOf(field) === index).join(" · ")}</p><p>{preview.blockingReasons[0] ?? (preview.impact.routeRecalculated ? `Route recalculated · ${preview.impact.capacityStatus} capacity · ${preview.impact.promiseStatus} promise.` : item.round ? "The current assigned route and capacity remain valid." : "Unplanned delivery · no route or assignment changes yet.")}</p>{preview.impact.routeRecalculated && <dl><div><dt>Distance</dt><dd>{preview.impact.distanceDeltaMeters && preview.impact.distanceDeltaMeters > 0 ? "+" : ""}{((preview.impact.distanceDeltaMeters ?? 0) / 1000).toFixed(1)} km</dd></div><div><dt>Road time</dt><dd>{preview.impact.durationDeltaSeconds && preview.impact.durationDeltaSeconds > 0 ? "+" : ""}{Math.round((preview.impact.durationDeltaSeconds ?? 0) / 60)} min</dd></div><div><dt>Capacity</dt><dd>{preview.impact.capacityStatus}</dd></div></dl>}</section>}
    <div className="v45-editor-actions"><button type="button" disabled={busy} onClick={() => { setEditing(false); setPreview(null); setEditError(""); }}>Cancel</button>{preview?.applicable ? <button className="primary" type="button" disabled={busy} onClick={() => void applyEdit()}>{busy ? "Saving…" : "Save delivery"}</button> : <button className="primary" type="button" disabled={busy} onClick={() => void previewEdit()}>{busy ? "Checking consequences…" : "Review changes"}</button>}</div>
  </section>{pinPickerOpen && item.coordinate && <DestinationPinPicker mode="change" initial={{ latitude: Number(draft.latitude) || item.coordinate.latitude, longitude: Number(draft.longitude) || item.coordinate.longitude }} onCancel={() => setPinPickerOpen(false)} onConfirm={(coordinate) => { updateDraft("latitude", String(coordinate.latitude)); updateDraft("longitude", String(coordinate.longitude)); setPinPickerOpen(false); }} />}</>;

  const copy = boundary === "plan"
    ? { label: "READY TO PLAN", title: "Place this delivery into a physical Round.", detail: "The saved destination, promise and manifest will be checked against driver, vehicle and route capacity before approval." }
    : boundary === "round-pre-custody"
      ? { label: "BEFORE PICKUP", title: "Pickup has not transferred custody.", detail: "Open the assigned Round to review this Stop or move it through the protected planning workflow." }
      : boundary === "round-live"
        ? { label: "LIVE DELIVERY", title: "Custody is active.", detail: "Open the exact Stop for live status, communication and the consequence-preview change workflow." }
        : boundary === "history"
          ? { label: "COMMITTED RECORD", title: "Execution is closed.", detail: "The delivery and physical manifest are read-only. History holds the committed outcome and evidence." }
          : { label: "NEEDS ACTION", title: "An Operations decision is required.", detail: "Use the Action queue to resolve the current exception against the latest Stop version." };
  const manifestLocked = item.manifest.state !== "draft" || boundary === "round-live" || boundary === "history";

  return <><section className="v45-decision"><small>{copy.label}</small><h3>{copy.title}</h3><p>{copy.detail}</p><div><span><small>Promise</small><b>{shortTime(item.promise.windowStart, tenant.timezone)}–{shortTime(item.promise.windowEnd, tenant.timezone)}</b></span><span><small>Stop</small><b>{item.round ? `${item.round.sequence} of ${item.round.reference}` : "Unplanned"}</b></span><span><small>State</small><b>{deliveryStateLabel(item.state)}</b></span></div></section>
    <section className="v45-detail"><h4>Delivery truth <span>v{item.version}</span></h4><dl><div><dt>Recipient</dt><dd>{item.recipientName}<small>{item.recipientPhone}</small></dd></div><div><dt>Destination</dt><dd>{item.rawAddress}{item.accessNote && <small>{item.accessNote}</small>}</dd></div><div><dt>Pickup</dt><dd>{item.pickupLocationName}</dd></div><div><dt>Service date</dt><dd>{item.serviceDate}</dd></div>{item.round && <><div><dt>Round</dt><dd>{item.round.reference}<small>{item.round.driverName}</small></dd></div><div><dt>Stop version</dt><dd>v{item.stop.version}</dd></div></>}</dl></section>
    <section className="v45-detail v45-record-manifest"><h4>Physical manifest <span>{manifestLocked ? "locked" : "draft"} · v{item.manifest.version}</span></h4>{item.manifest.items.map((manifestItem) => <article key={manifestItem.lineNumber}><b>{String(manifestItem.lineNumber).padStart(2, "0")}</b><span><strong>{manifestItem.description}</strong>{manifestItem.handlingNote && <small>{manifestItem.handlingNote}</small>}</span><em>×{manifestItem.quantity}</em></article>)}{item.deliveryNote && <p><b>Instruction</b>{item.deliveryNote}</p>}</section>
    <div className="v45-drawer-actions">{canEdit && <button className="primary" type="button" onClick={() => setEditing(true)}>Edit delivery</button>}{boundary === "plan" && <button type="button" onClick={onPlan}>Open in planning</button>}{(boundary === "round-pre-custody" || boundary === "round-live") && <button className={canEdit ? "" : "primary"} type="button" onClick={onOpenRound}>{boundary === "round-live" ? "Open live Stop" : "Open assigned Round"}</button>}{boundary === "history" && <button className="primary" type="button" onClick={onHistory}>Open delivery history</button>}{item.coordinate && <button type="button" onClick={onInspect}>Inspect destination on map</button>}<button type="button" onClick={() => void navigator.clipboard.writeText(item.deliveryId)}>Copy delivery ID</button></div>
  </>;
}

function SearchIcon() { return <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>; }
function MessageIcon() { return <svg viewBox="0 0 24 24"><path d="M4 5h16v11H8l-4 4z"/><path d="M8 9h8M8 12h5"/></svg>; }
function BellIcon() { return <svg viewBox="0 0 24 24"><path d="M15 17h5l-1.4-1.4A2 2 0 0 1 18 14.2V11a6 6 0 1 0-12 0v3.2a2 2 0 0 1-.6 1.4L4 17h5"/><path d="M10 17a2 2 0 0 0 4 0"/></svg>; }
function UserIcon() { return <svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>; }
function ChevronIcon() { return <svg viewBox="0 0 24 24"><path d="m9 18 6-6-6-6"/></svg>; }
function CloseIcon() { return <svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18"/></svg>; }
function FocusIcon() { return <svg viewBox="0 0 24 24"><path d="M8 3H3v5M16 3h5v5M21 16v5h-5M3 16v5h5"/></svg>; }
