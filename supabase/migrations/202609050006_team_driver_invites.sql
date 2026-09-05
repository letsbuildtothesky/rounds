-- Canonical A02-A05 Team-driver entry: verified phone identity plus a
-- single-use, expiring business invitation. Raw invite codes are never stored.

create type public.team_driver_invite_status as enum (
  'pending',
  'accepted',
  'revoked'
);

create table public.team_driver_invites (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  invited_phone_e164 text not null check (invited_phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  invited_display_name text not null check (length(btrim(invited_display_name)) between 1 and 160),
  business_initials text not null check (length(btrim(business_initials)) between 1 and 4),
  location_label text not null check (length(btrim(location_label)) between 1 and 120),
  code_digest text not null unique check (length(code_digest) = 64),
  status public.team_driver_invite_status not null default 'pending',
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by_person_id uuid references public.persons(id) on delete restrict,
  created_by_person_id uuid references public.persons(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'accepted') = (accepted_at is not null)),
  check ((status = 'accepted') = (accepted_by_person_id is not null))
);

create index team_driver_invites_phone_pending_idx
  on public.team_driver_invites (invited_phone_e164, expires_at desc)
  where status = 'pending';

alter table public.team_driver_invites enable row level security;

create or replace function public.pending_team_driver_invite(
  p_auth_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_phone text;
  v_result jsonb;
begin
  select phone into v_phone
  from auth.users
  where id = p_auth_user_id
    and phone_confirmed_at is not null;
  if v_phone is null then
    return null;
  end if;

  select jsonb_build_object(
    'id', invite.id,
    'tenantId', invite.tenant_id,
    'businessName', tenant.display_name,
    'businessInitials', invite.business_initials,
    'locationLabel', invite.location_label,
    'expiresAt', invite.expires_at
  ) into v_result
  from public.team_driver_invites invite
  join public.tenants tenant on tenant.id = invite.tenant_id
  where invite.invited_phone_e164 = v_phone
    and invite.status = 'pending'
    and invite.expires_at > now()
    and tenant.status = 'active'
    and tenant.deleted_at is null
  order by invite.created_at desc
  limit 1;
  return v_result;
end;
$$;

create or replace function public.resolve_team_driver_invite(
  p_auth_user_id uuid,
  p_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_phone text;
  v_result jsonb;
begin
  if coalesce(p_code, '') !~ '^[0-9]{6}$' then
    return null;
  end if;
  select phone into v_phone
  from auth.users
  where id = p_auth_user_id
    and phone_confirmed_at is not null;
  if v_phone is null then
    return null;
  end if;

  select jsonb_build_object(
    'id', invite.id,
    'tenantId', invite.tenant_id,
    'businessName', tenant.display_name,
    'businessInitials', invite.business_initials,
    'locationLabel', invite.location_label,
    'expiresAt', invite.expires_at
  ) into v_result
  from public.team_driver_invites invite
  join public.tenants tenant on tenant.id = invite.tenant_id
  where invite.code_digest = encode(digest(p_code, 'sha256'), 'hex')
    and invite.invited_phone_e164 = v_phone
    and invite.status = 'pending'
    and invite.expires_at > now()
    and tenant.status = 'active'
    and tenant.deleted_at is null
  limit 1;
  return v_result;
end;
$$;

create or replace function public.accept_team_driver_invite(
  p_auth_user_id uuid,
  p_invite_id uuid,
  p_code text default null,
  p_preferred_locale text default 'en'
)
returns boolean
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_phone text;
  v_invite public.team_driver_invites%rowtype;
  v_person_id uuid;
  v_existing_phone text;
  v_driver_id uuid;
  v_relationship_version bigint;
  v_event_id uuid := gen_random_uuid();
begin
  if p_preferred_locale not in ('th-TH', 'en') then
    return false;
  end if;
  select phone into v_phone
  from auth.users
  where id = p_auth_user_id
    and phone_confirmed_at is not null;
  if v_phone is null then
    return false;
  end if;

  select * into v_invite
  from public.team_driver_invites
  where id = p_invite_id
  for update;
  if not found then
    return false;
  end if;
  if v_invite.status <> 'pending'
    or v_invite.expires_at <= now()
    or v_invite.invited_phone_e164 <> v_phone
    or (p_code is not null and (
      p_code !~ '^[0-9]{6}$'
      or v_invite.code_digest <> encode(digest(p_code, 'sha256'), 'hex')
    )) then
    return false;
  end if;

  select identity.person_id, person.phone_e164
    into v_person_id, v_existing_phone
  from public.auth_identities identity
  join public.persons person on person.id = identity.person_id
  where identity.auth_user_id = p_auth_user_id;
  if v_person_id is not null and v_existing_phone is not null and v_existing_phone <> v_phone then
    return false;
  end if;

  if v_person_id is null then
    select id into v_person_id
    from public.persons
    where phone_e164 = v_phone and deleted_at is null
    order by created_at
    limit 1;
  end if;
  if v_person_id is null then
    insert into public.persons (display_name, phone_e164)
    values (v_invite.invited_display_name, v_phone)
    returning id into v_person_id;
  else
    update public.persons
    set phone_e164 = coalesce(phone_e164, v_phone), updated_at = now()
    where id = v_person_id;
  end if;

  insert into public.auth_identities (auth_user_id, person_id)
  values (p_auth_user_id, v_person_id)
  on conflict (auth_user_id) do nothing;

  insert into public.driver_profiles (person_id, preferred_locale)
  values (v_person_id, p_preferred_locale)
  on conflict (person_id) do update
    set preferred_locale = excluded.preferred_locale,
        active = true,
        deleted_at = null,
        updated_at = now()
  returning id into v_driver_id;

  insert into public.tenant_memberships (
    tenant_id, person_id, role, status, activated_at
  ) values (
    v_invite.tenant_id, v_person_id, 'team_driver', 'active', now()
  )
  on conflict (tenant_id, person_id, role) do update
    set status = 'active', activated_at = coalesce(public.tenant_memberships.activated_at, now()),
        revoked_at = null, updated_at = now();

  insert into public.driver_tenant_relationships (
    tenant_id, driver_id, relationship_kind, status
  ) values (
    v_invite.tenant_id, v_driver_id, 'team', 'active'
  )
  on conflict (tenant_id, driver_id) do update
    set relationship_kind = 'team', status = 'active', deleted_at = null,
        version = public.driver_tenant_relationships.version + 1,
        updated_at = now()
  returning version into v_relationship_version;

  update public.team_driver_invites
  set status = 'accepted', accepted_at = now(),
      accepted_by_person_id = v_person_id, updated_at = now()
  where id = v_invite.id;

  insert into public.audit_events (
    id, tenant_id, actor_person_id, actor_role, action, aggregate_type,
    aggregate_id, aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_event_id, v_invite.tenant_id, v_person_id, 'team_driver',
    'driver.team_invite_accepted', 'driver_tenant_relationship', v_driver_id,
    v_relationship_version, v_event_id, v_event_id,
    jsonb_build_object('inviteId', v_invite.id, 'phoneVerified', true)
  );
  return true;
end;
$$;

revoke all on table public.team_driver_invites from public, anon, authenticated;
revoke all on function public.pending_team_driver_invite(uuid) from public, anon, authenticated;
revoke all on function public.resolve_team_driver_invite(uuid, text) from public, anon, authenticated;
revoke all on function public.accept_team_driver_invite(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.pending_team_driver_invite(uuid) to service_role;
grant execute on function public.resolve_team_driver_invite(uuid, text) to service_role;
grant execute on function public.accept_team_driver_invite(uuid, uuid, text, text) to service_role;
