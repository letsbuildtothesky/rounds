"use client";

import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from "react";
import mapboxgl, { type LngLatLike, type Map as MapboxMap } from "mapbox-gl";
import type { OperationsActionException, OperationsLiveRoundMapProjection, OperationsMapStop, OperationsRoundSummary, UnplannedDeliverySummary } from "@rounds/contracts";
import type { RoundCommunicationUnreadState } from "../src/operations-communications-state";
import { operationsMapDriverMarkers } from "../src/operations-map-driver-markers";
import { operationsMapStopMarkers } from "../src/operations-map-stops";

export type OperationsMapMode = "operations" | "satellite" | "site" | "street";
export type OperationsMapCamera = { bearing: number; pitch: number };
export type OperationsMapControl = "focus" | "zoom-in" | "zoom-out" | "rotate-left" | "rotate-right" | "north" | "pitch-2d" | "pitch-3d";
export type OperationsMapHandle = {
  control: (action: OperationsMapControl) => void;
  focusPosition: (position: { latitude: number; longitude: number }) => void;
};

type Props = {
  mode: "live" | "plan";
  mapMode: OperationsMapMode;
  rounds: OperationsRoundSummary[];
  mapStops: OperationsMapStop[];
  exceptions: OperationsActionException[];
  planningDeliveries: UnplannedDeliverySummary[];
  routeGeometry?: { type: "LineString"; coordinates: [number, number][] };
  liveMapProjections: OperationsLiveRoundMapProjection[];
  communicationUnreadByRound: Record<string, RoundCommunicationUnreadState>;
  onCameraChange: (camera: OperationsMapCamera) => void;
  onSelectRound: (round: OperationsRoundSummary) => void;
  onSelectStop: (round: OperationsRoundSummary, stop: OperationsMapStop) => void;
  onOpenDriverMenu: (round: OperationsRoundSummary, position: { latitude: number; longitude: number }, point: { x: number; y: number }) => void;
  onSelectException: (exception: OperationsActionException) => void;
  onSelectDelivery: (delivery: UnplannedDeliverySummary) => void;
};

const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN ?? "";
const bangkokCenter: [number, number] = [100.5598, 13.735];

function initials(name: string): string {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "DR";
}

function styleForMode(mode: OperationsMapMode): string {
  return mode === "satellite"
    ? "mapbox://styles/mapbox/standard-satellite"
    : "mapbox://styles/mapbox/standard";
}

function styleConfig(mode: OperationsMapMode) {
  return {
    basemap: {
      theme: mode === "satellite" ? "default" : "faded",
      lightPreset: "day",
      showPointOfInterestLabels: false,
      showTransitLabels: false,
      showPedestrianRoads: false,
      show3dObjects: mode === "site",
      showPlaceLabels: true,
      showRoadLabels: true,
      showAdminBoundaries: false,
    },
  };
}

