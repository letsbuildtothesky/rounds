-- A delivery-stage damage exception closes only after Operations confirms that
-- the physical item is back with the merchant. This is distinct from ordering
-- a future return or creating replacement work.

create or replace function public.is_valid_delivery_transition(
  p_from public.delivery_state,
  p_to public.delivery_state
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select p_from = p_to or (p_from, p_to) in (
    ('draft'::public.delivery_state, 'unplanned'::public.delivery_state),
    ('draft'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('unplanned'::public.delivery_state, 'planned'::public.delivery_state),
    ('unplanned'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('planned'::public.delivery_state, 'assigned'::public.delivery_state),
    ('planned'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('assigned'::public.delivery_state, 'pickup_pending'::public.delivery_state),
    ('assigned'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('pickup_pending'::public.delivery_state, 'in_custody'::public.delivery_state),
    ('pickup_pending'::public.delivery_state, 'exception'::public.delivery_state),
    ('pickup_pending'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('in_custody'::public.delivery_state, 'en_route'::public.delivery_state),
    ('in_custody'::public.delivery_state, 'exception'::public.delivery_state),
    ('in_custody'::public.delivery_state, 'returned'::public.delivery_state),
    ('en_route'::public.delivery_state, 'arrived'::public.delivery_state),
    ('en_route'::public.delivery_state, 'exception'::public.delivery_state),
    ('en_route'::public.delivery_state, 'returned'::public.delivery_state),
    ('arrived'::public.delivery_state, 'delivered_pending_evidence'::public.delivery_state),
    ('arrived'::public.delivery_state, 'exception'::public.delivery_state),
    ('arrived'::public.delivery_state, 'returned'::public.delivery_state),
    ('delivered_pending_evidence'::public.delivery_state, 'delivered'::public.delivery_state),
    ('delivered_pending_evidence'::public.delivery_state, 'exception'::public.delivery_state),
    ('exception'::public.delivery_state, 'assigned'::public.delivery_state),
    ('exception'::public.delivery_state, 'returned'::public.delivery_state)
  );
$$;

comment on function public.is_valid_delivery_transition(public.delivery_state, public.delivery_state) is
  'Canonical delivery state graph, including audited pickup recovery and confirmed physical return after an exception.';

create or replace function public.confirm_delivery_return_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'operations.confirm_delivery_return';
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
      'code', 'VALIDATION_FAILED', 'message', 'Return confirmation identifiers or version are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  v_note := btrim(coalesce(v_payload ->> 'note', ''));
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
    or length(v_note) < 1 or length(v_note) > 500 then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Delivery return confirmation payload is invalid'));
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
      'code', 'NOT_AUTHORIZED', 'message', 'Delivery return confirmation is not permitted'));
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
  if v_exception.stage <> 'delivery' or v_exception.category <> 'damaged_item' or v_exception.stop_id <> v_stop_id then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Only the matching delivery-stage damage exception can confirm a return'));
  end if;
  if not exists (select 1 from public.rounds where id = v_exception.round_id and tenant_id = v_tenant_id
    and state = 'active' and deleted_at is null) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Round is no longer active'));
  end if;

  select * into v_stop from public.delivery_stops
   where id = v_stop_id and tenant_id = v_tenant_id for update;
  if not found or v_stop.state <> 'exception' then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Stop is no longer blocked by this damage exception'));
  end if;
  if v_stop.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Stop changed; refresh before confirming the return'));
  end if;
  select * into v_delivery from public.deliveries
   where id = v_exception.delivery_id and tenant_id = v_tenant_id and state = 'exception' and deleted_at is null for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Delivery is no longer blocked by this exception'));
  end if;

  update public.delivery_exceptions set status = 'resolved', resolved_at = v_occurred_at where id = v_exception_id;
  update public.deliveries set state = 'returned', version = version + 1, updated_at = v_occurred_at where id = v_delivery.id;
  update public.delivery_stops set state = 'cancelled', version = version + 1, updated_at = v_occurred_at
   where id = v_stop_id returning version into v_stop_version;

  v_state := jsonb_build_object(
    'exceptionId', v_exception_id, 'stopId', v_stop_id, 'deliveryId', v_delivery.id,
    'roundId', v_exception.round_id, 'resolution', 'delivery_returned', 'returnedAt', v_occurred_at,
    'stopState', 'cancelled', 'deliveryState', 'returned');
  v_event := jsonb_build_object(
    'event', 'operations.delivery_return_confirmed', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'stop',
    'aggregateId', v_stop_id, 'aggregateVersion', v_stop_version, 'occurredAt', v_occurred_at,
    'payload', v_state - 'stopState' - 'deliveryState');
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'operations.delivery_return_confirmed', 'stop', v_stop_id,
    v_stop_version, v_command_id, v_trace_id,
    jsonb_build_object('exceptionId', v_exception_id, 'resolution', 'delivery_returned', 'note', v_note,
      'state', jsonb_build_object('from', 'exception', 'to', 'returned'),
      'physicalTruth', 'merchant_received_return'));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'operations.delivery_return_confirmed', 1, 'stop', v_stop_id,
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

revoke all on function public.confirm_delivery_return_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.confirm_delivery_return_command(jsonb, uuid) to service_role;

comment on function public.confirm_delivery_return_command(jsonb, uuid) is
  'Server-only audited Operations command that closes a delivery-stage damage exception after the merchant physically receives the returned item.';
