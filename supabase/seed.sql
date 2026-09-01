-- Deterministic synthetic UrbanFlowers fixture for local reset and CI only.
-- No real recipient, driver or customer data belongs in this file.

insert into public.tenants (
  id, slug, display_name, legal_name, timezone, status
)
values (
  '00000000-0000-4000-8000-000000000001',
  'urbanflowers-demo',
  'UrbanFlowers Demo',
  'UrbanFlowers Demo Co., Ltd.',
  'Asia/Bangkok',
  'active'
)
on conflict (id) do update set
  display_name = excluded.display_name,
  timezone = excluded.timezone,
  status = excluded.status,
  updated_at = now();

insert into public.persons (id, display_name, email, phone_e164)
values
  (
    '00000000-0000-4000-8000-000000000007',
    'Demo Dispatcher',
    'dispatcher@demo.rounds.invalid',
    '+66000000001'
  ),
  (
    '00000000-0000-4000-8000-000000000008',
    'Demo Team Driver',
    'driver@demo.rounds.invalid',
    '+66000000002'
  )
on conflict (id) do update set
  display_name = excluded.display_name,
  email = excluded.email,
  phone_e164 = excluded.phone_e164,
  updated_at = now();

insert into public.tenant_locations (
  id, tenant_id, code, display_name, raw_address,
  position, position_provenance, pickup_contact_name, pickup_contact_phone
)
values (
  '00000000-0000-4000-8000-000000000020',
  '00000000-0000-4000-8000-000000000001',
  'sukhumvit-39',
  'UrbanFlowers · Sukhumvit 39',
  'Sukhumvit 39, Bangkok, Thailand',
  st_setsrid(st_makepoint(100.5731, 13.7378), 4326)::extensions.geography,
  'merchant_verified',
  'UrbanFlowers Dispatch',
  '+66000000001'
)
on conflict (id) do update set
  display_name = excluded.display_name,
  raw_address = excluded.raw_address,
  position = excluded.position,
  position_provenance = excluded.position_provenance,
  pickup_contact_name = excluded.pickup_contact_name,
  pickup_contact_phone = excluded.pickup_contact_phone,
  active = true,
  updated_at = now();

insert into public.tenant_memberships (
  id, tenant_id, person_id, role, status, activated_at
)
values
  (
    '00000000-0000-4000-8000-000000000021',
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000007',
    'dispatcher',
    'active',
    now()
  ),
  (
    '00000000-0000-4000-8000-000000000022',
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000008',
    'team_driver',
    'active',
    now()
  )
on conflict (id) do update set
  status = 'active',
  activated_at = coalesce(public.tenant_memberships.activated_at, excluded.activated_at),
  revoked_at = null,
  updated_at = now();

insert into public.driver_profiles (
  id, person_id, preferred_locale, vehicle_label, vehicle_plate
)
values (
  '00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000008',
  'th-TH',
  'Motorbike + delivery box',
  'DEMO-001'
)
on conflict (id) do update set
  preferred_locale = excluded.preferred_locale,
  vehicle_label = excluded.vehicle_label,
  vehicle_plate = excluded.vehicle_plate,
  active = true,
  updated_at = now();

insert into public.driver_tenant_relationships (
  id, tenant_id, driver_id, relationship_kind, status, permissions
)
values (
  '00000000-0000-4000-8000-000000000023',
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000002',
  'team',
  'active',
  '{"assigned_work":true,"tracking_during_work":true}'::jsonb
)
on conflict (id) do update set
  status = 'active',
  permissions = excluded.permissions,
  updated_at = now();

insert into public.driver_devices (
  id, driver_id, platform, device_fingerprint, app_version, last_seen_at
)
values (
  '00000000-0000-4000-8000-000000000003',
  '00000000-0000-4000-8000-000000000002',
  'android',
  'phase-zero-samsung-demo',
  'phase0',
  now()
)
on conflict (id) do update set
  app_version = excluded.app_version,
  last_seen_at = excluded.last_seen_at,
  revoked_at = null,
  updated_at = now();

insert into public.deliveries (
  id, tenant_id, reference, source_system, external_id, source_payload_hash,
  service_date, service_timezone, pickup_location_id,
  buyer_same_as_recipient, buyer_name, buyer_phone,
  recipient_name, recipient_phone, destination_raw_address,
  destination_position, destination_provenance, access_note,
  delivery_note, is_surprise, state, created_by_person_id
)
values (
  '00000000-0000-4000-8000-000000000010',
  '00000000-0000-4000-8000-000000000001',
  'UF-DEMO-001',
  'manual',
  'UF-DEMO-001',
  encode(digest('UF-DEMO-001-v1', 'sha256'), 'hex'),
  current_date,
  'Asia/Bangkok',
  '00000000-0000-4000-8000-000000000020',
  true,
  'Siriporn Demo',
  '+66999999999',
  'Siriporn Demo',
  '+66999999999',
  'Park Hyatt Bangkok, Wireless Road',
  st_setsrid(st_makepoint(100.5470, 13.7439), 4326)::extensions.geography,
  'dispatcher_pin',
  'Hotel reception',
  'Synthetic demo delivery',
  true,
  'assigned',
  '00000000-0000-4000-8000-000000000007'
)
on conflict (id) do nothing;

insert into public.delivery_promises (
  id, tenant_id, delivery_id, window_start, window_end
)
values (
  '00000000-0000-4000-8000-000000000024',
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000010',
  date_trunc('day', now()) + interval '9 hours',
  date_trunc('day', now()) + interval '12 hours'
)
on conflict (id) do nothing;

insert into public.delivery_stops (
  id, tenant_id, delivery_id, state
)
values (
  '00000000-0000-4000-8000-000000000005',
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000010',
  'assigned'
)
on conflict (id) do nothing;

insert into public.manifests (
  id, tenant_id, delivery_id, state
)
values (
  '00000000-0000-4000-8000-000000000011',
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000010',
  'draft'
)
on conflict (id) do nothing;

insert into public.manifest_items (
  id, tenant_id, manifest_id, line_number, sku, description, quantity, cargo_class
)
values (
  '00000000-0000-4000-8000-000000000012',
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000011',
  1,
  'BOUQUET-DEMO',
  'Synthetic flower bouquet',
  1,
  'fragile'
)
on conflict (id) do nothing;

insert into public.rounds (
  id, tenant_id, reference, service_date, driver_id, state
)
values (
  '00000000-0000-4000-8000-000000000004',
  '00000000-0000-4000-8000-000000000001',
  'ROUND-DEMO-001',
  current_date,
  '00000000-0000-4000-8000-000000000002',
  'approved'
)
on conflict (id) do nothing;

insert into public.round_stops (
  id, tenant_id, round_id, stop_id, sequence
)
values (
  '00000000-0000-4000-8000-000000000013',
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000004',
  '00000000-0000-4000-8000-000000000005',
  1
)
on conflict (id) do nothing;
