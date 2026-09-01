create extension if not exists pgcrypto with schema extensions;

create type public.tenant_status as enum ('active', 'suspended', 'closed');
create type public.tenant_role as enum (
  'tenant_owner',
  'operations_admin',
  'dispatcher',
  'viewer',
  'team_driver',
  'internal_support'
);
create type public.membership_status as enum ('invited', 'active', 'revoked');
create type public.driver_relationship_kind as enum ('team', 'preferred', 'known');
create type public.driver_relationship_status as enum ('invited', 'active', 'inactive', 'blocked');
create type public.delivery_state as enum (
  'draft',
  'unplanned',
  'planned',
  'assigned',
  'pickup_pending',
  'in_custody',
  'en_route',
  'arrived',
  'delivered_pending_evidence',
  'delivered',
  'exception',
  'returned',
  'cancelled'
);
create type public.delivery_stop_state as enum (
  'pending',
  'ready',
  'assigned',
  'active',
  'arrived',
  'completed',
  'exception',
  'cancelled'
);
create type public.round_state as enum (
  'proposed',
  'approved',
  'loading',
  'active',
  'complete',
  'cancelled'
);
create type public.manifest_state as enum ('draft', 'picked_up_locked');

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]*$'),
  display_name text not null check (length(btrim(display_name)) between 1 and 160),
  legal_name text,
  timezone text not null default 'Asia/Bangkok',
  status public.tenant_status not null default 'active',
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.persons (
  id uuid primary key default gen_random_uuid(),
  display_name text not null check (length(btrim(display_name)) between 1 and 160),
  phone_e164 text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (phone_e164 is not null or email is not null)
);

create table public.auth_identities (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  person_id uuid not null references public.persons(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (person_id, auth_user_id)
);

create table public.tenant_locations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  code text not null,
  display_name text not null check (length(btrim(display_name)) between 1 and 160),
  raw_address text not null check (length(btrim(raw_address)) > 0),
  position extensions.geography(point, 4326),
  position_provenance text,
  pickup_contact_name text not null,
  pickup_contact_phone text not null,
  active boolean not null default true,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tenant_id, code),
  unique (tenant_id, id),
  check ((position is null) = (position_provenance is null))
);

create table public.tenant_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  person_id uuid not null references public.persons(id) on delete restrict,
  role public.tenant_role not null,
  status public.membership_status not null default 'invited',
  invited_at timestamptz not null default now(),
  activated_at timestamptz,
  revoked_at timestamptz,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, person_id, role),
  check (status <> 'active' or activated_at is not null),
  check (status <> 'revoked' or revoked_at is not null)
);

create table public.driver_profiles (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null unique references public.persons(id) on delete restrict,
  preferred_locale text not null default 'th-TH' check (preferred_locale in ('th-TH', 'en', 'en-US')),
  vehicle_label text,
  vehicle_plate text,
  active boolean not null default true,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.driver_tenant_relationships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  relationship_kind public.driver_relationship_kind not null,
  status public.driver_relationship_status not null default 'invited',
  permissions jsonb not null default '{}'::jsonb,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tenant_id, driver_id, relationship_kind),
  unique (tenant_id, driver_id)
);

create table public.driver_devices (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  platform text not null check (platform in ('android', 'ios')),
  device_fingerprint text not null,
  push_token text,
  app_version text,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (driver_id, device_fingerprint)
);

create table public.sensitive_access_audit (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete restrict,
  actor_person_id uuid references public.persons(id) on delete restrict,
  subject_type text not null,
  subject_id uuid,
  access_type text not null,
  purpose text not null check (length(btrim(purpose)) > 0),
  trace_id uuid not null,
  occurred_at timestamptz not null default now()
);

