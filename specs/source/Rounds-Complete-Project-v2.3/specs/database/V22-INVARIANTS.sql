-- Fresh V2.2 reference extension: apply after base DDL, before ROLE-POLICIES.sql. Not a live-data migration.
ALTER TABLE rounds.policy_versions ADD CONSTRAINT policy_kind_closed CHECK(policy_kind IN ('own_fleet','broadcast','proof','customer','timing','commercial','retention','map','locale','slot','intake','intercity','messaging','escalation','account','weather')) ;
CREATE TABLE rounds.fulfillment_units (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
 delivery_id uuid NOT NULL,
 manifest_id uuid NOT NULL,
 parent_unit_id uuid,
 remaining_obligation_id uuid,
 state text NOT NULL CHECK(state IN ('open','collected','delivered','returned','cancelled')),
 collected_at timestamptz,
 completed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 version bigint NOT NULL DEFAULT 1 CHECK(version>0),
 archived_at timestamptz,
 UNIQUE(tenant_id,id),
 FOREIGN KEY (tenant_id,delivery_id) REFERENCES rounds.deliveries(tenant_id,id),
 FOREIGN KEY (tenant_id,manifest_id) REFERENCES rounds.manifests(tenant_id,id),
 FOREIGN KEY (tenant_id,remaining_obligation_id) REFERENCES rounds.remaining_obligations(tenant_id,id)
);
ALTER TABLE rounds.fulfillment_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.fulfillment_units FORCE ROW LEVEL SECURITY;
ALTER TABLE rounds.fulfillment_units ADD FOREIGN KEY(tenant_id,parent_unit_id) REFERENCES rounds.fulfillment_units(tenant_id,id);
CREATE TABLE rounds.fulfillment_unit_lines (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
 unit_id uuid NOT NULL,
 line_id uuid NOT NULL,
 allocated_quantity numeric(18,4) NOT NULL CHECK(allocated_quantity>0),
 delivered_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(delivered_quantity>=0),
 returned_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(returned_quantity>=0),
 cancelled_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(cancelled_quantity>=0),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 version bigint NOT NULL DEFAULT 1 CHECK(version>0),
 archived_at timestamptz,
 UNIQUE(tenant_id,id),
 UNIQUE(tenant_id,unit_id,line_id),
 CHECK(delivered_quantity+returned_quantity+cancelled_quantity<=allocated_quantity),
 FOREIGN KEY (tenant_id,unit_id) REFERENCES rounds.fulfillment_units(tenant_id,id),
 FOREIGN KEY (tenant_id,line_id) REFERENCES rounds.manifest_lines(tenant_id,id)
);
ALTER TABLE rounds.fulfillment_unit_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.fulfillment_unit_lines FORCE ROW LEVEL SECURITY;
ALTER TABLE rounds.active_delivery_claims ADD COLUMN fulfillment_unit_id uuid NOT NULL;
ALTER TABLE rounds.active_delivery_claims ADD FOREIGN KEY (tenant_id,fulfillment_unit_id) REFERENCES rounds.fulfillment_units(tenant_id,id);
ALTER TABLE rounds.stops ADD COLUMN fulfillment_unit_id uuid;
ALTER TABLE rounds.stops ADD FOREIGN KEY (tenant_id,fulfillment_unit_id) REFERENCES rounds.fulfillment_units(tenant_id,id);
ALTER TABLE rounds.delivery_attempts ADD COLUMN fulfillment_unit_id uuid NOT NULL;
ALTER TABLE rounds.delivery_attempts ADD FOREIGN KEY (tenant_id,fulfillment_unit_id) REFERENCES rounds.fulfillment_units(tenant_id,id);
ALTER TABLE rounds.stops ADD CONSTRAINT dropoff_unit_required CHECK(kind<>'dropoff' OR fulfillment_unit_id IS NOT NULL);
DO $$ DECLARE c record; BEGIN FOR c IN SELECT conname FROM pg_constraint WHERE conrelid='rounds.active_delivery_claims'::regclass AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (tenant_id, delivery_id)' LOOP EXECUTE format('ALTER TABLE rounds.active_delivery_claims DROP CONSTRAINT %I',c.conname); END LOOP; END $$;
DROP INDEX rounds.one_active_dropoff;
CREATE UNIQUE INDEX one_active_dropoff ON rounds.stops(tenant_id,fulfillment_unit_id) WHERE kind='dropoff' AND state NOT IN ('completed','failed','cancelled');
CREATE UNIQUE INDEX one_unit_claim ON rounds.active_delivery_claims(tenant_id,fulfillment_unit_id);
CREATE TABLE rounds.offline_evidence_observations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
 principal_id uuid NOT NULL,
 device_id uuid NOT NULL,
 observation_id uuid NOT NULL,
 assignment_id uuid NOT NULL,
 assignment_version bigint NOT NULL,
 kind text NOT NULL,
 observed_at timestamptz NOT NULL,
 observation jsonb NOT NULL,
 asset_ids uuid[] NOT NULL,
 incident_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,id),
 UNIQUE(tenant_id,device_id,observation_id),
 FOREIGN KEY (principal_id) REFERENCES rounds.principals(id),
 FOREIGN KEY (device_id) REFERENCES rounds.driver_devices(id),
 FOREIGN KEY (tenant_id,assignment_id) REFERENCES rounds.assignments(tenant_id,id)
);
ALTER TABLE rounds.offline_evidence_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.offline_evidence_observations FORCE ROW LEVEL SECURITY;
CREATE TRIGGER immutable_offline_evidence_observations BEFORE UPDATE OR DELETE ON rounds.offline_evidence_observations FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
ALTER TABLE rounds.plan_proposals ADD COLUMN version bigint NOT NULL DEFAULT 1 CHECK(version=1);
ALTER TABLE rounds.settlement_records ADD COLUMN earning_state text NOT NULL DEFAULT 'unearned' CHECK(earning_state IN ('unearned','earned','void'));
ALTER TABLE rounds.settlement_records ADD COLUMN payment_state text NOT NULL DEFAULT 'unpaid' CHECK(payment_state IN ('unpaid','partially_paid','paid','overpaid'));
ALTER TABLE rounds.settlement_records ADD COLUMN earned_minor bigint NOT NULL DEFAULT 0 CHECK(earned_minor>=0);
ALTER TABLE rounds.settlement_records ADD COLUMN paid_minor bigint NOT NULL DEFAULT 0 CHECK(paid_minor>=0);
ALTER TABLE rounds.settlement_records ADD COLUMN adjustment_minor bigint NOT NULL DEFAULT 0;
CREATE TABLE rounds.settlement_payments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
 settlement_id uuid NOT NULL,
 amount_minor bigint NOT NULL CHECK(amount_minor>0),
 direction text NOT NULL CHECK(direction IN ('payment','refund')),
 currency char(3) NOT NULL,
 external_reference text NOT NULL,
 occurred_at timestamptz NOT NULL,
 recorded_by uuid NOT NULL,
 command_id uuid NOT NULL,
 proof_asset_id uuid,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,id),
 UNIQUE(tenant_id,command_id),
 UNIQUE(tenant_id,settlement_id,direction,external_reference),
 FOREIGN KEY (tenant_id,settlement_id) REFERENCES rounds.settlement_records(tenant_id,id),
 FOREIGN KEY (recorded_by) REFERENCES rounds.principals(id),
 FOREIGN KEY (tenant_id,proof_asset_id) REFERENCES rounds.assets(tenant_id,id)
);
ALTER TABLE rounds.settlement_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.settlement_payments FORCE ROW LEVEL SECURITY;
CREATE TRIGGER immutable_settlement_payments BEFORE UPDATE OR DELETE ON rounds.settlement_payments FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TABLE rounds.dispute_cases (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
 kind text NOT NULL CHECK(kind IN ('financial','evidence')),
 agreement_id uuid,
 proof_submission_id uuid,
 state text NOT NULL CHECK(state IN ('open','investigating','decided','closed')),
 opened_by uuid NOT NULL,
 reason_code text NOT NULL,
 decision text,
 decided_by uuid,
 decided_at timestamptz,
 prior_proof_state text,
 replacement_proof_submission_id uuid,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 version bigint NOT NULL DEFAULT 1 CHECK(version>0),
 archived_at timestamptz,
 UNIQUE(tenant_id,id),
 CHECK((kind='financial' AND agreement_id IS NOT NULL AND proof_submission_id IS NULL) OR (kind='evidence' AND proof_submission_id IS NOT NULL AND agreement_id IS NULL)),
 FOREIGN KEY (tenant_id,agreement_id) REFERENCES rounds.freelance_agreements(tenant_id,id),
 FOREIGN KEY (tenant_id,proof_submission_id) REFERENCES rounds.proof_submissions(tenant_id,id),
 FOREIGN KEY (opened_by) REFERENCES rounds.principals(id),
 FOREIGN KEY (decided_by) REFERENCES rounds.principals(id),
 FOREIGN KEY (tenant_id,replacement_proof_submission_id) REFERENCES rounds.proof_submissions(tenant_id,id)
);
ALTER TABLE rounds.dispute_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.dispute_cases FORCE ROW LEVEL SECURITY;

