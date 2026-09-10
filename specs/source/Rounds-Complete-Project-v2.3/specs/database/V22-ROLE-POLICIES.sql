-- Apply after ROLE-POLICIES.sql.
GRANT SELECT,INSERT,UPDATE,DELETE ON rounds.fulfillment_units TO rounds_api;
CREATE POLICY tenant_scope ON rounds.fulfillment_units TO rounds_api USING(tenant_id=rounds.context_tenant()) WITH CHECK(tenant_id=rounds.context_tenant());
GRANT SELECT,INSERT,UPDATE,DELETE ON rounds.fulfillment_unit_lines TO rounds_api;
CREATE POLICY tenant_scope ON rounds.fulfillment_unit_lines TO rounds_api USING(tenant_id=rounds.context_tenant()) WITH CHECK(tenant_id=rounds.context_tenant());
GRANT SELECT,INSERT,UPDATE,DELETE ON rounds.offline_evidence_observations TO rounds_api;
CREATE POLICY tenant_scope ON rounds.offline_evidence_observations TO rounds_api USING(tenant_id=rounds.context_tenant()) WITH CHECK(tenant_id=rounds.context_tenant());
GRANT SELECT,INSERT,UPDATE,DELETE ON rounds.settlement_payments TO rounds_api;
CREATE POLICY tenant_scope ON rounds.settlement_payments TO rounds_api USING(tenant_id=rounds.context_tenant()) WITH CHECK(tenant_id=rounds.context_tenant());
GRANT SELECT,INSERT,UPDATE,DELETE ON rounds.dispute_cases TO rounds_api;
CREATE POLICY tenant_scope ON rounds.dispute_cases TO rounds_api USING(tenant_id=rounds.context_tenant()) WITH CHECK(tenant_id=rounds.context_tenant());

GRANT SELECT ON rounds.tracking_entitlements TO rounds_api;
CREATE POLICY own_collection_entitlement ON rounds.tracking_entitlements FOR SELECT TO rounds_api USING(EXISTS(SELECT 1 FROM rounds.drivers d WHERE d.id=tracking_entitlements.driver_id AND d.principal_id=rounds.context_principal()));
GRANT SELECT ON rounds.tracking_entitlements TO rounds_entitlements;
CREATE POLICY entitlement_work_read ON rounds.tracking_entitlements FOR SELECT TO rounds_entitlements USING(tenant_id=rounds.context_tenant());
GRANT SELECT ON rounds.shift_occurrences TO rounds_entitlements;
CREATE POLICY entitlement_work_read ON rounds.shift_occurrences FOR SELECT TO rounds_entitlements USING(tenant_id=rounds.context_tenant());
GRANT SELECT ON rounds.driver_relationships TO rounds_entitlements;
CREATE POLICY entitlement_work_read ON rounds.driver_relationships FOR SELECT TO rounds_entitlements USING(tenant_id=rounds.context_tenant());
GRANT SELECT ON rounds.rounds TO rounds_entitlements;
CREATE POLICY entitlement_work_read ON rounds.rounds FOR SELECT TO rounds_entitlements USING(tenant_id=rounds.context_tenant());
GRANT SELECT ON rounds.assignments TO rounds_entitlements;
CREATE POLICY entitlement_work_read ON rounds.assignments FOR SELECT TO rounds_entitlements USING(tenant_id=rounds.context_tenant());
GRANT SELECT ON rounds.transport_trips TO rounds_entitlements;
CREATE POLICY entitlement_work_read ON rounds.transport_trips FOR SELECT TO rounds_entitlements USING(tenant_id=rounds.context_tenant());
CREATE ROLE rounds_notifications NOLOGIN NOSUPERUSER NOBYPASSRLS;
GRANT USAGE ON SCHEMA rounds TO rounds_notifications;
GRANT SELECT,INSERT ON rounds.notifications TO rounds_notifications;
REVOKE INSERT,DELETE ON rounds.notifications FROM rounds_api;
REVOKE UPDATE ON rounds.notifications FROM rounds_api;
GRANT UPDATE(read_at) ON rounds.notifications TO rounds_api;
GRANT SELECT ON rounds.domain_events TO rounds_notifications;
CREATE POLICY notification_context ON rounds.domain_events FOR SELECT TO rounds_notifications USING(tenant_id=rounds.context_tenant());
GRANT SELECT ON rounds.memberships TO rounds_notifications;
CREATE POLICY notification_context ON rounds.memberships FOR SELECT TO rounds_notifications USING(tenant_id=rounds.context_tenant());
GRANT SELECT ON rounds.driver_relationships TO rounds_notifications;
CREATE POLICY notification_context ON rounds.driver_relationships FOR SELECT TO rounds_notifications USING(tenant_id=rounds.context_tenant());
GRANT SELECT ON rounds.assignments TO rounds_notifications;
CREATE POLICY notification_context ON rounds.assignments FOR SELECT TO rounds_notifications USING(tenant_id=rounds.context_tenant());
GRANT SELECT ON rounds.rounds TO rounds_notifications;
CREATE POLICY notification_context ON rounds.rounds FOR SELECT TO rounds_notifications USING(tenant_id=rounds.context_tenant());
GRANT SELECT(id,principal_id) ON rounds.drivers TO rounds_notifications;
CREATE POLICY notification_driver_identity ON rounds.drivers FOR SELECT TO rounds_notifications USING(EXISTS(SELECT 1 FROM rounds.driver_relationships r WHERE r.tenant_id=rounds.context_tenant() AND r.driver_id=drivers.id AND r.status='active') OR EXISTS(SELECT 1 FROM rounds.assignments a WHERE a.tenant_id=rounds.context_tenant() AND a.driver_id=drivers.id AND a.state IN ('issued','received','acknowledged')));
CREATE POLICY notification_producer ON rounds.notifications TO rounds_notifications USING(tenant_id=rounds.context_tenant()) WITH CHECK(
 tenant_id=rounds.context_tenant() AND EXISTS(SELECT 1 FROM rounds.domain_events e WHERE e.tenant_id=notifications.tenant_id AND e.id=notifications.event_id)
 AND (EXISTS(SELECT 1 FROM rounds.memberships m WHERE m.tenant_id=notifications.tenant_id AND m.principal_id=notifications.principal_id AND m.status='active') OR EXISTS(SELECT 1 FROM rounds.drivers d WHERE d.principal_id=notifications.principal_id))
);
REVOKE SELECT,UPDATE ON rounds.principals FROM rounds_api;
GRANT SELECT(id,display_name,preferred_locale) ON rounds.principals TO rounds_api;
GRANT UPDATE(display_name,preferred_locale) ON rounds.principals TO rounds_api;

