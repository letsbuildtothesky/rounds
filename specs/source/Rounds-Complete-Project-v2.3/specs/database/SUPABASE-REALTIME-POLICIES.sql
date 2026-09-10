-- Apply in Supabase after all V2.2 role files. The migration identity must be able to CREATE ROLE and set function ownership.
CREATE ROLE rounds_auth_resolver NOLOGIN NOSUPERUSER NOBYPASSRLS;
GRANT USAGE ON SCHEMA rounds,auth TO rounds_auth_resolver;
GRANT EXECUTE ON FUNCTION auth.uid() TO rounds_auth_resolver;
GRANT SELECT(id,auth_subject,disabled_at) ON rounds.principals TO rounds_auth_resolver;
CREATE POLICY auth_resolver_self ON rounds.principals FOR SELECT TO rounds_auth_resolver USING(auth_subject=auth.uid());
-- Apply after role policies, in Supabase with auth.uid(), authenticated, realtime.messages/topic().
-- Narrow SECURITY DEFINER identity lookup; returns only current auth principal ID.
CREATE OR REPLACE FUNCTION rounds.auth_principal_id() RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT p.id FROM rounds.principals p WHERE p.auth_subject=auth.uid() AND p.disabled_at IS NULL $$;
ALTER FUNCTION rounds.auth_principal_id() OWNER TO rounds_auth_resolver;
REVOKE ALL ON FUNCTION rounds.auth_principal_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rounds.auth_principal_id() TO authenticated;
GRANT USAGE ON SCHEMA rounds TO authenticated;
GRANT SELECT ON rounds.realtime_grants TO authenticated;
CREATE POLICY own_realtime_grants ON rounds.realtime_grants FOR SELECT TO authenticated USING(principal_id=rounds.auth_principal_id() AND revoked_at IS NULL AND expires_at>now());
CREATE POLICY rounds_private_receive ON realtime.messages FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM rounds.realtime_grants g WHERE g.principal_id=rounds.auth_principal_id() AND g.topic=realtime.topic() AND g.revoked_at IS NULL AND g.expires_at>now()));
-- No client publication policy. On entitlement revocation, service revokes grants, disconnects authorized sessions and denies refetch. Prove active-channel invalidation on the deployed service.