ALTER TABLE rounds.tracking_entitlements ADD UNIQUE(tenant_id,driver_id,id);
ALTER TABLE rounds.driver_tracking_grants ADD CONSTRAINT grant_entitlement_identity FOREIGN KEY(tenant_id,driver_id,tracking_entitlement_id) REFERENCES rounds.tracking_entitlements(tenant_id,driver_id,id);
CREATE OR REPLACE FUNCTION rounds.validate_tracking_grant() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE e rounds.tracking_entitlements%ROWTYPE; valid_work boolean:=false;
BEGIN
 IF TG_OP='UPDATE' AND NEW.revoked_at IS NOT NULL THEN RETURN NEW; END IF;
 SELECT * INTO e FROM rounds.tracking_entitlements WHERE id=NEW.tracking_entitlement_id AND tenant_id=NEW.tenant_id AND driver_id=NEW.driver_id;
 IF NOT FOUND OR e.revoked_at IS NOT NULL OR NEW.starts_at<e.starts_at OR (e.ends_at IS NOT NULL AND NEW.ends_at>e.ends_at) THEN RAISE EXCEPTION 'TRACKING_GRANT_INVALID' USING ERRCODE='23514'; END IF;
 IF NEW.purpose='team_shift' THEN
 SELECT EXISTS(SELECT 1 FROM rounds.shift_occurrences s JOIN rounds.driver_relationships r ON r.tenant_id=s.tenant_id AND r.id=s.relationship_id WHERE s.tenant_id=NEW.tenant_id AND s.id=NEW.shift_id AND r.driver_id=NEW.driver_id AND r.status='active' AND s.state IN ('started','on_break') AND NEW.starts_at>=s.starts_at AND NEW.ends_at<=s.ends_at) INTO valid_work;
 ELSIF NEW.purpose='accepted_round' THEN
 SELECT EXISTS(SELECT 1 FROM rounds.rounds r JOIN rounds.assignments a ON a.tenant_id=r.tenant_id AND a.round_id=r.id WHERE r.tenant_id=NEW.tenant_id AND r.id=NEW.round_id AND r.id=e.round_id AND a.driver_id=NEW.driver_id AND a.state IN ('issued','received','acknowledged') AND r.state IN ('staged','released','active')) INTO valid_work;
 ELSIF NEW.purpose='accepted_trip' THEN
 SELECT EXISTS(SELECT 1 FROM rounds.transport_trips t WHERE t.tenant_id=NEW.tenant_id AND t.id=NEW.trip_id AND t.id=e.trip_id AND t.driver_id=NEW.driver_id AND t.state IN ('scheduled','loading','departed','arrived','receiving')) INTO valid_work;
 END IF;
 IF NOT valid_work THEN RAISE EXCEPTION 'TRACKING_GRANT_INVALID' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER tracking_grant_work BEFORE INSERT OR UPDATE ON rounds.driver_tracking_grants FOR EACH ROW EXECUTE FUNCTION rounds.validate_tracking_grant();
