-- Slice 2: a Round cannot be approved without a fresh server-produced route fit.
-- Geometry stays transient; the durable snapshot contains provider provenance,
-- travel totals, per-Stop ETAs, promise results, and warnings only.

alter table public.rounds add column route_plan_snapshot jsonb;

alter function public.plan_and_approve_round_command(jsonb, uuid)
  rename to plan_and_approve_round_without_route_plan_guard;
revoke all on function public.plan_and_approve_round_without_route_plan_guard(jsonb, uuid)
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
  v_payload jsonb;
  v_route jsonb;
  v_round_id uuid;
  v_tenant_id uuid;
  v_result jsonb;
begin
  if p_command is null or p_command ->> 'commandType' <> 'round.plan_and_approve' then
    return public.plan_and_approve_round_without_route_plan_guard(p_command, p_actor_person_id);
  end if;
  v_payload := p_command -> 'payload';
  v_route := v_payload -> 'routePlan';
  begin
    v_round_id := (p_command ->> 'aggregateId')::uuid;
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
  exception when others then
    return public.plan_and_approve_round_without_route_plan_guard(p_command, p_actor_person_id);
  end;

  if jsonb_typeof(v_route) <> 'object'
     or v_route ->> 'status' <> 'fits'
     or v_route ->> 'driverId' is distinct from v_payload ->> 'driverId'
     or v_route ->> 'serviceDate' is distinct from v_payload ->> 'serviceDate'
     or v_route -> 'stopIds' is distinct from v_payload -> 'stopIds'
     or v_route -> 'provider' ->> 'name' <> 'mapbox'
     or v_route -> 'provider' ->> 'profile' <> 'driving-traffic'
     or jsonb_typeof(v_route -> 'stops') <> 'array'
     or jsonb_array_length(coalesce(v_route -> 'blockingReasons', '[]'::jsonb)) <> 0 then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE',
      'message', 'A matching server-calculated route and promised-window fit is required before approval.'));
  end if;

  v_result := public.plan_and_approve_round_without_route_plan_guard(p_command, p_actor_person_id);
  if v_result ->> 'status' = 'committed' then
    update public.rounds
       set route_plan_snapshot = v_route,
           capacity_rule_snapshot = case
             when capacity_rule_snapshot is null then null
             else jsonb_set(capacity_rule_snapshot, '{warnings}', coalesce((
               select jsonb_agg(warning)
                 from jsonb_array_elements(capacity_rule_snapshot -> 'warnings') warning
                where warning #>> '{}' <> 'Travel time and promised-window fit are not verified until server routing is connected.'
             ), '[]'::jsonb))
           end
     where id = v_round_id and tenant_id = v_tenant_id;
  end if;
  return v_result;
end;
$$;

revoke all on function public.plan_and_approve_round_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.plan_and_approve_round_command(jsonb, uuid) to service_role;

comment on column public.rounds.route_plan_snapshot is
  'Immutable-at-approval server route, timing, promise-fit, and provider-provenance snapshot. Route geometry is intentionally not persisted.';
comment on function public.plan_and_approve_round_command(jsonb, uuid) is
  'Manual Team Round approval guarded by static capacity plus a matching server-calculated route and promised-window fit.';
