-- G05 Driver Emergency. This is a typed safety event and an explicit
-- Operations hold. It preserves custody and does not invent an Operations
-- acknowledgement, reassignment, or resolution policy.

alter type public.pickup_problem_category add value if not exists 'emergency';

alter table public.operations_threads
  add column priority text not null default 'normal'
  check (priority in ('normal', 'emergency'));

create table public.driver_emergency_events (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  round_id uuid not null,
  stop_id uuid not null,
  delivery_id uuid not null,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  exception_id uuid not null,
  safety_status text not null check (safety_status in ('safe', 'urgent')),
  position extensions.geography(point, 4326),
  accuracy_meters double precision check (accuracy_meters is null or accuracy_meters >= 0),
  location_source text check (location_source is null or location_source in ('google_nav', 'rounds_os', 'unknown')),
  actor_person_id uuid not null references public.persons(id) on delete restrict,
  occurred_from_device_at timestamptz,
  reported_at timestamptz not null default now(),
  command_id uuid not null unique,
  unique (tenant_id, id),
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id) references public.delivery_stops(tenant_id, id) on delete restrict,
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict,
  foreign key (tenant_id, exception_id) references public.delivery_exceptions(tenant_id, id) on delete restrict,
  check (
    (position is null and accuracy_meters is null and location_source is null)
    or (position is not null and accuracy_meters is not null and location_source is not null)
  )
);

create index driver_emergency_events_round_reported_idx
  on public.driver_emergency_events (tenant_id, round_id, reported_at desc);

alter table public.driver_emergency_events enable row level security;
revoke all on table public.driver_emergency_events from anon, authenticated;
grant select on table public.driver_emergency_events to service_role;

create or replace function public.guard_unapproved_location_exception_resolution()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.category::text in (
      'wrong_pin', 'wrong_entrance', 'wrong_address', 'cannot_find_location', 'emergency'
    )
    and (new.status is distinct from old.status or new.resolved_at is distinct from old.resolved_at)
  then
    raise exception using
      errcode = '23514',
      message = case when old.category::text = 'emergency'
        then 'EMERGENCY_RESOLUTION_POLICY_REQUIRED'
        else 'LOCATION_RESOLUTION_POLICY_REQUIRED'
      end;
  end if;
  return new;
end;
$$;

