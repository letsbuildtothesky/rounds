-- Operations may release a pickup-blocking exception only after recording a
-- durable correction note. The Stop returns to assigned so the same driver can
-- re-check the physical manifest before custody is transferred.

create or replace function public.resolve_operations_exception_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'operations.resolve_exception';
  v_tenant_id uuid;
  v_stop_id uuid;
  v_exception_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_exception public.delivery_exceptions%rowtype;
  v_stop public.delivery_stops%rowtype;
  v_delivery public.deliveries%rowtype;
  v_actor_role public.tenant_role;
  v_resolution text;
  v_note text;
  v_occurred_at timestamptz := now();
  v_stop_version bigint;
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
    v_stop_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_exception_id := (p_command -> 'payload' ->> 'exceptionId')::uuid;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Exception identifiers or version are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  v_resolution := coalesce(v_payload ->> 'resolution', '');
  v_note := btrim(coalesce(v_payload ->> 'note', ''));
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
    or v_resolution <> 'pickup_corrected' or length(v_note) < 1 or length(v_note) > 500 then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Exception resolution payload is invalid'));
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
      'code', 'NOT_AUTHORIZED', 'message', 'Exception resolution is not permitted'));
  end if;

  select * into v_exception from public.delivery_exceptions
   where id = v_exception_id and tenant_id = v_tenant_id for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Exception is not available in this tenant'));
  end if;
  if v_exception.status <> 'open' then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Exception has already been resolved'));
  end if;
  if v_exception.stage <> 'pickup' or v_exception.stop_id <> v_stop_id then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Only the matching pickup exception can be released'));
  end if;
  if not exists (select 1 from public.rounds where id = v_exception.round_id and tenant_id = v_tenant_id
    and state in ('approved', 'loading') and deleted_at is null) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Round is no longer awaiting pickup'));
  end if;

  select * into v_stop from public.delivery_stops
   where id = v_stop_id and tenant_id = v_tenant_id for update;
  if not found or v_stop.state <> 'exception' then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Stop is no longer blocked by this exception'));
  end if;
  if v_stop.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Stop changed; refresh before resolving the exception'));
  end if;
  select * into v_delivery from public.deliveries
   where id = v_exception.delivery_id and tenant_id = v_tenant_id and state = 'exception' and deleted_at is null for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Delivery is no longer blocked by this exception'));
  end if;

  update public.delivery_exceptions set status = 'resolved', resolved_at = v_occurred_at where id = v_exception_id;
  update public.deliveries set state = 'assigned', version = version + 1, updated_at = v_occurred_at where id = v_delivery.id;
  update public.delivery_stops set state = 'assigned', version = version + 1, updated_at = v_occurred_at
   where id = v_stop_id returning version into v_stop_version;

  v_state := jsonb_build_object(
    'exceptionId', v_exception_id, 'stopId', v_stop_id, 'deliveryId', v_delivery.id,
    'roundId', v_exception.round_id, 'resolution', v_resolution, 'resolvedAt', v_occurred_at,
    'stopState', 'assigned', 'deliveryState', 'assigned');
  v_event := jsonb_build_object(
    'event', 'operations.exception_resolved', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'stop',
    'aggregateId', v_stop_id, 'aggregateVersion', v_stop_version, 'occurredAt', v_occurred_at,
    'payload', v_state - 'stopState' - 'deliveryState');
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'operations.exception_resolved', 'stop', v_stop_id,
    v_stop_version, v_command_id, v_trace_id,
    jsonb_build_object('exceptionId', v_exception_id, 'resolution', v_resolution, 'note', v_note,
      'state', jsonb_build_object('from', 'exception', 'to', 'assigned')));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'operations.exception_resolved', 1, 'stop', v_stop_id,
    v_stop_version, v_trace_id, v_event, v_occurred_at);
  v_result := jsonb_build_object('status', 'committed', 'aggregateVersion', v_stop_version,
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

revoke all on function public.resolve_operations_exception_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.resolve_operations_exception_command(jsonb, uuid) to service_role;

comment on function public.resolve_operations_exception_command(jsonb, uuid) is
  'Server-only audited Operations command that releases a corrected pickup exception back to assigned.';
