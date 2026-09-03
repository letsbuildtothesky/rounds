begin;

create extension if not exists pgtap with schema extensions;

select plan(22);

select has_function(
  'public',
  'plan_and_approve_round_command',
  array['jsonb', 'uuid'],
  'Team Round command exists'
);
select ok(
  has_function_privilege('service_role', 'public.plan_and_approve_round_command(jsonb,uuid)', 'EXECUTE'),
  'only the API service receives Round command execution'
);

insert into public.tenants (id, slug, display_name)
values ('30000000-0000-4000-8000-000000000001', 'round-test', 'Round Test');

insert into public.persons (id, display_name, email)
values
  ('30000000-0000-4000-8000-000000000007', 'Round Dispatcher', 'round-dispatcher@test.invalid'),
  ('30000000-0000-4000-8000-000000000008', 'Round Driver', 'round-driver@test.invalid');

insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at)
values
  ('30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000007', 'dispatcher', 'active', now()),
  ('30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000008', 'team_driver', 'active', now());

insert into public.driver_profiles (id, person_id, preferred_locale, vehicle_label)
values ('30000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000008', 'en', 'Motorbike');

insert into public.driver_tenant_relationships (
  tenant_id, driver_id, relationship_kind, status, permissions
) values (
  '30000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000002',
  'team',
  'active',
  '{"assigned_work":true}'::jsonb
);

insert into public.vehicle_profiles (
  id, tenant_id, code, display_name, vehicle_group, departure_pattern,
  max_stops_per_departure, planning_deliveries_per_block, pickup_turnaround_minutes
) values (
  '30000000-0000-4000-8000-000000000003',
  '30000000-0000-4000-8000-000000000001',
  'round-test-bike', 'Round Test Bike', 'motorbike', 'multi_stop', 4, 4, 15
);

insert into public.cargo_classes (id, tenant_id, code, display_name)
values (
  '30000000-0000-4000-8000-000000000004',
  '30000000-0000-4000-8000-000000000001',
  'test-bouquet', 'Test bouquet'
);

insert into public.vehicle_profile_cargo_limits (
  tenant_id, vehicle_profile_id, cargo_class_id, allowed, max_quantity
) values (
  '30000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000003',
  '30000000-0000-4000-8000-000000000004', true, 4
);

insert into public.driver_recurring_schedules (
  tenant_id, driver_id, weekdays, start_local, end_local, timezone, vehicle_profile_id, note
) values (
  '30000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000002',
  array[1,2,3,4,5]::smallint[], '08:00', '18:00', 'Asia/Bangkok',
  '30000000-0000-4000-8000-000000000003', 'Round command test capacity fixture'
);

insert into public.tenant_locations (
  id, tenant_id, code, display_name, raw_address, position, position_provenance,
  pickup_contact_name, pickup_contact_phone
) values (
  '30000000-0000-4000-8000-000000000020',
  '30000000-0000-4000-8000-000000000001',
  'studio', 'Round Test Studio', 'Bangkok',
  extensions.st_setsrid(extensions.st_makepoint(100.57::double precision, 13.73::double precision), 4326)::extensions.geography,
  'merchant_verified', 'Dispatch', '+66000000000'
);

create temporary table round_test_commands (name text primary key, body jsonb not null) on commit drop;

insert into round_test_commands values (
  'delivery',
  jsonb_build_object(
    'schemaVersion', 1,
    'commandType', 'delivery.create',
    'commandId', '30000000-0000-4000-8000-000000000101',
    'traceId', '30000000-0000-4000-8000-000000000102',
    'idempotencyKey', 'manual:ROUND-DELIVERY-001',
    'tenantId', '30000000-0000-4000-8000-000000000001',
    'aggregateId', '30000000-0000-4000-8000-000000000100',
    'expectedVersion', 0,
    'payload', jsonb_build_object(
      'sourceSystem', 'manual',
      'externalId', 'ROUND-DELIVERY-001',
      'reference', 'ROUND-DELIVERY-001',
      'serviceDate', '2026-09-02',
      'serviceTimezone', 'Asia/Bangkok',
      'pickupLocationId', '30000000-0000-4000-8000-000000000020',
      'recipient', jsonb_build_object(
        'name', 'Recipient', 'phone', '+66999999999', 'rawAddress', 'Bangkok',
        'coordinate', jsonb_build_object('latitude', 13.74, 'longitude', 100.54, 'provenance', 'dispatcher_pin')
      ),
      'buyer', jsonb_build_object('sameAsRecipient', true),
      'promise', jsonb_build_object('windowStart', '2026-09-02T02:00:00Z', 'windowEnd', '2026-09-02T04:00:00Z'),
      'manifest', jsonb_build_object('items', jsonb_build_array(jsonb_build_object(
        'description', 'Bouquet', 'quantity', 1, 'cargoClass', 'test-bouquet'
      )))
    )
  )
);

