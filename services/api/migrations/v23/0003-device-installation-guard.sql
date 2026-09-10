-- Isolated v2.3 only. Preserve legacy rows/keys; never backfill credentials.
BEGIN;
CREATE FUNCTION rounds.guard_device_installation() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF OLD.device_key LIKE 'v23-install-sha256:%' OR NEW.device_key LIKE 'v23-install-sha256:%' THEN
  IF ROW(NEW.driver_id,NEW.device_key,NEW.platform) IS DISTINCT FROM ROW(OLD.driver_id,OLD.device_key,OLD.platform)
     OR NEW.session_epoch < OLD.session_epoch
     OR (OLD.revoked_at IS NOT NULL AND NEW.revoked_at IS DISTINCT FROM OLD.revoked_at)
     OR (OLD.archived_at IS NOT NULL AND NEW.archived_at IS DISTINCT FROM OLD.archived_at)
  THEN RAISE EXCEPTION 'IMMUTABLE_RECORD' USING ERRCODE='23514'; END IF;
  IF (OLD.revoked_at IS NULL AND NEW.revoked_at IS NOT NULL) OR (OLD.archived_at IS NULL AND NEW.archived_at IS NOT NULL) THEN
   NEW.session_epoch := greatest(NEW.session_epoch, OLD.session_epoch+1);
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER device_installation_immutable BEFORE UPDATE ON rounds.driver_devices
 FOR EACH ROW EXECUTE FUNCTION rounds.guard_device_installation();
COMMIT;
