import type {
  OperationsDriverCapacityItem,
  PlanningRoutePreview,
  PlanningRouteSnapshot,
  UnplannedDeliverySummary,
} from "@rounds/contracts";
import type { ActorContext, PlanningRouteContextGateway } from "./types.js";
import type { RoutingProvider } from "./routing-provider.js";

export type PlanningRouteService = {
  preview(actor: ActorContext, request: { serviceDate: string; driverId: string; stopIds: string[] }, now: Date): Promise<PlanningRoutePreview>;
};

function localServiceDate(now: Date, timezone: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: timezone }).format(now);
}

export function routeSnapshot(preview: PlanningRoutePreview): PlanningRouteSnapshot {
  const { tenantId: _tenantId, geometry: _geometry, ...snapshot } = preview;
  return snapshot;
}

export function createPlanningRouteService(
  gateway: PlanningRouteContextGateway,
  routing: RoutingProvider,
): PlanningRouteService {
  return {
    async preview(actor, request, now) {
      const context = await gateway.getPlanningRouteContext(actor, request.driverId, request.serviceDate, request.stopIds, now);
      const blockingReasons = [...context.blockingReasons];
      const warnings = [...context.warnings];
      const driver = context.driver;
      if (!driver.effectiveShift) blockingReasons.push("Driver has no effective shift for this service date.");
      if (!driver.vehicleProfile) blockingReasons.push("Driver has no active vehicle profile for this service date.");
      if (driver.vehicleProfile && context.stops.length > driver.vehicleProfile.maxStopsPerDeparture) {
        blockingReasons.push(`${driver.vehicleProfile.displayName} allows ${driver.vehicleProfile.maxStopsPerDeparture} Stops per departure.`);
      }
      if (driver.vehicleProfile?.departurePattern === "return_after_every_delivery" && context.stops.length > 1) {
        blockingReasons.push("Vehicle rules require returning to pickup after every delivery.");
      }
      if (!driver.effectiveShift || !context.pickup) {
        throw new Error(blockingReasons[0] || "Planning route context is incomplete");
      }
      const shiftStart = new Date(driver.effectiveShift.startAt);
      const shiftEnd = new Date(driver.effectiveShift.endAt);
      const departure = request.serviceDate === localServiceDate(now, context.timezone) && now > shiftStart ? now : shiftStart;
      const providerDeparture = departure.getTime() >= now.getTime() - 5_000
        ? new Date(Math.max(departure.getTime(), now.getTime() + 1_000)).toISOString()
        : undefined;
      const returnsToPickup = driver.vehicleProfile?.departurePattern === "return_after_round"
        || driver.vehicleProfile?.departurePattern === "return_after_every_delivery";
      const routed = await routing.calculate({
        coordinates: [
          context.pickup.coordinate,
          ...context.stops.map((stop) => stop.coordinate!),
          ...(returnsToPickup ? [context.pickup.coordinate] : []),
        ],
        ...(providerDeparture ? { departureAt: providerDeparture } : {}),
      });
      let cursor = departure.getTime();
      const evaluatedStops = context.stops.map((stop, index) => {
        const leg = routed.legs[index]!;
        cursor += Math.round(leg.durationSeconds * 1_000);
        const rawEta = cursor;
        const windowStart = Date.parse(stop.windowStart);
        const windowEnd = Date.parse(stop.windowEnd);
        const waitingSeconds = rawEta < windowStart ? Math.ceil((windowStart - rawEta) / 1_000) : 0;
        const latenessSeconds = rawEta > windowEnd ? Math.ceil((rawEta - windowEnd) / 1_000) : 0;
        const promiseStatus = latenessSeconds > 0 ? "late" as const : waitingSeconds > 0 ? "early" as const : "safe" as const;
        if (latenessSeconds > 0) blockingReasons.push(`Stop ${index + 1} arrives ${Math.ceil(latenessSeconds / 60)} min after its promised window.`);
        if (waitingSeconds > 0) cursor = windowStart;
        return {
          stopId: stop.stopId,
          sequence: index + 1,
          eta: new Date(rawEta).toISOString(),
          departureAt: new Date(cursor).toISOString(),
          windowStart: stop.windowStart,
          windowEnd: stop.windowEnd,
          promiseStatus,
          waitingSeconds,
          latenessSeconds,
          legDurationSeconds: Math.round(leg.durationSeconds),
          legDistanceMeters: Math.round(leg.distanceMeters),
        };
      });
      if (returnsToPickup) cursor += Math.round(routed.legs[context.stops.length]!.durationSeconds * 1_000);
      if (cursor > shiftEnd.getTime()) {
        blockingReasons.push(`The proposed Round finishes ${Math.ceil((cursor - shiftEnd.getTime()) / 60_000)} min after the driver shift.`);
      }
      if (driver.vehicleProfile?.vehicleGroup === "motorbike") {
        warnings.push("Current travel time uses Mapbox driving traffic; motorcycle-specific restrictions are not modeled.");
      }
      warnings.push("Promise fit includes routed road time and early-arrival waiting; destination handoff dwell is not configured yet.");
      if (returnsToPickup) warnings.push("Finish time includes the vehicle rule requiring a return to pickup.");
      return {
        tenantId: actor.tenantId,
        status: blockingReasons.length ? "blocked" : "fits",
        serviceDate: request.serviceDate,
        driverId: request.driverId,
        stopIds: [...request.stopIds],
        calculatedAt: now.toISOString(),
        departureAt: departure.toISOString(),
        finishAt: new Date(cursor).toISOString(),
        distanceMeters: Math.round(routed.distanceMeters),
        durationSeconds: Math.round(routed.durationSeconds),
        provider: {
          name: routed.provider,
          profile: routed.profile,
          freshness: providerDeparture ? "live" : "current_snapshot",
        },
        stops: evaluatedStops,
        blockingReasons: [...new Set(blockingReasons)],
        warnings: [...new Set(warnings)],
        geometry: routed.geometry,
      };
    },
  };
}

export type PlanningRouteContext = {
  timezone: string;
  pickup?: { id: string; coordinate: { latitude: number; longitude: number } };
  driver: OperationsDriverCapacityItem;
  stops: UnplannedDeliverySummary[];
  blockingReasons: string[];
  warnings: string[];
};