create table public.deliveries (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  reference text not null,
  source_system text not null check (source_system ~ '^[a-z0-9][a-z0-9_.-]*$'),
  external_id text not null check (length(btrim(external_id)) > 0),
  source_payload_hash text not null check (source_payload_hash ~ '^[0-9a-f]{64}$'),
  service_date date not null,
  service_timezone text not null,
  pickup_location_id uuid not null,
  buyer_same_as_recipient boolean not null default true,
  buyer_name text not null,
  buyer_phone text not null,
  recipient_name text not null check (length(btrim(recipient_name)) > 0),
  recipient_phone text not null check (length(btrim(recipient_phone)) > 0),
  destination_raw_address text not null check (length(btrim(destination_raw_address)) > 0),
  destination_position extensions.geography(point, 4326) not null,
  destination_provenance text not null check (length(btrim(destination_provenance)) > 0),
  access_note text,
  delivery_note text,
  is_surprise boolean not null default false,
  state public.delivery_state not null default 'unplanned',
  version bigint not null default 1 check (version > 0),
  created_by_person_id uuid not null references public.persons(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tenant_id, source_system, external_id),
  unique (tenant_id, id),
  foreign key (tenant_id, pickup_location_id)
    references public.tenant_locations(tenant_id, id) on delete restrict,
  check (buyer_same_as_recipient = false or (buyer_name = recipient_name and buyer_phone = recipient_phone))
);

create table public.delivery_promises (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  delivery_id uuid not null,
  window_start timestamptz not null,
  window_end timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (delivery_id),
  unique (tenant_id, id),
  foreign key (tenant_id, delivery_id)
    references public.deliveries(tenant_id, id) on delete restrict,
  check (window_end > window_start)
);

create table public.delivery_stops (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  delivery_id uuid not null,
  state public.delivery_stop_state not null default 'pending',
  destination_version bigint not null default 1 check (destination_version > 0),
  arrived_at timestamptz,
  completed_at timestamptz,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (delivery_id),
  unique (tenant_id, id),
  foreign key (tenant_id, delivery_id)
    references public.deliveries(tenant_id, id) on delete restrict
);

create table public.manifests (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  delivery_id uuid not null,
  state public.manifest_state not null default 'draft',
  version bigint not null default 1 check (version > 0),
  locked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (delivery_id, version),
  unique (tenant_id, id),
  foreign key (tenant_id, delivery_id)
    references public.deliveries(tenant_id, id) on delete restrict,
  check ((state = 'picked_up_locked') = (locked_at is not null))
);

create table public.manifest_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  manifest_id uuid not null,
  line_number integer not null check (line_number > 0),
  sku text,
  description text not null check (length(btrim(description)) > 0),
  quantity integer not null check (quantity > 0),
  cargo_class text,
  handling_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (manifest_id, line_number),
  foreign key (tenant_id, manifest_id)
    references public.manifests(tenant_id, id) on delete restrict
);

create table public.rounds (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  reference text not null,
  service_date date not null,
  driver_id uuid references public.driver_profiles(id) on delete restrict,
  state public.round_state not null default 'proposed',
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tenant_id, reference),
  unique (tenant_id, id)
);

