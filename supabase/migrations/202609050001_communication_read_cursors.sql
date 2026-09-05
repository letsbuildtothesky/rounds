-- Slice 2 / SPEC-6 + Driver H01: one durable read cursor per person and
-- communication thread. Read state is private metadata; it does not advance
-- the operational thread aggregate version or create domain events.

create table public.communication_thread_read_cursors (
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  thread_id uuid not null,
  reader_person_id uuid not null references public.persons(id) on delete restrict,
  last_read_message_id uuid not null,
  last_read_sent_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (tenant_id, thread_id, reader_person_id),
  foreign key (tenant_id, thread_id)
    references public.operations_threads(tenant_id, id) on delete cascade,
  foreign key (tenant_id, last_read_message_id)
    references public.operations_messages(tenant_id, id) on delete restrict
);

create index communication_thread_read_cursors_reader_idx
  on public.communication_thread_read_cursors (tenant_id, reader_person_id, thread_id);

alter table public.communication_thread_read_cursors enable row level security;
revoke all on table public.communication_thread_read_cursors from anon, authenticated;
grant select, insert, update on table public.communication_thread_read_cursors to service_role;

create or replace function public.mark_operations_thread_read(
  p_thread_id uuid,
  p_last_read_message_id uuid,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_target_sent_at timestamptz;
  v_cursor public.communication_thread_read_cursors%rowtype;
  v_unread_count integer;
  v_first_unread_message_id uuid;
  v_has_unread_voice boolean;
begin
  select thread.tenant_id, message.sent_at
    into v_tenant_id, v_target_sent_at
    from public.operations_threads thread
    join public.operations_messages message
      on message.tenant_id = thread.tenant_id
     and message.thread_id = thread.id
     and message.id = p_last_read_message_id
    join public.tenant_memberships membership
      on membership.tenant_id = thread.tenant_id
     and membership.person_id = p_actor_person_id
   where thread.id = p_thread_id
     and membership.status = 'active'
     and membership.role in ('tenant_owner', 'operations_admin', 'dispatcher', 'viewer')
   limit 1;
  if v_tenant_id is null then return null; end if;

  insert into public.communication_thread_read_cursors (
    tenant_id, thread_id, reader_person_id,
    last_read_message_id, last_read_sent_at, updated_at
  ) values (
    v_tenant_id, p_thread_id, p_actor_person_id,
    p_last_read_message_id, v_target_sent_at, now()
  )
  on conflict (tenant_id, thread_id, reader_person_id) do update
    set last_read_message_id = excluded.last_read_message_id,
        last_read_sent_at = excluded.last_read_sent_at,
        updated_at = excluded.updated_at
    where (excluded.last_read_sent_at, excluded.last_read_message_id)
        > (public.communication_thread_read_cursors.last_read_sent_at,
           public.communication_thread_read_cursors.last_read_message_id);

  select * into v_cursor
    from public.communication_thread_read_cursors
   where tenant_id = v_tenant_id
     and thread_id = p_thread_id
     and reader_person_id = p_actor_person_id;

  select count(*)::integer,
         (array_agg(message.id order by message.sent_at, message.id))[1],
         coalesce(bool_or(exists (
           select 1 from jsonb_array_elements(coalesce(message.attachments, '[]'::jsonb)) attachment
            where attachment ->> 'kind' = 'voice'
         )), false)
    into v_unread_count, v_first_unread_message_id, v_has_unread_voice
    from public.operations_messages message
   where message.tenant_id = v_tenant_id
     and message.thread_id = p_thread_id
     and message.sender = 'driver'
     and (message.sent_at, message.id) > (v_cursor.last_read_sent_at, v_cursor.last_read_message_id);

  return jsonb_strip_nulls(jsonb_build_object(
    'threadId', p_thread_id,
    'lastReadMessageId', v_cursor.last_read_message_id,
    'unreadCount', v_unread_count,
    'firstUnreadMessageId', v_first_unread_message_id,
    'hasUnreadVoice', v_has_unread_voice
  ));
end;
$$;

create or replace function public.mark_driver_operations_thread_read(
  p_round_id uuid,
  p_stop_id uuid,
  p_last_read_message_id uuid,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_thread_id uuid;
  v_target_sent_at timestamptz;
  v_cursor public.communication_thread_read_cursors%rowtype;
  v_unread_count integer;
  v_first_unread_message_id uuid;
  v_has_unread_voice boolean;
begin
  select thread.tenant_id, thread.id, message.sent_at
    into v_tenant_id, v_thread_id, v_target_sent_at
    from public.operations_threads thread
    join public.rounds round_record
      on round_record.tenant_id = thread.tenant_id and round_record.id = thread.round_id
    join public.round_stops assigned
      on assigned.tenant_id = thread.tenant_id
     and assigned.round_id = thread.round_id
     and assigned.stop_id = thread.stop_id
    join public.driver_profiles driver on driver.id = thread.driver_id
    join public.driver_tenant_relationships relationship
      on relationship.driver_id = driver.id and relationship.tenant_id = thread.tenant_id
    join public.tenant_memberships membership
      on membership.tenant_id = thread.tenant_id and membership.person_id = driver.person_id
    join public.operations_messages message
      on message.tenant_id = thread.tenant_id
     and message.thread_id = thread.id
     and message.id = p_last_read_message_id
   where thread.round_id = p_round_id and thread.stop_id = p_stop_id
     and driver.person_id = p_actor_person_id and driver.active = true and driver.deleted_at is null
     and relationship.relationship_kind = 'team' and relationship.status = 'active'
     and relationship.deleted_at is null
     and membership.status = 'active' and membership.role = 'team_driver'
     and round_record.state in ('approved', 'loading', 'active') and round_record.deleted_at is null
   limit 1;
  if v_thread_id is null then return null; end if;

  insert into public.communication_thread_read_cursors (
    tenant_id, thread_id, reader_person_id,
    last_read_message_id, last_read_sent_at, updated_at
  ) values (
    v_tenant_id, v_thread_id, p_actor_person_id,
    p_last_read_message_id, v_target_sent_at, now()
  )
  on conflict (tenant_id, thread_id, reader_person_id) do update
    set last_read_message_id = excluded.last_read_message_id,
        last_read_sent_at = excluded.last_read_sent_at,
        updated_at = excluded.updated_at
    where (excluded.last_read_sent_at, excluded.last_read_message_id)
        > (public.communication_thread_read_cursors.last_read_sent_at,
           public.communication_thread_read_cursors.last_read_message_id);

  select * into v_cursor
    from public.communication_thread_read_cursors
   where tenant_id = v_tenant_id
     and thread_id = v_thread_id
     and reader_person_id = p_actor_person_id;

  select count(*)::integer,
         (array_agg(message.id order by message.sent_at, message.id))[1],
         coalesce(bool_or(exists (
           select 1 from jsonb_array_elements(coalesce(message.attachments, '[]'::jsonb)) attachment
            where attachment ->> 'kind' = 'voice'
         )), false)
    into v_unread_count, v_first_unread_message_id, v_has_unread_voice
    from public.operations_messages message
   where message.tenant_id = v_tenant_id
     and message.thread_id = v_thread_id
     and message.sender = 'operations'
     and (message.sent_at, message.id) > (v_cursor.last_read_sent_at, v_cursor.last_read_message_id);

  return jsonb_strip_nulls(jsonb_build_object(
    'threadId', v_thread_id,
    'lastReadMessageId', v_cursor.last_read_message_id,
    'unreadCount', v_unread_count,
    'firstUnreadMessageId', v_first_unread_message_id,
    'hasUnreadVoice', v_has_unread_voice
  ));
end;
$$;

-- The Driver projection carries the unread boundary required by H01. This is
-- the existing assignment-guarded projection with read metadata added.
create or replace function public.ensure_driver_operations_thread(
  p_round_id uuid,
  p_stop_id uuid,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_tenant_id uuid;
  v_driver_id uuid;
  v_thread public.operations_threads%rowtype;
  v_cursor public.communication_thread_read_cursors%rowtype;
  v_messages jsonb;
  v_unread_count integer;
  v_first_unread_message_id uuid;
  v_has_unread_voice boolean;
begin
  select round_record.tenant_id, driver.id
    into v_tenant_id, v_driver_id
    from public.rounds round_record
    join public.round_stops assigned
      on assigned.tenant_id = round_record.tenant_id and assigned.round_id = round_record.id
    join public.delivery_stops stop
      on stop.tenant_id = assigned.tenant_id and stop.id = assigned.stop_id
    join public.driver_profiles driver on driver.id = round_record.driver_id
    join public.driver_tenant_relationships relationship
      on relationship.driver_id = driver.id and relationship.tenant_id = round_record.tenant_id
    join public.tenant_memberships membership
      on membership.tenant_id = round_record.tenant_id and membership.person_id = driver.person_id
   where round_record.id = p_round_id and assigned.stop_id = p_stop_id
     and driver.person_id = p_actor_person_id and driver.active = true and driver.deleted_at is null
     and relationship.relationship_kind = 'team' and relationship.status = 'active'
     and relationship.deleted_at is null
     and membership.status = 'active' and membership.role = 'team_driver'
     and round_record.state in ('approved', 'loading', 'active') and round_record.deleted_at is null
   limit 1;
  if v_driver_id is null then return null; end if;

  insert into public.operations_threads (tenant_id, round_id, stop_id, driver_id)
  values (v_tenant_id, p_round_id, p_stop_id, v_driver_id)
  on conflict (tenant_id, round_id, stop_id) do update
    set updated_at = public.operations_threads.updated_at
  returning * into v_thread;

  select * into v_cursor
    from public.communication_thread_read_cursors
   where tenant_id = v_tenant_id
     and thread_id = v_thread.id
     and reader_person_id = p_actor_person_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', message.id,
    'sender', message.sender,
    'body', message.body,
    'attachments', message.attachments,
    'sentAt', message.sent_at
  ) order by message.sent_at, message.id), '[]'::jsonb)
  into v_messages
  from public.operations_messages message
  where message.tenant_id = v_tenant_id and message.thread_id = v_thread.id;

  select count(*)::integer,
         (array_agg(message.id order by message.sent_at, message.id))[1],
         coalesce(bool_or(exists (
           select 1 from jsonb_array_elements(coalesce(message.attachments, '[]'::jsonb)) attachment
            where attachment ->> 'kind' = 'voice'
         )), false)
    into v_unread_count, v_first_unread_message_id, v_has_unread_voice
    from public.operations_messages message
   where message.tenant_id = v_tenant_id
     and message.thread_id = v_thread.id
     and message.sender = 'operations'
     and (v_cursor.thread_id is null
       or (message.sent_at, message.id) > (v_cursor.last_read_sent_at, v_cursor.last_read_message_id));

  return jsonb_strip_nulls(jsonb_build_object(
    'id', v_thread.id,
    'roundId', v_thread.round_id,
    'stopId', v_thread.stop_id,
    'version', v_thread.version,
    'unreadCount', v_unread_count,
    'firstUnreadMessageId', v_first_unread_message_id,
    'hasUnreadVoice', v_has_unread_voice,
    'lastReadMessageId', v_cursor.last_read_message_id,
    'messages', v_messages
  ));
end;
$$;

revoke all on function public.mark_operations_thread_read(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.mark_driver_operations_thread_read(uuid, uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.mark_operations_thread_read(uuid, uuid, uuid) to service_role;
grant execute on function public.mark_driver_operations_thread_read(uuid, uuid, uuid, uuid) to service_role;

comment on table public.communication_thread_read_cursors is
  'Private per-person communication read cursors. Monotonic and independent for every Operations user and Team driver.';
