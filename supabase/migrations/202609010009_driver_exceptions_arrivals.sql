-- Pilot/Slice 1: durable structured pickup exceptions and explicit,
-- server-confirmed destination arrival. Both commands are Team-driver only,
-- versioned, idempotent and auditable.

create type public.pickup_problem_category as enum (
  'missing_item',
  'wrong_item',
  'damaged_item'
);
create type public.operational_exception_status as enum ('open', 'resolved', 'cancelled');

create table public.delivery_exceptions (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  delivery_id uuid not null,
  stop_id uuid not null,
  round_id uuid not null,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  manifest_id uuid not null,
  manifest_version bigint not null check (manifest_version > 0),
  stage text not null check (stage in ('pickup', 'delivery')),
  category public.pickup_problem_category not null,
  note text check (note is null or length(note) <= 500),
  status public.operational_exception_status not null default 'open',
  actor_person_id uuid not null references public.persons(id) on delete restrict,
  occurred_from_device_at timestamptz,
  reported_at timestamptz not null default now(),
  resolved_at timestamptz,
  command_id uuid not null unique,
  unique (tenant_id, id),
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id) references public.delivery_stops(tenant_id, id) on delete restrict,
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict,
  foreign key (tenant_id, manifest_id) references public.manifests(tenant_id, id) on delete restrict,
  check ((status = 'resolved') = (resolved_at is not null))
);

create table public.stop_arrival_events (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  delivery_id uuid not null,
  stop_id uuid not null,
  round_id uuid not null,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  actor_person_id uuid not null references public.persons(id) on delete restrict,
  position extensions.geography(point, 4326),
  accuracy_meters double precision check (accuracy_meters is null or accuracy_meters >= 0),
  location_source text check (location_source is null or location_source in ('google_nav', 'rounds_os', 'unknown')),
  override_reason text check (override_reason is null or length(override_reason) <= 500),
  occurred_from_device_at timestamptz,
  arrived_at timestamptz not null default now(),
  command_id uuid not null unique,
  unique (stop_id),
  unique (tenant_id, id),
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id) references public.delivery_stops(tenant_id, id) on delete restrict,
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict,
  check ((position is null) = (accuracy_meters is null)),
  check ((position is null) = (location_source is null))
);

create index delivery_exceptions_open_idx
  on public.delivery_exceptions (tenant_id, status, reported_at desc);
create index stop_arrival_events_round_idx
  on public.stop_arrival_events (tenant_id, round_id, arrived_at);

alter table public.delivery_exceptions enable row level security;
alter table public.stop_arrival_events enable row level security;
revoke all on table public.delivery_exceptions, public.stop_arrival_events from anon, authenticated;
grant select on table public.delivery_exceptions, public.stop_arrival_events to service_role;

create or replace function public.report_pickup_problem_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'stop.report_pickup_problem';
  v_tenant_id uuid;
  v_stop_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_occurred_from_device_at timestamptz;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_stop public.delivery_stops%rowtype;
  v_delivery public.deliveries%rowtype;
  v_round_id uuid;
  v_driver_id uuid;
  v_actor_role public.tenant_role;
  v_manifest public.manifests%rowtype;
  v_category public.pickup_problem_category;
  v_note text;
  v_exception_id uuid := gen_random_uuid();
  v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now();
  v_stop_version bigint;
  v_event jsonb;
  v_event_payload jsonb;
  v_result jsonb;
