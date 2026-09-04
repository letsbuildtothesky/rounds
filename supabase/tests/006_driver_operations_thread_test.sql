begin;

create extension if not exists pgtap with schema extensions;
select plan(54);

select has_function('public', 'ensure_driver_operations_thread', array['uuid', 'uuid', 'uuid'], 'driver thread projection exists');
select has_function('public', 'send_driver_message_command', array['jsonb', 'uuid'], 'driver message command exists');
select has_function('public', 'send_operations_message_command', array['jsonb', 'uuid'], 'Operations reply command exists');
select ok(has_function_privilege('service_role', 'public.send_driver_message_command(jsonb,uuid)', 'EXECUTE'), 'API service can send driver messages');
select ok(has_function_privilege('service_role', 'public.send_operations_message_command(jsonb,uuid)', 'EXECUTE'), 'API service can send Operations replies');
select ok(not has_table_privilege('authenticated', 'public.operations_threads', 'SELECT'), 'driver cannot read threads directly');
select ok(not has_table_privilege('authenticated', 'public.operations_messages', 'SELECT'), 'driver cannot read messages directly');

insert into public.tenants (id, slug, display_name)
values ('70000000-0000-4000-8000-000000000001', 'thread-command-test', 'Thread Command Test');
insert into public.persons (id, display_name, email) values
  ('70000000-0000-4000-8000-000000000007', 'Thread Driver', 'thread-driver@test.invalid'),
  ('70000000-0000-4000-8000-000000000008', 'Other Person', 'other-thread@test.invalid'),
  ('70000000-0000-4000-8000-000000000009', 'Dispatcher', 'thread-dispatcher@test.invalid'),
  ('70000000-0000-4000-8000-000000000010', 'Viewer', 'thread-viewer@test.invalid');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at)
values
  ('70000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000007', 'team_driver', 'active', now()),
  ('70000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000009', 'dispatcher', 'active', now()),
  ('70000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000010', 'viewer', 'active', now());
insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('70000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000007', 'en', 'Motorbike');
insert into public.driver_tenant_relationships (tenant_id, driver_id, relationship_kind, status, permissions)
values ('70000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000002', 'team', 'active', '{"assigned_work":true}'::jsonb);
insert into public.tenant_locations (
  id, tenant_id, code, display_name, raw_address, position, position_provenance,
  pickup_contact_name, pickup_contact_phone
) values (
  '70000000-0000-4000-8000-000000000020', '70000000-0000-4000-8000-000000000001',
  'studio', 'Pickup Studio', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.57::double precision, 13.73::double precision), 4326)::extensions.geography,
  'merchant_verified', 'Dispatch', '+66000000000'
);
insert into public.deliveries (
  id, tenant_id, reference, source_system, external_id, source_payload_hash,
  service_date, service_timezone, pickup_location_id, buyer_same_as_recipient, buyer_name, buyer_phone,
  recipient_name, recipient_phone, destination_raw_address, destination_position,
  destination_provenance, state, version, created_by_person_id
) values (
  '70000000-0000-4000-8000-000000000100', '70000000-0000-4000-8000-000000000001',
  'THREAD-001', 'manual', 'THREAD-001', repeat('f', 64), '2026-09-02', 'Asia/Bangkok',
  '70000000-0000-4000-8000-000000000020', false, 'Buyer', '+66999999998', 'Siriporn', '+66999999999',
  'Bangkok', extensions.st_setsrid(extensions.st_makepoint(100.55::double precision, 13.75::double precision), 4326)::extensions.geography,
  'dispatcher_pin', 'in_custody', 4, '70000000-0000-4000-8000-000000000007'
);
insert into public.delivery_stops (id, tenant_id, delivery_id, state, version)
values ('70000000-0000-4000-8000-000000000110', '70000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000100', 'active', 4);
insert into public.rounds (id, tenant_id, reference, service_date, driver_id, state, version)
values ('70000000-0000-4000-8000-000000000130', '70000000-0000-4000-8000-000000000001', 'ROUND-THREAD-001', '2026-09-02', '70000000-0000-4000-8000-000000000002', 'active', 2);
insert into public.round_stops (tenant_id, round_id, stop_id, sequence)
values ('70000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000130', '70000000-0000-4000-8000-000000000110', 1);