-- Dispatcher may read only collection windows already authorized by a valid tenant grant, never unrelated discovery entitlements.
CREATE POLICY granted_collection_context ON rounds.tracking_entitlements FOR SELECT TO rounds_api USING(
 tenant_id=rounds.context_tenant() AND revoked_at IS NULL AND EXISTS(SELECT 1 FROM rounds.driver_tracking_grants g WHERE g.tenant_id=tracking_entitlements.tenant_id AND g.driver_id=tracking_entitlements.driver_id AND g.tracking_entitlement_id=tracking_entitlements.id AND g.revoked_at IS NULL AND now()>=g.starts_at AND now()<g.ends_at)
);
CREATE ROLE rounds_retention NOLOGIN NOSUPERUSER NOBYPASSRLS;
CREATE ROLE rounds_retention_runner NOLOGIN NOSUPERUSER NOBYPASSRLS;
CREATE ROLE rounds_privacy_admin NOLOGIN NOSUPERUSER NOBYPASSRLS;
GRANT USAGE ON SCHEMA rounds TO rounds_retention,rounds_retention_runner,rounds_privacy_admin;
GRANT SELECT,DELETE ON rounds.location_samples TO rounds_retention;
CREATE POLICY gps_retention_scan ON rounds.location_samples TO rounds_retention USING(expires_at<=now());
GRANT SELECT ON rounds.gps_retention_holds TO rounds_retention;
CREATE POLICY retention_holds_read ON rounds.gps_retention_holds FOR SELECT TO rounds_retention USING(true);
GRANT SELECT,INSERT,UPDATE ON rounds.gps_retention_holds TO rounds_privacy_admin;
CREATE POLICY privacy_hold_admin ON rounds.gps_retention_holds TO rounds_privacy_admin USING(true) WITH CHECK(authorized_by=rounds.context_principal());
GRANT INSERT,SELECT ON rounds.gps_purge_audit TO rounds_retention;
CREATE POLICY retention_audit ON rounds.gps_purge_audit TO rounds_retention USING(true) WITH CHECK(true);
CREATE OR REPLACE FUNCTION rounds.guard_raw_gps_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' AND current_user='rounds_retention' AND OLD.expires_at<=now() AND NOT EXISTS(SELECT 1 FROM rounds.gps_retention_holds h WHERE h.driver_id=OLD.driver_id AND h.released_at IS NULL AND OLD.observed_at>=h.starts_at AND OLD.observed_at<h.ends_at) THEN RETURN OLD; END IF;
 RAISE EXCEPTION 'IMMUTABLE_RECORD' USING ERRCODE='23514';
END $$;
DROP TRIGGER immutable_location_samples ON rounds.location_samples;
CREATE TRIGGER immutable_location_samples BEFORE UPDATE OR DELETE ON rounds.location_samples FOR EACH ROW EXECUTE FUNCTION rounds.guard_raw_gps_mutation();
CREATE OR REPLACE FUNCTION rounds.purge_expired_gps(p_run_id uuid,p_limit integer DEFAULT 1000) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE deleted integer;
BEGIN
 IF p_limit<1 OR p_limit>10000 THEN RAISE EXCEPTION 'VALIDATION_FAILED' USING ERRCODE='23514'; END IF;
 -- Serialize hold insertion/release against purge selection; normal GPS ingestion does not take this lock.
 LOCK TABLE rounds.gps_retention_holds IN SHARE MODE;
 SELECT deleted_count INTO deleted FROM rounds.gps_purge_audit WHERE run_id=p_run_id;
 IF FOUND THEN RETURN deleted; END IF;
 WITH candidates AS (SELECT s.id FROM rounds.location_samples s WHERE s.expires_at<=now() AND NOT EXISTS(SELECT 1 FROM rounds.gps_retention_holds h WHERE h.driver_id=s.driver_id AND h.released_at IS NULL AND s.observed_at>=h.starts_at AND s.observed_at<h.ends_at) ORDER BY s.expires_at,s.id LIMIT p_limit FOR UPDATE SKIP LOCKED), removed AS (DELETE FROM rounds.location_samples s USING candidates c WHERE s.id=c.id RETURNING s.id) SELECT count(*) INTO deleted FROM removed;
 INSERT INTO rounds.gps_purge_audit(run_id,deleted_count) VALUES(p_run_id,deleted);
 RETURN deleted;
END $$;
ALTER FUNCTION rounds.purge_expired_gps(uuid,integer) OWNER TO rounds_retention;
REVOKE ALL ON FUNCTION rounds.purge_expired_gps(uuid,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rounds.purge_expired_gps(uuid,integer) TO rounds_retention_runner;
-- No application/driver role is a member of retention, retention_runner or privacy_admin.

GRANT UPDATE(id) ON rounds.location_samples TO rounds_retention;
