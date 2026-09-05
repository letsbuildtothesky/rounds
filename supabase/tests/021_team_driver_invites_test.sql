begin;

create extension if not exists pgtap with schema extensions;
select plan(8);

select has_table('public', 'team_driver_invites', 'Team invitations have a durable source of truth');
select has_function('public', 'pending_team_driver_invite', array['uuid'], 'Verified phone can resolve its pending invite');
select has_function('public', 'resolve_team_driver_invite', array['uuid', 'text'], 'Manual invite code can be resolved');
select has_function('public', 'accept_team_driver_invite', array['uuid', 'uuid', 'text', 'text'], 'Team invitation can be accepted transactionally');
select ok(
  has_function_privilege('service_role', 'public.pending_team_driver_invite(uuid)', 'EXECUTE'),
  'API service can read a matching pending invite'
);
select ok(
  not has_function_privilege('authenticated', 'public.resolve_team_driver_invite(uuid,text)', 'EXECUTE'),
  'Driver clients cannot bypass the API to inspect invite codes'
);
select ok(
  not has_function_privilege('authenticated', 'public.accept_team_driver_invite(uuid,uuid,text,text)', 'EXECUTE'),
  'Driver clients cannot create their own Team relationship'
);
select ok(
  not has_table_privilege('authenticated', 'public.team_driver_invites', 'SELECT'),
  'Invitation records are not directly readable by Driver clients'
);

select * from finish();
rollback;