create temporary table thread_projection (body jsonb not null) on commit drop;
insert into thread_projection values (public.ensure_driver_operations_thread(
  '70000000-0000-4000-8000-000000000130',
  '70000000-0000-4000-8000-000000000110',
  '70000000-0000-4000-8000-000000000007'
));

select ok((select body ->> 'id' is not null from thread_projection), 'assigned driver gets a durable thread');
select is((select body ->> 'roundId' from thread_projection), '70000000-0000-4000-8000-000000000130', 'thread is Round scoped');
select is((select body ->> 'stopId' from thread_projection), '70000000-0000-4000-8000-000000000110', 'thread is Stop scoped');
select is((select (body ->> 'version')::bigint from thread_projection), 1::bigint, 'new thread starts at version one');
select is((select count(*) from public.operations_threads where round_id = '70000000-0000-4000-8000-000000000130'), 1::bigint, 'one thread is created');
select is(
  public.ensure_driver_operations_thread(
    '70000000-0000-4000-8000-000000000130',
    '70000000-0000-4000-8000-000000000110',
    '70000000-0000-4000-8000-000000000007'
  ) ->> 'id',
  (select body ->> 'id' from thread_projection),
  'reloading reuses the same thread'
);

create temporary table message_command (body jsonb not null) on commit drop;
insert into message_command values (jsonb_build_object(
  'schemaVersion', 1, 'commandType', 'thread.send_message',
  'commandId', '70000000-0000-4000-8000-000000000201',
  'traceId', '70000000-0000-4000-8000-000000000202',
  'idempotencyKey', 'message:THREAD-001:one',
  'tenantId', '70000000-0000-4000-8000-000000000001',
  'aggregateId', (select body ->> 'id' from thread_projection),
  'expectedVersion', 1,
  'occurredFromDeviceAt', '2026-09-02T03:00:00Z',
  'payload', jsonb_build_object('body', 'Running five minutes late')
));

select is((public.send_driver_message_command((select body from message_command), '70000000-0000-4000-8000-000000000007') ->> 'status'), 'committed', 'assigned driver message commits');
select is((select count(*) from public.operations_messages), 1::bigint, 'one message is durable');
select is((select body from public.operations_messages limit 1), 'Running five minutes late', 'exact message body is preserved');
select is((select version from public.operations_threads limit 1), 2::bigint, 'message advances thread version');
select is((select count(*) from public.audit_events where action = 'thread.message_sent'), 1::bigint, 'message is audited once');
select is((select count(*) from public.domain_event_outbox where event_name = 'thread.message_sent'), 1::bigint, 'message event is staged once');
select is((public.send_driver_message_command((select body from message_command), '70000000-0000-4000-8000-000000000007') ->> 'deduplicated'), 'true', 'message retry is safely deduplicated');
select is((select count(*) from public.operations_messages), 1::bigint, 'deduplication does not duplicate chat history');
select is(
  (public.send_driver_message_command(jsonb_set((select body from message_command), '{idempotencyKey}', '"message:THREAD-001:stale"'), '70000000-0000-4000-8000-000000000007') -> 'error' ->> 'code'),
  'STALE_VERSION', 'stale thread version cannot append a message'
);
select is(
  public.ensure_driver_operations_thread(
    '70000000-0000-4000-8000-000000000130',
    '70000000-0000-4000-8000-000000000110',
    '70000000-0000-4000-8000-000000000008'
  ),
  null::jsonb,
  'unassigned person cannot load the thread'
);

create temporary table operations_message_command (body jsonb not null) on commit drop;
insert into operations_message_command values (jsonb_build_object(
  'schemaVersion', 1, 'commandType', 'thread.send_operations_message',
  'commandId', '70000000-0000-4000-8000-000000000211',
  'traceId', '70000000-0000-4000-8000-000000000212',
  'idempotencyKey', 'operations-message:THREAD-001:one',
  'tenantId', '70000000-0000-4000-8000-000000000001',
  'aggregateId', (select body ->> 'id' from thread_projection),
  'expectedVersion', 2,
  'payload', jsonb_build_object('body', 'Continue to the recipient')
));