select is(
  (public.create_delivery_command((select body from round_test_commands where name = 'delivery'), '30000000-0000-4000-8000-000000000007') ->> 'status'),
  'committed',
  'test delivery is created through the canonical command'
);

select is(
  (public.get_own_team_round_capacity(
    '30000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000002',
    '2026-09-02',
    jsonb_build_array((select id from public.delivery_stops where delivery_id = '30000000-0000-4000-8000-000000000100'))
  ) ->> 'status'),
  'fits',
  'classified cargo fits the configured vehicle quantity limit'
);

update public.manifest_items set cargo_class = null
 where manifest_id = (select id from public.manifests where delivery_id = '30000000-0000-4000-8000-000000000100');
select is(
  (public.get_own_team_round_capacity(
    '30000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000002',
    '2026-09-02',
    jsonb_build_array((select id from public.delivery_stops where delivery_id = '30000000-0000-4000-8000-000000000100'))
  ) ->> 'status'),
  'review_required',
  'unclassified cargo can never silently fit'
);
update public.manifest_items set cargo_class = 'test-bouquet'
 where manifest_id = (select id from public.manifests where delivery_id = '30000000-0000-4000-8000-000000000100');

insert into round_test_commands
select 'round', jsonb_build_object(
  'schemaVersion', 1,
  'commandType', 'round.plan_and_approve',
  'commandId', '30000000-0000-4000-8000-000000000111',
  'traceId', '30000000-0000-4000-8000-000000000112',
  'idempotencyKey', 'round:ROUND-TEST-001',
  'tenantId', '30000000-0000-4000-8000-000000000001',
  'aggregateId', '30000000-0000-4000-8000-000000000110',
  'expectedVersion', 0,
  'payload', jsonb_build_object(
    'reference', 'ROUND-TEST-001',
    'serviceDate', '2026-09-02',
    'departureAt', '2026-09-02T01:00:00Z',
    'driverId', '30000000-0000-4000-8000-000000000002',
    'stopIds', jsonb_build_array(
      (select id from public.delivery_stops where delivery_id = '30000000-0000-4000-8000-000000000100')
    ),
    'routePlan', jsonb_build_object(
      'status', 'fits',
      'serviceDate', '2026-09-02',
      'driverId', '30000000-0000-4000-8000-000000000002',
      'stopIds', jsonb_build_array(
        (select id from public.delivery_stops where delivery_id = '30000000-0000-4000-8000-000000000100')
      ),
      'calculatedAt', '2026-09-01T12:00:00Z',
      'departureAt', '2026-09-02T01:00:00Z',
      'finishAt', '2026-09-02T02:15:00Z',
      'distanceMeters', 2500,
      'durationSeconds', 900,
      'provider', jsonb_build_object('name', 'mapbox', 'profile', 'driving-traffic', 'freshness', 'live'),
      'stops', jsonb_build_array(jsonb_build_object(
        'stopId', (select id from public.delivery_stops where delivery_id = '30000000-0000-4000-8000-000000000100'),
        'sequence', 1, 'eta', '2026-09-02T01:15:00Z', 'departureAt', '2026-09-02T02:00:00Z',
        'windowStart', '2026-09-02T02:00:00Z', 'windowEnd', '2026-09-02T04:00:00Z',
        'promiseStatus', 'early', 'waitingSeconds', 2700, 'latenessSeconds', 0,
        'legDurationSeconds', 900, 'legDistanceMeters', 2500
      )),
      'blockingReasons', jsonb_build_array(),
      'warnings', jsonb_build_array(),
      'capacity', jsonb_build_object('status', 'fits')
    )
  )
)
from round_test_commands where name = 'delivery';

