begin;

create extension if not exists pgtap with schema extensions;
select plan(28);

select has_function('public', 'report_pickup_problem_command', array['jsonb', 'uuid'], 'pickup problem command exists');
select has_function('public', 'confirm_stop_arrival_command', array['jsonb', 'uuid'], 'arrival command exists');
select ok(has_function_privilege('service_role', 'public.report_pickup_problem_command(jsonb,uuid)', 'EXECUTE'), 'API service can report pickup problems');
select ok(has_function_privilege('service_role', 'public.confirm_stop_arrival_command(jsonb,uuid)', 'EXECUTE'), 'API service can confirm arrival');
select ok(not has_table_privilege('authenticated', 'public.delivery_exceptions', 'SELECT'), 'driver cannot read exception evidence directly');
select ok(not has_table_privilege('authenticated', 'public.stop_arrival_events', 'SELECT'), 'driver cannot read arrival evidence directly');

insert into public.tenants (id, slug, display_name)
values ('50000000-0000-4000-8000-000000000001', 'driver-command-test', 'Driver Command Test');
insert into public.persons (id, display_name, email)
values ('50000000-0000-4000-8000-000000000007', 'Command Driver', 'command-driver@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at)
values ('50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000007', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('50000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000007', 'en', 'Motorbike');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000002', 'team', 'active', '{"assigned_work":true}'::jsonb);
insert into public.tenant_locations (
  id, tenant_id, code, display_name, raw_address, position, position_provenance,
  pickup_contact_name, pickup_contact_phone
) values (
  '50000000-0000-4000-8000-000000000020', '50000000-0000-4000-8000-000000000001',
  'studio', 'Pickup Studio', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.57::double precision, 13.73::double precision), 4326)::extensions.geography,
  'merchant_verified', 'Dispatch', '+66000000000'
);

