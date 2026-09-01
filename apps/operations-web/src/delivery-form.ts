import type { CreateDeliveryPayload } from "@rounds/contracts";

export class DeliveryFormError extends Error {}

export type ManifestItemDraft = {
  description: string;
  quantity: string;
  handlingNote: string;
};

export type DeliveryFormDraft = {
  reference: string;
  serviceDate: string;
  pickupLocationId: string;
  recipientName: string;
  recipientPhone: string;
  address: string;
  latitude: string;
  longitude: string;
  accessNote: string;
  buyerSameAsRecipient: boolean;
  buyerName: string;
  buyerPhone: string;
  windowStart: string;
  windowEnd: string;
  items: ManifestItemDraft[];
  note: string;
  isSurprise: boolean;
};

export function todayInBangkok(now = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Bangkok",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

export function defaultDeliveryDraft(serviceDate = todayInBangkok()): DeliveryFormDraft {
  return {
    reference: "",
    serviceDate,
    pickupLocationId: "",
    recipientName: "",
    recipientPhone: "",
    address: "",
    latitude: "",
    longitude: "",
    accessNote: "",
    buyerSameAsRecipient: true,
    buyerName: "",
    buyerPhone: "",
    windowStart: `${serviceDate}T09:00`,
    windowEnd: `${serviceDate}T12:00`,
    items: [{ description: "", quantity: "1", handlingNote: "" }],
    note: "",
    isSurprise: false,
  };
}

function bangkokLocalToIso(value: string, field: string): string {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) {
    throw new DeliveryFormError(`${field} is required`);
  }
  const parsed = new Date(`${value}:00+07:00`);
  if (!Number.isFinite(parsed.getTime())) throw new DeliveryFormError(`${field} is invalid`);
  return parsed.toISOString();
}

export function buildCreateDeliveryPayload(draft: DeliveryFormDraft): CreateDeliveryPayload {
  const reference = draft.reference.trim();
  if (!reference) throw new DeliveryFormError("Order reference is required");
  if (!draft.latitude.trim() || !draft.longitude.trim()) {
    throw new DeliveryFormError("Operational destination latitude and longitude are required");
  }

  const items = draft.items.map((item) => ({
    description: item.description.trim(),
    quantity: Number(item.quantity),
    ...(item.handlingNote.trim() ? { handlingNote: item.handlingNote.trim() } : {}),
  }));

  const payload: CreateDeliveryPayload = {
    sourceSystem: "manual",
    externalId: reference,
    reference,
    serviceDate: draft.serviceDate,
    serviceTimezone: "Asia/Bangkok",
    pickupLocationId: draft.pickupLocationId,
    recipient: {
      name: draft.recipientName.trim(),
      phone: draft.recipientPhone.trim(),
      rawAddress: draft.address.trim(),
      coordinate: {
        latitude: Number(draft.latitude),
        longitude: Number(draft.longitude),
        provenance: "dispatcher_pin",
      },
      ...(draft.accessNote.trim() ? { accessNote: draft.accessNote.trim() } : {}),
    },
    buyer: draft.buyerSameAsRecipient
      ? { sameAsRecipient: true }
      : {
          sameAsRecipient: false,
          name: draft.buyerName.trim(),
          phone: draft.buyerPhone.trim(),
        },
    promise: {
      windowStart: bangkokLocalToIso(draft.windowStart, "Promise start"),
      windowEnd: bangkokLocalToIso(draft.windowEnd, "Promise end"),
    },
    manifest: { items },
    ...(draft.note.trim() ? { note: draft.note.trim() } : {}),
    ...(draft.isSurprise ? { isSurprise: true } : {}),
  };

  if (!payload.pickupLocationId || !draft.recipientName.trim() || !draft.recipientPhone.trim() || !draft.address.trim()) {
    throw new DeliveryFormError("Pickup, recipient name, phone and address are required");
  }
  if (!Number.isFinite(payload.recipient.coordinate.latitude)
    || payload.recipient.coordinate.latitude < -90
    || payload.recipient.coordinate.latitude > 90
    || !Number.isFinite(payload.recipient.coordinate.longitude)
    || payload.recipient.coordinate.longitude < -180
    || payload.recipient.coordinate.longitude > 180) {
    throw new DeliveryFormError("Operational destination coordinate is invalid");
  }
  if (Date.parse(payload.promise.windowEnd) <= Date.parse(payload.promise.windowStart)) {
    throw new DeliveryFormError("Promise end must be after promise start");
  }
  if (!payload.buyer.sameAsRecipient && (!payload.buyer.name || !payload.buyer.phone)) {
    throw new DeliveryFormError("Buyer name and phone are required");
  }
  if (items.length === 0 || items.some((item) => !item.description || !Number.isInteger(item.quantity) || item.quantity <= 0)) {
    throw new DeliveryFormError("Every item needs a description and positive quantity");
  }
  return payload;
}
