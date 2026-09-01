-- Pilot/Slice 1: resumable proof-of-delivery evidence, exact handoff
-- verification, final custody transfer, Stop/Round completion and the durable
-- evidence source used by Operations History.

create type public.media_asset_state as enum (
  'staged',
  'uploaded_uncommitted',
  'committed',
  'quarantined',
  'purged'
);
create type public.pod_handoff_type as enum (
  'recipient',
  'someone_else',
  'left_at_location'
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pod-evidence',
  'pod-evidence',
  false,
  6291456,
  array['image/jpeg', 'image/png']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table public.media_assets (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  delivery_id uuid not null,
  stop_id uuid not null,
  round_id uuid not null,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  intent text not null check (intent = 'delivery_photo'),
  storage_bucket text not null default 'pod-evidence' check (storage_bucket = 'pod-evidence'),
  storage_path text not null unique,
  expected_sha256 text not null check (expected_sha256 ~ '^[0-9a-f]{64}$'),
  verified_sha256 text check (verified_sha256 is null or verified_sha256 ~ '^[0-9a-f]{64}$'),
  expected_size bigint not null check (expected_size between 1 and 6291456),
  verified_size bigint check (verified_size is null or verified_size > 0),
  content_type text not null check (content_type in ('image/jpeg', 'image/png')),
  state public.media_asset_state not null default 'staged',
  staged_at timestamptz not null default now(),
  uploaded_at timestamptz,
  committed_at timestamptz,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  unique (tenant_id, id),
  unique (stop_id, expected_sha256, expected_size),
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id) references public.delivery_stops(tenant_id, id) on delete restrict,
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict,
  check ((state in ('uploaded_uncommitted', 'committed')) = (uploaded_at is not null)),
  check ((state = 'committed') = (committed_at is not null)),
  check ((uploaded_at is null) = (verified_sha256 is null)),
  check ((uploaded_at is null) = (verified_size is null))
);

create table public.pod_records (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  delivery_id uuid not null,
  stop_id uuid not null,
  round_id uuid not null,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  manifest_id uuid not null,
  manifest_version bigint not null check (manifest_version > 0),
  manifest_verification_id uuid not null,
  media_asset_id uuid not null,
  handoff_type public.pod_handoff_type not null,
  receiver_name text check (receiver_name is null or length(btrim(receiver_name)) between 1 and 160),
  receiver_relationship text check (receiver_relationship is null or length(btrim(receiver_relationship)) between 1 and 120),
  left_at_location text check (left_at_location is null or length(btrim(left_at_location)) between 1 and 240),
  note text check (note is null or length(note) <= 500),
  position extensions.geography(point, 4326),
  accuracy_meters double precision check (accuracy_meters is null or accuracy_meters >= 0),
  location_source text check (location_source is null or location_source in ('google_nav', 'rounds_os', 'unknown')),
  occurred_from_device_at timestamptz,
  delivered_at timestamptz not null default now(),
  actor_person_id uuid not null references public.persons(id) on delete restrict,
  command_id uuid not null unique,
  unique (tenant_id, id),
  unique (stop_id),
  unique (media_asset_id),
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id) references public.delivery_stops(tenant_id, id) on delete restrict,
  foreign key (tenant_id, round_id) references public.rounds(tenant_id, id) on delete restrict,
  foreign key (tenant_id, manifest_id) references public.manifests(tenant_id, id) on delete restrict,
  foreign key (tenant_id, manifest_verification_id) references public.manifest_verifications(tenant_id, id) on delete restrict,
  foreign key (tenant_id, media_asset_id) references public.media_assets(tenant_id, id) on delete restrict,
  check ((position is null) = (accuracy_meters is null)),
  check ((position is null) = (location_source is null)),
  check (
    (handoff_type = 'recipient' and receiver_name is not null and receiver_relationship is null and left_at_location is null)
    or (handoff_type = 'someone_else' and receiver_name is not null and receiver_relationship is not null and left_at_location is null)
    or (handoff_type = 'left_at_location' and receiver_name is null and receiver_relationship is null and left_at_location is not null)
  )
);

