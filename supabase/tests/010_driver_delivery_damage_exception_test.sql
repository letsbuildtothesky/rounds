begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

select has_function('public', 'prepare_exception_media_asset', array['uuid','uuid','uuid','text','bigint','text'], 'damage media preparation exists');
select has_function('public', 'report_delivery_problem_command', array['jsonb','uuid'], 'delivery problem command exists');
select ok(has_function_privilege('service_role', 'public.report_delivery_problem_command(jsonb,uuid)', 'EXECUTE'), 'API service can report delivery damage');
select ok(not has_function_privilege('authenticated', 'public.report_delivery_problem_command(jsonb,uuid)', 'EXECUTE'), 'driver cannot bypass API command boundary');

insert into public.tenants (id, slug, display_name)
values ('82000000-0000-4000-8000-000000000001', 'delivery-damage-test', 'Delivery Damage Test');
insert into public.persons (id, display_name, email)
values ('82000000-0000-4000-8000-000000000002', 'Damage Driver', 'damage-driver@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at)
values ('82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale)
values ('82000000-0000-4000-8000-000000000010', '82000000-0000-4000-8000-000000000002', 'en');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000010', 'team', 'active', '{"assigned_work":true}');
insert into public.tenant_locations (id, tenant_id, code, display_name, raw_address, position, position_provenance, pickup_contact_name, pickup_contact_phone)
values ('82000000-0000-4000-8000-000000000020', '82000000-0000-4000-8000-000000000001', 'studio', 'UrbanFlowers', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.57::double precision,13.73::double precision),4326)::extensions.geography,
  'merchant_verified', 'Mali', '+66000000000');
insert into public.deliveries (id, tenant_id, reference, source_system, external_id, source_payload_hash, service_date, service_timezone, pickup_location_id,
  buyer_name, buyer_phone, recipient_name, recipient_phone, destination_raw_address, destination_position, destination_provenance, state, version, created_by_person_id)
values ('82000000-0000-4000-8000-000000000030', '82000000-0000-4000-8000-000000000001', 'DAMAGE-001', 'manual', 'DAMAGE-001', repeat('d',64),
  '2026-09-02', 'Asia/Bangkok', '82000000-0000-4000-8000-000000000020', 'Siriporn', '+66900000000', 'Siriporn', '+66900000000', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.55::double precision,13.75::double precision),4326)::extensions.geography,
  'dispatcher_pin', 'arrived', 6, '82000000-0000-4000-8000-000000000002');
insert into public.delivery_stops (id, tenant_id, delivery_id, state, version, arrived_at)
values ('82000000-0000-4000-8000-000000000040', '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000030', 'arrived', 5, now());
insert into public.manifests (id, tenant_id, delivery_id, state, version, locked_at)
values ('82000000-0000-4000-8000-000000000050', '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000030', 'draft', 1, null);
insert into public.manifest_items (tenant_id, manifest_id, line_number, description, quantity)
values ('82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000050', 1, 'Glass vase bouquet', 1);
update public.manifests set state='picked_up_locked', version=2, locked_at=now(), updated_at=now()
where id='82000000-0000-4000-8000-000000000050';
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('82000000-0000-4000-8000-000000000060', '82000000-0000-4000-8000-000000000001', 'ROUND-DAMAGE-001', '2026-09-02', '82000000-0000-4000-8000-000000000010', 'active', 4);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000060', '82000000-0000-4000-8000-000000000040', 1);

create temporary table damage_command (body jsonb) on commit drop;
insert into damage_command values (jsonb_build_object(
  'schemaVersion',1,'commandType','stop.report_delivery_problem','commandId','82000000-0000-4000-8000-000000000080',
  'traceId','82000000-0000-4000-8000-000000000081','idempotencyKey','damage:DAMAGE-001','tenantId','82000000-0000-4000-8000-000000000001',
  'aggregateId','82000000-0000-4000-8000-000000000040','expectedVersion',5,'occurredFromDeviceAt','2026-09-02T10:00:00Z',
  'payload',jsonb_build_object('manifestId','82000000-0000-4000-8000-000000000050','manifestVersion',2,'category','damaged_item',
    'mediaAssetId','82000000-0000-4000-8000-000000000070','note','Glass vase cracked before handoff')));

select is((public.report_delivery_problem_command((select body from damage_command), '82000000-0000-4000-8000-000000000002')->'error'->>'code'), 'EVIDENCE_REQUIRED', 'unverified evidence cannot create an exception');
select is((public.prepare_exception_media_asset('82000000-0000-4000-8000-000000000040','82000000-0000-4000-8000-000000000002',
  '82000000-0000-4000-8000-000000000070',repeat('a',64),2048,'image/jpeg')->>'status'), 'prepared', 'arrived Stop prepares private damage evidence');
select is((select intent from public.media_assets where id='82000000-0000-4000-8000-000000000070'), 'exception_photo', 'asset intent cannot be confused with POD');
select is((public.mark_pod_media_uploaded('82000000-0000-4000-8000-000000000070','82000000-0000-4000-8000-000000000002',repeat('b',64),2048)->'error'->>'code'), 'EVIDENCE_REQUIRED', 'mismatched bytes are rejected');
select is((select state::text from public.media_assets where id='82000000-0000-4000-8000-000000000070'), 'quarantined', 'mismatched evidence is quarantined');
update public.media_assets set state='staged' where id='82000000-0000-4000-8000-000000000070';
select is((public.mark_pod_media_uploaded('82000000-0000-4000-8000-000000000070','82000000-0000-4000-8000-000000000002',repeat('a',64),2048)->>'status'), 'verified', 'matching bytes become uploaded-uncommitted');
select is((public.report_delivery_problem_command(jsonb_set((select body from damage_command),'{expectedVersion}','6'), '82000000-0000-4000-8000-000000000002')->'error'->>'code'), 'STALE_VERSION', 'stale Stop cannot report damage');
select is((public.report_delivery_problem_command((select body from damage_command), '82000000-0000-4000-8000-000000000002')->>'status'), 'committed', 'verified damage report commits');
select is((select state::text from public.media_assets where id='82000000-0000-4000-8000-000000000070'), 'committed', 'damage evidence becomes immutable');
select is((select state::text from public.delivery_stops where id='82000000-0000-4000-8000-000000000040'), 'exception', 'Stop is blocked from ordinary delivery');
select is((select state::text from public.deliveries where id='82000000-0000-4000-8000-000000000030'), 'exception', 'delivery truth records the exception');
select is((select stage from public.delivery_exceptions where stop_id='82000000-0000-4000-8000-000000000040'), 'delivery', 'exception records delivery stage');
select is((select media_asset_id::text from public.delivery_exceptions where stop_id='82000000-0000-4000-8000-000000000040'), '82000000-0000-4000-8000-000000000070', 'exception owns exact evidence');
select is((select count(*) from public.audit_events where action='stop.delivery_problem_reported' and aggregate_id='82000000-0000-4000-8000-000000000040'), 1::bigint, 'damage report is audited once');
select is((select count(*) from public.domain_event_outbox where event_name='stop.delivery_problem_reported' and aggregate_id='82000000-0000-4000-8000-000000000040'), 1::bigint, 'damage event is staged once');
select is((public.report_delivery_problem_command((select body from damage_command), '82000000-0000-4000-8000-000000000002')->>'deduplicated'), 'true', 'retry is safely deduplicated');

select * from finish();
rollback;
