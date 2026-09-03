-- Slice 2: restore the recurring schedule by explicitly clearing a date override.

create or replace function public.clear_driver_shift_exception_command(p_command jsonb, p_actor_person_id uuid)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_type constant text := 'operations.clear_driver_shift_exception';
  v_tenant_id uuid; v_driver_id uuid; v_command_id uuid; v_trace_id uuid;
  v_expected_version bigint; v_service_date date; v_key text; v_hash text;
  v_existing public.command_idempotency%rowtype; v_exception public.driver_shift_exceptions%rowtype;
  v_role public.tenant_role; v_now timestamptz := now(); v_event_id uuid := gen_random_uuid();
  v_state jsonb; v_event jsonb; v_result jsonb;
begin
  if p_command is null or coalesce((p_command->>'schemaVersion')::int,0) <> 1 or p_command->>'commandType' <> v_type then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command->>'tenantId')::uuid; v_driver_id := (p_command->>'aggregateId')::uuid;
    v_command_id := (p_command->>'commandId')::uuid; v_trace_id := (p_command->>'traceId')::uuid;
    v_expected_version := (p_command->>'expectedVersion')::bigint;
    v_service_date := (p_command->'payload'->>'serviceDate')::date;
  exception when others then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Clear-exception identifiers, version or date are invalid'));
  end;
  v_key := btrim(coalesce(p_command->>'idempotencyKey',''));
  if v_expected_version < 1 or v_key = '' or length(v_key) > 200 then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','VALIDATION_FAILED','message','Clear-exception command is invalid'));
  end if;
  v_hash := encode(digest((p_command->'payload')::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text||':'||v_type||':'||v_key,0));
  select * into v_existing from public.command_idempotency where tenant_id=v_tenant_id and command_type=v_type and idempotency_key=v_key;
  if found then
    if v_existing.payload_hash<>v_hash then return jsonb_build_object('status','rejected','error',jsonb_build_object('code','IDEMPOTENCY_CONFLICT','message','Idempotency key was already used with different payload')); end if;
    return v_existing.result||jsonb_build_object('deduplicated',true);
  end if;
  select membership.role into v_role from public.tenant_memberships membership where membership.tenant_id=v_tenant_id and membership.person_id=p_actor_person_id and membership.status='active' and membership.role in ('tenant_owner','operations_admin','dispatcher') limit 1;
  if not found then return jsonb_build_object('status','rejected','error',jsonb_build_object('code','NOT_AUTHORIZED','message','Driver shift exception configuration is not permitted')); end if;
  select * into v_exception from public.driver_shift_exceptions where tenant_id=v_tenant_id and driver_id=v_driver_id and service_date=v_service_date and deleted_at is null for update;
  if not found then return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','No active date exception exists')); end if;
  if v_exception.version<>v_expected_version then return jsonb_build_object('status','rejected','error',jsonb_build_object('code','STALE_VERSION','message','Driver date exception changed; refresh before clearing')); end if;
  update public.driver_shift_exceptions set version=version+1,updated_at=v_now,deleted_at=v_now where id=v_exception.id;
  v_state:=jsonb_build_object('exceptionId',v_exception.id,'driverId',v_driver_id,'serviceDate',v_service_date,'clearedAt',v_now);
  v_event:=jsonb_build_object('event','operations.driver_shift_exception_cleared','version',1,'eventId',v_event_id,'traceId',v_trace_id,'tenantId',v_tenant_id,'aggregateType','driver_shift_exception','aggregateId',v_driver_id,'aggregateVersion',v_expected_version+1,'occurredAt',v_now,'payload',v_state);
  insert into public.audit_events(tenant_id,actor_person_id,actor_role,action,aggregate_type,aggregate_id,aggregate_version,command_id,trace_id,semantic_change) values(v_tenant_id,p_actor_person_id,v_role,'operations.driver_shift_exception_cleared','driver_shift_exception',v_driver_id,v_expected_version+1,v_command_id,v_trace_id,jsonb_build_object('serviceDate',v_service_date,'restoredSource','recurring'));
  insert into public.domain_event_outbox(id,tenant_id,event_name,event_version,aggregate_type,aggregate_id,aggregate_version,trace_id,payload,occurred_at) values(v_event_id,v_tenant_id,'operations.driver_shift_exception_cleared',1,'driver_shift_exception',v_driver_id,v_expected_version+1,v_trace_id,v_event,v_now);
  v_result:=jsonb_build_object('status','committed','aggregateVersion',v_expected_version+1,'state',v_state,'events',jsonb_build_array(v_event));
  insert into public.command_idempotency(tenant_id,command_type,idempotency_key,command_id,aggregate_id,payload_hash,status,result,trace_id,actor_person_id) values(v_tenant_id,v_type,v_key,v_command_id,v_driver_id,v_hash,'committed',v_result,v_trace_id,p_actor_person_id);
  return v_result;
end;
$$;

revoke all on function public.clear_driver_shift_exception_command(jsonb,uuid) from public,anon,authenticated;
grant execute on function public.clear_driver_shift_exception_command(jsonb,uuid) to service_role;
comment on function public.clear_driver_shift_exception_command(jsonb,uuid) is 'Server-only audited action that restores the recurring schedule for one driver date.';
