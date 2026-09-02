"use client";

import { useEffect, useRef, useState } from "react";
import mapboxgl, { type GeoJSONSource, type LngLatLike, type Map as MapboxMap } from "mapbox-gl";
import type { OperationsActionException, OperationsRoundSummary, UnplannedDeliverySummary } from "@rounds/contracts";

export type OperationsMapMode = "operations" | "satellite" | "site" | "street";
export type OperationsMapCamera = { bearing: number; pitch: number };

type Props = {
  mode: "live" | "plan";
  mapMode: OperationsMapMode;
  weatherLayerOn: boolean;
  networkSupplyOn: boolean;
  rounds: OperationsRoundSummary[];
  exceptions: OperationsActionException[];
  planningDeliveries: UnplannedDeliverySummary[];
  onCameraChange: (camera: OperationsMapCamera) => void;
  onSelectRound: (round: OperationsRoundSummary) => void;
  onSelectException: (exception: OperationsActionException) => void;
  onSelectDelivery: (delivery: UnplannedDeliverySummary) => void;
};

type MapData = Pick<Props, "mode" | "mapMode" | "weatherLayerOn" | "networkSupplyOn" | "rounds" | "exceptions" | "planningDeliveries">;
type MapControl = "focus" | "zoom-in" | "zoom-out" | "rotate-left" | "rotate-right" | "north" | "toggle-pitch";

const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN ?? "";
const bangkokCenter: [number, number] = [100.5598, 13.735];
const siteCenter: [number, number] = [100.5663, 13.7274];
const roundPoints: Array<[number, number]> = [
  [100.5487, 13.7298],
  [100.5766, 13.7338],
  [100.5442, 13.7442],
  [100.5688, 13.746],
];
const deliveryPoints: Array<[number, number]> = [
  [100.5663, 13.7274],
  [100.5298, 13.7215],
  [100.5417, 13.7402],
  [100.5846, 13.7487],
];
const networkSupplyPoints: Array<[number, number]> = [
  [100.5703, 13.7358], [100.5637, 13.7311], [100.5687, 13.7279],
  [100.5858, 13.7278], [100.5486, 13.7428], [100.5752, 13.7391],
  [100.5582, 13.7384], [100.5512, 13.7462],
];

function initials(name: string): string {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "DR";
}

function routeCollection(rounds: OperationsRoundSummary[]) {
  return {
    type: "FeatureCollection" as const,
    features: rounds.slice(0, 4).map((round, index) => {
      const start = roundPoints[index] ?? bangkokCenter;
      const middle: [number, number] = [start[0] + (index % 2 ? -.009 : .011), start[1] + .007];
      const end: [number, number] = [start[0] + (index % 2 ? -.018 : .019), start[1] + (index % 2 ? .003 : -.006)];
      return { type: "Feature" as const, properties: { id: round.id, state: round.state }, geometry: { type: "LineString" as const, coordinates: [start, middle, end] } };
    }),
  };
}

function weatherCollection() {
  return { type: "FeatureCollection" as const, features: [{ type: "Feature" as const, properties: {}, geometry: { type: "Polygon" as const, coordinates: [[[100.562, 13.718], [100.594, 13.724], [100.589, 13.756], [100.557, 13.751], [100.562, 13.718]]] } }] };
}

function supplyCollection() {
  return { type: "FeatureCollection" as const, features: networkSupplyPoints.map((coordinates, index) => ({ type: "Feature" as const, properties: { status: index < 5 ? "open" : "busy" }, geometry: { type: "Point" as const, coordinates } })) };
}

function styleForMode(mode: OperationsMapMode): string {
  if (mode === "satellite") return "mapbox://styles/mapbox/satellite-streets-v12";
  if (mode === "site") return "mapbox://styles/mapbox/streets-v12";
  return "mapbox://styles/mapbox/light-v11";
}

