-- Isolated schema only. Nullable additions preserve every prior item; no
-- guessed location, note, verified state or commitment is backfilled.
BEGIN;
ALTER TABLE rounds.proof_items ADD COLUMN IF NOT EXISTS note text CHECK(length(note)<=2000);
ALTER TABLE rounds.proof_items ADD COLUMN IF NOT EXISTS location_observation_id uuid;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='rounds.proof_items'::regclass AND conname='proof_item_location_observation_fk') THEN
  ALTER TABLE rounds.proof_items ADD CONSTRAINT proof_item_location_observation_fk FOREIGN KEY(tenant_id,location_observation_id) REFERENCES rounds.location_observations(tenant_id,id);
 END IF;
END $$;
CREATE FUNCTION rounds.guard_proof_identity() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF TG_TABLE_NAME='proof_items' THEN
  IF ROW(NEW.tenant_id,NEW.submission_id,NEW.item_kind,NEW.asset_id,NEW.line_id,NEW.quantity,NEW.receiver_contact_id,NEW.note,NEW.location_observation_id,NEW.captured_at)
    IS DISTINCT FROM ROW(OLD.tenant_id,OLD.submission_id,OLD.item_kind,OLD.asset_id,OLD.line_id,OLD.quantity,OLD.receiver_contact_id,OLD.note,OLD.location_observation_id,OLD.captured_at)
  THEN RAISE EXCEPTION 'IMMUTABLE_RECORD' USING ERRCODE='23514'; END IF;
 ELSE
  IF ROW(NEW.tenant_id,NEW.attempt_id,NEW.handoff_id,NEW.policy_version_id,NEW.submitted_by,NEW.command_id)
    IS DISTINCT FROM ROW(OLD.tenant_id,OLD.attempt_id,OLD.handoff_id,OLD.policy_version_id,OLD.submitted_by,OLD.command_id)
  THEN RAISE EXCEPTION 'IMMUTABLE_RECORD' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER proof_item_identity BEFORE UPDATE ON rounds.proof_items FOR EACH ROW EXECUTE FUNCTION rounds.guard_proof_identity();
CREATE TRIGGER proof_submission_identity BEFORE UPDATE ON rounds.proof_submissions FOR EACH ROW EXECUTE FUNCTION rounds.guard_proof_identity();
REVOKE DELETE ON rounds.proof_items,rounds.proof_submissions FROM rounds_api;
-- No broker membership/global availability access. Allow only this actor's
-- city-scoped own-team commitment rows, and only final state/version updates.
GRANT SELECT ON rounds.driver_commitments TO rounds_api;
GRANT UPDATE(state,version,updated_at) ON rounds.driver_commitments TO rounds_api;
CREATE POLICY own_team_commitment_read ON rounds.driver_commitments FOR SELECT TO rounds_api
 USING(tenant_id=rounds.context_tenant() AND EXISTS(SELECT 1 FROM rounds.rounds r JOIN rounds.drivers d ON d.id=r.driver_id
 WHERE r.tenant_id=driver_commitments.tenant_id AND r.id=driver_commitments.round_id AND r.city_id=rounds.context_city()
 AND r.fulfillment_kind='team' AND d.principal_id=rounds.context_principal()));
CREATE POLICY own_team_commitment_finish ON rounds.driver_commitments FOR UPDATE TO rounds_api
 USING(tenant_id=rounds.context_tenant() AND state='committed' AND EXISTS(SELECT 1 FROM rounds.rounds r JOIN rounds.drivers d ON d.id=r.driver_id
 WHERE r.tenant_id=driver_commitments.tenant_id AND r.id=driver_commitments.round_id AND r.city_id=rounds.context_city()
 AND r.fulfillment_kind='team' AND r.state='completed' AND r.driver_id=driver_commitments.driver_id AND d.principal_id=rounds.context_principal()))
 WITH CHECK(state='completed' AND tenant_id=rounds.context_tenant() AND EXISTS(SELECT 1 FROM rounds.rounds r JOIN rounds.drivers d ON d.id=r.driver_id
 WHERE r.tenant_id=driver_commitments.tenant_id AND r.id=driver_commitments.round_id AND r.city_id=rounds.context_city()
 AND r.fulfillment_kind='team' AND r.state='completed' AND r.driver_id=driver_commitments.driver_id AND d.principal_id=rounds.context_principal()));
COMMIT;
