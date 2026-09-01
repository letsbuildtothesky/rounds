import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type {
  AuthenticatedIdentity,
  ActorContext,
  DeliveryCommandGateway,
  IdentityGateway,
  OperationsRole,
  RoundGateway,
} from "./types.js";
import type {
  CreateDeliveryCommand,
  CreateDeliveryResult,
  DriverRoundStop,
  DriverSession,
  OperationsLocation,
  OperationsPlanningProjection,
  OperationsSession,
  OperationsTenant,
  PlanRoundCommand,
  PlanRoundResult,
  RoundState,
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

type DriverProfileRow = { id: string; person_id: string; preferred_locale: string; vehicle_label: string | null; vehicle_plate: string | null };
type DriverRelationshipRow = { tenant_id: string; driver_id: string };
type PersonRow = { id: string; display_name: string };
type DeliveryRow = {
  id: string; reference: string; service_date: string; pickup_location_id: string; recipient_name: string;
  recipient_phone: string; destination_raw_address: string; destination_position: unknown; access_note: string | null;
  delivery_note: string | null; is_surprise: boolean;
};
type StopRow = { id: string; delivery_id: string; state: string; destination_version: number };
type PromiseRow = { delivery_id: string; window_start: string; window_end: string };
type ManifestRow = { id: string; delivery_id: string; version: number };
type ManifestItemRow = { manifest_id: string; line_number: number; description: string; quantity: number; handling_note: string | null };
type RoundRow = { id: string; tenant_id: string; reference: string; service_date: string; state: RoundState; version: number };
type RoundStopRow = { stop_id: string; sequence: number };

export function parseDatabasePoint(value: unknown): { latitude: number; longitude: number } | undefined {
  if (value && typeof value === "object" && "coordinates" in value) {
    const coordinates = (value as { coordinates?: unknown }).coordinates;
    if (Array.isArray(coordinates) && coordinates.length >= 2) {
      const longitude = Number(coordinates[0]);
      const latitude = Number(coordinates[1]);
      if (Number.isFinite(latitude) && Number.isFinite(longitude)) return { latitude, longitude };
    }
  }
  if (typeof value === "string") {
    const match = value.match(/POINT\(([-\d.]+) ([-\d.]+)\)/i);
    if (match) return { longitude: Number(match[1]), latitude: Number(match[2]) };
    if (/^[0-9a-f]+$/i.test(value) && value.length >= 42) {
      const bytes = Buffer.from(value, "hex");
      const littleEndian = bytes.readUInt8(0) === 1;
      const readUInt32 = littleEndian
        ? (offset: number) => bytes.readUInt32LE(offset)
        : (offset: number) => bytes.readUInt32BE(offset);
      const geometryType = readUInt32(1);
      let offset = 5;
      if ((geometryType & 0x20000000) !== 0) offset += 4;
      const longitude = littleEndian ? bytes.readDoubleLE(offset) : bytes.readDoubleBE(offset);
      const latitude = littleEndian ? bytes.readDoubleLE(offset + 8) : bytes.readDoubleBE(offset + 8);
      if (Number.isFinite(latitude) && Number.isFinite(longitude)) return { latitude, longitude };
    }
  }
  return undefined;
}

export class SupabaseGateway implements IdentityGateway, DeliveryCommandGateway, RoundGateway {
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

  async getOperationsPlanning(actor: ActorContext): Promise<OperationsPlanningProjection> {
    const { data: relationships, error: relationshipsError } = await this.admin
      .from("driver_tenant_relationships")
      .select("tenant_id, driver_id")
      .eq("tenant_id", actor.tenantId)
      .eq("relationship_kind", "team")
      .eq("status", "active")
      .is("deleted_at", null)
      .returns<DriverRelationshipRow[]>();
    if (relationshipsError) throw relationshipsError;
    const driverIds = (relationships ?? []).map((relationship) => relationship.driver_id);

    let profiles: DriverProfileRow[] = [];
    let persons: PersonRow[] = [];
    if (driverIds.length) {
      const { data, error } = await this.admin
        .from("driver_profiles")
        .select("id, person_id, preferred_locale, vehicle_label, vehicle_plate")
        .in("id", driverIds)
        .eq("active", true)
        .is("deleted_at", null)
        .returns<DriverProfileRow[]>();
      if (error) throw error;
      profiles = data ?? [];
      const { data: personData, error: personError } = await this.admin
        .from("persons")
        .select("id, display_name")
        .in("id", profiles.map((profile) => profile.person_id))
        .is("deleted_at", null)
        .returns<PersonRow[]>();
      if (personError) throw personError;
      persons = personData ?? [];
    }
    const personById = new Map(persons.map((person) => [person.id, person]));

    const { data: deliveries, error: deliveriesError } = await this.admin
      .from("deliveries")
      .select("id, reference, service_date, pickup_location_id, recipient_name, recipient_phone, destination_raw_address, destination_position, access_note, delivery_note, is_surprise")
      .eq("tenant_id", actor.tenantId)
      .eq("state", "unplanned")
      .is("deleted_at", null)
      .order("service_date")
      .order("created_at")
      .returns<DeliveryRow[]>();
    if (deliveriesError) throw deliveriesError;
    const deliveryIds = (deliveries ?? []).map((delivery) => delivery.id);

    let stops: StopRow[] = [];
    let promises: PromiseRow[] = [];
    let manifests: ManifestRow[] = [];
    let items: ManifestItemRow[] = [];
    if (deliveryIds.length) {
      const [stopResult, promiseResult, manifestResult] = await Promise.all([
        this.admin.from("delivery_stops").select("id, delivery_id, state, destination_version").in("delivery_id", deliveryIds).returns<StopRow[]>(),
        this.admin.from("delivery_promises").select("delivery_id, window_start, window_end").in("delivery_id", deliveryIds).returns<PromiseRow[]>(),
        this.admin.from("manifests").select("id, delivery_id, version").in("delivery_id", deliveryIds).returns<ManifestRow[]>(),
      ]);
      if (stopResult.error) throw stopResult.error;
      if (promiseResult.error) throw promiseResult.error;
      if (manifestResult.error) throw manifestResult.error;
      stops = stopResult.data ?? [];
      promises = promiseResult.data ?? [];
      manifests = manifestResult.data ?? [];
      if (manifests.length) {
        const itemResult = await this.admin.from("manifest_items")
          .select("manifest_id, line_number, description, quantity, handling_note")
          .in("manifest_id", manifests.map((manifest) => manifest.id))
          .order("line_number")
          .returns<ManifestItemRow[]>();
        if (itemResult.error) throw itemResult.error;
        items = itemResult.data ?? [];
      }
    }
    const stopByDelivery = new Map(stops.map((stop) => [stop.delivery_id, stop]));
    const promiseByDelivery = new Map(promises.map((promise) => [promise.delivery_id, promise]));
    const manifestByDelivery = new Map(manifests.map((manifest) => [manifest.delivery_id, manifest]));

    return {
      tenantId: actor.tenantId,
      drivers: profiles.map((profile) => ({
        id: profile.id,
        displayName: personById.get(profile.person_id)?.display_name ?? "Team driver",
        ...(profile.vehicle_label ? { vehicleLabel: profile.vehicle_label } : {}),
        ...(profile.vehicle_plate ? { vehiclePlate: profile.vehicle_plate } : {}),
      })).sort((a, b) => a.displayName.localeCompare(b.displayName)),
      unplannedDeliveries: (deliveries ?? []).flatMap((delivery) => {
        const stop = stopByDelivery.get(delivery.id);
        const promise = promiseByDelivery.get(delivery.id);
        const manifest = manifestByDelivery.get(delivery.id);
        if (!stop || !promise || !manifest) return [];
        const summary = items
          .filter((item) => item.manifest_id === manifest.id)
          .map((item) => `${item.quantity}× ${item.description}`)
          .join(", ");
        return [{
          deliveryId: delivery.id,
          stopId: stop.id,
          reference: delivery.reference,
          serviceDate: delivery.service_date,
          pickupLocationId: delivery.pickup_location_id,
          recipientName: delivery.recipient_name,
          rawAddress: delivery.destination_raw_address,
          windowStart: promise.window_start,
          windowEnd: promise.window_end,
          manifestSummary: summary || "Manifest ready",
        }];
      }),
    };
  }

  async planRound(command: PlanRoundCommand, actor: ActorContext): Promise<PlanRoundResult> {
    const { data, error } = await this.admin.rpc("plan_and_approve_round_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as PlanRoundResult;
  }

  async getDriverSession(identity: AuthenticatedIdentity): Promise<DriverSession | null> {
    const { data: linked, error: linkedError } = await this.admin.from("auth_identities")
      .select("person_id").eq("auth_user_id", identity.authUserId).maybeSingle<{ person_id: string }>();
    if (linkedError) throw linkedError;
    if (!linked) return null;

    const [{ data: person, error: personError }, { data: driver, error: driverError }] = await Promise.all([
      this.admin.from("persons").select("id, display_name").eq("id", linked.person_id).maybeSingle<PersonRow>(),
      this.admin.from("driver_profiles").select("id, person_id, preferred_locale, vehicle_label, vehicle_plate")
        .eq("person_id", linked.person_id).eq("active", true).is("deleted_at", null).maybeSingle<DriverProfileRow>(),
    ]);
    if (personError) throw personError;
    if (driverError) throw driverError;
    if (!person || !driver) return null;

    const { data: relationship, error: relationshipError } = await this.admin.from("driver_tenant_relationships")
      .select("tenant_id, driver_id").eq("driver_id", driver.id).eq("relationship_kind", "team")
      .eq("status", "active").is("deleted_at", null).limit(1).maybeSingle<DriverRelationshipRow>();
    if (relationshipError) throw relationshipError;
    if (!relationship) return null;

    const { data: tenant, error: tenantError } = await this.admin.from("tenants")
      .select("id, display_name, timezone").eq("id", relationship.tenant_id).eq("status", "active")
      .is("deleted_at", null).maybeSingle<TenantRow>();
    if (tenantError) throw tenantError;
    if (!tenant) return null;

    const session: DriverSession = {
      user: { id: identity.authUserId, displayName: person.display_name },
      driver: {
        id: driver.id,
        preferredLocale: driver.preferred_locale,
        ...(driver.vehicle_label ? { vehicleLabel: driver.vehicle_label } : {}),
        ...(driver.vehicle_plate ? { vehiclePlate: driver.vehicle_plate } : {}),
      },
    };

    const { data: round, error: roundError } = await this.admin.from("rounds")
      .select("id, tenant_id, reference, service_date, state, version")
      .eq("tenant_id", tenant.id).eq("driver_id", driver.id)
      .in("state", ["approved", "loading", "active"])
      .is("deleted_at", null).order("service_date").order("created_at").limit(1).maybeSingle<RoundRow>();
    if (roundError) throw roundError;
    if (!round) return session;

    const { data: roundStops, error: roundStopsError } = await this.admin.from("round_stops")
      .select("stop_id, sequence").eq("round_id", round.id).order("sequence").returns<RoundStopRow[]>();
    if (roundStopsError) throw roundStopsError;
    const stopIds = (roundStops ?? []).map((entry) => entry.stop_id);
    if (!stopIds.length) return session;

    const { data: stops, error: stopsError } = await this.admin.from("delivery_stops")
      .select("id, delivery_id, state, destination_version").in("id", stopIds).returns<StopRow[]>();
    if (stopsError) throw stopsError;
    const deliveryIds = (stops ?? []).map((stop) => stop.delivery_id);
    const [deliveryResult, promiseResult, manifestResult] = await Promise.all([
      this.admin.from("deliveries")
        .select("id, reference, service_date, pickup_location_id, recipient_name, recipient_phone, destination_raw_address, destination_position, access_note, delivery_note, is_surprise")
        .in("id", deliveryIds).returns<DeliveryRow[]>(),
      this.admin.from("delivery_promises").select("delivery_id, window_start, window_end").in("delivery_id", deliveryIds).returns<PromiseRow[]>(),
      this.admin.from("manifests").select("id, delivery_id, version").in("delivery_id", deliveryIds).returns<ManifestRow[]>(),
    ]);
    if (deliveryResult.error) throw deliveryResult.error;
    if (promiseResult.error) throw promiseResult.error;
    if (manifestResult.error) throw manifestResult.error;
    const deliveries = deliveryResult.data ?? [];
    const manifests = manifestResult.data ?? [];
    const itemResult = await this.admin.from("manifest_items")
      .select("manifest_id, line_number, description, quantity, handling_note")
      .in("manifest_id", manifests.map((manifest) => manifest.id)).order("line_number").returns<ManifestItemRow[]>();
    if (itemResult.error) throw itemResult.error;
    const pickupId = deliveries[0]?.pickup_location_id;
    if (!pickupId) return session;
    const { data: pickup, error: pickupError } = await this.admin.from("tenant_locations")
      .select("id, tenant_id, code, display_name, raw_address, pickup_contact_name, pickup_contact_phone, position")
      .eq("id", pickupId).maybeSingle<LocationRow & { position: unknown }>();
    if (pickupError) throw pickupError;
    if (!pickup) return session;

    const stopById = new Map((stops ?? []).map((stop) => [stop.id, stop]));
    const deliveryById = new Map(deliveries.map((delivery) => [delivery.id, delivery]));
    const promiseByDelivery = new Map((promiseResult.data ?? []).map((promise) => [promise.delivery_id, promise]));
    const manifestByDelivery = new Map(manifests.map((manifest) => [manifest.delivery_id, manifest]));
    const driverStops: DriverRoundStop[] = (roundStops ?? []).flatMap((entry) => {
      const stop = stopById.get(entry.stop_id);
      const delivery = stop ? deliveryById.get(stop.delivery_id) : undefined;
      const promise = delivery ? promiseByDelivery.get(delivery.id) : undefined;
      const manifest = delivery ? manifestByDelivery.get(delivery.id) : undefined;
      const coordinate = delivery ? parseDatabasePoint(delivery.destination_position) : undefined;
      if (!stop || !delivery || !promise || !manifest || !coordinate) return [];
      return [{
        id: stop.id,
        sequence: entry.sequence,
        state: stop.state,
        destinationVersion: stop.destination_version,
        deliveryId: delivery.id,
        deliveryReference: delivery.reference,
        recipientName: delivery.recipient_name,
        recipientPhone: delivery.recipient_phone,
        rawAddress: delivery.destination_raw_address,
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        ...(delivery.access_note ? { accessNote: delivery.access_note } : {}),
        ...(delivery.delivery_note ? { deliveryNote: delivery.delivery_note } : {}),
        isSurprise: delivery.is_surprise,
        windowStart: promise.window_start,
        windowEnd: promise.window_end,
        manifestId: manifest.id,
        manifestVersion: manifest.version,
        manifestItems: (itemResult.data ?? []).filter((item) => item.manifest_id === manifest.id).map((item) => ({
          lineNumber: item.line_number,
          description: item.description,
          quantity: item.quantity,
          ...(item.handling_note ? { handlingNote: item.handling_note } : {}),
        })),
      }];
    });
    const pickupCoordinate = parseDatabasePoint(pickup.position);
    session.currentRound = {
      id: round.id,
      reference: round.reference,
      serviceDate: round.service_date,
      state: round.state,
      version: round.version,
      tenant: { id: tenant.id, displayName: tenant.display_name, timezone: tenant.timezone },
      pickup: {
        id: pickup.id,
        displayName: pickup.display_name,
        rawAddress: pickup.raw_address,
        contactName: pickup.pickup_contact_name,
        contactPhone: pickup.pickup_contact_phone,
        ...(pickupCoordinate ? pickupCoordinate : {}),
      },
      stops: driverStops,
    };
    return session;
  }

  async ready(): Promise<boolean> {
    const { error } = await this.admin.from("tenants").select("id", { head: true, count: "exact" }).limit(1);
    return !error;
  }
}
