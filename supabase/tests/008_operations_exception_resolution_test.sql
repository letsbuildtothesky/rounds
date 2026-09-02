begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select has_function('public', 'resolve_operations_exception_command', array['jsonb', 'uuid'], 'Operations exception resolution command exists');
select ok(has_function_privilege('service_role', 'public.resolve_operations_exception_command(jsonb,uuid)', 'EXECUTE'), 'API service can resolve exceptions');

insert into public.tenants (id, slug, display_name) values ('80000000-0000-4000-8000-000000000001', 'exception-resolution-test', 'Exception Resolution Test');
insert into public.persons (id, display_name, email) values
  ('80000000-0000-4000-8000-000000000002', 'Dispatcher', 'dispatcher-resolution@test.invalid'),
  ('80000000-0000-4000-8000-000000000003', 'Viewer', 'viewer-resolution@test.invalid'),
  ('80000000-0000-4000-8000-000000000004', 'Driver', 'driver-resolution@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at) values
  ('80000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000002', 'dispatcher', 'active', now()),
  ('80000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000003', 'viewer', 'active', now()),
  ('80000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000004', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale) values ('80000000-0000-4000-8000-000000000010', '80000000-0000-4000-8000-000000000004', 'en');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('80000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.tenant_locations (id, tenant_id, code, display_name, raw_address, position, position_provenance, pickup_contact_name, pickup_contact_phone)
values ('80000000-0000-4000-8000-000000000020', '80000000-0000-4000-8000-000000000001', 'studio', 'Studio', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.57::double precision, 13.73::double precision), 4326)::extensions.geography,
  'merchant_verified', 'Dispatch', '+66000000000');
insert into public.deliveries (id, tenant_id, reference, source_system, external_id, source_payload_hash, service_date, service_timezone, pickup_location_id,
  buyer_name, buyer_phone, recipient_name, recipient_phone, destination_raw_address, destination_position, destination_provenance, state, version, created_by_person_id)
values ('80000000-0000-4000-8000-000000000030', '80000000-0000-4000-8000-000000000001', 'RESOLVE-001', 'manual', 'RESOLVE-001', repeat('c',64),
  '2026-09-02', 'Asia/Bangkok', '80000000-0000-4000-8000-000000000020', 'Recipient', '+66900000000', 'Recipient', '+66900000000', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.55::double precision, 13.75::double precision), 4326)::extensions.geography, 'dispatcher_pin', 'exception', 4,
  '80000000-0000-4000-8000-000000000002');
insert into public.delivery_stops (id, tenant_id, delivery_id, state, version)
values ('80000000-0000-4000-8000-000000000040', '80000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000030', 'exception', 3);
insert into public.manifests (id, tenant_id, delivery_id, state, version)
values ('80000000-0000-4000-8000-000000000050', '80000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000030', 'draft', 1);
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('80000000-0000-4000-8000-000000000060', '80000000-0000-4000-8000-000000000001', 'ROUND-RESOLVE-001', '2026-09-02', '80000000-0000-4000-8000-000000000010', 'loading', 2);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('80000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000060', '80000000-0000-4000-8000-000000000040', 1);
insert into public.delivery_exceptions (id, tenant_id, delivery_id, stop_id, round_id, driver_id, manifest_id, manifest_version, stage, category, note, status, actor_person_id, command_id)
values ('80000000-0000-4000-8000-000000000070', '80000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000030',
  '80000000-0000-4000-8000-000000000040', '80000000-0000-4000-8000-000000000060', '80000000-0000-4000-8000-000000000010',
  '80000000-0000-4000-8000-000000000050', 1, 'pickup', 'missing_item', 'Bouquet missing', 'open',
  '80000000-0000-4000-8000-000000000004', '80000000-0000-4000-8000-000000000071');

create temporary table resolution_command (body jsonb) on commit drop;
insert into resolution_command values (jsonb_build_object(
  'schemaVersion',1,'commandType','operations.resolve_exception','commandId','80000000-0000-4000-8000-000000000080',
  'traceId','80000000-0000-4000-8000-000000000081','idempotencyKey','resolve:RESOLVE-001','tenantId','80000000-0000-4000-8000-000000000001',
  'aggregateId','80000000-0000-4000-8000-000000000040','expectedVersion',3,
  'payload',jsonb_build_object('exceptionId','80000000-0000-4000-8000-000000000070','resolution','pickup_corrected','note','Bouquet located and checked by Operations')));

select is((public.resolve_operations_exception_command((select body from resolution_command), '80000000-0000-4000-8000-000000000003')->'error'->>'code'), 'NOT_AUTHORIZED', 'viewer cannot resolve');
select is((public.resolve_operations_exception_command(jsonb_set((select body from resolution_command),'{expectedVersion}','4'), '80000000-0000-4000-8000-000000000002')->'error'->>'code'), 'STALE_VERSION', 'stale Stop cannot resolve');
select is((public.resolve_operations_exception_command((select body from resolution_command), '80000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'dispatcher resolves corrected pickup');
select is((select status::text from public.delivery_exceptions where id='80000000-0000-4000-8000-000000000070'), 'resolved', 'exception is resolved');
select ok((select resolved_at is not null from public.delivery_exceptions where id='80000000-0000-4000-8000-000000000070'), 'resolution is timestamped');
select is((select state::text from public.delivery_stops where id='80000000-0000-4000-8000-000000000040'), 'assigned', 'Stop returns to assigned');
select is((select state::text from public.deliveries where id='80000000-0000-4000-8000-000000000030'), 'assigned', 'delivery returns to assigned');
select is((select count(*) from public.audit_events where action='operations.exception_resolved' and aggregate_id='80000000-0000-4000-8000-000000000040'), 1::bigint, 'resolution is audited');
select is((select count(*) from public.domain_event_outbox where event_name='operations.exception_resolved' and aggregate_id='80000000-0000-4000-8000-000000000040'), 1::bigint, 'resolution event is staged');
select is((public.resolve_operations_exception_command((select body from resolution_command), '80000000-0000-4000-8000-000000000002')->>'deduplicated'), 'true', 'retry is deduplicated');

set local role authenticated;
select throws_ok($$select public.resolve_operations_exception_command('{}'::jsonb, '80000000-0000-4000-8000-000000000002')$$,
  '42501','permission denied for function resolve_operations_exception_command','authenticated clients cannot call resolution command directly');
reset role;

select * from finish();
rollback;