function addDataLayers(map: MapboxMap, data: MapData) {
  if (data.mapMode === "site" && map.getSource("composite") && !map.getLayer("rounds-3d-buildings")) {
    map.addLayer({
      id: "rounds-3d-buildings", type: "fill-extrusion", source: "composite", "source-layer": "building", minzoom: 14,
      paint: { "fill-extrusion-color": "#d9dee3", "fill-extrusion-height": ["coalesce", ["get", "height"], 8], "fill-extrusion-base": ["coalesce", ["get", "min_height"], 0], "fill-extrusion-opacity": .82 },
    });
  }

  if (!map.getSource("rounds-routes")) map.addSource("rounds-routes", { type: "geojson", data: routeCollection(data.rounds) });
  else (map.getSource("rounds-routes") as GeoJSONSource).setData(routeCollection(data.rounds));
  if (!map.getLayer("rounds-route-shadow")) map.addLayer({ id: "rounds-route-shadow", type: "line", source: "rounds-routes", layout: { "line-cap": "round", "line-join": "round" }, paint: { "line-color": "#ffffff", "line-width": 11, "line-opacity": .92 } });
  if (!map.getLayer("rounds-route")) map.addLayer({ id: "rounds-route", type: "line", source: "rounds-routes", layout: { "line-cap": "round", "line-join": "round" }, paint: { "line-color": ["match", ["get", "state"], "active", "#152033", "#178f50"], "line-width": 6, "line-opacity": .96 } });

  if (data.weatherLayerOn) {
    if (!map.getSource("rounds-weather")) map.addSource("rounds-weather", { type: "geojson", data: weatherCollection() });
    if (!map.getLayer("rounds-weather")) map.addLayer({ id: "rounds-weather", type: "fill", source: "rounds-weather", paint: { "fill-color": "#66afd6", "fill-opacity": .13, "fill-outline-color": "#5aa5d2" } });
  } else {
    if (map.getLayer("rounds-weather")) map.removeLayer("rounds-weather");
    if (map.getSource("rounds-weather")) map.removeSource("rounds-weather");
  }

  if (data.networkSupplyOn) {
    if (!map.getSource("rounds-network-supply")) map.addSource("rounds-network-supply", { type: "geojson", data: supplyCollection() });
    if (!map.getLayer("rounds-network-supply")) map.addLayer({ id: "rounds-network-supply", type: "circle", source: "rounds-network-supply", paint: { "circle-radius": ["match", ["get", "status"], "open", 8, 6], "circle-color": ["match", ["get", "status"], "open", "#ffffff", "#ff6a21"], "circle-stroke-color": "#ff6a21", "circle-stroke-width": 2, "circle-opacity": .92 } });
  } else {
    if (map.getLayer("rounds-network-supply")) map.removeLayer("rounds-network-supply");
    if (map.getSource("rounds-network-supply")) map.removeSource("rounds-network-supply");
  }
}

