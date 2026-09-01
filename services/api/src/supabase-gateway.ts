import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type {
  AuthenticatedIdentity,
  ActorContext,
  DeliveryCommandGateway,
  IdentityGateway,
  OperationsRole,
} from "./types.js";
import type {
  CreateDeliveryCommand,
  CreateDeliveryResult,
  OperationsLocation,
  OperationsSession,
  OperationsTenant,
} from "@rounds/contracts";

type MembershipRow = {
  person_id: string;
  tenant_id: string;
  role: OperationsRole;
};

type TenantRow = {
  id: string;
  display_name: string;
  timezone: string;
};

type LocationRow = {
  id: string;
  tenant_id: string;
  code: string;
  display_name: string;
  raw_address: string;
  pickup_contact_name: string;
  pickup_contact_phone: string;
};

const rolePriority: Record<OperationsRole, number> = {
  tenant_owner: 1,
  operations_admin: 2,
  dispatcher: 3,
  viewer: 4,
};

export class SupabaseGateway implements IdentityGateway, DeliveryCommandGateway {
  private readonly admin: SupabaseClient;

  constructor(
    private readonly url: string,
    private readonly publishableKey: string,
    secretKey: string,
  ) {
    this.admin = createClient(url, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }

  async authenticate(accessToken: string): Promise<AuthenticatedIdentity | null> {
    const client = createClient(this.url, this.publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await client.auth.getUser(accessToken);
    if (error || !data.user) return null;
    return {
      authUserId: data.user.id,
      ...(data.user.email ? { email: data.user.email } : {}),
    };
  }

  async getOperationsSession(identity: AuthenticatedIdentity): Promise<OperationsSession | null> {
    const { data: linkedIdentity, error: identityError } = await this.admin
      .from("auth_identities")
      .select("person_id")
      .eq("auth_user_id", identity.authUserId)
      .maybeSingle<{ person_id: string }>();
    if (identityError) throw identityError;
    if (!linkedIdentity) return null;

    const { data: person, error: personError } = await this.admin
      .from("persons")
      .select("display_name")
      .eq("id", linkedIdentity.person_id)
      .maybeSingle<{ display_name: string }>();
    if (personError) throw personError;
    if (!person) return null;

    const { data: memberships, error: membershipsError } = await this.admin
      .from("tenant_memberships")
      .select("person_id, tenant_id, role")
      .eq("person_id", linkedIdentity.person_id)
      .eq("status", "active")
      .in("role", ["tenant_owner", "operations_admin", "dispatcher", "viewer"])
      .returns<MembershipRow[]>();
    if (membershipsError) throw membershipsError;
    if (!memberships?.length) return null;

    const roleByTenant = new Map<string, OperationsRole>();
    for (const membership of memberships) {
      const current = roleByTenant.get(membership.tenant_id);
      if (!current || rolePriority[membership.role] < rolePriority[current]) {
        roleByTenant.set(membership.tenant_id, membership.role);
      }
    }
    const tenantIds = [...roleByTenant.keys()];

    const [{ data: tenants, error: tenantsError }, { data: locations, error: locationsError }] = await Promise.all([
      this.admin
        .from("tenants")
        .select("id, display_name, timezone")
        .in("id", tenantIds)
        .eq("status", "active")
        .is("deleted_at", null)
        .returns<TenantRow[]>(),
      this.admin
        .from("tenant_locations")
        .select("id, tenant_id, code, display_name, raw_address, pickup_contact_name, pickup_contact_phone")
        .in("tenant_id", tenantIds)
        .eq("active", true)
        .is("deleted_at", null)
        .returns<LocationRow[]>(),
    ]);
    if (tenantsError) throw tenantsError;
    if (locationsError) throw locationsError;

    const locationsByTenant = new Map<string, OperationsLocation[]>();
    for (const location of locations ?? []) {
      const normalized: OperationsLocation = {
        id: location.id,
        code: location.code,
        displayName: location.display_name,
        rawAddress: location.raw_address,
        pickupContactName: location.pickup_contact_name,
        pickupContactPhone: location.pickup_contact_phone,
      };
      locationsByTenant.set(location.tenant_id, [
        ...(locationsByTenant.get(location.tenant_id) ?? []),
        normalized,
      ]);
    }

    const sessionTenants: OperationsTenant[] = (tenants ?? [])
      .map((tenant) => ({
        id: tenant.id,
        displayName: tenant.display_name,
        timezone: tenant.timezone,
        role: roleByTenant.get(tenant.id)!,
        locations: (locationsByTenant.get(tenant.id) ?? [])
          .sort((a, b) => a.displayName.localeCompare(b.displayName)),
      }))
      .sort((a, b) => a.displayName.localeCompare(b.displayName));

    if (!sessionTenants.length) return null;
    return {
      user: {
        id: identity.authUserId,
        ...(identity.email ? { email: identity.email } : {}),
        displayName: person.display_name,
      },
      tenants: sessionTenants,
    };
  }

  async authorizeTenant(authUserId: string, tenantId: string): Promise<ActorContext | null> {
    const { data: identity, error: identityError } = await this.admin
      .from("auth_identities")
      .select("person_id")
      .eq("auth_user_id", authUserId)
      .maybeSingle<{ person_id: string }>();
    if (identityError) throw identityError;
    if (!identity) return null;

    const { data: membership, error: membershipError } = await this.admin
      .from("tenant_memberships")
      .select("person_id, tenant_id, role")
      .eq("tenant_id", tenantId)
      .eq("person_id", identity.person_id)
      .eq("status", "active")
      .in("role", ["tenant_owner", "operations_admin", "dispatcher", "viewer"])
      .order("role")
      .limit(1)
      .maybeSingle<MembershipRow>();
    if (membershipError) throw membershipError;
    if (!membership) return null;
    return {
      authUserId,
      personId: membership.person_id,
      tenantId,
      role: membership.role,
    };
  }

  async createDelivery(
    command: CreateDeliveryCommand,
    actor: ActorContext,
  ): Promise<CreateDeliveryResult> {
    const { data, error } = await this.admin.rpc("create_delivery_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as CreateDeliveryResult;
  }

  async ready(): Promise<boolean> {
    const { error } = await this.admin.from("tenants").select("id", { head: true, count: "exact" }).limit(1);
    return !error;
  }
}
