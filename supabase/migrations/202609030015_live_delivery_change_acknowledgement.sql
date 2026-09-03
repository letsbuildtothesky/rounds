-- Slice 2 E04-E06: versioned own-team live delivery changes after verified
-- pickup. The physical manifest and custody assignment remain immutable.

create table public.live_delivery_changes (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  round_id uuid not null,
  stop_id uuid not null,
  delivery_id uuid not null,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  change_version bigint not null check (change_version > 0),
  before_state jsonb not null,
  changes jsonb not null,
  after_state jsonb not null,
  route_impact jsonb not null,
  route_plan_snapshot jsonb not null,
  driver_ack_status text not null default 'pending' check (driver_ack_status in ('pending', 'acknowledged')),
  applied_by_person_id uuid not null references public.persons(id) on delete restrict,
  applied_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  acknowledged_from_device_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (tenant_id, id),
  unique (tenant_id, stop_id, change_version),
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id) references public.delivery_stops(tenant_id, id) on delete restrict,
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict,
  check ((driver_ack_status = 'acknowledged') = (acknowledged_at is not null))
);

create unique index live_delivery_changes_one_pending_per_stop
  on public.live_delivery_changes (tenant_id, stop_id)
  where driver_ack_status = 'pending';
create index live_delivery_changes_driver_pending
  on public.live_delivery_changes (driver_id, applied_at desc)
  where driver_ack_status = 'pending';

alter table public.live_delivery_changes enable row level security;
revoke all on table public.live_delivery_changes from anon, authenticated;
grant select on table public.live_delivery_changes to service_role;

create or replace function public.apply_live_delivery_change_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'delivery.apply_live_change';
  v_tenant_id uuid;
  v_stop_id uuid;
  v_round_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_stop_version bigint;
  v_expected_round_version bigint;
  v_expected_destination_version bigint;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_actor_role public.tenant_role;
  v_round public.rounds%rowtype;
  v_stop public.delivery_stops%rowtype;
  v_delivery public.deliveries%rowtype;
  v_manifest public.manifests%rowtype;
  v_driver_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_changes jsonb;
  v_impact jsonb;
  v_route jsonb;
  v_change_id uuid := gen_random_uuid();
  v_change_version bigint;
  v_stop_order uuid[];
  v_current_stop_order uuid[];
  v_current_sequence integer;
  v_destination_changed boolean;
  v_window_changed boolean;
  v_round_version bigint;
  v_stop_version bigint;
  v_destination_version bigint;
  v_thread_id uuid;
  v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now();
  v_event jsonb;
  v_state jsonb;
  v_result jsonb;
