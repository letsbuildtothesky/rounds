-- Slice 2: make cargo class limits part of the same server-authoritative
-- own-team capacity decision as Stop count and departure pattern.
-- No tenant cargo values are inferred or seeded by this migration.

create or replace function public.get_own_team_round_capacity(
  p_tenant_id uuid,
  p_driver_id uuid,
  p_service_date date,
  p_stop_ids jsonb
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, extensions
as $$
declare
  v_static jsonb;
  v_profile_id uuid;
  v_dimensions jsonb := '[]'::jsonb;
  v_reasons jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_status text := 'fits';
  v_requirement record;
  v_class_id uuid;
  v_class_name text;
  v_allowed boolean;
  v_max_quantity integer;
  v_dimension jsonb;
  v_constraining jsonb;
  v_stop_count integer;
begin
  if jsonb_typeof(p_stop_ids) <> 'array' then
    return jsonb_build_object(
      'valid', false, 'status', 'blocked', 'dimensions', '[]'::jsonb,
      'reasons', jsonb_build_array('Stop IDs must be an ordered array.'), 'warnings', '[]'::jsonb);
  end if;
  v_stop_count := jsonb_array_length(p_stop_ids);
  v_static := public.get_own_team_round_static_capacity(
    p_tenant_id, p_driver_id, p_service_date, v_stop_count);
  v_reasons := coalesce(v_static -> 'reasons', '[]'::jsonb);
  select coalesce(jsonb_agg(warning), '[]'::jsonb) into v_warnings
    from jsonb_array_elements(coalesce(v_static -> 'warnings', '[]'::jsonb)) warning
   where warning #>> '{}' <> 'Cargo fit is not verified for deliveries without a configured cargo class.';

  v_dimensions := jsonb_build_array(jsonb_build_object(
    'kind', 'stops', 'code', 'stops', 'displayName', 'Stops per departure',
    'used', v_stop_count,
    'limit', coalesce((v_static -> 'vehicleProfile' ->> 'maxStopsPerDeparture')::integer, 0),
    'remaining', greatest(0, coalesce((v_static -> 'vehicleProfile' ->> 'maxStopsPerDeparture')::integer, 0) - v_stop_count),
    'utilizationPercent', case
      when coalesce((v_static -> 'vehicleProfile' ->> 'maxStopsPerDeparture')::integer, 0) > 0
      then round(100.0 * v_stop_count / (v_static -> 'vehicleProfile' ->> 'maxStopsPerDeparture')::integer)
      else 100 end,
    'status', case when coalesce((v_static ->> 'valid')::boolean, false) then 'fits' else 'blocked' end));

  if not coalesce((v_static ->> 'valid')::boolean, false) then v_status := 'blocked'; end if;
  begin
    v_profile_id := (v_static -> 'vehicleProfile' ->> 'id')::uuid;
  exception when others then
    v_profile_id := null;
  end;

  if v_profile_id is not null then
    for v_requirement in
      with selected_stops as (
        select value::uuid as stop_id from jsonb_array_elements_text(p_stop_ids)
      ), selected_manifests as (
        select distinct on (manifest.delivery_id) manifest.id
          from selected_stops selected
          join public.delivery_stops stop
            on stop.tenant_id = p_tenant_id and stop.id = selected.stop_id
          join public.deliveries delivery
            on delivery.tenant_id = p_tenant_id and delivery.id = stop.delivery_id
          join public.manifests manifest
            on manifest.tenant_id = p_tenant_id and manifest.delivery_id = delivery.id
         order by manifest.delivery_id, manifest.version desc
      )
      select coalesce(nullif(lower(btrim(item.cargo_class)), ''), 'unclassified') as cargo_code,
             sum(item.quantity)::integer as used_quantity
        from selected_manifests manifest
        join public.manifest_items item
          on item.tenant_id = p_tenant_id and item.manifest_id = manifest.id
       group by coalesce(nullif(lower(btrim(item.cargo_class)), ''), 'unclassified')
       order by 1
    loop
      v_class_id := null;
      v_class_name := null;
      v_allowed := null;
      v_max_quantity := null;
      if v_requirement.cargo_code <> 'unclassified' then
        select cargo.id, cargo.display_name, limit_rule.allowed, limit_rule.max_quantity
          into v_class_id, v_class_name, v_allowed, v_max_quantity
          from public.cargo_classes cargo
          left join public.vehicle_profile_cargo_limits limit_rule
            on limit_rule.tenant_id = cargo.tenant_id
           and limit_rule.cargo_class_id = cargo.id
           and limit_rule.vehicle_profile_id = v_profile_id
         where cargo.tenant_id = p_tenant_id and cargo.code = v_requirement.cargo_code
           and cargo.active = true and cargo.deleted_at is null;
      end if;

      if v_requirement.cargo_code = 'unclassified' then
        v_dimension := jsonb_build_object(
          'kind', 'cargo', 'code', 'unclassified', 'displayName', 'Unclassified cargo',
          'used', v_requirement.used_quantity, 'status', 'review_required');
        v_reasons := v_reasons || jsonb_build_array(format(
          '%s cargo unit%s %s unclassified and require Operations review.',
          v_requirement.used_quantity,
          case when v_requirement.used_quantity = 1 then '' else 's' end,
          case when v_requirement.used_quantity = 1 then 'is' else 'are' end));
        if v_status = 'fits' then v_status := 'review_required'; end if;
      elsif v_class_id is null then
        v_dimension := jsonb_build_object(
          'kind', 'cargo', 'code', v_requirement.cargo_code, 'displayName', v_requirement.cargo_code,
          'used', v_requirement.used_quantity, 'status', 'review_required');
        v_reasons := v_reasons || jsonb_build_array(format(
          '%s is not an active tenant cargo class.', v_requirement.cargo_code));
        if v_status = 'fits' then v_status := 'review_required'; end if;
      elsif v_allowed is null then
        v_dimension := jsonb_build_object(
          'kind', 'cargo', 'code', v_requirement.cargo_code, 'displayName', v_class_name,
          'used', v_requirement.used_quantity, 'status', 'review_required');
        v_reasons := v_reasons || jsonb_build_array(format(
          '%s has no configured limit for this vehicle profile.', v_class_name));
        if v_status = 'fits' then v_status := 'review_required'; end if;
      elsif not v_allowed then
        v_dimension := jsonb_build_object(
          'kind', 'cargo', 'code', v_requirement.cargo_code, 'displayName', v_class_name,
          'used', v_requirement.used_quantity, 'status', 'blocked');
        v_reasons := v_reasons || jsonb_build_array(format(
          '%s is not allowed for this vehicle profile.', v_class_name));
        v_status := 'blocked';
      elsif v_max_quantity is null then
        v_dimension := jsonb_build_object(
          'kind', 'cargo', 'code', v_requirement.cargo_code, 'displayName', v_class_name,
          'used', v_requirement.used_quantity, 'status', 'review_required');
        v_reasons := v_reasons || jsonb_build_array(format(
          '%s has no approved quantity limit for this vehicle profile.', v_class_name));
        if v_status = 'fits' then v_status := 'review_required'; end if;
      else
        v_dimension := jsonb_build_object(
          'kind', 'cargo', 'code', v_requirement.cargo_code, 'displayName', v_class_name,
          'used', v_requirement.used_quantity, 'limit', v_max_quantity,
          'remaining', greatest(0, v_max_quantity - v_requirement.used_quantity),
          'utilizationPercent', round(100.0 * v_requirement.used_quantity / v_max_quantity),
          'status', case when v_requirement.used_quantity > v_max_quantity then 'blocked' else 'fits' end);
        if v_requirement.used_quantity > v_max_quantity then
          v_reasons := v_reasons || jsonb_build_array(format(
            '%s allows %s unit%s; this proposal has %s.', v_class_name, v_max_quantity,
            case when v_max_quantity = 1 then '' else 's' end, v_requirement.used_quantity));
          v_status := 'blocked';
        end if;
      end if;
      v_dimensions := v_dimensions || jsonb_build_array(v_dimension);
    end loop;
  end if;

  select jsonb_build_object('kind', dimension ->> 'kind', 'code', dimension ->> 'code')
    into v_constraining
    from jsonb_array_elements(v_dimensions) dimension
   order by case dimension ->> 'status' when 'blocked' then 0 when 'review_required' then 1 else 2 end,
            coalesce((dimension ->> 'utilizationPercent')::numeric, 1000000) desc
   limit 1;

  return jsonb_strip_nulls(jsonb_build_object(
    'valid', v_status = 'fits', 'status', v_status,
    'serviceDate', p_service_date, 'stopIds', p_stop_ids,
    'dimensions', v_dimensions, 'constrainingDimension', v_constraining,
    'reasons', v_reasons, 'warnings', v_warnings,
    'effectiveShift', v_static -> 'effectiveShift',
    'vehicleProfile', v_static -> 'vehicleProfile'));
end;
$$;

revoke all on function public.get_own_team_round_capacity(uuid, uuid, date, jsonb)
  from public, anon, authenticated;
grant execute on function public.get_own_team_round_capacity(uuid, uuid, date, jsonb) to service_role;

alter function public.plan_and_approve_round_command(jsonb, uuid)
  rename to plan_and_approve_round_without_cargo_capacity_guard;
revoke all on function public.plan_and_approve_round_without_cargo_capacity_guard(jsonb, uuid)
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
  v_stop_ids jsonb;
  v_idempotency_key text;
  v_existing public.command_idempotency%rowtype;
  v_capacity jsonb;
  v_result jsonb;
begin
  if p_command is null or p_command ->> 'commandType' <> 'round.plan_and_approve' then
    return public.plan_and_approve_round_without_cargo_capacity_guard(p_command, p_actor_person_id);
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_round_id := (p_command ->> 'aggregateId')::uuid;
    v_driver_id := (p_command -> 'payload' ->> 'driverId')::uuid;
    v_service_date := (p_command -> 'payload' ->> 'serviceDate')::date;
    v_stop_ids := p_command -> 'payload' -> 'stopIds';
  exception when others then
    return public.plan_and_approve_round_without_cargo_capacity_guard(p_command, p_actor_person_id);
  end;

  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  select * into v_existing from public.command_idempotency
   where tenant_id = v_tenant_id and command_type = 'round.plan_and_approve'
     and idempotency_key = v_idempotency_key;
  if found then return v_existing.result; end if;

  if p_command -> 'payload' -> 'routePlan' -> 'capacity' ->> 'status' <> 'fits' then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE',
      'message', 'A server-calculated cargo and vehicle capacity fit is required before approval.'));
  end if;

  v_capacity := public.get_own_team_round_capacity(
    v_tenant_id, v_driver_id, v_service_date, v_stop_ids);
  if not coalesce((v_capacity ->> 'valid')::boolean, false) then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object(
        'code', 'INVALID_STATE',
        'message', coalesce(v_capacity -> 'reasons' ->> 0, 'Round exceeds own-team capacity rules.'),
        'capacity', v_capacity));
  end if;

  v_result := public.plan_and_approve_round_without_cargo_capacity_guard(p_command, p_actor_person_id);
  if v_result ->> 'status' = 'committed' then
    update public.rounds set capacity_rule_snapshot = v_capacity
     where id = v_round_id and tenant_id = v_tenant_id;
  end if;
  return v_result;
end;
$$;

revoke all on function public.plan_and_approve_round_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.plan_and_approve_round_command(jsonb, uuid) to service_role;

comment on function public.get_own_team_round_capacity(uuid, uuid, date, jsonb) is
  'Shared own-team capacity decision over Stop count, departure pattern, classified cargo quantities, and vehicle cargo limits. Unknown truth returns review_required and cannot approve.';
comment on function public.plan_and_approve_round_command(jsonb, uuid) is
  'Manual Team Round approval guarded by a fresh server route plus server-recalculated multidimensional vehicle and cargo capacity.';
