-- Slice 2 / Operations v45: secure rich media authored by tenant Operations.
-- Browser drafts remain local; only integrity-verified private media may be
-- committed into the shared Team-driver thread.

drop index if exists public.communication_media_active_content_idx;
create unique index communication_media_active_content_idx
  on public.communication_media_assets (thread_id, uploader_person_id, kind, expected_sha256, expected_size)
  where state in ('staged', 'uploaded_uncommitted');

create or replace function public.prepare_operations_message_media_asset(
  p_thread_id uuid,
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
    or (p_kind = 'voice' and (p_content_type not in ('audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/wav', 'audio/webm', 'audio/ogg')
      or p_duration_milliseconds not between 250 and 600000))
    or (p_kind <> 'voice' and p_duration_milliseconds is not null) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Message attachment metadata is invalid'));
  end if;

  select thread.* into v_thread
    from public.operations_threads thread
    join public.rounds round_record
      on round_record.tenant_id = thread.tenant_id and round_record.id = thread.round_id
    join public.driver_tenant_relationships relationship
      on relationship.driver_id = thread.driver_id and relationship.tenant_id = thread.tenant_id
    join public.tenant_memberships membership
      on membership.tenant_id = thread.tenant_id and membership.person_id = p_actor_person_id
   where thread.id = p_thread_id
     and membership.status = 'active'
     and membership.role in ('tenant_owner', 'operations_admin', 'dispatcher')
     and relationship.relationship_kind = 'team' and relationship.status = 'active'
     and relationship.deleted_at is null
     and round_record.state in ('approved', 'loading', 'active') and round_record.deleted_at is null
   limit 1;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Operations media is not permitted for this thread'));
  end if;

  select * into v_existing from public.communication_media_assets
   where thread_id = v_thread.id and uploader_person_id = p_actor_person_id
     and kind = p_kind and expected_sha256 = p_sha256 and expected_size = p_size
     and state in ('staged', 'uploaded_uncommitted')
   limit 1;
  if found then
    return jsonb_build_object(
      'status', 'prepared', 'mediaAssetId', v_existing.id,
      'bucket', v_existing.storage_bucket, 'path', v_existing.storage_path,
      'assetState', v_existing.state, 'deduplicated', true);
  end if;

  v_path := v_thread.tenant_id::text || '/' || v_thread.id::text || '/' || p_asset_id::text;
  insert into public.communication_media_assets (
    id, tenant_id, thread_id, round_id, stop_id, driver_id, uploader_person_id,
    kind, file_name, content_type, duration_milliseconds, storage_path,
    expected_sha256, expected_size
  ) values (
    p_asset_id, v_thread.tenant_id, v_thread.id, v_thread.round_id, v_thread.stop_id,
    v_thread.driver_id, p_actor_person_id, p_kind, btrim(p_file_name), btrim(p_content_type),
    p_duration_milliseconds, v_path, p_sha256, p_size
  );
  return jsonb_build_object(
    'status', 'prepared', 'mediaAssetId', p_asset_id,
    'bucket', 'communication-media', 'path', v_path, 'assetState', 'staged');
exception when unique_violation then
  select * into v_existing from public.communication_media_assets
   where thread_id = v_thread.id and uploader_person_id = p_actor_person_id
     and kind = p_kind and expected_sha256 = p_sha256 and expected_size = p_size
     and state in ('staged', 'uploaded_uncommitted')
   limit 1;
  if found then
    return jsonb_build_object(
      'status', 'prepared', 'mediaAssetId', v_existing.id,
      'bucket', v_existing.storage_bucket, 'path', v_existing.storage_path,
      'assetState', v_existing.state, 'deduplicated', true);
  end if;
  raise;
end;
$$;

create or replace function public.mark_operations_message_media_uploaded(
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
  select asset.* into v_asset
    from public.communication_media_assets asset
    join public.tenant_memberships membership
      on membership.tenant_id = asset.tenant_id and membership.person_id = p_actor_person_id
   where asset.id = p_asset_id and asset.uploader_person_id = p_actor_person_id
     and membership.status = 'active'
     and membership.role in ('tenant_owner', 'operations_admin', 'dispatcher')
   for update of asset;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Message attachment is not owned by this Operations user'));
  end if;
  if v_asset.state in ('committed', 'uploaded_uncommitted') then
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

revoke all on function public.prepare_operations_message_media_asset(uuid, uuid, uuid, text, text, text, bigint, text, integer) from public, anon, authenticated;
revoke all on function public.mark_operations_message_media_uploaded(uuid, uuid, text, bigint) from public, anon, authenticated;
grant execute on function public.prepare_operations_message_media_asset(uuid, uuid, uuid, text, text, text, bigint, text, integer) to service_role;
grant execute on function public.mark_operations_message_media_uploaded(uuid, uuid, text, bigint) to service_role;

create or replace function public.send_operations_message_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'thread.send_operations_message';
  v_tenant_id uuid; v_thread_id uuid; v_command_id uuid; v_trace_id uuid;
  v_expected_version bigint; v_occurred_from_device_at timestamptz;
  v_idempotency_key text; v_payload jsonb; v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_thread public.operations_threads%rowtype;
  v_actor_role public.tenant_role; v_body text; v_attachments jsonb;
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

  select membership.role into v_actor_role
    from public.tenant_memberships membership
   where membership.tenant_id = v_tenant_id and membership.person_id = p_actor_person_id
     and membership.status = 'active'
     and membership.role in ('tenant_owner', 'operations_admin', 'dispatcher')
   limit 1;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Operations reply is not permitted for this thread'));
  end if;

  select thread.* into v_thread
    from public.operations_threads thread
    join public.rounds round_record
      on round_record.tenant_id = thread.tenant_id and round_record.id = thread.round_id
    join public.driver_tenant_relationships relationship
      on relationship.driver_id = thread.driver_id and relationship.tenant_id = thread.tenant_id
   where thread.id = v_thread_id and thread.tenant_id = v_tenant_id
     and relationship.relationship_kind = 'team' and relationship.status = 'active'
     and relationship.deleted_at is null
     and round_record.state in ('approved', 'loading', 'active') and round_record.deleted_at is null
   for update of thread;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Operations reply is not permitted for this thread'));
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
    v_message_id, v_tenant_id, v_thread_id, 'operations', p_actor_person_id, v_body, v_attachments,
    v_occurred_from_device_at, v_occurred_at, v_command_id
  );
  update public.communication_media_assets set state = 'committed', committed_at = v_occurred_at
   where id in (select (attachment ->> 'mediaAssetId')::uuid from jsonb_array_elements(v_attachments) attachment
     where attachment ->> 'kind' in ('image', 'file', 'voice'));
  update public.operations_threads set version = version + 1, updated_at = v_occurred_at
   where id = v_thread_id returning version into v_thread_version;

  v_message := jsonb_build_object('id', v_message_id, 'sender', 'operations', 'body', v_body,
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
    v_tenant_id, p_actor_person_id, v_actor_role, 'thread.message_sent', 'operations_thread',
    v_thread_id, v_thread_version, v_command_id, v_trace_id,
    jsonb_build_object('messageId', v_message_id, 'sender', 'operations',
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

comment on function public.prepare_operations_message_media_asset(uuid, uuid, uuid, text, text, text, bigint, text, integer) is
  'Authorizes and stages private v45 Dispatch message media for an active Team-driver thread.';
comment on function public.send_operations_message_command(jsonb, uuid) is
  'Server-only versioned/idempotent Operations rich-message command; commits verified media atomically.';
