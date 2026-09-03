-- H02 durable call evidence. The native phone app performs the call; Rounds
-- records the Driver-selected outcome after returning to the app. No call
-- connection or telephony result is fabricated.

create table public.contact_attempts (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  delivery_id uuid not null,
  stop_id uuid not null,
  round_id uuid not null,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  actor_person_id uuid not null references public.persons(id) on delete restrict,
  target text not null check (target in ('recipient', 'operations')),
  channel text not null check (channel = 'native_phone'),
  outcome text not null check (outcome in ('reached', 'no_answer', 'busy', 'call_failed')),
  occurred_from_device_at timestamptz,
  recorded_at timestamptz not null default now(),
  command_id uuid not null unique,
  unique (tenant_id, id),
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id) references public.delivery_stops(tenant_id, id) on delete restrict,
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict
);

create index contact_attempts_stop_time_idx
  on public.contact_attempts (tenant_id, stop_id, recorded_at);

alter table public.contact_attempts enable row level security;
revoke all on table public.contact_attempts from anon, authenticated;
grant select on table public.contact_attempts to service_role;

create or replace function public.log_contact_attempt_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'stop.log_contact_attempt';
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
  v_driver_id uuid;
  v_actor_role public.tenant_role;
  v_target text;
  v_channel text;
  v_outcome text;
  v_attempt_id uuid := gen_random_uuid();
  v_thread_id uuid;
  v_system_message_id uuid := gen_random_uuid();
  v_event_id uuid := gen_random_uuid();
  v_recorded_at timestamptz := now();
  v_attempt jsonb;
  v_state jsonb;
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
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Contact attempt identifiers or version are invalid'));
  end;

  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  v_target := coalesce(v_payload ->> 'target', '');
  v_channel := coalesce(v_payload ->> 'channel', '');
  v_outcome := coalesce(v_payload ->> 'outcome', '');
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
     or v_target not in ('recipient', 'operations') or v_channel <> 'native_phone'
     or v_outcome not in ('reached', 'no_answer', 'busy', 'call_failed') then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Contact attempt payload is invalid'));
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
     and round_record.state in ('approved', 'loading', 'active')
   for update of stop;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Stop is not assigned to this Team driver'));
  end if;
  if v_stop.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Stop changed; refresh before recording the contact attempt'));
  end if;
  if v_stop.state not in ('assigned', 'active', 'arrived', 'exception') then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Contact evidence is not available for this Stop state'));
  end if;

  select round_record.* into v_round from public.rounds round_record
    join public.round_stops assigned on assigned.round_id = round_record.id and assigned.tenant_id = round_record.tenant_id
   where assigned.stop_id = v_stop_id and round_record.tenant_id = v_tenant_id
     and round_record.driver_id = v_driver_id;
  select * into v_delivery from public.deliveries
   where id = v_stop.delivery_id and tenant_id = v_tenant_id and deleted_at is null;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Delivery is no longer available'));
  end if;

  insert into public.contact_attempts (
    id, tenant_id, delivery_id, stop_id, round_id, driver_id, actor_person_id,
    target, channel, outcome, occurred_from_device_at, recorded_at, command_id
  ) values (
    v_attempt_id, v_tenant_id, v_delivery.id, v_stop_id, v_round.id, v_driver_id,
    p_actor_person_id, v_target, v_channel, v_outcome,
    v_occurred_from_device_at, v_recorded_at, v_command_id
  );

  insert into public.operations_threads (tenant_id, round_id, stop_id, driver_id, updated_at)
  values (v_tenant_id, v_round.id, v_stop_id, v_driver_id, v_recorded_at)
  on conflict (tenant_id, round_id, stop_id) do update set updated_at = excluded.updated_at
  returning id into v_thread_id;
  insert into public.operations_messages (
    id, tenant_id, thread_id, sender, body, occurred_from_device_at, sent_at, command_id
  ) values (
    v_system_message_id, v_tenant_id, v_thread_id, 'system',
    initcap(v_target) || ' call · ' || replace(initcap(replace(v_outcome, '_', ' ')), 'No Answer', 'No answer'),
    v_occurred_from_device_at, v_recorded_at, v_command_id
  );
  update public.operations_threads set version = version + 1, updated_at = v_recorded_at where id = v_thread_id;

  v_attempt := jsonb_build_object(
    'id', v_attempt_id, 'target', v_target, 'channel', v_channel,
    'outcome', v_outcome, 'occurredAt', coalesce(v_occurred_from_device_at, v_recorded_at));
  v_state := jsonb_build_object(
    'stopId', v_stop_id, 'deliveryId', v_delivery.id, 'roundId', v_round.id,
    'operationsThreadId', v_thread_id, 'attempt', v_attempt);
  v_event := jsonb_build_object(
    'event', 'stop.contact_attempt_recorded', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'stop',
    'aggregateId', v_stop_id, 'aggregateVersion', v_stop.version, 'occurredAt', v_recorded_at,
    'payload', v_state);
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'stop.contact_attempt_recorded', 'stop', v_stop_id,
    v_stop.version, v_command_id, v_trace_id,
    jsonb_build_object('target', v_target, 'channel', v_channel, 'outcome', v_outcome,
      'stateMutation', false, 'contactAttemptId', v_attempt_id));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'stop.contact_attempt_recorded', 1, 'stop', v_stop_id,
    v_stop.version, v_trace_id, v_event, v_recorded_at);
  v_result := jsonb_build_object(
    'status', 'committed', 'aggregateVersion', v_stop.version,
    'state', v_state, 'events', jsonb_build_array(v_event));
  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_stop_id,
    v_payload_hash, 'committed', v_result, v_trace_id, p_actor_person_id);
  return v_result;
end;
$$;

revoke all on function public.log_contact_attempt_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.log_contact_attempt_command(jsonb, uuid) to service_role;

comment on function public.log_contact_attempt_command(jsonb, uuid) is
  'Server-only H02 call-outcome evidence command. Records a Driver-selected native-phone outcome without claiming telephony-provider truth.';
