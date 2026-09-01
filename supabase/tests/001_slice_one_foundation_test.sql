begin;

create extension if not exists pgtap with schema extensions;

select plan(27);

select has_table('public', 'tenants', 'tenants table exists');
select has_table('public', 'deliveries', 'deliveries table exists');
select has_table('public', 'command_idempotency', 'command replay ledger exists');
select has_table('public', 'domain_event_outbox', 'transactional outbox exists');

insert into public.tenants (id, slug, display_name)
values
  ('10000000-0000-4000-8000-000000000001', 'urbanflowers-test', 'UrbanFlowers Test'),
  ('20000000-0000-4000-8000-000000000001', 'other-merchant-test', 'Other Merchant Test');

insert into public.persons (id, display_name, email)
values
  ('10000000-0000-4000-8000-000000000010', 'UrbanFlowers Dispatcher', 'dispatcher@test.invalid'),
  ('20000000-0000-4000-8000-000000000010', 'Other Merchant Dispatcher', 'other@test.invalid');

insert into public.tenant_memberships (
  tenant_id, person_id, role, status, activated_at
)
values
  (
    '10000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000010',
    'dispatcher',
    'active',
    now()
  ),
  (
    '20000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000010',
    'dispatcher',
    'active',
    now()
  );

insert into public.tenant_locations (
  id, tenant_id, code, display_name, raw_address,
  position, position_provenance, pickup_contact_name, pickup_contact_phone
)
values
  (
    '10000000-0000-4000-8000-000000000020',
    '10000000-0000-4000-8000-000000000001',
    'sukhumvit-39',
    'UrbanFlowers · Sukhumvit 39',
    'Sukhumvit 39, Bangkok',
    st_setsrid(st_makepoint(100.5731, 13.7378), 4326)::extensions.geography,
    'merchant_verified',
    'UrbanFlowers Dispatch',
    '+66000000000'
  ),
  (
    '20000000-0000-4000-8000-000000000020',
    '20000000-0000-4000-8000-000000000001',
    'other',
    'Other Merchant',
    'Bangkok',
    st_setsrid(st_makepoint(100.55, 13.75), 4326)::extensions.geography,
    'merchant_verified',
    'Other Dispatch',
    '+66111111111'
  );

create temporary table test_commands (
  name text primary key,
  body jsonb not null
) on commit drop;

insert into test_commands (name, body)
values (
  'create',
  jsonb_build_object(
    'schemaVersion', 1,
    'commandType', 'delivery.create',
    'commandId', '10000000-0000-4000-8000-000000000101',
    'traceId', '10000000-0000-4000-8000-000000000102',
    'idempotencyKey', 'manual:UF-TEST-001',
    'tenantId', '10000000-0000-4000-8000-000000000001',
    'aggregateId', '10000000-0000-4000-8000-000000000100',
    'expectedVersion', 0,
    'payload', jsonb_build_object(
      'sourceSystem', 'manual',
      'externalId', 'UF-TEST-001',
      'reference', 'UF-TEST-001',
      'serviceDate', '2026-09-02',
      'serviceTimezone', 'Asia/Bangkok',
      'pickupLocationId', '10000000-0000-4000-8000-000000000020',
      'recipient', jsonb_build_object(
        'name', 'Siriporn',
        'phone', '+66999999999',
        'rawAddress', 'Park Hyatt Bangkok, Wireless Road',
        'coordinate', jsonb_build_object(
          'latitude', 13.7439,
          'longitude', 100.5470,
          'provenance', 'dispatcher_pin'
        ),
        'accessNote', 'Hotel reception'
      ),
      'buyer', jsonb_build_object('sameAsRecipient', true),
      'promise', jsonb_build_object(
        'windowStart', '2026-09-02T02:00:00Z',
        'windowEnd', '2026-09-02T04:00:00Z'
      ),
      'manifest', jsonb_build_object(
        'items', jsonb_build_array(
          jsonb_build_object(
            'sku', 'BOUQUET-001',
            'description', 'Flower bouquet',
            'quantity', 1,
            'cargoClass', 'fragile'
          ),
          jsonb_build_object(
            'description', 'Message card',
            'quantity', 1
          )
        )
      ),
      'note', 'Call before arrival',
      'isSurprise', true
    )
  )
);

select is(
  (public.create_delivery_command(
    (select body from test_commands where name = 'create'),
    '10000000-0000-4000-8000-000000000010'
  ) ->> 'status'),
  'committed',
  'authorized canonical delivery command commits'
);

select is(
  (select count(*) from public.deliveries where id = '10000000-0000-4000-8000-000000000100'),
  1::bigint,
  'one delivery is created'
);
select is(
  (select count(*) from public.delivery_stops where delivery_id = '10000000-0000-4000-8000-000000000100'),
  1::bigint,
  'one stable delivery Stop is created'
);
select is(
  (select count(*)
     from public.manifest_items item
     join public.manifests manifest on manifest.id = item.manifest_id
    where manifest.delivery_id = '10000000-0000-4000-8000-000000000100'),
  2::bigint,
  'manifest item lines are normalized'
);
select is(
  (select count(*) from public.audit_events where aggregate_id = '10000000-0000-4000-8000-000000000100'),
  1::bigint,
  'delivery creation is audited'
);
select is(
  (select count(*) from public.domain_event_outbox where aggregate_id = '10000000-0000-4000-8000-000000000100'),
  1::bigint,
  'delivery creation stages one event atomically'
);
select ok(
  (select audit.trace_id = outbox.trace_id
     from public.audit_events audit
     join public.domain_event_outbox outbox using (tenant_id, aggregate_id)
    where audit.aggregate_id = '10000000-0000-4000-8000-000000000100'),
  'audit and event preserve the trace id'
);

