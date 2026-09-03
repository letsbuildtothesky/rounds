-- Operations History composes terminal return outcomes from durable domain truth.
-- The API service role needs read access to the return-confirmation audit evidence;
-- browser-facing anon/authenticated roles remain explicitly denied.

revoke all on table public.audit_events from anon, authenticated;
grant select on table public.audit_events to service_role;