create index media_assets_expiry_idx on public.media_assets (state, expires_at);
create index pod_records_history_idx on public.pod_records (tenant_id, delivered_at desc);

alter table public.media_assets enable row level security;
alter table public.pod_records enable row level security;
revoke all on table public.media_assets, public.pod_records from anon, authenticated;
grant select on table public.media_assets, public.pod_records to service_role;

create or replace function public.prepare_pod_media_asset(
  p_stop_id uuid,
  p_actor_person_id uuid,
  p_asset_id uuid,
  p_sha256 text,
  p_size bigint,
  p_content_type text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stop public.delivery_stops%rowtype;
  v_round public.rounds%rowtype;
  v_driver_id uuid;
  v_existing public.media_assets%rowtype;
  v_path text;
begin
  if p_sha256 !~ '^[0-9a-f]{64}$' or p_size not between 1 and 6291456
     or p_content_type not in ('image/jpeg', 'image/png') then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Photo metadata is invalid'));
  end if;
  select driver.id into v_driver_id
    from public.driver_profiles driver
    join public.tenant_memberships membership on membership.person_id = driver.person_id
    join public.driver_tenant_relationships relationship
      on relationship.driver_id = driver.id and relationship.tenant_id = membership.tenant_id
   where driver.person_id = p_actor_person_id and driver.active = true and driver.deleted_at is null
     and membership.role = 'team_driver' and membership.status = 'active'
     and relationship.relationship_kind = 'team' and relationship.status = 'active'
     and relationship.deleted_at is null limit 1;
  if v_driver_id is null then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Actor is not an active Team driver'));
  end if;
  select stop.* into v_stop from public.delivery_stops stop
    join public.round_stops assigned on assigned.stop_id = stop.id and assigned.tenant_id = stop.tenant_id
    join public.rounds round_record on round_record.id = assigned.round_id and round_record.tenant_id = stop.tenant_id
   where stop.id = p_stop_id and stop.state = 'arrived'
     and round_record.driver_id = v_driver_id and round_record.state = 'active'
   limit 1;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Stop is not awaiting proof of delivery for this driver'));
  end if;
  select round_record.* into v_round from public.rounds round_record
    join public.round_stops assigned on assigned.round_id = round_record.id
   where assigned.stop_id = p_stop_id;
  select * into v_existing from public.media_assets
   where stop_id = p_stop_id and expected_sha256 = p_sha256 and expected_size = p_size
     and state in ('staged', 'uploaded_uncommitted', 'committed') limit 1;
  if found then
    return jsonb_build_object(
      'status', 'prepared', 'mediaAssetId', v_existing.id,
      'bucket', v_existing.storage_bucket, 'path', v_existing.storage_path,
      'assetState', v_existing.state, 'deduplicated', true);
  end if;
  v_path := v_stop.tenant_id::text || '/' || v_round.id::text || '/' || p_stop_id::text || '/' || p_asset_id::text ||
    case when p_content_type = 'image/png' then '.png' else '.jpg' end;
  insert into public.media_assets (
    id, tenant_id, delivery_id, stop_id, round_id, driver_id, intent,
    storage_path, expected_sha256, expected_size, content_type
  ) values (
    p_asset_id, v_stop.tenant_id, v_stop.delivery_id, p_stop_id, v_round.id, v_driver_id,
    'delivery_photo', v_path, p_sha256, p_size, p_content_type
  );
  return jsonb_build_object(
    'status', 'prepared', 'mediaAssetId', p_asset_id,
    'bucket', 'pod-evidence', 'path', v_path, 'assetState', 'staged');
end;
$$;

create or replace function public.mark_pod_media_uploaded(
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
  v_asset public.media_assets%rowtype;
begin
  select asset.* into v_asset from public.media_assets asset
    join public.driver_profiles driver on driver.id = asset.driver_id
   where asset.id = p_asset_id and driver.person_id = p_actor_person_id for update of asset;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Photo asset is not owned by this driver'));
  end if;
  if v_asset.state = 'committed' then
    return jsonb_build_object('status', 'verified', 'mediaAssetId', p_asset_id, 'assetState', v_asset.state);
  end if;
  if p_verified_sha256 <> v_asset.expected_sha256 or p_verified_size <> v_asset.expected_size then
    update public.media_assets set state = 'quarantined' where id = p_asset_id;
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'EVIDENCE_REQUIRED', 'message', 'Uploaded photo failed integrity verification'));
  end if;
  update public.media_assets set
    state = 'uploaded_uncommitted', verified_sha256 = p_verified_sha256,
    verified_size = p_verified_size, uploaded_at = now()
   where id = p_asset_id;
  return jsonb_build_object('status', 'verified', 'mediaAssetId', p_asset_id, 'assetState', 'uploaded_uncommitted');
