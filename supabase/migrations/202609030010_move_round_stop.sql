-- Slice 2 B2: atomically move one pre-custody Stop between two approved own-team Rounds.
-- The API recalculates both resulting routes; this command independently verifies
-- versions, membership, state, exact orders, route fit, and custody protection.

create or replace function public.move_round_stop_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'round.move_stop';
  v_tenant_id uuid;
  v_source_id uuid;
  v_target_id uuid;
  v_stop_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_source_expected_version bigint;
  v_target_expected_version bigint;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_actor_role public.tenant_role;
  v_source public.rounds%rowtype;
  v_target public.rounds%rowtype;
  v_source_current uuid[];
  v_target_current uuid[];
  v_source_after uuid[];
  v_target_after uuid[];
  v_source_route jsonb;
  v_target_route jsonb;
  v_source_version bigint;
  v_target_version bigint;
  v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now();
  v_event jsonb;
  v_result jsonb;
begin
  if p_command is null
     or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
     or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_source_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_source_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_payload := p_command -> 'payload';
    v_target_id := (v_payload ->> 'targetRoundId')::uuid;
    v_stop_id := (v_payload ->> 'stopId')::uuid;
    v_target_expected_version := (v_payload ->> 'targetExpectedVersion')::bigint;
    select coalesce(array_agg(value::uuid order by ordinality), '{}'::uuid[])
      into v_source_after from jsonb_array_elements_text(v_payload -> 'sourceStopIds') with ordinality;
    select coalesce(array_agg(value::uuid order by ordinality), '{}'::uuid[])
      into v_target_after from jsonb_array_elements_text(v_payload -> 'targetStopIds') with ordinality;
  exception when others then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Round move identifiers or Stop orders are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey',''));
  if v_source_id = v_target_id or v_source_id <> (v_payload ->> 'sourceRoundId')::uuid
     or v_idempotency_key = '' or length(v_idempotency_key) > 200
     or v_source_expected_version < 1 or v_target_expected_version < 1
     or cardinality(v_target_after) < 1
     or cardinality(v_target_after) > 20
     or v_stop_id = any(v_source_after) or not (v_stop_id = any(v_target_after))
     or (select count(distinct value) from unnest(v_source_after || v_target_after) value)
        <> cardinality(v_source_after) + cardinality(v_target_after) then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Move requires two different Rounds and exact unique resulting Stop orders'));
  end if;

  v_payload_hash := encode(digest(v_payload::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key, 0));
  select * into v_existing from public.command_idempotency
   where tenant_id=v_tenant_id and command_type=v_command_type and idempotency_key=v_idempotency_key;
  if found then
    if v_existing.payload_hash <> v_payload_hash then
      return jsonb_build_object('status','rejected','error',jsonb_build_object('code','IDEMPOTENCY_CONFLICT','message','Idempotency key was already used with different payload'));
    end if;
    return v_existing.result;
  end if;

  select membership.role into v_actor_role from public.tenant_memberships membership
   where membership.tenant_id=v_tenant_id and membership.person_id=p_actor_person_id
     and membership.status='active' and membership.role in ('tenant_owner','operations_admin','dispatcher')
   order by case membership.role when 'tenant_owner' then 1 when 'operations_admin' then 2 else 3 end limit 1;
  if v_actor_role is null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','NOT_AUTHORIZED','message','Actor cannot edit Team Rounds for this tenant'));
  end if;

  perform id from public.rounds where tenant_id=v_tenant_id and id in (v_source_id,v_target_id) order by id for update;
  select * into v_source from public.rounds where tenant_id=v_tenant_id and id=v_source_id and deleted_at is null;
  select * into v_target from public.rounds where tenant_id=v_tenant_id and id=v_target_id and deleted_at is null;
  if v_source.id is null or v_target.id is null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','NOT_FOUND','message','Source or target Round was not found'));
  end if;
  if v_source.version <> v_source_expected_version or v_target.version <> v_target_expected_version then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VERSION_CONFLICT','message','A Round changed after preview; refresh before moving the Stop'));
  end if;
  if v_source.state <> 'approved' or v_target.state <> 'approved' or v_source.service_date <> v_target.service_date then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Stops may move only between approved Rounds on the same service date'));
  end if;

  select coalesce(array_agg(stop_id order by sequence), '{}'::uuid[]) into v_source_current
    from public.round_stops where tenant_id=v_tenant_id and round_id=v_source_id;
  select coalesce(array_agg(stop_id order by sequence), '{}'::uuid[]) into v_target_current
    from public.round_stops where tenant_id=v_tenant_id and round_id=v_target_id;
  if not (v_stop_id = any(v_source_current))
     or v_source_after <> array_remove(v_source_current,v_stop_id)
     or v_target_after <> array_prepend(v_stop_id,v_target_current) then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VERSION_CONFLICT','message','Round Stop order changed after preview'));
  end if;
  if exists (
    select 1 from public.delivery_stops stop
    where stop.tenant_id=v_tenant_id and stop.id=v_stop_id
      and (stop.state <> 'assigned' or stop.arrived_at is not null or stop.completed_at is not null)
  ) or exists (
    select 1 from public.manifest_verifications verification
    where verification.tenant_id=v_tenant_id and verification.stop_id=v_stop_id and verification.stage='pickup'
  ) or exists (
    select 1 from public.delivery_exceptions exception
    where exception.tenant_id=v_tenant_id and exception.stop_id=v_stop_id and exception.status='open'
  ) then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Current, custody, arrived, completed, or exception Stops cannot be moved'));
  end if;
  if (select count(distinct delivery.pickup_location_id)
        from public.round_stops assignment
        join public.delivery_stops stop on stop.id=assignment.stop_id and stop.tenant_id=assignment.tenant_id
        join public.deliveries delivery on delivery.id=stop.delivery_id and delivery.tenant_id=stop.tenant_id
       where assignment.tenant_id=v_tenant_id and assignment.round_id in (v_source_id,v_target_id)) <> 1 then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Source and target Rounds must use the same pickup location'));
  end if;

  v_source_route := v_payload -> 'sourceRoutePlan';
  v_target_route := v_payload -> 'targetRoutePlan';
  if (cardinality(v_source_after) = 0 and v_source_route is not null)
     or (cardinality(v_source_after) > 0 and (
       jsonb_typeof(v_source_route) <> 'object' or v_source_route ->> 'status' <> 'fits'
       or v_source_route ->> 'driverId' is distinct from v_source.driver_id::text
       or v_source_route ->> 'serviceDate' is distinct from v_source.service_date::text
       or v_source_route -> 'stopIds' is distinct from to_jsonb(v_source_after)
       or jsonb_array_length(coalesce(v_source_route -> 'blockingReasons','[]'::jsonb)) <> 0))
     or jsonb_typeof(v_target_route) <> 'object' or v_target_route ->> 'status' <> 'fits'
     or v_target_route ->> 'driverId' is distinct from v_target.driver_id::text
     or v_target_route ->> 'serviceDate' is distinct from v_target.service_date::text
     or v_target_route -> 'stopIds' is distinct from to_jsonb(v_target_after)
     or jsonb_array_length(coalesce(v_target_route -> 'blockingReasons','[]'::jsonb)) <> 0 then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Matching server-calculated route fits are required for both resulting Rounds'));
  end if;

  delete from public.round_stops where tenant_id=v_tenant_id and round_id=v_source_id and stop_id=v_stop_id;
  update public.round_stops set sequence=sequence+1000,updated_at=v_occurred_at
   where tenant_id=v_tenant_id and round_id in (v_source_id,v_target_id);
  update public.round_stops assignment set sequence=requested.ordinality::integer,updated_at=v_occurred_at
    from unnest(v_source_after) with ordinality requested(stop_id,ordinality)
   where assignment.tenant_id=v_tenant_id and assignment.round_id=v_source_id and assignment.stop_id=requested.stop_id;
  insert into public.round_stops(tenant_id,round_id,stop_id,sequence,updated_at)
    values(v_tenant_id,v_target_id,v_stop_id,1,v_occurred_at);
  update public.round_stops assignment set sequence=requested.ordinality::integer,updated_at=v_occurred_at
    from unnest(v_target_after) with ordinality requested(stop_id,ordinality)
   where assignment.tenant_id=v_tenant_id and assignment.round_id=v_target_id and assignment.stop_id=requested.stop_id;

  v_source_version := v_source.version+1;
  v_target_version := v_target.version+1;
  update public.rounds set state=case when cardinality(v_source_after)=0 then 'cancelled'::public.round_state else state end,
    route_plan_snapshot=case when cardinality(v_source_after)=0 then null else v_source_route end,
    version=v_source_version,updated_at=v_occurred_at where id=v_source_id and tenant_id=v_tenant_id;
  update public.rounds set route_plan_snapshot=v_target_route,version=v_target_version,updated_at=v_occurred_at
   where id=v_target_id and tenant_id=v_tenant_id;

  v_event := jsonb_build_object('event','round.stop_moved','version',1,'eventId',v_event_id,'traceId',v_trace_id,
    'tenantId',v_tenant_id,'aggregateType','round','aggregateId',v_source_id,'aggregateVersion',v_source_version,
    'occurredAt',v_occurred_at,'payload',jsonb_build_object('stopId',v_stop_id,'sourceRoundId',v_source_id,
      'targetRoundId',v_target_id,'sourceStopIds',to_jsonb(v_source_after),'targetStopIds',to_jsonb(v_target_after)));
  insert into public.audit_events(tenant_id,actor_person_id,actor_role,action,aggregate_type,aggregate_id,aggregate_version,command_id,trace_id,semantic_change)
    values
      (v_tenant_id,p_actor_person_id,v_actor_role,'round.stop_moved_out','round',v_source_id,v_source_version,v_command_id,v_trace_id,
       jsonb_build_object('stopId',v_stop_id,'targetRoundId',v_target_id,'stopIds',to_jsonb(v_source_after),'state',case when cardinality(v_source_after)=0 then 'cancelled' else 'approved' end)),
      (v_tenant_id,p_actor_person_id,v_actor_role,'round.stop_moved_in','round',v_target_id,v_target_version,v_command_id,v_trace_id,
       jsonb_build_object('stopId',v_stop_id,'sourceRoundId',v_source_id,'stopIds',to_jsonb(v_target_after)));
  insert into public.domain_event_outbox(id,tenant_id,event_name,event_version,aggregate_type,aggregate_id,aggregate_version,trace_id,payload,occurred_at)
    values(v_event_id,v_tenant_id,'round.stop_moved',1,'round',v_source_id,v_source_version,v_trace_id,v_event,v_occurred_at);
  v_result := jsonb_build_object('status','committed','aggregateVersion',v_source_version,
    'state',jsonb_build_object('stopId',v_stop_id,'sourceRoundId',v_source_id,'targetRoundId',v_target_id,
      'sourceStopIds',to_jsonb(v_source_after),'targetStopIds',to_jsonb(v_target_after),
      'sourceRoundVersion',v_source_version,'targetRoundVersion',v_target_version,'sourceRoundRemoved',cardinality(v_source_after)=0),
    'events',jsonb_build_array(v_event));
  insert into public.command_idempotency(tenant_id,command_type,idempotency_key,command_id,aggregate_id,payload_hash,status,result,trace_id,actor_person_id)
    values(v_tenant_id,v_command_type,v_idempotency_key,v_command_id,v_source_id,v_payload_hash,'committed',v_result,v_trace_id,p_actor_person_id);
  return v_result;
exception when unique_violation then
  return jsonb_build_object('status','rejected','error',jsonb_build_object('code','IDEMPOTENCY_CONFLICT','message','Round move command identifier conflicts with an existing command'));
end;
$$;

revoke all on function public.move_round_stop_command(jsonb,uuid) from public,anon,authenticated;
grant execute on function public.move_round_stop_command(jsonb,uuid) to service_role;
comment on function public.move_round_stop_command(jsonb,uuid) is
  'Moves one pre-custody Stop between two approved own-team Rounds with dual version locks, exact route snapshots, audit, outbox, and idempotency.';