select is((public.send_operations_message_command((select body from operations_message_command), '70000000-0000-4000-8000-000000000009') ->> 'status'), 'committed', 'dispatcher reply commits');
select is((select count(*) from public.operations_messages), 2::bigint, 'Operations reply is durable beside driver message');
select is((select sender::text from public.operations_messages where body = 'Continue to the recipient'), 'operations', 'reply sender is Operations');
select is((select body from public.operations_messages where sender = 'operations'), 'Continue to the recipient', 'exact Operations body is preserved');
select is((select version from public.operations_threads limit 1), 3::bigint, 'Operations reply advances thread version');
select is((select count(*) from public.audit_events where semantic_change ->> 'sender' = 'operations'), 1::bigint, 'Operations reply is audited once');
select is((select count(*) from public.domain_event_outbox where event_name = 'thread.message_sent'), 2::bigint, 'driver and Operations message events are staged');
select is((public.send_operations_message_command((select body from operations_message_command), '70000000-0000-4000-8000-000000000009') ->> 'deduplicated'), 'true', 'Operations retry is safely deduplicated');
select is((select count(*) from public.operations_messages), 2::bigint, 'Operations deduplication does not duplicate history');
select is(
  (public.send_operations_message_command(jsonb_set((select body from operations_message_command), '{idempotencyKey}', '"operations-message:viewer"'), '70000000-0000-4000-8000-000000000010') -> 'error' ->> 'code'),
  'NOT_AUTHORIZED', 'viewer cannot reply'
);
select is(
  (public.send_operations_message_command(jsonb_set((select body from operations_message_command), '{idempotencyKey}', '"operations-message:outsider"'), '70000000-0000-4000-8000-000000000008') -> 'error' ->> 'code'),
  'NOT_AUTHORIZED', 'person outside the tenant cannot reply'
);
select is(
  (public.send_operations_message_command(jsonb_set((select body from operations_message_command), '{idempotencyKey}', '"operations-message:stale"'), '70000000-0000-4000-8000-000000000009') -> 'error' ->> 'code'),
  'STALE_VERSION', 'stale Operations reply cannot append a message'
);

create temporary table location_message_command (body jsonb not null) on commit drop;
insert into location_message_command values (jsonb_build_object(
  'schemaVersion', 1, 'commandType', 'thread.send_message',
  'commandId', '70000000-0000-4000-8000-000000000221',
  'traceId', '70000000-0000-4000-8000-000000000222',
  'idempotencyKey', 'message:THREAD-001:location',
  'tenantId', '70000000-0000-4000-8000-000000000001',
  'aggregateId', (select body ->> 'id' from thread_projection),
  'expectedVersion', 3,
  'occurredFromDeviceAt', '2026-09-02T03:02:00Z',
  'payload', jsonb_build_object(
    'body', '',
    'attachments', jsonb_build_array(jsonb_build_object(
      'kind', 'location', 'label', 'Current location',
      'latitude', 13.7306, 'longitude', 100.5697,
      'accuracyMeters', 8.5, 'capturedAt', '2026-09-02T03:02:00Z'
    ))
  )
));

select is((public.send_driver_message_command((select body from location_message_command), '70000000-0000-4000-8000-000000000007') ->> 'status'), 'committed', 'location-only message commits');
select is((select attachments -> 0 ->> 'kind' from public.operations_messages where command_id = '70000000-0000-4000-8000-000000000221'), 'location', 'location remains structured durable thread data');
select is((public.ensure_driver_operations_thread(
  '70000000-0000-4000-8000-000000000130',
  '70000000-0000-4000-8000-000000000110',
  '70000000-0000-4000-8000-000000000007'
) -> 'messages' -> 2 -> 'attachments' -> 0 ->> 'label'), 'Current location', 'driver thread projection returns the attachment');
select is((public.send_driver_message_command(
  jsonb_set(
    jsonb_set((select body from location_message_command), '{idempotencyKey}', '"message:THREAD-001:bad-location"'),
    '{payload,attachments,0,latitude}', '130'::jsonb
  ),
  '70000000-0000-4000-8000-000000000007'
) -> 'error' ->> 'code'), 'VALIDATION_FAILED', 'invalid location coordinates are rejected');

select has_table('public', 'communication_media_assets', 'private communication media registry exists');
select has_function('public', 'prepare_driver_message_media_asset', array['uuid', 'uuid', 'uuid', 'uuid', 'text', 'text', 'text', 'bigint', 'text', 'integer'], 'driver can prepare private message media through the API');
select has_function('public', 'mark_driver_message_media_uploaded', array['uuid', 'uuid', 'text', 'bigint'], 'uploaded message media can be integrity verified');
select ok(has_function_privilege('service_role', 'public.prepare_driver_message_media_asset(uuid,uuid,uuid,uuid,text,text,text,bigint,text,integer)', 'EXECUTE'), 'API service can prepare message media');
select ok(not has_table_privilege('authenticated', 'public.communication_media_assets', 'SELECT'), 'driver cannot enumerate message media records directly');

