-- G03 supports the three canonical delivery package problems. Damaged and
-- wrong packages require verified photo evidence; missing packages do not.

alter table public.delivery_exceptions
  drop constraint delivery_exceptions_delivery_evidence_check;
alter table public.delivery_exceptions
  add constraint delivery_exceptions_delivery_evidence_check
  check (
    stage <> 'delivery'
    or category = 'missing_item'
    or media_asset_id is not null
  );

create or replace function public.report_delivery_problem_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'stop.report_delivery_problem';
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
  v_asset public.media_assets%rowtype;
  v_category public.pickup_problem_category;
  v_driver_id uuid;
  v_actor_role public.tenant_role;
  v_note text;
  v_exception_id uuid := gen_random_uuid();
  v_event_id uuid := gen_random_uuid();
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
    v_category := (p_command #>> '{payload,category}')::public.pickup_problem_category;
    if v_category not in ('damaged_item', 'missing_item', 'wrong_item') then
      raise exception 'unsupported category';
    end if;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Delivery problem identifiers, version or category are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  v_note := nullif(btrim(coalesce(v_payload ->> 'note', '')), '');
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
     or v_payload is null or length(coalesce(v_note, '')) > 500 then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Delivery problem payload is invalid'));
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
  select * into v_stop from public.delivery_stops
   where id = v_stop_id and tenant_id = v_tenant_id and state = 'arrived' for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Stop is not awaiting a delivery decision'));
  end if;
  if v_stop.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Stop changed; refresh before reporting the problem'));
  end if;
  select round_record.* into v_round from public.rounds round_record
    join public.round_stops assigned on assigned.round_id = round_record.id and assigned.tenant_id = round_record.tenant_id
   where assigned.stop_id = v_stop_id and round_record.driver_id = v_driver_id
     and round_record.state = 'active' and round_record.deleted_at is null for update of round_record;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Stop is not assigned to this active driver Round'));
  end if;
  select * into v_delivery from public.deliveries
   where id = v_stop.delivery_id and tenant_id = v_tenant_id and state = 'arrived' and deleted_at is null for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Delivery is not awaiting handoff'));
  end if;
  select * into v_manifest from public.manifests
   where id = (v_payload ->> 'manifestId')::uuid and tenant_id = v_tenant_id
     and delivery_id = v_delivery.id and version = (v_payload ->> 'manifestVersion')::bigint
     and state = 'picked_up_locked' for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'CUSTODY_LOCKED', 'message', 'Problem manifest does not match the locked pickup manifest'));
  end if;
  if v_category <> 'missing_item' then
    begin
      select * into strict v_asset from public.media_assets
       where id = (v_payload ->> 'mediaAssetId')::uuid and tenant_id = v_tenant_id
         and stop_id = v_stop_id and driver_id = v_driver_id and intent = 'exception_photo'
         and state = 'uploaded_uncommitted' for update;
    exception when others then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'EVIDENCE_REQUIRED', 'message', 'A verified package photo is required'));
    end;
  end if;
  insert into public.delivery_exceptions (
    id, tenant_id, delivery_id, stop_id, round_id, driver_id, manifest_id,
    manifest_version, stage, category, note, media_asset_id, actor_person_id,
    occurred_from_device_at, reported_at, command_id
  ) values (
    v_exception_id, v_tenant_id, v_delivery.id, v_stop_id, v_round.id, v_driver_id,
    v_manifest.id, v_manifest.version, 'delivery', v_category, v_note,
    case when v_category = 'missing_item' then null else v_asset.id end,
    p_actor_person_id, v_occurred_from_device_at, v_occurred_at, v_command_id
  );
  if v_category <> 'missing_item' then
    update public.media_assets set state = 'committed', committed_at = v_occurred_at where id = v_asset.id;
  end if;
  update public.deliveries set state = 'exception', version = version + 1, updated_at = v_occurred_at
   where id = v_delivery.id;
  update public.delivery_stops set state = 'exception', version = version + 1, updated_at = v_occurred_at
   where id = v_stop_id returning version into v_stop_version;
  v_event_payload := jsonb_strip_nulls(jsonb_build_object(
    'exceptionId', v_exception_id,
    'mediaAssetId', case when v_category = 'missing_item' then null else v_asset.id end,
    'stopId', v_stop_id, 'deliveryId', v_delivery.id, 'roundId', v_round.id,
    'category', v_category));
  v_event := jsonb_build_object(
    'event', 'stop.delivery_problem_reported', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'stop',
    'aggregateId', v_stop_id, 'aggregateVersion', v_stop_version, 'occurredAt', v_occurred_at,
    'payload', v_event_payload);
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'stop.delivery_problem_reported', 'stop', v_stop_id,
    v_stop_version, v_command_id, v_trace_id,
    jsonb_strip_nulls(jsonb_build_object(
      'state', jsonb_build_object('from', v_stop.state, 'to', 'exception'),
      'exceptionId', v_exception_id, 'category', v_category,
      'mediaAssetId', case when v_category = 'missing_item' then null else v_asset.id end,
      'custody', 'driver_retains_package')));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'stop.delivery_problem_reported', 1, 'stop', v_stop_id,
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

revoke all on function public.report_delivery_problem_command(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.report_delivery_problem_command(jsonb, uuid)
  to service_role;

comment on function public.report_delivery_problem_command(jsonb, uuid) is
  'Server-only Team-driver command for canonical G03 damage, missing and wrong-package custody holds.';
