-- Canonical Operations "Edit delivery" command before physical pickup.
-- The command is versioned, idempotent and atomic. Assigned edits must carry a
-- fresh fitting route/capacity snapshot; picked-up manifests are immutable.

create or replace function public.apply_pre_pickup_delivery_edit_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  v_command_type constant text := 'delivery.edit_before_pickup';
  v_tenant_id uuid; v_delivery_id uuid; v_stop_id uuid; v_manifest_id uuid; v_round_id uuid;
  v_command_id uuid; v_trace_id uuid; v_idempotency_key text; v_payload jsonb; v_payload_hash text;
  v_expected_delivery_version bigint; v_expected_stop_version bigint; v_expected_destination_version bigint;
  v_expected_manifest_version bigint; v_expected_round_version bigint;
  v_existing public.command_idempotency%rowtype; v_actor_role public.tenant_role;
  v_delivery public.deliveries%rowtype; v_stop public.delivery_stops%rowtype;
  v_manifest public.manifests%rowtype; v_round public.rounds%rowtype;
  v_assignment_round_id uuid; v_before jsonb; v_after jsonb; v_changed_fields jsonb; v_impact jsonb; v_route jsonb;
  v_current_stop_order uuid[]; v_route_stop_order uuid[];
  v_destination_changed boolean; v_manifest_changed boolean;
  v_delivery_version bigint; v_stop_version bigint; v_destination_version bigint; v_manifest_version bigint; v_round_version bigint;
  v_event_id uuid := gen_random_uuid(); v_occurred_at timestamptz := now(); v_event jsonb; v_state jsonb; v_result jsonb;