ALTER TABLE rounds.driver_tracking_grants ADD CONSTRAINT no_unscoped_recovery_grant CHECK(purpose<>'recovery');
ALTER TABLE rounds.notifications ADD CONSTRAINT notification_source_event FOREIGN KEY(tenant_id,event_id) REFERENCES rounds.domain_events(tenant_id,id);
CREATE UNIQUE INDEX notification_logical_delivery ON rounds.notifications(tenant_id,event_id,principal_id,kind);
CREATE OR REPLACE FUNCTION rounds.check_header_manifest() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN IF NOT EXISTS(SELECT 1 FROM rounds.manifests m WHERE m.tenant_id=NEW.tenant_id AND m.id=NEW.manifest_id AND m.delivery_id=NEW.delivery_id) THEN RAISE EXCEPTION 'MANIFEST_MISMATCH' USING ERRCODE='23514'; END IF; RETURN NEW; END $$;
CREATE TRIGGER header_manifest_identity BEFORE INSERT OR UPDATE ON rounds.return_tasks FOR EACH ROW EXECUTE FUNCTION rounds.check_header_manifest();
CREATE TRIGGER header_manifest_identity BEFORE INSERT OR UPDATE ON rounds.trip_bookings FOR EACH ROW EXECUTE FUNCTION rounds.check_header_manifest();
CREATE TRIGGER header_manifest_identity BEFORE INSERT OR UPDATE ON rounds.remaining_obligations FOR EACH ROW EXECUTE FUNCTION rounds.check_header_manifest();
CREATE TRIGGER header_manifest_identity BEFORE INSERT OR UPDATE ON rounds.fulfillment_units FOR EACH ROW EXECUTE FUNCTION rounds.check_header_manifest();
CREATE OR REPLACE FUNCTION rounds.check_physical_line_manifest() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE header_manifest uuid; parent_id uuid;
BEGIN parent_id:=(to_jsonb(NEW)->>TG_ARGV[1])::uuid;
 EXECUTE format('SELECT manifest_id FROM rounds.%I WHERE tenant_id=$1 AND id=$2',TG_ARGV[0]) INTO header_manifest USING NEW.tenant_id,parent_id;
 IF header_manifest IS NULL OR NOT EXISTS(SELECT 1 FROM rounds.manifest_lines l WHERE l.tenant_id=NEW.tenant_id AND l.id=NEW.line_id AND l.manifest_id=header_manifest) THEN RAISE EXCEPTION 'MANIFEST_MISMATCH' USING ERRCODE='23514'; END IF;
 RETURN NEW; END $$;
