-- Slice 2 / H01: private, integrity-verified rich message media. Final
-- production expiry is intentionally policy-pending; uncommitted uploads still
-- expire after 24 hours and committed assets remain tenant/assignment scoped.

insert into storage.buckets (id, name, public, file_size_limit)
values ('communication-media', 'communication-media', false, 15728640)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;

create table public.communication_media_assets (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  thread_id uuid not null,
  round_id uuid not null,
  stop_id uuid not null,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  uploader_person_id uuid not null references public.persons(id) on delete restrict,
  kind text not null check (kind in ('image', 'file', 'voice')),
  file_name text not null check (length(btrim(file_name)) between 1 and 240),
  content_type text not null check (length(btrim(content_type)) between 1 and 120),
  duration_milliseconds integer check (
    (kind = 'voice' and duration_milliseconds between 250 and 600000)
    or (kind <> 'voice' and duration_milliseconds is null)
  ),
  storage_bucket text not null default 'communication-media' check (storage_bucket = 'communication-media'),
  storage_path text not null unique,
  expected_sha256 text not null check (expected_sha256 ~ '^[0-9a-f]{64}$'),
  verified_sha256 text check (verified_sha256 is null or verified_sha256 ~ '^[0-9a-f]{64}$'),
  expected_size bigint not null check (expected_size between 1 and 15728640),
  verified_size bigint check (verified_size is null or verified_size > 0),
  state public.media_asset_state not null default 'staged',
  retention_class text not null default 'communications_policy_pending'
    check (retention_class = 'communications_policy_pending'),
  staged_at timestamptz not null default now(),
  uploaded_at timestamptz,
  committed_at timestamptz,
  staging_expires_at timestamptz not null default (now() + interval '24 hours'),
  retention_expires_at timestamptz,
  unique (tenant_id, id),
  foreign key (tenant_id, thread_id) references public.operations_threads(tenant_id, id) on delete restrict,
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id) references public.delivery_stops(tenant_id, id) on delete restrict,
  check ((state in ('uploaded_uncommitted', 'committed')) = (uploaded_at is not null)),
  check ((state = 'committed') = (committed_at is not null)),
  check ((uploaded_at is null) = (verified_sha256 is null)),
  check ((uploaded_at is null) = (verified_size is null))
);

create index communication_media_staging_expiry_idx
  on public.communication_media_assets (state, staging_expires_at);
create unique index communication_media_active_content_idx
  on public.communication_media_assets (thread_id, kind, expected_sha256, expected_size)
  where state in ('staged', 'uploaded_uncommitted');
alter table public.communication_media_assets enable row level security;
revoke all on table public.communication_media_assets from anon, authenticated;
grant select on table public.communication_media_assets to service_role;