insert into public.deliveries (
  id, tenant_id, reference, source_system, external_id, source_payload_hash,
  service_date, service_timezone, pickup_location_id, buyer_name, buyer_phone,
  recipient_name, recipient_phone, destination_raw_address, destination_position,
  destination_provenance, state, version, created_by_person_id
) values
(
  '50000000-0000-4000-8000-000000000100', '50000000-0000-4000-8000-000000000001',
  'PROBLEM-001', 'manual', 'PROBLEM-001', repeat('a', 64), '2026-09-02', 'Asia/Bangkok',
  '50000000-0000-4000-8000-000000000020', 'Recipient', '+66999999999', 'Recipient', '+66999999999',
  'Bangkok', extensions.st_setsrid(extensions.st_makepoint(100.54::double precision, 13.74::double precision), 4326)::extensions.geography,
  'dispatcher_pin', 'assigned', 3, '50000000-0000-4000-8000-000000000007'
),
(
  '50000000-0000-4000-8000-000000000101', '50000000-0000-4000-8000-000000000001',
  'ARRIVAL-001', 'manual', 'ARRIVAL-001', repeat('b', 64), '2026-09-02', 'Asia/Bangkok',
  '50000000-0000-4000-8000-000000000020', 'Recipient', '+66888888888', 'Recipient', '+66888888888',
  'Bangkok', extensions.st_setsrid(extensions.st_makepoint(100.55::double precision, 13.75::double precision), 4326)::extensions.geography,
  'dispatcher_pin', 'in_custody', 5, '50000000-0000-4000-8000-000000000007'
);
insert into public.delivery_stops (id, tenant_id, delivery_id, state, version)
values
  ('50000000-0000-4000-8000-000000000110', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000100', 'assigned', 2),
  ('50000000-0000-4000-8000-000000000111', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000101', 'active', 4);
insert into public.manifests (id, tenant_id, delivery_id, state, version, locked_at)
values
  ('50000000-0000-4000-8000-000000000120', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000100', 'draft', 1, null),
  ('50000000-0000-4000-8000-000000000121', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000101', 'draft', 1, null);
insert into public.manifest_items (tenant_id, manifest_id, line_number, description, quantity)
values
  ('50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000120', 1, 'Bouquet', 1),
  ('50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000121', 1, 'Cake', 1);
update public.manifests set state = 'picked_up_locked', locked_at = now(), updated_at = now()
where id = '50000000-0000-4000-8000-000000000121';
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values
  ('50000000-0000-4000-8000-000000000130', '50000000-0000-4000-8000-000000000001', 'ROUND-PROBLEM-001', '2026-09-02', '50000000-0000-4000-8000-000000000002', 'approved', 1),
  ('50000000-0000-4000-8000-000000000131', '50000000-0000-4000-8000-000000000001', 'ROUND-ARRIVAL-001', '2026-09-02', '50000000-0000-4000-8000-000000000002', 'active', 2);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values
  ('50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000130', '50000000-0000-4000-8000-000000000110', 1),
  ('50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000131', '50000000-0000-4000-8000-000000000111', 1);

create temporary table driver_test_commands (name text primary key, body jsonb not null) on commit drop;
insert into driver_test_commands values
('problem', jsonb_build_object(
  'schemaVersion', 1, 'commandType', 'stop.report_pickup_problem',
  'commandId', '50000000-0000-4000-8000-000000000201',
  'traceId', '50000000-0000-4000-8000-000000000202',
  'idempotencyKey', 'problem:PROBLEM-001',
  'tenantId', '50000000-0000-4000-8000-000000000001',
  'aggregateId', '50000000-0000-4000-8000-000000000110',
  'expectedVersion', 2,
  'occurredFromDeviceAt', '2026-09-01T12:00:00Z',
  'payload', jsonb_build_object(
    'manifestId', '50000000-0000-4000-8000-000000000120',
    'manifestVersion', 1, 'category', 'missing_item', 'note', 'Bouquet is not at pickup')
)),
('arrival', jsonb_build_object(
  'schemaVersion', 1, 'commandType', 'stop.confirm_arrival',
  'commandId', '50000000-0000-4000-8000-000000000211',
  'traceId', '50000000-0000-4000-8000-000000000212',
  'idempotencyKey', 'arrival:ARRIVAL-001',
  'tenantId', '50000000-0000-4000-8000-000000000001',
  'aggregateId', '50000000-0000-4000-8000-000000000111',
  'expectedVersion', 4,
  'occurredFromDeviceAt', '2026-09-01T12:05:00Z',
  'payload', jsonb_build_object('position', jsonb_build_object(
    'latitude', 13.75, 'longitude', 100.55, 'accuracyMeters', 18.5, 'source', 'google_nav'))
));

select is(
  (public.report_pickup_problem_command(jsonb_set((select body from driver_test_commands where name = 'problem'), '{expectedVersion}', '3'), '50000000-0000-4000-8000-000000000007') -> 'error' ->> 'code'),
  'STALE_VERSION', 'stale Stop cannot report a pickup problem');
select is((public.report_pickup_problem_command((select body from driver_test_commands where name = 'problem'), '50000000-0000-4000-8000-000000000007') ->> 'status'), 'committed', 'structured pickup problem commits');
select is((select state::text from public.delivery_stops where id = '50000000-0000-4000-8000-000000000110'), 'exception', 'problem Stop enters exception');
select is((select state::text from public.deliveries where id = '50000000-0000-4000-8000-000000000100'), 'exception', 'problem delivery enters exception through pickup_pending');
select is((select category::text from public.delivery_exceptions where stop_id = '50000000-0000-4000-8000-000000000110'), 'missing_item', 'typed problem category is durable');
select is((select count(*) from public.delivery_exceptions where stop_id = '50000000-0000-4000-8000-000000000110'), 1::bigint, 'one exception record is written');
select is((select count(*) from public.audit_events where action = 'stop.pickup_problem_reported' and aggregate_id = '50000000-0000-4000-8000-000000000110'), 1::bigint, 'pickup problem is audited');
select is((public.report_pickup_problem_command((select body from driver_test_commands where name = 'problem'), '50000000-0000-4000-8000-000000000007') ->> 'deduplicated'), 'true', 'pickup problem retry is deduplicated');

select is(
  (public.confirm_stop_arrival_command(jsonb_set((select body from driver_test_commands where name = 'arrival'), '{expectedVersion}', '5'), '50000000-0000-4000-8000-000000000007') -> 'error' ->> 'code'),
  'STALE_VERSION', 'stale Stop cannot confirm arrival');
select is((public.confirm_stop_arrival_command((select body from driver_test_commands where name = 'arrival'), '50000000-0000-4000-8000-000000000007') ->> 'status'), 'committed', 'explicit arrival commits');
select is((select state::text from public.delivery_stops where id = '50000000-0000-4000-8000-000000000111'), 'arrived', 'arrival Stop enters arrived');
select ok((select arrived_at is not null from public.delivery_stops where id = '50000000-0000-4000-8000-000000000111'), 'Stop arrival is timestamped');
select is((select state::text from public.deliveries where id = '50000000-0000-4000-8000-000000000101'), 'arrived', 'delivery advances through en_route to arrived');
select is((select version from public.deliveries where id = '50000000-0000-4000-8000-000000000101'), 7::bigint, 'delivery transitions increment version twice');
select is((select count(*) from public.stop_arrival_events where stop_id = '50000000-0000-4000-8000-000000000111'), 1::bigint, 'one arrival event is durable');
select is((select location_source from public.stop_arrival_events where stop_id = '50000000-0000-4000-8000-000000000111'), 'google_nav', 'arrival keeps location provenance');
select is((select accuracy_meters from public.stop_arrival_events where stop_id = '50000000-0000-4000-8000-000000000111'), 18.5::double precision, 'arrival keeps measured accuracy');
select is((select count(*) from public.audit_events where action = 'stop.arrival_confirmed' and aggregate_id = '50000000-0000-4000-8000-000000000111'), 1::bigint, 'arrival is audited');
select is((select count(*) from public.domain_event_outbox where event_name = 'stop.arrival_confirmed' and aggregate_id = '50000000-0000-4000-8000-000000000111'), 1::bigint, 'arrival event is staged');
select is((public.confirm_stop_arrival_command((select body from driver_test_commands where name = 'arrival'), '50000000-0000-4000-8000-000000000007') ->> 'deduplicated'), 'true', 'arrival retry is deduplicated');

set local role authenticated;
select throws_ok(
  $$select public.report_pickup_problem_command('{}'::jsonb, '50000000-0000-4000-8000-000000000007')$$,
  '42501', 'permission denied for function report_pickup_problem_command',
  'authenticated clients cannot execute exception command directly');
select throws_ok(
  $$select public.confirm_stop_arrival_command('{}'::jsonb, '50000000-0000-4000-8000-000000000007')$$,
  '42501', 'permission denied for function confirm_stop_arrival_command',
  'authenticated clients cannot execute arrival command directly');
reset role;

select * from finish();
rollback;
