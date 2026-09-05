import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createHash } from "node:crypto";
import type {
  AuthenticatedIdentity,
  ActorContext,
  DeliveryCommandGateway,
  DriverCommunicationsGateway,
  DriverProfileGateway,
  DriverShiftGateway,
  DriverStopGateway,
  IdentityGateway,
  OperationsRole,
  PickupGateway,
  RoundGateway,
  OperationsHistoryGateway,
  OperationsActionGateway,
  OperationsDeliveriesGateway,
  OperationsDriversGateway,
  OperationsRoundDetailGateway,
  OperationsCommunicationsGateway,
  PlanningRouteContextGateway,
  RoundMoveGateway,
  LiveDeliveryChangeGateway,
  PodGateway,
} from "./types.js";
import type {
  ConfirmDeliveryReturnCommand,
  ConfirmDeliveryReturnResult,
  ClearDriverShiftExceptionCommand,
  ClearDriverShiftExceptionResult,
  CreateDeliveryCommand,
  CreateDeliveryResult,
  ConfirmPickupCommand,
  ConfirmPickupResult,
  ConfirmStopArrivalCommand,
  ConfirmStopArrivalResult,
  CompleteStopPodCommand,
  CompleteStopPodResult,
  CommunicationThreadReadState,
  DeliveryState,
  DriverRoundStop,
  DriverSession,
  DriverOperationsThread,
  DriverThreadMessage,
  LogContactAttemptCommand,
  LogContactAttemptResult,
  OperationsLocation,
  OperationsPlanningProjection,
  OperationsHistoryProjection,
  OperationsActionProjection,
  OperationsDeliveriesProjection,
  OperationsDriversProjection,
  OperationsRoundDetail,
  MoveRoundStopCommand,
  MoveRoundStopResult,
  PlanningRouteSnapshot,
  OperationsCommunicationThread,
  OperationsCommunicationsProjection,
  OperationsSession,
  OperationsTenant,
  PlanRoundCommand,
  PlanRoundResult,
  RoundState,
  ReportPickupProblemCommand,
  ReportPickupProblemResult,
  ReportDeliveryProblemCommand,
  ReportDeliveryProblemResult,
  ReportLocationProblemCommand,
  ReportLocationProblemResult,
  ReportDriverEmergencyCommand,
  ReportDriverEmergencyResult,
  ResolveOperationsExceptionCommand,
  ResolveOperationsExceptionResult,
  SendDriverMessageCommand,
  SendDriverMessageResult,
  SendOperationsMessageCommand,
  SendOperationsMessageResult,
  PrepareMessageMediaPayload,
  SetDriverRecurringScheduleCommand,
  SetDriverRecurringScheduleResult,
  SetDriverShiftExceptionCommand,
  SetDriverShiftExceptionResult,
  ApplyLiveDeliveryChangeCommand,
  ApplyLiveDeliveryChangeResult,
  AcknowledgeLiveDeliveryChangeCommand,
  AcknowledgeLiveDeliveryChangeResult,
  DriverLiveDeliveryChange,
  StartDriverShiftCommand,
  StartDriverShiftResult,
  EndDriverShiftCommand,
  EndDriverShiftResult,
  UpdateDriverPreferredLocaleCommand,
  UpdateDriverPreferredLocaleResult,
} from "@rounds/contracts";
import { projectCurrentRoundAvailability } from "./operations-driver-availability.js";

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

type DriverProfileRow = { id: string; person_id: string; version: number; preferred_locale: string; vehicle_label: string | null; vehicle_plate: string | null };
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
type ManifestItemRow = { manifest_id: string; line_number: number; description: string; quantity: number; cargo_class: string | null; handling_note: string | null };
type RoundRow = { id: string; tenant_id: string; reference: string; service_date: string; state: RoundState; version: number };
type DriverHistoryRoundRow = RoundRow & { updated_at: string; route_plan_snapshot: PlanningRouteSnapshot | null };
type DriverHistoryRoundStopRow = { round_id: string; stop_id: string };
type DriverHistoryStopRow = { id: string; state: string };
type DriverHistoryPodRow = { round_id: string; stop_id: string };
type RoundStopRow = { stop_id: string; sequence: number };
type PlanningRoundStopRow = { round_id: string; stop_id: string };
type PickupVerificationRow = { round_id: string; stop_id: string };
type DeliveryExceptionRow = { round_id: string };
type DriverPositionRow = { driver_id: string; position: unknown; captured_at: string };

type AssignedRoundCandidate = Pick<RoundRow, "id" | "reference" | "service_date"> & {
  state: "active" | "loading" | "approved";
};

export function selectDriverAssignedRound<T extends AssignedRoundCandidate>(candidates: T[], serviceDate: string): T | undefined {
  const statePriority: Record<"active" | "loading" | "approved", number> = { active: 0, loading: 1, approved: 2 };
  const dateBucket = (candidate: T): number => candidate.service_date === serviceDate ? 0 : candidate.service_date > serviceDate ? 1 : 2;
  return [...candidates].sort((left, right) => {
    const stateDelta = statePriority[left.state] - statePriority[right.state];
    if (stateDelta) return stateDelta;
    const bucketDelta = dateBucket(left) - dateBucket(right);
    if (bucketDelta) return bucketDelta;
    return dateBucket(left) === 2
      ? right.service_date.localeCompare(left.service_date)
      : left.service_date.localeCompare(right.service_date);
  })[0];
}

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

