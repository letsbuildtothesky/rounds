begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

select has_function('public', 'report_driver_emergency_command', array['jsonb','uuid'], 'driver emergency command exists');
select ok(has_function_privilege('service_role', 'public.report_driver_emergency_command(jsonb,uuid)', 'EXECUTE'), 'API service can report an emergency');
select ok(not has_function_privilege('authenticated', 'public.report_driver_emergency_command(jsonb,uuid)', 'EXECUTE'), 'driver cannot bypass the API command boundary');
select ok(not has_table_privilege('authenticated', 'public.driver_emergency_events', 'SELECT'), 'driver cannot read emergency evidence directly');

insert into public.tenants (id, slug, display_name)
values ('86000000-0000-4000-8000-000000000001', 'driver-emergency-test', 'Driver Emergency Test');
insert into public.persons (id, display_name, email)
values ('86000000-0000-4000-8000-000000000002', 'Emergency Driver', 'emergency-driver@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at)
values ('86000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000002', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale)
values ('86000000-0000-4000-8000-000000000010', '86000000-0000-4000-8000-000000000002', 'en');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('86000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.tenant_locations (id, tenant_id, code, display_name, raw_address, position, position_provenance, pickup_contact_name, pickup_contact_phone)
values ('86000000-0000-4000-8000-000000000020', '86000000-0000-4000-8000-000000000001', 'studio', 'UrbanFlowers', 'Pickup truth',
  extensions.st_setsrid(extensions.st_makepoint(100.570000::double precision,13.730000::double precision),4326)::extensions.geography,
  'merchant_verified', 'Mali', '+66000000000');
insert into public.deliveries (id, tenant_id, reference, source_system, external_id, source_payload_hash, service_date, service_timezone, pickup_location_id,
  buyer_name, buyer_phone, recipient_name, recipient_phone, destination_raw_address, destination_position, destination_provenance, state, version, created_by_person_id)
values ('86000000-0000-4000-8000-000000000030', '86000000-0000-4000-8000-000000000001', 'EMERGENCY-001', 'manual', 'EMERGENCY-001', repeat('f',64),
  '2026-09-03', 'Asia/Bangkok', '86000000-0000-4000-8000-000000000020', 'Siriporn', '+66900000000', 'Siriporn', '+66900000000', 'Destination truth',
  extensions.st_setsrid(extensions.st_makepoint(100.550000::double precision,13.750000::double precision),4326)::extensions.geography,
  'dispatcher_pin', 'in_custody', 6, '86000000-0000-4000-8000-000000000002');
insert into public.delivery_stops (id, tenant_id, delivery_id, state, destination_version, version)
values ('86000000-0000-4000-8000-000000000040', '86000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000030', 'active', 1, 5);
insert into public.manifests (id, tenant_id, delivery_id, state, version)
values ('86000000-0000-4000-8000-000000000050', '86000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000030', 'draft', 1);
insert into public.manifest_items (tenant_id, manifest_id, line_number, description, quantity)
values ('86000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000050', 1, 'Bouquet', 1);
update public.manifests set state='picked_up_locked', version=2, locked_at=now(), updated_at=now()
where id='86000000-0000-4000-8000-000000000050';
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('86000000-0000-4000-8000-000000000060', '86000000-0000-4000-8000-000000000001', 'ROUND-EMERGENCY-001', '2026-09-03', '86000000-0000-4000-8000-000000000010', 'active', 4);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('86000000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000060', '86000000-0000-4000-8000-000000000040', 1);

create temporary table emergency_command (body jsonb) on commit drop;
insert into emergency_command values (jsonb_build_object(
  'schemaVersion',1,'commandType','stop.report_driver_emergency','commandId','86000000-0000-4000-8000-000000000080',
  'traceId','86000000-0000-4000-8000-000000000081','idempotencyKey','emergency:EMERGENCY-001','tenantId','86000000-0000-4000-8000-000000000001',
  'aggregateId','86000000-0000-4000-8000-000000000040','expectedVersion',5,'occurredFromDeviceAt','2026-09-03T05:00:00Z',
  'payload',jsonb_build_object(
    'manifestId','86000000-0000-4000-8000-000000000050','manifestVersion',2,'safetyStatus','urgent',
    'position',jsonb_build_object('latitude',13.751000,'longitude',100.551000,'accuracyMeters',8,'source','rounds_os'))));

select is((public.report_driver_emergency_command(jsonb_set((select body from emergency_command),'{payload,safetyStatus}','"unknown"'), '86000000-0000-4000-8000-000000000002')->'error'->>'code'), 'VALIDATION_FAILED', 'unknown safety status is rejected');
select is((public.report_driver_emergency_command(jsonb_set((select body from emergency_command),'{expectedVersion}','6'), '86000000-0000-4000-8000-000000000002')->'error'->>'code'), 'STALE_VERSION', 'stale Stop cannot report an emergency');
select is((public.report_driver_emergency_command((select body from emergency_command), '86000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'typed driver emergency commits');
select is((select state::text from public.delivery_stops where id='86000000-0000-4000-8000-000000000040'), 'exception', 'Stop enters an emergency hold');
select is((select state::text from public.deliveries where id='86000000-0000-4000-8000-000000000030'), 'exception', 'delivery enters an emergency hold');
select is((select state::text from public.manifests where id='86000000-0000-4000-8000-000000000050'), 'picked_up_locked', 'custody manifest remains locked');
select is((select category::text from public.delivery_exceptions where stop_id='86000000-0000-4000-8000-000000000040'), 'emergency', 'exception category is emergency');
select is((select safety_status from public.driver_emergency_events where stop_id='86000000-0000-4000-8000-000000000040'), 'urgent', 'typed safety status is durable');
select is((select location_source from public.driver_emergency_events where stop_id='86000000-0000-4000-8000-000000000040'), 'rounds_os', 'location provenance is durable');
select is(round((select extensions.st_y(position::extensions.geometry) from public.driver_emergency_events where stop_id='86000000-0000-4000-8000-000000000040')::numeric, 3), 13.751::numeric, 'emergency latitude is durable');
select is((select priority from public.operations_threads where stop_id='86000000-0000-4000-8000-000000000040'), 'emergency', 'Operations thread is raised to emergency priority');
select like((select body from public.operations_messages where command_id='86000000-0000-4000-8000-000000000080'), 'DRIVER EMERGENCY%', 'thread contains an obvious emergency system message');
select is((select count(*) from public.audit_events where action='stop.driver_emergency_reported' and aggregate_id='86000000-0000-4000-8000-000000000040'), 1::bigint, 'emergency is audited once');
select is((select count(*) from public.domain_event_outbox where event_name='stop.driver_emergency_reported' and aggregate_id='86000000-0000-4000-8000-000000000040'), 1::bigint, 'emergency domain event is staged once');
select is((select version from public.rounds where id='86000000-0000-4000-8000-000000000060'), 5::bigint, 'Round version advances to protect assignment truth');
select throws_ok(
  $$update public.delivery_exceptions set status='resolved', resolved_at=now() where stop_id='86000000-0000-4000-8000-000000000040'$$,
  '23514', 'EMERGENCY_RESOLUTION_POLICY_REQUIRED',
  'generic resolution cannot bypass the emergency safety policy');
select is((public.report_driver_emergency_command((select body from emergency_command), '86000000-0000-4000-8000-000000000002')->>'deduplicated'), 'true', 'emergency retry is safely deduplicated');

select * from finish();
rollback;
