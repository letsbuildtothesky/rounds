-- Add independent own-team and route-provenance/capacity checks without
-- changing the already-applied atomic move implementation.

alter function public.move_round_stop_command(jsonb,uuid)
  rename to move_round_stop_without_integrity_guard;
revoke all on function public.move_round_stop_without_integrity_guard(jsonb,uuid)
  from public,anon,authenticated,service_role;

create or replace function public.move_round_stop_command(p_command jsonb,p_actor_person_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  v_tenant_id uuid;
  v_source_id uuid;
  v_target_id uuid;
  v_idempotency_key text;
  v_source_driver_id uuid;
  v_target_driver_id uuid;
  v_source_route jsonb;
  v_target_route jsonb;
  v_source_stops jsonb;
begin
  if p_command is null or p_command ->> 'commandType' <> 'round.move_stop' then
    return public.move_round_stop_without_integrity_guard(p_command,p_actor_person_id);
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_source_id := (p_command ->> 'aggregateId')::uuid;
    v_target_id := (p_command -> 'payload' ->> 'targetRoundId')::uuid;
    v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey',''));
  exception when others then
    return public.move_round_stop_without_integrity_guard(p_command,p_actor_person_id);
  end;
  if exists(select 1 from public.command_idempotency where tenant_id=v_tenant_id and command_type='round.move_stop' and idempotency_key=v_idempotency_key) then
    return public.move_round_stop_without_integrity_guard(p_command,p_actor_person_id);
  end if;

  select driver_id into v_source_driver_id from public.rounds where tenant_id=v_tenant_id and id=v_source_id and deleted_at is null;
  select driver_id into v_target_driver_id from public.rounds where tenant_id=v_tenant_id and id=v_target_id and deleted_at is null;
  if exists(
    select 1 from unnest(array[v_source_driver_id,v_target_driver_id]) requested(driver_id)
     where not exists(
       select 1 from public.driver_tenant_relationships relationship
       join public.driver_profiles driver on driver.id=relationship.driver_id
       where relationship.tenant_id=v_tenant_id and relationship.driver_id=requested.driver_id
         and relationship.relationship_kind='team' and relationship.status='active' and relationship.deleted_at is null
         and driver.active=true and driver.deleted_at is null)) then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Both Rounds must belong to active own-team drivers'));
  end if;

  v_source_route := p_command -> 'payload' -> 'sourceRoutePlan';
  v_target_route := p_command -> 'payload' -> 'targetRoutePlan';
  v_source_stops := p_command -> 'payload' -> 'sourceStopIds';
  if (jsonb_array_length(coalesce(v_source_stops,'[]'::jsonb)) > 0 and (
       v_source_route -> 'capacity' ->> 'status' <> 'fits'
       or v_source_route -> 'provider' ->> 'name' <> 'mapbox'
       or v_source_route -> 'provider' ->> 'profile' <> 'driving-traffic'))
     or v_target_route -> 'capacity' ->> 'status' <> 'fits'
     or v_target_route -> 'provider' ->> 'name' <> 'mapbox'
     or v_target_route -> 'provider' ->> 'profile' <> 'driving-traffic' then
    return jsonb_build_object('status','rejected','error',jsonb_build_object('code','INVALID_STATE','message','Both resulting routes require fitting capacity and approved provider provenance'));
  end if;
  return public.move_round_stop_without_integrity_guard(p_command,p_actor_person_id);
end;
$$;

revoke all on function public.move_round_stop_command(jsonb,uuid) from public,anon,authenticated;
grant execute on function public.move_round_stop_command(jsonb,uuid) to service_role;
comment on function public.move_round_stop_command(jsonb,uuid) is
  'Guarded pre-custody Stop move requiring two active own-team drivers and fitting Mapbox route provenance before the atomic dual-Round command.';
