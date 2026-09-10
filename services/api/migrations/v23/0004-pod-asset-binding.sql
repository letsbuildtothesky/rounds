-- Isolated v2.3 only. Existing assets/legacy photos are preserved, not assigned
-- guessed ownership. Missing bindings fail closed in the new POD path.
BEGIN;
CREATE TABLE rounds.pod_asset_bindings (
  asset_id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL,
  city_id uuid NOT NULL,
  actor_id uuid NOT NULL REFERENCES rounds.principals(id),
  handoff_id uuid NOT NULL,
  attempt_id uuid NOT NULL,
  round_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  assignment_version bigint NOT NULL CHECK(assignment_version>0),
  upload_key text NOT NULL UNIQUE,
  policy_version_id uuid NOT NULL,
  receiver_contact_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(tenant_id,asset_id) REFERENCES rounds.assets(tenant_id,id),
  FOREIGN KEY(tenant_id,city_id) REFERENCES rounds.cities(tenant_id,id),
  FOREIGN KEY(tenant_id,handoff_id) REFERENCES rounds.handoffs(tenant_id,id),
  FOREIGN KEY(tenant_id,attempt_id) REFERENCES rounds.delivery_attempts(tenant_id,id),
  FOREIGN KEY(tenant_id,round_id) REFERENCES rounds.rounds(tenant_id,id),
  FOREIGN KEY(tenant_id,assignment_id) REFERENCES rounds.assignments(tenant_id,id),
  FOREIGN KEY(tenant_id,policy_version_id) REFERENCES rounds.policy_versions(tenant_id,id),
  FOREIGN KEY(tenant_id,receiver_contact_id) REFERENCES rounds.delivery_contacts(tenant_id,id)
);
ALTER TABLE rounds.pod_asset_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.pod_asset_bindings FORCE ROW LEVEL SECURITY;
CREATE POLICY pod_asset_owner ON rounds.pod_asset_bindings TO rounds_api
  USING(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city() AND actor_id=rounds.context_principal())
  WITH CHECK(tenant_id=rounds.context_tenant() AND city_id=rounds.context_city() AND actor_id=rounds.context_principal());
GRANT SELECT,INSERT ON rounds.pod_asset_bindings TO rounds_api;
-- Immutable purpose/owner; verification may only change storage key/state.
CREATE FUNCTION rounds.guard_pod_asset_metadata() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF (ROW(NEW.id,NEW.tenant_id,NEW.kind,NEW.mime_type,NEW.byte_size,NEW.sha256,NEW.created_by,NEW.retention_class)
      IS DISTINCT FROM ROW(OLD.id,OLD.tenant_id,OLD.kind,OLD.mime_type,OLD.byte_size,OLD.sha256,OLD.created_by,OLD.retention_class)
    OR (OLD.state='verified' AND ROW(NEW.object_key,NEW.state,NEW.verified_at) IS DISTINCT FROM ROW(OLD.object_key,OLD.state,OLD.verified_at)))
 THEN RAISE EXCEPTION 'IMMUTABLE_RECORD' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER pod_asset_metadata_immutable BEFORE UPDATE ON rounds.assets
 FOR EACH ROW EXECUTE FUNCTION rounds.guard_pod_asset_metadata();
COMMIT;
