-- Slice 2: normalized own-fleet vehicle and schedule truth.
-- Existing free-text vehicle labels are preserved through conservative,
-- review-required single-Stop profiles; no larger capacity is inferred.

create table public.vehicle_profiles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  code text not null check (code ~ '^[a-z0-9][a-z0-9-]*$'),
  display_name text not null check (length(btrim(display_name)) between 1 and 120),
  vehicle_group text not null check (vehicle_group in ('motorbike', 'car', 'van', 'pickup', 'cargo_bike', 'other')),
  departure_pattern text not null check (departure_pattern in (
    'multi_stop', 'return_after_every_delivery', 'return_after_round', 'return_when_capacity_exhausted'
  )),
  max_stops_per_departure integer not null check (max_stops_per_departure between 1 and 100),
  planning_deliveries_per_block integer not null check (planning_deliveries_per_block between 1 and 500),
  pickup_turnaround_minutes integer not null check (pickup_turnaround_minutes between 0 and 240),
  requires_review boolean not null default false,
  active boolean not null default true,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tenant_id, code),
  unique (tenant_id, id)
);

create table public.cargo_classes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  code text not null check (code ~ '^[a-z0-9][a-z0-9_-]*$'),
  display_name text not null check (length(btrim(display_name)) between 1 and 120),
  active boolean not null default true,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tenant_id, code),
  unique (tenant_id, id)
);

create table public.vehicle_profile_cargo_limits (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  vehicle_profile_id uuid not null,
  cargo_class_id uuid not null,
  allowed boolean not null default true,
  max_quantity integer check (max_quantity is null or max_quantity between 1 and 10000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, vehicle_profile_id, cargo_class_id),
  foreign key (tenant_id, vehicle_profile_id) references public.vehicle_profiles(tenant_id, id) on delete restrict,
  foreign key (tenant_id, cargo_class_id) references public.cargo_classes(tenant_id, id) on delete restrict,
  check ((allowed and max_quantity is not null) or (not allowed and max_quantity is null))
);

create table public.driver_vehicle_assignments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  vehicle_profile_id uuid not null,
  is_default boolean not null default true,
  effective_from date not null default current_date,
  effective_to date,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tenant_id, id),
  foreign key (tenant_id, vehicle_profile_id) references public.vehicle_profiles(tenant_id, id) on delete restrict,
  check (effective_to is null or effective_to >= effective_from)
);

create unique index driver_vehicle_assignments_default_idx
  on public.driver_vehicle_assignments (tenant_id, driver_id)
  where is_default and effective_to is null and deleted_at is null;

create table public.driver_recurring_schedules (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  weekdays smallint[] not null,
  start_local time not null,
  end_local time not null,
  timezone text not null,
  vehicle_profile_id uuid not null,
  note text check (note is null or length(note) <= 500),
  active boolean not null default true,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tenant_id, driver_id),
  unique (tenant_id, id),
  foreign key (tenant_id, vehicle_profile_id) references public.vehicle_profiles(tenant_id, id) on delete restrict,
  check (cardinality(weekdays) between 1 and 7),
  check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  check (start_local <> end_local)
);

create table public.driver_shift_exceptions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  driver_id uuid not null references public.driver_profiles(id) on delete restrict,
  service_date date not null,
  exception_kind text not null check (exception_kind in ('shift', 'off')),
  start_local time,
  end_local time,
  timezone text not null,
  vehicle_profile_id uuid,
  note text check (note is null or length(note) <= 500),
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (tenant_id, driver_id, service_date),
  unique (tenant_id, id),
  foreign key (tenant_id, vehicle_profile_id) references public.vehicle_profiles(tenant_id, id) on delete restrict,
  check (
    (exception_kind = 'off' and start_local is null and end_local is null and vehicle_profile_id is null)
    or
    (exception_kind = 'shift' and start_local is not null and end_local is not null
      and start_local <> end_local and vehicle_profile_id is not null)
  )
);

create index vehicle_profiles_active_idx on public.vehicle_profiles (tenant_id, active) where deleted_at is null;
create index driver_schedules_active_idx on public.driver_recurring_schedules (tenant_id, active) where deleted_at is null;
create index driver_shift_exceptions_date_idx on public.driver_shift_exceptions (tenant_id, service_date);

alter table public.vehicle_profiles enable row level security;
alter table public.cargo_classes enable row level security;
alter table public.vehicle_profile_cargo_limits enable row level security;
alter table public.driver_vehicle_assignments enable row level security;
alter table public.driver_recurring_schedules enable row level security;
alter table public.driver_shift_exceptions enable row level security;

revoke all on table public.vehicle_profiles, public.cargo_classes,
  public.vehicle_profile_cargo_limits, public.driver_vehicle_assignments,
  public.driver_recurring_schedules, public.driver_shift_exceptions
  from anon, authenticated;
grant select on table public.vehicle_profiles, public.cargo_classes,
  public.vehicle_profile_cargo_limits, public.driver_vehicle_assignments,
  public.driver_recurring_schedules, public.driver_shift_exceptions
  to service_role;

with existing_driver_labels as (
  select relationship.tenant_id, driver.id as driver_id,
    coalesce(nullif(btrim(driver.vehicle_label), ''), 'Vehicle · review required') as vehicle_label
  from public.driver_tenant_relationships relationship
  join public.driver_profiles driver on driver.id = relationship.driver_id
  where relationship.relationship_kind = 'team' and relationship.status = 'active'
    and relationship.deleted_at is null and driver.active = true and driver.deleted_at is null
), inserted_profiles as (
  insert into public.vehicle_profiles (
    tenant_id, code, display_name, vehicle_group, departure_pattern,
    max_stops_per_departure, planning_deliveries_per_block,
    pickup_turnaround_minutes, requires_review
  )
  select tenant_id, 'legacy-' || substr(replace(driver_id::text, '-', ''), 1, 12),
    vehicle_label, 'other', 'return_after_every_delivery', 1, 1, 20, true
  from existing_driver_labels
  on conflict (tenant_id, code) do nothing
  returning id, tenant_id, code
)
insert into public.driver_vehicle_assignments (
  tenant_id, driver_id, vehicle_profile_id, is_default, effective_from
)
select label.tenant_id, label.driver_id, profile.id, true, current_date
from existing_driver_labels label
join public.vehicle_profiles profile
  on profile.tenant_id = label.tenant_id
 and profile.code = 'legacy-' || substr(replace(label.driver_id::text, '-', ''), 1, 12)
where not exists (
  select 1 from public.driver_vehicle_assignments assignment
  where assignment.tenant_id = label.tenant_id and assignment.driver_id = label.driver_id
    and assignment.is_default and assignment.effective_to is null and assignment.deleted_at is null
);

comment on table public.vehicle_profiles is
  'Versioned tenant vehicle/capacity rules. Conservative migrated profiles require Operations review.';
comment on table public.driver_recurring_schedules is
  'Own-team weekly capacity schedule; ISO weekdays 1=Monday through 7=Sunday.';
comment on table public.driver_shift_exceptions is
  'Date-specific own-team shift or day-off override; never used for Network availability.';

