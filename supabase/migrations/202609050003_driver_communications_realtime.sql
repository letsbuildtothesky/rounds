-- Private, hint-only Realtime delivery for the canonical Driver H01 thread.
-- Durable thread state remains API/database truth.

create or replace function public.can_receive_driver_communications_broadcast(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.auth_identities identity
      join public.driver_profiles driver
        on driver.person_id = identity.person_id
      join public.tenant_memberships membership
        on membership.person_id = driver.person_id
       and membership.role = 'team_driver'
       and membership.status = 'active'
      join public.driver_tenant_relationships relationship
        on relationship.tenant_id = membership.tenant_id
       and relationship.driver_id = driver.id
       and relationship.relationship_kind = 'team'
       and relationship.status = 'active'
       and relationship.deleted_at is null
     where identity.auth_user_id = (select auth.uid())
       and driver.active = true
       and driver.deleted_at is null
       and p_topic = 'driver:' || driver.id::text
  );
$$;

revoke all on function public.can_receive_driver_communications_broadcast(text) from public, anon;
grant execute on function public.can_receive_driver_communications_broadcast(text) to authenticated;

drop policy if exists driver_communications_receive_broadcast on realtime.messages;
create policy driver_communications_receive_broadcast
  on realtime.messages
  for select
  to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and public.can_receive_driver_communications_broadcast((select realtime.topic()))
  );

create or replace function public.broadcast_operations_communications_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payload jsonb;
begin
  if tg_op = 'INSERT' or new.version is distinct from old.version then
    v_payload := jsonb_build_object(
      'schemaVersion', 1,
      'event', 'communications.changed',
      'tenantId', new.tenant_id,
      'driverId', new.driver_id,
      'aggregateType', 'operations_thread',
      'aggregateId', new.id,
      'aggregateVersion', new.version,
      'occurredAt', new.updated_at
    );

    perform realtime.send(
      v_payload,
      'communications.changed',
      'tenant:' || new.tenant_id::text || ':dispatch',
      true
    );
    perform realtime.send(
      v_payload,
      'communications.changed',
      'driver:' || new.driver_id::text,
      true
    );
  end if;
  return new;
end;
$$;

revoke all on function public.broadcast_operations_communications_change() from public, anon, authenticated;

comment on function public.can_receive_driver_communications_broadcast(text) is
  'Authorizes an authenticated active Team driver for exactly their private Driver Broadcast topic.';
comment on function public.broadcast_operations_communications_change() is
  'Emits private Operations and Driver communications.changed hints without message or media content.';
