begin;

create extension if not exists pgtap with schema extensions;
select plan(31);

select has_function('public', 'prepare_pod_media_asset', array['uuid', 'uuid', 'uuid', 'text', 'bigint', 'text'], 'POD media preparation exists');
select has_function('public', 'mark_pod_media_uploaded', array['uuid', 'uuid', 'text', 'bigint'], 'POD media verification exists');
select has_function('public', 'complete_stop_pod_command', array['jsonb', 'uuid'], 'POD completion command exists');
select ok(has_function_privilege('service_role', 'public.complete_stop_pod_command(jsonb,uuid)', 'EXECUTE'), 'API service can complete POD');
select ok(not has_table_privilege('authenticated', 'public.pod_records', 'SELECT'), 'driver cannot read POD evidence directly');
select ok(not has_table_privilege('authenticated', 'public.media_assets', 'SELECT'), 'driver cannot read media lifecycle directly');
select is((select public from storage.buckets where id = 'pod-evidence'), false, 'POD bucket is private');
select has_function('public', 'can_access_pod_object', array['text', 'text', 'boolean'], 'exact-object storage authorization exists');
select ok(has_function_privilege('authenticated', 'public.can_access_pod_object(text,text,boolean)', 'EXECUTE'), 'authenticated driver can evaluate exact-object authorization');
select ok(not has_function_privilege('anon', 'public.can_access_pod_object(text,text,boolean)', 'EXECUTE'), 'anonymous clients cannot evaluate POD object authorization');

insert into public.tenants (id, slug, display_name)
values ('60000000-0000-4000-8000-000000000001', 'pod-command-test', 'POD Command Test');
insert into public.persons (id, display_name, email)
values ('60000000-0000-4000-8000-000000000007', 'POD Driver', 'pod-driver@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at)
values ('60000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000007', 'team_driver', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('60000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000007', 'en', 'Motorbike');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('60000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000002', 'team', 'active', '{"assigned_work":true}'::jsonb);
insert into public.tenant_locations (
  id, tenant_id, code, display_name, raw_address, position, position_provenance,
  pickup_contact_name, pickup_contact_phone
) values (
  '60000000-0000-4000-8000-000000000020', '60000000-0000-4000-8000-000000000001',
  'studio', 'Pickup Studio', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.57::double precision, 13.73::double precision), 4326)::extensions.geography,
  'merchant_verified', 'Dispatch', '+66000000000'
);
insert into public.deliveries (
  id, tenant_id, reference, source_system, external_id, source_payload_hash,
  service_date, service_timezone, pickup_location_id, buyer_name, buyer_phone,
  recipient_name, recipient_phone, destination_raw_address, destination_position,
  destination_provenance, state, version, created_by_person_id
) values (
  '60000000-0000-4000-8000-000000000100', '60000000-0000-4000-8000-000000000001',
  'POD-001', 'manual', 'POD-001', repeat('c', 64), '2026-09-02', 'Asia/Bangkok',
  '60000000-0000-4000-8000-000000000020', 'Siriporn', '+66999999999', 'Siriporn', '+66999999999',
  'Bangkok', extensions.st_setsrid(extensions.st_makepoint(100.55::double precision, 13.75::double precision), 4326)::extensions.geography,
  'dispatcher_pin', 'arrived', 7, '60000000-0000-4000-8000-000000000007'
);
insert into public.delivery_stops (id, tenant_id, delivery_id, state, version, arrived_at)
values ('60000000-0000-4000-8000-000000000110', '60000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000100', 'arrived', 5, now());
insert into public.manifests (id, tenant_id, delivery_id, state, version, locked_at)
values ('60000000-0000-4000-8000-000000000120', '60000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000100', 'draft', 1, null);
insert into public.manifest_items (tenant_id, manifest_id, line_number, description, quantity)
values
  ('60000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000120', 1, 'Bouquet', 1),
  ('60000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000120', 2, 'Gift card', 1);
update public.manifests set state = 'picked_up_locked', locked_at = now(), updated_at = now()
where id = '60000000-0000-4000-8000-000000000120';
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('60000000-0000-4000-8000-000000000130', '60000000-0000-4000-8000-000000000001', 'ROUND-POD-001', '2026-09-02', '60000000-0000-4000-8000-000000000002', 'active', 2);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('60000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000130', '60000000-0000-4000-8000-000000000110', 1);