create or replace function public.report_driver_emergency_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'stop.report_driver_emergency';
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
  v_round public.rounds%rowtype;
  v_manifest public.manifests%rowtype;
  v_driver_id uuid;
  v_actor_role public.tenant_role;
  v_safety_status text;
  v_position extensions.geography(point, 4326);
  v_accuracy double precision;
  v_location_source text;
  v_original_stop_state public.delivery_stop_state;
  v_original_delivery_state public.delivery_state;
  v_stage text;
  v_emergency_id uuid := gen_random_uuid();
  v_exception_id uuid := gen_random_uuid();
  v_event_id uuid := gen_random_uuid();
  v_system_message_id uuid := gen_random_uuid();
  v_thread_id uuid;
  v_occurred_at timestamptz := now();
  v_stop_version bigint;
  v_event_payload jsonb;
  v_event jsonb;
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
    v_safety_status := p_command #>> '{payload,safetyStatus}';
    if v_safety_status not in ('safe', 'urgent') then raise exception 'invalid safety status'; end if;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Emergency identifiers, safety status or version are invalid'));
  end;

  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200 or v_payload is null then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Emergency payload is invalid'));
  end if;
  if v_payload ? 'position' then
    begin
      if (v_payload #>> '{position,latitude}')::double precision not between -90 and 90
         or (v_payload #>> '{position,longitude}')::double precision not between -180 and 180
         or (v_payload #>> '{position,accuracyMeters}')::double precision < 0
         or v_payload #>> '{position,source}' not in ('google_nav', 'rounds_os', 'unknown') then
        raise exception 'invalid position';
      end if;
      v_position := extensions.st_setsrid(extensions.st_makepoint(
        (v_payload #>> '{position,longitude}')::double precision,
        (v_payload #>> '{position,latitude}')::double precision), 4326)::extensions.geography;
      v_accuracy := (v_payload #>> '{position,accuracyMeters}')::double precision;
      v_location_source := v_payload #>> '{position,source}';
    exception when others then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'VALIDATION_FAILED', 'message', 'Emergency position evidence is invalid'));
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
   where stop.id = v_stop_id and stop.tenant_id = v_tenant_id
     and round_record.driver_id = v_driver_id and round_record.deleted_at is null
   for update of stop;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Stop is not assigned to this Team driver'));
  end if;
  if v_stop.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Stop changed; refresh before reporting the emergency'));
  end if;
  if exists (select 1 from public.delivery_exceptions e where e.tenant_id=v_tenant_id and e.stop_id=v_stop_id and e.status='open') then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Stop already has an open Operations hold'));
  end if;

  select round_record.* into v_round from public.rounds round_record
    join public.round_stops assigned on assigned.round_id = round_record.id and assigned.tenant_id = round_record.tenant_id
   where assigned.stop_id = v_stop_id and round_record.tenant_id = v_tenant_id
     and round_record.driver_id = v_driver_id for update of round_record;
  select * into v_delivery from public.deliveries
   where id = v_stop.delivery_id and tenant_id = v_tenant_id and deleted_at is null for update;
  if not found or v_round.state not in ('approved', 'loading', 'active')
     or not ((v_stop.state = 'assigned' and v_delivery.state in ('assigned', 'pickup_pending'))
          or (v_stop.state = 'active' and v_delivery.state = 'in_custody')
          or (v_stop.state = 'arrived' and v_delivery.state = 'arrived')) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Emergency must be attached to the current assigned or in-custody Stop'));
  end if;

  select * into v_manifest from public.manifests
   where id = (v_payload ->> 'manifestId')::uuid and tenant_id = v_tenant_id
     and delivery_id = v_delivery.id and version = (v_payload ->> 'manifestVersion')::bigint for update;
  if not found or v_manifest.state not in ('draft', 'picked_up_locked') then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'CUSTODY_LOCKED', 'message', 'Emergency does not match the current custody manifest'));
  end if;

  v_original_stop_state := v_stop.state;
  v_original_delivery_state := v_delivery.state;
  v_stage := case when v_manifest.state = 'draft' then 'pickup' else 'delivery' end;
  insert into public.delivery_exceptions (
    id, tenant_id, delivery_id, stop_id, round_id, driver_id, manifest_id,
    manifest_version, stage, category, note, observed_position,
    observed_accuracy_meters, observed_location_source, original_stop_state,
    original_delivery_state, actor_person_id, occurred_from_device_at,
    reported_at, command_id
  ) values (
    v_exception_id, v_tenant_id, v_delivery.id, v_stop_id, v_round.id,
    v_driver_id, v_manifest.id, v_manifest.version, v_stage, 'emergency',
    'Driver safety status: ' || v_safety_status, v_position, v_accuracy,
    v_location_source, v_original_stop_state, v_original_delivery_state,
    p_actor_person_id, v_occurred_from_device_at, v_occurred_at, v_command_id
  );

  insert into public.driver_emergency_events (
    id, tenant_id, round_id, stop_id, delivery_id, driver_id, exception_id,
    safety_status, position, accuracy_meters, location_source, actor_person_id,
    occurred_from_device_at, reported_at, command_id
  ) values (
    v_emergency_id, v_tenant_id, v_round.id, v_stop_id, v_delivery.id,
    v_driver_id, v_exception_id, v_safety_status, v_position, v_accuracy,
    v_location_source, p_actor_person_id, v_occurred_from_device_at,
    v_occurred_at, v_command_id
  );

  update public.deliveries set state='exception', version=version+1, updated_at=v_occurred_at where id=v_delivery.id;
  update public.delivery_stops set state='exception', version=version+1, updated_at=v_occurred_at
   where id=v_stop_id returning version into v_stop_version;
  update public.rounds set version=version+1, updated_at=v_occurred_at where id=v_round.id;

  insert into public.operations_threads (tenant_id, round_id, stop_id, driver_id, priority, updated_at)
  values (v_tenant_id, v_round.id, v_stop_id, v_driver_id, 'emergency', v_occurred_at)
  on conflict (tenant_id, round_id, stop_id) do update
    set priority='emergency', updated_at=excluded.updated_at
  returning id into v_thread_id;
  insert into public.operations_messages (
    id, tenant_id, thread_id, sender, body, occurred_from_device_at, sent_at, command_id
  ) values (
    v_system_message_id, v_tenant_id, v_thread_id, 'system',
    'DRIVER EMERGENCY · Safety status: ' || upper(v_safety_status) ||
      case when v_position is null then ' · Location unavailable' else ' · Location attached' end,
    v_occurred_from_device_at, v_occurred_at, v_command_id
  );
  update public.operations_threads set version=version+1, updated_at=v_occurred_at where id=v_thread_id;

  v_event_payload := jsonb_build_object(
    'emergencyEventId', v_emergency_id, 'exceptionId', v_exception_id,
    'stopId', v_stop_id, 'deliveryId', v_delivery.id, 'roundId', v_round.id,
    'safetyStatus', v_safety_status, 'hasPositionEvidence', v_position is not null,
    'operationsThreadId', v_thread_id);
  v_event := jsonb_build_object(
    'event', 'stop.driver_emergency_reported', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'stop',
    'aggregateId', v_stop_id, 'aggregateVersion', v_stop_version,
    'occurredAt', v_occurred_at, 'payload', v_event_payload);
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'stop.driver_emergency_reported',
    'stop', v_stop_id, v_stop_version, v_command_id, v_trace_id,
    jsonb_build_object(
      'state', jsonb_build_object('from', v_original_stop_state, 'to', 'exception'),
      'deliveryState', jsonb_build_object('from', v_original_delivery_state, 'to', 'exception'),
      'emergencyEventId', v_emergency_id, 'exceptionId', v_exception_id,
      'safetyStatus', v_safety_status, 'hasPositionEvidence', v_position is not null,
      'emergencyHold', true, 'custodyDisposition', 'preserved'));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'stop.driver_emergency_reported', 1, 'stop',
    v_stop_id, v_stop_version, v_trace_id, v_event, v_occurred_at);
  v_result := jsonb_build_object(
    'status', 'committed', 'aggregateVersion', v_stop_version,
    'state', v_event_payload || jsonb_build_object(
      'stopState', 'exception', 'deliveryState', 'exception', 'emergencyHold', true),
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

revoke all on function public.report_driver_emergency_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.report_driver_emergency_command(jsonb, uuid) to service_role;

comment on function public.report_driver_emergency_command(jsonb, uuid) is
  'Server-only typed G05 command. Records safety status, opens a priority Operations hold, and preserves custody without inventing acknowledgement or resolution.';