create temporary table prepared_message_media (body jsonb not null) on commit drop;
insert into prepared_message_media values (public.prepare_driver_message_media_asset(
  '70000000-0000-4000-8000-000000000130',
  '70000000-0000-4000-8000-000000000110',
  '70000000-0000-4000-8000-000000000007',
  '70000000-0000-4000-8000-000000000231',
  'image', 'package.jpg', 'image/jpeg', 4096, repeat('c', 64), null
));
select is((select body ->> 'status' from prepared_message_media), 'prepared', 'assigned driver prepares message media');
select is((select state::text from public.communication_media_assets where id = '70000000-0000-4000-8000-000000000231'), 'staged', 'prepared media starts staged');
select is((public.mark_driver_message_media_uploaded(
  '70000000-0000-4000-8000-000000000231',
  '70000000-0000-4000-8000-000000000007', repeat('c', 64), 4096
) ->> 'status'), 'verified', 'matching uploaded media passes integrity verification');

create temporary table media_message_command (body jsonb not null) on commit drop;
insert into media_message_command values (jsonb_build_object(
  'schemaVersion', 1, 'commandType', 'thread.send_message',
  'commandId', '70000000-0000-4000-8000-000000000241',
  'traceId', '70000000-0000-4000-8000-000000000242',
  'idempotencyKey', 'message:THREAD-001:image',
  'tenantId', '70000000-0000-4000-8000-000000000001',
  'aggregateId', (select body ->> 'id' from thread_projection),
  'expectedVersion', 4,
  'occurredFromDeviceAt', '2026-09-02T03:03:00Z',
  'payload', jsonb_build_object(
    'body', '',
    'attachments', jsonb_build_array(jsonb_build_object(
      'kind', 'image',
      'mediaAssetId', '70000000-0000-4000-8000-000000000231',
      'fileName', 'package.jpg',
      'contentType', 'image/jpeg',
      'byteSize', 4096
    ))
  )
));
select is((public.send_driver_message_command((select body from media_message_command), '70000000-0000-4000-8000-000000000007') ->> 'status'), 'committed', 'verified rich media message commits atomically');
select is((select state::text from public.communication_media_assets where id = '70000000-0000-4000-8000-000000000231'), 'committed', 'message commit also commits its private media');
select is((public.ensure_driver_operations_thread(
  '70000000-0000-4000-8000-000000000130',
  '70000000-0000-4000-8000-000000000110',
  '70000000-0000-4000-8000-000000000007'
) -> 'messages' -> 3 -> 'attachments' -> 0 ->> 'kind'), 'image', 'driver thread projection returns verified media metadata');

set local role authenticated;
select throws_ok(
  $$select public.ensure_driver_operations_thread('70000000-0000-4000-8000-000000000130', '70000000-0000-4000-8000-000000000110', '70000000-0000-4000-8000-000000000007')$$,
  '42501', 'permission denied for function ensure_driver_operations_thread',
  'authenticated clients cannot execute thread projection directly'
);
select throws_ok(
  $$select public.send_driver_message_command('{}'::jsonb, '70000000-0000-4000-8000-000000000007')$$,
  '42501', 'permission denied for function send_driver_message_command',
  'authenticated clients cannot execute message commands directly'
);
select throws_ok(
  $$select public.send_operations_message_command('{}'::jsonb, '70000000-0000-4000-8000-000000000009')$$,
  '42501', 'permission denied for function send_operations_message_command',
  'authenticated clients cannot execute Operations message commands directly'
);
select throws_ok(
  $$select public.prepare_driver_message_media_asset('70000000-0000-4000-8000-000000000130', '70000000-0000-4000-8000-000000000110', '70000000-0000-4000-8000-000000000007', '70000000-0000-4000-8000-000000000251', 'image', 'x.jpg', 'image/jpeg', 1, repeat('d', 64), null)$$,
  '42501', 'permission denied for function prepare_driver_message_media_asset',
  'authenticated clients cannot prepare message media directly'
);
reset role;

select * from finish();
rollback;
