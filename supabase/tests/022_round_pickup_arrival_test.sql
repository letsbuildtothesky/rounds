begin;

create extension if not exists pgtap with schema extensions;
select plan(17);

select has_function('public', 'confirm_round_pickup_arrival_command', array['jsonb', 'uuid'], 'pickup arrival command exists');
select ok(has_function_privilege('service_role', 'public.confirm_round_pickup_arrival_command(jsonb,uuid)', 'EXECUTE'), 'API service can confirm pickup arrival');
select ok(not has_table_privilege('authenticated', 'public.round_pickup_arrival_events', 'SELECT'), 'driver cannot read pickup arrival evidence directly');

insert into public.tenants (id, slug, display_name)
values ('56000000-0000-4000-8000-000000000001', 'pickup-arrival-test', 'Pickup Arrival Test');
insert into public.persons (id, display_name, email)
values ('56000000-0000-4000-8000-000000000007', 'Arrival Driver', 'arrival-driver@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at)
values ('56000000-0000-4000-8000-000000000001', '56000000-0000-4000-8000-000000000007', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('56000000-0000-4000-8000-000000000002', '56000000-0000-4000-8000-000000000007', 'en', 'Motorbike');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('56000000-0000-4000-8000-000000000001', '56000000-0000-4000-8000-000000000002', 'team', 'active', '{"assigned_work":true}'::jsonb);
insert into public.tenant_locations (
  id, tenant_id, code, display_name, raw_address, position, position_provenance,
  pickup_contact_name, pickup_contact_phone
) values
(
  '56000000-0000-4000-8000-000000000020', '56000000-0000-4000-8000-000000000001',
  'studio', 'Pickup Studio', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.57::double precision, 13.73::double precision), 4326)::extensions.geography,
  'merchant_verified', 'Dispatch', '+66000000000'
),
(
  '56000000-0000-4000-8000-000000000021', '56000000-0000-4000-8000-000000000001',
  'other', 'Other Studio', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.58::double precision, 13.74::double precision), 4326)::extensions.geography,
  'merchant_verified', 'Dispatch', '+66000000001'
);
insert into public.deliveries (
  id, tenant_id, reference, source_system, external_id, source_payload_hash,
  service_date, service_timezone, pickup_location_id, buyer_name, buyer_phone,
  recipient_name, recipient_phone, destination_raw_address, destination_position,
  destination_provenance, state, version, created_by_person_id
) values (
  '56000000-0000-4000-8000-000000000100', '56000000-0000-4000-8000-000000000001',
  'PICKUP-ARRIVAL-001', 'manual', 'PICKUP-ARRIVAL-001', repeat('a', 64), '2026-09-06', 'Asia/Bangkok',
  '56000000-0000-4000-8000-000000000020', 'Recipient', '+66999999999', 'Recipient', '+66999999999',
  'Bangkok', extensions.st_setsrid(extensions.st_makepoint(100.54::double precision, 13.74::double precision), 4326)::extensions.geography,
  'dispatcher_pin', 'assigned', 3, '56000000-0000-4000-8000-000000000007'
);
insert into public.delivery_stops (id, tenant_id, delivery_id, state, version)
values ('56000000-0000-4000-8000-000000000110', '56000000-0000-4000-8000-000000000001', '56000000-0000-4000-8000-000000000100', 'assigned', 2);
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('56000000-0000-4000-8000-000000000130', '56000000-0000-4000-8000-000000000001', 'ROUND-PICKUP-ARRIVAL-001', '2026-09-06', '56000000-0000-4000-8000-000000000002', 'approved', 4);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('56000000-0000-4000-8000-000000000001', '56000000-0000-4000-8000-000000000130', '56000000-0000-4000-8000-000000000110', 1);

