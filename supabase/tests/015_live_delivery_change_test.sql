begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

select has_function('public', 'apply_live_delivery_change_command', array['jsonb','uuid'], 'live delivery change command exists');
select has_function('public', 'acknowledge_live_delivery_change_command', array['jsonb','uuid'], 'driver acknowledgement command exists');
select ok(has_function_privilege('service_role', 'public.apply_live_delivery_change_command(jsonb,uuid)', 'EXECUTE'), 'API service can apply a live change');
select ok(not has_function_privilege('authenticated', 'public.apply_live_delivery_change_command(jsonb,uuid)', 'EXECUTE'), 'Operations browser cannot bypass the command boundary');
select ok(not has_table_privilege('authenticated', 'public.live_delivery_changes', 'SELECT'), 'browser cannot read the internal change ledger directly');

insert into public.tenants (id, slug, display_name)
values ('85000000-0000-4000-8000-000000000001', 'live-change-test', 'Live Change Test');
insert into public.persons (id, display_name, email) values
  ('85000000-0000-4000-8000-000000000002', 'Operations', 'live-operations@test.invalid'),
  ('85000000-0000-4000-8000-000000000003', 'Driver', 'live-driver@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at) values
  ('85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000002', 'dispatcher', 'active', now()),
  ('85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000003', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('85000000-0000-4000-8000-000000000010', '85000000-0000-4000-8000-000000000003', 'en', 'Motorbike');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.tenant_locations (id, tenant_id, code, display_name, raw_address, position, position_provenance, pickup_contact_name, pickup_contact_phone)
values ('85000000-0000-4000-8000-000000000020', '85000000-0000-4000-8000-000000000001', 'studio', 'UrbanFlowers', 'Pickup',
  extensions.st_setsrid(extensions.st_makepoint(100.570000::double precision,13.730000::double precision),4326)::extensions.geography,
  'merchant_verified', 'Operations', '+66000000000');
insert into public.deliveries (id, tenant_id, reference, source_system, external_id, source_payload_hash, service_date, service_timezone, pickup_location_id,
  buyer_name, buyer_phone, recipient_name, recipient_phone, destination_raw_address, destination_position, destination_provenance, access_note, state, version, created_by_person_id)
values ('85000000-0000-4000-8000-000000000030', '85000000-0000-4000-8000-000000000001', 'LIVE-001', 'manual', 'LIVE-001', repeat('f',64),
  '2026-09-03', 'Asia/Bangkok', '85000000-0000-4000-8000-000000000020', 'Siriporn', '+66900000000', 'Siriporn', '+66900000000', 'Original address',
  extensions.st_setsrid(extensions.st_makepoint(100.550000::double precision,13.750000::double precision),4326)::extensions.geography,
  'dispatcher_pin', 'Tower A lobby', 'in_custody', 6, '85000000-0000-4000-8000-000000000002');
insert into public.delivery_promises (id, tenant_id, delivery_id, window_start, window_end)
values ('85000000-0000-4000-8000-000000000031', '85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000030', '2026-09-03T07:00:00Z', '2026-09-03T09:00:00Z');
insert into public.delivery_stops (id, tenant_id, delivery_id, state, destination_version, version)
values ('85000000-0000-4000-8000-000000000040', '85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000030', 'active', 2, 5);
insert into public.manifests (id, tenant_id, delivery_id, state, version, locked_at)
values ('85000000-0000-4000-8000-000000000050', '85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000030', 'picked_up_locked', 2, now());
insert into public.manifest_items (tenant_id, manifest_id, line_number, description, quantity)
values ('85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000050', 1, 'Bouquet', 1);
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('85000000-0000-4000-8000-000000000060', '85000000-0000-4000-8000-000000000001', 'ROUND-LIVE-001', '2026-09-03', '85000000-0000-4000-8000-000000000010', 'active', 4);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000060', '85000000-0000-4000-8000-000000000040', 1);
insert into public.manifest_verifications (id, tenant_id, manifest_id, manifest_version, delivery_id, stop_id, round_id, driver_id, stage,
  confirmed_line_numbers, verified_units, expected_units, actor_person_id, verified_at, command_id)
values ('85000000-0000-4000-8000-000000000070', '85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000050', 2,
  '85000000-0000-4000-8000-000000000030', '85000000-0000-4000-8000-000000000040', '85000000-0000-4000-8000-000000000060',
  '85000000-0000-4000-8000-000000000010', 'pickup', array[1], 1, 1, '85000000-0000-4000-8000-000000000003', now(), '85000000-0000-4000-8000-000000000071');

create temporary table live_change_commands (name text primary key, body jsonb not null) on commit drop;
insert into live_change_commands values ('apply', jsonb_build_object(
  'schemaVersion',1,'commandType','delivery.apply_live_change','commandId','85000000-0000-4000-8000-000000000080',
  'traceId','85000000-0000-4000-8000-000000000081','idempotencyKey','live:LIVE-001','tenantId','85000000-0000-4000-8000-000000000001',
  'aggregateId','85000000-0000-4000-8000-000000000040','expectedVersion',5,'occurredFromDeviceAt','2026-09-03T06:00:00Z',
  'payload',jsonb_build_object(
    'roundId','85000000-0000-4000-8000-000000000060','stopId','85000000-0000-4000-8000-000000000040',
    'expectedRoundVersion',4,'expectedStopVersion',5,'expectedDestinationVersion',2,
    'changes',jsonb_build_object('accessNote','Gate B'),
    'before',jsonb_build_object('sequence',1,'rawAddress','Original address','latitude',13.75,'longitude',100.55,'accessNote','Tower A lobby','windowStart','2026-09-03T07:00:00Z','windowEnd','2026-09-03T09:00:00Z'),
    'after',jsonb_build_object('sequence',1,'rawAddress','Original address','latitude',13.75,'longitude',100.55,'accessNote','Gate B','windowStart','2026-09-03T07:00:00Z','windowEnd','2026-09-03T09:00:00Z'),
    'impact',jsonb_build_object('distanceDeltaMeters',0,'durationDeltaSeconds',120,'etaAfter','2026-09-03T06:20:00Z','downstreamStopCount',0,'promiseStatus','safe','shiftSafe',true),
    'routePlan',jsonb_build_object('status','fits','blockingReasons',jsonb_build_array(),'stopIds',jsonb_build_array('85000000-0000-4000-8000-000000000040')),
    'stopOrderAfter',jsonb_build_array('85000000-0000-4000-8000-000000000040')
  )
));

select is((public.apply_live_delivery_change_command(jsonb_set((select body from live_change_commands where name='apply'),'{expectedVersion}','6'), '85000000-0000-4000-8000-000000000002')->'error'->>'code'), 'STALE_VERSION', 'stale live change is rejected');
select is((public.apply_live_delivery_change_command((select body from live_change_commands where name='apply'), '85000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'versioned live change commits');
select is((select access_note from public.deliveries where id='85000000-0000-4000-8000-000000000030'), 'Gate B', 'access instruction changes');
select is((select destination_version from public.delivery_stops where id='85000000-0000-4000-8000-000000000040'), 3::bigint, 'destination version advances');
select is((select version from public.rounds where id='85000000-0000-4000-8000-000000000060'), 5::bigint, 'Round version advances');
select is((select state::text from public.manifests where id='85000000-0000-4000-8000-000000000050'), 'picked_up_locked', 'physical manifest stays locked');
select is((select count(*) from public.live_delivery_changes where stop_id='85000000-0000-4000-8000-000000000040' and driver_ack_status='pending'), 1::bigint, 'Driver acknowledgement is pending');
select is((select count(*) from public.audit_events where action='delivery.live_changed' and aggregate_id='85000000-0000-4000-8000-000000000040'), 1::bigint, 'live change is audited');
select is((select count(*) from public.domain_event_outbox where event_name='delivery.live_changed' and aggregate_id='85000000-0000-4000-8000-000000000040'), 1::bigint, 'live change event is staged');
select is((public.apply_live_delivery_change_command((select body from live_change_commands where name='apply'), '85000000-0000-4000-8000-000000000002')->>'deduplicated'), 'true', 'live change retry is idempotent');

insert into live_change_commands values ('ack', jsonb_build_object(
  'schemaVersion',1,'commandType','driver.acknowledge_live_change','commandId','85000000-0000-4000-8000-000000000082',
  'traceId','85000000-0000-4000-8000-000000000083','idempotencyKey','ack:LIVE-001','tenantId','85000000-0000-4000-8000-000000000001',
  'aggregateId',(select id from public.live_delivery_changes where stop_id='85000000-0000-4000-8000-000000000040'),
  'expectedVersion',1,'occurredFromDeviceAt','2026-09-03T06:02:00Z',
  'payload',jsonb_build_object('changeId',(select id from public.live_delivery_changes where stop_id='85000000-0000-4000-8000-000000000040'),'expectedChangeVersion',1)
));
select is((public.acknowledge_live_delivery_change_command((select body from live_change_commands where name='ack'), '85000000-0000-4000-8000-000000000002')->'error'->>'code'), 'NOT_AUTHORIZED', 'Operations cannot acknowledge for the Driver');
select is((public.acknowledge_live_delivery_change_command((select body from live_change_commands where name='ack'), '85000000-0000-4000-8000-000000000003')->>'status'), 'committed', 'assigned Driver acknowledges');
select is((select driver_ack_status from public.live_delivery_changes where stop_id='85000000-0000-4000-8000-000000000040'), 'acknowledged', 'acknowledgement state is durable');
select ok((select acknowledged_at is not null from public.live_delivery_changes where stop_id='85000000-0000-4000-8000-000000000040'), 'acknowledgement is timestamped');
select is((select count(*) from public.domain_event_outbox where event_name='delivery.live_change_acknowledged'), 1::bigint, 'acknowledgement event is staged');
select is((public.acknowledge_live_delivery_change_command((select body from live_change_commands where name='ack'), '85000000-0000-4000-8000-000000000003')->>'deduplicated'), 'true', 'acknowledgement retry is idempotent');
select is((select count(*) from public.operations_messages where thread_id in (select id from public.operations_threads where stop_id='85000000-0000-4000-8000-000000000040')), 2::bigint, 'Operations thread records apply and acknowledge');

select * from finish();
rollback;
