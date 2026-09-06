-- D01: explicit, server-confirmed physical arrival at the assigned pickup.
-- This is an observational Round event: custody remains unconfirmed and the
-- Round version/state do not change until round.confirm_pickup succeeds.

create table public.round_pickup_arrival_events (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  round_id uuid not null,
  pickup_location_id uuid not null,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  actor_person_id uuid not null references public.persons(id) on delete restrict,
  position extensions.geography(point, 4326),
  accuracy_meters double precision check (accuracy_meters is null or accuracy_meters >= 0),
  location_source text check (location_source is null or location_source in ('google_nav', 'rounds_os', 'unknown')),
  occurred_from_device_at timestamptz,
  arrived_at timestamptz not null default now(),
  command_id uuid not null unique,
  unique (round_id),
  unique (tenant_id, id),
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict,
  foreign key (tenant_id, pickup_location_id) references public.tenant_locations(tenant_id, id) on delete restrict,
  check ((position is null) = (accuracy_meters is null)),
  check ((position is null) = (location_source is null))
);

create index round_pickup_arrival_driver_idx
  on public.round_pickup_arrival_events (tenant_id, driver_id, arrived_at desc);

alter table public.round_pickup_arrival_events enable row level security;
revoke all on table public.round_pickup_arrival_events from anon, authenticated;
grant select on table public.round_pickup_arrival_events to service_role;

create or replace function public.confirm_round_pickup_arrival_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'round.confirm_pickup_arrival';
  v_tenant_id uuid;
  v_round_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_occurred_from_device_at timestamptz;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_round public.rounds%rowtype;
  v_driver_id uuid;
  v_actor_role public.tenant_role;
  v_pickup_location_id uuid;
  v_assigned_pickup_location_id uuid;
  v_assigned_pickup_count bigint;
  v_position extensions.geography(point, 4326);
  v_accuracy_meters double precision;
  v_location_source text;
  v_arrival_id uuid := gen_random_uuid();
  v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now();
  v_event_payload jsonb;
  v_event jsonb;
  v_result jsonb;
