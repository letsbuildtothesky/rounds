-- B00 Team Driver shift start. The scheduled window remains Operations-owned;
-- this command records the Driver's explicit attendance action without
-- changing assignments, custody, or the configured schedule.

create table public.driver_shift_attendance (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  service_date date not null,
  timezone text not null,
  schedule_source text not null check (schedule_source in ('recurring', 'exception')),
  scheduled_start_at timestamptz not null,
  scheduled_end_at timestamptz not null,
  started_at timestamptz not null,
  started_from_device_at timestamptz,
  ended_at timestamptz,
  version bigint not null default 1 check (version > 0),
  start_command_id uuid not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, driver_id, service_date),
  unique (tenant_id, id),
  check (scheduled_end_at > scheduled_start_at),
  check (ended_at is null or ended_at >= started_at)
);

create index driver_shift_attendance_driver_date_idx
  on public.driver_shift_attendance (tenant_id, driver_id, service_date desc);

alter table public.driver_shift_attendance enable row level security;
revoke all on table public.driver_shift_attendance from anon, authenticated;
grant select on table public.driver_shift_attendance to service_role;

create or replace function public.start_driver_shift_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'driver.start_shift';
  v_tenant_id uuid;
  v_driver_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_service_date date;
  v_idempotency_key text;
  v_occurred_from_device_at timestamptz;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_role public.tenant_role;
  v_timezone text;
  v_source text;
  v_start_local time;
  v_end_local time;
  v_start_at timestamptz;
  v_end_at timestamptz;
  v_attendance_id uuid := gen_random_uuid();
  v_event_id uuid := gen_random_uuid();
  v_started_at timestamptz := now();
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
    v_driver_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_service_date := (p_command #>> '{payload,serviceDate}')::date;
    v_occurred_from_device_at := nullif(p_command ->> 'occurredFromDeviceAt','')::timestamptz;
  exception when others then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','VALIDATION_FAILED','message','Shift identifiers, date, or version are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey',''));
  v_payload := p_command -> 'payload';
  if v_expected_version <> 0 or v_idempotency_key = '' or length(v_idempotency_key) > 200 or v_payload is null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','VALIDATION_FAILED','message','Shift start payload is invalid'));
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

  select membership.role, tenant.timezone into v_role, v_timezone
    from public.tenant_memberships membership
    join public.tenants tenant on tenant.id=membership.tenant_id and tenant.status='active' and tenant.deleted_at is null
    join public.driver_profiles driver on driver.person_id=membership.person_id
    join public.driver_tenant_relationships relationship
      on relationship.driver_id=driver.id and relationship.tenant_id=membership.tenant_id
   where membership.tenant_id=v_tenant_id and membership.person_id=p_actor_person_id
     and membership.status='active' and membership.role='team_driver'
     and driver.id=v_driver_id and driver.active=true and driver.deleted_at is null
     and relationship.relationship_kind='team' and relationship.status='active'
     and relationship.deleted_at is null limit 1;
  if v_role is null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','NOT_AUTHORIZED','message','Actor is not the active Team driver'));
  end if;
  if v_service_date <> (v_started_at at time zone v_timezone)::date then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','INVALID_STATE','message','Only the current local Team shift can be started'));
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_driver_id::text || ':' || v_service_date::text, 0));
  if exists (select 1 from public.driver_shift_attendance
             where tenant_id=v_tenant_id and driver_id=v_driver_id and service_date=v_service_date) then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','INVALID_STATE','message','This Team shift has already started'));
  end if;

  select 'exception', exception.start_local, exception.end_local
    into v_source, v_start_local, v_end_local
    from public.driver_shift_exceptions exception
   where exception.tenant_id=v_tenant_id and exception.driver_id=v_driver_id
     and exception.service_date=v_service_date and exception.exception_kind='shift'
     and exception.deleted_at is null limit 1;
  if v_source is null and exists (
    select 1 from public.driver_shift_exceptions exception
     where exception.tenant_id=v_tenant_id and exception.driver_id=v_driver_id
       and exception.service_date=v_service_date and exception.exception_kind='off'
       and exception.deleted_at is null
  ) then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','INVALID_STATE','message','Today is configured as a Team day off'));
  end if;
  if v_source is null then
    select 'recurring', schedule.start_local, schedule.end_local
      into v_source, v_start_local, v_end_local
      from public.driver_recurring_schedules schedule
     where schedule.tenant_id=v_tenant_id and schedule.driver_id=v_driver_id
       and extract(isodow from v_service_date)::smallint = any(schedule.weekdays)
       and schedule.active=true and schedule.deleted_at is null limit 1;
  end if;
  if v_source is null then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','INVALID_STATE','message','No effective Team shift exists for today'));
  end if;

  v_start_at := (v_service_date + v_start_local) at time zone v_timezone;
  v_end_at := (v_service_date + case when v_end_local <= v_start_local then 1 else 0 end + v_end_local) at time zone v_timezone;
  if v_started_at >= v_end_at then
    return jsonb_build_object('status','rejected','error',jsonb_build_object(
      'code','INVALID_STATE','message','The scheduled Team shift has already ended'));
  end if;

  insert into public.driver_shift_attendance (
    id,tenant_id,driver_id,service_date,timezone,schedule_source,
    scheduled_start_at,scheduled_end_at,started_at,started_from_device_at,start_command_id
  ) values (
    v_attendance_id,v_tenant_id,v_driver_id,v_service_date,v_timezone,v_source,
    v_start_at,v_end_at,v_started_at,v_occurred_from_device_at,v_command_id
  );
  v_state := jsonb_build_object(
    'id',v_attendance_id,'version',1,'serviceDate',v_service_date,
    'driverId',v_driver_id,'startedAt',v_started_at,'scheduledStartAt',v_start_at,
    'scheduledEndAt',v_end_at,'scheduleSource',v_source);
  v_event := jsonb_build_object(
    'event','driver.shift_started','version',1,'eventId',v_event_id,'traceId',v_trace_id,
    'tenantId',v_tenant_id,'aggregateType','driver_shift','aggregateId',v_attendance_id,
    'aggregateVersion',1,'occurredAt',v_started_at,'payload',v_state);
  insert into public.audit_events (
    tenant_id,actor_person_id,actor_role,action,aggregate_type,aggregate_id,
    aggregate_version,command_id,trace_id,semantic_change
  ) values (
    v_tenant_id,p_actor_person_id,v_role,'driver.shift_started','driver_shift',
    v_attendance_id,1,v_command_id,v_trace_id,jsonb_build_object(
      'serviceDate',v_service_date,'scheduledStartAt',v_start_at,'scheduledEndAt',v_end_at,
      'actualStartAt',v_started_at,'scheduleSource',v_source));
  insert into public.domain_event_outbox (
    id,tenant_id,event_name,event_version,aggregate_type,aggregate_id,
    aggregate_version,trace_id,payload,occurred_at
  ) values (
    v_event_id,v_tenant_id,'driver.shift_started',1,'driver_shift',v_attendance_id,
    1,v_trace_id,v_event,v_started_at);
  v_result := jsonb_build_object('status','committed','aggregateVersion',1,
    'state',v_state,'events',jsonb_build_array(v_event));
  insert into public.command_idempotency (
    tenant_id,command_type,idempotency_key,command_id,aggregate_id,
    payload_hash,status,result,trace_id,actor_person_id
  ) values (
    v_tenant_id,v_command_type,v_idempotency_key,v_command_id,v_driver_id,
    v_payload_hash,'committed',v_result,v_trace_id,p_actor_person_id);
  return v_result;
end;
$$;

revoke all on function public.start_driver_shift_command(jsonb,uuid) from public,anon,authenticated;
grant execute on function public.start_driver_shift_command(jsonb,uuid) to service_role;

comment on function public.start_driver_shift_command(jsonb,uuid) is
  'Server-only B00 command that records one explicit Team Driver attendance start against the effective scheduled shift.';