export const OperationsMap = forwardRef<OperationsMapHandle, Props>(function OperationsMap({ mode, mapMode, rounds, mapStops, exceptions, planningDeliveries, routeGeometry, liveMapProjections, communicationUnreadByRound, onCameraChange, onSelectRound, onSelectStop, onOpenDriverMenu, onSelectException, onSelectDelivery }, ref) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapboxMap | null>(null);
  const markersRef = useRef<mapboxgl.Marker[]>([]);
  const boundsRef = useRef<mapboxgl.LngLatBounds | null>(null);
  const appliedModeRef = useRef<OperationsMapMode>("operations");
  const callbacksRef = useRef({ onCameraChange, onSelectRound, onSelectStop, onOpenDriverMenu, onSelectException, onSelectDelivery });
  const [state, setState] = useState<"loading" | "ready" | "error">(token ? "loading" : "error");

  callbacksRef.current = { onCameraChange, onSelectRound, onSelectStop, onOpenDriverMenu, onSelectException, onSelectDelivery };

  useImperativeHandle(ref, () => ({
    control(action) {
      const map = mapRef.current;
      if (!map) return;
      if (action === "zoom-in") map.zoomIn({ duration: 180 });
      if (action === "zoom-out") map.zoomOut({ duration: 180 });
      if (action === "rotate-left") {
        const bearing = map.getBearing() - 20;
        map.easeTo({ bearing, duration: 220 });
        callbacksRef.current.onCameraChange({ bearing, pitch: map.getPitch() });
      }
      if (action === "rotate-right") {
        const bearing = map.getBearing() + 20;
        map.easeTo({ bearing, duration: 220 });
        callbacksRef.current.onCameraChange({ bearing, pitch: map.getPitch() });
      }
      if (action === "north") {
        map.easeTo({ bearing: 0, duration: 300 });
        callbacksRef.current.onCameraChange({ bearing: 0, pitch: map.getPitch() });
      }
      if (action === "pitch-2d" || action === "pitch-3d") {
        const pitch = action === "pitch-2d" ? 0 : 52;
        map.easeTo({ pitch, duration: 350 });
        callbacksRef.current.onCameraChange({ bearing: map.getBearing(), pitch });
      }
      if (action === "focus") {
        if (boundsRef.current) map.fitBounds(boundsRef.current, { padding: { top: 95, right: 90, bottom: 80, left: 90 }, maxZoom: 14.5, duration: 500 });
        else map.easeTo({ center: bangkokCenter as LngLatLike, zoom: 12.55, pitch: 0, bearing: 0, duration: 450 });
      }
    },
    focusPosition(position) {
      const map = mapRef.current;
      if (!map) return;
      map.easeTo({ center: [position.longitude, position.latitude], zoom: 15.25, pitch: 0, bearing: 0, duration: 520 });
      callbacksRef.current.onCameraChange({ bearing: 0, pitch: 0 });
    },
  }), []);

  useEffect(() => {
    if (!containerRef.current || !token || mapRef.current) return;
    mapboxgl.accessToken = token;
    let map: MapboxMap;
    try {
      map = new mapboxgl.Map({
        container: containerRef.current,
        accessToken: token,
        style: styleForMode("operations"),
        center: bangkokCenter,
        zoom: 12.55,
        pitch: 0,
        bearing: 0,
        minZoom: 10,
        maxZoom: 19,
        logoPosition: "bottom-left",
        config: styleConfig("operations"),
      });
    } catch {
      setState("error");
      return;
    }
    mapRef.current = map;
    const publishCamera = () => callbacksRef.current.onCameraChange({ bearing: map.getBearing(), pitch: map.getPitch() });
    map.on("moveend", publishCamera);
    map.on("load", () => {
      setState("ready");
      publishCamera();
    });
    map.on("error", () => { if (!map.loaded()) setState("error"); });
    return () => {
      markersRef.current.forEach((marker) => marker.remove());
      markersRef.current = [];
      map.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || state !== "ready" || appliedModeRef.current === mapMode) return;
    appliedModeRef.current = mapMode;
    setState("loading");
    map.setStyle(styleForMode(mapMode), {
      config: styleConfig(mapMode),
      localFontFamily: undefined,
      localIdeographFontFamily: undefined,
    });
    map.once("idle", () => setState("ready"));
  }, [mapMode, state]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || state !== "ready" || !map.isStyleLoaded()) return;
    const sourceId = "rounds-proposed-route";
    const source = map.getSource(sourceId) as mapboxgl.GeoJSONSource | undefined;
    const data = { type: "Feature" as const, properties: {}, geometry: routeGeometry ?? { type: "LineString" as const, coordinates: [] } };
    if (source) source.setData(data);
    else {
      map.addSource(sourceId, { type: "geojson", data });
      map.addLayer({ id: "rounds-proposed-route-casing", type: "line", source: sourceId, paint: { "line-color": "#ffffff", "line-width": 8, "line-opacity": 0.9 } });
      map.addLayer({ id: "rounds-proposed-route", type: "line", source: sourceId, paint: { "line-color": "#f4511e", "line-width": 5, "line-opacity": 0.95, "line-dasharray": [1.2, 0.6] } });
    }
  }, [mapMode, routeGeometry, state]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || state !== "ready" || !map.isStyleLoaded()) return;
    const remainingRouteData = {
      type: "FeatureCollection" as const,
      features: liveMapProjections.flatMap((item) => item.remainingRoute ? [{
        type: "Feature" as const,
        properties: { roundId: item.roundId, kind: item.remainingRoute.kind },
        geometry: item.remainingRoute.geometry,
      }] : []),
    };
    const actualTrailData = {
      type: "FeatureCollection" as const,
      features: liveMapProjections.flatMap((item) => item.actualTrail ? [{
        type: "Feature" as const,
        properties: { roundId: item.roundId, kind: item.actualTrail.source, truncated: item.actualTrail.truncated },
        geometry: item.actualTrail.geometry,
      }] : []),
    };
    const remainingSource = map.getSource("rounds-remaining-routes") as mapboxgl.GeoJSONSource | undefined;
    if (remainingSource) remainingSource.setData(remainingRouteData);
    else {
      map.addSource("rounds-remaining-routes", { type: "geojson", data: remainingRouteData });
      map.addLayer({ id: "rounds-remaining-routes-casing", type: "line", source: "rounds-remaining-routes", layout: { "line-cap": "round", "line-join": "round" }, paint: { "line-color": "#ffffff", "line-width": 9, "line-opacity": 0.88 } });
      map.addLayer({ id: "rounds-remaining-routes", type: "line", source: "rounds-remaining-routes", layout: { "line-cap": "round", "line-join": "round" }, paint: { "line-color": "#17233b", "line-width": 5, "line-opacity": 0.94 } });
    }
    const trailSource = map.getSource("rounds-actual-trails") as mapboxgl.GeoJSONSource | undefined;
    if (trailSource) trailSource.setData(actualTrailData);
    else {
      map.addSource("rounds-actual-trails", { type: "geojson", data: actualTrailData });
      map.addLayer({ id: "rounds-actual-trails-casing", type: "line", source: "rounds-actual-trails", layout: { "line-cap": "round", "line-join": "round" }, paint: { "line-color": "#ffffff", "line-width": 6, "line-opacity": 0.72 } });
      map.addLayer({ id: "rounds-actual-trails", type: "line", source: "rounds-actual-trails", layout: { "line-cap": "round", "line-join": "round" }, paint: { "line-color": "#12805c", "line-width": 3.25, "line-opacity": 0.96 } });
    }
  }, [liveMapProjections, mapMode, state]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || state !== "ready" || !map.isStyleLoaded()) return;
    markersRef.current.forEach((marker) => marker.remove());
    markersRef.current = [];

    const coordinates: Array<[number, number]> = [];
    operationsMapDriverMarkers(rounds).forEach(({ round, roundIds, position }) => {
      const coordinate: [number, number] = [position.longitude, position.latitude];
      coordinates.push(coordinate);
      const element = document.createElement("button");
      element.type = "button";
      element.className = "v45-mapbox-driver";
      element.textContent = initials(round.driverName);
      const unread = roundIds.reduce<{ count: number; hasVoice: boolean }>((total, roundId) => {
        const current = communicationUnreadByRound[roundId];
        return { count: total.count + (current?.count ?? 0), hasVoice: total.hasVoice || Boolean(current?.hasVoice) };
      }, { count: 0, hasVoice: false });
      if (unread.count) {
        const badge = document.createElement("i");
        badge.className = unread.hasVoice ? "voice" : "";
        badge.textContent = unread.hasVoice ? "●" : String(unread.count);
        badge.setAttribute("aria-hidden", "true");
        element.appendChild(badge);
      }
      const roundContext = roundIds.length > 1 ? `${round.reference} · ${roundIds.length} Rounds on board` : round.reference;
      element.title = `${round.driverName} · ${roundContext} · ${new Date(position.capturedAt).toLocaleTimeString()}${unread.count ? ` · ${unread.count} unread${unread.hasVoice ? " including voice" : ""}` : ""}`;
      element.setAttribute("aria-label", element.title);
      let longPressTimer: number | undefined;
      let longPressed = false;
      const openMenu = (clientX: number, clientY: number) => {
        const bounds = containerRef.current?.getBoundingClientRect();
        callbacksRef.current.onOpenDriverMenu(round, position, {
          x: clientX - (bounds?.left ?? 0),
          y: clientY - (bounds?.top ?? 0),
        });
      };
      const cancelLongPress = () => {
        if (longPressTimer != null) window.clearTimeout(longPressTimer);
        longPressTimer = undefined;
      };
      element.addEventListener("click", (event) => {
        event.stopPropagation();
        if (longPressed) {
          longPressed = false;
          return;
        }
        callbacksRef.current.onSelectRound(round);
      });
      element.addEventListener("contextmenu", (event) => {
        event.preventDefault();
        event.stopPropagation();
        openMenu(event.clientX, event.clientY);
      });
      element.addEventListener("pointerdown", (event) => {
        if (event.pointerType === "mouse") return;
        cancelLongPress();
        longPressTimer = window.setTimeout(() => {
          longPressed = true;
          openMenu(event.clientX, event.clientY);
          navigator.vibrate?.(12);
        }, 520);
      });
      element.addEventListener("pointerup", cancelLongPress);
      element.addEventListener("pointercancel", cancelLongPress);
      element.addEventListener("pointermove", cancelLongPress);
      markersRef.current.push(new mapboxgl.Marker({ element }).setLngLat(coordinate).addTo(map));
    });

    const visibleStopMarkers = mode === "live" ? operationsMapStopMarkers(mapStops, rounds) : [];
    const exceptionByStop = new Map(exceptions.map((exception) => [exception.stopId, exception]));
    visibleStopMarkers.forEach(({ stop, round, emphasis }) => {
      const coordinate: [number, number] = [stop.coordinate.longitude, stop.coordinate.latitude];
      coordinates.push(coordinate);
      const exception = exceptionByStop.get(stop.stopId);
      const element = document.createElement("button");
      element.type = "button";
      element.className = `v45-mapbox-stop ${emphasis}${exception ? " action" : ""}`;
      element.textContent = String(stop.sequence);
      element.title = `${round.reference} · Stop ${stop.sequence} · #${stop.deliveryReference} · ${stop.recipientName}${exception ? " · Needs action" : ""}`;
      element.setAttribute("aria-label", element.title);
      element.addEventListener("click", (event) => {
        event.stopPropagation();
        if (exception) callbacksRef.current.onSelectException(exception);
        else callbacksRef.current.onSelectStop(round, stop);
      });
      markersRef.current.push(new mapboxgl.Marker({ element }).setLngLat(coordinate).addTo(map));
    });

    const mappedStopIds = new Set(visibleStopMarkers.map(({ stop }) => stop.stopId));
    const deliveries = mode === "plan" ? planningDeliveries : exceptions.filter((exception) => !mappedStopIds.has(exception.stopId));
    deliveries.forEach((item, index) => {
      if (!item.coordinate) return;
      const coordinate: [number, number] = [item.coordinate.longitude, item.coordinate.latitude];
      coordinates.push(coordinate);
      const element = document.createElement("button");
      element.type = "button";
      element.className = `v45-mapbox-stop ${mode === "plan" ? "planning" : "action"}`;
      element.textContent = String(index + 1);
      element.title = item.recipientName;
      element.setAttribute("aria-label", item.recipientName);
      element.addEventListener("click", (event) => {
        event.stopPropagation();
        if (mode === "plan") callbacksRef.current.onSelectDelivery(item as UnplannedDeliverySummary);
        else callbacksRef.current.onSelectException(item as OperationsActionException);
      });
      markersRef.current.push(new mapboxgl.Marker({ element }).setLngLat(coordinate).addTo(map));
    });

    const routeCoordinates = routeGeometry?.coordinates ?? [];
    const liveEvidenceCoordinates = liveMapProjections.flatMap((item) => [
      ...(item.remainingRoute?.geometry.coordinates ?? []),
      ...(item.actualTrail?.geometry.coordinates ?? []),
    ]);
    const focusCoordinates = routeCoordinates.length ? routeCoordinates : liveEvidenceCoordinates.length ? liveEvidenceCoordinates : coordinates;
    if (focusCoordinates.length) {
      boundsRef.current = focusCoordinates.reduce((bounds, coordinate) => bounds.extend(coordinate), new mapboxgl.LngLatBounds(focusCoordinates[0], focusCoordinates[0]));
      if (mapMode === "site") {
        const siteCoordinate = coordinates.at(-1) ?? focusCoordinates.at(-1)!;
        map.flyTo({ center: siteCoordinate, zoom: 17.2, pitch: 52, bearing: map.getBearing(), duration: 900, essential: true });
      } else if (mapMode !== "street") {
        map.fitBounds(boundsRef.current, { padding: { top: 95, right: 90, bottom: 80, left: 90 }, maxZoom: 14.5, pitch: 0, duration: 650 });
      }
    } else {
      boundsRef.current = null;
      map.easeTo({ center: bangkokCenter as LngLatLike, zoom: mapMode === "site" ? 16.5 : 12.55, pitch: mapMode === "site" ? 52 : 0, duration: 450 });
    }
  }, [communicationUnreadByRound, exceptions, liveMapProjections, mapMode, mapStops, mode, planningDeliveries, rounds, routeGeometry, state]);

  return <>
    <div className="v45-mapbox" ref={containerRef} />
    {state === "loading" && <div className="v45-mapbox-state"><b>Loading Mapbox</b><span>Preparing the selected basemap…</span></div>}
    {state === "error" && <div className="v45-mapbox-state error"><b>Map service unavailable</b><span>Dispatch remains usable; no substitute geography is drawn.</span></div>}
  </>;
});
