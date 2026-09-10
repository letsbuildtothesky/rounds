-- W01.2 isolated v2.3 upgrade only; never import over the legacy public schema.
-- Existing receipts stay intact. No guessed original job scope is backfilled.
BEGIN;
ALTER TABLE rounds.command_receipts ADD COLUMN IF NOT EXISTS authorization_round_id uuid;
ALTER TABLE rounds.command_receipts ADD COLUMN IF NOT EXISTS authorization_assignment_id uuid;
ALTER TABLE rounds.command_receipts ADD CONSTRAINT receipt_job_pair
  CHECK ((authorization_round_id IS NULL) = (authorization_assignment_id IS NULL));
CREATE FUNCTION rounds.guard_receipt_authorization_scope() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF ROW(NEW.actor_id,NEW.tenant_id,NEW.city_id,NEW.command_key,NEW.command_type,NEW.request_hash,NEW.scope_key,NEW.authorization_round_id,NEW.authorization_assignment_id)
    IS DISTINCT FROM ROW(OLD.actor_id,OLD.tenant_id,OLD.city_id,OLD.command_key,OLD.command_type,OLD.request_hash,OLD.scope_key,OLD.authorization_round_id,OLD.authorization_assignment_id)
 THEN RAISE EXCEPTION 'IMMUTABLE_RECORD' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER receipt_authorization_immutable BEFORE UPDATE ON rounds.command_receipts
 FOR EACH ROW EXECUTE FUNCTION rounds.guard_receipt_authorization_scope();

CREATE ROLE rounds_api_auth_resolver NOLOGIN NOSUPERUSER NOBYPASSRLS;
GRANT USAGE ON SCHEMA rounds TO rounds_api_auth_resolver;
GRANT SELECT(id,auth_subject,disabled_at,archived_at) ON rounds.principals TO rounds_api_auth_resolver;
CREATE POLICY api_auth_subject ON rounds.principals FOR SELECT TO rounds_api_auth_resolver
 USING(auth_subject=nullif(current_setting('rounds.auth_subject',true),'')::uuid);
CREATE FUNCTION rounds.api_principal_id() RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT id FROM rounds.principals
 WHERE auth_subject=nullif(current_setting('rounds.auth_subject',true),'')::uuid AND disabled_at IS NULL AND archived_at IS NULL
$$;
ALTER FUNCTION rounds.api_principal_id() OWNER TO rounds_api_auth_resolver;
REVOKE ALL ON FUNCTION rounds.api_principal_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rounds.api_principal_id() TO rounds_api;
-- No resolver role membership or direct identity-column grants to API logins.
COMMIT;
