import type { CommandEnvelope, CommandResult, DomainEventEnvelope } from "./command.js";

export const deliveryStates = [
  "draft",
  "unplanned",
  "planned",
  "assigned",
  "pickup_pending",
  "in_custody",
  "en_route",
  "arrived",
  "delivered_pending_evidence",
  "delivered",
  "exception",
  "returned",
  "cancelled",
] as const;

export type DeliveryState = (typeof deliveryStates)[number];

export type DeliveryCoordinate = {
  latitude: number;
  longitude: number;
  provenance: string;
};

export type DeliveryRecipient = {
  name: string;
  phone: string;
  rawAddress: string;
  coordinate: DeliveryCoordinate;
  accessNote?: string;
};

export type DeliveryBuyer =
  | { sameAsRecipient: true }
  | { sameAsRecipient: false; name: string; phone: string };

export type ManifestItemInput = {
  sku?: string;
  description: string;
  quantity: number;
  cargoClass?: string;
  handlingNote?: string;
};

export type CreateDeliveryPayload = {
  sourceSystem: "manual" | "internal";
  externalId: string;
  reference?: string;
  serviceDate: string;
  serviceTimezone: string;
  pickupLocationId: string;
  recipient: DeliveryRecipient;
  buyer: DeliveryBuyer;
  promise: {
    windowStart: string;
    windowEnd: string;
  };
  manifest: {
    items: ManifestItemInput[];
  };
  note?: string;
  isSurprise?: boolean;
};

export type CreateDeliveryCommand = CommandEnvelope<"delivery.create", CreateDeliveryPayload>;

export type DeliveryCreatedPayload = {
  deliveryId: string;
  stopId: string;
  manifestId: string;
  sourceSystem: string;
  externalId: string;
};

export type DeliveryCreatedEvent = DomainEventEnvelope<"delivery.created", DeliveryCreatedPayload>;

export type CreateDeliveryState = {
  deliveryId: string;
  deliveryState: "unplanned";
  stopId: string;
  manifestId: string;
};

export type CreateDeliveryResult = CommandResult<CreateDeliveryState, DeliveryCreatedEvent>;