begin
  if p_command is null or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
     or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_stop_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_stop_version := (p_command ->> 'expectedVersion')::bigint;
    v_payload := p_command -> 'payload';
    v_round_id := (v_payload ->> 'roundId')::uuid;
    v_expected_round_version := (v_payload ->> 'expectedRoundVersion')::bigint;
    v_expected_destination_version := (v_payload ->> 'expectedDestinationVersion')::bigint;
    select array_agg(value::uuid order by ordinality) into v_stop_order
      from jsonb_array_elements_text(v_payload -> 'stopOrderAfter') with ordinality requested(value,ordinality);
  exception when others then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Live change identifiers or versions are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey',''));
  v_before := v_payload -> 'before';
  v_after := v_payload -> 'after';
  v_changes := v_payload -> 'changes';
  v_impact := v_payload -> 'impact';
  v_route := v_payload -> 'routePlan';
  if v_stop_id <> (v_payload ->> 'stopId')::uuid or v_expected_stop_version < 1
     or v_expected_round_version < 1 or v_expected_destination_version < 1
     or v_idempotency_key = '' or length(v_idempotency_key) > 200
     or jsonb_typeof(v_before) <> 'object' or jsonb_typeof(v_after) <> 'object'
     or jsonb_typeof(v_changes) <> 'object' or v_changes = '{}'::jsonb
     or jsonb_typeof(v_payload -> 'stopOrderAfter') <> 'array' or cardinality(v_stop_order) < 1
     or jsonb_typeof(v_impact) <> 'object' or jsonb_typeof(v_route) <> 'object'
     or v_route ->> 'status' <> 'fits'
     or jsonb_array_length(coalesce(v_route -> 'blockingReasons','[]'::jsonb)) <> 0 then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Live change payload is invalid'));
  end if;

  v_payload_hash := encode(digest(v_payload::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key, 0));
  select * into v_existing from public.command_idempotency
   where tenant_id=v_tenant_id and command_type=v_command_type and idempotency_key=v_idempotency_key;
  if found then
    if v_existing.payload_hash <> v_payload_hash then
      return jsonb_build_object('status','rejected','error',jsonb_build_object('code','IDEMPOTENCY_CONFLICT','message','Idempotency key was already used with different payload'));
    end if;
    return v_existing.result || jsonb_build_object('deduplicated',true);
  end if;

  select membership.role into v_actor_role from public.tenant_memberships membership
   where membership.tenant_id=v_tenant_id and membership.person_id=p_actor_person_id
     and membership.status='active' and membership.role in ('tenant_owner','operations_admin','dispatcher')
   order by case membership.role when 'tenant_owner' then 1 when 'operations_admin' then 2 else 3 end limit 1;
  if v_actor_role is null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','NOT_AUTHORIZED','message','Actor cannot change this live delivery'));
  end if;

  select * into v_round from public.rounds
   where tenant_id=v_tenant_id and id=v_round_id and deleted_at is null for update;
  select stop.* into v_stop from public.delivery_stops stop
   join public.round_stops assignment on assignment.tenant_id=stop.tenant_id and assignment.stop_id=stop.id
   where stop.tenant_id=v_tenant_id and stop.id=v_stop_id and assignment.round_id=v_round_id for update of stop;
  if v_round.id is null or v_stop.id is null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','NOT_FOUND','message','Round or Stop was not found'));
  end if;
  if v_round.version <> v_expected_round_version or v_stop.version <> v_expected_stop_version
     or v_stop.destination_version <> v_expected_destination_version then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','STALE_VERSION','message','Round or delivery changed after preview; refresh before applying'));
  end if;
  if v_round.state <> 'active' or v_round.driver_id is null
     or v_stop.state in ('completed','cancelled') or v_stop.completed_at is not null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Stop is not an active post-pickup delivery'));
  end if;
  v_driver_id := v_round.driver_id;
  select * into v_delivery from public.deliveries
   where tenant_id=v_tenant_id and id=v_stop.delivery_id and deleted_at is null for update;
  select * into v_manifest from public.manifests
   where tenant_id=v_tenant_id and delivery_id=v_delivery.id order by version desc limit 1 for update;
  if v_manifest.state <> 'picked_up_locked' or not exists (
    select 1 from public.manifest_verifications verification
     where verification.tenant_id=v_tenant_id and verification.round_id=v_round_id
       and verification.stop_id=v_stop_id and verification.manifest_id=v_manifest.id and verification.stage='pickup'
  ) then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','CUSTODY_LOCKED','message','Verified pickup custody is required before this change'));
  end if;
  if exists (select 1 from public.delivery_exceptions exception where exception.tenant_id=v_tenant_id and exception.stop_id=v_stop_id and exception.status='open') then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Resolve the open Stop exception before changing the delivery'));
  end if;
  if exists (select 1 from public.live_delivery_changes change where change.tenant_id=v_tenant_id and change.stop_id=v_stop_id and change.driver_ack_status='pending') then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','The Driver must acknowledge the previous live change first'));
  end if;

  select array_agg(assignment.stop_id order by assignment.sequence),
         max(assignment.sequence) filter (where assignment.stop_id=v_stop_id)
    into v_current_stop_order,v_current_sequence
    from public.round_stops assignment
   where assignment.tenant_id=v_tenant_id and assignment.round_id=v_round_id;
  if cardinality(v_stop_order) <> cardinality(v_current_stop_order)
     or not (v_stop_order @> v_current_stop_order and v_current_stop_order @> v_stop_order)
     or coalesce((v_before ->> 'sequence')::integer,0) <> v_current_sequence
     or coalesce((v_after ->> 'sequence')::integer,0) <> array_position(v_stop_order,v_stop_id) then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','STALE_VERSION','message','Round order changed after preview; refresh before applying'));
  end if;

  v_destination_changed := (v_before ->> 'rawAddress') is distinct from (v_after ->> 'rawAddress')
    or (v_before ->> 'latitude') is distinct from (v_after ->> 'latitude')
    or (v_before ->> 'longitude') is distinct from (v_after ->> 'longitude')
    or coalesce(v_before ->> 'accessNote','') is distinct from coalesce(v_after ->> 'accessNote','');
  v_window_changed := (v_before ->> 'windowStart') is distinct from (v_after ->> 'windowStart')
    or (v_before ->> 'windowEnd') is distinct from (v_after ->> 'windowEnd');

  select coalesce(max(change_version),0)+1 into v_change_version
    from public.live_delivery_changes where tenant_id=v_tenant_id and stop_id=v_stop_id;

  update public.deliveries set
    destination_raw_address=coalesce(nullif(btrim(v_after ->> 'rawAddress'),''),destination_raw_address),
    destination_position=extensions.st_setsrid(extensions.st_makepoint((v_after ->> 'longitude')::double precision,(v_after ->> 'latitude')::double precision),4326)::extensions.geography,
    destination_provenance='operations_live_change',
    access_note=nullif(btrim(coalesce(v_after ->> 'accessNote','')),''),
    version=version+1, updated_at=v_occurred_at
   where id=v_delivery.id and v_destination_changed;
  update public.delivery_promises set
    window_start=(v_after ->> 'windowStart')::timestamptz,
    window_end=(v_after ->> 'windowEnd')::timestamptz,
    updated_at=v_occurred_at
   where tenant_id=v_tenant_id and delivery_id=v_delivery.id and v_window_changed;
  update public.round_stops set sequence=sequence+1000,updated_at=v_occurred_at
   where tenant_id=v_tenant_id and round_id=v_round_id;
  update public.round_stops assignment set sequence=requested.ordinality::integer,updated_at=v_occurred_at
    from unnest(v_stop_order) with ordinality requested(stop_id,ordinality)
   where assignment.tenant_id=v_tenant_id and assignment.round_id=v_round_id and assignment.stop_id=requested.stop_id;
  update public.delivery_stops set
    destination_version=destination_version+case when v_destination_changed then 1 else 0 end,
    version=version+1,
    updated_at=v_occurred_at
   where id=v_stop_id returning version,destination_version into v_stop_version,v_destination_version;
  update public.rounds set
    route_plan_snapshot=v_route,
    version=version+1,
    updated_at=v_occurred_at
   where id=v_round_id returning version into v_round_version;

  insert into public.live_delivery_changes (
    id,tenant_id,round_id,stop_id,delivery_id,driver_id,change_version,
    before_state,changes,after_state,route_impact,route_plan_snapshot,applied_by_person_id,applied_at
  ) values (
    v_change_id,v_tenant_id,v_round_id,v_stop_id,v_delivery.id,v_driver_id,v_change_version,
    v_before,v_changes,v_after,v_impact,v_route,p_actor_person_id,v_occurred_at
  );

  insert into public.operations_threads (tenant_id,round_id,stop_id,driver_id)
  values (v_tenant_id,v_round_id,v_stop_id,v_driver_id)
  on conflict (tenant_id,round_id,stop_id) do update set updated_at=excluded.updated_at
  returning id into v_thread_id;
  insert into public.operations_messages (id,tenant_id,thread_id,sender,body,sent_at,command_id)
  values (gen_random_uuid(),v_tenant_id,v_thread_id,'system','Operations changed the live delivery. Driver acknowledgement is required.',v_occurred_at,v_command_id);
  update public.operations_threads set version=version+1,updated_at=v_occurred_at where id=v_thread_id;

  v_state := jsonb_build_object('changeId',v_change_id,'changeVersion',v_change_version,'roundId',v_round_id,'roundVersion',v_round_version,'stopId',v_stop_id,'stopVersion',v_stop_version,'destinationVersion',v_destination_version,'driverAckStatus','pending');
  v_event := jsonb_build_object('event','delivery.live_changed','version',1,'eventId',v_event_id,'traceId',v_trace_id,'tenantId',v_tenant_id,'aggregateType','delivery_stop','aggregateId',v_stop_id,'aggregateVersion',v_stop_version,'occurredAt',v_occurred_at,'payload',v_state);
  insert into public.audit_events (tenant_id,actor_person_id,actor_role,action,aggregate_type,aggregate_id,aggregate_version,command_id,trace_id,semantic_change)
  values (v_tenant_id,p_actor_person_id,v_actor_role,'delivery.live_changed','delivery_stop',v_stop_id,v_stop_version,v_command_id,v_trace_id,jsonb_build_object('before',v_before,'after',v_after,'impact',v_impact,'custodyDriverId',v_driver_id,'manifestId',v_manifest.id,'manifestVersion',v_manifest.version));
  insert into public.domain_event_outbox (id,tenant_id,event_name,event_version,aggregate_type,aggregate_id,aggregate_version,trace_id,payload,occurred_at)
  values (v_event_id,v_tenant_id,'delivery.live_changed',1,'delivery_stop',v_stop_id,v_stop_version,v_trace_id,v_event,v_occurred_at);
  v_result := jsonb_build_object('status','committed','aggregateVersion',v_stop_version,'state',v_state,'events',jsonb_build_array(v_event));
  insert into public.command_idempotency (tenant_id,command_type,idempotency_key,command_id,aggregate_id,payload_hash,status,result,trace_id,actor_person_id)
  values (v_tenant_id,v_command_type,v_idempotency_key,v_command_id,v_stop_id,v_payload_hash,'committed',v_result,v_trace_id,p_actor_person_id);
  return v_result;