create temporary table pod_test_command (body jsonb not null) on commit drop;
insert into pod_test_command values (jsonb_build_object(
  'schemaVersion', 1, 'commandType', 'stop.complete_pod',
  'commandId', '60000000-0000-4000-8000-000000000201',
  'traceId', '60000000-0000-4000-8000-000000000202',
  'idempotencyKey', 'pod:POD-001',
  'tenantId', '60000000-0000-4000-8000-000000000001',
  'aggregateId', '60000000-0000-4000-8000-000000000110',
  'expectedVersion', 5,
  'occurredFromDeviceAt', '2026-09-01T12:10:00Z',
  'payload', jsonb_build_object(
    'manifestId', '60000000-0000-4000-8000-000000000120',
    'manifestVersion', 1, 'confirmedLineNumbers', jsonb_build_array(1, 2),
    'mediaAssetId', '60000000-0000-4000-8000-000000000140',
    'handoffType', 'recipient', 'receiverName', 'Siriporn', 'note', 'Handed directly')
));

select is(
  (public.complete_stop_pod_command((select body from pod_test_command), '60000000-0000-4000-8000-000000000007') -> 'error' ->> 'code'),
  'EVIDENCE_REQUIRED', 'completion is blocked until photo bytes are verified');

select is(
  (public.prepare_pod_media_asset(
    '60000000-0000-4000-8000-000000000110', '60000000-0000-4000-8000-000000000007',
    '60000000-0000-4000-8000-000000000140', repeat('d', 64), 2048, 'image/jpeg') ->> 'status'),
  'prepared', 'arrived Stop prepares immutable photo metadata');
select is((select state::text from public.media_assets where id = '60000000-0000-4000-8000-000000000140'), 'staged', 'media starts staged');
select is(
  (public.mark_pod_media_uploaded('60000000-0000-4000-8000-000000000140', '60000000-0000-4000-8000-000000000007', repeat('e', 64), 2048) -> 'error' ->> 'code'),
  'EVIDENCE_REQUIRED', 'hash mismatch is rejected');
select is((select state::text from public.media_assets where id = '60000000-0000-4000-8000-000000000140'), 'quarantined', 'hash mismatch quarantines media');
update public.media_assets set state = 'staged' where id = '60000000-0000-4000-8000-000000000140';
select is(
  (public.mark_pod_media_uploaded('60000000-0000-4000-8000-000000000140', '60000000-0000-4000-8000-000000000007', repeat('d', 64), 2048) ->> 'status'),
  'verified', 'matching photo bytes become uploaded-uncommitted');

select is(
  (public.complete_stop_pod_command(jsonb_set((select body from pod_test_command), '{expectedVersion}', '6'), '60000000-0000-4000-8000-000000000007') -> 'error' ->> 'code'),
  'STALE_VERSION', 'stale Stop cannot commit POD');
select is((public.complete_stop_pod_command((select body from pod_test_command), '60000000-0000-4000-8000-000000000007') ->> 'status'), 'committed', 'verified POD commits');
select is((select state::text from public.media_assets where id = '60000000-0000-4000-8000-000000000140'), 'committed', 'media is immutable committed evidence');
select is((select state::text from public.delivery_stops where id = '60000000-0000-4000-8000-000000000110'), 'completed', 'Stop is completed');
select ok((select completed_at is not null from public.delivery_stops where id = '60000000-0000-4000-8000-000000000110'), 'Stop completion is timestamped');
select is((select state::text from public.deliveries where id = '60000000-0000-4000-8000-000000000100'), 'delivered', 'delivery advances through pending evidence to delivered');
select is((select state::text from public.rounds where id = '60000000-0000-4000-8000-000000000130'), 'complete', 'last Stop completes Round');
select is((select handoff_type::text from public.pod_records where stop_id = '60000000-0000-4000-8000-000000000110'), 'recipient', 'receiver choice is durable');
select is((select receiver_name from public.pod_records where stop_id = '60000000-0000-4000-8000-000000000110'), 'Siriporn', 'receiver identity is durable');
select is((select stage::text from public.manifest_verifications where stop_id = '60000000-0000-4000-8000-000000000110' and stage = 'handoff'), 'handoff', 'same manifest is verified at handoff');
select is((select event_type::text from public.custody_events where stop_id = '60000000-0000-4000-8000-000000000110' and event_type = 'driver_to_recipient'), 'driver_to_recipient', 'final custody transfer is durable');
select is((select count(*) from public.audit_events where action = 'stop.delivery_completed' and aggregate_id = '60000000-0000-4000-8000-000000000110'), 1::bigint, 'completion is audited once');
select is((select count(*) from public.domain_event_outbox where event_name = 'stop.delivery_completed' and aggregate_id = '60000000-0000-4000-8000-000000000110'), 1::bigint, 'completion event is staged once');
select is((public.complete_stop_pod_command((select body from pod_test_command), '60000000-0000-4000-8000-000000000007') ->> 'deduplicated'), 'true', 'completion retry is safely deduplicated');

set local role authenticated;
select throws_ok(
  $$select public.complete_stop_pod_command('{}'::jsonb, '60000000-0000-4000-8000-000000000007')$$,
  '42501', 'permission denied for function complete_stop_pod_command',
  'authenticated clients cannot execute POD command directly');
reset role;

select * from finish();
rollback;
