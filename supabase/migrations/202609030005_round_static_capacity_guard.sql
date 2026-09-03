-- Slice 2: the existing manual Round command now shares a server-side
-- own-team shift and vehicle Stop-limit guard with planning guidance.
-- Route duration and cargo classification remain explicit unverified warnings.

alter table public.rounds add column capacity_rule_snapshot jsonb;

create or replace function public.get_own_team_round_static_capacity(
  p_tenant_id uuid,
  p_driver_id uuid,
  p_service_date date,
  p_stop_count integer
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, extensions
as $$
declare
  v_schedule public.driver_recurring_schedules%rowtype;
  v_exception public.driver_shift_exceptions%rowtype;
  v_profile public.vehicle_profiles%rowtype;
  v_profile_id uuid;
  v_shift_source text;
  v_start_local time;
  v_end_local time;
  v_iso_weekday integer := extract(isodow from p_service_date)::integer;
  v_reasons jsonb := '[]'::jsonb;
  v_warnings jsonb := jsonb_build_array(
    'Travel time and promised-window fit are not verified until server routing is connected.',
    'Cargo fit is not verified for deliveries without a configured cargo class.'
  );
begin
  if p_stop_count is null or p_stop_count < 1 then
    return jsonb_build_object('valid', false, 'reasons', jsonb_build_array('A Round needs at least one Stop.'), 'warnings', v_warnings);
  end if;
  if not exists (
    select 1 from public.driver_tenant_relationships relationship
    join public.driver_profiles driver on driver.id = relationship.driver_id
    where relationship.tenant_id = p_tenant_id and relationship.driver_id = p_driver_id
      and relationship.relationship_kind = 'team' and relationship.status = 'active'
      and relationship.deleted_at is null and driver.active = true and driver.deleted_at is null
  ) then
    return jsonb_build_object('valid', false, 'reasons', jsonb_build_array('Driver is not an active own-team driver.'), 'warnings', v_warnings);
  end if;

  select * into v_schedule from public.driver_recurring_schedules
   where tenant_id = p_tenant_id and driver_id = p_driver_id and active = true and deleted_at is null;
  select * into v_exception from public.driver_shift_exceptions
   where tenant_id = p_tenant_id and driver_id = p_driver_id and service_date = p_service_date and deleted_at is null;

  if found and v_exception.exception_kind = 'off' then
    v_reasons := v_reasons || jsonb_build_array('Driver has a day-off exception for this service date.');
  elsif found and v_exception.exception_kind = 'shift' then
    v_shift_source := 'exception';
    v_start_local := v_exception.start_local;
    v_end_local := v_exception.end_local;
    v_profile_id := v_exception.vehicle_profile_id;
  elsif v_schedule.id is null then
    v_reasons := v_reasons || jsonb_build_array('Driver has no recurring schedule for this service date.');
  elsif not (v_iso_weekday = any(v_schedule.weekdays)) then
    v_reasons := v_reasons || jsonb_build_array('Driver is off shift on this service date.');
  else
    v_shift_source := 'recurring';
    v_start_local := v_schedule.start_local;
    v_end_local := v_schedule.end_local;
    v_profile_id := v_schedule.vehicle_profile_id;
  end if;

  if v_profile_id is null then
    select assignment.vehicle_profile_id into v_profile_id
      from public.driver_vehicle_assignments assignment
     where assignment.tenant_id = p_tenant_id and assignment.driver_id = p_driver_id
       and assignment.is_default = true and assignment.deleted_at is null
       and assignment.effective_from <= p_service_date
       and (assignment.effective_to is null or assignment.effective_to >= p_service_date)
     order by assignment.effective_from desc limit 1;
  end if;
  if v_profile_id is not null then
    select * into v_profile from public.vehicle_profiles
     where tenant_id = p_tenant_id and id = v_profile_id and active = true and deleted_at is null;
  end if;
  if v_profile.id is null then
    v_reasons := v_reasons || jsonb_build_array('Driver has no active vehicle profile for this service date.');
  else
    if p_stop_count > v_profile.max_stops_per_departure then
      v_reasons := v_reasons || jsonb_build_array(format(
        '%s allows %s Stop%s per departure; this proposal has %s.',
        v_profile.display_name, v_profile.max_stops_per_departure,
        case when v_profile.max_stops_per_departure = 1 then '' else 's' end, p_stop_count));
    end if;
    if v_profile.departure_pattern = 'return_after_every_delivery' and p_stop_count > 1 then
      v_reasons := v_reasons || jsonb_build_array('Vehicle rules require returning to pickup after every delivery.');
    end if;
    if v_profile.requires_review then
      v_warnings := v_warnings || jsonb_build_array('Vehicle profile is a conservative migrated default and still requires Operations review.');
    end if;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'valid', jsonb_array_length(v_reasons) = 0,
    'serviceDate', p_service_date,
    'stopCount', p_stop_count,
    'reasons', v_reasons,
    'warnings', v_warnings,
    'effectiveShift', case when v_shift_source is null then null else jsonb_build_object(
      'source', v_shift_source, 'startLocal', to_char(v_start_local, 'HH24:MI'),
      'endLocal', to_char(v_end_local, 'HH24:MI'), 'crossesMidnight', v_end_local <= v_start_local) end,
    'vehicleProfile', case when v_profile.id is null then null else jsonb_build_object(
      'id', v_profile.id, 'version', v_profile.version, 'displayName', v_profile.display_name,
      'vehicleGroup', v_profile.vehicle_group, 'departurePattern', v_profile.departure_pattern,
      'maxStopsPerDeparture', v_profile.max_stops_per_departure,
      'planningDeliveriesPerBlock', v_profile.planning_deliveries_per_block,
      'pickupTurnaroundMinutes', v_profile.pickup_turnaround_minutes,
      'requiresReview', v_profile.requires_review) end));
