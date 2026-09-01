begin;

create extension if not exists pgtap with schema extensions;
select plan(24);

select has_function('public', 'confirm_round_pickup_command', array['jsonb', 'uuid'], 'pickup command exists');
select ok(
  has_function_privilege('service_role', 'public.confirm_round_pickup_command(jsonb,uuid)', 'EXECUTE'),
  'API service can execute pickup command'
);
select ok(not has_table_privilege('authenticated', 'public.manifest_verifications', 'SELECT'), 'browser cannot read verification evidence directly');
select ok(not has_table_privilege('authenticated', 'public.custody_events', 'SELECT'), 'browser cannot read custody evidence directly');

insert into public.tenants (id, slug, display_name)
values ('40000000-0000-4000-8000-000000000001', 'pickup-test', 'Pickup Test');
insert into public.persons (id, display_name, email)
values ('40000000-0000-4000-8000-000000000007', 'Pickup Driver', 'pickup-driver@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at)
values ('40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000007', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('40000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000007', 'en', 'Motorbike');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000002', 'team', 'active', '{"assigned_work":true}'::jsonb);
insert into public.tenant_locations (
  id, tenant_id, code, display_name, raw_address, position, position_provenance,
  pickup_contact_name, pickup_contact_phone
) values (
  '40000000-0000-4000-8000-000000000020', '40000000-0000-4000-8000-000000000001',
  'studio', 'Pickup Studio', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.57::double precision, 13.73::double precision), 4326)::extensions.geography,
  'merchant_verified', 'Dispatch', '+66000000000'
);
insert into public.deliveries (
  id, tenant_id, reference, source_system, external_id, source_payload_hash,
  service_date, service_timezone, pickup_location_id, buyer_name, buyer_phone,
  recipient_name, recipient_phone, destination_raw_address, destination_position,
  destination_provenance, state, version, created_by_person_id
) values (
  '40000000-0000-4000-8000-000000000100', '40000000-0000-4000-8000-000000000001',
  'PICKUP-001', 'manual', 'PICKUP-001', repeat('a', 64), '2026-09-02', 'Asia/Bangkok',
  '40000000-0000-4000-8000-000000000020', 'Recipient', '+66999999999', 'Recipient', '+66999999999',
  'Bangkok', extensions.st_setsrid(extensions.st_makepoint(100.54::double precision, 13.74::double precision), 4326)::extensions.geography,
  'dispatcher_pin', 'assigned', 3, '40000000-0000-4000-8000-000000000007'
);
insert into public.delivery_stops (id, tenant_id, delivery_id, state, version)
values ('40000000-0000-4000-8000-000000000110', '40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000100', 'assigned', 2);
insert into public.manifests (id, tenant_id, delivery_id, state, version)
values ('40000000-0000-4000-8000-000000000120', '40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000100', 'draft', 1);
insert into public.manifest_items (tenant_id, manifest_id, line_number, description, quantity)
values
  ('40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000120', 1, 'Bouquet', 2),
  ('40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000120', 2, 'Cake', 1);
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('40000000-0000-4000-8000-000000000130', '40000000-0000-4000-8000-000000000001', 'ROUND-PICKUP-001', '2026-09-02', '40000000-0000-4000-8000-000000000002', 'approved', 1);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000130', '40000000-0000-4000-8000-000000000110', 1);

create temporary table pickup_test_commands (name text primary key, body jsonb not null) on commit drop;
insert into pickup_test_commands values ('pickup', jsonb_build_object(
  'schemaVersion', 1, 'commandType', 'round.confirm_pickup',
  'commandId', '40000000-0000-4000-8000-000000000201',
  'traceId', '40000000-0000-4000-8000-000000000202',
  'idempotencyKey', 'pickup:ROUND-PICKUP-001',
  'tenantId', '40000000-0000-4000-8000-000000000001',
  'aggregateId', '40000000-0000-4000-8000-000000000130',
  'expectedVersion', 1,
  'occurredFromDeviceAt', '2026-09-01T12:00:00Z',
  'payload', jsonb_build_object('stops', jsonb_build_array(jsonb_build_object(
    'stopId', '40000000-0000-4000-8000-000000000110',
    'manifestId', '40000000-0000-4000-8000-000000000120',
    'manifestVersion', 1,
    'confirmedLineNumbers', jsonb_build_array(1, 2)
  )))
));

