import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createHash } from "node:crypto";
import type {
  AuthenticatedIdentity,
  ActorContext,
  DeliveryCommandGateway,
  DriverCommunicationsGateway,
  DriverStopGateway,
  IdentityGateway,
  OperationsRole,
  PickupGateway,
  RoundGateway,
  OperationsHistoryGateway,
  OperationsActionGateway,
  OperationsDeliveriesGateway,
  OperationsRoundDetailGateway,
  OperationsCommunicationsGateway,
  PodGateway,
} from "./types.js";
import type {
  ConfirmDeliveryReturnCommand,
  ConfirmDeliveryReturnResult,
  CreateDeliveryCommand,
  CreateDeliveryResult,
  ConfirmPickupCommand,
  ConfirmPickupResult,
  ConfirmStopArrivalCommand,
  ConfirmStopArrivalResult,
  CompleteStopPodCommand,
  CompleteStopPodResult,
  DriverRoundStop,
  DriverSession,
  DriverOperationsThread,
  OperationsLocation,
  OperationsPlanningProjection,
  OperationsHistoryProjection,
  OperationsActionProjection,
  OperationsDeliveriesProjection,
  OperationsRoundDetail,
  OperationsCommunicationThread,
  OperationsCommunicationsProjection,
  OperationsSession,
  OperationsTenant,
  PlanRoundCommand,
  PlanRoundResult,
  RoundState,
  ReportPickupProblemCommand,
  ReportPickupProblemResult,
  ResolveOperationsExceptionCommand,
  ResolveOperationsExceptionResult,
  SendDriverMessageCommand,
  SendDriverMessageResult,
  SendOperationsMessageCommand,
  SendOperationsMessageResult,
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
type StopRow = { id: string; delivery_id: string; state: string; version: number; destination_version: number };
type PromiseRow = { delivery_id: string; window_start: string; window_end: string };
type ManifestRow = { id: string; delivery_id: string; version: number };
type ManifestItemRow = { manifest_id: string; line_number: number; description: string; quantity: number; handling_note: string | null };
type RoundRow = { id: string; tenant_id: string; reference: string; service_date: string; state: RoundState; version: number };
type RoundStopRow = { stop_id: string; sequence: number };
type PlanningRoundStopRow = { round_id: string; stop_id: string };
type PickupVerificationRow = { round_id: string; stop_id: string };
type DeliveryExceptionRow = { round_id: string };
type DriverPositionRow = { driver_id: string; position: unknown; captured_at: string };

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

export class SupabaseGateway implements IdentityGateway, DeliveryCommandGateway, RoundGateway, PickupGateway, DriverStopGateway, DriverCommunicationsGateway, OperationsCommunicationsGateway, PodGateway, OperationsHistoryGateway, OperationsActionGateway, OperationsDeliveriesGateway, OperationsRoundDetailGateway {
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

  async getOperationsDeliveries(actor: ActorContext, observedAt: Date): Promise<OperationsDeliveriesProjection> {
    type DeliveryListRow = {
      id: string; reference: string; state: OperationsDeliveriesProjection["deliveries"][number]["state"]; version: number;
      source_system: string; service_date: string; service_timezone: string; pickup_location_id: string;
      buyer_same_as_recipient: boolean; buyer_name: string; buyer_phone: string; recipient_name: string;
      recipient_phone: string; destination_raw_address: string; destination_position: unknown; access_note: string | null;
      delivery_note: string | null; is_surprise: boolean; created_at: string; updated_at: string;
    };
    type DeliveryStopListRow = { id: string; delivery_id: string; state: string; version: number };
    type ManifestListRow = { id: string; delivery_id: string; state: string; version: number };
    type RoundStopListRow = { round_id: string; stop_id: string; sequence: number };
    type DeliveryRoundRow = { id: string; reference: string; state: string; driver_id: string | null };

    const { data: deliveries, error: deliveriesError } = await this.admin.from("deliveries")
      .select("id, reference, state, version, source_system, service_date, service_timezone, pickup_location_id, buyer_same_as_recipient, buyer_name, buyer_phone, recipient_name, recipient_phone, destination_raw_address, destination_position, access_note, delivery_note, is_surprise, created_at, updated_at")
      .eq("tenant_id", actor.tenantId).is("deleted_at", null)
      .order("updated_at", { ascending: false }).limit(250).returns<DeliveryListRow[]>();
    if (deliveriesError) throw deliveriesError;
    const rows = deliveries ?? [];
    if (!rows.length) return { tenantId: actor.tenantId, observedAt: observedAt.toISOString(), deliveries: [] };

    const deliveryIds = rows.map((delivery) => delivery.id);
    const pickupIds = [...new Set(rows.map((delivery) => delivery.pickup_location_id))];
    const [stopResult, promiseResult, manifestResult, locationResult] = await Promise.all([
      this.admin.from("delivery_stops").select("id, delivery_id, state, version").eq("tenant_id", actor.tenantId).in("delivery_id", deliveryIds).returns<DeliveryStopListRow[]>(),
      this.admin.from("delivery_promises").select("delivery_id, window_start, window_end").eq("tenant_id", actor.tenantId).in("delivery_id", deliveryIds).returns<PromiseRow[]>(),
      this.admin.from("manifests").select("id, delivery_id, state, version").eq("tenant_id", actor.tenantId).in("delivery_id", deliveryIds).order("version", { ascending: false }).returns<ManifestListRow[]>(),
      this.admin.from("tenant_locations").select("id, display_name").eq("tenant_id", actor.tenantId).in("id", pickupIds).returns<{ id: string; display_name: string }[]>(),
    ]);
    if (stopResult.error) throw stopResult.error;
    if (promiseResult.error) throw promiseResult.error;
    if (manifestResult.error) throw manifestResult.error;
    if (locationResult.error) throw locationResult.error;

    const stops = stopResult.data ?? [];
    const manifests = manifestResult.data ?? [];
    const currentManifestByDelivery = new Map<string, ManifestListRow>();
    for (const manifest of manifests) if (!currentManifestByDelivery.has(manifest.delivery_id)) currentManifestByDelivery.set(manifest.delivery_id, manifest);
    const manifestIds = [...currentManifestByDelivery.values()].map((manifest) => manifest.id);
    const stopIds = stops.map((stop) => stop.id);
    const [itemResult, roundStopResult] = await Promise.all([
      manifestIds.length ? this.admin.from("manifest_items").select("manifest_id, line_number, description, quantity, handling_note").eq("tenant_id", actor.tenantId).in("manifest_id", manifestIds).order("line_number").returns<ManifestItemRow[]>() : Promise.resolve({ data: [] as ManifestItemRow[], error: null }),
      stopIds.length ? this.admin.from("round_stops").select("round_id, stop_id, sequence").eq("tenant_id", actor.tenantId).in("stop_id", stopIds).returns<RoundStopListRow[]>() : Promise.resolve({ data: [] as RoundStopListRow[], error: null }),
    ]);
    if (itemResult.error) throw itemResult.error;
    if (roundStopResult.error) throw roundStopResult.error;

    const roundStops = roundStopResult.data ?? [];
    const roundIds = [...new Set(roundStops.map((entry) => entry.round_id))];
    let rounds: DeliveryRoundRow[] = [];
    let profiles: Array<{ id: string; person_id: string }> = [];
    let people: Array<{ id: string; display_name: string }> = [];
    if (roundIds.length) {
      const roundResult = await this.admin.from("rounds").select("id, reference, state, driver_id").eq("tenant_id", actor.tenantId).in("id", roundIds).returns<DeliveryRoundRow[]>();
      if (roundResult.error) throw roundResult.error;
      rounds = roundResult.data ?? [];
      const driverIds = [...new Set(rounds.flatMap((round) => round.driver_id ? [round.driver_id] : []))];
      if (driverIds.length) {
        const profileResult = await this.admin.from("driver_profiles").select("id, person_id").in("id", driverIds).returns<Array<{ id: string; person_id: string }>>();
        if (profileResult.error) throw profileResult.error;
        profiles = profileResult.data ?? [];
        const personIds = [...new Set(profiles.map((profile) => profile.person_id))];
        if (personIds.length) {
          const personResult = await this.admin.from("persons").select("id, display_name").in("id", personIds).returns<Array<{ id: string; display_name: string }>>();
          if (personResult.error) throw personResult.error;
          people = personResult.data ?? [];
        }
      }
    }

    const stopByDelivery = new Map(stops.map((stop) => [stop.delivery_id, stop]));
    const promiseByDelivery = new Map((promiseResult.data ?? []).map((promise) => [promise.delivery_id, promise]));
    const locationById = new Map((locationResult.data ?? []).map((location) => [location.id, location.display_name]));
    const roundStopByStop = new Map(roundStops.map((entry) => [entry.stop_id, entry]));
    const roundById = new Map(rounds.map((round) => [round.id, round]));
    const personIdByDriver = new Map(profiles.map((profile) => [profile.id, profile.person_id]));
    const personById = new Map(people.map((person) => [person.id, person.display_name]));

    return {
      tenantId: actor.tenantId,
      observedAt: observedAt.toISOString(),
      deliveries: rows.flatMap((delivery) => {
        const stop = stopByDelivery.get(delivery.id);
        const promise = promiseByDelivery.get(delivery.id);
        const manifest = currentManifestByDelivery.get(delivery.id);
        if (!stop || !promise || !manifest) return [];
        const coordinate = parseDatabasePoint(delivery.destination_position);
        const roundStop = roundStopByStop.get(stop.id);
        const round = roundStop ? roundById.get(roundStop.round_id) : undefined;
        const driverName = round?.driver_id ? personById.get(personIdByDriver.get(round.driver_id) ?? "") : undefined;
        return [{
          deliveryId: delivery.id,
          reference: delivery.reference,
          state: delivery.state,
          version: delivery.version,
          sourceSystem: delivery.source_system,
          serviceDate: delivery.service_date,
          serviceTimezone: delivery.service_timezone,
          pickupLocationId: delivery.pickup_location_id,
          pickupLocationName: locationById.get(delivery.pickup_location_id) ?? "Pickup location",
          buyerSameAsRecipient: delivery.buyer_same_as_recipient,
          buyerName: delivery.buyer_name,
          buyerPhone: delivery.buyer_phone,
          recipientName: delivery.recipient_name,
          recipientPhone: delivery.recipient_phone,
          rawAddress: delivery.destination_raw_address,
          ...(coordinate ? { coordinate } : {}),
          ...(delivery.access_note ? { accessNote: delivery.access_note } : {}),
          ...(delivery.delivery_note ? { deliveryNote: delivery.delivery_note } : {}),
          isSurprise: delivery.is_surprise,
          createdAt: delivery.created_at,
          updatedAt: delivery.updated_at,
          stop: { id: stop.id, state: stop.state, version: stop.version },
          promise: { windowStart: promise.window_start, windowEnd: promise.window_end },
          manifest: {
            id: manifest.id,
            state: manifest.state,
            version: manifest.version,
            items: (itemResult.data ?? []).filter((item) => item.manifest_id === manifest.id).map((item) => ({ lineNumber: item.line_number, description: item.description, quantity: item.quantity, ...(item.handling_note ? { handlingNote: item.handling_note } : {}) })),
          },
          ...(round && roundStop ? { round: { id: round.id, reference: round.reference, state: round.state, sequence: roundStop.sequence, driverName: driverName ?? "Team driver" } } : {}),
        }];
      }),
    };
  }

  async getOperationsRoundDetail(roundId: string, actor: ActorContext, observedAt: Date): Promise<OperationsRoundDetail | null> {
    type DetailRoundRow = RoundRow & { driver_id: string | null };
    type DetailRoundStopRow = { stop_id: string; sequence: number };
    type DetailStopRow = StopRow & { arrived_at: string | null; completed_at: string | null };
    type DetailDeliveryRow = {
      id: string; reference: string; state: string; pickup_location_id: string; recipient_name: string;
      recipient_phone: string; destination_raw_address: string; destination_position: unknown;
    };
    type DetailManifestRow = ManifestRow & { state: string };
    type DetailVerificationRow = { stop_id: string };
    type DetailExceptionRow = { stop_id: string };
    type DetailThreadRow = { id: string; stop_id: string; updated_at: string };

    const { data: round, error: roundError } = await this.admin.from("rounds")
      .select("id, tenant_id, reference, service_date, state, version, driver_id")
      .eq("tenant_id", actor.tenantId).eq("id", roundId).is("deleted_at", null)
      .maybeSingle<DetailRoundRow>();
    if (roundError) throw roundError;
    if (!round) return null;

    const { data: roundStops, error: roundStopsError } = await this.admin.from("round_stops")
      .select("stop_id, sequence").eq("tenant_id", actor.tenantId).eq("round_id", roundId)
      .order("sequence").returns<DetailRoundStopRow[]>();
    if (roundStopsError) throw roundStopsError;
    const ordered = roundStops ?? [];
    const stopIds = ordered.map((entry) => entry.stop_id);

    let driver: OperationsRoundDetail["driver"] = { id: round.driver_id ?? "", displayName: "Unassigned driver" };
    let currentPosition: OperationsRoundDetail["currentPosition"];
    if (round.driver_id) {
      const [profileResult, positionResult] = await Promise.all([
        this.admin.from("driver_profiles").select("id, person_id, vehicle_label, vehicle_plate")
          .eq("id", round.driver_id).is("deleted_at", null)
          .maybeSingle<{ id: string; person_id: string; vehicle_label: string | null; vehicle_plate: string | null }>(),
        this.admin.from("driver_position_current").select("driver_id, position, captured_at")
          .eq("tenant_id", actor.tenantId).eq("driver_id", round.driver_id)
          .maybeSingle<DriverPositionRow>(),
      ]);
      if (profileResult.error) throw profileResult.error;
      if (positionResult.error) throw positionResult.error;
      if (profileResult.data) {
        const { data: person, error: personError } = await this.admin.from("persons")
          .select("id, display_name").eq("id", profileResult.data.person_id).is("deleted_at", null)
          .maybeSingle<PersonRow>();
        if (personError) throw personError;
        driver = {
          id: profileResult.data.id,
          displayName: person?.display_name ?? "Team driver",
          ...(profileResult.data.vehicle_label ? { vehicleLabel: profileResult.data.vehicle_label } : {}),
          ...(profileResult.data.vehicle_plate ? { vehiclePlate: profileResult.data.vehicle_plate } : {}),
        };
      }
      if (positionResult.data) {
        const coordinate = parseDatabasePoint(positionResult.data.position);
        if (coordinate) currentPosition = { ...coordinate, capturedAt: positionResult.data.captured_at };
      }
    }

    if (!stopIds.length) return {
      tenantId: actor.tenantId, observedAt: observedAt.toISOString(), id: round.id, reference: round.reference,
      serviceDate: round.service_date, state: round.state, version: round.version, driver,
      pickup: { id: "", displayName: "Pickup not assigned" }, stops: [], custodyStopCount: 0, openExceptionCount: 0,
      ...(currentPosition ? { currentPosition } : {}),
    };

    const [stopResult, verificationResult, exceptionResult, threadResult] = await Promise.all([
      this.admin.from("delivery_stops").select("id, delivery_id, state, version, destination_version, arrived_at, completed_at")
        .eq("tenant_id", actor.tenantId).in("id", stopIds).returns<DetailStopRow[]>(),
      this.admin.from("manifest_verifications").select("stop_id").eq("tenant_id", actor.tenantId)
        .eq("round_id", roundId).eq("stage", "pickup").returns<DetailVerificationRow[]>(),
      this.admin.from("delivery_exceptions").select("stop_id").eq("tenant_id", actor.tenantId)
        .eq("round_id", roundId).eq("status", "open").returns<DetailExceptionRow[]>(),
      this.admin.from("operations_threads").select("id, stop_id, updated_at").eq("tenant_id", actor.tenantId)
        .eq("round_id", roundId).order("updated_at", { ascending: false }).returns<DetailThreadRow[]>(),
    ]);
    if (stopResult.error) throw stopResult.error;
    if (verificationResult.error) throw verificationResult.error;
    if (exceptionResult.error) throw exceptionResult.error;
    if (threadResult.error) throw threadResult.error;
    const stops = stopResult.data ?? [];
    const deliveryIds = [...new Set(stops.map((stop) => stop.delivery_id))];

    const [deliveryResult, promiseResult, manifestResult] = await Promise.all([
      this.admin.from("deliveries").select("id, reference, state, pickup_location_id, recipient_name, recipient_phone, destination_raw_address, destination_position")
        .eq("tenant_id", actor.tenantId).in("id", deliveryIds).is("deleted_at", null).returns<DetailDeliveryRow[]>(),
      this.admin.from("delivery_promises").select("delivery_id, window_start, window_end")
        .eq("tenant_id", actor.tenantId).in("delivery_id", deliveryIds).returns<PromiseRow[]>(),
      this.admin.from("manifests").select("id, delivery_id, state, version").eq("tenant_id", actor.tenantId)
        .in("delivery_id", deliveryIds).order("version", { ascending: false }).returns<DetailManifestRow[]>(),
    ]);
    if (deliveryResult.error) throw deliveryResult.error;
    if (promiseResult.error) throw promiseResult.error;
    if (manifestResult.error) throw manifestResult.error;

    const currentManifestByDelivery = new Map<string, DetailManifestRow>();
    for (const manifest of manifestResult.data ?? []) if (!currentManifestByDelivery.has(manifest.delivery_id)) currentManifestByDelivery.set(manifest.delivery_id, manifest);
    const manifestIds = [...currentManifestByDelivery.values()].map((manifest) => manifest.id);
    const itemsResult = manifestIds.length
      ? await this.admin.from("manifest_items").select("manifest_id, line_number, description, quantity, handling_note")
        .eq("tenant_id", actor.tenantId).in("manifest_id", manifestIds).order("line_number").returns<ManifestItemRow[]>()
      : { data: [] as ManifestItemRow[], error: null };
    if (itemsResult.error) throw itemsResult.error;

    const deliveries = deliveryResult.data ?? [];
    const pickupId = deliveries[0]?.pickup_location_id ?? "";
    let pickup = { id: pickupId, displayName: "Pickup location" };
    if (pickupId) {
      const { data: location, error: locationError } = await this.admin.from("tenant_locations")
        .select("id, display_name").eq("tenant_id", actor.tenantId).eq("id", pickupId)
        .maybeSingle<{ id: string; display_name: string }>();
      if (locationError) throw locationError;
      if (location) pickup = { id: location.id, displayName: location.display_name };
    }

    const stopById = new Map(stops.map((stop) => [stop.id, stop]));
    const deliveryById = new Map(deliveries.map((delivery) => [delivery.id, delivery]));
    const promiseByDelivery = new Map((promiseResult.data ?? []).map((promise) => [promise.delivery_id, promise]));
    const pickupConfirmedStops = new Set((verificationResult.data ?? []).map((entry) => entry.stop_id));
    const exceptionCountByStop = new Map<string, number>();
    for (const exception of exceptionResult.data ?? []) exceptionCountByStop.set(exception.stop_id, (exceptionCountByStop.get(exception.stop_id) ?? 0) + 1);
    const threadByStop = new Map<string, string>();
    for (const thread of threadResult.data ?? []) if (!threadByStop.has(thread.stop_id)) threadByStop.set(thread.stop_id, thread.id);

    const detailStops = ordered.flatMap((entry) => {
      const stop = stopById.get(entry.stop_id);
      const delivery = stop ? deliveryById.get(stop.delivery_id) : undefined;
      const promise = delivery ? promiseByDelivery.get(delivery.id) : undefined;
      const manifest = delivery ? currentManifestByDelivery.get(delivery.id) : undefined;
      if (!stop || !delivery || !promise || !manifest) return [];
      const coordinate = parseDatabasePoint(delivery.destination_position);
      const operationsThreadId = threadByStop.get(stop.id);
      return [{
        stopId: stop.id, sequence: entry.sequence, stopState: stop.state, stopVersion: stop.version,
        deliveryId: delivery.id, deliveryReference: delivery.reference, deliveryState: delivery.state,
        recipientName: delivery.recipient_name, recipientPhone: delivery.recipient_phone,
        rawAddress: delivery.destination_raw_address, ...(coordinate ? { coordinate } : {}),
        windowStart: promise.window_start, windowEnd: promise.window_end,
        manifest: {
          id: manifest.id, state: manifest.state, version: manifest.version,
          items: (itemsResult.data ?? []).filter((item) => item.manifest_id === manifest.id).map((item) => ({
            lineNumber: item.line_number, description: item.description, quantity: item.quantity,
            ...(item.handling_note ? { handlingNote: item.handling_note } : {}),
          })),
        },
        pickupConfirmed: pickupConfirmedStops.has(stop.id),
        ...(stop.arrived_at ? { arrivedAt: stop.arrived_at } : {}),
        ...(stop.completed_at ? { completedAt: stop.completed_at } : {}),
        openExceptionCount: exceptionCountByStop.get(stop.id) ?? 0,
        ...(operationsThreadId ? { operationsThreadId } : {}),
      }];
    });

    return {
      tenantId: actor.tenantId, observedAt: observedAt.toISOString(), id: round.id, reference: round.reference,
      serviceDate: round.service_date, state: round.state, version: round.version, driver, pickup, stops: detailStops,
      custodyStopCount: detailStops.filter((stop) => stop.pickupConfirmed).length,
      openExceptionCount: detailStops.reduce((total, stop) => total + stop.openExceptionCount, 0),
      ...(currentPosition ? { currentPosition } : {}),
    };
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
        this.admin.from("delivery_stops").select("id, delivery_id, state, version, destination_version").in("delivery_id", deliveryIds).returns<StopRow[]>(),
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

    const { data: activeRounds, error: activeRoundsError } = await this.admin.from("rounds")
      .select("id, tenant_id, reference, service_date, state, version, driver_id")
      .eq("tenant_id", actor.tenantId).in("state", ["approved", "loading", "active"])
      .is("deleted_at", null).order("service_date").order("created_at")
      .returns<(RoundRow & { driver_id: string })[]>();
    if (activeRoundsError) throw activeRoundsError;
    const activeRoundIds = (activeRounds ?? []).map((round) => round.id);
    const activeDriverIds = [...new Set((activeRounds ?? []).map((round) => round.driver_id))];
    let planningRoundStops: PlanningRoundStopRow[] = [];
    let pickupVerifications: PickupVerificationRow[] = [];
    let deliveryExceptions: DeliveryExceptionRow[] = [];
    let driverPositions: DriverPositionRow[] = [];
    if (activeRoundIds.length) {
      const [roundStopResult, verificationResult, exceptionResult, positionResult] = await Promise.all([
        this.admin.from("round_stops").select("round_id, stop_id").in("round_id", activeRoundIds)
          .returns<PlanningRoundStopRow[]>(),
        this.admin.from("manifest_verifications").select("round_id, stop_id")
          .in("round_id", activeRoundIds).eq("stage", "pickup").returns<PickupVerificationRow[]>(),
        this.admin.from("delivery_exceptions").select("round_id")
          .in("round_id", activeRoundIds).eq("status", "open").returns<DeliveryExceptionRow[]>(),
        this.admin.from("driver_position_current").select("driver_id, position, captured_at")
          .eq("tenant_id", actor.tenantId).in("driver_id", activeDriverIds).returns<DriverPositionRow[]>(),
      ]);
      if (roundStopResult.error) throw roundStopResult.error;
      if (verificationResult.error) throw verificationResult.error;
      if (exceptionResult.error) throw exceptionResult.error;
      if (positionResult.error) throw positionResult.error;
      planningRoundStops = roundStopResult.data ?? [];
      pickupVerifications = verificationResult.data ?? [];
      deliveryExceptions = exceptionResult.data ?? [];
      driverPositions = positionResult.data ?? [];
    }
    const profileById = new Map(profiles.map((profile) => [profile.id, profile]));
    const positionByDriver = new Map(driverPositions.flatMap((row) => {
      const coordinate = parseDatabasePoint(row.position);
      return coordinate ? [[row.driver_id, { ...coordinate, capturedAt: row.captured_at }] as const] : [];
    }));

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
        const coordinate = parseDatabasePoint(delivery.destination_position);
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
          ...(coordinate ? { coordinate } : {}),
          windowStart: promise.window_start,
          windowEnd: promise.window_end,
          manifestSummary: summary || "Manifest ready",
        }];
      }),
      activeRounds: (activeRounds ?? []).map((round) => {
        const profile = profileById.get(round.driver_id);
        const currentPosition = positionByDriver.get(round.driver_id);
        return {
          id: round.id,
          reference: round.reference,
          serviceDate: round.service_date,
          state: round.state,
          driverId: round.driver_id,
          driverName: profile ? personById.get(profile.person_id)?.display_name ?? "Team driver" : "Team driver",
          stopCount: planningRoundStops.filter((stop) => stop.round_id === round.id).length,
          custodyStopCount: pickupVerifications.filter((verification) => verification.round_id === round.id).length,
          openExceptionCount: deliveryExceptions.filter((exception) => exception.round_id === round.id).length,
          ...(currentPosition ? { currentPosition } : {}),
        };
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

  async confirmPickup(
    command: ConfirmPickupCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ConfirmPickupResult> {
    const { data: linked, error: linkedError } = await this.admin.from("auth_identities")
      .select("person_id").eq("auth_user_id", identity.authUserId).maybeSingle<{ person_id: string }>();
    if (linkedError) throw linkedError;
    if (!linked) return { status: "rejected", error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" } };
    const { data, error } = await this.admin.rpc("confirm_round_pickup_command", {
      p_command: command,
      p_actor_person_id: linked.person_id,
    });
    if (error) throw error;
    return data as ConfirmPickupResult;
  }

  async reportPickupProblem(
    command: ReportPickupProblemCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ReportPickupProblemResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("report_pickup_problem_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as ReportPickupProblemResult;
  }

  async confirmStopArrival(
    command: ConfirmStopArrivalCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ConfirmStopArrivalResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("confirm_stop_arrival_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as ConfirmStopArrivalResult;
  }

  async getDriverOperationsThread(
    roundId: string,
    stopId: string,
    identity: AuthenticatedIdentity,
  ): Promise<DriverOperationsThread | null> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return null;
    const { data, error } = await this.admin.rpc("ensure_driver_operations_thread", {
      p_round_id: roundId,
      p_stop_id: stopId,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as DriverOperationsThread | null;
  }

  async sendDriverMessage(
    command: SendDriverMessageCommand,
    identity: AuthenticatedIdentity,
  ): Promise<SendDriverMessageResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("send_driver_message_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as SendDriverMessageResult;
  }

  async getOperationsCommunications(actor: ActorContext): Promise<OperationsCommunicationsProjection> {
    type ThreadRow = {
      id: string; round_id: string; stop_id: string; driver_id: string;
      version: number; updated_at: string;
    };
    const { data: threads, error: threadsError } = await this.admin.from("operations_threads")
      .select("id, round_id, stop_id, driver_id, version, updated_at")
      .eq("tenant_id", actor.tenantId).order("updated_at", { ascending: false }).returns<ThreadRow[]>();
    if (threadsError) throw threadsError;
    if (!threads?.length) return { tenantId: actor.tenantId, threads: [] };

    const threadIds = threads.map((thread) => thread.id);
    const roundIds = [...new Set(threads.map((thread) => thread.round_id))];
    const stopIds = [...new Set(threads.map((thread) => thread.stop_id))];
    const driverIds = [...new Set(threads.map((thread) => thread.driver_id))];
    const [roundResult, roundStopResult, stopResult, driverResult, messageResult] = await Promise.all([
      this.admin.from("rounds").select("id, reference").eq("tenant_id", actor.tenantId).in("id", roundIds)
        .returns<{ id: string; reference: string }[]>(),
      this.admin.from("round_stops").select("round_id, stop_id, sequence").eq("tenant_id", actor.tenantId)
        .in("round_id", roundIds).in("stop_id", stopIds)
        .returns<{ round_id: string; stop_id: string; sequence: number }[]>(),
      this.admin.from("delivery_stops").select("id, delivery_id").eq("tenant_id", actor.tenantId).in("id", stopIds)
        .returns<{ id: string; delivery_id: string }[]>(),
      this.admin.from("driver_profiles").select("id, person_id").in("id", driverIds)
        .returns<{ id: string; person_id: string }[]>(),
      this.admin.from("operations_messages").select("id, thread_id, sender, body, sent_at")
        .eq("tenant_id", actor.tenantId).in("thread_id", threadIds).order("sent_at")
        .returns<{ id: string; thread_id: string; sender: "driver" | "operations" | "system"; body: string; sent_at: string }[]>(),
    ]);
    if (roundResult.error) throw roundResult.error;
    if (roundStopResult.error) throw roundStopResult.error;
    if (stopResult.error) throw stopResult.error;
    if (driverResult.error) throw driverResult.error;
    if (messageResult.error) throw messageResult.error;

    const deliveryIds = (stopResult.data ?? []).map((stop) => stop.delivery_id);
    const personIds = (driverResult.data ?? []).map((driver) => driver.person_id);
    const [deliveryResult, peopleResult] = await Promise.all([
      this.admin.from("deliveries").select("id, reference, recipient_name, destination_raw_address")
        .eq("tenant_id", actor.tenantId).in("id", deliveryIds)
        .returns<{ id: string; reference: string; recipient_name: string; destination_raw_address: string }[]>(),
      this.admin.from("persons").select("id, display_name").in("id", personIds)
        .returns<{ id: string; display_name: string }[]>(),
    ]);
    if (deliveryResult.error) throw deliveryResult.error;
    if (peopleResult.error) throw peopleResult.error;

    const roundById = new Map((roundResult.data ?? []).map((round) => [round.id, round]));
    const sequenceByKey = new Map((roundStopResult.data ?? []).map((entry) => [`${entry.round_id}:${entry.stop_id}`, entry.sequence]));
    const stopById = new Map((stopResult.data ?? []).map((stop) => [stop.id, stop]));
    const deliveryById = new Map((deliveryResult.data ?? []).map((delivery) => [delivery.id, delivery]));
    const personById = new Map((peopleResult.data ?? []).map((person) => [person.id, person]));
    const driverById = new Map((driverResult.data ?? []).map((driver) => [driver.id, driver]));
    const messages = messageResult.data ?? [];

    return {
      tenantId: actor.tenantId,
      threads: threads.flatMap((thread): OperationsCommunicationThread[] => {
        const round = roundById.get(thread.round_id);
        const stop = stopById.get(thread.stop_id);
        const delivery = stop ? deliveryById.get(stop.delivery_id) : undefined;
        const driver = driverById.get(thread.driver_id);
        if (!round || !stop || !delivery || !driver) return [];
        return [{
          id: thread.id,
          roundId: thread.round_id,
          roundReference: round.reference,
          stopId: thread.stop_id,
          stopSequence: sequenceByKey.get(`${thread.round_id}:${thread.stop_id}`) ?? 0,
          deliveryId: delivery.id,
          deliveryReference: delivery.reference,
          recipientName: delivery.recipient_name,
          rawAddress: delivery.destination_raw_address,
          driverId: thread.driver_id,
          driverName: personById.get(driver.person_id)?.display_name ?? "Team driver",
          version: thread.version,
          updatedAt: thread.updated_at,
          messages: messages.filter((message) => message.thread_id === thread.id).map((message) => ({
            id: message.id,
            sender: message.sender,
            body: message.body,
            sentAt: message.sent_at,
          })),
        }];
      }),
    };
  }

  async getOperationsCommunicationThread(
    threadId: string,
    actor: ActorContext,
  ): Promise<OperationsCommunicationThread | null> {
    const projection = await this.getOperationsCommunications(actor);
    return projection.threads.find((thread) => thread.id === threadId) ?? null;
  }

  async sendOperationsMessage(
    command: SendOperationsMessageCommand,
    actor: ActorContext,
  ): Promise<SendOperationsMessageResult> {
    const { data, error } = await this.admin.rpc("send_operations_message_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as SendOperationsMessageResult;
  }

  async preparePodMedia(
    stopId: string,
    identity: AuthenticatedIdentity,
    assetId: string,
    sha256: string,
    byteSize: number,
    contentType: string,
  ): Promise<Record<string, unknown>> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("prepare_pod_media_asset", {
      p_stop_id: stopId,
      p_actor_person_id: actorPersonId,
      p_asset_id: assetId,
      p_sha256: sha256,
      p_size: byteSize,
      p_content_type: contentType,
    });
    if (error) throw error;
    const prepared = data as Record<string, unknown>;
    if (prepared.status !== "prepared") return prepared;
    const projectRef = new URL(this.url).hostname.split(".")[0];
    return {
      ...prepared,
      tusEndpoint: `https://${projectRef}.storage.supabase.co/storage/v1/upload/resumable`,
      uploadAuthorization: "driver_session",
    };
  }

  async verifyPodMedia(assetId: string, identity: AuthenticatedIdentity): Promise<Record<string, unknown>> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data: asset, error: assetError } = await this.admin.from("media_assets")
      .select("id, storage_bucket, storage_path, state, driver_id, expected_sha256, expected_size")
      .eq("id", assetId).maybeSingle<{
        id: string; storage_bucket: string; storage_path: string; state: string; driver_id: string;
        expected_sha256: string; expected_size: number;
      }>();
    if (assetError) throw assetError;
    if (!asset) return { status: "rejected", error: { code: "EVIDENCE_REQUIRED", message: "Photo asset was not prepared" } };
    const { data: driver, error: driverError } = await this.admin.from("driver_profiles")
      .select("person_id").eq("id", asset.driver_id).maybeSingle<{ person_id: string }>();
    if (driverError) throw driverError;
    if (driver?.person_id !== actorPersonId) return {
      status: "rejected", error: { code: "NOT_AUTHORIZED", message: "Photo asset is not owned by this driver" },
    };
    if (asset.state === "committed" || asset.state === "uploaded_uncommitted") {
      return { status: "verified", mediaAssetId: asset.id, assetState: asset.state };
    }
    const downloaded = await this.admin.storage.from(asset.storage_bucket).download(asset.storage_path);
    if (downloaded.error || !downloaded.data) return {
      status: "rejected", error: { code: "EVIDENCE_REQUIRED", message: "Photo upload is not complete yet" },
    };
    const bytes = Buffer.from(await downloaded.data.arrayBuffer());
    const verifiedSha256 = createHash("sha256").update(bytes).digest("hex");
    const { data, error } = await this.admin.rpc("mark_pod_media_uploaded", {
      p_asset_id: assetId,
      p_actor_person_id: actorPersonId,
      p_verified_sha256: verifiedSha256,
      p_verified_size: bytes.byteLength,
    });
    if (error) throw error;
    return data as Record<string, unknown>;
  }

  async completeStopPod(
    command: CompleteStopPodCommand,
    identity: AuthenticatedIdentity,
  ): Promise<CompleteStopPodResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("complete_stop_pod_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as CompleteStopPodResult;
  }

  async getOperationsHistory(actor: ActorContext): Promise<OperationsHistoryProjection> {
    type PodRow = {
      id: string; delivery_id: string; stop_id: string; round_id: string; driver_id: string;
      media_asset_id: string; handoff_type: "recipient" | "someone_else" | "left_at_location";
      receiver_name: string | null; receiver_relationship: string | null; left_at_location: string | null;
      delivered_at: string; manifest_version: number;
    };
    const { data: pods, error: podsError } = await this.admin.from("pod_records")
      .select("id, delivery_id, stop_id, round_id, driver_id, media_asset_id, handoff_type, receiver_name, receiver_relationship, left_at_location, delivered_at, manifest_version")
      .eq("tenant_id", actor.tenantId).order("delivered_at", { ascending: false }).limit(100).returns<PodRow[]>();
    if (podsError) throw podsError;
    if (!pods?.length) return { tenantId: actor.tenantId, deliveries: [] };
    const deliveryIds = [...new Set(pods.map((pod) => pod.delivery_id))];
    const roundIds = [...new Set(pods.map((pod) => pod.round_id))];
    const driverIds = [...new Set(pods.map((pod) => pod.driver_id))];
    const mediaIds = [...new Set(pods.map((pod) => pod.media_asset_id))];
    const [deliveryResult, roundResult, driverResult, mediaResult] = await Promise.all([
      this.admin.from("deliveries").select("id, reference, recipient_name, destination_raw_address").in("id", deliveryIds)
        .returns<{ id: string; reference: string; recipient_name: string; destination_raw_address: string }[]>(),
      this.admin.from("rounds").select("id, reference").in("id", roundIds).returns<{ id: string; reference: string }[]>(),
      this.admin.from("driver_profiles").select("id, person_id").in("id", driverIds).returns<{ id: string; person_id: string }[]>(),
      this.admin.from("media_assets").select("id, state").in("id", mediaIds).eq("state", "committed")
        .returns<{ id: string; state: "committed" }[]>(),
    ]);
    if (deliveryResult.error) throw deliveryResult.error;
    if (roundResult.error) throw roundResult.error;
    if (driverResult.error) throw driverResult.error;
    if (mediaResult.error) throw mediaResult.error;
    const personIds = (driverResult.data ?? []).map((driver) => driver.person_id);
    const { data: people, error: peopleError } = await this.admin.from("persons")
      .select("id, display_name").in("id", personIds).returns<{ id: string; display_name: string }[]>();
    if (peopleError) throw peopleError;
    const deliveryById = new Map((deliveryResult.data ?? []).map((row) => [row.id, row]));
    const roundById = new Map((roundResult.data ?? []).map((row) => [row.id, row]));
    const personById = new Map((people ?? []).map((row) => [row.id, row]));
    const personIdByDriver = new Map((driverResult.data ?? []).map((row) => [row.id, row.person_id]));
    const committedMedia = new Set((mediaResult.data ?? []).map((row) => row.id));
    return {
      tenantId: actor.tenantId,
      deliveries: pods.flatMap((pod) => {
        const delivery = deliveryById.get(pod.delivery_id);
        const round = roundById.get(pod.round_id);
        if (!delivery || !round || !committedMedia.has(pod.media_asset_id)) return [];
        const receiverLabel = pod.handoff_type === "left_at_location"
          ? pod.left_at_location ?? "Approved location"
          : pod.receiver_relationship
            ? `${pod.receiver_name ?? "Receiver"} · ${pod.receiver_relationship}`
            : pod.receiver_name ?? delivery.recipient_name;
        return [{
          podId: pod.id,
          deliveryId: pod.delivery_id,
          stopId: pod.stop_id,
          roundId: pod.round_id,
          deliveryReference: delivery.reference,
          roundReference: round.reference,
          recipientName: delivery.recipient_name,
          rawAddress: delivery.destination_raw_address,
          driverName: personById.get(personIdByDriver.get(pod.driver_id) ?? "")?.display_name ?? "Team driver",
          handoffType: pod.handoff_type,
          receiverLabel,
          deliveredAt: pod.delivered_at,
          manifestVersion: pod.manifest_version,
          verifiedPhotoCount: 1 as const,
          mediaAssetId: pod.media_asset_id,
          mediaState: "committed" as const,
        }];
      }),
    };
  }

  async getOperationsAction(actor: ActorContext, observedAt: Date): Promise<OperationsActionProjection> {
    type ExceptionRow = {
      id: string; delivery_id: string; stop_id: string; round_id: string; driver_id: string;
      stage: "pickup" | "delivery"; category: "missing_item" | "wrong_item" | "damaged_item";
      note: string | null; status: "open"; manifest_version: number; reported_at: string;
    };
    const [planning, exceptionResult] = await Promise.all([
      this.getOperationsPlanning(actor),
      this.admin.from("delivery_exceptions")
        .select("id, delivery_id, stop_id, round_id, driver_id, stage, category, note, status, manifest_version, reported_at")
        .eq("tenant_id", actor.tenantId).eq("status", "open")
        .order("reported_at", { ascending: false }).limit(100).returns<ExceptionRow[]>(),
    ]);
    if (exceptionResult.error) throw exceptionResult.error;
    const exceptions = exceptionResult.data ?? [];
    if (!exceptions.length) return {
      tenantId: actor.tenantId,
      observedAt: observedAt.toISOString(),
      rounds: planning.activeRounds,
      exceptions: [],
    };

    const deliveryIds = [...new Set(exceptions.map((item) => item.delivery_id))];
    const stopIds = [...new Set(exceptions.map((item) => item.stop_id))];
    const roundIds = [...new Set(exceptions.map((item) => item.round_id))];
    const driverIds = [...new Set(exceptions.map((item) => item.driver_id))];
    const [deliveryResult, stopResult, roundResult, roundStopResult, driverResult, threadResult] = await Promise.all([
      this.admin.from("deliveries").select("id, reference, recipient_name, destination_raw_address, destination_position")
        .eq("tenant_id", actor.tenantId).in("id", deliveryIds)
        .returns<{ id: string; reference: string; recipient_name: string; destination_raw_address: string; destination_position: unknown }[]>(),
      this.admin.from("delivery_stops").select("id, state, version").eq("tenant_id", actor.tenantId).in("id", stopIds)
        .returns<{ id: string; state: string; version: number }[]>(),
      this.admin.from("rounds").select("id, reference, state").eq("tenant_id", actor.tenantId).in("id", roundIds)
        .returns<{ id: string; reference: string; state: string }[]>(),
      this.admin.from("round_stops").select("round_id, stop_id, sequence").eq("tenant_id", actor.tenantId)
        .in("round_id", roundIds).in("stop_id", stopIds)
        .returns<{ round_id: string; stop_id: string; sequence: number }[]>(),
      this.admin.from("driver_profiles").select("id, person_id").in("id", driverIds)
        .returns<{ id: string; person_id: string }[]>(),
      this.admin.from("operations_threads").select("id, round_id, stop_id, updated_at")
        .eq("tenant_id", actor.tenantId).in("round_id", roundIds).in("stop_id", stopIds)
        .order("updated_at", { ascending: false })
        .returns<{ id: string; round_id: string; stop_id: string; updated_at: string }[]>(),
    ]);
    if (deliveryResult.error) throw deliveryResult.error;
    if (stopResult.error) throw stopResult.error;
    if (roundResult.error) throw roundResult.error;
    if (roundStopResult.error) throw roundStopResult.error;
    if (driverResult.error) throw driverResult.error;
    if (threadResult.error) throw threadResult.error;

    const personIds = [...new Set((driverResult.data ?? []).map((driver) => driver.person_id))];
    const peopleResult = await this.admin.from("persons").select("id, display_name").in("id", personIds)
      .returns<{ id: string; display_name: string }[]>();
    if (peopleResult.error) throw peopleResult.error;
    const deliveryById = new Map((deliveryResult.data ?? []).map((row) => [row.id, row]));
    const stopById = new Map((stopResult.data ?? []).map((row) => [row.id, row]));
    const roundById = new Map((roundResult.data ?? []).map((row) => [row.id, row]));
    const sequenceByStop = new Map((roundStopResult.data ?? []).map((row) => [`${row.round_id}:${row.stop_id}`, row.sequence]));
    const personIdByDriver = new Map((driverResult.data ?? []).map((row) => [row.id, row.person_id]));
    const personById = new Map((peopleResult.data ?? []).map((row) => [row.id, row]));
    const threadByStop = new Map<string, string>();
    for (const thread of threadResult.data ?? []) {
      const key = `${thread.round_id}:${thread.stop_id}`;
      if (!threadByStop.has(key)) threadByStop.set(key, thread.id);
    }

    return {
      tenantId: actor.tenantId,
      observedAt: observedAt.toISOString(),
      rounds: planning.activeRounds,
      exceptions: exceptions.flatMap((item) => {
        const delivery = deliveryById.get(item.delivery_id);
        const stop = stopById.get(item.stop_id);
        const round = roundById.get(item.round_id);
        if (!delivery || !stop || !round) return [];
        const coordinate = parseDatabasePoint(delivery.destination_position);
        const threadId = threadByStop.get(`${item.round_id}:${item.stop_id}`);
        return [{
          id: item.id,
          deliveryId: item.delivery_id,
          deliveryReference: delivery.reference,
          recipientName: delivery.recipient_name,
          rawAddress: delivery.destination_raw_address,
          ...(coordinate ? { coordinate } : {}),
          stopId: item.stop_id,
          stopSequence: sequenceByStop.get(`${item.round_id}:${item.stop_id}`) ?? 0,
          stopState: stop.state,
          stopVersion: stop.version,
          roundId: item.round_id,
          roundReference: round.reference,
          roundState: round.state,
          driverId: item.driver_id,
          driverName: personById.get(personIdByDriver.get(item.driver_id) ?? "")?.display_name ?? "Team driver",
          stage: item.stage,
          category: item.category,
          ...(item.note ? { note: item.note } : {}),
          status: item.status,
          manifestVersion: item.manifest_version,
          reportedAt: item.reported_at,
          ...(threadId ? { operationsThreadId: threadId } : {}),
        }];
      }),
    };
  }

  async resolveOperationsException(command: ResolveOperationsExceptionCommand, actor: ActorContext): Promise<ResolveOperationsExceptionResult> {
    const { data, error } = await this.admin.rpc("resolve_operations_exception_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as ResolveOperationsExceptionResult;
  }

  async confirmDeliveryReturn(command: ConfirmDeliveryReturnCommand, actor: ActorContext): Promise<ConfirmDeliveryReturnResult> {
    const { data, error } = await this.admin.rpc("confirm_delivery_return_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as ConfirmDeliveryReturnResult;
  }

  private async driverActorPersonId(identity: AuthenticatedIdentity): Promise<string | null> {
    const { data, error } = await this.admin.from("auth_identities")
      .select("person_id").eq("auth_user_id", identity.authUserId)
      .maybeSingle<{ person_id: string }>();
    if (error) throw error;
    return data?.person_id ?? null;
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
      .select("id, delivery_id, state, version, destination_version").in("id", stopIds).returns<StopRow[]>();
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
        version: stop.version,
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
