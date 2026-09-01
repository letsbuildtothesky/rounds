-- Pilot/Slice 1: exact manifest verification and the first durable custody
-- transfer. The server commits the full pickup for one Round atomically.

create type public.manifest_verification_stage as enum ('pickup', 'handoff');
create type public.custody_event_type as enum (
  'merchant_to_driver',
  'driver_to_recipient',
  'driver_returned_to_merchant',
  'driver_to_driver'
);

create table public.manifest_verifications (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  manifest_id uuid not null,
  manifest_version bigint not null check (manifest_version > 0),
  delivery_id uuid not null,
  stop_id uuid not null,
  round_id uuid not null,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  stage public.manifest_verification_stage not null,
  confirmed_line_numbers integer[] not null check (cardinality(confirmed_line_numbers) > 0),
  verified_units integer not null check (verified_units > 0),
  expected_units integer not null check (expected_units > 0),
  actor_person_id uuid not null references public.persons(id) on delete restrict,
  occurred_from_device_at timestamptz,
  verified_at timestamptz not null default now(),
  command_id uuid not null,
  unique (manifest_id, manifest_version, stage),
  unique (tenant_id, id),
  foreign key (tenant_id, manifest_id) references public.manifests(tenant_id, id) on delete restrict,
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id) references public.delivery_stops(tenant_id, id) on delete restrict,
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict,
  check (verified_units = expected_units)
);

create table public.custody_events (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  delivery_id uuid not null,
  stop_id uuid not null,
  round_id uuid not null,
  manifest_id uuid not null,
  manifest_version bigint not null check (manifest_version > 0),
  manifest_verification_id uuid not null,
  event_type public.custody_event_type not null,
  from_party_type text not null,
  from_party_id uuid,
  to_party_type text not null,
  to_party_id uuid,
  actor_person_id uuid not null references public.persons(id) on delete restrict,
  occurred_from_device_at timestamptz,
  occurred_at timestamptz not null default now(),
  command_id uuid not null,
  unique (manifest_verification_id),
  unique (tenant_id, id),
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id) references public.delivery_stops(tenant_id, id) on delete restrict,
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict,
  foreign key (tenant_id, manifest_id) references public.manifests(tenant_id, id) on delete restrict,
  foreign key (tenant_id, manifest_verification_id) references public.manifest_verifications(tenant_id, id) on delete restrict
);

create index manifest_verifications_round_idx
  on public.manifest_verifications (tenant_id, round_id, stage, verified_at);
create index custody_events_delivery_idx
  on public.custody_events (tenant_id, delivery_id, occurred_at);

alter table public.manifest_verifications enable row level security;
alter table public.custody_events enable row level security;
revoke all on table public.manifest_verifications, public.custody_events from anon, authenticated;
grant select on table public.manifest_verifications, public.custody_events to service_role;

