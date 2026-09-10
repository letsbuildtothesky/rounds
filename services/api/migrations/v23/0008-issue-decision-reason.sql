-- ADR-T08, isolated v2.3 schema only. Preserve every existing immutable decision.
-- Old unknown reasons remain NULL; never backfill or rewrite decision history.
BEGIN;
ALTER TABLE rounds.issue_decisions ADD COLUMN IF NOT EXISTS reason text;
COMMENT ON COLUMN rounds.issue_decisions.reason IS 'Original Operations decision reason; NULL means legacy/unrecorded. Not exposed in Driver instructions.';

-- Operations needs the original report fence, but must never insert or alter
-- another actor's observation. The original actor-only write policy is retained.
DROP POLICY IF EXISTS operations_issue_report_read ON rounds.issue_report_observations;
CREATE POLICY operations_issue_report_read ON rounds.issue_report_observations
FOR SELECT TO rounds_api
USING (
  tenant_id=rounds.context_tenant() AND city_id=rounds.context_city()
  AND EXISTS (
    SELECT 1 FROM rounds.memberships m
    JOIN rounds.city_grants g ON g.tenant_id=m.tenant_id AND g.membership_id=m.id
    JOIN rounds.cities c ON c.tenant_id=g.tenant_id AND c.id=g.city_id
    JOIN rounds.tenants t ON t.id=m.tenant_id
    WHERE m.tenant_id=issue_report_observations.tenant_id
      AND m.principal_id=rounds.context_principal()
      AND m.status='active' AND m.archived_at IS NULL
      AND g.city_id=issue_report_observations.city_id AND g.archived_at IS NULL
      AND 'issues.decide'=ANY(g.capabilities)
      AND c.enabled AND c.archived_at IS NULL
      AND t.status='active' AND t.archived_at IS NULL
  )
);
COMMIT;