CREATE TRIGGER physical_line_membership BEFORE INSERT OR UPDATE ON rounds.return_task_lines FOR EACH ROW EXECUTE FUNCTION rounds.check_physical_line_manifest('return_tasks','return_task_id');
CREATE TRIGGER physical_line_membership BEFORE INSERT OR UPDATE ON rounds.custody_transfer_lines FOR EACH ROW EXECUTE FUNCTION rounds.check_physical_line_manifest('custody_transfers','transfer_id');
CREATE TRIGGER physical_line_membership BEFORE INSERT OR UPDATE ON rounds.remaining_obligation_lines FOR EACH ROW EXECUTE FUNCTION rounds.check_physical_line_manifest('remaining_obligations','obligation_id');
CREATE TRIGGER physical_line_membership BEFORE INSERT OR UPDATE ON rounds.fulfillment_unit_lines FOR EACH ROW EXECUTE FUNCTION rounds.check_physical_line_manifest('fulfillment_units','unit_id');
ALTER TABLE rounds.fulfillment_units ADD UNIQUE(tenant_id,delivery_id,id);
ALTER TABLE rounds.stops ADD FOREIGN KEY(tenant_id,delivery_id,fulfillment_unit_id) REFERENCES rounds.fulfillment_units(tenant_id,delivery_id,id);
ALTER TABLE rounds.active_delivery_claims ADD FOREIGN KEY(tenant_id,delivery_id,fulfillment_unit_id) REFERENCES rounds.fulfillment_units(tenant_id,delivery_id,id);
ALTER TABLE rounds.delivery_attempts ADD FOREIGN KEY(tenant_id,delivery_id,fulfillment_unit_id) REFERENCES rounds.fulfillment_units(tenant_id,delivery_id,id);
CREATE OR REPLACE FUNCTION rounds.guard_unit_quantity() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE expected numeric; allocated numeric; scope_id uuid; line uuid;
BEGIN scope_id:=COALESCE(NEW.tenant_id,OLD.tenant_id); line:=COALESCE(NEW.line_id,OLD.line_id);
 SELECT quantity INTO expected FROM rounds.manifest_lines WHERE tenant_id=scope_id AND id=line FOR UPDATE;
 SELECT COALESCE(sum(allocated_quantity),0) INTO allocated FROM rounds.fulfillment_unit_lines WHERE tenant_id=scope_id AND line_id=line;
 IF allocated<>expected THEN RAISE EXCEPTION 'QUANTITY_EXCEEDED' USING ERRCODE='23514'; END IF;
 RETURN NULL; END $$;
