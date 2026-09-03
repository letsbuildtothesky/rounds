-- Slice 2: audited date-specific own-team shift overrides and days off.

create or replace function public.set_driver_shift_exception_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'operations.set_driver_shift_exception';
  v_tenant_id uuid;
  v_driver_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_exception public.driver_shift_exceptions%rowtype;
  v_actor_role public.tenant_role;
  v_service_date date;
  v_kind text;
  v_start_local time;
  v_end_local time;
  v_vehicle_profile_id uuid;
  v_note text;
  v_timezone text;
  v_occurred_at timestamptz := now();
  v_exception_id uuid;
  v_exception_version bigint;
  v_event_id uuid := gen_random_uuid();
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
    v_driver_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_service_date := (p_command -> 'payload' ->> 'serviceDate')::date;
    v_kind := p_command -> 'payload' ->> 'kind';
    if v_kind = 'shift' then
      v_start_local := (p_command -> 'payload' ->> 'startLocal')::time;
      v_end_local := (p_command -> 'payload' ->> 'endLocal')::time;
      v_vehicle_profile_id := (p_command -> 'payload' ->> 'vehicleProfileId')::uuid;
    end if;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Exception identifiers, version, date or time values are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  v_note := nullif(btrim(coalesce(v_payload ->> 'note', '')), '');
  if v_expected_version < 0 or v_idempotency_key = '' or length(v_idempotency_key) > 200
    or v_kind not in ('shift', 'off') or coalesce(length(v_note), 0) > 500
    or (v_kind = 'shift' and (v_start_local is null or v_end_local is null or v_start_local = v_end_local or v_vehicle_profile_id is null))
    or (v_kind = 'off' and (v_payload ? 'startLocal' or v_payload ? 'endLocal' or v_payload ? 'vehicleProfileId')) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Date-specific shift exception payload is invalid'));
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

  select membership.role into v_actor_role from public.tenant_memberships membership
   where membership.tenant_id = v_tenant_id and membership.person_id = p_actor_person_id
     and membership.status = 'active' and membership.role in ('tenant_owner', 'operations_admin', 'dispatcher')
   limit 1;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Driver shift exception configuration is not permitted'));
  end if;
  if not exists (
    select 1 from public.driver_tenant_relationships relationship
    join public.driver_profiles driver on driver.id = relationship.driver_id
    where relationship.tenant_id = v_tenant_id and relationship.driver_id = v_driver_id
      and relationship.relationship_kind = 'team' and relationship.status = 'active'
      and relationship.deleted_at is null and driver.active = true and driver.deleted_at is null
  ) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Driver is not an active own-team driver in this tenant'));
  end if;
  if v_kind = 'shift' and not exists (
    select 1 from public.vehicle_profiles profile
    where profile.id = v_vehicle_profile_id and profile.tenant_id = v_tenant_id
      and profile.active = true and profile.deleted_at is null
  ) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Vehicle profile is not active in this tenant'));
  end if;
  select timezone into v_timezone from public.tenants
    where id = v_tenant_id and status = 'active' and deleted_at is null;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Tenant timezone is unavailable'));
  end if;

  select * into v_exception from public.driver_shift_exceptions
   where tenant_id = v_tenant_id and driver_id = v_driver_id and service_date = v_service_date for update;
  if found then
    if v_exception.version <> v_expected_version then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'STALE_VERSION', 'message', 'Driver date exception changed; refresh before saving'));
    end if;
    update public.driver_shift_exceptions
       set exception_kind = v_kind, start_local = v_start_local, end_local = v_end_local,
           timezone = v_timezone, vehicle_profile_id = v_vehicle_profile_id,
           note = v_note, version = version + 1, updated_at = v_occurred_at, deleted_at = null
     where id = v_exception.id
     returning id, version into v_exception_id, v_exception_version;
  else
    if v_expected_version <> 0 then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'STALE_VERSION', 'message', 'Driver date exception does not exist; refresh before saving'));
    end if;
    insert into public.driver_shift_exceptions (
      tenant_id, driver_id, service_date, exception_kind, start_local, end_local,
      timezone, vehicle_profile_id, note
    ) values (
      v_tenant_id, v_driver_id, v_service_date, v_kind, v_start_local, v_end_local,
      v_timezone, v_vehicle_profile_id, v_note
    ) returning id, version into v_exception_id, v_exception_version;
  end if;

  v_state := jsonb_strip_nulls(jsonb_build_object(
    'exceptionId', v_exception_id, 'driverId', v_driver_id, 'serviceDate', v_service_date,
    'kind', v_kind, 'startLocal', case when v_start_local is null then null else to_char(v_start_local, 'HH24:MI') end,
    'endLocal', case when v_end_local is null then null else to_char(v_end_local, 'HH24:MI') end,
    'vehicleProfileId', v_vehicle_profile_id, 'updatedAt', v_occurred_at));
  v_event := jsonb_build_object(
    'event', 'operations.driver_shift_exception_set', 'version', 1,
    'eventId', v_event_id, 'traceId', v_trace_id, 'tenantId', v_tenant_id,
    'aggregateType', 'driver_shift_exception', 'aggregateId', v_driver_id,
    'aggregateVersion', v_exception_version, 'occurredAt', v_occurred_at, 'payload', v_state);
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role,
    'operations.driver_shift_exception_set', 'driver_shift_exception', v_driver_id,
    v_exception_version, v_command_id, v_trace_id,
    jsonb_build_object('serviceDate', v_service_date, 'kind', v_kind,
      'startLocal', v_start_local, 'endLocal', v_end_local,
      'vehicleProfileId', v_vehicle_profile_id, 'note', v_note));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'operations.driver_shift_exception_set', 1,
    'driver_shift_exception', v_driver_id, v_exception_version, v_trace_id, v_event, v_occurred_at);
  v_result := jsonb_build_object(
    'status', 'committed', 'aggregateVersion', v_exception_version,
    'state', v_state, 'events', jsonb_build_array(v_event));
  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_driver_id,
    v_payload_hash, 'committed', v_result, v_trace_id, p_actor_person_id);
  return v_result;
end;
$$;

revoke all on function public.set_driver_shift_exception_command(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.set_driver_shift_exception_command(jsonb, uuid) to service_role;

comment on function public.set_driver_shift_exception_command(jsonb, uuid) is
  'Server-only, versioned and audited date-specific shift or day-off command for an active own-team driver.';
