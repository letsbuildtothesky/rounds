begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

select has_table('public', 'driver_shift_attendance', 'explicit Team shift attendance exists');
select has_function('public', 'start_driver_shift_command', array['jsonb','uuid'], 'B00 start command exists');
select ok(has_function_privilege('service_role', 'public.start_driver_shift_command(jsonb,uuid)', 'EXECUTE'), 'API service can start a Team shift');
select ok(not has_function_privilege('authenticated', 'public.start_driver_shift_command(jsonb,uuid)', 'EXECUTE'), 'mobile clients cannot execute the command directly');

insert into public.tenants (id, slug, display_name, timezone)
values ('99000000-0000-4000-8000-000000000001', 'driver-shift-start-test', 'Driver Shift Start Test', 'Asia/Bangkok');
insert into public.persons (id, display_name, email) values
  ('99000000-0000-4000-8000-000000000002', 'Johannes Test Driver', 'johannes-shift@test.invalid'),
  ('99000000-0000-4000-8000-000000000003', 'Shift Viewer', 'viewer-shift@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at) values
  ('99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-000000000002', 'team_driver', 'active', now()),
  ('99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-000000000003', 'viewer', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('99000000-0000-4000-8000-000000000010', '99000000-0000-4000-8000-000000000002', 'en', 'Shift Test Bike');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.vehicle_profiles (
  id, tenant_id, code, display_name, vehicle_group, departure_pattern,
  max_stops_per_departure, planning_deliveries_per_block, pickup_turnaround_minutes
) values (
  '99000000-0000-4000-8000-000000000020', '99000000-0000-4000-8000-000000000001',
  'shift-test-bike', 'Shift Test Bike', 'motorbike', 'multi_stop', 4, 4, 15
);
insert into public.driver_recurring_schedules (
  tenant_id, driver_id, weekdays, start_local, end_local, timezone, vehicle_profile_id
) values (
  '99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-000000000010',
  array[extract(isodow from (now() at time zone 'Asia/Bangkok')::date)::smallint],
  ((now() at time zone 'Asia/Bangkok')::time - interval '1 hour')::time,
  ((now() at time zone 'Asia/Bangkok')::time + interval '2 hours')::time,
  'Asia/Bangkok', '99000000-0000-4000-8000-000000000020'
);

create temporary table driver_shift_start_command (body jsonb) on commit drop;
insert into driver_shift_start_command values (jsonb_build_object(
  'schemaVersion', 1,
  'commandType', 'driver.start_shift',
  'commandId', '99000000-0000-4000-8000-000000000030',
  'traceId', '99000000-0000-4000-8000-000000000031',
  'idempotencyKey', 'driver-shift:start:test-driver',
  'tenantId', '99000000-0000-4000-8000-000000000001',
  'aggregateId', '99000000-0000-4000-8000-000000000010',
  'expectedVersion', 0,
  'occurredFromDeviceAt', '2020-01-01T00:00:00Z',
  'payload', jsonb_build_object(
    'serviceDate', ((now() at time zone 'Asia/Bangkok')::date)::text
  )
));

select is(
  (public.start_driver_shift_command((select body from driver_shift_start_command), '99000000-0000-4000-8000-000000000003')->'error'->>'code'),
  'NOT_AUTHORIZED', 'viewer cannot start the Driver shift'
);
select is(
  (public.start_driver_shift_command((select body from driver_shift_start_command), '99000000-0000-4000-8000-000000000002')->>'status'),
  'committed', 'active Team Driver starts the effective shift'
);
select is((select count(*) from public.driver_shift_attendance where driver_id='99000000-0000-4000-8000-000000000010'), 1::bigint, 'one attendance record is created');
select is((select schedule_source from public.driver_shift_attendance where driver_id='99000000-0000-4000-8000-000000000010'), 'recurring', 'attendance snapshots the effective schedule source');
select isnt((select started_at::text from public.driver_shift_attendance where driver_id='99000000-0000-4000-8000-000000000010'), '2020-01-01 00:00:00+00', 'server time, not device time, is authoritative');
select is((select started_from_device_at::text from public.driver_shift_attendance where driver_id='99000000-0000-4000-8000-000000000010'), '2020-01-01 00:00:00+00', 'device occurrence time remains evidence');
select is((select count(*) from public.audit_events where action='driver.shift_started' and aggregate_id in (select id from public.driver_shift_attendance where driver_id='99000000-0000-4000-8000-000000000010')), 1::bigint, 'shift start is audited');
select is((select count(*) from public.domain_event_outbox where event_name='driver.shift_started' and aggregate_id in (select id from public.driver_shift_attendance where driver_id='99000000-0000-4000-8000-000000000010')), 1::bigint, 'shift-start event is staged');
select is((public.start_driver_shift_command((select body from driver_shift_start_command), '99000000-0000-4000-8000-000000000002')->>'deduplicated'), 'true', 'same start command is safely deduplicated');
select is(
  (public.start_driver_shift_command(
    jsonb_set(jsonb_set((select body from driver_shift_start_command), '{commandId}', '"99000000-0000-4000-8000-000000000032"'), '{idempotencyKey}', '"driver-shift:start:duplicate"'),
    '99000000-0000-4000-8000-000000000002'
  )->'error'->>'code'),
  'INVALID_STATE', 'a second distinct command cannot start the same shift twice'
);
select is(
  (public.start_driver_shift_command(
    jsonb_set(jsonb_set(jsonb_set((select body from driver_shift_start_command), '{commandId}', '"99000000-0000-4000-8000-000000000033"'), '{idempotencyKey}', '"driver-shift:start:wrong-date"'), '{payload,serviceDate}', '"2000-01-01"'),
    '99000000-0000-4000-8000-000000000002'
  )->'error'->>'code'),
  'INVALID_STATE', 'Driver cannot start a shift for another local service date'
);
select is((select count(*) from public.driver_shift_attendance where driver_id='99000000-0000-4000-8000-000000000010'), 1::bigint, 'retries and rejected attempts never duplicate attendance');

set local role authenticated;
select throws_ok(
  $$select * from public.driver_shift_attendance$$,
  '42501', 'permission denied for table driver_shift_attendance',
  'authenticated clients cannot read attendance storage directly'
);
reset role;

select * from finish();
rollback;