CREATE CONSTRAINT TRIGGER unit_quantity_conservation AFTER INSERT OR UPDATE OR DELETE ON rounds.fulfillment_unit_lines DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION rounds.guard_unit_quantity();
CREATE OR REPLACE FUNCTION rounds.agreement_revision_sequence() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE prior bigint;
BEGIN PERFORM 1 FROM rounds.freelance_agreements WHERE tenant_id=NEW.tenant_id AND id=NEW.agreement_id FOR UPDATE;
 SELECT max(revision) INTO prior FROM rounds.agreement_revisions WHERE tenant_id=NEW.tenant_id AND agreement_id=NEW.agreement_id;
 IF NEW.revision<>COALESCE(prior,0)+1 THEN RAISE EXCEPTION 'INVALID_REVISION' USING ERRCODE='23514'; END IF; RETURN NEW; END $$;
CREATE TRIGGER revision_insert_sequence BEFORE INSERT ON rounds.agreement_revisions FOR EACH ROW EXECUTE FUNCTION rounds.agreement_revision_sequence();
ALTER TABLE rounds.shift_occurrences ADD CONSTRAINT relationship_shift_overlap EXCLUDE USING gist(tenant_id WITH =,relationship_id WITH =,tstzrange(starts_at,ends_at,'[)') WITH &&) WHERE (state IN ('scheduled','started','on_break'));
CREATE INDEX broadcasts_city_day ON rounds.broadcasts(tenant_id,city_id,service_date);
CREATE INDEX slots_city_day ON rounds.slot_occurrences(tenant_id,city_id,service_date);
CREATE INDEX shifts_city_day ON rounds.shift_occurrences(tenant_id,city_id,service_date);
ALTER TABLE rounds.domain_events ALTER COLUMN command_id DROP NOT NULL;
ALTER TABLE rounds.domain_events ADD COLUMN worker_run_id uuid;
ALTER TABLE rounds.domain_events ADD CONSTRAINT event_cause CHECK(num_nonnulls(command_id,worker_run_id)=1);

ALTER TABLE rounds.assignments ADD COLUMN agreement_id uuid;
ALTER TABLE rounds.assignments ADD COLUMN origin text NOT NULL DEFAULT 'team' CHECK(origin IN ('team','freelance'));
ALTER TABLE rounds.assignments ADD FOREIGN KEY(tenant_id,agreement_id) REFERENCES rounds.freelance_agreements(tenant_id,id);
ALTER TABLE rounds.assignments ADD CONSTRAINT assignment_origin CHECK((origin='team' AND agreement_id IS NULL) OR (origin='freelance' AND agreement_id IS NOT NULL AND release_id IS NULL));
CREATE OR REPLACE FUNCTION rounds.freeze_collected_allocation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE unit_state text;
BEGIN
 SELECT state INTO unit_state FROM rounds.fulfillment_units WHERE tenant_id=OLD.tenant_id AND id=OLD.unit_id FOR UPDATE;
 IF TG_OP='DELETE' OR NEW.unit_id<>OLD.unit_id OR NEW.line_id<>OLD.line_id OR NEW.tenant_id<>OLD.tenant_id OR (NEW.allocated_quantity<>OLD.allocated_quantity AND unit_state<>'open') THEN RAISE EXCEPTION 'IMMUTABLE_RECORD' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER collected_allocation_frozen BEFORE UPDATE OR DELETE ON rounds.fulfillment_unit_lines FOR EACH ROW EXECUTE FUNCTION rounds.freeze_collected_allocation();
