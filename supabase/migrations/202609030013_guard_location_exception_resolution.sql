-- GAP-006/GAP-007 safety boundary. Location observations may place a Stop on
-- an Operations hold, but no existing generic resolver may silently turn that
-- observation into authoritative address, pin, custody, or route truth.

create or replace function public.guard_unapproved_location_exception_resolution()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.category::text in (
      'wrong_pin',
      'wrong_entrance',
      'wrong_address',
      'cannot_find_location'
    )
    and (new.status is distinct from old.status or new.resolved_at is distinct from old.resolved_at)
  then
    raise exception using
      errcode = '23514',
      message = 'LOCATION_RESOLUTION_POLICY_REQUIRED';
  end if;

  return new;
end;
$$;

drop trigger if exists delivery_exceptions_guard_location_resolution
  on public.delivery_exceptions;

create trigger delivery_exceptions_guard_location_resolution
before update of status, resolved_at on public.delivery_exceptions
for each row
execute function public.guard_unapproved_location_exception_resolution();

revoke all on function public.guard_unapproved_location_exception_resolution() from public, anon, authenticated;

comment on function public.guard_unapproved_location_exception_resolution() is
  'Blocks location-exception resolution until GAP-006/GAP-007 correction and acknowledgement policy is approved.';