function addCalendarDay(serviceDate: string): string {
  const value = new Date(`${serviceDate}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() + 1);
  return value.toISOString().slice(0, 10);
}

function localServiceDate(now: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat("en", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value;
  return `${value("year")}-${value("month")}-${value("day")}`;
}

function zonedLocalIso(serviceDate: string, localTime: string, timezone: string): string {
  const [year, month, day] = serviceDate.split("-").map(Number);
  const [hour, minute] = localTime.split(":").map(Number);
  const target = Date.UTC(year!, month! - 1, day!, hour!, minute!);
  let candidate = target;
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23",
  });
  for (let pass = 0; pass < 2; pass += 1) {
    const parts = Object.fromEntries(formatter.formatToParts(new Date(candidate)).map((part) => [part.type, part.value]));
    const represented = Date.UTC(Number(parts.year), Number(parts.month) - 1, Number(parts.day), Number(parts.hour), Number(parts.minute));
    candidate -= represented - target;
  }
  return new Date(candidate).toISOString();
}

function compactLocalTime(value: string): string {
  return value.slice(0, 5);
}

function localClockTime(value: string, timezone: string): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: timezone,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(value));
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((entry) => entry.type === type)?.value ?? "00";
  return `${part("hour")}:${part("minute")}`;
}

function initials(displayName: string): string {
  return displayName.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]!.toUpperCase()).join("") || "DR";
}

export class SupabaseGateway implements IdentityGateway, DeliveryCommandGateway, RoundGateway, PickupGateway, DriverStopGateway, DriverCommunicationsGateway, DriverShiftGateway, DriverProfileGateway, OperationsCommunicationsGateway, PodGateway, OperationsHistoryGateway, OperationsActionGateway, OperationsDeliveriesGateway, OperationsDriversGateway, OperationsRoundDetailGateway, PlanningRouteContextGateway, RoundMoveGateway, LiveDeliveryChangeGateway {
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
      manifestIds.length ? this.admin.from("manifest_items").select("manifest_id, line_number, description, quantity, cargo_class, handling_note").eq("tenant_id", actor.tenantId).in("manifest_id", manifestIds).order("line_number").returns<ManifestItemRow[]>() : Promise.resolve({ data: [] as ManifestItemRow[], error: null }),
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
    type DetailRoundRow = RoundRow & { driver_id: string | null; route_plan_snapshot: PlanningRouteSnapshot | null };
    type DetailRoundStopRow = { stop_id: string; sequence: number };
    type DetailStopRow = StopRow & { arrived_at: string | null; completed_at: string | null };
    type DetailDeliveryRow = {
      id: string; reference: string; state: string; pickup_location_id: string; recipient_name: string;
      recipient_phone: string; destination_raw_address: string; destination_position: unknown; access_note: string | null;
    };
    type DetailManifestRow = ManifestRow & { state: string };
    type DetailVerificationRow = { stop_id: string };
    type DetailExceptionRow = { stop_id: string };
    type DetailThreadRow = { id: string; stop_id: string; updated_at: string };
    type DetailLiveChangeRow = {
      id: string; stop_id: string; change_version: number; round_id: string; applied_at: string;
      before_state: DriverLiveDeliveryChange["before"]; after_state: DriverLiveDeliveryChange["after"];
      route_impact: DriverLiveDeliveryChange["impact"]; driver_ack_status: "pending" | "acknowledged";
      acknowledged_at: string | null;
    };

    const { data: round, error: roundError } = await this.admin.from("rounds")
      .select("id, tenant_id, reference, service_date, state, version, driver_id, route_plan_snapshot")
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
      serviceDate: round.service_date, state: round.state, version: round.version, ...(round.route_plan_snapshot ? { routePlan: round.route_plan_snapshot } : {}), driver,
      pickup: { id: "", displayName: "Pickup not assigned" }, stops: [], custodyStopCount: 0, openExceptionCount: 0,
      ...(currentPosition ? { currentPosition } : {}),
    };

    const [stopResult, verificationResult, exceptionResult, threadResult, liveChangeResult] = await Promise.all([
      this.admin.from("delivery_stops").select("id, delivery_id, state, version, destination_version, arrived_at, completed_at")
        .eq("tenant_id", actor.tenantId).in("id", stopIds).returns<DetailStopRow[]>(),
      this.admin.from("manifest_verifications").select("stop_id").eq("tenant_id", actor.tenantId)
        .eq("round_id", roundId).eq("stage", "pickup").returns<DetailVerificationRow[]>(),
      this.admin.from("delivery_exceptions").select("stop_id").eq("tenant_id", actor.tenantId)
        .eq("round_id", roundId).eq("status", "open").returns<DetailExceptionRow[]>(),
      this.admin.from("operations_threads").select("id, stop_id, updated_at").eq("tenant_id", actor.tenantId)
        .eq("round_id", roundId).order("updated_at", { ascending: false }).returns<DetailThreadRow[]>(),
      this.admin.from("live_delivery_changes")
        .select("id, stop_id, change_version, round_id, applied_at, before_state, after_state, route_impact, driver_ack_status, acknowledged_at")
        .eq("tenant_id", actor.tenantId).eq("round_id", roundId)
        .order("applied_at", { ascending: false }).returns<DetailLiveChangeRow[]>(),
    ]);
    if (stopResult.error) throw stopResult.error;
    if (verificationResult.error) throw verificationResult.error;
    if (exceptionResult.error) throw exceptionResult.error;
    if (threadResult.error) throw threadResult.error;
    if (liveChangeResult.error) throw liveChangeResult.error;
    const stops = stopResult.data ?? [];
    const deliveryIds = [...new Set(stops.map((stop) => stop.delivery_id))];

    const [deliveryResult, promiseResult, manifestResult] = await Promise.all([
      this.admin.from("deliveries").select("id, reference, state, pickup_location_id, recipient_name, recipient_phone, destination_raw_address, destination_position, access_note")
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
      ? await this.admin.from("manifest_items").select("manifest_id, line_number, description, quantity, cargo_class, handling_note")
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
    const liveChangeByStop = new Map<string, DriverLiveDeliveryChange>();
    for (const change of liveChangeResult.data ?? []) {
      if (liveChangeByStop.has(change.stop_id)) continue;
      liveChangeByStop.set(change.stop_id, {
        id: change.id,
        changeVersion: change.change_version,
        roundId: change.round_id,
        stopId: change.stop_id,
        appliedAt: change.applied_at,
        before: change.before_state,
        after: change.after_state,
        impact: change.route_impact,
        driverAckStatus: change.driver_ack_status,
        ...(change.acknowledged_at ? { acknowledgedAt: change.acknowledged_at } : {}),
      });
    }

    const detailStops = ordered.flatMap((entry) => {
      const stop = stopById.get(entry.stop_id);
      const delivery = stop ? deliveryById.get(stop.delivery_id) : undefined;
      const promise = delivery ? promiseByDelivery.get(delivery.id) : undefined;
      const manifest = delivery ? currentManifestByDelivery.get(delivery.id) : undefined;
      if (!stop || !delivery || !promise || !manifest) return [];
      const coordinate = parseDatabasePoint(delivery.destination_position);
      const operationsThreadId = threadByStop.get(stop.id);
      const latestLiveChange = liveChangeByStop.get(stop.id);
      return [{
        stopId: stop.id, sequence: entry.sequence, stopState: stop.state, stopVersion: stop.version, destinationVersion: stop.destination_version,
        deliveryId: delivery.id, deliveryReference: delivery.reference, deliveryState: delivery.state,
        recipientName: delivery.recipient_name, recipientPhone: delivery.recipient_phone,
        rawAddress: delivery.destination_raw_address, ...(delivery.access_note ? { accessNote: delivery.access_note } : {}), ...(coordinate ? { coordinate } : {}),
        windowStart: promise.window_start, windowEnd: promise.window_end,
        manifest: {
          id: manifest.id, state: manifest.state, version: manifest.version,
          items: (itemsResult.data ?? []).filter((item) => item.manifest_id === manifest.id).map((item) => ({
            lineNumber: item.line_number, description: item.description, quantity: item.quantity,
            ...(item.cargo_class ? { cargoClass: item.cargo_class } : {}),
            ...(item.handling_note ? { handlingNote: item.handling_note } : {}),
          })),
        },
        pickupConfirmed: pickupConfirmedStops.has(stop.id),
        ...(stop.arrived_at ? { arrivedAt: stop.arrived_at } : {}),
        ...(stop.completed_at ? { completedAt: stop.completed_at } : {}),
        openExceptionCount: exceptionCountByStop.get(stop.id) ?? 0,
        ...(operationsThreadId ? { operationsThreadId } : {}),
        ...(latestLiveChange ? { latestLiveChange } : {}),
      }];
    });

    return {
      tenantId: actor.tenantId, observedAt: observedAt.toISOString(), id: round.id, reference: round.reference,
      serviceDate: round.service_date, state: round.state, version: round.version, ...(round.route_plan_snapshot ? { routePlan: round.route_plan_snapshot } : {}), driver, pickup, stops: detailStops,
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
        .select("id, person_id, version, preferred_locale, vehicle_label, vehicle_plate")
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
          .select("manifest_id, line_number, description, quantity, cargo_class, handling_note")
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
          cargoRequirements: (() => {
            const grouped = new Map<string, number>();
            for (const item of items.filter((entry) => entry.manifest_id === manifest.id)) {
              const code = item.cargo_class?.trim().toLowerCase() || "unclassified";
              grouped.set(code, (grouped.get(code) ?? 0) + item.quantity);
            }
            return [...grouped.entries()].map(([cargoClassCode, quantity]) => ({
              cargoClassCode,
              displayName: cargoClassCode === "unclassified" ? "Unclassified cargo" : cargoClassCode,
              quantity,
              classificationStatus: cargoClassCode === "unclassified" ? "unclassified" as const : "classified" as const,
            }));
          })(),
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

  async moveRoundStop(command: MoveRoundStopCommand, actor: ActorContext): Promise<MoveRoundStopResult> {
    const { data, error } = await this.admin.rpc("move_round_stop_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as MoveRoundStopResult;
  }

  async applyLiveDeliveryChange(command: ApplyLiveDeliveryChangeCommand, actor: ActorContext): Promise<ApplyLiveDeliveryChangeResult> {
    const { data, error } = await this.admin.rpc("apply_live_delivery_change_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as ApplyLiveDeliveryChangeResult;
  }

  async acknowledgeLiveDeliveryChange(command: AcknowledgeLiveDeliveryChangeCommand, identity: AuthenticatedIdentity): Promise<AcknowledgeLiveDeliveryChangeResult> {
    const { data: linked, error: linkedError } = await this.admin.from("auth_identities")
      .select("person_id").eq("auth_user_id", identity.authUserId).maybeSingle<{ person_id: string }>();
    if (linkedError) throw linkedError;
    if (!linked) return { status: "rejected", error: { code: "NOT_AUTHORIZED", message: "Driver identity is unavailable" } };
    const { data, error } = await this.admin.rpc("acknowledge_live_delivery_change_command", {
      p_command: command,
      p_actor_person_id: linked.person_id,
    });
    if (error) throw error;
    return data as AcknowledgeLiveDeliveryChangeResult;
  }

  async getPlanningRouteContext(
    actor: ActorContext,
    driverId: string,
    serviceDate: string,
    stopIds: string[],
    observedAt: Date,
  ) {
    const [planning, capacity, tenantResult] = await Promise.all([
      this.getOperationsPlanning(actor),
      this.getOperationsDrivers(actor, serviceDate, observedAt),
      this.admin.from("tenants").select("timezone").eq("id", actor.tenantId).single<{ timezone: string }>(),
    ]);
    if (tenantResult.error) throw tenantResult.error;
    const driver = capacity.drivers.find((item) => item.driverId === driverId);
    if (!driver) throw new Error("Driver is not an active own-team driver for this tenant.");
    const deliveryByStop = new Map(planning.unplannedDeliveries.map((delivery) => [delivery.stopId, delivery]));
    const stops = stopIds.flatMap((stopId) => {
      const delivery = deliveryByStop.get(stopId);
      return delivery ? [delivery] : [];
    });
    if (stops.length !== stopIds.length) throw new Error("One or more Stops are no longer in the unplanned pool.");
    if (stops.some((stop) => stop.serviceDate !== serviceDate)) throw new Error("Every Stop must match the planning service date.");
    const pickupIds = [...new Set(stops.map((stop) => stop.pickupLocationId))];
    if (pickupIds.length !== 1) throw new Error("Every Stop in a Round must use the same pickup location.");
    if (stops.some((stop) => !stop.coordinate)) throw new Error("Every Stop needs a verified destination coordinate before routing.");
    const pickupResult = await this.admin.from("tenant_locations")
      .select("id, position").eq("tenant_id", actor.tenantId).eq("id", pickupIds[0]!)
      .eq("active", true).is("deleted_at", null).maybeSingle<{ id: string; position: unknown }>();
    if (pickupResult.error) throw pickupResult.error;
    const pickupCoordinate = pickupResult.data ? parseDatabasePoint(pickupResult.data.position) : undefined;
    if (!pickupResult.data || !pickupCoordinate) throw new Error("Pickup location needs a verified coordinate before routing.");
    return {
      timezone: tenantResult.data.timezone,
      pickup: { id: pickupResult.data.id, coordinate: pickupCoordinate },
      driver,
      stops,
      blockingReasons: [] as string[],
      warnings: [
        ...(driver.vehicleProfile?.requiresReview
          ? ["Vehicle profile is a conservative migrated default and requires Operations review."] : []),
      ],
    };
  }

  async getAssignedPlanningRouteContext(
    actor: ActorContext,
    allowedRoundIds: string[],
    driverId: string,
    serviceDate: string,
    stopIds: string[],
    observedAt: Date,
  ) {
    const [details, capacity, tenantResult] = await Promise.all([
      Promise.all(allowedRoundIds.map((roundId) => this.getOperationsRoundDetail(roundId, actor, observedAt))),
      this.getOperationsDrivers(actor, serviceDate, observedAt),
      this.admin.from("tenants").select("timezone").eq("id", actor.tenantId).single<{ timezone: string }>(),
    ]);
    if (tenantResult.error) throw tenantResult.error;
    if (details.some((detail) => !detail)) throw new Error("One or more Rounds no longer exist.");
    const driver = capacity.drivers.find((item) => item.driverId === driverId);
    if (!driver) throw new Error("Driver is not an active own-team driver for this tenant.");
    const stopById = new Map(details.flatMap((detail) => detail?.stops ?? []).map((stop) => [stop.stopId, stop]));
    const pickupIds = [...new Set(details.filter(Boolean).map((detail) => detail!.pickup.id).filter(Boolean))];
    if (pickupIds.length !== 1) throw new Error("Source and target Rounds must use the same pickup location.");
    const stops = stopIds.flatMap((stopId) => {
      const stop = stopById.get(stopId);
      if (!stop) return [];
      const grouped = new Map<string, number>();
      for (const item of stop.manifest.items) {
        const code = item.cargoClass?.trim().toLowerCase() || "unclassified";
        grouped.set(code, (grouped.get(code) ?? 0) + item.quantity);
      }
      return [{
        deliveryId: stop.deliveryId,
        stopId: stop.stopId,
        reference: stop.deliveryReference,
        serviceDate,
        pickupLocationId: pickupIds[0]!,
        recipientName: stop.recipientName,
        rawAddress: stop.rawAddress,
        ...(stop.coordinate ? { coordinate: stop.coordinate } : {}),
        windowStart: stop.windowStart,
        windowEnd: stop.windowEnd,
        manifestSummary: stop.manifest.items.map((item) => `${item.quantity}× ${item.description}`).join(", ") || "Manifest ready",
        cargoRequirements: [...grouped.entries()].map(([cargoClassCode, quantity]) => ({
          cargoClassCode,
          displayName: cargoClassCode === "unclassified" ? "Unclassified cargo" : cargoClassCode,
          quantity,
          classificationStatus: cargoClassCode === "unclassified" ? "unclassified" as const : "classified" as const,
        })),
      }];
    });
    if (stops.length !== stopIds.length) throw new Error("One or more Stops are no longer assigned to the selected Rounds.");
    if (stops.some((stop) => !stop.coordinate)) throw new Error("Every Stop needs a verified destination coordinate before routing.");
    const pickupResult = await this.admin.from("tenant_locations")
      .select("id, position").eq("tenant_id", actor.tenantId).eq("id", pickupIds[0]!)
      .eq("active", true).is("deleted_at", null).maybeSingle<{ id: string; position: unknown }>();
    if (pickupResult.error) throw pickupResult.error;
    const pickupCoordinate = pickupResult.data ? parseDatabasePoint(pickupResult.data.position) : undefined;
    if (!pickupResult.data || !pickupCoordinate) throw new Error("Pickup location needs a verified coordinate before routing.");
    return {
      timezone: tenantResult.data.timezone,
      pickup: { id: pickupResult.data.id, coordinate: pickupCoordinate },
      driver,
      stops,
      blockingReasons: [] as string[],
      warnings: driver.vehicleProfile?.requiresReview
        ? ["Vehicle profile is a conservative migrated default and requires Operations review."] : [],
    };
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

  async startDriverShift(
    command: StartDriverShiftCommand,
    identity: AuthenticatedIdentity,
  ): Promise<StartDriverShiftResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("start_driver_shift_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as StartDriverShiftResult;
  }

  async endDriverShift(
    command: EndDriverShiftCommand,
    identity: AuthenticatedIdentity,
  ): Promise<EndDriverShiftResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("end_driver_shift_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as EndDriverShiftResult;
  }

  async updateDriverPreferredLocale(
    command: UpdateDriverPreferredLocaleCommand,
    identity: AuthenticatedIdentity,
  ): Promise<UpdateDriverPreferredLocaleResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("update_driver_preferred_locale_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as UpdateDriverPreferredLocaleResult;
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

  async reportLocationProblem(
    command: ReportLocationProblemCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ReportLocationProblemResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("report_location_problem_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as ReportLocationProblemResult;
  }

  async reportDriverEmergency(
    command: ReportDriverEmergencyCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ReportDriverEmergencyResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("report_driver_emergency_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as ReportDriverEmergencyResult;
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
    const thread = data as DriverOperationsThread | null;
    if (!thread) return null;
    return { ...thread, messages: await this.withCommunicationMediaUrls(thread.messages) };
  }

  async markDriverOperationsThreadRead(
    roundId: string,
    stopId: string,
    lastReadMessageId: string,
    identity: AuthenticatedIdentity,
  ): Promise<CommunicationThreadReadState | null> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return null;
    const { data, error } = await this.admin.rpc("mark_driver_operations_thread_read", {
      p_round_id: roundId,
      p_stop_id: stopId,
      p_last_read_message_id: lastReadMessageId,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as CommunicationThreadReadState | null;
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

  async prepareMessageMedia(
    roundId: string,
    stopId: string,
    identity: AuthenticatedIdentity,
    assetId: string,
    payload: PrepareMessageMediaPayload,
  ): Promise<Record<string, unknown>> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return { status: "rejected", error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" } };
    const { data, error } = await this.admin.rpc("prepare_driver_message_media_asset", {
      p_round_id: roundId,
      p_stop_id: stopId,
      p_actor_person_id: actorPersonId,
      p_asset_id: assetId,
      p_kind: payload.kind,
      p_file_name: payload.fileName,
      p_content_type: payload.contentType,
      p_size: payload.byteSize,
      p_sha256: payload.sha256,
      p_duration_milliseconds: payload.durationMilliseconds ?? null,
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

  private async withCommunicationMediaUrls(messages: DriverThreadMessage[]): Promise<DriverThreadMessage[]> {
    const assetIds = [...new Set(messages.flatMap((message) =>
      (message.attachments ?? []).flatMap((attachment) => attachment.kind === "location" ? [] : [attachment.mediaAssetId]),
    ))];
    if (!assetIds.length) return messages;
    const { data: assets, error } = await this.admin.from("communication_media_assets")
      .select("id, storage_path").in("id", assetIds)
      .returns<{ id: string; storage_path: string }[]>();
    if (error) throw error;
    const paths = new Map((assets ?? []).map((asset) => [asset.id, asset.storage_path]));
    return Promise.all(messages.map(async (message) => ({
      ...message,
      attachments: message.attachments ? await Promise.all(message.attachments.map(async (attachment) => {
        if (attachment.kind === "location") return attachment;
        const storagePath = paths.get(attachment.mediaAssetId);
        if (!storagePath) return attachment;
        const signed = await this.admin.storage.from("communication-media").createSignedUrl(storagePath, 300);
        return signed.data?.signedUrl ? { ...attachment, downloadUrl: signed.data.signedUrl } : attachment;
      })) : [],
    })));
  }

  async verifyMessageMedia(assetId: string, identity: AuthenticatedIdentity): Promise<Record<string, unknown>> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return { status: "rejected", error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" } };
    const { data: asset, error: assetError } = await this.admin.from("communication_media_assets")
      .select("id, storage_bucket, storage_path, state, uploader_person_id, expected_sha256, expected_size")
      .eq("id", assetId).maybeSingle<{
        id: string; storage_bucket: string; storage_path: string; state: string;
        uploader_person_id: string; expected_sha256: string; expected_size: number;
      }>();
    if (assetError) throw assetError;
    if (!asset || asset.uploader_person_id !== actorPersonId) return {
      status: "rejected", error: { code: "NOT_AUTHORIZED", message: "Message attachment is not owned by this driver" },
    };
    if (asset.state === "committed" || asset.state === "uploaded_uncommitted") {
      return { status: "verified", mediaAssetId: asset.id, assetState: asset.state };
    }
    const downloaded = await this.admin.storage.from(asset.storage_bucket).download(asset.storage_path);
    if (downloaded.error || !downloaded.data) return {
      status: "rejected", error: { code: "EVIDENCE_REQUIRED", message: "Message attachment upload is not complete yet" },
    };
    const bytes = Buffer.from(await downloaded.data.arrayBuffer());
    const verifiedSha256 = createHash("sha256").update(bytes).digest("hex");
    const { data, error } = await this.admin.rpc("mark_driver_message_media_uploaded", {
      p_asset_id: assetId,
      p_actor_person_id: actorPersonId,
      p_verified_sha256: verifiedSha256,
      p_verified_size: bytes.byteLength,
    });
    if (error) throw error;
    return data as Record<string, unknown>;
  }

  async logContactAttempt(
    command: LogContactAttemptCommand,
    identity: AuthenticatedIdentity,
  ): Promise<LogContactAttemptResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("log_contact_attempt_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as LogContactAttemptResult;
  }

  async getOperationsCommunications(actor: ActorContext): Promise<OperationsCommunicationsProjection> {
    type ThreadRow = {
      id: string; round_id: string; stop_id: string; driver_id: string;
      version: number; priority: "normal" | "emergency"; updated_at: string;
    };
    type ReadCursorRow = {
      thread_id: string;
      last_read_message_id: string;
      last_read_sent_at: string;
    };
    const { data: threads, error: threadsError } = await this.admin.from("operations_threads")
      .select("id, round_id, stop_id, driver_id, version, priority, updated_at")
      .eq("tenant_id", actor.tenantId).order("priority", { ascending: true })
      .order("updated_at", { ascending: false }).returns<ThreadRow[]>();
    if (threadsError) throw threadsError;
    if (!threads?.length) return { tenantId: actor.tenantId, totalUnreadCount: 0, threads: [] };

    const threadIds = threads.map((thread) => thread.id);
    const roundIds = [...new Set(threads.map((thread) => thread.round_id))];
    const stopIds = [...new Set(threads.map((thread) => thread.stop_id))];
    const driverIds = [...new Set(threads.map((thread) => thread.driver_id))];
    const [roundResult, roundStopResult, stopResult, driverResult, messageResult, cursorResult, contactResult] = await Promise.all([
      this.admin.from("rounds").select("id, reference").eq("tenant_id", actor.tenantId).in("id", roundIds)
        .returns<{ id: string; reference: string }[]>(),
      this.admin.from("round_stops").select("round_id, stop_id, sequence").eq("tenant_id", actor.tenantId)
        .in("round_id", roundIds).in("stop_id", stopIds)
        .returns<{ round_id: string; stop_id: string; sequence: number }[]>(),
      this.admin.from("delivery_stops").select("id, delivery_id").eq("tenant_id", actor.tenantId).in("id", stopIds)
        .returns<{ id: string; delivery_id: string }[]>(),
      this.admin.from("driver_profiles").select("id, person_id").in("id", driverIds)
        .returns<{ id: string; person_id: string }[]>(),
      this.admin.from("operations_messages").select("id, thread_id, sender, body, attachments, sent_at")
        .eq("tenant_id", actor.tenantId).in("thread_id", threadIds).order("sent_at").order("id")
        .returns<{ id: string; thread_id: string; sender: "driver" | "operations" | "system"; body: string; attachments: OperationsCommunicationThread["messages"][number]["attachments"]; sent_at: string }[]>(),
      this.admin.from("communication_thread_read_cursors")
        .select("thread_id, last_read_message_id, last_read_sent_at")
        .eq("tenant_id", actor.tenantId).eq("reader_person_id", actor.personId).in("thread_id", threadIds)
        .returns<ReadCursorRow[]>(),
      this.admin.from("contact_attempts")
        .select("id, stop_id, target, channel, outcome, occurred_from_device_at, recorded_at")
        .eq("tenant_id", actor.tenantId).in("stop_id", stopIds).order("recorded_at")
        .returns<{ id: string; stop_id: string; target: "recipient" | "operations"; channel: "native_phone"; outcome: "reached" | "no_answer" | "busy" | "call_failed"; occurred_from_device_at: string | null; recorded_at: string }[]>(),
    ]);
    if (roundResult.error) throw roundResult.error;
    if (roundStopResult.error) throw roundStopResult.error;
    if (stopResult.error) throw stopResult.error;
    if (driverResult.error) throw driverResult.error;
    if (messageResult.error) throw messageResult.error;
    if (cursorResult.error) throw cursorResult.error;
    if (contactResult.error) throw contactResult.error;

    const deliveryIds = (stopResult.data ?? []).map((stop) => stop.delivery_id);
    const personIds = (driverResult.data ?? []).map((driver) => driver.person_id);
    const [deliveryResult, peopleResult] = await Promise.all([
      this.admin.from("deliveries").select("id, reference, recipient_name, destination_raw_address, destination_position")
        .eq("tenant_id", actor.tenantId).in("id", deliveryIds)
        .returns<{ id: string; reference: string; recipient_name: string; destination_raw_address: string; destination_position: unknown }[]>(),
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
    const cursorByThreadId = new Map((cursorResult.data ?? []).map((cursor) => [cursor.thread_id, cursor]));

    const projection: OperationsCommunicationsProjection = {
      tenantId: actor.tenantId,
      totalUnreadCount: 0,
      threads: threads.flatMap((thread): OperationsCommunicationThread[] => {
        const round = roundById.get(thread.round_id);
        const stop = stopById.get(thread.stop_id);
        const delivery = stop ? deliveryById.get(stop.delivery_id) : undefined;
        const driver = driverById.get(thread.driver_id);
        if (!round || !stop || !delivery || !driver) return [];
        const threadMessages = messages.filter((message) => message.thread_id === thread.id).map((message) => ({
          id: message.id,
          sender: message.sender,
          body: message.body,
          attachments: message.attachments ?? [],
          sentAt: message.sent_at,
        }));
        const cursor = cursorByThreadId.get(thread.id);
        const unreadMessages = threadMessages.filter((message) => message.sender === "driver" && (
          !cursor || message.sentAt > cursor.last_read_sent_at
            || (message.sentAt === cursor.last_read_sent_at && message.id > cursor.last_read_message_id)
        ));
        return [{
          id: thread.id,
          priority: thread.priority,
          roundId: thread.round_id,
          roundReference: round.reference,
          stopId: thread.stop_id,
          stopSequence: sequenceByKey.get(`${thread.round_id}:${thread.stop_id}`) ?? 0,
          deliveryId: delivery.id,
          deliveryReference: delivery.reference,
          recipientName: delivery.recipient_name,
          rawAddress: delivery.destination_raw_address,
          ...(parseDatabasePoint(delivery.destination_position) == null
            ? {}
            : { destinationPosition: parseDatabasePoint(delivery.destination_position)! }),
          driverId: thread.driver_id,
          driverName: personById.get(driver.person_id)?.display_name ?? "Team driver",
          contactAttempts: (contactResult.data ?? []).filter((attempt) => attempt.stop_id === thread.stop_id).map((attempt) => ({
            id: attempt.id,
            target: attempt.target,
            channel: attempt.channel,
            outcome: attempt.outcome,
            occurredAt: attempt.occurred_from_device_at ?? attempt.recorded_at,
          })),
          version: thread.version,
          updatedAt: thread.updated_at,
          unreadCount: unreadMessages.length,
          ...(unreadMessages[0] ? { firstUnreadMessageId: unreadMessages[0].id } : {}),
          hasUnreadVoice: unreadMessages.some((message) => message.attachments?.some((attachment) => attachment.kind === "voice")),
          ...(cursor ? { lastReadMessageId: cursor.last_read_message_id } : {}),
          messages: threadMessages,
        }];
      }),
    };
    projection.totalUnreadCount = projection.threads.reduce((total, thread) => total + thread.unreadCount, 0);
    return {
      ...projection,
      threads: await Promise.all(projection.threads.map(async (thread) => ({
        ...thread,
        messages: await this.withCommunicationMediaUrls(thread.messages),
      }))),
    };
  }

  async getOperationsCommunicationThread(
    threadId: string,
    actor: ActorContext,
  ): Promise<OperationsCommunicationThread | null> {
    const projection = await this.getOperationsCommunications(actor);
    return projection.threads.find((thread) => thread.id === threadId) ?? null;
  }

  async markOperationsCommunicationThreadRead(
    threadId: string,
    lastReadMessageId: string,
    actor: ActorContext,
  ): Promise<CommunicationThreadReadState | null> {
    const { data, error } = await this.admin.rpc("mark_operations_thread_read", {
      p_thread_id: threadId,
      p_last_read_message_id: lastReadMessageId,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as CommunicationThreadReadState | null;
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

  async prepareOperationsMessageMedia(
    threadId: string,
    actor: ActorContext,
    assetId: string,
    payload: PrepareMessageMediaPayload,
  ): Promise<Record<string, unknown>> {
    const { data, error } = await this.admin.rpc("prepare_operations_message_media_asset", {
      p_thread_id: threadId,
      p_actor_person_id: actor.personId,
      p_asset_id: assetId,
      p_kind: payload.kind,
      p_file_name: payload.fileName,
      p_content_type: payload.contentType,
      p_size: payload.byteSize,
      p_sha256: payload.sha256,
      p_duration_milliseconds: payload.durationMilliseconds ?? null,
    });
    if (error) throw error;
    const prepared = data as Record<string, unknown>;
    if (prepared.status !== "prepared") return prepared;
    const projectRef = new URL(this.url).hostname.split(".")[0];
    return {
      ...prepared,
      tusEndpoint: `https://${projectRef}.storage.supabase.co/storage/v1/upload/resumable`,
      uploadAuthorization: "operations_session",
    };
  }

  async verifyOperationsMessageMedia(
    assetId: string,
    actor: ActorContext,
  ): Promise<Record<string, unknown>> {
    const { data: asset, error: assetError } = await this.admin.from("communication_media_assets")
      .select("id, tenant_id, storage_bucket, storage_path, state, uploader_person_id, expected_sha256, expected_size")
      .eq("id", assetId).maybeSingle<{
        id: string; tenant_id: string; storage_bucket: string; storage_path: string; state: string;
        uploader_person_id: string; expected_sha256: string; expected_size: number;
      }>();
    if (assetError) throw assetError;
    if (!asset || asset.tenant_id !== actor.tenantId || asset.uploader_person_id !== actor.personId) return {
      status: "rejected", error: { code: "NOT_AUTHORIZED", message: "Message attachment is not owned by this Operations user" },
    };
    if (asset.state === "committed" || asset.state === "uploaded_uncommitted") {
      return { status: "verified", mediaAssetId: asset.id, assetState: asset.state };
    }
    const downloaded = await this.admin.storage.from(asset.storage_bucket).download(asset.storage_path);
    if (downloaded.error || !downloaded.data) return {
      status: "rejected", error: { code: "EVIDENCE_REQUIRED", message: "Message attachment upload is not complete yet" },
    };
    const bytes = Buffer.from(await downloaded.data.arrayBuffer());
    const verifiedSha256 = createHash("sha256").update(bytes).digest("hex");
    const { data, error } = await this.admin.rpc("mark_operations_message_media_uploaded", {
      p_asset_id: assetId,
      p_actor_person_id: actor.personId,
      p_verified_sha256: verifiedSha256,
      p_verified_size: bytes.byteLength,
    });
    if (error) throw error;
    return data as Record<string, unknown>;
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

  async prepareExceptionMedia(
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
    const { data, error } = await this.admin.rpc("prepare_exception_media_asset", {
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

  async reportDeliveryProblem(
    command: ReportDeliveryProblemCommand,
    identity: AuthenticatedIdentity,
  ): Promise<ReportDeliveryProblemResult> {
    const actorPersonId = await this.driverActorPersonId(identity);
    if (!actorPersonId) return {
      status: "rejected",
      error: { code: "NOT_AUTHORIZED", message: "Driver identity is not linked" },
    };
    const { data, error } = await this.admin.rpc("report_delivery_problem_command", {
      p_command: command,
      p_actor_person_id: actorPersonId,
    });
    if (error) throw error;
    return data as ReportDeliveryProblemResult;
  }

  async setDriverRecurringSchedule(
    command: SetDriverRecurringScheduleCommand,
    actor: ActorContext,
  ): Promise<SetDriverRecurringScheduleResult> {
    const { data, error } = await this.admin.rpc("set_driver_recurring_schedule_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as SetDriverRecurringScheduleResult;
  }

  async setDriverShiftException(
    command: SetDriverShiftExceptionCommand,
    actor: ActorContext,
  ): Promise<SetDriverShiftExceptionResult> {
    const { data, error } = await this.admin.rpc("set_driver_shift_exception_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as SetDriverShiftExceptionResult;
  }

  async clearDriverShiftException(
    command: ClearDriverShiftExceptionCommand,
    actor: ActorContext,
  ): Promise<ClearDriverShiftExceptionResult> {
    const { data, error } = await this.admin.rpc("clear_driver_shift_exception_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as ClearDriverShiftExceptionResult;
  }

  async getOperationsDrivers(
    actor: ActorContext,
    serviceDate: string,
    observedAt: Date,
  ): Promise<OperationsDriversProjection> {
    type CapacityDriverRow = { id: string; person_id: string; vehicle_plate: string | null };
    type CapacityPersonRow = { id: string; display_name: string; phone_e164: string | null };
    type VehicleProfileRow = {
      id: string; code: string; display_name: string;
      vehicle_group: "motorbike" | "car" | "van" | "pickup" | "cargo_bike" | "other";
      departure_pattern: "multi_stop" | "return_after_every_delivery" | "return_after_round" | "return_when_capacity_exhausted";
      max_stops_per_departure: number; planning_deliveries_per_block: number;
      pickup_turnaround_minutes: number; requires_review: boolean; version: number;
    };
    type CargoClassRow = { id: string; code: string; display_name: string };
    type CargoLimitRow = { vehicle_profile_id: string; cargo_class_id: string; allowed: boolean; max_quantity: number | null };
    type AssignmentRow = { driver_id: string; vehicle_profile_id: string };
    type ScheduleRow = {
      id: string; driver_id: string; weekdays: number[]; start_local: string; end_local: string;
      vehicle_profile_id: string; note: string | null; version: number;
    };
    type ShiftExceptionRow = {
      id: string; driver_id: string; service_date: string; exception_kind: "shift" | "off"; start_local: string | null;
      end_local: string | null; vehicle_profile_id: string | null; note: string | null; version: number;
    };
    type CurrentRoundRow = {
      id: string; reference: string; driver_id: string;
      state: "approved" | "loading" | "active"; updated_at: string;
      route_plan_snapshot: PlanningRouteSnapshot | null;
    };
    type CurrentPositionRow = { driver_id: string; captured_at: string };
    type TodayPodRow = { driver_id: string };

    const { data: relationships, error: relationshipsError } = await this.admin.from("driver_tenant_relationships")
      .select("driver_id").eq("tenant_id", actor.tenantId).eq("relationship_kind", "team")
      .eq("status", "active").is("deleted_at", null).returns<{ driver_id: string }[]>();
    if (relationshipsError) throw relationshipsError;
    const driverIds = [...new Set((relationships ?? []).map((row) => row.driver_id))];
    if (!driverIds.length) return {
      tenantId: actor.tenantId, serviceDate, observedAt: observedAt.toISOString(), drivers: [], vehicleProfiles: [],
      summary: { ownDrivers: 0, scheduled: 0, activeRounds: 0, availableNow: 0, scheduleRequired: 0, vehicleGroups: {} },
    };
    const tenantResult = await this.admin.from("tenants").select("timezone").eq("id", actor.tenantId)
      .single<{ timezone: string }>();
    if (tenantResult.error) throw tenantResult.error;
    const timezone = tenantResult.data.timezone;
    const dayStart = zonedLocalIso(serviceDate, "00:00", timezone);
    const dayEnd = zonedLocalIso(addCalendarDay(serviceDate), "00:00", timezone);
    const [driverResult, assignmentResult, vehicleResult, cargoClassResult, cargoLimitResult, scheduleResult, exceptionResult, roundResult, positionResult, podResult] = await Promise.all([
      this.admin.from("driver_profiles").select("id, person_id, vehicle_plate").in("id", driverIds)
        .eq("active", true).is("deleted_at", null).returns<CapacityDriverRow[]>(),
      this.admin.from("driver_vehicle_assignments").select("driver_id, vehicle_profile_id")
        .eq("tenant_id", actor.tenantId).in("driver_id", driverIds).eq("is_default", true)
        .is("effective_to", null).is("deleted_at", null).returns<AssignmentRow[]>(),
      this.admin.from("vehicle_profiles")
        .select("id, code, display_name, vehicle_group, departure_pattern, max_stops_per_departure, planning_deliveries_per_block, pickup_turnaround_minutes, requires_review, version")
        .eq("tenant_id", actor.tenantId).eq("active", true).is("deleted_at", null).returns<VehicleProfileRow[]>(),
      this.admin.from("cargo_classes").select("id, code, display_name")
        .eq("tenant_id", actor.tenantId).eq("active", true).is("deleted_at", null).returns<CargoClassRow[]>(),
      this.admin.from("vehicle_profile_cargo_limits").select("vehicle_profile_id, cargo_class_id, allowed, max_quantity")
        .eq("tenant_id", actor.tenantId).returns<CargoLimitRow[]>(),
      this.admin.from("driver_recurring_schedules")
        .select("id, driver_id, weekdays, start_local, end_local, vehicle_profile_id, note, version")
        .eq("tenant_id", actor.tenantId).in("driver_id", driverIds).eq("active", true)
        .is("deleted_at", null).returns<ScheduleRow[]>(),
      this.admin.from("driver_shift_exceptions")
        .select("id, driver_id, service_date, exception_kind, start_local, end_local, vehicle_profile_id, note, version")
        .eq("tenant_id", actor.tenantId).in("driver_id", driverIds).eq("service_date", serviceDate)
        .is("deleted_at", null).returns<ShiftExceptionRow[]>(),
      this.admin.from("rounds").select("id, reference, driver_id, state, updated_at, route_plan_snapshot")
        .eq("tenant_id", actor.tenantId).in("driver_id", driverIds).in("state", ["approved", "loading", "active"])
        .is("deleted_at", null).order("updated_at", { ascending: false }).returns<CurrentRoundRow[]>(),
      this.admin.from("driver_position_current").select("driver_id, captured_at")
        .in("driver_id", driverIds).returns<CurrentPositionRow[]>(),
      this.admin.from("pod_records").select("driver_id").eq("tenant_id", actor.tenantId)
        .gte("delivered_at", dayStart).lt("delivered_at", dayEnd).returns<TodayPodRow[]>(),
    ]);
    for (const result of [driverResult, assignmentResult, vehicleResult, cargoClassResult, cargoLimitResult, scheduleResult, exceptionResult, roundResult, positionResult, podResult]) {
      if (result.error) throw result.error;
    }
    const drivers = driverResult.data ?? [];
    const personIds = drivers.map((driver) => driver.person_id);
    const roundIds = (roundResult.data ?? []).map((round) => round.id);
    const [peopleResult, roundStopsResult] = await Promise.all([
      this.admin.from("persons").select("id, display_name, phone_e164").in("id", personIds)
        .returns<CapacityPersonRow[]>(),
      this.admin.from("round_stops").select("round_id").eq("tenant_id", actor.tenantId)
        .in("round_id", roundIds.length ? roundIds : ["00000000-0000-0000-0000-000000000000"])
        .returns<{ round_id: string }[]>(),
    ]);
    if (peopleResult.error) throw peopleResult.error;
    if (roundStopsResult.error) throw roundStopsResult.error;

    const cargoClassById = new Map((cargoClassResult.data ?? []).map((cargoClass) => [cargoClass.id, cargoClass]));
    const profileSummary = (vehicleResult.data ?? []).map((profile) => ({
      id: profile.id, code: profile.code, displayName: profile.display_name,
      vehicleGroup: profile.vehicle_group, departurePattern: profile.departure_pattern,
      maxStopsPerDeparture: profile.max_stops_per_departure,
      planningDeliveriesPerBlock: profile.planning_deliveries_per_block,
      pickupTurnaroundMinutes: profile.pickup_turnaround_minutes,
      requiresReview: profile.requires_review, version: profile.version,
      cargoLimits: (cargoLimitResult.data ?? []).flatMap((limit) => {
        const cargoClass = cargoClassById.get(limit.cargo_class_id);
        if (limit.vehicle_profile_id !== profile.id || !cargoClass) return [];
        return [{
          cargoClassCode: cargoClass.code,
          displayName: cargoClass.display_name,
          allowed: limit.allowed,
          ...(limit.max_quantity == null ? {} : { maxQuantity: limit.max_quantity }),
        }];
      }),
    }));
    const profileById = new Map(profileSummary.map((profile) => [profile.id, profile]));
    const personById = new Map((peopleResult.data ?? []).map((person) => [person.id, person]));
    const assignmentByDriver = new Map((assignmentResult.data ?? []).map((assignment) => [assignment.driver_id, assignment]));
    const scheduleByDriver = new Map((scheduleResult.data ?? []).map((schedule) => [schedule.driver_id, schedule]));
    const exceptionByDriver = new Map((exceptionResult.data ?? []).map((exception) => [exception.driver_id, exception]));
    const positionByDriver = new Map((positionResult.data ?? []).map((position) => [position.driver_id, position]));
    const roundByDriver = new Map<string, CurrentRoundRow>();
    for (const round of roundResult.data ?? []) if (!roundByDriver.has(round.driver_id)) roundByDriver.set(round.driver_id, round);
    const stopCountByRound = new Map<string, number>();
    for (const stop of roundStopsResult.data ?? []) stopCountByRound.set(stop.round_id, (stopCountByRound.get(stop.round_id) ?? 0) + 1);
    const completedByDriver = new Map<string, number>();
    for (const pod of podResult.data ?? []) completedByDriver.set(pod.driver_id, (completedByDriver.get(pod.driver_id) ?? 0) + 1);
    const isoDay = new Date(`${serviceDate}T00:00:00.000Z`).getUTCDay() || 7;
    const observedMs = observedAt.getTime();

    const items = drivers.flatMap((driver) => {
      const person = personById.get(driver.person_id);
      if (!person) return [];
      const schedule = scheduleByDriver.get(driver.id);
      const exception = exceptionByDriver.get(driver.id);
      const currentRound = roundByDriver.get(driver.id);
      const exceptionShift = exception?.exception_kind === "shift" && exception.start_local && exception.end_local && exception.vehicle_profile_id
        ? { source: "exception" as const, startLocal: compactLocalTime(exception.start_local), endLocal: compactLocalTime(exception.end_local), vehicleProfileId: exception.vehicle_profile_id }
        : undefined;
      const recurringShift = !exception && schedule?.weekdays.includes(isoDay)
        ? { source: "recurring" as const, startLocal: compactLocalTime(schedule.start_local), endLocal: compactLocalTime(schedule.end_local), vehicleProfileId: schedule.vehicle_profile_id }
        : undefined;
      const shift = exceptionShift ?? recurringShift;
      const shiftStart = shift ? zonedLocalIso(serviceDate, shift.startLocal, timezone) : undefined;
      const crossesMidnight = !!shift && shift.endLocal <= shift.startLocal;
      const shiftEnd = shift ? zonedLocalIso(crossesMidnight ? addCalendarDay(serviceDate) : serviceDate, shift.endLocal, timezone) : undefined;
      const profileId = shift?.vehicleProfileId ?? schedule?.vehicle_profile_id
        ?? assignmentByDriver.get(driver.id)?.vehicle_profile_id;
      const vehicleProfile = profileId ? profileById.get(profileId) : undefined;
      const position = positionByDriver.get(driver.id);
      const positionAgeMs = position ? observedMs - Date.parse(position.captured_at) : Number.POSITIVE_INFINITY;
      const presence = position
        ? { state: positionAgeMs <= 120_000 ? "live" as const : "stale" as const, capturedAt: position.captured_at }
        : { state: "unknown" as const };
      const withinShift = !!shiftStart && !!shiftEnd && observedMs >= Date.parse(shiftStart) && observedMs < Date.parse(shiftEnd);
      let availability: {
        state: "on_round" | "loading" | "available" | "off_shift" | "schedule_required";
        label: string; nextAvailableAt?: string; projectionBasis: string;
      };
      if (currentRound) availability = projectCurrentRoundAvailability({
        reference: currentRound.reference,
        state: currentRound.state,
        routePlan: currentRound.route_plan_snapshot,
      }, observedAt);
      else if (!shift && !schedule) availability = {
        state: "schedule_required", label: "Schedule required",
        projectionBasis: "No recurring own-team schedule has been configured.",
      };
      else if (withinShift) availability = {
        state: "available", label: "Available now",
        projectionBasis: "Inside the effective shift with no current Round.",
      };
      else availability = {
        state: "off_shift", label: exception?.exception_kind === "off" ? "Off · date exception" : "Off shift",
        ...(shiftStart && observedMs < Date.parse(shiftStart) ? { nextAvailableAt: shiftStart } : {}),
        projectionBasis: exception?.exception_kind === "off"
          ? "A date-specific day-off exception overrides the recurring schedule."
          : shift ? "Outside the effective shift window." : "Today is not a scheduled recurring workday.",
      };
      return [{
        driverId: driver.id, displayName: person.display_name, initials: initials(person.display_name),
        ...(person.phone_e164 ? { phone: person.phone_e164 } : {}),
        ...(driver.vehicle_plate ? { vehiclePlate: driver.vehicle_plate } : {}),
        presence, availability,
        ...(shiftStart && shiftEnd && shift ? { effectiveShift: {
          source: shift.source, startAt: shiftStart, endAt: shiftEnd, crossesMidnight,
        } } : {}),
        ...(schedule ? { schedule: {
          id: schedule.id, version: schedule.version, weekdays: schedule.weekdays,
          startLocal: compactLocalTime(schedule.start_local), endLocal: compactLocalTime(schedule.end_local),
          ...(schedule.note ? { note: schedule.note } : {}),
        } } : {}),
        ...(exception ? { dateException: {
          id: exception.id, version: exception.version, serviceDate: exception.service_date,
          kind: exception.exception_kind,
          ...(exception.start_local ? { startLocal: compactLocalTime(exception.start_local) } : {}),
          ...(exception.end_local ? { endLocal: compactLocalTime(exception.end_local) } : {}),
          ...(exception.vehicle_profile_id ? { vehicleProfileId: exception.vehicle_profile_id } : {}),
          ...(exception.note ? { note: exception.note } : {}),
        } } : {}),
        ...(vehicleProfile ? { vehicleProfile } : {}),
        ...(currentRound ? { currentRound: {
          id: currentRound.id, reference: currentRound.reference, state: currentRound.state,
          stopCount: stopCountByRound.get(currentRound.id) ?? 0,
        } } : {}),
        completedDeliveriesToday: completedByDriver.get(driver.id) ?? 0,
      }];
    });
    const vehicleGroups: Record<string, number> = {};
    for (const item of items) {
      const group = item.vehicleProfile?.vehicleGroup ?? "unconfigured";
      vehicleGroups[group] = (vehicleGroups[group] ?? 0) + 1;
    }
    return {
      tenantId: actor.tenantId, serviceDate, observedAt: observedAt.toISOString(),
      drivers: items, vehicleProfiles: profileSummary,
      summary: {
        ownDrivers: items.length,
        scheduled: items.filter((item) => item.effectiveShift).length,
        activeRounds: items.filter((item) => item.currentRound?.state === "active").length,
        availableNow: items.filter((item) => item.availability.state === "available").length,
        scheduleRequired: items.filter((item) => !item.schedule).length,
        vehicleGroups,
      },
    };
  }

  async getOperationsHistory(actor: ActorContext): Promise<OperationsHistoryProjection> {
    type PodRow = {
      id: string; delivery_id: string; stop_id: string; round_id: string; driver_id: string;
      media_asset_id: string; handoff_type: "recipient" | "someone_else" | "left_at_location";
      receiver_name: string | null; receiver_relationship: string | null; left_at_location: string | null;
      delivered_at: string; manifest_version: number;
    };
    type ReturnedExceptionRow = {
      id: string; delivery_id: string; stop_id: string; round_id: string; driver_id: string;
      media_asset_id: string | null; category: "damaged_item"; note: string | null;
      reported_at: string; resolved_at: string | null; command_id: string; manifest_version: number;
    };
    const [podResult, returnedResult] = await Promise.all([
      this.admin.from("pod_records")
        .select("id, delivery_id, stop_id, round_id, driver_id, media_asset_id, handoff_type, receiver_name, receiver_relationship, left_at_location, delivered_at, manifest_version")
        .eq("tenant_id", actor.tenantId).order("delivered_at", { ascending: false }).limit(100).returns<PodRow[]>(),
      this.admin.from("delivery_exceptions")
        .select("id, delivery_id, stop_id, round_id, driver_id, media_asset_id, category, note, reported_at, resolved_at, command_id, manifest_version")
        .eq("tenant_id", actor.tenantId).eq("stage", "delivery").eq("category", "damaged_item")
        .eq("status", "resolved").order("resolved_at", { ascending: false }).limit(100).returns<ReturnedExceptionRow[]>(),
    ]);
    const { data: pods, error: podsError } = podResult;
    const { data: returnedExceptions, error: returnedError } = returnedResult;
    if (podsError) throw podsError;
    if (returnedError) throw returnedError;
    const podRows = pods ?? [];
    const returnRows = returnedExceptions ?? [];
    if (!podRows.length && !returnRows.length) return { tenantId: actor.tenantId, deliveries: [] };
    const allRows = [...podRows, ...returnRows];
    const deliveryIds = [...new Set(allRows.map((item) => item.delivery_id))];
    const roundIds = [...new Set(allRows.map((item) => item.round_id))];
    const driverIds = [...new Set(allRows.map((item) => item.driver_id))];
    const mediaIds = [...new Set(allRows.flatMap((item) => item.media_asset_id ? [item.media_asset_id] : []))];
    const returnedStopIds = [...new Set(returnRows.map((item) => item.stop_id))];
    const [deliveryResult, roundResult, driverResult, mediaResult, returnAuditResult] = await Promise.all([
      this.admin.from("deliveries").select("id, reference, recipient_name, destination_raw_address, state").in("id", deliveryIds)
        .returns<{ id: string; reference: string; recipient_name: string; destination_raw_address: string; state: string }[]>(),
      this.admin.from("rounds").select("id, reference").in("id", roundIds).returns<{ id: string; reference: string }[]>(),
      this.admin.from("driver_profiles").select("id, person_id").in("id", driverIds).returns<{ id: string; person_id: string }[]>(),
      this.admin.from("media_assets").select("id, state").in("id", mediaIds).eq("state", "committed")
        .returns<{ id: string; state: "committed" }[]>(),
      this.admin.from("audit_events").select("aggregate_id, semantic_change, occurred_at")
        .eq("tenant_id", actor.tenantId).eq("action", "operations.delivery_return_confirmed")
        .in("aggregate_id", returnedStopIds.length ? returnedStopIds : ["00000000-0000-0000-0000-000000000000"])
        .order("occurred_at", { ascending: false })
        .returns<{ aggregate_id: string; semantic_change: unknown; occurred_at: string }[]>(),
    ]);
    if (deliveryResult.error) throw deliveryResult.error;
    if (roundResult.error) throw roundResult.error;
    if (driverResult.error) throw driverResult.error;
    if (mediaResult.error) throw mediaResult.error;
    if (returnAuditResult.error) throw returnAuditResult.error;
    const personIds = (driverResult.data ?? []).map((driver) => driver.person_id);
    const { data: people, error: peopleError } = await this.admin.from("persons")
      .select("id, display_name").in("id", personIds).returns<{ id: string; display_name: string }[]>();
    if (peopleError) throw peopleError;
    const deliveryById = new Map((deliveryResult.data ?? []).map((row) => [row.id, row]));
    const roundById = new Map((roundResult.data ?? []).map((row) => [row.id, row]));
    const personById = new Map((people ?? []).map((row) => [row.id, row]));
    const personIdByDriver = new Map((driverResult.data ?? []).map((row) => [row.id, row.person_id]));
    const committedMedia = new Set((mediaResult.data ?? []).map((row) => row.id));
    const returnAuditByStop = new Map<string, { note?: string; occurredAt: string }>();
    for (const audit of returnAuditResult.data ?? []) {
      if (returnAuditByStop.has(audit.aggregate_id)) continue;
      const semantic = audit.semantic_change && typeof audit.semantic_change === "object"
        ? audit.semantic_change as Record<string, unknown>
        : {};
      const note = typeof semantic.note === "string" ? semantic.note.trim() : "";
      returnAuditByStop.set(audit.aggregate_id, {
        ...(note ? { note } : {}),
        occurredAt: audit.occurred_at,
      });
    }
    const driverName = (driverId: string) =>
      personById.get(personIdByDriver.get(driverId) ?? "")?.display_name ?? "Team driver";
    const deliveredItems = podRows.flatMap((pod) => {
      const delivery = deliveryById.get(pod.delivery_id);
      const round = roundById.get(pod.round_id);
      if (!delivery || !round || !committedMedia.has(pod.media_asset_id)) return [];
      const receiverLabel = pod.handoff_type === "left_at_location"
        ? pod.left_at_location ?? "Approved location"
        : pod.receiver_relationship
          ? `${pod.receiver_name ?? "Receiver"} · ${pod.receiver_relationship}`
          : pod.receiver_name ?? delivery.recipient_name;
      return [{
        outcome: "delivered" as const,
        recordId: `pod:${pod.id}`,
        podId: pod.id,
        deliveryId: pod.delivery_id,
        stopId: pod.stop_id,
        roundId: pod.round_id,
        deliveryReference: delivery.reference,
        roundReference: round.reference,
        recipientName: delivery.recipient_name,
        rawAddress: delivery.destination_raw_address,
        driverName: driverName(pod.driver_id),
        handoffType: pod.handoff_type,
        receiverLabel,
        deliveredAt: pod.delivered_at,
        occurredAt: pod.delivered_at,
        manifestVersion: pod.manifest_version,
        verifiedPhotoCount: 1 as const,
        mediaAssetId: pod.media_asset_id,
        mediaState: "committed" as const,
      }];
    });
    const returnedItems = returnRows.flatMap((exception) => {
      const delivery = deliveryById.get(exception.delivery_id);
      const round = roundById.get(exception.round_id);
      if (!delivery || delivery.state !== "returned" || !round || !exception.media_asset_id
        || !exception.resolved_at || !committedMedia.has(exception.media_asset_id)) return [];
      const audit = returnAuditByStop.get(exception.stop_id);
      const returnedAt = audit?.occurredAt ?? exception.resolved_at;
      return [{
        outcome: "returned" as const,
        recordId: `exception:${exception.id}`,
        exceptionId: exception.id,
        deliveryId: exception.delivery_id,
        stopId: exception.stop_id,
        roundId: exception.round_id,
        deliveryReference: delivery.reference,
        roundReference: round.reference,
        recipientName: delivery.recipient_name,
        rawAddress: delivery.destination_raw_address,
        driverName: driverName(exception.driver_id),
        category: exception.category,
        ...(exception.note?.trim() ? { exceptionNote: exception.note.trim() } : {}),
        ...(audit?.note ? { resolutionNote: audit.note } : {}),
        reportedAt: exception.reported_at,
        returnedAt,
        occurredAt: returnedAt,
        manifestVersion: exception.manifest_version,
        verifiedPhotoCount: 1 as const,
        mediaAssetId: exception.media_asset_id,
        mediaState: "committed" as const,
      }];
    });
    return {
      tenantId: actor.tenantId,
      deliveries: [...deliveredItems, ...returnedItems]
        .sort((left, right) => Date.parse(right.occurredAt) - Date.parse(left.occurredAt))
        .slice(0, 100),
    };
  }

  async getOperationsAction(actor: ActorContext, observedAt: Date): Promise<OperationsActionProjection> {
    type ExceptionRow = {
      id: string; delivery_id: string; stop_id: string; round_id: string; driver_id: string;
      stage: "pickup" | "delivery";
      category: "missing_item" | "wrong_item" | "damaged_item" | "wrong_pin" | "wrong_entrance" | "wrong_address" | "cannot_find_location" | "emergency";
      note: string | null; status: "open"; manifest_version: number; reported_at: string;
      expected_position: unknown; observed_position: unknown; observed_accuracy_meters: number | null;
      observed_location_source: "google_nav" | "rounds_os" | "unknown" | null;
      original_stop_state: string | null; original_delivery_state: DeliveryState | null;
    };
    const [planning, exceptionResult] = await Promise.all([
      this.getOperationsPlanning(actor),
      this.admin.from("delivery_exceptions")
        .select("id, delivery_id, stop_id, round_id, driver_id, stage, category, note, status, manifest_version, reported_at, expected_position, observed_position, observed_accuracy_meters, observed_location_source, original_stop_state, original_delivery_state")
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
    const [deliveryResult, stopResult, roundResult, roundStopResult, driverResult, threadResult, emergencyResult] = await Promise.all([
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
      this.admin.from("driver_emergency_events").select("exception_id, safety_status")
        .eq("tenant_id", actor.tenantId).in("exception_id", exceptions.map((item) => item.id))
        .returns<{ exception_id: string; safety_status: "safe" | "urgent" }[]>(),
    ]);
    if (deliveryResult.error) throw deliveryResult.error;
    if (stopResult.error) throw stopResult.error;
    if (roundResult.error) throw roundResult.error;
    if (roundStopResult.error) throw roundStopResult.error;
    if (driverResult.error) throw driverResult.error;
    if (threadResult.error) throw threadResult.error;
    if (emergencyResult.error) throw emergencyResult.error;

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
    const emergencyByException = new Map((emergencyResult.data ?? []).map((row) => [row.exception_id, row.safety_status]));
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
        const expectedCoordinate = parseDatabasePoint(item.expected_position);
        const observedCoordinate = parseDatabasePoint(item.observed_position);
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
          ...(expectedCoordinate ? { expectedCoordinate } : {}),
          ...(observedCoordinate ? { observedCoordinate } : {}),
          ...(item.observed_accuracy_meters != null ? { observedAccuracyMeters: item.observed_accuracy_meters } : {}),
          ...(item.observed_location_source ? { observedLocationSource: item.observed_location_source } : {}),
          ...(emergencyByException.get(item.id) ? { emergencySafetyStatus: emergencyByException.get(item.id)! } : {}),
          ...(item.original_stop_state ? { originalStopState: item.original_stop_state } : {}),
          ...(item.original_delivery_state ? { originalDeliveryState: item.original_delivery_state } : {}),
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
      this.admin.from("driver_profiles").select("id, person_id, version, preferred_locale, vehicle_label, vehicle_plate")
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

    type DriverScheduleRow = {
      weekdays: number[];
      start_local: string;
      end_local: string;
    };
    type DriverShiftExceptionRow = {
      exception_kind: "shift" | "off";
      start_local: string | null;
      end_local: string | null;
    };
    type DriverShiftAttendanceRow = {
      id: string;
      service_date: string;
      timezone: string;
      schedule_source: "recurring" | "exception";
      scheduled_start_at: string;
      scheduled_end_at: string;
      started_at: string;
      ended_at: string | null;
      version: number;
    };
    const currentServiceDate = localServiceDate(new Date(), tenant.timezone);
    const openAttendanceResult = await this.admin.from("driver_shift_attendance")
      .select("id, service_date, timezone, schedule_source, scheduled_start_at, scheduled_end_at, started_at, ended_at, version")
      .eq("tenant_id", tenant.id).eq("driver_id", driver.id).is("ended_at", null)
      .order("service_date", { ascending: false }).limit(1).maybeSingle<DriverShiftAttendanceRow>();
    if (openAttendanceResult.error) throw openAttendanceResult.error;
    const serviceDate = openAttendanceResult.data?.service_date ?? currentServiceDate;
    const isoDay = new Date(`${serviceDate}T00:00:00.000Z`).getUTCDay() || 7;
    const [scheduleResult, shiftExceptionResult, attendanceResult] = await Promise.all([
      this.admin.from("driver_recurring_schedules")
        .select("weekdays, start_local, end_local")
        .eq("tenant_id", tenant.id).eq("driver_id", driver.id).eq("active", true)
        .is("deleted_at", null).maybeSingle<DriverScheduleRow>(),
      this.admin.from("driver_shift_exceptions")
        .select("exception_kind, start_local, end_local")
        .eq("tenant_id", tenant.id).eq("driver_id", driver.id).eq("service_date", serviceDate)
        .is("deleted_at", null).maybeSingle<DriverShiftExceptionRow>(),
      openAttendanceResult.data
        ? Promise.resolve({ data: openAttendanceResult.data, error: null })
        : this.admin.from("driver_shift_attendance")
          .select("id, service_date, timezone, schedule_source, scheduled_start_at, scheduled_end_at, started_at, ended_at, version")
          .eq("tenant_id", tenant.id).eq("driver_id", driver.id).eq("service_date", serviceDate)
          .maybeSingle<DriverShiftAttendanceRow>(),
    ]);
    if (scheduleResult.error) throw scheduleResult.error;
    if (shiftExceptionResult.error) throw shiftExceptionResult.error;
    if (attendanceResult.error) throw attendanceResult.error;
    const attendance = attendanceResult.data;
    const shiftException = shiftExceptionResult.data;
    const schedule = scheduleResult.data;
    const exceptionShift = shiftException?.exception_kind === "shift"
      && shiftException.start_local && shiftException.end_local
      ? {
          source: "exception" as const,
          startLocal: compactLocalTime(shiftException.start_local),
          endLocal: compactLocalTime(shiftException.end_local),
        }
      : undefined;
    const recurringShift = !shiftException && schedule?.weekdays.includes(isoDay)
      ? {
          source: "recurring" as const,
          startLocal: compactLocalTime(schedule.start_local),
          endLocal: compactLocalTime(schedule.end_local),
        }
      : undefined;
    const configuredShift = exceptionShift ?? recurringShift;
    const effectiveShift = attendance ? {
      source: attendance.schedule_source,
      startLocal: localClockTime(attendance.scheduled_start_at, attendance.timezone),
      endLocal: localClockTime(attendance.scheduled_end_at, attendance.timezone),
      startAt: attendance.scheduled_start_at,
      endAt: attendance.scheduled_end_at,
      timezone: attendance.timezone,
    } : configuredShift ? {
      ...configuredShift,
      startAt: zonedLocalIso(serviceDate, configuredShift.startLocal, tenant.timezone),
      endAt: zonedLocalIso(
        configuredShift.endLocal <= configuredShift.startLocal ? addCalendarDay(serviceDate) : serviceDate,
        configuredShift.endLocal,
        tenant.timezone,
      ),
      timezone: tenant.timezone,
    } : undefined;
    const crossesMidnight = !!effectiveShift
      && localServiceDate(new Date(effectiveShift.endAt), effectiveShift.timezone) !== serviceDate;
    const shiftProjection = effectiveShift ? {
      effective: {
        serviceDate,
        timezone: effectiveShift.timezone,
        source: effectiveShift.source,
        startAt: effectiveShift.startAt,
        endAt: effectiveShift.endAt,
        startLocal: effectiveShift.startLocal,
        endLocal: effectiveShift.endLocal,
        crossesMidnight,
      },
      ...(attendance ? { attendance: {
        id: attendance.id,
        version: attendance.version,
        serviceDate: attendance.service_date,
        startedAt: attendance.started_at,
        ...(attendance.ended_at ? { endedAt: attendance.ended_at } : {}),
      } } : {}),
    } : undefined;

    const session: DriverSession = {
      user: { id: identity.authUserId, displayName: person.display_name },
      driver: {
        id: driver.id,
        version: driver.version,
        preferredLocale: driver.preferred_locale,
        ...(driver.vehicle_label ? { vehicleLabel: driver.vehicle_label } : {}),
        ...(driver.vehicle_plate ? { vehiclePlate: driver.vehicle_plate } : {}),
      },
      team: { tenantId: tenant.id, displayName: tenant.display_name, status: "active" },
      ...(shiftProjection ? { shift: shiftProjection } : {}),
      completedRounds: [],
    };

    const { data: completedRounds, error: completedRoundsError } = await this.admin.from("rounds")
      .select("id, tenant_id, reference, service_date, state, version, updated_at, route_plan_snapshot")
      .eq("tenant_id", tenant.id).eq("driver_id", driver.id).eq("state", "complete")
      .is("deleted_at", null).order("updated_at", { ascending: false }).limit(30)
      .returns<DriverHistoryRoundRow[]>();
    if (completedRoundsError) throw completedRoundsError;
    const completedRoundIds = (completedRounds ?? []).map((item) => item.id);
    if (completedRoundIds.length) {
      const [historyAssignments, historyPods] = await Promise.all([
        this.admin.from("round_stops").select("round_id, stop_id")
          .eq("tenant_id", tenant.id).in("round_id", completedRoundIds)
          .returns<DriverHistoryRoundStopRow[]>(),
        this.admin.from("pod_records").select("round_id, stop_id")
          .eq("tenant_id", tenant.id).in("round_id", completedRoundIds)
          .returns<DriverHistoryPodRow[]>(),
      ]);
      if (historyAssignments.error) throw historyAssignments.error;
      if (historyPods.error) throw historyPods.error;
      const historyStopIds = [...new Set((historyAssignments.data ?? []).map((item) => item.stop_id))];
      const historyStops = historyStopIds.length
        ? await this.admin.from("delivery_stops").select("id, state")
          .eq("tenant_id", tenant.id).in("id", historyStopIds)
          .returns<DriverHistoryStopRow[]>()
        : { data: [] as DriverHistoryStopRow[], error: null };
      if (historyStops.error) throw historyStops.error;
      const stopById = new Map((historyStops.data ?? []).map((item) => [item.id, item]));
      session.completedRounds = (completedRounds ?? []).map((item) => {
        const assignments = (historyAssignments.data ?? []).filter((entry) => entry.round_id === item.id);
        const states = assignments.map((entry) => stopById.get(entry.stop_id)?.state);
        const route = item.route_plan_snapshot;
        return {
          id: item.id,
          reference: item.reference,
          serviceDate: item.service_date,
          tenant: { id: tenant.id, displayName: tenant.display_name, timezone: tenant.timezone },
          completedAt: item.updated_at,
          stopCount: assignments.length,
          deliveredStopCount: states.filter((state) => state === "completed").length,
          formallyClosedStopCount: states.filter((state) => state === "cancelled").length,
          podCount: (historyPods.data ?? []).filter((pod) => pod.round_id === item.id).length,
          ...(route && Number.isFinite(route.distanceMeters) ? { plannedDistanceMeters: route.distanceMeters } : {}),
          ...(route && Number.isFinite(route.durationSeconds) ? { plannedDurationSeconds: route.durationSeconds } : {}),
        };
      });
    }

    const { data: assignedRounds, error: roundError } = await this.admin.from("rounds")
      .select("id, tenant_id, reference, service_date, state, version, route_plan_snapshot")
      .eq("tenant_id", tenant.id).eq("driver_id", driver.id)
      .in("state", ["approved", "loading", "active"])
      .is("deleted_at", null).order("service_date").order("created_at").limit(20)
      .returns<(AssignedRoundCandidate & Pick<RoundRow, "tenant_id" | "version"> & { route_plan_snapshot: PlanningRouteSnapshot | null })[]>();
    if (roundError) throw roundError;
    const driverServiceDate = new Intl.DateTimeFormat("en-CA", { timeZone: tenant.timezone }).format(new Date());
    const round = selectDriverAssignedRound(assignedRounds ?? [], driverServiceDate);
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
    const [deliveryResult, promiseResult, manifestResult, contactResult] = await Promise.all([
      this.admin.from("deliveries")
        .select("id, reference, service_date, pickup_location_id, recipient_name, recipient_phone, destination_raw_address, destination_position, access_note, delivery_note, is_surprise")
        .in("id", deliveryIds).returns<DeliveryRow[]>(),
      this.admin.from("delivery_promises").select("delivery_id, window_start, window_end").in("delivery_id", deliveryIds).returns<PromiseRow[]>(),
      this.admin.from("manifests").select("id, delivery_id, version").in("delivery_id", deliveryIds).returns<ManifestRow[]>(),
      this.admin.from("contact_attempts")
        .select("id, stop_id, target, channel, outcome, occurred_from_device_at, recorded_at")
        .in("stop_id", stopIds).order("recorded_at")
        .returns<{ id: string; stop_id: string; target: "recipient" | "operations"; channel: "native_phone"; outcome: "reached" | "no_answer" | "busy" | "call_failed"; occurred_from_device_at: string | null; recorded_at: string }[]>(),
    ]);
    if (deliveryResult.error) throw deliveryResult.error;
    if (promiseResult.error) throw promiseResult.error;
    if (manifestResult.error) throw manifestResult.error;
    if (contactResult.error) throw contactResult.error;
    const deliveries = deliveryResult.data ?? [];
    const manifests = manifestResult.data ?? [];
    const itemResult = await this.admin.from("manifest_items")
      .select("manifest_id, line_number, description, quantity, cargo_class, handling_note")
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
        contactAttempts: (contactResult.data ?? []).filter((attempt) => attempt.stop_id === stop.id).map((attempt) => ({
          id: attempt.id,
          target: attempt.target,
          channel: attempt.channel,
          outcome: attempt.outcome,
          occurredAt: attempt.occurred_from_device_at ?? attempt.recorded_at,
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
      ...(round.route_plan_snapshot ? { routePlan: round.route_plan_snapshot } : {}),
    };
    const { data: pendingChange, error: pendingChangeError } = await this.admin.from("live_delivery_changes")
      .select("id, change_version, round_id, stop_id, applied_at, before_state, after_state, route_impact, driver_ack_status, acknowledged_at")
      .eq("tenant_id", tenant.id).eq("driver_id", driver.id).eq("round_id", round.id)
      .eq("driver_ack_status", "pending").order("applied_at", { ascending: false }).limit(1)
      .maybeSingle<{
        id: string; change_version: number; round_id: string; stop_id: string; applied_at: string;
        before_state: DriverLiveDeliveryChange["before"]; after_state: DriverLiveDeliveryChange["after"];
        route_impact: DriverLiveDeliveryChange["impact"]; driver_ack_status: "pending" | "acknowledged"; acknowledged_at: string | null;
      }>();
    if (pendingChangeError) throw pendingChangeError;
    if (pendingChange) session.pendingLiveChange = {
      id: pendingChange.id,
      changeVersion: pendingChange.change_version,
      roundId: pendingChange.round_id,
      stopId: pendingChange.stop_id,
      appliedAt: pendingChange.applied_at,
      before: pendingChange.before_state,
      after: pendingChange.after_state,
      impact: pendingChange.route_impact,
      driverAckStatus: pendingChange.driver_ack_status,
      ...(pendingChange.acknowledged_at ? { acknowledgedAt: pendingChange.acknowledged_at } : {}),
    };
    return session;
  }

  async ready(): Promise<boolean> {
    const { error } = await this.admin.from("tenants").select("id", { head: true, count: "exact" }).limit(1);
    return !error;
  }
}
