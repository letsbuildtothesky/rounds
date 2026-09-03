alter function public.plan_and_approve_round_command(jsonb, uuid)
  rename to plan_and_approve_round_without_departure_guard;
revoke all on function public.plan_and_approve_round_without_departure_guard(jsonb, uuid)
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
  v_idempotency_key text;
  v_existing public.command_idempotency%rowtype;
  v_requested_departure timestamptz;
  v_routed_departure timestamptz;
begin
  if p_command is null or p_command ->> 'commandType' <> 'round.plan_and_approve' then
    return public.plan_and_approve_round_without_departure_guard(p_command, p_actor_person_id);
  end if;

  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  exception when others then
    return public.plan_and_approve_round_without_departure_guard(p_command, p_actor_person_id);
  end;

  select * into v_existing
    from public.command_idempotency
   where tenant_id = v_tenant_id
     and command_type = 'round.plan_and_approve'
     and idempotency_key = v_idempotency_key;
  if found then
    return public.plan_and_approve_round_without_departure_guard(p_command, p_actor_person_id);
  end if;

  begin
    v_requested_departure := (p_command -> 'payload' ->> 'departureAt')::timestamptz;
    v_routed_departure := (p_command -> 'payload' -> 'routePlan' ->> 'departureAt')::timestamptz;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE',
      'message', 'A valid requested departure and matching server route are required before approval.'));
  end;

  if v_requested_departure is null
     or v_routed_departure is null
     or v_requested_departure is distinct from v_routed_departure then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE',
      'message', 'The approved route must match the requested Round departure.'));
  end if;

  return public.plan_and_approve_round_without_departure_guard(p_command, p_actor_person_id);
end;
$$;

revoke all on function public.plan_and_approve_round_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.plan_and_approve_round_command(jsonb, uuid) to service_role;

comment on function public.plan_and_approve_round_command(jsonb, uuid) is
  'Manual Team Round approval guarded by matching requested and server-routed departure time, fresh route evidence, and server-recalculated multidimensional capacity.';
