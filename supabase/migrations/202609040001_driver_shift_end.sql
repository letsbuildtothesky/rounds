-- B01F Team Driver shift end. The server owns the timestamp and refuses to
-- release attendance while assigned work or custody is still active.

alter table public.driver_shift_attendance
  add column end_command_id uuid unique;

create or replace function public.end_driver_shift_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'driver.end_shift';
  v_tenant_id uuid;
  v_attendance_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_idempotency_key text;
  v_occurred_from_device_at timestamptz;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_attendance public.driver_shift_attendance%rowtype;
  v_role public.tenant_role;
  v_ended_at timestamptz := now();
  v_worked_minutes integer;
  v_past_scheduled_end_minutes integer;
  v_event_id uuid := gen_random_uuid();
  v_state jsonb;
  v_event jsonb;
  v_result jsonb;
begin
  if p_command is null or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
     or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','VALIDATION_FAILED','message','Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_attendance_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_occurred_from_device_at := nullif(p_command ->> 'occurredFromDeviceAt','')::timestamptz;
  exception when others then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','VALIDATION_FAILED','message','Shift identifiers or version are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey',''));
  v_payload := p_command -> 'payload';
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
     or v_payload is null or nullif(v_payload ->> 'attendanceId','') is null
     or nullif(v_payload ->> 'attendanceId','')::uuid <> v_attendance_id then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','VALIDATION_FAILED','message','Shift end payload is invalid'));
  end if;

  v_payload_hash := encode(digest(v_payload::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key, 0));
  select * into v_existing from public.command_idempotency
   where tenant_id=v_tenant_id and command_type=v_command_type and idempotency_key=v_idempotency_key;
  if found then
    if v_existing.payload_hash <> v_payload_hash then
      return jsonb_build_object('status','rejected','error',jsonb_build_object(
        'code','IDEMPOTENCY_CONFLICT','message','Idempotency key was already used with different payload'));
    end if;
    return v_existing.result || jsonb_build_object('deduplicated',true);
  end if;

  select attendance.* into v_attendance
    from public.driver_shift_attendance attendance
    join public.driver_profiles driver on driver.id=attendance.driver_id
    join public.tenant_memberships membership
      on membership.tenant_id=attendance.tenant_id and membership.person_id=driver.person_id
    join public.driver_tenant_relationships relationship
      on relationship.tenant_id=attendance.tenant_id and relationship.driver_id=driver.id
   where attendance.id=v_attendance_id and attendance.tenant_id=v_tenant_id
     and membership.person_id=p_actor_person_id and membership.status='active'
     and membership.role='team_driver' and driver.active=true and driver.deleted_at is null
     and relationship.relationship_kind='team' and relationship.status='active'
     and relationship.deleted_at is null
   for update of attendance;
  if not found then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','NOT_AUTHORIZED','message','Actor is not the active Team driver for this shift'));
  end if;
  v_role := 'team_driver';
  if v_attendance.version <> v_expected_version then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','STALE_VERSION','message','Shift attendance changed; refresh before ending the shift'));
  end if;
  if v_attendance.ended_at is not null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','INVALID_STATE','message','This Team shift has already ended'));
  end if;
  if v_ended_at < v_attendance.scheduled_end_at then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','INVALID_STATE','message','The scheduled Team shift has not ended yet'));
  end if;
  if exists (
    select 1 from public.rounds round
     where round.tenant_id=v_tenant_id and round.driver_id=v_attendance.driver_id
       and round.state in ('approved','loading','active') and round.deleted_at is null
  ) then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','CUSTODY_LOCKED','message','Complete or transfer assigned work before ending the shift'));
  end if;

  v_worked_minutes := greatest(0, floor(extract(epoch from (v_ended_at-v_attendance.started_at))/60)::integer);
  v_past_scheduled_end_minutes := greatest(0, floor(extract(epoch from (v_ended_at-v_attendance.scheduled_end_at))/60)::integer);
  update public.driver_shift_attendance set
    ended_at=v_ended_at,
    end_command_id=v_command_id,
    version=version+1,
    updated_at=v_ended_at
   where id=v_attendance_id;

  v_state := jsonb_build_object(
    'id',v_attendance_id,'version',v_expected_version+1,'serviceDate',v_attendance.service_date,
    'driverId',v_attendance.driver_id,'startedAt',v_attendance.started_at,'endedAt',v_ended_at,
    'scheduledStartAt',v_attendance.scheduled_start_at,'scheduledEndAt',v_attendance.scheduled_end_at,
    'workedMinutes',v_worked_minutes,'pastScheduledEndMinutes',v_past_scheduled_end_minutes);
  v_event := jsonb_build_object(
    'event','driver.shift_ended','version',1,'eventId',v_event_id,'traceId',v_trace_id,
    'tenantId',v_tenant_id,'aggregateType','driver_shift','aggregateId',v_attendance_id,
    'aggregateVersion',v_expected_version+1,'occurredAt',v_ended_at,'payload',v_state);
  insert into public.audit_events (
    tenant_id,actor_person_id,actor_role,action,aggregate_type,aggregate_id,
    aggregate_version,command_id,trace_id,semantic_change
  ) values (
    v_tenant_id,p_actor_person_id,v_role,'driver.shift_ended','driver_shift',
    v_attendance_id,v_expected_version+1,v_command_id,v_trace_id,jsonb_build_object(
      'serviceDate',v_attendance.service_date,'scheduledEndAt',v_attendance.scheduled_end_at,
      'actualEndAt',v_ended_at,'occurredFromDeviceAt',v_occurred_from_device_at,
      'workedMinutes',v_worked_minutes,'pastScheduledEndMinutes',v_past_scheduled_end_minutes));
  insert into public.domain_event_outbox (
    id,tenant_id,event_name,event_version,aggregate_type,aggregate_id,
    aggregate_version,trace_id,payload,occurred_at
  ) values (
    v_event_id,v_tenant_id,'driver.shift_ended',1,'driver_shift',v_attendance_id,
    v_expected_version+1,v_trace_id,v_event,v_ended_at);
  v_result := jsonb_build_object('status','committed','aggregateVersion',v_expected_version+1,
    'state',v_state,'events',jsonb_build_array(v_event));
  insert into public.command_idempotency (
    tenant_id,command_type,idempotency_key,command_id,aggregate_id,
    payload_hash,status,result,trace_id,actor_person_id
  ) values (
    v_tenant_id,v_command_type,v_idempotency_key,v_command_id,v_attendance_id,
    v_payload_hash,'committed',v_result,v_trace_id,p_actor_person_id);
  return v_result;
exception when invalid_text_representation then
  return jsonb_build_object('status','rejected','error',jsonb_build_object(
    'code','VALIDATION_FAILED','message','Shift end payload is invalid'));
end;
$$;

revoke all on function public.end_driver_shift_command(jsonb,uuid) from public,anon,authenticated;
grant execute on function public.end_driver_shift_command(jsonb,uuid) to service_role;

comment on function public.end_driver_shift_command(jsonb,uuid) is
  'Server-only B01F command that ends Team attendance after scheduled time and only when no assigned work remains.';
