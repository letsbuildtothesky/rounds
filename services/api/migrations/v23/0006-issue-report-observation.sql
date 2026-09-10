-- Isolated v2.3 increment. Existing issues/evidence are not backfilled, moved
-- or assigned today's fence. The original report is separate from decisions.
BEGIN;
CREATE TABLE rounds.issue_report_observations (
  issue_id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL,
  city_id uuid NOT NULL,
  actor_id uuid NOT NULL REFERENCES rounds.principals(id),
  round_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  assignment_version bigint NOT NULL CHECK(assignment_version>0),
  observation_id uuid NOT NULL,
  delivery_id uuid,
  manifest_id uuid,
  observed_at timestamptz NOT NULL,
  expected_versions jsonb NOT NULL CHECK(jsonb_typeof(expected_versions)='array'),
  payload jsonb NOT NULL CHECK(jsonb_typeof(payload)='object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,actor_id,observation_id),
  CHECK((delivery_id IS NULL)=(manifest_id IS NULL)),
  FOREIGN KEY(tenant_id,issue_id) REFERENCES rounds.issues(tenant_id,id),
  FOREIGN KEY(tenant_id,city_id) REFERENCES rounds.cities(tenant_id,id),
  FOREIGN KEY(tenant_id,round_id) REFERENCES rounds.rounds(tenant_id,id),
  FOREIGN KEY(tenant_id,assignment_id) REFERENCES rounds.assignments(tenant_id,id),
  FOREIGN KEY(tenant_id,delivery_id) REFERENCES rounds.deliveries(tenant_id,id),
  FOREIGN KEY(tenant_id,manifest_id) REFERENCES rounds.manifests(tenant_id,id)
);
ALTER TABLE rounds.issue_report_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.issue_report_observations FORCE ROW LEVEL SECURITY;
CREATE POLICY own_issue_report ON rounds.issue_report_observations TO rounds_api
  USING(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city() AND actor_id=rounds.context_principal())
  WITH CHECK(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city() AND actor_id=rounds.context_principal());
GRANT SELECT,INSERT ON rounds.issue_report_observations TO rounds_api;
CREATE TRIGGER issue_report_immutable BEFORE UPDATE OR DELETE ON rounds.issue_report_observations
  FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
COMMIT;