ALTER TABLE rounds.location_samples ADD COLUMN expires_at timestamptz NOT NULL;
ALTER TABLE rounds.location_samples ADD CONSTRAINT gps_expiry CHECK(expires_at>received_at AND expires_at<=received_at+interval '30 days');
CREATE INDEX raw_gps_expiry ON rounds.location_samples(expires_at);
CREATE TABLE rounds.gps_retention_holds (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), driver_id uuid NOT NULL REFERENCES rounds.drivers(id),
 starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, reason text NOT NULL,
 authorized_by uuid NOT NULL REFERENCES rounds.principals(id), created_at timestamptz NOT NULL DEFAULT now(), released_at timestamptz,
 CHECK(ends_at>starts_at)
);
ALTER TABLE rounds.gps_retention_holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.gps_retention_holds FORCE ROW LEVEL SECURITY;
CREATE INDEX gps_hold_scope ON rounds.gps_retention_holds(driver_id,starts_at,ends_at) WHERE released_at IS NULL;
CREATE TABLE rounds.gps_purge_audit (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), run_id uuid NOT NULL UNIQUE, deleted_count integer NOT NULL CHECK(deleted_count>=0),
 occurred_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE rounds.gps_purge_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.gps_purge_audit FORCE ROW LEVEL SECURITY;
CREATE TRIGGER immutable_gps_purge_audit BEFORE UPDATE OR DELETE ON rounds.gps_purge_audit FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();

ALTER TABLE rounds.memberships ADD CONSTRAINT code_memberships_role_code CHECK(role_code IN ('owner','admin','dispatcher','fleet_manager','reviewer','finance','driver','receiver'));
ALTER TABLE rounds.sites ADD CONSTRAINT code_sites_site_type CHECK(site_type IN ('pickup','hub','depot','office','residence'));
ALTER TABLE rounds.invitations ADD CONSTRAINT code_invitations_relationship_kind CHECK(relationship_kind IN ('team','known_freelancer'));
ALTER TABLE rounds.driver_devices ADD CONSTRAINT code_driver_devices_platform CHECK(platform IN ('ios','android'));
ALTER TABLE rounds.verification_evidence ADD CONSTRAINT code_verification_evidence_evidence_kind CHECK(evidence_kind IN ('identity_front','identity_back','face_capture','liveness_receipt','vehicle_document','license'));
ALTER TABLE rounds.payout_methods ADD CONSTRAINT code_payout_methods_method_kind CHECK(method_kind IN ('promptpay','bank'));
ALTER TABLE rounds.intake_batches ADD CONSTRAINT code_intake_batches_input_kind CHECK(input_kind IN ('text','image','pdf','csv'));
ALTER TABLE rounds.active_delivery_claims ADD CONSTRAINT code_active_delivery_claims_claim_kind CHECK(claim_kind IN ('team','freelance','broadcast'));
ALTER TABLE rounds.handoffs ADD CONSTRAINT code_handoffs_receiver_kind CHECK(receiver_kind IN ('recipient','alternate','unattended'));
ALTER TABLE rounds.assets ADD CONSTRAINT code_assets_kind CHECK(kind IN ('delivery_photo','signature','issue_photo','message_photo','voice','document','import','export'));
ALTER TABLE rounds.customer_tracking_tokens ADD CONSTRAINT code_customer_tracking_tokens_audience CHECK(audience IN ('buyer','recipient'));
ALTER TABLE rounds.export_jobs ADD CONSTRAINT code_export_jobs_kind CHECK(kind IN ('deliveries','drivers','incidents','finance','subject'));
ALTER TABLE rounds.privacy_requests ADD CONSTRAINT code_privacy_requests_kind CHECK(kind IN ('access','export','delete'));
ALTER TABLE rounds.offline_evidence_observations ADD CONSTRAINT code_offline_evidence_observations_kind CHECK(kind IN ('pickup','arrival','handoff','proof','completion'));
ALTER TABLE rounds.policy_bindings ADD CONSTRAINT code_policy_bindings_policy_kind CHECK(policy_kind IN ('own_fleet','broadcast','proof','customer','timing','commercial','retention','map','locale','slot','intake','intercity','messaging','escalation','account','weather'));
