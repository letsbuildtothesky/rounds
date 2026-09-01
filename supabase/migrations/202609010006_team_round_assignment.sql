-- Pilot/Slice 1: one server-authoritative command turns explicitly ordered,
-- unplanned delivery Stops into an approved Team-driver Round.

create or replace function public.plan_and_approve_round_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'round.plan_and_approve';
  v_tenant_id uuid;
  v_round_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_actor_role public.tenant_role;
  v_existing public.command_idempotency%rowtype;
  v_reference text;
  v_service_date date;
  v_driver_id uuid;
  v_stop_ids uuid[];
  v_stop_count integer;
  v_delivery_ids uuid[];
  v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now();
  v_event jsonb;
  v_result jsonb;
begin
  if p_command is null
    or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
    or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Unsupported command envelope')
    );
  end if;

  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_round_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
  exception when others then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Command identifiers are invalid')
    );
  end;

  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  if v_expected_version <> 0
    or v_idempotency_key = ''
    or length(v_idempotency_key) > 200
    or v_payload is null then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'A new Round requires expectedVersion 0, idempotencyKey and payload')
    );
  end if;

  v_payload_hash := encode(digest(v_payload::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key, 0));

  select * into v_existing
    from public.command_idempotency
   where tenant_id = v_tenant_id
     and command_type = v_command_type
     and idempotency_key = v_idempotency_key;

  if found then
    if v_existing.payload_hash <> v_payload_hash then
      return jsonb_build_object(
        'status', 'rejected',
        'error', jsonb_build_object('code', 'IDEMPOTENCY_CONFLICT', 'message', 'Idempotency key was already used with different payload')
      );
    end if;
    return v_existing.result;
  end if;

  select membership.role into v_actor_role
    from public.tenant_memberships membership
   where membership.tenant_id = v_tenant_id
     and membership.person_id = p_actor_person_id
     and membership.status = 'active'
     and membership.role in ('tenant_owner', 'operations_admin', 'dispatcher')
   order by case membership.role
     when 'tenant_owner' then 1
     when 'operations_admin' then 2
     else 3
   end
   limit 1;

  if v_actor_role is null then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'NOT_AUTHORIZED', 'message', 'Actor cannot approve Team Rounds for this tenant')
    );
  end if;

  begin
    v_reference := btrim(v_payload ->> 'reference');
    v_service_date := (v_payload ->> 'serviceDate')::date;
    v_driver_id := (v_payload ->> 'driverId')::uuid;
    select array_agg(value::uuid order by ordinality), count(*)
      into v_stop_ids, v_stop_count
      from jsonb_array_elements_text(v_payload -> 'stopIds') with ordinality;
  exception when others then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Round reference, date, driver or Stops are invalid')
    );
  end;

  if v_reference = '' or v_stop_count is null or v_stop_count < 1 or v_stop_count > 20
    or (select count(distinct stop_id) from unnest(v_stop_ids) stop_id) <> v_stop_count then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Round needs a reference and 1-20 unique ordered Stops')
    );
  end if;

  if not exists (
    select 1
      from public.driver_profiles driver
      join public.driver_tenant_relationships relationship
        on relationship.driver_id = driver.id
       and relationship.tenant_id = v_tenant_id
     where driver.id = v_driver_id
       and driver.active = true
       and driver.deleted_at is null
       and relationship.relationship_kind = 'team'
       and relationship.status = 'active'
       and relationship.deleted_at is null
  ) then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Driver is not an active Team driver for this tenant')
    );
  end if;

  if (
    select count(*)
      from public.delivery_stops stop
      join public.deliveries delivery
        on delivery.id = stop.delivery_id and delivery.tenant_id = stop.tenant_id
     where stop.tenant_id = v_tenant_id
       and stop.id = any(v_stop_ids)
       and stop.state = 'pending'
       and delivery.state = 'unplanned'
       and delivery.service_date = v_service_date
       and delivery.deleted_at is null
  ) <> v_stop_count then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'INVALID_STATE', 'message', 'Every Stop must be unplanned, pending and on the Round service date')
    );
  end if;

  if exists (select 1 from public.round_stops where stop_id = any(v_stop_ids)) then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'INVALID_STATE', 'message', 'One or more Stops already belong to a Round')
    );
  end if;

  if (
    select count(distinct delivery.pickup_location_id)
      from public.delivery_stops stop
      join public.deliveries delivery on delivery.id = stop.delivery_id
     where stop.id = any(v_stop_ids)
  ) <> 1 then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Pilot Rounds require one shared pickup location')
    );
  end if;

  select array_agg(stop.delivery_id order by requested.ordinality)
    into v_delivery_ids
    from unnest(v_stop_ids) with ordinality requested(stop_id, ordinality)
    join public.delivery_stops stop on stop.id = requested.stop_id;

  insert into public.rounds (
    id, tenant_id, reference, service_date, driver_id, state
  ) values (
    v_round_id, v_tenant_id, v_reference, v_service_date, v_driver_id, 'approved'
  );

  insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
  select v_tenant_id, v_round_id, requested.stop_id, requested.ordinality::integer
    from unnest(v_stop_ids) with ordinality requested(stop_id, ordinality);

  update public.deliveries delivery
     set state = 'planned', version = version + 1, updated_at = v_occurred_at
    from public.delivery_stops stop
   where stop.delivery_id = delivery.id
     and stop.id = any(v_stop_ids);

  update public.deliveries delivery
     set state = 'assigned', version = version + 1, updated_at = v_occurred_at
    from public.delivery_stops stop
   where stop.delivery_id = delivery.id
     and stop.id = any(v_stop_ids);

  update public.delivery_stops
     set state = 'assigned', version = version + 1, updated_at = v_occurred_at
   where id = any(v_stop_ids);

  v_event := jsonb_build_object(
    'event', 'round.approved',
    'version', 1,
    'eventId', v_event_id,
    'traceId', v_trace_id,
    'tenantId', v_tenant_id,
    'aggregateType', 'round',
    'aggregateId', v_round_id,
    'aggregateVersion', 1,
    'occurredAt', v_occurred_at,
    'payload', jsonb_build_object(
      'roundId', v_round_id,
      'driverId', v_driver_id,
      'stopIds', to_jsonb(v_stop_ids),
      'deliveryIds', to_jsonb(v_delivery_ids)
    )
  );

  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type,
    aggregate_id, aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'round.approved', 'round',
    v_round_id, 1, v_command_id, v_trace_id,
    jsonb_build_object('state', jsonb_build_object('from', null, 'to', 'approved'), 'driverId', v_driver_id, 'stopIds', to_jsonb(v_stop_ids))
  );

  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type,
    aggregate_id, aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'round.approved', 1, 'round',
    v_round_id, 1, v_trace_id, v_event, v_occurred_at
  );

  v_result := jsonb_build_object(
    'status', 'committed',
    'aggregateVersion', 1,
    'state', jsonb_build_object(
      'roundId', v_round_id,
      'reference', v_reference,
      'roundState', 'approved',
      'driverId', v_driver_id,
      'stopIds', to_jsonb(v_stop_ids),
      'deliveryIds', to_jsonb(v_delivery_ids)
    ),
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
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'IDEMPOTENCY_CONFLICT', 'message', 'Round reference, aggregate or command identifier already exists')
    );
end;
$$;

revoke all on function public.plan_and_approve_round_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.plan_and_approve_round_command(jsonb, uuid) to service_role;

grant select on table
  public.driver_profiles,
  public.driver_tenant_relationships,
  public.deliveries,
  public.delivery_promises,
  public.delivery_stops,
  public.manifests,
  public.manifest_items,
  public.rounds,
  public.round_stops
to service_role;

comment on function public.plan_and_approve_round_command(jsonb, uuid) is
  'Slice 1 server-only manual Team Round assignment. Validates actor, tenant, driver, ordered Stops and state in one transaction.';
