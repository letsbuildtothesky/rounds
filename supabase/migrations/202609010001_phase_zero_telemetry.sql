create extension if not exists postgis with schema extensions;

create type public.location_source as enum ('google_nav', 'rounds_os');

create table public.driver_position_current (
  tenant_id uuid not null,
  driver_id uuid primary key,
  device_id uuid not null,
  session_id uuid not null,
  round_id uuid,
  stop_id uuid,
  source public.location_source not null,
  position extensions.geography(point, 4326) not null,
  captured_at timestamptz not null,
  received_at timestamptz not null default now(),
  accuracy_meters real not null check (accuracy_meters >= 0),
  speed_meters_per_second real,
  heading_degrees real,
  ingest_watermark bigint not null check (ingest_watermark >= 0),
  updated_at timestamptz not null default now()
);

create index driver_position_current_tenant_idx
  on public.driver_position_current (tenant_id, captured_at desc);

create table public.driver_location_samples (
  tenant_id uuid not null,
  driver_id uuid not null,
  session_id uuid not null,
  sequence bigint not null check (sequence > 0),
  source public.location_source not null,
  position extensions.geography(point, 4326) not null,
  captured_at timestamptz not null,
  received_at timestamptz not null default now(),
  accuracy_meters real not null check (accuracy_meters >= 0),
  speed_meters_per_second real,
  heading_degrees real,
  primary key (driver_id, session_id, sequence)
);

create index driver_location_samples_retention_idx
  on public.driver_location_samples (received_at);

alter table public.driver_position_current enable row level security;
alter table public.driver_location_samples enable row level security;

comment on table public.driver_position_current is
  'Phase 0 hot position plane. Writes occur through the server ingest boundary.';
comment on table public.driver_location_samples is
  'Phase 0 short-retention telemetry samples; never a permanent audited trail.';