create or replace function public.can_access_communication_object(
  p_bucket text,
  p_path text,
  p_require_staged boolean
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select p_bucket = 'communication-media' and exists (
    select 1
      from public.communication_media_assets asset
      join public.auth_identities identity on identity.person_id = asset.uploader_person_id
     where asset.storage_bucket = p_bucket
       and asset.storage_path = p_path
       and ((p_require_staged and asset.state = 'staged')
         or (not p_require_staged and asset.state in ('staged', 'uploaded_uncommitted', 'committed')))
       and identity.auth_user_id = (select auth.uid())
  );
$$;

revoke all on function public.can_access_communication_object(text, text, boolean) from public, anon;
grant execute on function public.can_access_communication_object(text, text, boolean) to authenticated;

create policy communication_media_driver_select_exact_object
on storage.objects for select to authenticated
using (public.can_access_communication_object(bucket_id, name, false));

create policy communication_media_driver_insert_exact_staged_object
on storage.objects for insert to authenticated
with check (public.can_access_communication_object(bucket_id, name, true));

create policy communication_media_driver_update_exact_staged_object
on storage.objects for update to authenticated
using (public.can_access_communication_object(bucket_id, name, true))
with check (public.can_access_communication_object(bucket_id, name, true));

create or replace function public.prepare_driver_message_media_asset(
  p_round_id uuid,
  p_stop_id uuid,
  p_actor_person_id uuid,
  p_asset_id uuid,
  p_kind text,
  p_file_name text,
  p_content_type text,
  p_size bigint,
  p_sha256 text,
  p_duration_milliseconds integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_thread public.operations_threads%rowtype;
  v_existing public.communication_media_assets%rowtype;
  v_path text;
begin
  if p_kind not in ('image', 'file', 'voice')
    or length(btrim(coalesce(p_file_name, ''))) not between 1 and 240
    or length(btrim(coalesce(p_content_type, ''))) not between 1 and 120
    or p_size not between 1 and 15728640
    or p_sha256 !~ '^[0-9a-f]{64}$'
    or (p_kind = 'image' and p_content_type not in ('image/jpeg', 'image/png', 'image/webp'))
    or (p_kind = 'voice' and (p_content_type not in ('audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/wav')
      or p_duration_milliseconds not between 250 and 600000))
    or (p_kind <> 'voice' and p_duration_milliseconds is not null) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Message attachment metadata is invalid'));
  end if;

  select thread.* into v_thread
    from public.operations_threads thread
    join public.rounds round_record
      on round_record.tenant_id = thread.tenant_id and round_record.id = thread.round_id
    join public.driver_profiles driver on driver.id = thread.driver_id
    join public.driver_tenant_relationships relationship
      on relationship.driver_id = driver.id and relationship.tenant_id = thread.tenant_id
    join public.tenant_memberships membership
      on membership.tenant_id = thread.tenant_id and membership.person_id = p_actor_person_id
   where thread.round_id = p_round_id and thread.stop_id = p_stop_id
     and driver.person_id = p_actor_person_id and driver.active = true and driver.deleted_at is null
     and relationship.relationship_kind = 'team' and relationship.status = 'active'
     and relationship.deleted_at is null
     and membership.status = 'active' and membership.role = 'team_driver'
     and round_record.state in ('approved', 'loading', 'active') and round_record.deleted_at is null
   limit 1;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Operations thread is not assigned to this Team driver'));
  end if;

  select * into v_existing from public.communication_media_assets
   where thread_id = v_thread.id and kind = p_kind and expected_sha256 = p_sha256
     and expected_size = p_size and state in ('staged', 'uploaded_uncommitted')
   limit 1;
  if found then
    return jsonb_build_object(
      'status', 'prepared', 'mediaAssetId', v_existing.id,
      'bucket', v_existing.storage_bucket, 'path', v_existing.storage_path,
      'assetState', v_existing.state, 'deduplicated', true);
  end if;

  v_path := v_thread.tenant_id::text || '/' || v_thread.id::text || '/' || p_asset_id::text;
  begin
    insert into public.communication_media_assets (
      id, tenant_id, thread_id, round_id, stop_id, driver_id, uploader_person_id,
      kind, file_name, content_type, duration_milliseconds, storage_path,
      expected_sha256, expected_size
    ) values (
      p_asset_id, v_thread.tenant_id, v_thread.id, v_thread.round_id, v_thread.stop_id,
      v_thread.driver_id, p_actor_person_id, p_kind, btrim(p_file_name), btrim(p_content_type),
      p_duration_milliseconds, v_path, p_sha256, p_size
    );
  exception when unique_violation then
    select * into v_existing from public.communication_media_assets
     where thread_id = v_thread.id and kind = p_kind and expected_sha256 = p_sha256
       and expected_size = p_size and state in ('staged', 'uploaded_uncommitted')
     limit 1;
    if found then
      return jsonb_build_object(
        'status', 'prepared', 'mediaAssetId', v_existing.id,
        'bucket', v_existing.storage_bucket, 'path', v_existing.storage_path,
        'assetState', v_existing.state, 'deduplicated', true);
    end if;
    raise;
  end;
  return jsonb_build_object(
    'status', 'prepared', 'mediaAssetId', p_asset_id,
    'bucket', 'communication-media', 'path', v_path, 'assetState', 'staged');
end;
$$;

create or replace function public.mark_driver_message_media_uploaded(
  p_asset_id uuid,
  p_actor_person_id uuid,
  p_verified_sha256 text,
  p_verified_size bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_asset public.communication_media_assets%rowtype;
begin
  select * into v_asset from public.communication_media_assets
   where id = p_asset_id and uploader_person_id = p_actor_person_id for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Message attachment is not owned by this driver'));
  end if;
  if v_asset.state = 'committed' or v_asset.state = 'uploaded_uncommitted' then
    return jsonb_build_object('status', 'verified', 'mediaAssetId', v_asset.id, 'assetState', v_asset.state);
  end if;
  if p_verified_sha256 <> v_asset.expected_sha256 or p_verified_size <> v_asset.expected_size then
    update public.communication_media_assets set state = 'quarantined' where id = p_asset_id;
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'EVIDENCE_REQUIRED', 'message', 'Uploaded message attachment failed integrity verification'));
  end if;
  update public.communication_media_assets set
    state = 'uploaded_uncommitted', verified_sha256 = p_verified_sha256,
    verified_size = p_verified_size, uploaded_at = now()
   where id = p_asset_id;
  return jsonb_build_object('status', 'verified', 'mediaAssetId', v_asset.id, 'assetState', 'uploaded_uncommitted');
end;
$$;

revoke all on function public.prepare_driver_message_media_asset(uuid, uuid, uuid, uuid, text, text, text, bigint, text, integer) from public, anon, authenticated;
revoke all on function public.mark_driver_message_media_uploaded(uuid, uuid, text, bigint) from public, anon, authenticated;
grant execute on function public.prepare_driver_message_media_asset(uuid, uuid, uuid, uuid, text, text, text, bigint, text, integer) to service_role;
grant execute on function public.mark_driver_message_media_uploaded(uuid, uuid, text, bigint) to service_role;

create or replace function public.send_driver_message_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'thread.send_message';
  v_tenant_id uuid; v_thread_id uuid; v_command_id uuid; v_trace_id uuid;
  v_expected_version bigint; v_occurred_from_device_at timestamptz;
  v_idempotency_key text; v_payload jsonb; v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_thread public.operations_threads%rowtype;
  v_body text; v_attachments jsonb;
  v_message_id uuid := gen_random_uuid(); v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now(); v_thread_version bigint;
  v_message jsonb; v_event jsonb; v_state jsonb; v_result jsonb;
begin
  if p_command is null or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
    or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_thread_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_occurred_from_device_at := nullif(p_command ->> 'occurredFromDeviceAt', '')::timestamptz;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Message identifiers or version are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  v_body := btrim(coalesce(v_payload ->> 'body', ''));
  v_attachments := coalesce(v_payload -> 'attachments', '[]'::jsonb);
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
    or length(v_body) > 2000 or jsonb_typeof(v_attachments) <> 'array'
    or jsonb_array_length(v_attachments) > 8
    or (v_body = '' and jsonb_array_length(v_attachments) = 0)
    or exists (
      select 1 from jsonb_array_elements(v_attachments) attachment
      where not (
        (attachment ->> 'kind' = 'location'
          and length(btrim(coalesce(attachment ->> 'label', ''))) between 1 and 120
          and jsonb_typeof(attachment -> 'latitude') = 'number'
          and (attachment ->> 'latitude')::numeric between -90 and 90
          and jsonb_typeof(attachment -> 'longitude') = 'number'
          and (attachment ->> 'longitude')::numeric between -180 and 180
          and (not attachment ? 'accuracyMeters' or (jsonb_typeof(attachment -> 'accuracyMeters') = 'number'
            and (attachment ->> 'accuracyMeters')::numeric >= 0))
          and coalesce(attachment ->> 'capturedAt', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T')
        or
        (attachment ->> 'kind' in ('image', 'file', 'voice')
          and coalesce(attachment ->> 'mediaAssetId', '') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
          and length(btrim(coalesce(attachment ->> 'fileName', ''))) between 1 and 240
          and length(btrim(coalesce(attachment ->> 'contentType', ''))) between 1 and 120
          and jsonb_typeof(attachment -> 'byteSize') = 'number'
          and (attachment ->> 'byteSize')::bigint between 1 and 15728640
          and ((attachment ->> 'kind' = 'voice' and jsonb_typeof(attachment -> 'durationMilliseconds') = 'number'
            and (attachment ->> 'durationMilliseconds')::integer between 250 and 600000)
            or (attachment ->> 'kind' <> 'voice' and not attachment ? 'durationMilliseconds')))
      )
    ) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Message payload is invalid'));
  end if;

  v_payload_hash := encode(digest(v_payload::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key, 0));
  select * into v_existing from public.command_idempotency
   where tenant_id = v_tenant_id and command_type = v_command_type and idempotency_key = v_idempotency_key;
  if found then
    if v_existing.payload_hash <> v_payload_hash then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'IDEMPOTENCY_CONFLICT', 'message', 'Idempotency key was already used with different payload'));
    end if;
    return v_existing.result || jsonb_build_object('deduplicated', true);
  end if;

  select thread.* into v_thread
    from public.operations_threads thread
    join public.rounds round_record on round_record.tenant_id = thread.tenant_id and round_record.id = thread.round_id
    join public.driver_profiles driver on driver.id = thread.driver_id
    join public.driver_tenant_relationships relationship on relationship.driver_id = driver.id and relationship.tenant_id = thread.tenant_id
    join public.tenant_memberships membership on membership.tenant_id = thread.tenant_id and membership.person_id = p_actor_person_id
   where thread.id = v_thread_id and thread.tenant_id = v_tenant_id
     and driver.person_id = p_actor_person_id and driver.active = true and driver.deleted_at is null
     and relationship.relationship_kind = 'team' and relationship.status = 'active' and relationship.deleted_at is null
     and membership.status = 'active' and membership.role = 'team_driver'
     and round_record.state in ('approved', 'loading', 'active') and round_record.deleted_at is null
   for update of thread;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Operations thread is not assigned to this Team driver'));
  end if;
  if v_thread.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Thread changed; refresh before sending another message'));
  end if;
  if exists (
    select 1 from jsonb_array_elements(v_attachments) attachment
     where attachment ->> 'kind' in ('image', 'file', 'voice') and not exists (
       select 1 from public.communication_media_assets asset
        where asset.id = (attachment ->> 'mediaAssetId')::uuid
          and asset.tenant_id = v_tenant_id and asset.thread_id = v_thread_id
          and asset.driver_id = v_thread.driver_id and asset.uploader_person_id = p_actor_person_id
          and asset.state = 'uploaded_uncommitted' and asset.kind = attachment ->> 'kind'
          and asset.file_name = btrim(attachment ->> 'fileName')
          and asset.content_type = btrim(attachment ->> 'contentType')
          and asset.expected_size = (attachment ->> 'byteSize')::bigint
          and coalesce(asset.duration_milliseconds, -1) = coalesce((attachment ->> 'durationMilliseconds')::integer, -1)
     )
  ) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'EVIDENCE_REQUIRED', 'message', 'Every message attachment must finish uploading before send'));
  end if;

  insert into public.operations_messages (
    id, tenant_id, thread_id, sender, sender_person_id, body, attachments,
    occurred_from_device_at, sent_at, command_id
  ) values (
    v_message_id, v_tenant_id, v_thread_id, 'driver', p_actor_person_id, v_body, v_attachments,
    v_occurred_from_device_at, v_occurred_at, v_command_id
  );
  update public.communication_media_assets set state = 'committed', committed_at = v_occurred_at
   where id in (select (attachment ->> 'mediaAssetId')::uuid from jsonb_array_elements(v_attachments) attachment
     where attachment ->> 'kind' in ('image', 'file', 'voice'));
  update public.operations_threads set version = version + 1, updated_at = v_occurred_at
   where id = v_thread_id returning version into v_thread_version;

  v_message := jsonb_build_object('id', v_message_id, 'sender', 'driver', 'body', v_body,
    'attachments', v_attachments, 'sentAt', v_occurred_at);
  v_state := jsonb_build_object('threadId', v_thread_id, 'message', v_message);
  v_event := jsonb_build_object('event', 'thread.message_sent', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'operations_thread',
    'aggregateId', v_thread_id, 'aggregateVersion', v_thread_version, 'occurredAt', v_occurred_at,
    'payload', v_state);
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, 'team_driver', 'thread.message_sent', 'operations_thread',
    v_thread_id, v_thread_version, v_command_id, v_trace_id,
    jsonb_build_object('messageId', v_message_id, 'sender', 'driver',
      'attachmentKinds', (select coalesce(jsonb_agg(attachment ->> 'kind'), '[]'::jsonb)
        from jsonb_array_elements(v_attachments) attachment)));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'thread.message_sent', 1, 'operations_thread', v_thread_id,
    v_thread_version, v_trace_id, v_event, v_occurred_at);
  v_result := jsonb_build_object('status', 'committed', 'aggregateVersion', v_thread_version,
    'state', v_state, 'events', jsonb_build_array(v_event));
  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_thread_id,
    v_payload_hash, 'committed', v_result, v_trace_id, p_actor_person_id);
  return v_result;
end;
$$;

comment on table public.communication_media_assets is
  'Private H01 image/file/voice bytes. Committed retention expiry remains policy-pending and must be locked before production.';
comment on column public.operations_messages.attachments is
  'Structured location or verified private media references for the shared Operations thread.';