end;
$$;

create or replace function public.complete_stop_pod_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'stop.complete_pod';
  v_tenant_id uuid;
  v_stop_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_occurred_from_device_at timestamptz;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_stop public.delivery_stops%rowtype;
  v_delivery public.deliveries%rowtype;
  v_round public.rounds%rowtype;
  v_manifest public.manifests%rowtype;
  v_asset public.media_assets%rowtype;
  v_driver_id uuid;
  v_actor_role public.tenant_role;
  v_line_numbers integer[];
  v_expected_lines integer;
  v_expected_units integer;
  v_handoff_type public.pod_handoff_type;
  v_receiver_name text;
  v_receiver_relationship text;
  v_left_at_location text;
  v_note text;
  v_position extensions.geography(point, 4326);
  v_accuracy double precision;
  v_location_source text;
  v_verification_id uuid := gen_random_uuid();
  v_custody_id uuid := gen_random_uuid();
  v_pod_id uuid := gen_random_uuid();
  v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now();
  v_stop_version bigint;
  v_round_version bigint;
  v_round_state public.round_state;
  v_event_payload jsonb;
  v_event jsonb;
  v_result jsonb;
begin
  if p_command is null or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
     or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_stop_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
    v_occurred_from_device_at := nullif(p_command ->> 'occurredFromDeviceAt', '')::timestamptz;
    v_handoff_type := (p_command #>> '{payload,handoffType}')::public.pod_handoff_type;
    v_line_numbers := array(select jsonb_array_elements_text(p_command #> '{payload,confirmedLineNumbers}')::integer order by 1);
    if p_command #> '{payload,position}' is not null then
      v_position := extensions.st_setsrid(extensions.st_makepoint(
        (p_command #>> '{payload,position,longitude}')::double precision,
        (p_command #>> '{payload,position,latitude}')::double precision), 4326)::extensions.geography;
      v_accuracy := (p_command #>> '{payload,position,accuracyMeters}')::double precision;
      v_location_source := p_command #>> '{payload,position,source}';
    end if;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'POD identifiers or evidence are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  v_payload_hash := encode(digest(v_payload::text, 'sha256'), 'hex');
  v_receiver_name := nullif(btrim(coalesce(v_payload ->> 'receiverName', '')), '');
  v_receiver_relationship := nullif(btrim(coalesce(v_payload ->> 'receiverRelationship', '')), '');
  v_left_at_location := nullif(btrim(coalesce(v_payload ->> 'leftAtLocation', '')), '');
  v_note := nullif(btrim(coalesce(v_payload ->> 'note', '')), '');
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
     or cardinality(v_line_numbers) < 1 or length(coalesce(v_note, '')) > 500
     or v_accuracy < 0 or v_location_source not in ('google_nav', 'rounds_os', 'unknown')
     or (v_handoff_type = 'recipient' and (v_receiver_name is null or v_receiver_relationship is not null or v_left_at_location is not null))
     or (v_handoff_type = 'someone_else' and (v_receiver_name is null or v_receiver_relationship is null or v_left_at_location is not null))
     or (v_handoff_type = 'left_at_location' and (v_receiver_name is not null or v_receiver_relationship is not null or v_left_at_location is null)) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'POD handoff details are incomplete'));
  end if;
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
  select membership.role, driver.id into v_actor_role, v_driver_id
    from public.tenant_memberships membership
    join public.driver_profiles driver on driver.person_id = membership.person_id
    join public.driver_tenant_relationships relationship
      on relationship.driver_id = driver.id and relationship.tenant_id = membership.tenant_id
   where membership.tenant_id = v_tenant_id and membership.person_id = p_actor_person_id
     and membership.status = 'active' and membership.role = 'team_driver'
     and driver.active = true and driver.deleted_at is null
     and relationship.relationship_kind = 'team' and relationship.status = 'active'
     and relationship.deleted_at is null limit 1;
  if v_driver_id is null then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Actor is not an active Team driver for this tenant'));
  end if;
  select stop.* into v_stop from public.delivery_stops stop
   where stop.id = v_stop_id and stop.tenant_id = v_tenant_id and stop.state = 'arrived' for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Stop is not awaiting proof of delivery'));
  end if;
  if v_stop.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Stop changed; refresh before completing delivery'));
  end if;
  select round_record.* into v_round from public.rounds round_record
    join public.round_stops assigned on assigned.round_id = round_record.id and assigned.tenant_id = round_record.tenant_id
   where assigned.stop_id = v_stop_id and round_record.driver_id = v_driver_id and round_record.state = 'active'
   for update of round_record;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Stop is not assigned to this active driver Round'));
  end if;
  select * into v_delivery from public.deliveries
   where id = v_stop.delivery_id and tenant_id = v_tenant_id and state = 'arrived' for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'INVALID_STATE', 'message', 'Delivery is not awaiting proof of delivery'));
  end if;
  select * into v_manifest from public.manifests
   where id = (v_payload ->> 'manifestId')::uuid and tenant_id = v_tenant_id
     and delivery_id = v_delivery.id and version = (v_payload ->> 'manifestVersion')::bigint
     and state = 'picked_up_locked' for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'CUSTODY_LOCKED', 'message', 'Handoff manifest does not match the locked pickup manifest'));
  end if;
  select count(*), coalesce(sum(quantity), 0) into v_expected_lines, v_expected_units
    from public.manifest_items where manifest_id = v_manifest.id;
  if cardinality(v_line_numbers) <> v_expected_lines or exists (
    select 1 from public.manifest_items item
     where item.manifest_id = v_manifest.id and not (item.line_number = any(v_line_numbers))
  ) then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'CUSTODY_LOCKED', 'message', 'Every locked manifest line must be confirmed at handoff'));
  end if;
  select * into v_asset from public.media_assets
   where id = (v_payload ->> 'mediaAssetId')::uuid and tenant_id = v_tenant_id
     and stop_id = v_stop_id and driver_id = v_driver_id and state = 'uploaded_uncommitted' for update;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'EVIDENCE_REQUIRED', 'message', 'A verified delivery photo is required'));
  end if;
  insert into public.manifest_verifications (
    id, tenant_id, manifest_id, manifest_version, delivery_id, stop_id, round_id,
    driver_id, stage, confirmed_line_numbers, verified_units, expected_units,
    actor_person_id, occurred_from_device_at, verified_at, command_id
  ) values (
    v_verification_id, v_tenant_id, v_manifest.id, v_manifest.version, v_delivery.id, v_stop_id, v_round.id,
    v_driver_id, 'handoff', v_line_numbers, v_expected_units, v_expected_units,
    p_actor_person_id, v_occurred_from_device_at, v_occurred_at, v_command_id);
  insert into public.custody_events (
    id, tenant_id, delivery_id, stop_id, round_id, manifest_id, manifest_version,
    manifest_verification_id, event_type, from_party_type, from_party_id,
    to_party_type, to_party_id, actor_person_id, occurred_from_device_at, occurred_at, command_id
  ) values (
    v_custody_id, v_tenant_id, v_delivery.id, v_stop_id, v_round.id, v_manifest.id, v_manifest.version,
    v_verification_id, 'driver_to_recipient', 'driver', v_driver_id,
    case when v_handoff_type = 'left_at_location' then 'approved_location' else 'recipient' end,
    null, p_actor_person_id, v_occurred_from_device_at, v_occurred_at, v_command_id);
  insert into public.pod_records (
    id, tenant_id, delivery_id, stop_id, round_id, driver_id, manifest_id, manifest_version,
    manifest_verification_id, media_asset_id, handoff_type, receiver_name,
    receiver_relationship, left_at_location, note, position, accuracy_meters,
    location_source, occurred_from_device_at, delivered_at, actor_person_id, command_id
  ) values (
    v_pod_id, v_tenant_id, v_delivery.id, v_stop_id, v_round.id, v_driver_id, v_manifest.id, v_manifest.version,
    v_verification_id, v_asset.id, v_handoff_type, v_receiver_name,
    v_receiver_relationship, v_left_at_location, v_note, v_position, v_accuracy,
    v_location_source, v_occurred_from_device_at, v_occurred_at, p_actor_person_id, v_command_id);
  update public.media_assets set state = 'committed', committed_at = v_occurred_at where id = v_asset.id;
  update public.deliveries set state = 'delivered_pending_evidence', version = version + 1, updated_at = v_occurred_at where id = v_delivery.id;
  update public.deliveries set state = 'delivered', version = version + 1, updated_at = v_occurred_at where id = v_delivery.id;
  update public.delivery_stops set state = 'completed', completed_at = v_occurred_at,
    version = version + 1, updated_at = v_occurred_at where id = v_stop_id returning version into v_stop_version;
  if not exists (
    select 1 from public.round_stops assigned join public.delivery_stops stop on stop.id = assigned.stop_id
     where assigned.round_id = v_round.id and stop.state <> 'completed'
  ) then
    update public.rounds set state = 'complete', version = version + 1, updated_at = v_occurred_at
     where id = v_round.id returning version, state into v_round_version, v_round_state;
  else
    v_round_version := v_round.version;
    v_round_state := v_round.state;
  end if;
  v_event_payload := jsonb_build_object(
    'podId', v_pod_id, 'mediaAssetId', v_asset.id, 'custodyEventId', v_custody_id,
    'manifestVerificationId', v_verification_id, 'stopId', v_stop_id,
    'deliveryId', v_delivery.id, 'roundId', v_round.id, 'driverId', v_driver_id,
    'handoffType', v_handoff_type, 'deliveredAt', v_occurred_at);
  v_event := jsonb_build_object(
    'event', 'stop.delivery_completed', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'stop',
    'aggregateId', v_stop_id, 'aggregateVersion', v_stop_version, 'occurredAt', v_occurred_at,
    'payload', v_event_payload);
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'stop.delivery_completed', 'stop', v_stop_id,
    v_stop_version, v_command_id, v_trace_id,
    jsonb_build_object('state', jsonb_build_object('from', v_stop.state, 'to', 'completed'),
      'deliveryState', 'delivered', 'podId', v_pod_id, 'mediaAssetId', v_asset.id,
      'roundState', v_round_state));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'stop.delivery_completed', 1, 'stop', v_stop_id,
    v_stop_version, v_trace_id, v_event, v_occurred_at);
  v_result := jsonb_build_object(
    'status', 'committed', 'aggregateVersion', v_stop_version,
    'state', v_event_payload || jsonb_build_object(
      'stopState', 'completed', 'deliveryState', 'delivered',
      'roundState', v_round_state, 'roundVersion', v_round_version),
    'events', jsonb_build_array(v_event));
  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_stop_id,
    v_payload_hash, 'committed', v_result, v_trace_id, p_actor_person_id);
  return v_result;
end;
$$;

revoke all on function public.prepare_pod_media_asset(uuid, uuid, uuid, text, bigint, text) from public, anon, authenticated;
revoke all on function public.mark_pod_media_uploaded(uuid, uuid, text, bigint) from public, anon, authenticated;
revoke all on function public.complete_stop_pod_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.prepare_pod_media_asset(uuid, uuid, uuid, text, bigint, text) to service_role;
grant execute on function public.mark_pod_media_uploaded(uuid, uuid, text, bigint) to service_role;
grant execute on function public.complete_stop_pod_command(jsonb, uuid) to service_role;

comment on table public.media_assets is 'Immutable POD media lifecycle. Bytes are verified before state can become uploaded_uncommitted.';
comment on table public.pod_records is 'Evidence-backed delivery handoff committed only after durable media verification.';
comment on function public.complete_stop_pod_command(jsonb, uuid) is
  'Server-only atomic handoff, POD, custody, Stop completion and conditional Round completion command.';
