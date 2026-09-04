-- A01B/L01 authenticated locale persistence. The device preference remains
-- immediate/offline truth; this command versions its cross-device profile sync.

create or replace function public.update_driver_preferred_locale_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'driver.update_preferred_locale';
  v_tenant_id uuid;
  v_driver_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_idempotency_key text;
  v_occurred_from_device_at timestamptz;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_driver public.driver_profiles%rowtype;
  v_preferred_locale text;
  v_occurred_at timestamptz := now();
  v_event_id uuid := gen_random_uuid();
  v_state jsonb;
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
    v_driver_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_occurred_from_device_at :=
      nullif(p_command ->> 'occurredFromDeviceAt', '')::timestamptz;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED',
      'message', 'Driver locale identifiers or version are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  v_preferred_locale := coalesce(v_payload ->> 'preferredLocale', '');
  if v_expected_version < 1
     or v_idempotency_key = ''
     or length(v_idempotency_key) > 200
     or v_payload is null
     or v_preferred_locale not in ('th-TH', 'en') then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED',
      'message', 'Preferred locale must be th-TH or en'));
  end if;

  v_payload_hash := encode(digest(v_payload::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(
    v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key,
    0
  ));
  select * into v_existing
    from public.command_idempotency
   where tenant_id = v_tenant_id
     and command_type = v_command_type
     and idempotency_key = v_idempotency_key;
  if found then
    if v_existing.payload_hash <> v_payload_hash then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'IDEMPOTENCY_CONFLICT',
        'message', 'Idempotency key was already used with different payload'));
    end if;
    return v_existing.result || jsonb_build_object('deduplicated', true);
  end if;

  select driver.* into v_driver
    from public.driver_profiles driver
    join public.tenant_memberships membership
      on membership.tenant_id = v_tenant_id
     and membership.person_id = driver.person_id
    join public.driver_tenant_relationships relationship
      on relationship.tenant_id = v_tenant_id
     and relationship.driver_id = driver.id
   where driver.id = v_driver_id
     and driver.person_id = p_actor_person_id
     and driver.active = true
     and driver.deleted_at is null
     and membership.status = 'active'
     and membership.role = 'team_driver'
     and relationship.relationship_kind = 'team'
     and relationship.status = 'active'
     and relationship.deleted_at is null
   for update of driver;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED',
      'message', 'Actor is not this active Team driver'));
  end if;
  if v_driver.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION',
      'message', 'Driver profile changed; refresh before syncing language'));
  end if;

  update public.driver_profiles
     set preferred_locale = v_preferred_locale,
         version = version + 1,
         updated_at = v_occurred_at
   where id = v_driver_id;

  v_state := jsonb_build_object(
    'driverId', v_driver_id,
    'preferredLocale', v_preferred_locale,
    'previousLocale', v_driver.preferred_locale
  );
  v_event := jsonb_build_object(
    'event', 'driver.preferred_locale_updated',
    'version', 1,
    'eventId', v_event_id,
    'traceId', v_trace_id,
    'tenantId', v_tenant_id,
    'aggregateType', 'driver',
    'aggregateId', v_driver_id,
    'aggregateVersion', v_expected_version + 1,
    'occurredAt', v_occurred_at,
    'payload', v_state
  );
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type,
    aggregate_id, aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, 'team_driver',
    'driver.preferred_locale_updated', 'driver', v_driver_id,
    v_expected_version + 1, v_command_id, v_trace_id,
    jsonb_build_object(
      'preferredLocale', jsonb_build_object(
        'from', v_driver.preferred_locale,
        'to', v_preferred_locale
      ),
      'occurredFromDeviceAt', v_occurred_from_device_at
    )
  );
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'driver.preferred_locale_updated', 1,
    'driver', v_driver_id, v_expected_version + 1, v_trace_id,
    v_event, v_occurred_at
  );
  v_result := jsonb_build_object(
    'status', 'committed',
    'aggregateVersion', v_expected_version + 1,
    'state', v_state,
    'events', jsonb_build_array(v_event)
  );
  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id,
    v_driver_id, v_payload_hash, 'committed', v_result, v_trace_id,
    p_actor_person_id
  );
  return v_result;
end;
$$;

revoke all on function public.update_driver_preferred_locale_command(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.update_driver_preferred_locale_command(jsonb, uuid)
  to service_role;

comment on function public.update_driver_preferred_locale_command(jsonb, uuid) is
  'Server-only versioned A01B/L01 Team-driver preferred locale sync.';
