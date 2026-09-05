"use client";

import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import mapboxgl, { type Map as MapboxMap } from "mapbox-gl";

export type DestinationCoordinate = {
  latitude: number;
  longitude: number;
};

type Props = {
  initial: DestinationCoordinate;
  mode: "create" | "change";
  onCancel: () => void;
  onConfirm: (coordinate: DestinationCoordinate) => void;
};

export function DestinationPinPicker({ initial, mode, onCancel, onConfirm }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const selectedRef = useRef(initial);
  const [selected, setSelected] = useState(initial);
  const [state, setState] = useState<"loading" | "ready" | "error">("loading");
  const creating = mode === "create";

  useEffect(() => {
    const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN ?? "";
    if (!containerRef.current || !token) {
      setState("error");
      return;
    }

    mapboxgl.accessToken = token;
    let map: MapboxMap;
    try {
      map = new mapboxgl.Map({
        container: containerRef.current,
        accessToken: token,
        style: "mapbox://styles/mapbox/light-v11",
        center: [initial.longitude, initial.latitude],
        zoom: 16.5,
        pitch: 0,
        bearing: 0,
        minZoom: 12,
        maxZoom: 20,
        logoPosition: "bottom-left",
      });
    } catch {
      setState("error");
      return;
    }

    const publishCenter = () => {
      const center = map.getCenter();
      selectedRef.current = { latitude: center.lat, longitude: center.lng };
      setSelected(selectedRef.current);
    };

    map.on("load", () => setState("ready"));
    map.on("moveend", publishCenter);
    map.on("error", () => {
      if (!map.loaded()) setState("error");
    });
    return () => map.remove();
  }, [initial.latitude, initial.longitude]);

  if (typeof document === "undefined") return null;

  return createPortal(<div className="v45-pin-picker-backdrop" role="presentation">
    <section className="v45-pin-picker" role="dialog" aria-modal="true" aria-label={creating ? "Set delivery pin" : "Set new delivery pin"}>
      <header>
        <div>
          <small>CONFIRMED DESTINATION</small>
          <h2>{creating ? "Place the delivery pin" : "Place the new delivery pin"}</h2>
          <p>Move the map until the crosshair is on the vehicle arrival or delivery point.</p>
        </div>
        <button type="button" onClick={onCancel} aria-label="Close pin picker">×</button>
      </header>
      <div className="v45-pin-picker-map">
        <div ref={containerRef} />
        {state === "loading" && <p>Loading the real map…</p>}
        {state === "error" && <p>Map service unavailable. The destination has not changed.</p>}
        <span className="v45-pin-crosshair" aria-hidden="true"><i /></span>
      </div>
      <footer>
        <span>{selected.latitude.toFixed(5)}, {selected.longitude.toFixed(5)}</span>
        <button type="button" onClick={onCancel}>Cancel</button>
        <button type="button" className="primary" disabled={state !== "ready"} onClick={() => onConfirm(selectedRef.current)}>Use this pin</button>
      </footer>
    </section>
  </div>, document.body);
}
