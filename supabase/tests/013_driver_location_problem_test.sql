begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

select has_function('public', 'report_location_problem_command', array['jsonb','uuid'], 'location problem command exists');
select ok(has_function_privilege('service_role', 'public.report_location_problem_command(jsonb,uuid)', 'EXECUTE'), 'API service can report a location problem');
select ok(not has_function_privilege('authenticated', 'public.report_location_problem_command(jsonb,uuid)', 'EXECUTE'), 'driver cannot bypass the API command boundary');

insert into public.tenants (id, slug, display_name)
values ('83000000-0000-4000-8000-000000000001', 'location-problem-test', 'Location Problem Test');
insert into public.persons (id, display_name, email)
values ('83000000-0000-4000-8000-000000000002', 'Location Driver', 'location-driver@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at)
values ('83000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000002', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale)
values ('83000000-0000-4000-8000-000000000010', '83000000-0000-4000-8000-000000000002', 'en');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('83000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.tenant_locations (id, tenant_id, code, display_name, raw_address, position, position_provenance, pickup_contact_name, pickup_contact_phone)
values ('83000000-0000-4000-8000-000000000020', '83000000-0000-4000-8000-000000000001', 'studio', 'UrbanFlowers', 'Pickup truth',
  extensions.st_setsrid(extensions.st_makepoint(100.570000::double precision,13.730000::double precision),4326)::extensions.geography,
  'merchant_verified', 'Mali', '+66000000000');
insert into public.deliveries (id, tenant_id, reference, source_system, external_id, source_payload_hash, service_date, service_timezone, pickup_location_id,
  buyer_name, buyer_phone, recipient_name, recipient_phone, destination_raw_address, destination_position, destination_provenance, state, version, created_by_person_id)
values ('83000000-0000-4000-8000-000000000030', '83000000-0000-4000-8000-000000000001', 'LOCATION-001', 'manual', 'LOCATION-001', repeat('e',64),
  '2026-09-03', 'Asia/Bangkok', '83000000-0000-4000-8000-000000000020', 'Siriporn', '+66900000000', 'Siriporn', '+66900000000', 'Original destination truth',
  extensions.st_setsrid(extensions.st_makepoint(100.550000::double precision,13.750000::double precision),4326)::extensions.geography,
  'dispatcher_pin', 'in_custody', 6, '83000000-0000-4000-8000-000000000002');
insert into public.delivery_stops (id, tenant_id, delivery_id, state, destination_version, version)
values ('83000000-0000-4000-8000-000000000040', '83000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000030', 'active', 1, 5);
insert into public.manifests (id, tenant_id, delivery_id, state, version, locked_at)
values ('83000000-0000-4000-8000-000000000050', '83000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000030', 'draft', 1, null);
insert into public.manifest_items (tenant_id, manifest_id, line_number, description, quantity)
values ('83000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000050', 1, 'Bouquet', 1);
update public.manifests set state='picked_up_locked', version=2, locked_at=now(), updated_at=now()
where id='83000000-0000-4000-8000-000000000050';
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('83000000-0000-4000-8000-000000000060', '83000000-0000-4000-8000-000000000001', 'ROUND-LOCATION-001', '2026-09-03', '83000000-0000-4000-8000-000000000010', 'active', 4);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('83000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000060', '83000000-0000-4000-8000-000000000040', 1);

create temporary table location_command (body jsonb) on commit drop;
insert into location_command values (jsonb_build_object(
  'schemaVersion',1,'commandType','stop.report_location_problem','commandId','83000000-0000-4000-8000-000000000080',
  'traceId','83000000-0000-4000-8000-000000000081','idempotencyKey','location:LOCATION-001','tenantId','83000000-0000-4000-8000-000000000001',
  'aggregateId','83000000-0000-4000-8000-000000000040','expectedVersion',5,'occurredFromDeviceAt','2026-09-03T05:00:00Z',
  'payload',jsonb_build_object(
    'manifestId','83000000-0000-4000-8000-000000000050','manifestVersion',2,'stage','delivery','category','wrong_pin',
    'detail','Driver is at the actual entrance',
    'position',jsonb_build_object('latitude',13.751000,'longitude',100.551000,'accuracyMeters',8,'source','rounds_os'))));

select is((public.report_location_problem_command(jsonb_set((select body from location_command),'{expectedVersion}','6'), '83000000-0000-4000-8000-000000000002')->'error'->>'code'), 'STALE_VERSION', 'stale Stop cannot report a location problem');
select is((public.report_location_problem_command(jsonb_set((select body from location_command),'{payload,position,latitude}','130'), '83000000-0000-4000-8000-000000000002')->'error'->>'code'), 'VALIDATION_FAILED', 'invalid GPS evidence is rejected');
select is((public.report_location_problem_command((select body from location_command), '83000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'typed delivery location report commits');
select is((select state::text from public.delivery_stops where id='83000000-0000-4000-8000-000000000040'), 'exception', 'Stop enters an Operations hold');
select is((select state::text from public.deliveries where id='83000000-0000-4000-8000-000000000030'), 'exception', 'delivery enters an Operations hold');
select is((select state::text from public.manifests where id='83000000-0000-4000-8000-000000000050'), 'picked_up_locked', 'locked custody manifest is unchanged');
select is((select version from public.manifests where id='83000000-0000-4000-8000-000000000050'), 2::bigint, 'manifest version is unchanged');
select is((select destination_version from public.delivery_stops where id='83000000-0000-4000-8000-000000000040'), 1::bigint, 'observation does not change destination version');
select is((select destination_raw_address from public.deliveries where id='83000000-0000-4000-8000-000000000030'), 'Original destination truth', 'observation does not overwrite address truth');
select is((select category::text from public.delivery_exceptions where stop_id='83000000-0000-4000-8000-000000000040'), 'wrong_pin', 'location category is typed');
select is((select stage from public.delivery_exceptions where stop_id='83000000-0000-4000-8000-000000000040'), 'delivery', 'custody stage is retained');
select is((select original_stop_state::text from public.delivery_exceptions where stop_id='83000000-0000-4000-8000-000000000040'), 'active', 'original Stop state is retained for future explicit resolution');
select is((select original_delivery_state::text from public.delivery_exceptions where stop_id='83000000-0000-4000-8000-000000000040'), 'in_custody', 'original custody state is retained');
select is((select expected_raw_address from public.delivery_exceptions where stop_id='83000000-0000-4000-8000-000000000040'), 'Original destination truth', 'server snapshots expected address truth');
select is(round((select observed_accuracy_meters from public.delivery_exceptions where stop_id='83000000-0000-4000-8000-000000000040')::numeric, 0), 8::numeric, 'real-device accuracy is retained');
select is(round((select extensions.st_y(observed_position::extensions.geometry) from public.delivery_exceptions where stop_id='83000000-0000-4000-8000-000000000040')::numeric, 3), 13.751::numeric, 'observed latitude is retained');
select is((select count(*) from public.audit_events where action='stop.location_problem_reported' and aggregate_id='83000000-0000-4000-8000-000000000040'), 1::bigint, 'location report is audited once');
select is((select semantic_change->>'destinationMutation' from public.audit_events where action='stop.location_problem_reported' and aggregate_id='83000000-0000-4000-8000-000000000040'), 'false', 'audit proves the destination was not mutated');
select is((select count(*) from public.domain_event_outbox where event_name='stop.location_problem_reported' and aggregate_id='83000000-0000-4000-8000-000000000040'), 1::bigint, 'location event is staged once');
select is((select count(*) from public.operations_threads where stop_id='83000000-0000-4000-8000-000000000040'), 1::bigint, 'Operations thread is created');
select is((select sender::text from public.operations_messages where command_id='83000000-0000-4000-8000-000000000080'), 'system', 'thread records a system location report');
select throws_ok(
  $$update public.delivery_exceptions set status='resolved', resolved_at=now() where stop_id='83000000-0000-4000-8000-000000000040'$$,
  '23514',
  'LOCATION_RESOLUTION_POLICY_REQUIRED',
  'generic resolution cannot bypass the unapproved location-correction policy'
);
select is((public.report_location_problem_command((select body from location_command), '83000000-0000-4000-8000-000000000002')->>'deduplicated'), 'true', 'retry is safely deduplicated');

select * from finish();
rollback;
