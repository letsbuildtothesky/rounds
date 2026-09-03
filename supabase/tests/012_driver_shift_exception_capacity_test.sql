begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

select has_function('public', 'get_own_team_round_static_capacity', array['uuid','uuid','date','integer'], 'shared static capacity guard exists');
select has_function('public', 'set_driver_shift_exception_command', array['jsonb','uuid'], 'date exception command exists');
select has_function('public', 'clear_driver_shift_exception_command', array['jsonb','uuid'], 'date exception clear command exists');
select ok(has_function_privilege('service_role', 'public.clear_driver_shift_exception_command(jsonb,uuid)', 'EXECUTE'), 'API service can clear a date exception');

insert into public.tenants (id, slug, display_name, timezone)
values ('96000000-0000-4000-8000-000000000001', 'capacity-exception-test', 'Capacity Exception Test', 'Asia/Bangkok');
insert into public.persons (id, display_name, email) values
  ('96000000-0000-4000-8000-000000000002', 'Capacity Dispatcher', 'capacity-dispatcher@test.invalid'),
  ('96000000-0000-4000-8000-000000000003', 'Capacity Driver', 'capacity-driver@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at) values
  ('96000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000002', 'dispatcher', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('96000000-0000-4000-8000-000000000010', '96000000-0000-4000-8000-000000000003', 'en', 'Capacity Bike');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('96000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.vehicle_profiles (
  id, tenant_id, code, display_name, vehicle_group, departure_pattern,
  max_stops_per_departure, planning_deliveries_per_block, pickup_turnaround_minutes
) values (
  '96000000-0000-4000-8000-000000000020', '96000000-0000-4000-8000-000000000001',
  'capacity-bike', 'Capacity Bike', 'motorbike', 'multi_stop', 1, 4, 15
);
insert into public.driver_recurring_schedules (
  tenant_id, driver_id, weekdays, start_local, end_local, timezone, vehicle_profile_id
) values (
  '96000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000010',
  array[1,2,3,4,5]::smallint[], '08:00', '18:00', 'Asia/Bangkok',
  '96000000-0000-4000-8000-000000000020'
);

select is((public.get_own_team_round_static_capacity(
  '96000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000010', '2026-09-02', 1
)->>'valid'), 'true', 'one Stop fits the recurring shift and vehicle profile');
select is((public.get_own_team_round_static_capacity(
  '96000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000010', '2026-09-02', 1
)->'effectiveShift'->>'source'), 'recurring', 'capacity explains the recurring shift source');
select is((public.get_own_team_round_static_capacity(
  '96000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000010', '2026-09-02', 2
)->>'valid'), 'false', 'vehicle Stop maximum blocks an oversized proposal');
select like((public.get_own_team_round_static_capacity(
  '96000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000010', '2026-09-02', 2
)->'reasons'->>0), '%allows 1 Stop per departure%', 'capacity gives the precise vehicle rule');

create temporary table capacity_exception_commands (name text primary key, body jsonb) on commit drop;
insert into capacity_exception_commands values (
  'set-off', jsonb_build_object(
    'schemaVersion',1,'commandType','operations.set_driver_shift_exception',
    'commandId','96000000-0000-4000-8000-000000000030','traceId','96000000-0000-4000-8000-000000000031',
    'idempotencyKey','capacity-exception:set-off','tenantId','96000000-0000-4000-8000-000000000001',
    'aggregateId','96000000-0000-4000-8000-000000000010','expectedVersion',0,
    'payload',jsonb_build_object('serviceDate','2026-09-02','kind','off','note','Capacity guard test'))
  ),
  ('clear-off', jsonb_build_object(
    'schemaVersion',1,'commandType','operations.clear_driver_shift_exception',
    'commandId','96000000-0000-4000-8000-000000000032','traceId','96000000-0000-4000-8000-000000000033',
    'idempotencyKey','capacity-exception:clear-off','tenantId','96000000-0000-4000-8000-000000000001',
    'aggregateId','96000000-0000-4000-8000-000000000010','expectedVersion',1,
    'payload',jsonb_build_object('serviceDate','2026-09-02'))
  );

select is((public.set_driver_shift_exception_command((select body from capacity_exception_commands where name='set-off'), '96000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'dispatcher sets a day-off exception');
select is((public.get_own_team_round_static_capacity(
  '96000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000010', '2026-09-02', 1
)->>'valid'), 'false', 'day-off exception blocks Round approval');
select is((public.clear_driver_shift_exception_command((select body from capacity_exception_commands where name='clear-off'), '96000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'dispatcher restores the recurring schedule');
select is((public.get_own_team_round_static_capacity(
  '96000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000010', '2026-09-02', 1
)->>'valid'), 'true', 'clearing the exception restores recurring capacity');
select is((select count(*) from public.audit_events where aggregate_id='96000000-0000-4000-8000-000000000010'), 2::bigint, 'set and clear are both audited');
select is((select count(*) from public.domain_event_outbox where aggregate_id='96000000-0000-4000-8000-000000000010'), 2::bigint, 'set and clear both stage domain events');

set local role authenticated;
select throws_ok(
  $$select public.clear_driver_shift_exception_command('{}'::jsonb, '96000000-0000-4000-8000-000000000002')$$,
  '42501', 'permission denied for function clear_driver_shift_exception_command',
  'authenticated clients cannot execute the clear command directly'
);
reset role;

select * from finish();
rollback;
