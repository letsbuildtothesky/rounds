-- Private, hint-only Realtime delivery for the canonical Operations
-- communications store. Durable thread state remains API/database truth.

create or replace function public.can_receive_operations_dispatch_broadcast(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.auth_identities identity
      join public.tenant_memberships membership
        on membership.person_id = identity.person_id
     where identity.auth_user_id = (select auth.uid())
       and membership.status = 'active'
       and membership.role in ('tenant_owner', 'operations_admin', 'dispatcher', 'viewer')
       and p_topic = 'tenant:' || membership.tenant_id::text || ':dispatch'
  );
$$;

revoke all on function public.can_receive_operations_dispatch_broadcast(text) from public, anon;
grant execute on function public.can_receive_operations_dispatch_broadcast(text) to authenticated;

drop policy if exists operations_dispatch_receive_broadcast on realtime.messages;
create policy operations_dispatch_receive_broadcast
  on realtime.messages
  for select
  to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and public.can_receive_operations_dispatch_broadcast((select realtime.topic()))
  );

create or replace function public.broadcast_operations_communications_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.version is distinct from old.version then
    perform realtime.send(
      jsonb_build_object(
        'schemaVersion', 1,
        'event', 'communications.changed',
        'tenantId', new.tenant_id,
        'aggregateType', 'operations_thread',
        'aggregateId', new.id,
        'aggregateVersion', new.version,
        'occurredAt', new.updated_at
      ),
      'communications.changed',
      'tenant:' || new.tenant_id::text || ':dispatch',
      true
    );
  end if;
  return new;
end;
$$;

revoke all on function public.broadcast_operations_communications_change() from public, anon, authenticated;

drop trigger if exists operations_communications_realtime on public.operations_threads;
create trigger operations_communications_realtime
after insert or update of version on public.operations_threads
for each row execute function public.broadcast_operations_communications_change();

comment on function public.can_receive_operations_dispatch_broadcast(text) is
  'Authorizes an authenticated active Operations member for exactly their tenant Dispatch Broadcast topic.';
comment on function public.broadcast_operations_communications_change() is
  'Emits a private versioned communications.changed hint without message or media content.';
