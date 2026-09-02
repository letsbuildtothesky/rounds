-- Close the Round when a confirmed physical return resolves its final open
-- Stop. The original v1 command remains the single authority for custody,
-- exception and delivery truth; this wrapper adds canonical Round completion.

alter function public.confirm_delivery_return_command(jsonb, uuid)
  rename to confirm_delivery_return_command_v1;

revoke all on function public.confirm_delivery_return_command_v1(jsonb, uuid)
  from public, anon, authenticated;

create function public.confirm_delivery_return_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_result jsonb;
  v_tenant_id uuid;
  v_round_id uuid;
  v_round_version bigint;
  v_round_state public.round_state;
begin
  v_result := public.confirm_delivery_return_command_v1(
    p_command,
    p_actor_person_id
  );
  if v_result ->> 'status' <> 'committed' then
    return v_result;
  end if;

  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_round_id := (v_result -> 'state' ->> 'roundId')::uuid;
  exception when others then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object(
        'code', 'INTERNAL_ERROR',
        'message', 'Committed return did not contain valid Round truth'
      )
    );
  end;

  if not exists (
    select 1
      from public.round_stops assigned
      join public.delivery_stops stop on stop.id = assigned.stop_id
     where assigned.round_id = v_round_id
       and stop.state not in ('completed', 'cancelled')
  ) then
    update public.rounds
       set state = 'complete', version = version + 1, updated_at = now()
     where id = v_round_id
       and tenant_id = v_tenant_id
       and state = 'active'
    returning version, state into v_round_version, v_round_state;
  end if;

  if v_round_state is null then
    select version, state into v_round_version, v_round_state
      from public.rounds
     where id = v_round_id and tenant_id = v_tenant_id;
  end if;

  if v_round_state is null then
    raise exception 'confirmed return Round is unavailable';
  end if;

  update public.audit_events
     set semantic_change = semantic_change || jsonb_build_object(
       'roundState', v_round_state,
       'roundVersion', v_round_version
     )
   where tenant_id = v_tenant_id
     and command_id = (p_command ->> 'commandId')::uuid
     and action = 'operations.delivery_return_confirmed';

  v_result := jsonb_set(
    jsonb_set(
      v_result,
      '{state,roundState}',
      to_jsonb(v_round_state),
      true
    ),
    '{state,roundVersion}',
    to_jsonb(v_round_version),
    true
  );
  return v_result;
end;
$$;

revoke all on function public.confirm_delivery_return_command(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.confirm_delivery_return_command(jsonb, uuid)
  to service_role;

comment on function public.confirm_delivery_return_command(jsonb, uuid) is
  'Server-only audited return confirmation with canonical terminal Round reconciliation.';
