export const operationsRoles = [
  "tenant_owner",
  "operations_admin",
  "dispatcher",
  "viewer",
] as const;

export type OperationsRole = (typeof operationsRoles)[number];

export type OperationsLocation = {
  id: string;
  code: string;
  displayName: string;
  rawAddress: string;
  pickupContactName: string;
  pickupContactPhone: string;
};

export type OperationsTenant = {
  id: string;
  displayName: string;
  timezone: string;
  role: OperationsRole;
  locations: OperationsLocation[];
};

export type OperationsSession = {
  user: {
    id: string;
    email?: string;
    displayName: string;
  };
  tenants: OperationsTenant[];
};

export type OperationsHistoryItem = {
  podId: string;
  deliveryId: string;
  stopId: string;
  roundId: string;
  deliveryReference: string;
  roundReference: string;
  recipientName: string;
  rawAddress: string;
  driverName: string;
  handoffType: "recipient" | "someone_else" | "left_at_location";
  receiverLabel: string;
  deliveredAt: string;
  manifestVersion: number;
  verifiedPhotoCount: 1;
  mediaAssetId: string;
  mediaState: "committed";
};

export type OperationsHistoryProjection = {
  tenantId: string;
  deliveries: OperationsHistoryItem[];
};
