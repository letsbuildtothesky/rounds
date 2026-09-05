"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type {
  CommunicationThreadReadState,
  OperationsCommunicationsProjection,
  OperationsTenant,
} from "@rounds/contracts";
import { applyCommunicationReadState } from "../src/operations-communications-state";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";
type ApiError = { error?: { message?: string } };

export type OperationsCommunicationsStore = {
  projection: OperationsCommunicationsProjection | null;
  loading: boolean;
  error: string;
  refresh: (quiet?: boolean) => Promise<void>;
  markRead: (threadId: string) => Promise<void>;
};

function errorMessage(body: ApiError, fallback: string): string {
  return body.error?.message ?? fallback;
}

export function useOperationsCommunications(
  accessToken: string | undefined,
  tenant: OperationsTenant,
): OperationsCommunicationsStore {
  const [projection, setProjection] = useState<OperationsCommunicationsProjection | null>(null);
  const [loading, setLoading] = useState(Boolean(accessToken));
  const [error, setError] = useState("");
  const projectionRef = useRef<OperationsCommunicationsProjection | null>(null);
  const marking = useRef(new Set<string>());

  useEffect(() => { projectionRef.current = projection; }, [projection]);

  const refresh = useCallback(async (quiet = false) => {
    if (!accessToken) {
      setProjection(null);
      setLoading(false);
      return;
    }
    if (!quiet) setLoading(true);
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/communications`, {
        headers: {
          authorization: `Bearer ${accessToken}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
      });
      const body = await response.json() as OperationsCommunicationsProjection | ApiError;
      if (!response.ok) throw new Error(errorMessage(body as ApiError, `Communications HTTP ${response.status}`));
      setProjection(body as OperationsCommunicationsProjection);
      setError("");
    } catch (caught) {
      if (!quiet) setError(caught instanceof Error ? caught.message : "Communications could not be loaded");
    } finally {
      if (!quiet) setLoading(false);
    }
  }, [accessToken, tenant.id]);

  useEffect(() => {
    void refresh();
    if (!accessToken) return;
    const timer = window.setInterval(() => void refresh(true), 5000);
    return () => window.clearInterval(timer);
  }, [accessToken, refresh]);

  const markRead = useCallback(async (threadId: string) => {
    const current = projectionRef.current;
    const thread = current?.threads.find((candidate) => candidate.id === threadId);
    const latestMessage = thread?.messages.at(-1);
    if (!accessToken || !thread?.unreadCount || !latestMessage || marking.current.has(threadId)) return;
    marking.current.add(threadId);
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/communications/${threadId}/read`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
        body: JSON.stringify({ lastReadMessageId: latestMessage.id }),
      });
      const body = await response.json() as CommunicationThreadReadState | ApiError;
      if (!response.ok) throw new Error(errorMessage(body as ApiError, `Read receipt HTTP ${response.status}`));
      setProjection((existing) => existing
        ? applyCommunicationReadState(existing, body as CommunicationThreadReadState)
        : existing);
      setError("");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "The conversation could not be marked read");
    } finally {
      marking.current.delete(threadId);
    }
  }, [accessToken, tenant.id]);

  return { projection, loading, error, refresh, markRead };
}