export function OperationsMap({ mode, mapMode, weatherLayerOn, networkSupplyOn, rounds, exceptions, planningDeliveries, onCameraChange, onSelectRound, onSelectException, onSelectDelivery }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapboxMap | null>(null);
  const markersRef = useRef<mapboxgl.Marker[]>([]);
  const boundsRef = useRef<mapboxgl.LngLatBounds | null>(null);
  const appliedModeRef = useRef<OperationsMapMode>("operations");
  const callbacksRef = useRef({ onCameraChange, onSelectRound, onSelectException, onSelectDelivery });
  const dataRef = useRef<MapData>({ mode, mapMode, weatherLayerOn, networkSupplyOn, rounds, exceptions, planningDeliveries });
  const [state, setState] = useState<"loading" | "ready" | "error">(token ? "loading" : "error");

  callbacksRef.current = { onCameraChange, onSelectRound, onSelectException, onSelectDelivery };
  dataRef.current = { mode, mapMode, weatherLayerOn, networkSupplyOn, rounds, exceptions, planningDeliveries };

  useEffect(() => {
    if (!containerRef.current || !token || mapRef.current) return;
    mapboxgl.accessToken = token;
    let map: MapboxMap;
    try {
      map = new mapboxgl.Map({ container: containerRef.current, accessToken: token, style: styleForMode("operations"), center: bangkokCenter, zoom: 12.55, pitch: 0, bearing: 0, minZoom: 10, maxZoom: 19, logoPosition: "bottom-left" });
    } catch {
      setState("error");
      return;
    }
    mapRef.current = map;
    const publishCamera = () => callbacksRef.current.onCameraChange({ bearing: map.getBearing(), pitch: map.getPitch() });
    const focus = () => {
      if (appliedModeRef.current === "site") map.flyTo({ center: siteCenter, zoom: 17.2, pitch: 52, bearing: -20, duration: 650, essential: true });
      else if (boundsRef.current) map.fitBounds(boundsRef.current, { padding: { top: 95, right: 90, bottom: 80, left: 90 }, maxZoom: 13.8, duration: 500 });
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
      addDataLayers(map, dataRef.current);
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
    if (!map || state !== "ready" || mapMode === "street" || appliedModeRef.current === mapMode) return;
    appliedModeRef.current = mapMode;
    setState("loading");
    map.setStyle(styleForMode(mapMode));
    map.once("style.load", () => {
      addDataLayers(map, dataRef.current);
      setState("ready");
      if (mapMode === "site") map.flyTo({ center: siteCenter, zoom: 17.2, pitch: 52, bearing: -20, duration: 800, essential: true });
      else if (mapMode === "satellite") map.flyTo({ center: siteCenter, zoom: 15.8, pitch: 0, bearing: 0, duration: 700, essential: true });
      else if (boundsRef.current) map.fitBounds(boundsRef.current, { padding: { top: 95, right: 90, bottom: 80, left: 90 }, maxZoom: 13.8, duration: 600 });
    });
  }, [mapMode, state]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || state !== "ready") return;
    addDataLayers(map, dataRef.current);
  }, [networkSupplyOn, rounds, state, weatherLayerOn]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || state !== "ready") return;
    markersRef.current.forEach((marker) => marker.remove());
    markersRef.current = [];

    const coordinates: Array<[number, number]> = [];
    rounds.slice(0, 4).forEach((round, index) => {
      const coord = roundPoints[index] ?? bangkokCenter;
      coordinates.push(coord);
      const element = document.createElement("button");
      element.type = "button";
      element.className = "v45-mapbox-driver";
      element.textContent = initials(round.driverName);
      element.title = `${round.reference} · ${round.driverName}`;
      element.addEventListener("click", () => callbacksRef.current.onSelectRound(round));
      markersRef.current.push(new mapboxgl.Marker({ element }).setLngLat(coord).addTo(map));
    });

    const deliveries = mode === "plan" ? planningDeliveries : exceptions;
    deliveries.slice(0, 4).forEach((item, index) => {
      const coord = deliveryPoints[index] ?? bangkokCenter;
      coordinates.push(coord);
      const element = document.createElement("button");
      element.type = "button";
      element.className = "v45-mapbox-stop";
      element.textContent = String(index + 1);
      element.title = "recipientName" in item ? item.recipientName : "Delivery";
      element.addEventListener("click", () => {
        if (mode === "plan") callbacksRef.current.onSelectDelivery(item as UnplannedDeliverySummary);
        else callbacksRef.current.onSelectException(item as OperationsActionException);
      });
      markersRef.current.push(new mapboxgl.Marker({ element }).setLngLat(coord).addTo(map));
    });

    if (coordinates.length) {
      boundsRef.current = coordinates.reduce((current, coordinate) => current.extend(coordinate), new mapboxgl.LngLatBounds(coordinates[0], coordinates[0]));
      if (mapMode === "operations") map.fitBounds(boundsRef.current, { padding: { top: 95, right: 90, bottom: 80, left: 90 }, maxZoom: 13.8, duration: 650 });
    } else {
      boundsRef.current = null;
      if (mapMode === "operations") map.easeTo({ center: bangkokCenter as LngLatLike, zoom: 12.55, duration: 450 });
    }
  }, [exceptions, mapMode, mode, planningDeliveries, rounds, state]);

  return <><div className="v45-mapbox" ref={containerRef} />{state === "loading" && <div className="v45-mapbox-state"><b>Changing Mapbox view</b><span>Restoring routes and operational layers…</span></div>}{state === "error" && <div className="v45-mapbox-state error"><b>Map service unavailable</b><span>The Dispatch board remains usable with its degraded map.</span></div>}</>;
}