create or replace function public.confirm_round_pickup_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'round.confirm_pickup';
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
  v_stop_payload jsonb;
  v_stop_id uuid;
  v_manifest_id uuid;
  v_manifest_version bigint;
  v_line_numbers integer[];
  v_line_count integer;
  v_delivery_id uuid;
  v_pickup_location_id uuid;
  v_manifest public.manifests%rowtype;
  v_expected_line_count integer;
  v_expected_units integer;
  v_verification_id uuid;
  v_custody_event_id uuid;
  v_confirmed_stops jsonb := '[]'::jsonb;
  v_stop_count integer;
  v_round_version bigint;
  v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now();
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
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Command identifiers or versions are invalid'));
  end;

  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
    or v_payload is null or jsonb_typeof(v_payload -> 'stops') <> 'array' then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Pickup requires version, idempotency key and Stop confirmations'));
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
    return v_existing.result;
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
      'code', 'STALE_VERSION', 'message', 'Round changed; refresh assigned work before confirming pickup'));
  end if;

  v_stop_count := jsonb_array_length(v_payload -> 'stops');
  if v_stop_count < 1
    or v_stop_count <> (select count(*) from public.round_stops where round_id = v_round_id)
    or v_stop_count <> (select count(distinct entry ->> 'stopId') from jsonb_array_elements(v_payload -> 'stops') entry)
    or exists (
      select 1 from public.round_stops assigned
       where assigned.round_id = v_round_id
         and not exists (
           select 1 from jsonb_array_elements(v_payload -> 'stops') entry
            where entry ->> 'stopId' = assigned.stop_id::text
         )
    ) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Every assigned Stop must be confirmed exactly once'));
  end if;

  -- Validate every line before writing anything, so a mismatch cannot create
  -- partial custody for a multi-Stop Round.
  for v_stop_payload in select value from jsonb_array_elements(v_payload -> 'stops') loop
    begin
      v_stop_id := (v_stop_payload ->> 'stopId')::uuid;
      v_manifest_id := (v_stop_payload ->> 'manifestId')::uuid;
      v_manifest_version := (v_stop_payload ->> 'manifestVersion')::bigint;
      select array_agg(value::integer order by value::integer), count(*)
        into v_line_numbers, v_line_count
        from jsonb_array_elements_text(v_stop_payload -> 'confirmedLineNumbers');
    exception when others then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'VALIDATION_FAILED', 'message', 'Pickup Stop or manifest confirmation is invalid'));
    end;
    if v_line_count < 1 or v_line_count <> (select count(distinct line_number) from unnest(v_line_numbers) line_number)
      or exists (select 1 from unnest(v_line_numbers) line_number where line_number < 1) then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'VALIDATION_FAILED', 'message', 'Confirmed manifest lines must be unique positive integers'));
    end if;

    select stop.delivery_id, delivery.pickup_location_id into v_delivery_id, v_pickup_location_id
      from public.round_stops assigned
      join public.delivery_stops stop on stop.id = assigned.stop_id and stop.tenant_id = assigned.tenant_id
      join public.deliveries delivery on delivery.id = stop.delivery_id and delivery.tenant_id = stop.tenant_id
     where assigned.round_id = v_round_id and assigned.stop_id = v_stop_id
       and stop.state = 'assigned' and delivery.state = 'assigned'
     for update of stop, delivery;
    if not found then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'INVALID_STATE', 'message', 'A Stop is no longer assigned and ready for pickup'));
    end if;

    select * into v_manifest from public.manifests
     where id = v_manifest_id and tenant_id = v_tenant_id and delivery_id = v_delivery_id
     for update;
    if not found or v_manifest.state <> 'draft' or v_manifest.version <> v_manifest_version then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'CUSTODY_LOCKED', 'message', 'Manifest version changed or was already picked up'));
    end if;

    select count(*), coalesce(sum(quantity), 0) into v_expected_line_count, v_expected_units
      from public.manifest_items where manifest_id = v_manifest_id;
    if v_expected_line_count < 1 or v_line_count <> v_expected_line_count
      or (select count(*) from public.manifest_items
           where manifest_id = v_manifest_id and line_number = any(v_line_numbers)) <> v_expected_line_count then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'EVIDENCE_REQUIRED', 'message', 'Every physical manifest line must be verified before pickup'));
    end if;
  end loop;

  for v_stop_payload in select value from jsonb_array_elements(v_payload -> 'stops') loop
    v_stop_id := (v_stop_payload ->> 'stopId')::uuid;
    v_manifest_id := (v_stop_payload ->> 'manifestId')::uuid;
    v_manifest_version := (v_stop_payload ->> 'manifestVersion')::bigint;
    select array_agg(value::integer order by value::integer)
      into v_line_numbers from jsonb_array_elements_text(v_stop_payload -> 'confirmedLineNumbers');
    select stop.delivery_id, delivery.pickup_location_id into v_delivery_id, v_pickup_location_id
      from public.delivery_stops stop join public.deliveries delivery on delivery.id = stop.delivery_id
     where stop.id = v_stop_id;
    select coalesce(sum(quantity), 0) into v_expected_units
      from public.manifest_items where manifest_id = v_manifest_id;

    v_verification_id := gen_random_uuid();
    v_custody_event_id := gen_random_uuid();
    insert into public.manifest_verifications (
      id, tenant_id, manifest_id, manifest_version, delivery_id, stop_id, round_id,
      driver_id, stage, confirmed_line_numbers, verified_units, expected_units,
      actor_person_id, occurred_from_device_at, verified_at, command_id
    ) values (
      v_verification_id, v_tenant_id, v_manifest_id, v_manifest_version, v_delivery_id, v_stop_id, v_round_id,
      v_driver_id, 'pickup', v_line_numbers, v_expected_units, v_expected_units,
      p_actor_person_id, v_occurred_from_device_at, v_occurred_at, v_command_id
    );
    insert into public.custody_events (
      id, tenant_id, delivery_id, stop_id, round_id, manifest_id, manifest_version,
      manifest_verification_id, event_type, from_party_type, from_party_id,
      to_party_type, to_party_id, actor_person_id, occurred_from_device_at, occurred_at, command_id
    ) values (
      v_custody_event_id, v_tenant_id, v_delivery_id, v_stop_id, v_round_id, v_manifest_id, v_manifest_version,
      v_verification_id, 'merchant_to_driver', 'tenant_location', v_pickup_location_id,
      'driver', v_driver_id, p_actor_person_id, v_occurred_from_device_at, v_occurred_at, v_command_id
    );
    update public.manifests manifest
       set state = 'picked_up_locked', locked_at = v_occurred_at, updated_at = v_occurred_at
     where manifest.id = v_manifest_id;
    update public.deliveries delivery
       set state = 'pickup_pending', version = delivery.version + 1, updated_at = v_occurred_at
     where delivery.id = v_delivery_id;
    update public.deliveries delivery
       set state = 'in_custody', version = delivery.version + 1, updated_at = v_occurred_at
     where delivery.id = v_delivery_id;
    update public.delivery_stops stop
       set state = 'active', version = stop.version + 1, updated_at = v_occurred_at
     where stop.id = v_stop_id;

    v_confirmed_stops := v_confirmed_stops || jsonb_build_array(jsonb_build_object(
      'stopId', v_stop_id, 'deliveryId', v_delivery_id, 'manifestId', v_manifest_id,
      'manifestVersion', v_manifest_version, 'verificationId', v_verification_id,
      'custodyEventId', v_custody_event_id, 'verifiedUnits', v_expected_units));
  end loop;

  update public.rounds round_update
     set state = 'active', version = round_update.version + 1, updated_at = v_occurred_at
   where round_update.id = v_round_id
   returning round_update.version into v_round_version;

  v_event := jsonb_build_object(
    'event', 'round.pickup_confirmed', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'round',
    'aggregateId', v_round_id, 'aggregateVersion', v_round_version, 'occurredAt', v_occurred_at,
    'payload', jsonb_build_object('roundId', v_round_id, 'driverId', v_driver_id, 'stops', v_confirmed_stops)
  );
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'round.pickup_confirmed', 'round', v_round_id,
    v_round_version, v_command_id, v_trace_id,
    jsonb_build_object('state', jsonb_build_object('from', v_round.state, 'to', 'active'), 'stops', v_confirmed_stops)
  );
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'round.pickup_confirmed', 1, 'round', v_round_id,
    v_round_version, v_trace_id, v_event, v_occurred_at
  );

  v_result := jsonb_build_object(
    'status', 'committed', 'aggregateVersion', v_round_version,
    'state', jsonb_build_object('roundId', v_round_id, 'roundState', 'active', 'driverId', v_driver_id, 'stops', v_confirmed_stops),
    'events', jsonb_build_array(v_event)
  );
  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_round_id,
    v_payload_hash, 'committed', v_result, v_trace_id, p_actor_person_id
  );
  return v_result;
exception
  when unique_violation then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'IDEMPOTENCY_CONFLICT', 'message', 'Pickup verification or command already exists'));
end;
$$;

revoke all on function public.confirm_round_pickup_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.confirm_round_pickup_command(jsonb, uuid) to service_role;

comment on function public.confirm_round_pickup_command(jsonb, uuid) is
  'Slice 1 server-only Team-driver pickup. Verifies every assigned manifest line and commits immutable custody atomically.';
