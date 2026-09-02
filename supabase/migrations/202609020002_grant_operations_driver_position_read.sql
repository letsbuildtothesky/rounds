-- Operations planning reads the latest driver position only after the API has
-- authenticated the user and authorized the selected tenant. Browser roles
-- remain default-deny; the server service identity receives the one missing
-- table privilege required by that projection.

grant select on table public.driver_position_current to service_role;
