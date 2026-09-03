begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

select has_table('public', 'contact_attempts', 'contact-attempt ledger exists');
select has_function('public', 'log_contact_attempt_command', array['jsonb','uuid'], 'contact-attempt command exists');
select ok(has_function_privilege('service_role', 'public.log_contact_attempt_command(jsonb,uuid)', 'EXECUTE'), 'API service can record contact evidence');
select ok(not has_function_privilege('authenticated', 'public.log_contact_attempt_command(jsonb,uuid)', 'EXECUTE'), 'driver cannot bypass the API command boundary');

insert into public.tenants (id, slug, display_name)
values ('84000000-0000-4000-8000-000000000001', 'contact-attempt-test', 'Contact Attempt Test');
insert into public.persons (id, display_name, email)
values ('84000000-0000-4000-8000-000000000002', 'Contact Driver', 'contact-driver@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at)
values ('84000000-0000-4000-8000-000000000001', '84000000-0000-4000-8000-000000000002', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale)
values ('84000000-0000-4000-8000-000000000010', '84000000-0000-4000-8000-000000000002', 'en');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('84000000-0000-4000-8000-000000000001', '84000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.tenant_locations (id, tenant_id, code, display_name, raw_address, position, position_provenance, pickup_contact_name, pickup_contact_phone)
values ('84000000-0000-4000-8000-000000000020', '84000000-0000-4000-8000-000000000001', 'studio', 'UrbanFlowers', 'Pickup truth',
  extensions.st_setsrid(extensions.st_makepoint(100.570000::double precision,13.730000::double precision),4326)::extensions.geography,
  'merchant_verified', 'Operations', '+66000000000');
insert into public.deliveries (id, tenant_id, reference, source_system, external_id, source_payload_hash, service_date, service_timezone, pickup_location_id,
  buyer_name, buyer_phone, recipient_name, recipient_phone, destination_raw_address, destination_position, destination_provenance, state, version, created_by_person_id)
values ('84000000-0000-4000-8000-000000000030', '84000000-0000-4000-8000-000000000001', 'CONTACT-001', 'manual', 'CONTACT-001', repeat('f',64),
  '2026-09-03', 'Asia/Bangkok', '84000000-0000-4000-8000-000000000020', 'Siriporn', '+66900000000', 'Siriporn', '+66900000000', 'Destination truth',
  extensions.st_setsrid(extensions.st_makepoint(100.550000::double precision,13.750000::double precision),4326)::extensions.geography,
  'dispatcher_pin', 'in_custody', 6, '84000000-0000-4000-8000-000000000002');
insert into public.delivery_stops (id, tenant_id, delivery_id, state, destination_version, version)
values ('84000000-0000-4000-8000-000000000040', '84000000-0000-4000-8000-000000000001', '84000000-0000-4000-8000-000000000030', 'arrived', 1, 5);
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('84000000-0000-4000-8000-000000000060', '84000000-0000-4000-8000-000000000001', 'ROUND-CONTACT-001', '2026-09-03', '84000000-0000-4000-8000-000000000010', 'active', 4);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('84000000-0000-4000-8000-000000000001', '84000000-0000-4000-8000-000000000060', '84000000-0000-4000-8000-000000000040', 1);

create temporary table contact_command (body jsonb) on commit drop;
insert into contact_command values (jsonb_build_object(
  'schemaVersion',1,'commandType','stop.log_contact_attempt','commandId','84000000-0000-4000-8000-000000000080',
  'traceId','84000000-0000-4000-8000-000000000081','idempotencyKey','contact:CONTACT-001:one','tenantId','84000000-0000-4000-8000-000000000001',
  'aggregateId','84000000-0000-4000-8000-000000000040','expectedVersion',5,'occurredFromDeviceAt','2026-09-03T06:00:00Z',
  'payload',jsonb_build_object('target','recipient','channel','native_phone','outcome','no_answer')));

select is((public.log_contact_attempt_command(jsonb_set((select body from contact_command),'{expectedVersion}','6'), '84000000-0000-4000-8000-000000000002')->'error'->>'code'), 'STALE_VERSION', 'stale Stop cannot record contact evidence');
select is((public.log_contact_attempt_command(jsonb_set((select body from contact_command),'{payload,outcome}','"connected"'), '84000000-0000-4000-8000-000000000002')->'error'->>'code'), 'VALIDATION_FAILED', 'unsupported outcome is rejected');
select is((public.log_contact_attempt_command((select body from contact_command), '84000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'recipient call outcome commits');
select is((select count(*) from public.contact_attempts where stop_id='84000000-0000-4000-8000-000000000040'), 1::bigint, 'one contact attempt is recorded');
select is((select target from public.contact_attempts where stop_id='84000000-0000-4000-8000-000000000040'), 'recipient', 'target is retained');
select is((select outcome from public.contact_attempts where stop_id='84000000-0000-4000-8000-000000000040'), 'no_answer', 'Driver-selected outcome is retained');
select is((select state::text from public.delivery_stops where id='84000000-0000-4000-8000-000000000040'), 'arrived', 'contact evidence does not mutate Stop state');
select is((select state::text from public.deliveries where id='84000000-0000-4000-8000-000000000030'), 'in_custody', 'contact evidence does not mutate custody');
select is((select count(*) from public.operations_threads where stop_id='84000000-0000-4000-8000-000000000040'), 1::bigint, 'Operations thread is available');
select is((select sender::text from public.operations_messages where command_id='84000000-0000-4000-8000-000000000080'), 'system', 'call evidence enters the shared ledger');
select is((select count(*) from public.audit_events where action='stop.contact_attempt_recorded' and command_id='84000000-0000-4000-8000-000000000080'), 1::bigint, 'contact evidence is audited once');
select is((select semantic_change->>'stateMutation' from public.audit_events where command_id='84000000-0000-4000-8000-000000000080'), 'false', 'audit proves no workflow state was changed');
select is((select count(*) from public.domain_event_outbox where event_name='stop.contact_attempt_recorded' and aggregate_id='84000000-0000-4000-8000-000000000040'), 1::bigint, 'contact event is staged once');
select is((public.log_contact_attempt_command((select body from contact_command), '84000000-0000-4000-8000-000000000002')->>'deduplicated'), 'true', 'retry is safely deduplicated');
select is((public.log_contact_attempt_command(
  jsonb_set(jsonb_set((select body from contact_command),'{commandId}','"84000000-0000-4000-8000-000000000082"'),'{idempotencyKey}','"contact:CONTACT-001:two"'),
  '84000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'a second call can be recorded against the unchanged Stop version');
select is((select count(*) from public.contact_attempts where stop_id='84000000-0000-4000-8000-000000000040'), 2::bigint, 'contact ledger retains both attempts');

select * from finish();
rollback;