begin
  if p_command is null or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
    or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_stop_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_occurred_from_device_at := nullif(p_command ->> 'occurredFromDeviceAt', '')::timestamptz;
    v_category := (p_command #>> '{payload,category}')::public.pickup_problem_category;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Pickup problem identifiers, version or category are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  v_note := nullif(btrim(coalesce(v_payload ->> 'note', '')), '');
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
    or v_payload is null or length(coalesce(v_note, '')) > 500 then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Pickup problem payload is invalid'));
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
     and relationship.deleted_at is null limit 1;
  if v_driver_id is null then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Actor is not an active Team driver for this tenant'));
  end if;

  select stop.* into v_stop from public.delivery_stops stop
    join public.round_stops assigned on assigned.stop_id = stop.id and assigned.tenant_id = stop.tenant_id
    join public.rounds round_record on round_record.id = assigned.round_id and round_record.tenant_id = stop.tenant_id
   where stop.id = v_stop_id and stop.tenant_id = v_tenant_id and stop.state = 'assigned'
     and round_record.driver_id = v_driver_id and round_record.state in ('approved', 'loading')
     and round_record.deleted_at is null
   for update of stop;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Stop is not awaiting pickup for this driver'));
  end if;
  if v_stop.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Stop changed; refresh before reporting the pickup problem'));
  end if;
  select assigned.round_id into v_round_id from public.round_stops assigned where assigned.stop_id = v_stop_id;
  select * into v_delivery from public.deliveries
   where id = v_stop.delivery_id and tenant_id = v_tenant_id and state = 'assigned' and deleted_at is null for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Delivery is no longer awaiting pickup'));
  end if;
  select * into v_manifest from public.manifests
   where id = (v_payload ->> 'manifestId')::uuid and tenant_id = v_tenant_id
     and delivery_id = v_delivery.id and version = (v_payload ->> 'manifestVersion')::bigint for update;
  if not found or v_manifest.state <> 'draft' then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'CUSTODY_LOCKED', 'message', 'Manifest changed or custody has already been confirmed'));
  end if;

  insert into public.delivery_exceptions (
    id, tenant_id, delivery_id, stop_id, round_id, driver_id, manifest_id,
    manifest_version, stage, category, note, actor_person_id,
    occurred_from_device_at, reported_at, command_id
  ) values (
    v_exception_id, v_tenant_id, v_delivery.id, v_stop_id, v_round_id, v_driver_id,
    v_manifest.id, v_manifest.version, 'pickup', v_category, v_note,
    p_actor_person_id, v_occurred_from_device_at, v_occurred_at, v_command_id
  );
  update public.deliveries set state = 'pickup_pending', version = version + 1, updated_at = v_occurred_at
   where id = v_delivery.id;
  update public.deliveries set state = 'exception', version = version + 1, updated_at = v_occurred_at
   where id = v_delivery.id;
  update public.delivery_stops set state = 'exception', version = version + 1, updated_at = v_occurred_at
   where id = v_stop_id returning version into v_stop_version;

  v_event_payload := jsonb_build_object(
    'exceptionId', v_exception_id, 'stopId', v_stop_id, 'deliveryId', v_delivery.id,
    'roundId', v_round_id, 'category', v_category);
  v_event := jsonb_build_object(
    'event', 'stop.pickup_problem_reported', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'stop',
    'aggregateId', v_stop_id, 'aggregateVersion', v_stop_version, 'occurredAt', v_occurred_at,
    'payload', v_event_payload);
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'stop.pickup_problem_reported', 'stop', v_stop_id,
    v_stop_version, v_command_id, v_trace_id,
    jsonb_build_object('state', jsonb_build_object('from', v_stop.state, 'to', 'exception'),
      'exceptionId', v_exception_id, 'category', v_category));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'stop.pickup_problem_reported', 1, 'stop', v_stop_id,
    v_stop_version, v_trace_id, v_event, v_occurred_at);
  v_result := jsonb_build_object(
    'status', 'committed', 'aggregateVersion', v_stop_version,
    'state', v_event_payload || jsonb_build_object('stopState', 'exception', 'deliveryState', 'exception'),
    'events', jsonb_build_array(v_event));
  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_stop_id,
    v_payload_hash, 'committed', v_result, v_trace_id, p_actor_person_id);
  return v_result;
end;
$$;

create or replace function public.confirm_stop_arrival_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'stop.confirm_arrival';
  v_tenant_id uuid;
  v_stop_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_occurred_from_device_at timestamptz;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_stop public.delivery_stops%rowtype;
  v_delivery public.deliveries%rowtype;
  v_round_id uuid;
  v_driver_id uuid;
  v_actor_role public.tenant_role;
  v_position extensions.geography(point, 4326);
  v_accuracy double precision;
  v_location_source text;
  v_override_reason text;
  v_arrival_id uuid := gen_random_uuid();
  v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now();
  v_stop_version bigint;
  v_event jsonb;
  v_event_payload jsonb;
  v_result jsonb;
