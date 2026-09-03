begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

select has_table('public', 'vehicle_profiles', 'vehicle profiles store explicit planning rules');
select has_table('public', 'driver_recurring_schedules', 'recurring own-team schedules exist');
select has_table('public', 'driver_shift_exceptions', 'date-specific shift exceptions exist');
select has_function('public', 'set_driver_recurring_schedule_command', array['jsonb', 'uuid'], 'recurring schedule command exists');
select ok(has_function_privilege('service_role', 'public.set_driver_recurring_schedule_command(jsonb,uuid)', 'EXECUTE'), 'API service can configure schedules');

insert into public.tenants (id, slug, display_name, timezone)
values ('95000000-0000-4000-8000-000000000001', 'driver-schedule-test', 'Driver Schedule Test', 'Asia/Bangkok');
insert into public.persons (id, display_name, email) values
  ('95000000-0000-4000-8000-000000000002', 'Johannes Dispatcher', 'johannes-schedule@test.invalid'),
  ('95000000-0000-4000-8000-000000000003', 'Test Driver', 'driver-schedule@test.invalid'),
  ('95000000-0000-4000-8000-000000000004', 'Viewer', 'viewer-schedule@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at) values
  ('95000000-0000-4000-8000-000000000001', '95000000-0000-4000-8000-000000000002', 'dispatcher', 'active', now()),
  ('95000000-0000-4000-8000-000000000001', '95000000-0000-4000-8000-000000000004', 'viewer', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('95000000-0000-4000-8000-000000000010', '95000000-0000-4000-8000-000000000003', 'en', 'Test motorbike');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('95000000-0000-4000-8000-000000000001', '95000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.vehicle_profiles (
  id, tenant_id, code, display_name, vehicle_group, departure_pattern,
  max_stops_per_departure, planning_deliveries_per_block, pickup_turnaround_minutes
) values (
  '95000000-0000-4000-8000-000000000020', '95000000-0000-4000-8000-000000000001',
  'test-bike', 'Test motorbike', 'motorbike', 'return_after_every_delivery', 1, 4, 15
);

create temporary table driver_schedule_command (body jsonb) on commit drop;
insert into driver_schedule_command values (jsonb_build_object(
  'schemaVersion', 1,
  'commandType', 'operations.set_driver_recurring_schedule',
  'commandId', '95000000-0000-4000-8000-000000000030',
  'traceId', '95000000-0000-4000-8000-000000000031',
  'idempotencyKey', 'driver-schedule:test-driver',
  'tenantId', '95000000-0000-4000-8000-000000000001',
  'aggregateId', '95000000-0000-4000-8000-000000000010',
  'expectedVersion', 0,
  'payload', jsonb_build_object(
    'weekdays', jsonb_build_array(1,2,3,4,5), 'startLocal', '08:00', 'endLocal', '18:00',
    'vehicleProfileId', '95000000-0000-4000-8000-000000000020',
    'note', 'TEST FIXTURE — configured by Johannes'
  )
));

select is((public.set_driver_recurring_schedule_command((select body from driver_schedule_command), '95000000-0000-4000-8000-000000000004')->'error'->>'code'), 'NOT_AUTHORIZED', 'viewer cannot configure a schedule');
select is((public.set_driver_recurring_schedule_command((select body from driver_schedule_command), '95000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'dispatcher configures recurring schedule');
select is((select version from public.driver_recurring_schedules where driver_id='95000000-0000-4000-8000-000000000010'), 1::bigint, 'new schedule starts at version one');
select is((select weekdays::text from public.driver_recurring_schedules where driver_id='95000000-0000-4000-8000-000000000010'), '{1,2,3,4,5}', 'ISO weekdays are stored canonically');
select is((select timezone from public.driver_recurring_schedules where driver_id='95000000-0000-4000-8000-000000000010'), 'Asia/Bangkok', 'tenant timezone is server authoritative');
select is((select count(*) from public.audit_events where action='operations.driver_recurring_schedule_set' and aggregate_id='95000000-0000-4000-8000-000000000010'), 1::bigint, 'schedule configuration is audited');
select is((select count(*) from public.domain_event_outbox where event_name='operations.driver_recurring_schedule_set' and aggregate_id='95000000-0000-4000-8000-000000000010'), 1::bigint, 'schedule event is staged');
select is((public.set_driver_recurring_schedule_command((select body from driver_schedule_command), '95000000-0000-4000-8000-000000000002')->>'deduplicated'), 'true', 'schedule retry is deduplicated');
select is((public.set_driver_recurring_schedule_command(jsonb_set(jsonb_set((select body from driver_schedule_command), '{idempotencyKey}', '"driver-schedule:stale"'), '{expectedVersion}', '2'), '95000000-0000-4000-8000-000000000002')->'error'->>'code'), 'STALE_VERSION', 'stale schedule update is rejected');

set local role authenticated;
select throws_ok($$select public.set_driver_recurring_schedule_command('{}'::jsonb, '95000000-0000-4000-8000-000000000002')$$,
  '42501', 'permission denied for function set_driver_recurring_schedule_command', 'authenticated clients cannot call schedule command directly');
reset role;

select * from finish();
rollback;
