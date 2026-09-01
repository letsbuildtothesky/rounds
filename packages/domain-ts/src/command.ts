import { createHash } from "node:crypto";
import type { CommandEnvelope } from "@rounds/contracts";

function canonicalize(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalize).join(",")}]`;
  const object = value as Record<string, unknown>;
  return `{${Object.keys(object)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonicalize(object[key])}`)
    .join(",")}}`;
}

export function normalizedPayloadHash(command: CommandEnvelope<string, unknown>): string {
  return createHash("sha256").update(canonicalize(command.payload)).digest("hex");
}

export type VersionCheck =
  | { ok: true; nextVersion: number }
  | { ok: false; code: "STALE_VERSION"; currentVersion: number };

export function checkExpectedVersion(currentVersion: number, expectedVersion: number): VersionCheck {
  if (currentVersion !== expectedVersion) {
    return { ok: false, code: "STALE_VERSION", currentVersion };
  }
  return { ok: true, nextVersion: currentVersion + 1 };
}