begin
  if p_command is null or coalesce((p_command ->> 'schemaVersion')::integer,0) <> 1 or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_delivery_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_delivery_version := (p_command ->> 'expectedVersion')::bigint;
    v_payload := p_command -> 'payload';
    v_stop_id := (v_payload ->> 'stopId')::uuid;
    v_manifest_id := (v_payload ->> 'manifestId')::uuid;
    v_round_id := nullif(v_payload ->> 'roundId','')::uuid;
    v_expected_stop_version := (v_payload ->> 'expectedStopVersion')::bigint;
    v_expected_destination_version := (v_payload ->> 'expectedDestinationVersion')::bigint;
    v_expected_manifest_version := (v_payload ->> 'expectedManifestVersion')::bigint;
    v_expected_round_version := nullif(v_payload ->> 'expectedRoundVersion','')::bigint;
  exception when others then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Delivery edit identifiers or versions are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey',''));
  v_before := v_payload -> 'before'; v_after := v_payload -> 'after';
  v_changed_fields := v_payload -> 'changedFields'; v_impact := v_payload -> 'impact'; v_route := v_payload -> 'routePlan';
  if v_delivery_id <> (v_payload ->> 'deliveryId')::uuid
     or v_expected_delivery_version < 1 or v_expected_delivery_version <> (v_payload ->> 'expectedDeliveryVersion')::bigint
     or v_expected_stop_version < 1 or v_expected_destination_version < 1 or v_expected_manifest_version < 1
     or v_idempotency_key='' or length(v_idempotency_key)>200
     or jsonb_typeof(v_before)<>'object' or jsonb_typeof(v_after)<>'object'
     or jsonb_typeof(v_changed_fields)<>'array' or jsonb_array_length(v_changed_fields)<1
     or jsonb_typeof(v_impact)<>'object' or jsonb_typeof(v_after -> 'manifestItems')<>'array'
     or jsonb_array_length(v_after -> 'manifestItems')<1 then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Delivery edit payload is invalid'));
  end if;

  v_payload_hash := encode(digest(v_payload::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key,0));
  select * into v_existing from public.command_idempotency where tenant_id=v_tenant_id and command_type=v_command_type and idempotency_key=v_idempotency_key;
  if found then
    if v_existing.payload_hash <> v_payload_hash then
      return jsonb_build_object('status','rejected','error',jsonb_build_object('code','IDEMPOTENCY_CONFLICT','message','Idempotency key was already used with different payload'));
    end if;
    return v_existing.result || jsonb_build_object('deduplicated',true);
  end if;

  select membership.role into v_actor_role from public.tenant_memberships membership
   where membership.tenant_id=v_tenant_id and membership.person_id=p_actor_person_id and membership.status='active'
     and membership.role in ('tenant_owner','operations_admin','dispatcher')
   order by case membership.role when 'tenant_owner' then 1 when 'operations_admin' then 2 else 3 end limit 1;
  if v_actor_role is null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','NOT_AUTHORIZED','message','Actor cannot edit this delivery'));
  end if;

  select * into v_delivery from public.deliveries where tenant_id=v_tenant_id and id=v_delivery_id and deleted_at is null for update;
  select * into v_stop from public.delivery_stops where tenant_id=v_tenant_id and id=v_stop_id and delivery_id=v_delivery_id for update;
  select * into v_manifest from public.manifests where tenant_id=v_tenant_id and id=v_manifest_id and delivery_id=v_delivery_id for update;
  if v_delivery.id is null or v_stop.id is null or v_manifest.id is null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Delivery, Stop or manifest no longer matches this edit'));
  end if;
  if v_delivery.version<>v_expected_delivery_version or v_stop.version<>v_expected_stop_version
     or v_stop.destination_version<>v_expected_destination_version or v_manifest.version<>v_expected_manifest_version then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','STALE_VERSION','message','Delivery changed after preview; refresh before applying'));
  end if;
  if v_manifest.state<>'draft' or v_manifest.locked_at is not null
     or v_delivery.state not in ('draft','unplanned','planned','assigned','pickup_pending')
     or v_stop.state not in ('pending','ready','assigned') or v_stop.arrived_at is not null or v_stop.completed_at is not null
     or exists(select 1 from public.manifest_verifications verification where verification.tenant_id=v_tenant_id and verification.stop_id=v_stop_id and verification.stage='pickup') then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','CUSTODY_LOCKED','message','Delivery editing is locked after pickup custody begins'));
  end if;
  if exists(select 1 from public.delivery_exceptions exception where exception.tenant_id=v_tenant_id and exception.stop_id=v_stop_id and exception.status='open') then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Resolve the open Stop exception before editing the delivery'));
  end if;

  select assignment.round_id into v_assignment_round_id from public.round_stops assignment
   where assignment.tenant_id=v_tenant_id and assignment.stop_id=v_stop_id limit 1;
  if v_assignment_round_id is distinct from v_round_id then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','STALE_VERSION','message','Delivery assignment changed after preview'));
  end if;
  if v_round_id is not null then
    select * into v_round from public.rounds where tenant_id=v_tenant_id and id=v_round_id and deleted_at is null for update;
    if v_round.id is null or v_round.version<>v_expected_round_version then
      return jsonb_build_object('status','rejected','error',jsonb_build_object('code','STALE_VERSION','message','Round changed after preview; refresh before applying'));
    end if;
    if v_round.state not in ('proposed','approved','loading') or v_round.driver_id is null then
      return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Assigned delivery editing is only available before the Round becomes active'));
    end if;
    if jsonb_typeof(v_route)<>'object' or v_route ->> 'status'<>'fits'
       or v_route -> 'capacity' ->> 'status'<>'fits'
       or jsonb_array_length(coalesce(v_route -> 'blockingReasons','[]'::jsonb))<>0
       or v_route -> 'provider' ->> 'name'<>'mapbox' or v_route -> 'provider' ->> 'profile'<>'driving-traffic' then
      return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Assigned delivery edit requires a fitting current Mapbox route and capacity preview'));
    end if;
    select array_agg(assignment.stop_id order by assignment.sequence) into v_current_stop_order
      from public.round_stops assignment where assignment.tenant_id=v_tenant_id and assignment.round_id=v_round_id;
    select array_agg(value::uuid order by ordinality) into v_route_stop_order
      from jsonb_array_elements_text(v_route -> 'stopIds') with ordinality requested(value,ordinality);
    if v_current_stop_order is distinct from v_route_stop_order then
      return jsonb_build_object('status','rejected','error',jsonb_build_object('code','STALE_VERSION','message','Round Stop order changed after preview'));
    end if;
  elsif v_route is not null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Unplanned delivery edit cannot carry a route plan'));
  end if;

  v_destination_changed := v_changed_fields ?| array['rawAddress','latitude','longitude','accessNote'];
  v_manifest_changed := v_changed_fields ? 'manifestItems';

  update public.deliveries set
    recipient_name=btrim(v_after ->> 'recipientName'),
    recipient_phone=btrim(v_after ->> 'recipientPhone'),
    buyer_name=case when buyer_same_as_recipient then btrim(v_after ->> 'recipientName') else buyer_name end,
    buyer_phone=case when buyer_same_as_recipient then btrim(v_after ->> 'recipientPhone') else buyer_phone end,
    destination_raw_address=btrim(v_after ->> 'rawAddress'),
    destination_position=extensions.st_setsrid(extensions.st_makepoint((v_after ->> 'longitude')::double precision,(v_after ->> 'latitude')::double precision),4326)::extensions.geography,
    destination_provenance=case when v_destination_changed then 'operations_pre_pickup_edit' else destination_provenance end,
    access_note=nullif(btrim(coalesce(v_after ->> 'accessNote','')),''),
    delivery_note=nullif(btrim(coalesce(v_after ->> 'deliveryNote','')),''),
    version=version+1,updated_at=v_occurred_at
   where id=v_delivery_id returning version into v_delivery_version;
  update public.delivery_promises set window_start=(v_after ->> 'windowStart')::timestamptz,window_end=(v_after ->> 'windowEnd')::timestamptz,updated_at=v_occurred_at
   where tenant_id=v_tenant_id and delivery_id=v_delivery_id;
  if v_manifest_changed then
    delete from public.manifest_items where tenant_id=v_tenant_id and manifest_id=v_manifest_id;
    insert into public.manifest_items(id,tenant_id,manifest_id,line_number,description,quantity,cargo_class,handling_note,created_at,updated_at)
    select gen_random_uuid(),v_tenant_id,v_manifest_id,(line.item ->> 'lineNumber')::integer,btrim(line.item ->> 'description'),(line.item ->> 'quantity')::integer,
           nullif(btrim(coalesce(line.item ->> 'cargoClass','')),''),nullif(btrim(coalesce(line.item ->> 'handlingNote','')),''),v_occurred_at,v_occurred_at
      from jsonb_array_elements(v_after -> 'manifestItems') with ordinality line(item,ordinality)
     order by line.ordinality;
    update public.manifests set version=version+1,updated_at=v_occurred_at where id=v_manifest_id returning version into v_manifest_version;
  else
    v_manifest_version := v_manifest.version;
  end if;
  update public.delivery_stops set destination_version=destination_version+case when v_destination_changed then 1 else 0 end,
    version=version+1,updated_at=v_occurred_at where id=v_stop_id returning version,destination_version into v_stop_version,v_destination_version;
  if v_round_id is not null then
    update public.rounds set route_plan_snapshot=v_route,version=version+1,updated_at=v_occurred_at where id=v_round_id returning version into v_round_version;
  end if;

  v_state := jsonb_build_object('deliveryId',v_delivery_id,'deliveryVersion',v_delivery_version,'stopId',v_stop_id,'stopVersion',v_stop_version,
    'destinationVersion',v_destination_version,'manifestId',v_manifest_id,'manifestVersion',v_manifest_version)
    || case when v_round_id is not null then jsonb_build_object('roundId',v_round_id,'roundVersion',v_round_version) else '{}'::jsonb end;
  v_event := jsonb_build_object('event','delivery.edited_before_pickup','version',1,'eventId',v_event_id,'traceId',v_trace_id,'tenantId',v_tenant_id,
    'aggregateType','delivery','aggregateId',v_delivery_id,'aggregateVersion',v_delivery_version,'occurredAt',v_occurred_at,'payload',v_state);
  insert into public.audit_events(tenant_id,actor_person_id,actor_role,action,aggregate_type,aggregate_id,aggregate_version,command_id,trace_id,semantic_change)
  values(v_tenant_id,p_actor_person_id,v_actor_role,'delivery.edited_before_pickup','delivery',v_delivery_id,v_delivery_version,v_command_id,v_trace_id,
    jsonb_build_object('before',v_before,'after',v_after,'changedFields',v_changed_fields,'impact',v_impact,'roundId',v_round_id));
  insert into public.domain_event_outbox(id,tenant_id,event_name,event_version,aggregate_type,aggregate_id,aggregate_version,trace_id,payload,occurred_at)
  values(v_event_id,v_tenant_id,'delivery.edited_before_pickup',1,'delivery',v_delivery_id,v_delivery_version,v_trace_id,v_event,v_occurred_at);
  v_result := jsonb_build_object('status','committed','aggregateVersion',v_delivery_version,'state',v_state,'events',jsonb_build_array(v_event));
  insert into public.command_idempotency(tenant_id,command_type,idempotency_key,command_id,aggregate_id,payload_hash,status,result,trace_id,actor_person_id)
  values(v_tenant_id,v_command_type,v_idempotency_key,v_command_id,v_delivery_id,v_payload_hash,'committed',v_result,v_trace_id,p_actor_person_id);
  return v_result;
exception when check_violation or not_null_violation or invalid_text_representation then
  return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Delivery edit values are invalid'));
end;
$$;

revoke all on function public.apply_pre_pickup_delivery_edit_command(jsonb,uuid) from public,anon,authenticated;
grant execute on function public.apply_pre_pickup_delivery_edit_command(jsonb,uuid) to service_role;
comment on function public.apply_pre_pickup_delivery_edit_command(jsonb,uuid) is
  'Atomic pre-pickup delivery edit with custody lock, optimistic versions, assigned-route/capacity proof, audit event and outbox event.';