create temporary table pickup_arrival_test_commands (name text primary key, body jsonb not null) on commit drop;
insert into pickup_arrival_test_commands values
('arrival', jsonb_build_object(
  'schemaVersion', 1, 'commandType', 'round.confirm_pickup_arrival',
  'commandId', '56000000-0000-4000-8000-000000000201',
  'traceId', '56000000-0000-4000-8000-000000000202',
  'idempotencyKey', 'pickup-arrival:ROUND-001:v4',
  'tenantId', '56000000-0000-4000-8000-000000000001',
  'aggregateId', '56000000-0000-4000-8000-000000000130',
  'expectedVersion', 4,
  'occurredFromDeviceAt', '2026-09-06T08:00:00Z',
  'payload', jsonb_build_object(
    'pickupLocationId', '56000000-0000-4000-8000-000000000020',
    'position', jsonb_build_object(
      'latitude', 13.73, 'longitude', 100.57, 'accuracyMeters', 11.5, 'source', 'rounds_os'))
));

select is(
  (public.confirm_round_pickup_arrival_command(
    jsonb_set((select body from pickup_arrival_test_commands where name = 'arrival'), '{expectedVersion}', '5'),
    '56000000-0000-4000-8000-000000000007') -> 'error' ->> 'code'),
  'STALE_VERSION', 'stale Round cannot confirm pickup arrival');
select is(
  (public.confirm_round_pickup_arrival_command(
    jsonb_set((select body from pickup_arrival_test_commands where name = 'arrival'), '{payload,pickupLocationId}', '"56000000-0000-4000-8000-000000000021"'),
    '56000000-0000-4000-8000-000000000007') -> 'error' ->> 'code'),
  'VALIDATION_FAILED', 'client cannot substitute another pickup location');
select is(
  (public.confirm_round_pickup_arrival_command((select body from pickup_arrival_test_commands where name = 'arrival'), '56000000-0000-4000-8000-000000000007') ->> 'status'),
  'committed', 'explicit pickup arrival commits');
select is((select state::text from public.rounds where id = '56000000-0000-4000-8000-000000000130'), 'approved', 'arrival does not pretend custody is active');
select is((select version from public.rounds where id = '56000000-0000-4000-8000-000000000130'), 4::bigint, 'observational arrival does not consume Round version');
select is((select count(*) from public.round_pickup_arrival_events where round_id = '56000000-0000-4000-8000-000000000130'), 1::bigint, 'one pickup arrival is durable');
select is((select pickup_location_id from public.round_pickup_arrival_events where round_id = '56000000-0000-4000-8000-000000000130'), '56000000-0000-4000-8000-000000000020'::uuid, 'authoritative pickup is stored');
select is((select location_source from public.round_pickup_arrival_events where round_id = '56000000-0000-4000-8000-000000000130'), 'rounds_os', 'location provenance is stored');
select is((select accuracy_meters from public.round_pickup_arrival_events where round_id = '56000000-0000-4000-8000-000000000130'), 11.5::double precision, 'measured accuracy is stored');
select is((select count(*) from public.audit_events where action = 'round.pickup_arrival_confirmed' and aggregate_id = '56000000-0000-4000-8000-000000000130'), 1::bigint, 'pickup arrival is audited');
select is((select count(*) from public.domain_event_outbox where event_name = 'round.pickup_arrival_confirmed' and aggregate_id = '56000000-0000-4000-8000-000000000130'), 1::bigint, 'pickup arrival event is staged');
select is((public.confirm_round_pickup_arrival_command((select body from pickup_arrival_test_commands where name = 'arrival'), '56000000-0000-4000-8000-000000000007') ->> 'deduplicated'), 'true', 'pickup arrival retry is deduplicated');
select is(
  (public.confirm_round_pickup_arrival_command(
    jsonb_set((select body from pickup_arrival_test_commands where name = 'arrival'), '{payload,position,accuracyMeters}', '20'),
    '56000000-0000-4000-8000-000000000007') -> 'error' ->> 'code'),
  'IDEMPOTENCY_CONFLICT', 'same idempotency key rejects changed evidence');

set local role authenticated;
select throws_ok(
  $$select public.confirm_round_pickup_arrival_command('{}'::jsonb, '56000000-0000-4000-8000-000000000007')$$,
  '42501', 'permission denied for function confirm_round_pickup_arrival_command',
  'authenticated clients cannot execute pickup arrival directly');
reset role;

select * from finish();
rollback;