select is(
  (public.plan_and_approve_round_command(
    (select body #- '{payload,routePlan}' from round_test_commands where name = 'round'),
    '30000000-0000-4000-8000-000000000007'
  ) -> 'error' ->> 'code'),
  'INVALID_STATE',
  'a Round cannot be approved without a matching server route fit'
);

select is(
  (public.plan_and_approve_round_command(
    (select body #- '{payload,departureAt}' from round_test_commands where name = 'round'),
    '30000000-0000-4000-8000-000000000007'
  ) -> 'error' ->> 'code'),
  'INVALID_STATE',
  'a Round cannot be approved without an explicit requested departure'
);

select is(
  (public.plan_and_approve_round_command(
    jsonb_set((select body from round_test_commands where name = 'round'), '{payload,departureAt}', '"2026-09-02T01:15:00Z"'::jsonb),
    '30000000-0000-4000-8000-000000000007'
  ) -> 'error' ->> 'code'),
  'INVALID_STATE',
  'a Round cannot be approved when the requested and routed departures differ'
);

select is(
  (public.plan_and_approve_round_command((select body from round_test_commands where name = 'round'), '30000000-0000-4000-8000-000000000007') ->> 'status'),
  'committed',
  'authorized dispatcher commits a Team Round'
);
select is(
  (select state::text from public.rounds where id = '30000000-0000-4000-8000-000000000110'),
  'approved',
  'Round is approved for Driver retrieval'
);
select is(
  (select driver_id from public.rounds where id = '30000000-0000-4000-8000-000000000110'),
  '30000000-0000-4000-8000-000000000002'::uuid,
  'Round belongs to the selected Team driver'
);
select is(
  (select sequence from public.round_stops where round_id = '30000000-0000-4000-8000-000000000110'),
  1,
  'explicit Stop order is persisted'
);
select is(
  (select route_plan_snapshot -> 'provider' ->> 'name' from public.rounds where id = '30000000-0000-4000-8000-000000000110'),
  'mapbox',
  'the provider-neutral route evidence is snapshotted on approval'
);
select is(
  (select state::text from public.deliveries where id = '30000000-0000-4000-8000-000000000100'),
  'assigned',
  'delivery advances through planned to assigned'
);
select is(
  (select version from public.deliveries where id = '30000000-0000-4000-8000-000000000100'),
  3::bigint,
  'both delivery transitions increment aggregate version'
);
select is(
  (select state::text from public.delivery_stops where delivery_id = '30000000-0000-4000-8000-000000000100'),
  'assigned',
  'Stop is assigned atomically'
);
select is(
  (select count(*) from public.audit_events where aggregate_id = '30000000-0000-4000-8000-000000000110'),
  1::bigint,
  'Round approval is audited'
);
select is(
  (select count(*) from public.domain_event_outbox where aggregate_id = '30000000-0000-4000-8000-000000000110'),
  1::bigint,
  'Round approval stages one event'
);
select is(
  (public.plan_and_approve_round_command((select body from round_test_commands where name = 'round'), '30000000-0000-4000-8000-000000000007') -> 'state' ->> 'roundId'),
  '30000000-0000-4000-8000-000000000110',
  'same idempotency key returns the committed Round'
);
select is(
  (select count(*) from public.rounds where tenant_id = '30000000-0000-4000-8000-000000000001'),
  1::bigint,
  'retry cannot duplicate the Round'
);
select is(
  (public.plan_and_approve_round_command(
    jsonb_set((select body from round_test_commands where name = 'round'), '{payload,reference}', '"CHANGED"'::jsonb),
    '30000000-0000-4000-8000-000000000007'
  ) -> 'error' ->> 'code'),
  'IDEMPOTENCY_CONFLICT',
  'same key with changed plan conflicts'
);
set local role authenticated;

select throws_ok(
  $$select public.plan_and_approve_round_command('{}'::jsonb, '30000000-0000-4000-8000-000000000007')$$,
  '42501',
  'permission denied for function plan_and_approve_round_command',
  'authenticated clients cannot execute the server command directly'
);

reset role;
select * from finish();
rollback;
