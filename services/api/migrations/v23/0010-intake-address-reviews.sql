-- Isolated v2.3 only: preserve every old draft, submitted revision and suggestion.
BEGIN;
CREATE TABLE rounds.intake_address_reviews (
  id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL,
  city_id uuid NOT NULL,
  draft_id uuid NOT NULL,
  input_version bigint NOT NULL CHECK(input_version>0),
  output_version bigint NOT NULL CHECK(output_version=input_version+1),
  input_hash text NOT NULL CHECK(input_hash ~ '^[a-f0-9]{64}$'),
  suggestion_id uuid,
  decision text NOT NULL CHECK(decision IN ('accept','edit','reject')),
  original_address jsonb NOT NULL CHECK(jsonb_typeof(original_address)='object'),
  proposed_address jsonb,
  selected_address jsonb NOT NULL CHECK(jsonb_typeof(selected_address)='object'),
  actor_id uuid NOT NULL REFERENCES rounds.principals(id),
  command_id uuid NOT NULL,
  occurred_at timestamptz NOT NULL,
  reviewed_at timestamptz NOT NULL,
  FOREIGN KEY(tenant_id,city_id) REFERENCES rounds.cities(tenant_id,id),
  FOREIGN KEY(tenant_id,draft_id,input_version) REFERENCES rounds.intake_draft_revisions(tenant_id,draft_id,version),
  FOREIGN KEY(tenant_id,draft_id,output_version) REFERENCES rounds.intake_draft_revisions(tenant_id,draft_id,version),
  FOREIGN KEY(tenant_id,suggestion_id) REFERENCES rounds.address_suggestions(tenant_id,id),
  UNIQUE(tenant_id,draft_id,output_version),
  UNIQUE(tenant_id,actor_id,command_id)
);
ALTER TABLE rounds.intake_address_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.intake_address_reviews FORCE ROW LEVEL SECURITY;
CREATE POLICY scoped_address_review_read ON rounds.intake_address_reviews FOR SELECT TO rounds_api
  USING(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city());
CREATE POLICY scoped_address_review_insert ON rounds.intake_address_reviews FOR INSERT TO rounds_api
  WITH CHECK(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city()
    AND actor_id=rounds.context_principal()
    AND EXISTS(SELECT 1 FROM rounds.intake_drafts d WHERE d.tenant_id=intake_address_reviews.tenant_id
      AND d.id=intake_address_reviews.draft_id AND d.city_id=intake_address_reviews.city_id));
GRANT SELECT,INSERT ON rounds.intake_address_reviews TO rounds_api;
CREATE TRIGGER intake_address_review_immutable BEFORE UPDATE OR DELETE ON rounds.intake_address_reviews
  FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
COMMIT;