select is(
  (public.confirm_round_pickup_command(jsonb_set((select body from pickup_test_commands where name = 'pickup'), '{expectedVersion}', '2'), '40000000-0000-4000-8000-000000000007') -> 'error' ->> 'code'),
  'STALE_VERSION', 'stale Round version is rejected'
);
select is(
  (public.confirm_round_pickup_command(
    jsonb_set(jsonb_set((select body from pickup_test_commands where name = 'pickup'), '{idempotencyKey}', '"pickup:incomplete"'), '{payload,stops,0,confirmedLineNumbers}', '[1]'),
    '40000000-0000-4000-8000-000000000007'
  ) -> 'error' ->> 'code'),
  'EVIDENCE_REQUIRED', 'missing physical line blocks custody'
);
select is((select count(*) from public.custody_events where round_id = '40000000-0000-4000-8000-000000000130'), 0::bigint, 'failed verification writes no custody');

select is(
  (public.confirm_round_pickup_command((select body from pickup_test_commands where name = 'pickup'), '40000000-0000-4000-8000-000000000007') ->> 'status'),
  'committed', 'complete pickup commits'
);
select is((select state::text from public.rounds where id = '40000000-0000-4000-8000-000000000130'), 'active', 'Round becomes active');
select is((select version from public.rounds where id = '40000000-0000-4000-8000-000000000130'), 2::bigint, 'Round version increments');
select is((select state::text from public.deliveries where id = '40000000-0000-4000-8000-000000000100'), 'in_custody', 'delivery enters custody');
select is((select version from public.deliveries where id = '40000000-0000-4000-8000-000000000100'), 5::bigint, 'pickup transitions increment delivery version');
select is((select state::text from public.delivery_stops where id = '40000000-0000-4000-8000-000000000110'), 'active', 'Stop becomes active');
select is((select state::text from public.manifests where id = '40000000-0000-4000-8000-000000000120'), 'picked_up_locked', 'manifest is custody locked');
select ok((select locked_at is not null from public.manifests where id = '40000000-0000-4000-8000-000000000120'), 'manifest lock is timestamped');
select is((select count(*) from public.manifest_verifications where round_id = '40000000-0000-4000-8000-000000000130'), 1::bigint, 'one pickup verification is durable');
select is((select confirmed_line_numbers from public.manifest_verifications where round_id = '40000000-0000-4000-8000-000000000130'), array[1,2], 'exact line numbers are evidence');
select is((select verified_units from public.manifest_verifications where round_id = '40000000-0000-4000-8000-000000000130'), 3, 'physical quantities are recorded');
select is((select count(*) from public.custody_events where round_id = '40000000-0000-4000-8000-000000000130'), 1::bigint, 'one custody transfer is durable');
select is((select event_type::text from public.custody_events where round_id = '40000000-0000-4000-8000-000000000130'), 'merchant_to_driver', 'custody transfers merchant to driver');
select is((select count(*) from public.audit_events where action = 'round.pickup_confirmed' and aggregate_id = '40000000-0000-4000-8000-000000000130'), 1::bigint, 'pickup is audited');
select is((select count(*) from public.domain_event_outbox where event_name = 'round.pickup_confirmed' and aggregate_id = '40000000-0000-4000-8000-000000000130'), 1::bigint, 'pickup event is staged');
select is(
  (public.confirm_round_pickup_command((select body from pickup_test_commands where name = 'pickup'), '40000000-0000-4000-8000-000000000007') -> 'state' ->> 'roundState'),
  'active', 'retry returns original committed result'
);

set local role authenticated;
select throws_ok(
  $$select public.confirm_round_pickup_command('{}'::jsonb, '40000000-0000-4000-8000-000000000007')$$,
  '42501', 'permission denied for function confirm_round_pickup_command',
  'authenticated clients cannot execute custody command directly'
);
reset role;

select * from finish();
rollback;