create table public.round_stops (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  round_id uuid not null,
  stop_id uuid not null,
  sequence integer not null check (sequence > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (round_id, stop_id),
  unique (round_id, sequence),
  foreign key (tenant_id, round_id)
    references public.rounds(tenant_id, id) on delete restrict,
  foreign key (tenant_id, stop_id)
    references public.delivery_stops(tenant_id, id) on delete restrict
);

create table public.command_idempotency (
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  command_type text not null,
  idempotency_key text not null check (length(btrim(idempotency_key)) between 1 and 200),
  command_id uuid not null unique,
  aggregate_id uuid not null,
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  status text not null check (status in ('committed', 'rejected')),
  result jsonb not null,
  trace_id uuid not null,
  actor_person_id uuid not null references public.persons(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (tenant_id, command_type, idempotency_key)
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  actor_person_id uuid not null references public.persons(id) on delete restrict,
  actor_role public.tenant_role not null,
  action text not null,
  aggregate_type text not null,
  aggregate_id uuid not null,
  aggregate_version bigint not null check (aggregate_version > 0),
  command_id uuid not null,
  trace_id uuid not null,
  reason text,
  semantic_change jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create table public.domain_event_outbox (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  event_name text not null,
  event_version integer not null check (event_version > 0),
  aggregate_type text not null,
  aggregate_id uuid not null,
  aggregate_version bigint not null check (aggregate_version > 0),
  trace_id uuid not null,
  payload jsonb not null,
  occurred_at timestamptz not null,
  available_at timestamptz not null default now(),
  published_at timestamptz,
  attempts integer not null default 0 check (attempts >= 0),
  last_error text
);

create index tenant_memberships_person_idx
  on public.tenant_memberships (person_id, tenant_id) where status = 'active';
create index driver_relationships_driver_idx
  on public.driver_tenant_relationships (driver_id, tenant_id) where status = 'active';
create index deliveries_tenant_service_state_idx
  on public.deliveries (tenant_id, service_date, state) where deleted_at is null;
create index delivery_stops_tenant_state_idx
  on public.delivery_stops (tenant_id, state, updated_at desc);
create index rounds_tenant_service_state_idx
  on public.rounds (tenant_id, service_date, state) where deleted_at is null;
create index audit_events_aggregate_idx
  on public.audit_events (tenant_id, aggregate_type, aggregate_id, occurred_at desc);
create index domain_event_outbox_pending_idx
  on public.domain_event_outbox (available_at, occurred_at) where published_at is null;

create or replace function public.is_valid_delivery_transition(
  p_from public.delivery_state,
  p_to public.delivery_state
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select p_from = p_to or (p_from, p_to) in (
    ('draft'::public.delivery_state, 'unplanned'::public.delivery_state),
    ('draft'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('unplanned'::public.delivery_state, 'planned'::public.delivery_state),
    ('unplanned'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('planned'::public.delivery_state, 'assigned'::public.delivery_state),
    ('planned'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('assigned'::public.delivery_state, 'pickup_pending'::public.delivery_state),
    ('assigned'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('pickup_pending'::public.delivery_state, 'in_custody'::public.delivery_state),
    ('pickup_pending'::public.delivery_state, 'exception'::public.delivery_state),
    ('pickup_pending'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('in_custody'::public.delivery_state, 'en_route'::public.delivery_state),
    ('in_custody'::public.delivery_state, 'exception'::public.delivery_state),
    ('in_custody'::public.delivery_state, 'returned'::public.delivery_state),
    ('en_route'::public.delivery_state, 'arrived'::public.delivery_state),
    ('en_route'::public.delivery_state, 'exception'::public.delivery_state),
    ('en_route'::public.delivery_state, 'returned'::public.delivery_state),
    ('arrived'::public.delivery_state, 'delivered_pending_evidence'::public.delivery_state),
    ('arrived'::public.delivery_state, 'exception'::public.delivery_state),
    ('arrived'::public.delivery_state, 'returned'::public.delivery_state),
    ('delivered_pending_evidence'::public.delivery_state, 'delivered'::public.delivery_state),
    ('delivered_pending_evidence'::public.delivery_state, 'exception'::public.delivery_state)
  );
$$;

create or replace function public.guard_delivery_transition()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.state <> old.state and not public.is_valid_delivery_transition(old.state, new.state) then
    raise exception 'INVALID_STATE: % -> %', old.state, new.state
      using errcode = '23514';
  end if;
  if new.version <= old.version and new is distinct from old then
    raise exception 'STALE_VERSION: delivery version must increase'
      using errcode = '40001';
  end if;
  return new;
end;
$$;

create trigger deliveries_guard_transition
before update on public.deliveries
for each row execute function public.guard_delivery_transition();

create or replace function public.guard_manifest_item_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_manifest_id uuid := coalesce(new.manifest_id, old.manifest_id);
  v_state public.manifest_state;
begin
  select state into v_state from public.manifests where id = v_manifest_id;
  if v_state = 'picked_up_locked' then
    raise exception 'CUSTODY_LOCKED: picked-up manifest is immutable'
      using errcode = '23514';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger manifest_items_guard_mutation
before insert or update or delete on public.manifest_items
for each row execute function public.guard_manifest_item_mutation();

create or replace function public.request_tenant_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'active_tenant_id',
    ''
  )::uuid;
$$;

create or replace function public.request_tenant_role()
returns public.tenant_role
language sql
stable
set search_path = ''
as $$
  select nullif(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'tenant_role',
    ''
  )::public.tenant_role;
$$;

create or replace function public.can_read_tenant(p_tenant_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_tenant_id = public.request_tenant_id()
    and public.request_tenant_role() in (
      'tenant_owner'::public.tenant_role,
      'operations_admin'::public.tenant_role,
      'dispatcher'::public.tenant_role,
      'viewer'::public.tenant_role
    );
$$;

alter table public.tenants enable row level security;
alter table public.persons enable row level security;
alter table public.auth_identities enable row level security;
alter table public.tenant_locations enable row level security;
alter table public.tenant_memberships enable row level security;
alter table public.driver_profiles enable row level security;
alter table public.driver_tenant_relationships enable row level security;
alter table public.driver_devices enable row level security;
alter table public.sensitive_access_audit enable row level security;
alter table public.deliveries enable row level security;
alter table public.delivery_promises enable row level security;
alter table public.delivery_stops enable row level security;
alter table public.manifests enable row level security;
alter table public.manifest_items enable row level security;
alter table public.rounds enable row level security;
alter table public.round_stops enable row level security;
alter table public.command_idempotency enable row level security;
alter table public.audit_events enable row level security;
alter table public.domain_event_outbox enable row level security;

create policy tenants_select_active_tenant on public.tenants
  for select to authenticated
  using (public.can_read_tenant(id));
create policy tenant_locations_select_active_tenant on public.tenant_locations
  for select to authenticated
  using (public.can_read_tenant(tenant_id));
create policy deliveries_select_active_tenant on public.deliveries
  for select to authenticated
  using (public.can_read_tenant(tenant_id));
create policy delivery_promises_select_active_tenant on public.delivery_promises
  for select to authenticated
  using (public.can_read_tenant(tenant_id));
create policy delivery_stops_select_active_tenant on public.delivery_stops
  for select to authenticated
  using (public.can_read_tenant(tenant_id));
create policy manifests_select_active_tenant on public.manifests
  for select to authenticated
  using (public.can_read_tenant(tenant_id));
create policy manifest_items_select_active_tenant on public.manifest_items
  for select to authenticated
  using (public.can_read_tenant(tenant_id));
create policy rounds_select_active_tenant on public.rounds
  for select to authenticated
  using (public.can_read_tenant(tenant_id));
create policy round_stops_select_active_tenant on public.round_stops
  for select to authenticated
  using (public.can_read_tenant(tenant_id));

revoke all on table public.tenants from anon, authenticated;
revoke all on table public.persons from anon, authenticated;
revoke all on table public.auth_identities from anon, authenticated;
revoke all on table public.tenant_locations from anon, authenticated;
revoke all on table public.tenant_memberships from anon, authenticated;
revoke all on table public.driver_profiles from anon, authenticated;
revoke all on table public.driver_tenant_relationships from anon, authenticated;
revoke all on table public.driver_devices from anon, authenticated;
revoke all on table public.sensitive_access_audit from anon, authenticated;
revoke all on table public.deliveries from anon, authenticated;
revoke all on table public.delivery_promises from anon, authenticated;
revoke all on table public.delivery_stops from anon, authenticated;
revoke all on table public.manifests from anon, authenticated;
revoke all on table public.manifest_items from anon, authenticated;
revoke all on table public.rounds from anon, authenticated;
revoke all on table public.round_stops from anon, authenticated;
revoke all on table public.command_idempotency from anon, authenticated;
revoke all on table public.audit_events from anon, authenticated;
revoke all on table public.domain_event_outbox from anon, authenticated;

grant select on table public.tenants,
  public.tenant_locations,
  public.deliveries,
  public.delivery_promises,
  public.delivery_stops,
  public.manifests,
  public.manifest_items,
  public.rounds,
  public.round_stops
to authenticated;

create or replace function public.create_delivery_command(p_command jsonb, p_actor_person_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'delivery.create';
  v_tenant_id uuid;
  v_delivery_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_actor_role public.tenant_role;
  v_existing public.command_idempotency%rowtype;
  v_existing_delivery public.deliveries%rowtype;
  v_source_system text;
  v_external_id text;
  v_pickup_location_id uuid;
  v_recipient jsonb;
  v_buyer jsonb;
  v_promise jsonb;
  v_manifest jsonb;
  v_items jsonb;
  v_item jsonb;
  v_recipient_name text;
  v_recipient_phone text;
  v_buyer_same boolean;
  v_buyer_name text;
  v_buyer_phone text;
  v_service_date date;
  v_service_timezone text;
  v_latitude double precision;
  v_longitude double precision;
  v_window_start timestamptz;
  v_window_end timestamptz;
  v_stop_id uuid := gen_random_uuid();
  v_manifest_id uuid := gen_random_uuid();
  v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now();
  v_event jsonb;
  v_result jsonb;
  v_line integer := 0;
begin
  if p_command is null
    or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
    or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Unsupported command envelope')
    );
  end if;

  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_delivery_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
  exception when others then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Command identifiers are invalid')
    );
  end;

  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  if v_expected_version <> 0
    or v_idempotency_key = ''
    or length(v_idempotency_key) > 200
    or v_payload is null then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'CreateDelivery requires expectedVersion 0, idempotencyKey and payload')
    );
  end if;

  v_payload_hash := encode(digest(v_payload::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key, 0));

  select * into v_existing
    from public.command_idempotency
   where tenant_id = v_tenant_id
     and command_type = v_command_type
     and idempotency_key = v_idempotency_key;

  if found then
    if v_existing.payload_hash <> v_payload_hash then
      return jsonb_build_object(
        'status', 'rejected',
        'error', jsonb_build_object('code', 'IDEMPOTENCY_CONFLICT', 'message', 'Idempotency key was already used with different payload')
      );
    end if;
    return v_existing.result;
  end if;

  select membership.role into v_actor_role
    from public.tenant_memberships membership
   where membership.tenant_id = v_tenant_id
     and membership.person_id = p_actor_person_id
     and membership.status = 'active'
     and membership.role in ('tenant_owner', 'operations_admin', 'dispatcher')
   order by case membership.role
     when 'tenant_owner' then 1
     when 'operations_admin' then 2
     else 3
   end
   limit 1;

  if v_actor_role is null then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'NOT_AUTHORIZED', 'message', 'Actor cannot create deliveries for this tenant')
    );
  end if;

  if not exists (select 1 from public.tenants where id = v_tenant_id and status = 'active' and deleted_at is null) then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Tenant is not active')
    );
  end if;

  v_source_system := lower(btrim(coalesce(v_payload ->> 'sourceSystem', '')));
  v_external_id := btrim(coalesce(v_payload ->> 'externalId', ''));
  begin
    v_pickup_location_id := (v_payload ->> 'pickupLocationId')::uuid;
  exception when others then
    v_pickup_location_id := null;
  end;
  v_recipient := v_payload -> 'recipient';
  v_buyer := coalesce(v_payload -> 'buyer', '{}'::jsonb);
  v_promise := v_payload -> 'promise';
  v_manifest := v_payload -> 'manifest';
  v_items := v_manifest -> 'items';
  v_recipient_name := btrim(coalesce(v_recipient ->> 'name', ''));
  v_recipient_phone := btrim(coalesce(v_recipient ->> 'phone', ''));
  begin
    v_buyer_same := coalesce((v_buyer ->> 'sameAsRecipient')::boolean, true);
  exception when others then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Buyer relationship is invalid')
    );
  end;
  v_buyer_name := case when v_buyer_same then v_recipient_name else btrim(coalesce(v_buyer ->> 'name', '')) end;
  v_buyer_phone := case when v_buyer_same then v_recipient_phone else btrim(coalesce(v_buyer ->> 'phone', '')) end;

  if v_source_system = ''
    or v_source_system !~ '^[a-z0-9][a-z0-9_.-]*$'
    or v_external_id = ''
    or v_pickup_location_id is null
    or v_recipient_name = ''
    or v_recipient_phone = ''
    or v_buyer_name = ''
    or v_buyer_phone = ''
    or btrim(coalesce(v_recipient ->> 'rawAddress', '')) = ''
    or v_recipient -> 'coordinate' is null
    or btrim(coalesce(v_recipient -> 'coordinate' ->> 'provenance', '')) = ''
    or v_promise is null
    or v_items is null
    or jsonb_typeof(v_items) <> 'array'
    or jsonb_array_length(v_items) = 0 then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Required delivery, recipient, coordinate, promise or manifest fields are missing')
    );
  end if;

  if not exists (
    select 1 from public.tenant_locations
     where tenant_id = v_tenant_id
       and id = v_pickup_location_id
       and active = true
       and deleted_at is null
  ) then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Pickup location does not belong to the tenant or is inactive')
    );
  end if;

  select * into v_existing_delivery
    from public.deliveries
   where tenant_id = v_tenant_id
     and source_system = v_source_system
     and external_id = v_external_id;

  if found then
    if v_existing_delivery.source_payload_hash <> v_payload_hash then
      v_result := jsonb_build_object(
        'status', 'rejected',
        'error', jsonb_build_object('code', 'IDEMPOTENCY_CONFLICT', 'message', 'External delivery identifier already exists with different content')
      );
    else
      v_result := jsonb_build_object(
        'status', 'committed',
        'aggregateVersion', v_existing_delivery.version,
        'state', jsonb_build_object('deliveryId', v_existing_delivery.id, 'deliveryState', v_existing_delivery.state),
        'events', '[]'::jsonb,
        'deduplicated', true
      );
    end if;

    insert into public.command_idempotency (
      tenant_id, command_type, idempotency_key, command_id, aggregate_id,
      payload_hash, status, result, trace_id, actor_person_id
    ) values (
      v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_existing_delivery.id,
      v_payload_hash, v_result ->> 'status', v_result, v_trace_id, p_actor_person_id
    );
    return v_result;
  end if;

  begin
    v_service_date := (v_payload ->> 'serviceDate')::date;
    v_service_timezone := btrim(v_payload ->> 'serviceTimezone');
    v_latitude := (v_recipient -> 'coordinate' ->> 'latitude')::double precision;
    v_longitude := (v_recipient -> 'coordinate' ->> 'longitude')::double precision;
    v_window_start := (v_promise ->> 'windowStart')::timestamptz;
    v_window_end := (v_promise ->> 'windowEnd')::timestamptz;

    if v_service_timezone = ''
      or v_latitude not between -90 and 90
      or v_longitude not between -180 and 180
      or v_window_end <= v_window_start then
      return jsonb_build_object(
        'status', 'rejected',
        'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Service timezone, coordinate or promise window is invalid')
      );
    end if;

    for v_item in select value from jsonb_array_elements(v_items)
    loop
      if btrim(coalesce(v_item ->> 'description', '')) = '' or coalesce((v_item ->> 'quantity')::integer, 0) <= 0 then
        return jsonb_build_object(
          'status', 'rejected',
          'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Every manifest item needs a description and positive quantity')
        );
      end if;
    end loop;
  exception when others then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'VALIDATION_FAILED', 'message', 'Promise, coordinate, service date or manifest values are invalid')
    );
  end;

  insert into public.deliveries (
    id, tenant_id, reference, source_system, external_id, source_payload_hash,
    service_date, service_timezone, pickup_location_id,
    buyer_same_as_recipient, buyer_name, buyer_phone,
    recipient_name, recipient_phone, destination_raw_address,
    destination_position, destination_provenance, access_note, delivery_note,
    is_surprise, state, created_by_person_id
  ) values (
    v_delivery_id,
    v_tenant_id,
    coalesce(nullif(btrim(v_payload ->> 'reference'), ''), v_external_id),
    v_source_system,
    v_external_id,
    v_payload_hash,
    v_service_date,
    v_service_timezone,
    v_pickup_location_id,
    v_buyer_same,
    v_buyer_name,
    v_buyer_phone,
    v_recipient_name,
    v_recipient_phone,
    btrim(v_recipient ->> 'rawAddress'),
    st_setsrid(st_makepoint(
      v_longitude,
      v_latitude
    ), 4326)::extensions.geography,
    btrim(v_recipient -> 'coordinate' ->> 'provenance'),
    nullif(btrim(v_recipient ->> 'accessNote'), ''),
    nullif(btrim(v_payload ->> 'note'), ''),
    coalesce((v_payload ->> 'isSurprise')::boolean, false),
    'unplanned',
    p_actor_person_id
  );

  insert into public.delivery_promises (
    tenant_id, delivery_id, window_start, window_end
  ) values (
    v_tenant_id,
    v_delivery_id,
    v_window_start,
    v_window_end
  );

  insert into public.delivery_stops (id, tenant_id, delivery_id)
  values (v_stop_id, v_tenant_id, v_delivery_id);

  insert into public.manifests (id, tenant_id, delivery_id)
  values (v_manifest_id, v_tenant_id, v_delivery_id);

  for v_item in select value from jsonb_array_elements(v_items)
  loop
    v_line := v_line + 1;
    insert into public.manifest_items (
      tenant_id, manifest_id, line_number, sku, description, quantity, cargo_class, handling_note
    ) values (
      v_tenant_id,
      v_manifest_id,
      v_line,
      nullif(btrim(v_item ->> 'sku'), ''),
      btrim(v_item ->> 'description'),
      (v_item ->> 'quantity')::integer,
      nullif(btrim(v_item ->> 'cargoClass'), ''),
      nullif(btrim(v_item ->> 'handlingNote'), '')
    );
  end loop;

  v_event := jsonb_build_object(
    'event', 'delivery.created',
    'version', 1,
    'eventId', v_event_id,
    'traceId', v_trace_id,
    'tenantId', v_tenant_id,
    'aggregateType', 'delivery',
    'aggregateId', v_delivery_id,
    'aggregateVersion', 1,
    'occurredAt', v_occurred_at,
    'payload', jsonb_build_object(
      'deliveryId', v_delivery_id,
      'stopId', v_stop_id,
      'manifestId', v_manifest_id,
      'sourceSystem', v_source_system,
      'externalId', v_external_id
    )
  );

  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type,
    aggregate_id, aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'delivery.created', 'delivery',
    v_delivery_id, 1, v_command_id, v_trace_id,
    jsonb_build_object('state', jsonb_build_object('from', null, 'to', 'unplanned'))
  );

  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type,
    aggregate_id, aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'delivery.created', 1, 'delivery',
    v_delivery_id, 1, v_trace_id, v_event, v_occurred_at
  );

  v_result := jsonb_build_object(
    'status', 'committed',
    'aggregateVersion', 1,
    'state', jsonb_build_object(
      'deliveryId', v_delivery_id,
      'deliveryState', 'unplanned',
      'stopId', v_stop_id,
      'manifestId', v_manifest_id
    ),
    'events', jsonb_build_array(v_event)
  );

  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_delivery_id,
    v_payload_hash, 'committed', v_result, v_trace_id, p_actor_person_id
  );

  return v_result;
exception
  when unique_violation then
    return jsonb_build_object(
      'status', 'rejected',
      'error', jsonb_build_object('code', 'IDEMPOTENCY_CONFLICT', 'message', 'Delivery or command identifier already exists')
    );
end;
$$;

revoke all on function public.create_delivery_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.create_delivery_command(jsonb, uuid) to service_role;

comment on function public.create_delivery_command(jsonb, uuid) is
  'Slice 1 server-only canonical delivery intake. Actor is derived by the API before this RPC and re-authorized against active membership.';
comment on table public.command_idempotency is
  'Server command replay ledger. Same key and normalized payload returns the original result; different payload conflicts.';
comment on table public.domain_event_outbox is
  'Transactional domain event staging. Realtime is a hint; durable state remains authoritative.';
