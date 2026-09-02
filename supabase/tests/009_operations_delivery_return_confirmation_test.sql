begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select has_function('public', 'confirm_delivery_return_command', array['jsonb', 'uuid'], 'Delivery return confirmation command exists');
select ok(has_function_privilege('service_role', 'public.confirm_delivery_return_command(jsonb,uuid)', 'EXECUTE'), 'API service can confirm delivery returns');
select ok(public.is_valid_delivery_transition('exception', 'returned'), 'canonical graph permits an audited exception return');

insert into public.tenants (id, slug, display_name) values ('81000000-0000-4000-8000-000000000001', 'delivery-return-test', 'Delivery Return Test');
insert into public.persons (id, display_name, email) values
  ('81000000-0000-4000-8000-000000000002', 'Dispatcher', 'dispatcher-return@test.invalid'),
  ('81000000-0000-4000-8000-000000000003', 'Viewer', 'viewer-return@test.invalid'),
  ('81000000-0000-4000-8000-000000000004', 'Driver', 'driver-return@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at) values
  ('81000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000002', 'dispatcher', 'active', now()),
  ('81000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000003', 'viewer', 'active', now()),
  ('81000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000004', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale) values ('81000000-0000-4000-8000-000000000010', '81000000-0000-4000-8000-000000000004', 'en');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('81000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.tenant_locations (id, tenant_id, code, display_name, raw_address, position, position_provenance, pickup_contact_name, pickup_contact_phone)
values ('81000000-0000-4000-8000-000000000020', '81000000-0000-4000-8000-000000000001', 'studio', 'UrbanFlowers', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.57::double precision, 13.73::double precision), 4326)::extensions.geography,
  'merchant_verified', 'Mali', '+66000000000');
insert into public.deliveries (id, tenant_id, reference, source_system, external_id, source_payload_hash, service_date, service_timezone, pickup_location_id,
  buyer_name, buyer_phone, recipient_name, recipient_phone, destination_raw_address, destination_position, destination_provenance, state, version, created_by_person_id)
values ('81000000-0000-4000-8000-000000000030', '81000000-0000-4000-8000-000000000001', 'RETURN-001', 'manual', 'RETURN-001', repeat('d',64),
  '2026-09-02', 'Asia/Bangkok', '81000000-0000-4000-8000-000000000020', 'Recipient', '+66900000000', 'Recipient', '+66900000000', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.55::double precision, 13.75::double precision), 4326)::extensions.geography, 'dispatcher_pin', 'exception', 6,
  '81000000-0000-4000-8000-000000000002');
insert into public.delivery_stops (id, tenant_id, delivery_id, state, version)
values ('81000000-0000-4000-8000-000000000040', '81000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000030', 'exception', 5);
insert into public.manifests (id, tenant_id, delivery_id, state, version)
values ('81000000-0000-4000-8000-000000000050', '81000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000030', 'picked_up_locked', 2);
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('81000000-0000-4000-8000-000000000060', '81000000-0000-4000-8000-000000000001', 'ROUND-RETURN-001', '2026-09-02', '81000000-0000-4000-8000-000000000010', 'active', 4);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('81000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000060', '81000000-0000-4000-8000-000000000040', 1);
insert into public.delivery_exceptions (id, tenant_id, delivery_id, stop_id, round_id, driver_id, manifest_id, manifest_version, stage, category, note, status, actor_person_id, command_id)
values ('81000000-0000-4000-8000-000000000070', '81000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000030',
  '81000000-0000-4000-8000-000000000040', '81000000-0000-4000-8000-000000000060', '81000000-0000-4000-8000-000000000010',
  '81000000-0000-4000-8000-000000000050', 2, 'delivery', 'damaged_item', 'Glass vase damaged in custody', 'open',
  '81000000-0000-4000-8000-000000000004', '81000000-0000-4000-8000-000000000071');

create temporary table delivery_return_command (body jsonb) on commit drop;
insert into delivery_return_command values (jsonb_build_object(
  'schemaVersion',1,'commandType','operations.confirm_delivery_return','commandId','81000000-0000-4000-8000-000000000080',
  'traceId','81000000-0000-4000-8000-000000000081','idempotencyKey','return:RETURN-001','tenantId','81000000-0000-4000-8000-000000000001',
  'aggregateId','81000000-0000-4000-8000-000000000040','expectedVersion',5,
  'payload',jsonb_build_object('exceptionId','81000000-0000-4000-8000-000000000070','note','Somchai returned the damaged package; Mali accepted it at UrbanFlowers')));

select is((public.confirm_delivery_return_command((select body from delivery_return_command), '81000000-0000-4000-8000-000000000003')->'error'->>'code'), 'NOT_AUTHORIZED', 'viewer cannot confirm a return');
select is((public.confirm_delivery_return_command(jsonb_set((select body from delivery_return_command),'{expectedVersion}','6'), '81000000-0000-4000-8000-000000000002')->'error'->>'code'), 'STALE_VERSION', 'stale Stop cannot confirm a return');
select is((public.confirm_delivery_return_command((select body from delivery_return_command), '81000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'dispatcher confirms physical return');
select is((select status::text from public.delivery_exceptions where id='81000000-0000-4000-8000-000000000070'), 'resolved', 'damage exception is resolved');
select ok((select resolved_at is not null from public.delivery_exceptions where id='81000000-0000-4000-8000-000000000070'), 'return resolution is timestamped');
select is((select state::text from public.delivery_stops where id='81000000-0000-4000-8000-000000000040'), 'cancelled', 'delivery Stop closes without POD');
select is((select state::text from public.deliveries where id='81000000-0000-4000-8000-000000000030'), 'returned', 'delivery records returned physical truth');
select is((select count(*) from public.audit_events where action='operations.delivery_return_confirmed' and aggregate_id='81000000-0000-4000-8000-000000000040'), 1::bigint, 'return is audited');
select is((select count(*) from public.domain_event_outbox where event_name='operations.delivery_return_confirmed' and aggregate_id='81000000-0000-4000-8000-000000000040'), 1::bigint, 'return event is staged');
select is((public.confirm_delivery_return_command((select body from delivery_return_command), '81000000-0000-4000-8000-000000000002')->>'deduplicated'), 'true', 'return retry is deduplicated');

set local role authenticated;
select throws_ok($$select public.confirm_delivery_return_command('{}'::jsonb, '81000000-0000-4000-8000-000000000002')$$,
  '42501','permission denied for function confirm_delivery_return_command','authenticated clients cannot call return command directly');
reset role;

select * from finish();
rollback;
