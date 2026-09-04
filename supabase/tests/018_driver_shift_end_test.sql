begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select has_function('public', 'end_driver_shift_command', array['jsonb','uuid'], 'B01F end command exists');
select ok(has_function_privilege('service_role', 'public.end_driver_shift_command(jsonb,uuid)', 'EXECUTE'), 'API service can end a Team shift');
select ok(not has_function_privilege('authenticated', 'public.end_driver_shift_command(jsonb,uuid)', 'EXECUTE'), 'mobile clients cannot execute end directly');

insert into public.tenants (id, slug, display_name, timezone)
values ('97000000-0000-4000-8000-000000000001', 'driver-shift-end-test', 'Driver Shift End Test', 'Asia/Bangkok');
insert into public.persons (id, display_name, email) values
  ('97000000-0000-4000-8000-000000000002', 'Johannes End Test', 'johannes-end@test.invalid'),
  ('97000000-0000-4000-8000-000000000003', 'End Viewer', 'viewer-end@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at) values
  ('97000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000002', 'team_driver', 'active', now()),
  ('97000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000003', 'viewer', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('97000000-0000-4000-8000-000000000010', '97000000-0000-4000-8000-000000000002', 'en', 'End Test Bike');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('97000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.driver_shift_attendance (
  id,tenant_id,driver_id,service_date,timezone,schedule_source,
  scheduled_start_at,scheduled_end_at,started_at,start_command_id
) values (
  '97000000-0000-4000-8000-000000000020','97000000-0000-4000-8000-000000000001',
  '97000000-0000-4000-8000-000000000010',(now() at time zone 'Asia/Bangkok')::date,
  'Asia/Bangkok','recurring',now()-interval '9 hours',now()-interval '1 hour',
  now()-interval '8 hours 22 minutes','97000000-0000-4000-8000-000000000021'
);

create temporary table driver_shift_end_command (body jsonb) on commit drop;
insert into driver_shift_end_command values (jsonb_build_object(
  'schemaVersion',1,'commandType','driver.end_shift',
  'commandId','97000000-0000-4000-8000-000000000030',
  'traceId','97000000-0000-4000-8000-000000000031',
  'idempotencyKey','driver-shift:end:test-driver',
  'tenantId','97000000-0000-4000-8000-000000000001',
  'aggregateId','97000000-0000-4000-8000-000000000020',
  'expectedVersion',1,'occurredFromDeviceAt','2020-01-01T00:00:00Z',
  'payload',jsonb_build_object('attendanceId','97000000-0000-4000-8000-000000000020')
));

select is(
  (public.end_driver_shift_command((select body from driver_shift_end_command),'97000000-0000-4000-8000-000000000003')->'error'->>'code'),
  'NOT_AUTHORIZED','viewer cannot end Driver shift'
);
insert into public.rounds (id,tenant_id,reference,service_date,driver_id,state) values (
  '97000000-0000-4000-8000-000000000040','97000000-0000-4000-8000-000000000001',
  'SHIFT-END-ACTIVE-WORK',(now() at time zone 'Asia/Bangkok')::date,
  '97000000-0000-4000-8000-000000000010','active'
);
select is(
  (public.end_driver_shift_command((select body from driver_shift_end_command),'97000000-0000-4000-8000-000000000002')->'error'->>'code'),
  'CUSTODY_LOCKED','assigned active work blocks shift end'
);
update public.rounds set state='complete' where id='97000000-0000-4000-8000-000000000040';
select is(
  (public.end_driver_shift_command((select body from driver_shift_end_command),'97000000-0000-4000-8000-000000000002')->>'status'),
  'committed','Driver ends shift after work is complete'
);
select ok(
  (select ended_at is not null from public.driver_shift_attendance where id='97000000-0000-4000-8000-000000000020'),
  'server records the end timestamp'
);
select is((select version from public.driver_shift_attendance where id='97000000-0000-4000-8000-000000000020'),2::bigint,'attendance version advances once');
select is((select count(*) from public.audit_events where action='driver.shift_ended' and aggregate_id='97000000-0000-4000-8000-000000000020'),1::bigint,'shift end is audited');
select is((select count(*) from public.domain_event_outbox where event_name='driver.shift_ended' and aggregate_id='97000000-0000-4000-8000-000000000020'),1::bigint,'shift-end event is staged');
select is(
  (public.end_driver_shift_command((select body from driver_shift_end_command),'97000000-0000-4000-8000-000000000002')->>'deduplicated'),
  'true','same end command is safely deduplicated'
);
select is(
  (public.end_driver_shift_command(
    jsonb_set(jsonb_set((select body from driver_shift_end_command),'{commandId}','"97000000-0000-4000-8000-000000000032"'),'{idempotencyKey}','"driver-shift:end:again"'),
    '97000000-0000-4000-8000-000000000002'
  )->'error'->>'code'),
  'STALE_VERSION','a second distinct command cannot end the version again'
);
select is((select count(*) from public.driver_shift_attendance where id='97000000-0000-4000-8000-000000000020' and end_command_id is not null),1::bigint,'one end command owns the transition');

select * from finish();
rollback;
