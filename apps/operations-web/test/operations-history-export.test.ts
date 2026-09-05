import assert from "node:assert/strict";
import test from "node:test";
import type { OperationsHistoryItem } from "@rounds/contracts";
import { operationsDeliveryHistoryCsv } from "../src/operations-history-export";

const common = {
  recordId: "record-1",
  deliveryId: "delivery-1",
  stopId: "stop-1",
  roundId: "round-1",
  deliveryReference: "UF-1",
  roundReference: "ROUND-1",
  recipientName: "Siriporn, Demo",
  rawAddress: "88 \"Wireless\" Road",
  driverName: "Johannes",
  manifestVersion: 2,
  verifiedPhotoCount: 1,
  mediaAssetId: "media-1",
  mediaState: "committed",
} as const;

test("history export is a UTF-8 machine-readable CSV with escaped operational truth", () => {
  const records: OperationsHistoryItem[] = [{
    ...common,
    outcome: "delivered",
    podId: "pod-1",
    handoffType: "someone_else",
    receiverLabel: "Reception",
    deliveredAt: "2026-09-05T04:00:00.000Z",
    occurredAt: "2026-09-05T04:00:00.000Z",
  }];
  const csv = operationsDeliveryHistoryCsv(records);
  assert.ok(csv.startsWith("\uFEFF\"Type\",\"Occurred at\""));
  assert.match(csv, /"Siriporn, Demo"/);
  assert.match(csv, /"88 ""Wireless"" Road"/);
  assert.match(csv, /"someone_else","Reception"/);
});

test("history export preserves return incident and resolution evidence", () => {
  const records: OperationsHistoryItem[] = [{
    ...common,
    outcome: "returned",
    exceptionId: "exception-1",
    category: "damaged_item",
    exceptionNote: "Box crushed",
    resolutionNote: "Received by Somchai",
    reportedAt: "2026-09-05T03:00:00.000Z",
    returnedAt: "2026-09-05T05:00:00.000Z",
    occurredAt: "2026-09-05T05:00:00.000Z",
  }];
  const csv = operationsDeliveryHistoryCsv(records);
  assert.match(csv, /"returned"/);
  assert.match(csv, /"damaged_item","Box crushed","Received by Somchai"/);
});
