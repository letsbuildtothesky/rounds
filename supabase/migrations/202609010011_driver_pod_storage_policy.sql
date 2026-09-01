-- The hosted Storage service for this project does not accept presigned TUS
-- x-signature tokens without an additional server credential. Never expose
-- that credential to a driver device. Authorize the driver's normal Supabase
-- session for only the exact staged object prepared by the Rounds API.

create or replace function public.can_access_pod_object(
  p_bucket text,
  p_path text,
  p_require_staged boolean
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select p_bucket = 'pod-evidence' and exists (
    select 1
      from public.media_assets asset
      join public.driver_profiles driver on driver.id = asset.driver_id
      join public.auth_identities identity on identity.person_id = driver.person_id
     where asset.storage_bucket = p_bucket
       and asset.storage_path = p_path
       and (
         (p_require_staged and asset.state = 'staged')
         or (not p_require_staged and asset.state in ('staged', 'uploaded_uncommitted', 'committed'))
       )
       and identity.auth_user_id = (select auth.uid())
  );
$$;

revoke all on function public.can_access_pod_object(text, text, boolean) from public, anon;
grant execute on function public.can_access_pod_object(text, text, boolean) to authenticated;

create policy pod_evidence_driver_select_exact_staged_object
on storage.objects for select to authenticated
using (
  public.can_access_pod_object(bucket_id, name, false)
);

create policy pod_evidence_driver_insert_exact_staged_object
on storage.objects for insert to authenticated
with check (
  public.can_access_pod_object(bucket_id, name, true)
);

create policy pod_evidence_driver_update_exact_staged_object
on storage.objects for update to authenticated
using (
  public.can_access_pod_object(bucket_id, name, true)
)
with check (
  public.can_access_pod_object(bucket_id, name, true)
);

comment on policy pod_evidence_driver_insert_exact_staged_object on storage.objects is
  'A driver session may upload only a server-prepared staged POD object owned by that driver.';
