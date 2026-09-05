"use client";

import { useEffect, useMemo, useState } from "react";
import type { OperationsRoundDetail, OperationsRoundSummary, OperationsTenant } from "@rounds/contracts";
import {
  groupOperationsRounds,
  roundCapacityLabel,
  roundVehicleLabel,
  type OperationsRoundOverviewItem,
} from "../src/operations-rounds-overview";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";
type ApiError = { error?: { message?: string } };

type Props = {
  accessToken?: string;
  tenant: OperationsTenant;
  rounds: OperationsRoundSummary[];
  onClose: () => void;
  onOpenRound: (roundId: string) => void;
  onPlanNext: () => void;
};

function timeLabel(value: string | undefined, timezone: string): string | null {
  if (!value) return null;
  return new Intl.DateTimeFormat("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
    timeZone: timezone,
  }).format(new Date(value));
}

function stateLabel(value: OperationsRoundSummary["state"]): string {
  return value.replaceAll("_", " ").replace(/^./, (character) => character.toUpperCase());
}

export function RoundsOverviewDrawer({ accessToken, tenant, rounds, onClose, onOpenRound, onPlanNext }: Props) {
  const [details, setDetails] = useState<Map<string, OperationsRoundDetail>>(new Map());
  const [loading, setLoading] = useState(Boolean(accessToken && rounds.length));
  const [detailError, setDetailError] = useState("");
  const detailRequestKey = rounds.map((round) => `${round.id}:${round.state}:${round.driverId}:${round.stopCount}`).join("|");

  useEffect(() => {
    const controller = new AbortController();
    setDetails(new Map());
    setDetailError("");
    if (!accessToken || rounds.length === 0) {
      setLoading(false);
      return () => controller.abort();
    }
    setLoading(true);
    void Promise.allSettled(rounds.map(async (round) => {
      const response = await fetch(`${roundsApiUrl}/v1/operations/rounds/${round.id}`, {
        signal: controller.signal,
        headers: {
          authorization: `Bearer ${accessToken}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
      });
      const body = await response.json() as OperationsRoundDetail | ApiError;
      if (!response.ok) throw new Error((body as ApiError).error?.message ?? `Round HTTP ${response.status}`);
      return body as OperationsRoundDetail;
    })).then((results) => {
      if (controller.signal.aborted) return;
      const loaded = results.flatMap((result) => result.status === "fulfilled" ? [result.value] : []);
      setDetails(new Map(loaded.map((detail) => [detail.id, detail])));
      if (loaded.length !== results.length) setDetailError("Some Round details could not be loaded");
    }).finally(() => {
      if (!controller.signal.aborted) setLoading(false);
    });
    return () => controller.abort();
  }, [accessToken, detailRequestKey, tenant.id]);

  const groups = useMemo(() => groupOperationsRounds(rounds, details), [details, rounds]);

  return <aside className="v45-drawer v45-rounds-overview open" role="dialog" aria-modal="false" aria-labelledby="v45-rounds-overview-title">
    <header>
      <div><small>DISPATCH</small><h2 id="v45-rounds-overview-title">Rounds</h2><p>Own fleet work</p></div>
      <button type="button" onClick={onClose} aria-label="Close Rounds overview"><CloseIcon /></button>
    </header>
    <div className="v45-drawer-body">
      {loading && <div className="v45-rounds-notice">Loading current route and capacity truth…</div>}
      {detailError && <div className="v45-rounds-notice warning">Round status is current. Some route details could not be loaded.</div>}
      <RoundSection label="Own · Active" items={groups.active} timezone={tenant.timezone} upcoming={false} onOpenRound={onOpenRound} />
      <RoundSection label="Own · Upcoming" items={groups.upcoming} timezone={tenant.timezone} upcoming onOpenRound={onOpenRound} />
      <div className="v45-rounds-plan-row">
        <div><b>Need another Round?</b><span>Plan it behind a driver&apos;s current work.</span></div>
        <button type="button" onClick={onPlanNext}>Plan next</button>
      </div>
    </div>
  </aside>;
}

function RoundSection({ label, items, timezone, upcoming, onOpenRound }: {
  label: string;
  items: OperationsRoundOverviewItem[];
  timezone: string;
  upcoming: boolean;
  onOpenRound: (roundId: string) => void;
}) {
  return <section className="v45-rounds-section">
    <div className="v45-rounds-section-title">{label} <span>{items.length}</span></div>
    <div className="v45-round-list">
      {items.length ? items.map(({ summary, detail }) => {
        const routeTime = timeLabel(upcoming ? detail?.routePlan?.departureAt : detail?.routePlan?.finishAt, timezone);
        return <button className={`v45-round-row ${upcoming ? "planned-row" : ""}`} type="button" key={summary.id} onClick={() => onOpenRound(summary.id)}>
          <div><b>{summary.reference} · {summary.driverName}</b><span>{roundVehicleLabel(detail)} · {summary.stopCount} stop{summary.stopCount === 1 ? "" : "s"} · {roundCapacityLabel(detail)}</span></div>
          <div className="right"><b>{routeTime ? `${upcoming ? "Starts" : "Finish"} ${routeTime}` : upcoming ? "Start not calculated" : "Finish not calculated"}</b><span>{stateLabel(summary.state)}</span></div>
        </button>;
      }) : <div className="v45-rounds-empty">No {upcoming ? "upcoming" : "active"} own-team Rounds.</div>}
    </div>
  </section>;
}

function CloseIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg>;
}