end;
$$;

revoke all on function public.get_own_team_round_static_capacity(uuid, uuid, date, integer)
  from public, anon, authenticated;
grant execute on function public.get_own_team_round_static_capacity(uuid, uuid, date, integer) to service_role;

alter function public.plan_and_approve_round_command(jsonb, uuid)
  rename to plan_and_approve_round_without_capacity_guard;
revoke all on function public.plan_and_approve_round_without_capacity_guard(jsonb, uuid)
  from public, anon, authenticated, service_role;

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
  v_tenant_id uuid;
  v_round_id uuid;
  v_driver_id uuid;
  v_service_date date;
  v_stop_count integer;
  v_idempotency_key text;
  v_existing public.command_idempotency%rowtype;
  v_capacity jsonb;
  v_result jsonb;
begin
  if p_command is null or p_command ->> 'commandType' <> 'round.plan_and_approve' then
    return public.plan_and_approve_round_without_capacity_guard(p_command, p_actor_person_id);
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_round_id := (p_command ->> 'aggregateId')::uuid;
    v_driver_id := (p_command -> 'payload' ->> 'driverId')::uuid;
    v_service_date := (p_command -> 'payload' ->> 'serviceDate')::date;
    v_stop_count := jsonb_array_length(p_command -> 'payload' -> 'stopIds');
  exception when others then
    return public.plan_and_approve_round_without_capacity_guard(p_command, p_actor_person_id);
  end;

  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  select * into v_existing from public.command_idempotency
   where tenant_id = v_tenant_id and command_type = 'round.plan_and_approve'
     and idempotency_key = v_idempotency_key;
  if found then return v_existing.result; end if;

  v_capacity := public.get_own_team_round_static_capacity(
    v_tenant_id, v_driver_id, v_service_date, v_stop_count);
  if not coalesce((v_capacity ->> 'valid')::boolean, false) then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object(
        'code', 'INVALID_STATE',
        'message', coalesce(v_capacity -> 'reasons' ->> 0, 'Round exceeds own-team capacity rules.'),
        'capacity', v_capacity));
  end if;

  v_result := public.plan_and_approve_round_without_capacity_guard(p_command, p_actor_person_id);
  if v_result ->> 'status' = 'committed' then
    update public.rounds set capacity_rule_snapshot = v_capacity where id = v_round_id and tenant_id = v_tenant_id;
  end if;
  return v_result;
end;
$$;

revoke all on function public.plan_and_approve_round_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.plan_and_approve_round_command(jsonb, uuid) to service_role;

comment on column public.rounds.capacity_rule_snapshot is
  'Immutable-at-approval snapshot of the own-team static capacity rule used for this Round.';
comment on function public.get_own_team_round_static_capacity(uuid, uuid, date, integer) is
  'Shared static own-team planning guard. Returns hard shift/vehicle rules plus explicit unverified route/cargo warnings.';
comment on function public.plan_and_approve_round_command(jsonb, uuid) is
  'Manual Team Round approval guarded by effective shift and vehicle Stop limits, with a rule snapshot on the Round.';
