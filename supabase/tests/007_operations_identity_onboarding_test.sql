begin;

create extension if not exists pgtap with schema extensions;
select plan(4);

select has_function(
  'public',
  'link_operations_auth_identity',
  array['uuid', 'uuid', 'text'],
  'Operations identity onboarding boundary exists'
);
select ok(
  has_function_privilege('service_role', 'public.link_operations_auth_identity(uuid,uuid,text)', 'EXECUTE'),
  'API service can invoke Operations identity onboarding'
);
select ok(
  not has_function_privilege('authenticated', 'public.link_operations_auth_identity(uuid,uuid,text)', 'EXECUTE'),
  'authenticated clients cannot link their own identities'
);
select ok(
  not has_table_privilege('service_role', 'public.auth_identities', 'INSERT'),
  'API service still cannot insert identity links directly'
);

select * from finish();
rollback;
