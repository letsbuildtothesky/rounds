"use client";

import { useEffect, useRef, useState } from "react";
import mapboxgl, { type LngLatLike, type Map as MapboxMap } from "mapbox-gl";
import type { OperationsActionException, OperationsRoundSummary, UnplannedDeliverySummary } from "@rounds/contracts";

export type OperationsMapMode = "operations" | "satellite";
export type OperationsMapCamera = { bearing: number; pitch: number };

type Props = {
  mode: "live" | "plan";
  mapMode: OperationsMapMode;
  rounds: OperationsRoundSummary[];
  exceptions: OperationsActionException[];
  planningDeliveries: UnplannedDeliverySummary[];
  routeGeometry?: { type: "LineString"; coordinates: [number, number][] };
  onCameraChange: (camera: OperationsMapCamera) => void;
  onSelectRound: (round: OperationsRoundSummary) => void;
  onSelectException: (exception: OperationsActionException) => void;
  onSelectDelivery: (delivery: UnplannedDeliverySummary) => void;
};

type MapControl = "focus" | "zoom-in" | "zoom-out" | "rotate-left" | "rotate-right" | "north" | "toggle-pitch";

const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN ?? "";
const bangkokCenter: [number, number] = [100.5598, 13.735];

function initials(name: string): string {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "DR";
}

function styleForMode(mode: OperationsMapMode): string {
  return mode === "satellite"
    ? "mapbox://styles/mapbox/satellite-streets-v12"
    : "mapbox://styles/mapbox/light-v11";
}

export function OperationsMap({ mode, mapMode, rounds, exceptions, planningDeliveries, routeGeometry, onCameraChange, onSelectRound, onSelectException, onSelectDelivery }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapboxMap | null>(null);
  const markersRef = useRef<mapboxgl.Marker[]>([]);
  const boundsRef = useRef<mapboxgl.LngLatBounds | null>(null);
  const appliedModeRef = useRef<OperationsMapMode>("operations");
  const callbacksRef = useRef({ onCameraChange, onSelectRound, onSelectException, onSelectDelivery });
  const [state, setState] = useState<"loading" | "ready" | "error">(token ? "loading" : "error");

  callbacksRef.current = { onCameraChange, onSelectRound, onSelectException, onSelectDelivery };

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
      });
    } catch {
      setState("error");
      return;
    }
    mapRef.current = map;
    const publishCamera = () => callbacksRef.current.onCameraChange({ bearing: map.getBearing(), pitch: map.getPitch() });
    const focus = () => {
      if (boundsRef.current) map.fitBounds(boundsRef.current, { padding: { top: 95, right: 90, bottom: 80, left: 90 }, maxZoom: 14.5, duration: 500 });
      else map.easeTo({ center: bangkokCenter as LngLatLike, zoom: 12.55, pitch: 0, bearing: 0, duration: 450 });
    };
    const handleControl = (event: Event) => {
      const action = (event as CustomEvent<MapControl>).detail;
      if (action === "zoom-in") map.zoomIn({ duration: 180 });
      if (action === "zoom-out") map.zoomOut({ duration: 180 });
      if (action === "rotate-left") map.easeTo({ bearing: map.getBearing() - 20, duration: 220 });
      if (action === "rotate-right") map.easeTo({ bearing: map.getBearing() + 20, duration: 220 });
      if (action === "north") map.easeTo({ bearing: 0, duration: 300 });
      if (action === "toggle-pitch") map.easeTo({ pitch: map.getPitch() < 20 ? 52 : 0, duration: 350 });
      if (action === "focus") focus();
    };
    window.addEventListener("rounds-map-control", handleControl);
    map.on("move", publishCamera);
    map.on("load", () => {
      setState("ready");
      publishCamera();
    });
    map.on("error", () => { if (!map.loaded()) setState("error"); });
    return () => {
      markersRef.current.forEach((marker) => marker.remove());
      markersRef.current = [];
      window.removeEventListener("rounds-map-control", handleControl);
      map.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || state !== "ready" || appliedModeRef.current === mapMode) return;
    appliedModeRef.current = mapMode;
    setState("loading");
    map.setStyle(styleForMode(mapMode));
    map.once("style.load", () => setState("ready"));
  }, [mapMode, state]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || state !== "ready") return;
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
    if (!map || state !== "ready") return;
    markersRef.current.forEach((marker) => marker.remove());
    markersRef.current = [];

    const coordinates: Array<[number, number]> = [];
    rounds.forEach((round) => {
      if (!round.currentPosition) return;
      const coordinate: [number, number] = [round.currentPosition.longitude, round.currentPosition.latitude];
      coordinates.push(coordinate);
      const element = document.createElement("button");
      element.type = "button";
      element.className = "v45-mapbox-driver";
      element.textContent = initials(round.driverName);
      element.title = `${round.reference} · ${round.driverName} · ${new Date(round.currentPosition.capturedAt).toLocaleTimeString()}`;
      element.addEventListener("click", () => callbacksRef.current.onSelectRound(round));
      markersRef.current.push(new mapboxgl.Marker({ element }).setLngLat(coordinate).addTo(map));
    });

    const deliveries = mode === "plan" ? planningDeliveries : exceptions;
    deliveries.forEach((item, index) => {
      if (!item.coordinate) return;
      const coordinate: [number, number] = [item.coordinate.longitude, item.coordinate.latitude];
      coordinates.push(coordinate);
      const element = document.createElement("button");
      element.type = "button";
      element.className = "v45-mapbox-stop";
      element.textContent = String(index + 1);
      element.title = item.recipientName;
      element.addEventListener("click", () => {
        if (mode === "plan") callbacksRef.current.onSelectDelivery(item as UnplannedDeliverySummary);
        else callbacksRef.current.onSelectException(item as OperationsActionException);
      });
      markersRef.current.push(new mapboxgl.Marker({ element }).setLngLat(coordinate).addTo(map));
    });

    const routeCoordinates = routeGeometry?.coordinates ?? [];
    const focusCoordinates = routeCoordinates.length ? routeCoordinates : coordinates;
    if (focusCoordinates.length) {
      boundsRef.current = focusCoordinates.reduce((bounds, coordinate) => bounds.extend(coordinate), new mapboxgl.LngLatBounds(focusCoordinates[0], focusCoordinates[0]));
      map.fitBounds(boundsRef.current, { padding: { top: 95, right: 90, bottom: 80, left: 90 }, maxZoom: 14.5, duration: 650 });
    } else {
      boundsRef.current = null;
      map.easeTo({ center: bangkokCenter as LngLatLike, zoom: 12.55, duration: 450 });
    }
  }, [exceptions, mapMode, mode, planningDeliveries, rounds, routeGeometry, state]);

  return <>
    <div className="v45-mapbox" ref={containerRef} />
    {state === "loading" && <div className="v45-mapbox-state"><b>Loading Mapbox</b><span>Preparing the selected basemap…</span></div>}
    {state === "error" && <div className="v45-mapbox-state error"><b>Map service unavailable</b><span>Dispatch remains usable; no substitute geography is drawn.</span></div>}
  </>;
}
