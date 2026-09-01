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
