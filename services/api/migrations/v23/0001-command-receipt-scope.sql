-- Forward policy correction for an ALREADY PROVISIONED isolated v2.3 rounds schema.
-- Not a bootstrap for legacy public tables. Apply only with migration credentials.
-- Empty local schemas only: do not guess a city for existing command receipts.
-- Populated schemas require an explicit original-scope migration/recovery plan.
BEGIN;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM rounds.command_receipts) THEN
    RAISE EXCEPTION 'Receipt scope migration requires empty isolated schema or separately reviewed backfill';
  END IF;
END $$;
ALTER TABLE rounds.command_receipts ADD COLUMN IF NOT EXISTS city_id uuid;
CREATE OR REPLACE FUNCTION rounds.context_city() RETURNS uuid LANGUAGE sql STABLE
  AS $$ SELECT nullif(current_setting('rounds.city_id',true),'')::uuid $$;
DROP POLICY account_scope ON rounds.command_receipts;
CREATE POLICY account_scope ON rounds.command_receipts TO rounds_api
  USING (actor_id=rounds.context_principal() AND tenant_id IS NOT DISTINCT FROM rounds.context_tenant() AND city_id IS NOT DISTINCT FROM rounds.context_city())
  WITH CHECK (actor_id=rounds.context_principal() AND tenant_id IS NOT DISTINCT FROM rounds.context_tenant() AND city_id IS NOT DISTINCT FROM rounds.context_city());
-- Full fresh schema installs the same-tenant city FK in ROUNDS-REVIEW-SCHEMA.sql.
-- This narrow upgrade intentionally does not bootstrap the other product tables.
COMMIT;
