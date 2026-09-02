-- Operations identity onboarding is deliberately narrower than granting the API
-- service direct INSERT/UPDATE privileges on the identity tables.

create or replace function public.link_operations_auth_identity(
  p_auth_user_id uuid,
  p_person_id uuid,
  p_verified_email text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_auth_email text;
  v_membership public.tenant_memberships%rowtype;
  v_existing_person_id uuid;
begin
  if p_auth_user_id is null or p_person_id is null or nullif(btrim(p_verified_email), '') is null then
    raise exception 'VALIDATION_FAILED: auth user, person and verified email are required'
      using errcode = '22023';
  end if;

  select lower(email) into v_auth_email
  from auth.users
  where id = p_auth_user_id
    and email_confirmed_at is not null;
  if v_auth_email is null or v_auth_email <> lower(btrim(p_verified_email)) then
    raise exception 'NOT_AUTHORIZED: Supabase email is not verified or does not match'
      using errcode = '42501';
  end if;

  select * into v_membership
  from public.tenant_memberships
  where person_id = p_person_id
    and status = 'active'
    and role in ('tenant_owner', 'operations_admin', 'dispatcher', 'viewer')
  order by case role
    when 'tenant_owner' then 1
    when 'operations_admin' then 2
    when 'dispatcher' then 3
    else 4
  end
  limit 1;
  if not found then
    raise exception 'NOT_AUTHORIZED: person has no active Operations membership'
      using errcode = '42501';
  end if;

  select person_id into v_existing_person_id
  from public.auth_identities
  where auth_user_id = p_auth_user_id;
  if v_existing_person_id is not null and v_existing_person_id <> p_person_id then
    raise exception 'CONFLICT: auth user is linked to another person'
      using errcode = '23505';
  end if;

  insert into public.auth_identities (auth_user_id, person_id)
  values (p_auth_user_id, p_person_id)
  on conflict (auth_user_id) do nothing;

  return jsonb_build_object(
    'status', 'linked',
    'authUserId', p_auth_user_id,
    'personId', p_person_id,
    'tenantId', v_membership.tenant_id,
    'role', v_membership.role
  );
end;
$$;

revoke all on function public.link_operations_auth_identity(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.link_operations_auth_identity(uuid, uuid, text) to service_role;