begin
  if p_command is null or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
    or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_stop_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_occurred_from_device_at := nullif(p_command ->> 'occurredFromDeviceAt', '')::timestamptz;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Arrival identifiers or version are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := coalesce(p_command -> 'payload', '{}'::jsonb);
  v_override_reason := nullif(btrim(coalesce(v_payload ->> 'overrideReason', '')), '');
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
    or length(coalesce(v_override_reason, '')) > 500 then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Arrival payload is invalid'));
  end if;
  if v_payload ? 'position' then
    begin
      if (v_payload #>> '{position,latitude}')::double precision not between -90 and 90
        or (v_payload #>> '{position,longitude}')::double precision not between -180 and 180
        or (v_payload #>> '{position,accuracyMeters}')::double precision < 0
        or v_payload #>> '{position,source}' not in ('google_nav', 'rounds_os', 'unknown') then
        raise exception 'invalid position';
      end if;
      v_position := st_setsrid(st_makepoint(
        (v_payload #>> '{position,longitude}')::double precision,
        (v_payload #>> '{position,latitude}')::double precision), 4326)::extensions.geography;
      v_accuracy := (v_payload #>> '{position,accuracyMeters}')::double precision;
      v_location_source := v_payload #>> '{position,source}';
    exception when others then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'VALIDATION_FAILED', 'message', 'Arrival position evidence is invalid'));
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
     and relationship.deleted_at is null limit 1;
  if v_driver_id is null then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Actor is not an active Team driver for this tenant'));
  end if;

  select stop.* into v_stop from public.delivery_stops stop
    join public.round_stops assigned on assigned.stop_id = stop.id and assigned.tenant_id = stop.tenant_id
    join public.rounds round_record on round_record.id = assigned.round_id and round_record.tenant_id = stop.tenant_id
   where stop.id = v_stop_id and stop.tenant_id = v_tenant_id and stop.state = 'active'
     and round_record.driver_id = v_driver_id and round_record.state = 'active'
     and round_record.deleted_at is null
   for update of stop;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Stop is not active for this driver'));
  end if;
  if v_stop.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Stop changed; refresh before confirming arrival'));
  end if;
  select assigned.round_id into v_round_id from public.round_stops assigned where assigned.stop_id = v_stop_id;
  select * into v_delivery from public.deliveries
   where id = v_stop.delivery_id and tenant_id = v_tenant_id and state = 'in_custody' and deleted_at is null for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Delivery is not in driver custody'));
  end if;

  insert into public.stop_arrival_events (
    id, tenant_id, delivery_id, stop_id, round_id, driver_id, actor_person_id,
    position, accuracy_meters, location_source, override_reason,
    occurred_from_device_at, arrived_at, command_id
  ) values (
    v_arrival_id, v_tenant_id, v_delivery.id, v_stop_id, v_round_id, v_driver_id,
    p_actor_person_id, v_position, v_accuracy, v_location_source, v_override_reason,
    v_occurred_from_device_at, v_occurred_at, v_command_id);
  update public.deliveries set state = 'en_route', version = version + 1, updated_at = v_occurred_at
   where id = v_delivery.id;
  update public.deliveries set state = 'arrived', version = version + 1, updated_at = v_occurred_at
   where id = v_delivery.id;
  update public.delivery_stops
     set state = 'arrived', arrived_at = v_occurred_at, version = version + 1, updated_at = v_occurred_at
   where id = v_stop_id returning version into v_stop_version;

  v_event_payload := jsonb_build_object(
    'arrivalId', v_arrival_id, 'stopId', v_stop_id, 'deliveryId', v_delivery.id,
    'roundId', v_round_id, 'driverId', v_driver_id, 'arrivedAt', v_occurred_at);
  v_event := jsonb_build_object(
    'event', 'stop.arrival_confirmed', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'stop',
    'aggregateId', v_stop_id, 'aggregateVersion', v_stop_version, 'occurredAt', v_occurred_at,
    'payload', v_event_payload);
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'stop.arrival_confirmed', 'stop', v_stop_id,
    v_stop_version, v_command_id, v_trace_id,
    jsonb_build_object('state', jsonb_build_object('from', v_stop.state, 'to', 'arrived'),
      'arrivalId', v_arrival_id, 'hasPositionEvidence', v_position is not null));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'stop.arrival_confirmed', 1, 'stop', v_stop_id,
    v_stop_version, v_trace_id, v_event, v_occurred_at);
  v_result := jsonb_build_object(
    'status', 'committed', 'aggregateVersion', v_stop_version,
    'state', v_event_payload || jsonb_build_object('stopState', 'arrived', 'deliveryState', 'arrived'),
    'events', jsonb_build_array(v_event));
  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_stop_id,
    v_payload_hash, 'committed', v_result, v_trace_id, p_actor_person_id);
  return v_result;
end;
$$;

revoke all on function public.report_pickup_problem_command(jsonb, uuid) from public, anon, authenticated;
revoke all on function public.confirm_stop_arrival_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.report_pickup_problem_command(jsonb, uuid) to service_role;
grant execute on function public.confirm_stop_arrival_command(jsonb, uuid) to service_role;

comment on function public.report_pickup_problem_command(jsonb, uuid) is
  'Server-only Team-driver command that records a structured pre-custody package problem and stops ordinary pickup.';
comment on function public.confirm_stop_arrival_command(jsonb, uuid) is
  'Server-only Team-driver command that explicitly confirms physical destination arrival with optional location evidence.';
