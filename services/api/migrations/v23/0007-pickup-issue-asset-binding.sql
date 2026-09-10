-- Isolated v2.3, ADR-M04. Preserve old assets and bindings without guessing
-- a pickup purpose. The future immutable report observation is known offline.
BEGIN;
CREATE TABLE rounds.pickup_issue_asset_bindings (
  asset_id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL,
  city_id uuid NOT NULL,
  actor_id uuid NOT NULL REFERENCES rounds.principals(id),
  delivery_id uuid NOT NULL,
  round_id uuid NOT NULL,
  pickup_stop_id uuid NOT NULL,
  fulfillment_unit_id uuid NOT NULL,
  manifest_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  assignment_version bigint NOT NULL CHECK(assignment_version>0),
  observation_id uuid NOT NULL,
  observed_at timestamptz NOT NULL,
  upload_key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(tenant_id,asset_id) REFERENCES rounds.assets(tenant_id,id),
  FOREIGN KEY(tenant_id,city_id) REFERENCES rounds.cities(tenant_id,id),
  FOREIGN KEY(tenant_id,delivery_id) REFERENCES rounds.deliveries(tenant_id,id),
  FOREIGN KEY(tenant_id,round_id) REFERENCES rounds.rounds(tenant_id,id),
  FOREIGN KEY(tenant_id,pickup_stop_id) REFERENCES rounds.stops(tenant_id,id),
  FOREIGN KEY(tenant_id,fulfillment_unit_id) REFERENCES rounds.fulfillment_units(tenant_id,id),
  FOREIGN KEY(tenant_id,manifest_id) REFERENCES rounds.manifests(tenant_id,id),
  FOREIGN KEY(tenant_id,assignment_id) REFERENCES rounds.assignments(tenant_id,id)
);
ALTER TABLE rounds.pickup_issue_asset_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.pickup_issue_asset_bindings FORCE ROW LEVEL SECURITY;
CREATE POLICY own_pickup_issue_asset ON rounds.pickup_issue_asset_bindings TO rounds_api
  USING(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city() AND actor_id=rounds.context_principal())
  WITH CHECK(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city() AND actor_id=rounds.context_principal());
GRANT SELECT,INSERT ON rounds.pickup_issue_asset_bindings TO rounds_api;
CREATE TRIGGER pickup_issue_asset_immutable BEFORE UPDATE OR DELETE ON rounds.pickup_issue_asset_bindings
  FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
COMMIT;