end;
$$;

create or replace function public.acknowledge_live_delivery_change_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'driver.acknowledge_live_change';
  v_tenant_id uuid; v_change_id uuid; v_command_id uuid; v_trace_id uuid;
  v_expected_version bigint; v_idempotency_key text; v_payload jsonb; v_payload_hash text;
  v_existing public.command_idempotency%rowtype; v_change public.live_delivery_changes%rowtype;
  v_driver_id uuid; v_thread_id uuid; v_occurred_at timestamptz := now(); v_event_id uuid := gen_random_uuid();
  v_state jsonb; v_event jsonb; v_result jsonb;
begin
  if p_command is null or coalesce((p_command ->> 'schemaVersion')::integer,0) <> 1 or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid; v_change_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid; v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint; v_payload := p_command -> 'payload';
  exception when others then return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Acknowledgement identifiers are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey',''));
  if v_change_id <> (v_payload ->> 'changeId')::uuid or v_expected_version <> (v_payload ->> 'expectedChangeVersion')::bigint or v_expected_version < 1 or v_idempotency_key='' then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Acknowledgement payload is invalid'));
  end if;
  v_payload_hash := encode(digest(v_payload::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key,0));
  select * into v_existing from public.command_idempotency where tenant_id=v_tenant_id and command_type=v_command_type and idempotency_key=v_idempotency_key;
  if found then
    if v_existing.payload_hash <> v_payload_hash then return jsonb_build_object('status','rejected','error',jsonb_build_object('code','IDEMPOTENCY_CONFLICT','message','Idempotency key was already used with different payload')); end if;
    return v_existing.result || jsonb_build_object('deduplicated',true);
  end if;
  select driver.id into v_driver_id from public.driver_profiles driver
   join public.tenant_memberships membership on membership.person_id=driver.person_id and membership.tenant_id=v_tenant_id
   join public.driver_tenant_relationships relationship on relationship.driver_id=driver.id and relationship.tenant_id=v_tenant_id
   where driver.person_id=p_actor_person_id and driver.active=true and driver.deleted_at is null
     and membership.status='active' and membership.role='team_driver'
     and relationship.relationship_kind='team' and relationship.status='active' and relationship.deleted_at is null limit 1;
  if v_driver_id is null then return jsonb_build_object('status','rejected','error',jsonb_build_object('code','NOT_AUTHORIZED','message','Actor is not an active Team driver')); end if;
  select * into v_change from public.live_delivery_changes where tenant_id=v_tenant_id and id=v_change_id for update;
  if v_change.id is null or v_change.driver_id <> v_driver_id then return jsonb_build_object('status','rejected','error',jsonb_build_object('code','NOT_AUTHORIZED','message','Live change is not assigned to this Driver')); end if;
  if v_change.version <> v_expected_version or v_change.driver_ack_status <> 'pending' then return jsonb_build_object('status','rejected','error',jsonb_build_object('code','STALE_VERSION','message','Live change is stale or already acknowledged; refresh the Round')); end if;
  update public.live_delivery_changes set driver_ack_status='acknowledged',acknowledged_at=v_occurred_at,acknowledged_from_device_at=nullif(p_command ->> 'occurredFromDeviceAt','')::timestamptz,version=version+1 where id=v_change_id;
  select id into v_thread_id from public.operations_threads where tenant_id=v_tenant_id and round_id=v_change.round_id and stop_id=v_change.stop_id;
  if v_thread_id is not null then
    insert into public.operations_messages (id,tenant_id,thread_id,sender,body,sent_at,command_id) values (gen_random_uuid(),v_tenant_id,v_thread_id,'system','Driver acknowledged the live delivery update.',v_occurred_at,v_command_id);
    update public.operations_threads set version=version+1,updated_at=v_occurred_at where id=v_thread_id;
  end if;
  v_state := jsonb_build_object('changeId',v_change_id,'changeVersion',v_change.change_version,'roundId',v_change.round_id,'stopId',v_change.stop_id,'driverAckStatus','acknowledged','acknowledgedAt',v_occurred_at);
  v_event := jsonb_build_object('event','delivery.live_change_acknowledged','version',1,'eventId',v_event_id,'traceId',v_trace_id,'tenantId',v_tenant_id,'aggregateType','live_delivery_change','aggregateId',v_change_id,'aggregateVersion',v_change.version+1,'occurredAt',v_occurred_at,'payload',v_state);
  insert into public.audit_events (tenant_id,actor_person_id,actor_role,action,aggregate_type,aggregate_id,aggregate_version,command_id,trace_id,semantic_change)
  values (v_tenant_id,p_actor_person_id,'team_driver','delivery.live_change_acknowledged','live_delivery_change',v_change_id,v_change.version+1,v_command_id,v_trace_id,jsonb_build_object('stopId',v_change.stop_id,'roundId',v_change.round_id));
  insert into public.domain_event_outbox (id,tenant_id,event_name,event_version,aggregate_type,aggregate_id,aggregate_version,trace_id,payload,occurred_at)
  values (v_event_id,v_tenant_id,'delivery.live_change_acknowledged',1,'live_delivery_change',v_change_id,v_change.version+1,v_trace_id,v_event,v_occurred_at);
  v_result := jsonb_build_object('status','committed','aggregateVersion',v_change.version+1,'state',v_state,'events',jsonb_build_array(v_event));
  insert into public.command_idempotency (tenant_id,command_type,idempotency_key,command_id,aggregate_id,payload_hash,status,result,trace_id,actor_person_id)
  values (v_tenant_id,v_command_type,v_idempotency_key,v_command_id,v_change_id,v_payload_hash,'committed',v_result,v_trace_id,p_actor_person_id);
  return v_result;
end;
$$;

revoke all on function public.apply_live_delivery_change_command(jsonb,uuid) from public,anon,authenticated;
revoke all on function public.acknowledge_live_delivery_change_command(jsonb,uuid) from public,anon,authenticated;
grant execute on function public.apply_live_delivery_change_command(jsonb,uuid) to service_role;
grant execute on function public.acknowledge_live_delivery_change_command(jsonb,uuid) to service_role;

comment on table public.live_delivery_changes is 'Versioned post-pickup operational delivery changes awaiting explicit assigned-Driver acknowledgement.';
