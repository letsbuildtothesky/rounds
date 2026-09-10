-- Isolated v2.3 only. No import/backfill of old drafts, source rows or clients.
BEGIN;
CREATE TABLE rounds.intake_draft_revisions (
  tenant_id uuid NOT NULL,
  city_id uuid NOT NULL,
  draft_id uuid NOT NULL,
  version bigint NOT NULL CHECK(version>0),
  schema_version integer NOT NULL CHECK(schema_version=1),
  actor_id uuid NOT NULL REFERENCES rounds.principals(id),
  command_id uuid NOT NULL,
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  payload jsonb NOT NULL CHECK(jsonb_typeof(payload)='object'),
  input_hash text NOT NULL CHECK(input_hash ~ '^[a-f0-9]{64}$'),
  field_provenance jsonb NOT NULL CHECK(jsonb_typeof(field_provenance)='object'),
  PRIMARY KEY(tenant_id,draft_id,version),
  FOREIGN KEY(tenant_id,draft_id) REFERENCES rounds.intake_drafts(tenant_id,id),
  FOREIGN KEY(tenant_id,city_id) REFERENCES rounds.cities(tenant_id,id),
  UNIQUE(tenant_id,actor_id,command_id)
);
ALTER TABLE rounds.intake_draft_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.intake_draft_revisions FORCE ROW LEVEL SECURITY;
CREATE POLICY scoped_revision_read ON rounds.intake_draft_revisions FOR SELECT TO rounds_api
  USING(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city());
CREATE POLICY scoped_revision_insert ON rounds.intake_draft_revisions FOR INSERT TO rounds_api
  WITH CHECK(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city() AND actor_id=rounds.context_principal());
GRANT SELECT,INSERT ON rounds.intake_draft_revisions TO rounds_api;
CREATE TRIGGER intake_revision_immutable BEFORE UPDATE OR DELETE ON rounds.intake_draft_revisions
  FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
-- Old rows remain byte-for-byte intact, including drafts whose city is unknown.
-- Those rows must be mapped explicitly; no actor gets a guessed current city.
DROP POLICY tenant_scope ON rounds.intake_drafts;
CREATE POLICY city_scope ON rounds.intake_drafts TO rounds_api
  USING(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city())
  WITH CHECK(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city());
REVOKE DELETE ON rounds.intake_drafts FROM rounds_api;
COMMIT;
