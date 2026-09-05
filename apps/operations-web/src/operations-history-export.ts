import type { OperationsHistoryItem } from "@rounds/contracts";

const headers = [
  "Type",
  "Occurred at",
  "Delivery reference",
  "Round reference",
  "Recipient",
  "Address",
  "Driver",
  "Outcome",
  "Handoff",
  "Receiver",
  "Verified photos",
  "Manifest version",
  "Exception category",
  "Exception note",
  "Resolution note",
];

function cell(value: string | number | undefined): string {
  return `"${String(value ?? "").replaceAll('"', '""')}"`;
}

export function operationsDeliveryHistoryCsv(records: OperationsHistoryItem[]): string {
  const rows = records.map((record) => [
    "Delivery",
    record.occurredAt,
    record.deliveryReference,
    record.roundReference,
    record.recipientName,
    record.rawAddress,
    record.driverName,
    record.outcome,
    record.outcome === "delivered" ? record.handoffType : "",
    record.outcome === "delivered" ? record.receiverLabel : "",
    record.verifiedPhotoCount,
    record.manifestVersion,
    record.outcome === "returned" ? record.category : "",
    record.outcome === "returned" ? record.exceptionNote : "",
    record.outcome === "returned" ? record.resolutionNote : "",
  ]);
  return `\uFEFF${[headers, ...rows].map((row) => row.map(cell).join(",")).join("\r\n")}`;
}
