begin;

create extension if not exists pgtap with schema extensions;
select plan(8);

select has_function(
  'public',
  'can_receive_operations_dispatch_broadcast',
  array['text'],
  'Operations Broadcast topic authorization exists'
);
select has_function(
  'public',
  'broadcast_operations_communications_change',
  array[]::text[],
  'Operations communications Broadcast trigger function exists'
);
select has_trigger(
  'public',
  'operations_threads',
  'operations_communications_realtime',
  'Operations thread changes emit realtime hints'
);
select ok(
  has_function_privilege('authenticated', 'public.can_receive_operations_dispatch_broadcast(text)', 'EXECUTE'),
  'authenticated sessions can evaluate their Broadcast topic access'
);
select ok(
  not has_function_privilege('anon', 'public.can_receive_operations_dispatch_broadcast(text)', 'EXECUTE'),
  'anonymous sessions cannot evaluate private Broadcast topic access'
);

insert into public.tenants (id, slug, display_name) values
  ('99000000-0000-4000-8000-000000000001', 'realtime-auth-a', 'Realtime Auth A'),
  ('99000000-0000-4000-8000-000000000002', 'realtime-auth-b', 'Realtime Auth B');
insert into public.persons (id, display_name, email) values
  ('99000000-0000-4000-8000-000000000010', 'Realtime Dispatcher', 'realtime-dispatcher@test.invalid'),
  ('99000000-0000-4000-8000-000000000011', 'Realtime Driver', 'realtime-driver@test.invalid');
insert into auth.users (id, aud, role, email, created_at, updated_at) values
  ('99000000-0000-4000-8000-000000000020', 'authenticated', 'authenticated', 'realtime-dispatcher@test.invalid', now(), now()),
  ('99000000-0000-4000-8000-000000000021', 'authenticated', 'authenticated', 'realtime-driver@test.invalid', now(), now());
insert into public.auth_identities (auth_user_id, person_id) values
  ('99000000-0000-4000-8000-000000000020', '99000000-0000-4000-8000-000000000010'),
  ('99000000-0000-4000-8000-000000000021', '99000000-0000-4000-8000-000000000011');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at) values
  ('99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-000000000010', 'dispatcher', 'active', now()),
  ('99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-000000000011', 'team_driver', 'active', now());

set local request.jwt.claims = '{"sub":"99000000-0000-4000-8000-000000000020","role":"authenticated"}';
set local role authenticated;
select ok(
  public.can_receive_operations_dispatch_broadcast('tenant:99000000-0000-4000-8000-000000000001:dispatch'),
  'active dispatcher can receive the exact tenant Dispatch topic'
);
select ok(
  not public.can_receive_operations_dispatch_broadcast('tenant:99000000-0000-4000-8000-000000000002:dispatch'),
  'dispatcher cannot receive another tenant Dispatch topic'
);
reset role;

set local request.jwt.claims = '{"sub":"99000000-0000-4000-8000-000000000021","role":"authenticated"}';
set local role authenticated;
select ok(
  not public.can_receive_operations_dispatch_broadcast('tenant:99000000-0000-4000-8000-000000000001:dispatch'),
  'Team driver cannot receive the tenant-wide Operations topic'
);
reset role;

select * from finish();
rollback;
