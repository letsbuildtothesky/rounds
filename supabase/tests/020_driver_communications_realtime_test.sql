begin;

create extension if not exists pgtap with schema extensions;
select plan(9);

select has_function(
  'public',
  'can_receive_driver_communications_broadcast',
  array['text'],
  'Driver Broadcast topic authorization exists'
);
select has_trigger(
  'public',
  'operations_threads',
  'operations_communications_realtime',
  'Operations thread changes retain their realtime trigger'
);
select ok(
  has_function_privilege('authenticated', 'public.can_receive_driver_communications_broadcast(text)', 'EXECUTE'),
  'authenticated sessions can evaluate their Driver Broadcast topic access'
);
select ok(
  not has_function_privilege('anon', 'public.can_receive_driver_communications_broadcast(text)', 'EXECUTE'),
  'anonymous sessions cannot evaluate private Driver Broadcast topic access'
);
select ok(
  exists (
    select 1 from pg_policies
     where schemaname = 'realtime'
       and tablename = 'messages'
       and policyname = 'driver_communications_receive_broadcast'
  ),
  'Realtime messages has the private Driver receive policy'
);

insert into public.tenants (id, slug, display_name) values
  ('99100000-0000-4000-8000-000000000001', 'driver-realtime-a', 'Driver Realtime A');
insert into public.persons (id, display_name, email) values
  ('99100000-0000-4000-8000-000000000010', 'Realtime Team Driver', 'driver-realtime@test.invalid'),
  ('99100000-0000-4000-8000-000000000011', 'Realtime Operations', 'operations-realtime@test.invalid');
insert into auth.users (id, aud, role, email, created_at, updated_at) values
  ('99100000-0000-4000-8000-000000000020', 'authenticated', 'authenticated', 'driver-realtime@test.invalid', now(), now()),
  ('99100000-0000-4000-8000-000000000021', 'authenticated', 'authenticated', 'operations-realtime@test.invalid', now(), now());
insert into public.auth_identities (auth_user_id, person_id) values
  ('99100000-0000-4000-8000-000000000020', '99100000-0000-4000-8000-000000000010'),
  ('99100000-0000-4000-8000-000000000021', '99100000-0000-4000-8000-000000000011');
insert into public.driver_profiles (id, person_id, preferred_locale) values
  ('99100000-0000-4000-8000-000000000030', '99100000-0000-4000-8000-000000000010', 'en');
insert into public.tenant_memberships (tenant_id, person_id, role, status, activated_at) values
  ('99100000-0000-4000-8000-000000000001', '99100000-0000-4000-8000-000000000010', 'team_driver', 'active', now()),
  ('99100000-0000-4000-8000-000000000001', '99100000-0000-4000-8000-000000000011', 'dispatcher', 'active', now());
insert into public.driver_tenant_relationships (
  tenant_id, driver_id, relationship_kind, status
) values (
  '99100000-0000-4000-8000-000000000001',
  '99100000-0000-4000-8000-000000000030',
  'team',
  'active'
);

set local request.jwt.claims = '{"sub":"99100000-0000-4000-8000-000000000020","role":"authenticated"}';
set local role authenticated;
select ok(
  public.can_receive_driver_communications_broadcast('driver:99100000-0000-4000-8000-000000000030'),
  'active Team driver can receive their exact Driver topic'
);
select ok(
  not public.can_receive_driver_communications_broadcast('driver:99100000-0000-4000-8000-000000000099'),
  'Team driver cannot receive another Driver topic'
);
reset role;

update public.driver_tenant_relationships
   set status = 'inactive'
 where driver_id = '99100000-0000-4000-8000-000000000030';
set local role authenticated;
select ok(
  not public.can_receive_driver_communications_broadcast('driver:99100000-0000-4000-8000-000000000030'),
  'inactive Team relationship cannot receive the Driver topic'
);
reset role;

set local request.jwt.claims = '{"sub":"99100000-0000-4000-8000-000000000021","role":"authenticated"}';
set local role authenticated;
select ok(
  not public.can_receive_driver_communications_broadcast('driver:99100000-0000-4000-8000-000000000030'),
  'Operations identity cannot subscribe to a Driver-scoped topic'
);
reset role;

select * from finish();
rollback;