begin
  if p_command is null
    or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
    or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Unsupported command envelope'));
  end if;

  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_round_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_occurred_from_device_at := nullif(p_command ->> 'occurredFromDeviceAt', '')::timestamptz;
    v_pickup_location_id := (p_command #>> '{payload,pickupLocationId}')::uuid;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Pickup arrival identifiers or version are invalid'));
  end;

  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
    or v_payload is null or v_pickup_location_id is null then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Pickup arrival payload is invalid'));
  end if;

  if v_payload ? 'position' then
    begin
      v_accuracy_meters := (v_payload #>> '{position,accuracyMeters}')::double precision;
      v_location_source := v_payload #>> '{position,source}';
      if (v_payload #>> '{position,latitude}')::double precision < -90
        or (v_payload #>> '{position,latitude}')::double precision > 90
        or (v_payload #>> '{position,longitude}')::double precision < -180
        or (v_payload #>> '{position,longitude}')::double precision > 180
        or v_accuracy_meters < 0
        or v_location_source not in ('google_nav', 'rounds_os', 'unknown') then
        raise exception 'invalid position';
      end if;
      v_position := extensions.st_setsrid(extensions.st_makepoint(
        (v_payload #>> '{position,longitude}')::double precision,
        (v_payload #>> '{position,latitude}')::double precision
      ), 4326)::extensions.geography;
    exception when others then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'VALIDATION_FAILED', 'message', 'Pickup arrival position is invalid'));
    end;
  end if;

  v_payload_hash := encode(digest(v_payload::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key, 0));
  select * into v_existing from public.command_idempotency
   where tenant_id = v_tenant_id and command_type = v_command_type and idempotency_key = v_idempotency_key;
  if found then
    if v_existing.payload_hash <> v_payload_hash then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'IDEMPOTENCY_CONFLICT', 'message', 'Idempotency key was already used with different payload'));
    end if;
    return v_existing.result || jsonb_build_object('deduplicated', true);
  end if;

  select membership.role, driver.id into v_actor_role, v_driver_id
    from public.tenant_memberships membership
    join public.driver_profiles driver on driver.person_id = membership.person_id
    join public.driver_tenant_relationships relationship
      on relationship.driver_id = driver.id and relationship.tenant_id = membership.tenant_id
   where membership.tenant_id = v_tenant_id and membership.person_id = p_actor_person_id
     and membership.status = 'active' and membership.role = 'team_driver'
     and driver.active = true and driver.deleted_at is null
     and relationship.relationship_kind = 'team' and relationship.status = 'active'
     and relationship.deleted_at is null
   limit 1;
  if v_driver_id is null then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Actor is not an active Team driver for this tenant'));
  end if;

  select * into v_round from public.rounds
   where id = v_round_id and tenant_id = v_tenant_id and driver_id = v_driver_id
     and state in ('approved', 'loading') and deleted_at is null
   for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Round is not assigned to this driver or is no longer awaiting pickup'));
  end if;
  if v_round.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Round changed; refresh before confirming pickup arrival'));
  end if;
  if exists (select 1 from public.round_pickup_arrival_events where round_id = v_round_id) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'ALREADY_COMPLETED', 'message', 'Pickup arrival was already confirmed'));
  end if;

  select count(distinct delivery.pickup_location_id), min(delivery.pickup_location_id::text)::uuid
    into v_assigned_pickup_count, v_assigned_pickup_location_id
    from public.round_stops assigned
    join public.delivery_stops stop on stop.id = assigned.stop_id and stop.tenant_id = assigned.tenant_id
    join public.deliveries delivery on delivery.id = stop.delivery_id and delivery.tenant_id = stop.tenant_id
   where assigned.round_id = v_round_id and assigned.tenant_id = v_tenant_id
     and delivery.deleted_at is null;
  if v_assigned_pickup_count <> 1 or v_assigned_pickup_location_id <> v_pickup_location_id then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Pickup location does not match every delivery in the assigned Round'));
  end if;

  insert into public.round_pickup_arrival_events (
    id, tenant_id, round_id, pickup_location_id, driver_id, actor_person_id,
    position, accuracy_meters, location_source, occurred_from_device_at,
    arrived_at, command_id
  ) values (
    v_arrival_id, v_tenant_id, v_round_id, v_pickup_location_id, v_driver_id,
    p_actor_person_id, v_position, v_accuracy_meters, v_location_source,
    v_occurred_from_device_at, v_occurred_at, v_command_id
  );

  v_event_payload := jsonb_build_object(
    'arrivalId', v_arrival_id,
    'roundId', v_round_id,
    'pickupLocationId', v_pickup_location_id,
    'driverId', v_driver_id,
    'arrivedAt', v_occurred_at,
    'hasPositionEvidence', v_position is not null
  );
  v_event := jsonb_build_object(
    'event', 'round.pickup_arrival_confirmed', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'round',
    'aggregateId', v_round_id, 'aggregateVersion', v_round.version,
    'occurredAt', v_occurred_at, 'payload', v_event_payload
  );
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'round.pickup_arrival_confirmed',
    'round', v_round_id, v_round.version, v_command_id, v_trace_id,
    jsonb_build_object('arrivalId', v_arrival_id, 'pickupLocationId', v_pickup_location_id,
      'hasPositionEvidence', v_position is not null)
  );
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'round.pickup_arrival_confirmed', 1, 'round',
    v_round_id, v_round.version, v_trace_id, v_event, v_occurred_at
  );
  v_result := jsonb_build_object(
    'status', 'committed', 'aggregateVersion', v_round.version,
    'state', v_event_payload, 'events', jsonb_build_array(v_event)
  );
  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_round_id,
    v_payload_hash, 'committed', v_result, v_trace_id, p_actor_person_id
  );
  return v_result;
end;
$$;

revoke all on function public.confirm_round_pickup_arrival_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.confirm_round_pickup_arrival_command(jsonb, uuid) to service_role;

comment on function public.confirm_round_pickup_arrival_command(jsonb, uuid) is
  'Server-only Team-driver command that records explicit physical arrival at the authoritative pickup, with optional measured location evidence.';
