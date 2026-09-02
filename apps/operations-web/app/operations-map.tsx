"use client";

import { useEffect, useRef, useState } from "react";
import mapboxgl, { type GeoJSONSource, type LngLatLike, type Map as MapboxMap } from "mapbox-gl";
import type { OperationsActionException, OperationsRoundSummary, UnplannedDeliverySummary } from "@rounds/contracts";

type Props = {
  mode: "live" | "plan";
  rounds: OperationsRoundSummary[];
  exceptions: OperationsActionException[];
  planningDeliveries: UnplannedDeliverySummary[];
  onSelectRound: (round: OperationsRoundSummary) => void;
  onSelectException: (exception: OperationsActionException) => void;
  onSelectDelivery: (delivery: UnplannedDeliverySummary) => void;
};

const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN ?? "";
const bangkokCenter: [number, number] = [100.5598, 13.735];
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

export function OperationsMap({ mode, rounds, exceptions, planningDeliveries, onSelectRound, onSelectException, onSelectDelivery }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapboxMap | null>(null);
  const markersRef = useRef<mapboxgl.Marker[]>([]);
  const boundsRef = useRef<mapboxgl.LngLatBounds | null>(null);
  const callbacksRef = useRef({ onSelectRound, onSelectException, onSelectDelivery });
  const [state, setState] = useState<"loading" | "ready" | "error">(token ? "loading" : "error");

  callbacksRef.current = { onSelectRound, onSelectException, onSelectDelivery };

  useEffect(() => {
    if (!containerRef.current || !token || mapRef.current) return;
    mapboxgl.accessToken = token;
    let map: MapboxMap;
    try {
      map = new mapboxgl.Map({
        container: containerRef.current,
        accessToken: token,
        style: "mapbox://styles/mapbox/light-v11",
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
    const handleControl = (event: Event) => {
      const action = (event as CustomEvent<"focus" | "zoom-in" | "zoom-out">).detail;
      if (action === "zoom-in") map.zoomIn({ duration: 180 });
      if (action === "zoom-out") map.zoomOut({ duration: 180 });
      if (action === "focus") {
        if (boundsRef.current) map.fitBounds(boundsRef.current, { padding: { top: 95, right: 90, bottom: 80, left: 90 }, maxZoom: 13.8, duration: 500 });
        else map.easeTo({ center: bangkokCenter as LngLatLike, zoom: 12.55, duration: 450 });
      }
    };
    window.addEventListener("rounds-map-control", handleControl);
    map.on("load", () => {
      map.addSource("rounds-routes", { type: "geojson", data: routeCollection([]) });
      map.addLayer({ id: "rounds-route-shadow", type: "line", source: "rounds-routes", layout: { "line-cap": "round", "line-join": "round" }, paint: { "line-color": "#ffffff", "line-width": 11, "line-opacity": .92 } });
      map.addLayer({ id: "rounds-route", type: "line", source: "rounds-routes", layout: { "line-cap": "round", "line-join": "round" }, paint: { "line-color": ["match", ["get", "state"], "active", "#152033", "#178f50"], "line-width": 6, "line-opacity": .96 } });
      setState("ready");
    });
    map.on("error", () => {
      if (!map.loaded()) setState("error");
    });
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
    if (!map || state !== "ready") return;
    const source = map.getSource("rounds-routes") as GeoJSONSource | undefined;
    source?.setData(routeCollection(rounds));
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
      const bounds = coordinates.reduce((current, coordinate) => current.extend(coordinate), new mapboxgl.LngLatBounds(coordinates[0], coordinates[0]));
      boundsRef.current = bounds;
      map.fitBounds(bounds, { padding: { top: 95, right: 90, bottom: 80, left: 90 }, maxZoom: 13.8, duration: 650 });
    } else {
      boundsRef.current = null;
      map.easeTo({ center: bangkokCenter as LngLatLike, zoom: 12.55, duration: 450 });
    }
  }, [exceptions, mode, planningDeliveries, rounds, state]);

  return <><div className="v45-mapbox" ref={containerRef} />{state === "loading" && <div className="v45-mapbox-state"><b>Loading real Mapbox</b><span>Bangkok operational map…</span></div>}{state === "error" && <div className="v45-mapbox-state error"><b>Map service unavailable</b><span>The Dispatch board remains usable with its degraded map.</span></div>}</>;
}