select is(
  (public.create_delivery_command(
    (select body from test_commands where name = 'create'),
    '10000000-0000-4000-8000-000000000010'
  ) -> 'state' ->> 'deliveryId'),
  '10000000-0000-4000-8000-000000000100',
  'same idempotency key and payload returns original result'
);
select is(
  (select count(*) from public.deliveries where tenant_id = '10000000-0000-4000-8000-000000000001'),
  1::bigint,
  'same command cannot duplicate the delivery'
);

select is(
  (public.create_delivery_command(
    jsonb_set(
      (select body from test_commands where name = 'create'),
      '{payload,recipient,name}',
      '"Changed recipient"'::jsonb
    ),
    '10000000-0000-4000-8000-000000000010'
  ) -> 'error' ->> 'code'),
  'IDEMPOTENCY_CONFLICT',
  'same idempotency key with different payload is rejected'
);

select is(
  (public.create_delivery_command(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          (select body from test_commands where name = 'create'),
          '{commandId}',
          '"10000000-0000-4000-8000-000000000111"'::jsonb
        ),
        '{aggregateId}',
        '"10000000-0000-4000-8000-000000000110"'::jsonb
      ),
      '{idempotencyKey}',
      '"manual:UF-TEST-001:retry"'::jsonb
    ),
    '10000000-0000-4000-8000-000000000010'
  ) ->> 'deduplicated'),
  'true',
  'same external source id and payload is deduplicated across command keys'
);
select is(
  (select count(*) from public.deliveries where tenant_id = '10000000-0000-4000-8000-000000000001'),
  1::bigint,
  'external source retry cannot duplicate the delivery'
);

select is(
  (public.create_delivery_command(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(
            (select body from test_commands where name = 'create'),
            '{commandId}',
            '"10000000-0000-4000-8000-000000000121"'::jsonb
          ),
          '{aggregateId}',
          '"10000000-0000-4000-8000-000000000120"'::jsonb
        ),
        '{idempotencyKey}',
        '"manual:UF-TEST-002"'::jsonb
      ),
      '{payload,externalId}',
      '"UF-TEST-002"'::jsonb
    ),
    '20000000-0000-4000-8000-000000000010'
  ) -> 'error' ->> 'code'),
  'NOT_AUTHORIZED',
  'actor from another tenant is not authorized'
);

select is(
  (public.create_delivery_command(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              (select body from test_commands where name = 'create'),
              '{commandId}',
              '"10000000-0000-4000-8000-000000000131"'::jsonb
            ),
            '{aggregateId}',
            '"10000000-0000-4000-8000-000000000130"'::jsonb
          ),
          '{idempotencyKey}',
          '"manual:UF-TEST-003"'::jsonb
        ),
        '{payload,externalId}',
        '"UF-TEST-003"'::jsonb
      ),
      '{payload,pickupLocationId}',
      '"20000000-0000-4000-8000-000000000020"'::jsonb
    ),
    '10000000-0000-4000-8000-000000000010'
  ) -> 'error' ->> 'code'),
  'VALIDATION_FAILED',
  'cross-tenant pickup location is rejected'
);
select is(
  (select count(*) from public.deliveries where id = '10000000-0000-4000-8000-000000000130'),
  0::bigint,
  'rejected command leaves no partial delivery'
);

set local request.jwt.claims = '{"active_tenant_id":"10000000-0000-4000-8000-000000000001","tenant_role":"dispatcher"}';
set local role authenticated;

select is(
  (select count(*) from public.deliveries),
  1::bigint,
  'authenticated dispatcher reads only the active tenant'
);
select throws_ok(
  $$update public.deliveries set reference = 'forged' where id = '10000000-0000-4000-8000-000000000100'$$,
  '42501',
  'permission denied for table deliveries',
  'authenticated client cannot direct-write delivery truth'
);
select throws_ok(
  $$select public.create_delivery_command('{}'::jsonb, '10000000-0000-4000-8000-000000000010')$$,
  '42501',
  'permission denied for function create_delivery_command',
  'authenticated client cannot execute the server command RPC'
);

reset role;
set local request.jwt.claims = '{"active_tenant_id":"20000000-0000-4000-8000-000000000001","tenant_role":"viewer"}';
set local role authenticated;

select is(
  (select count(*) from public.deliveries),
  0::bigint,
  'tenant B cannot read tenant A delivery'
);

reset role;

select throws_ok(
  $$update public.deliveries
       set state = 'delivered', version = version + 1
     where id = '10000000-0000-4000-8000-000000000100'$$,
  '23514',
  'INVALID_STATE: unplanned -> delivered',
  'invalid delivery state jump is blocked'
);
select throws_ok(
  $$update public.deliveries
       set reference = 'stale-write'
     where id = '10000000-0000-4000-8000-000000000100'$$,
  '40001',
  'STALE_VERSION: delivery version must increase',
  'delivery mutation without version increment is blocked'
);

update public.deliveries
   set state = 'planned', version = version + 1
 where id = '10000000-0000-4000-8000-000000000100';

select is(
  (select state::text from public.deliveries where id = '10000000-0000-4000-8000-000000000100'),
  'planned',
  'valid versioned delivery transition succeeds'
);

update public.manifests
   set state = 'picked_up_locked', locked_at = now(), version = version + 1
 where delivery_id = '10000000-0000-4000-8000-000000000100';

select throws_ok(
  $$insert into public.manifest_items (
       tenant_id, manifest_id, line_number, description, quantity
     )
     select tenant_id, id, 3, 'Late mutation', 1
       from public.manifests
      where delivery_id = '10000000-0000-4000-8000-000000000100'$$,
  '23514',
  'CUSTODY_LOCKED: picked-up manifest is immutable',
  'picked-up manifest item lines are immutable'
);

select * from finish();
rollback;
