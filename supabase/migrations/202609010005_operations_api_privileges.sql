-- The Rounds API uses the Supabase secret/service identity after authenticating
-- the browser access token. Keep browser roles default-deny while granting only
-- the reads needed to resolve an Operations actor and their pickup locations.

grant select on table
  public.tenants,
  public.persons,
  public.auth_identities,
  public.tenant_memberships,
  public.tenant_locations
to service_role;

revoke all on table
  public.persons,
  public.auth_identities,
  public.tenant_memberships
from anon, authenticated;

comment on table public.auth_identities is
  'Server-readable identity link. Browser roles have no direct access; the Operations session API returns a purpose-limited projection.';
