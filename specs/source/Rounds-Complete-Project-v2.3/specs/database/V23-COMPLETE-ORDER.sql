
-- V2.3-r1 launch constraints. Fresh reference only, after V22-INVARIANTS.sql.
-- 2026-09-08: real PostGIS regression tests exposed unchecked missing allocations
-- and manifest-only quantity changes. Validate the final current manifest from
-- every contributing table, not only from changed allocation rows.
ALTER TABLE rounds.fulfillment_units ADD CONSTRAINT one_whole_unit_per_delivery UNIQUE(tenant_id,delivery_id);
ALTER TABLE rounds.fulfillment_units ADD CONSTRAINT no_split_fulfillment_launch CHECK(parent_unit_id IS NULL AND remaining_obligation_id IS NULL);

CREATE OR REPLACE FUNCTION rounds.check_complete_delivery(p_tenant uuid,p_delivery uuid)
RETURNS void LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE manifest uuid; selected_unit uuid;
BEGIN
 SELECT current_manifest_id INTO manifest FROM rounds.deliveries
 WHERE tenant_id=p_tenant AND id=p_delivery FOR UPDATE;
 -- Nullable during draft construction; a committed manifest must be complete.
 IF NOT FOUND OR manifest IS NULL THEN RETURN; END IF;
 SELECT id INTO selected_unit FROM rounds.fulfillment_units
 WHERE tenant_id=p_tenant AND delivery_id=p_delivery AND manifest_id=manifest FOR UPDATE;
 IF selected_unit IS NULL
 OR NOT EXISTS(SELECT 1 FROM rounds.manifests WHERE tenant_id=p_tenant AND id=manifest AND delivery_id=p_delivery)
 OR NOT EXISTS(SELECT 1 FROM rounds.manifest_lines WHERE tenant_id=p_tenant AND manifest_id=manifest)
 OR EXISTS(
   SELECT 1 FROM rounds.manifest_lines l
   LEFT JOIN rounds.fulfillment_unit_lines u ON u.tenant_id=l.tenant_id AND u.line_id=l.id AND u.unit_id=selected_unit
   WHERE l.tenant_id=p_tenant AND l.manifest_id=manifest
   AND (u.id IS NULL OR u.allocated_quantity<>l.quantity)
 ) THEN RAISE EXCEPTION 'COMPLETE_ORDER_REQUIRED' USING ERRCODE='23514'; END IF;
END $$;

CREATE OR REPLACE FUNCTION rounds.guard_complete_delivery() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE row_value jsonb; delivery uuid; scope_id uuid;
BEGIN
 -- Check old and new owners if a reference changes; a missing deleted parent
 -- is handled by its own trigger/FK. These checks are initially deferred so a
 -- legitimate manifest+allocation revision can be written in one transaction.
 FOR row_value IN SELECT v FROM (VALUES (to_jsonb(OLD)),(to_jsonb(NEW))) AS rows(v) WHERE v IS NOT NULL LOOP
   scope_id:=(row_value->>'tenant_id')::uuid;
   IF TG_TABLE_NAME='deliveries' THEN delivery:=(row_value->>'id')::uuid;
   ELSIF TG_TABLE_NAME IN ('fulfillment_units','manifests') THEN delivery:=(row_value->>'delivery_id')::uuid;
   ELSIF TG_TABLE_NAME='manifest_lines' THEN
     SELECT delivery_id INTO delivery FROM rounds.manifests WHERE tenant_id=scope_id AND id=(row_value->>'manifest_id')::uuid;
   ELSE
     SELECT delivery_id INTO delivery FROM rounds.fulfillment_units WHERE tenant_id=scope_id AND id=(row_value->>'unit_id')::uuid;
   END IF;
   IF delivery IS NOT NULL THEN PERFORM rounds.check_complete_delivery(scope_id,delivery); END IF;
 END LOOP;
 RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER complete_delivery AFTER INSERT OR UPDATE OR DELETE ON rounds.deliveries DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION rounds.guard_complete_delivery();
CREATE CONSTRAINT TRIGGER complete_delivery AFTER INSERT OR UPDATE OR DELETE ON rounds.fulfillment_units DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION rounds.guard_complete_delivery();
CREATE CONSTRAINT TRIGGER complete_delivery AFTER INSERT OR UPDATE OR DELETE ON rounds.manifests DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION rounds.guard_complete_delivery();
CREATE CONSTRAINT TRIGGER complete_delivery AFTER INSERT OR UPDATE OR DELETE ON rounds.manifest_lines DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION rounds.guard_complete_delivery();
CREATE CONSTRAINT TRIGGER complete_delivery AFTER INSERT OR UPDATE OR DELETE ON rounds.fulfillment_unit_lines DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION rounds.guard_complete_delivery();
