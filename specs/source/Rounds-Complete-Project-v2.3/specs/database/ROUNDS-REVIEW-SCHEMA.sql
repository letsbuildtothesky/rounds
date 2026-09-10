-- Rounds review DDL v2. Proposed physical schema, not a deployed or migration-tested release.
-- Service-only private schema. Production roles/policies/grants must be installed by reviewed migrations.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE SCHEMA IF NOT EXISTS rounds;
REVOKE ALL ON SCHEMA rounds FROM PUBLIC;

-- Business identity and lifecycle; fixture names never define product logic.
CREATE TABLE rounds.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  country_code char(2) NOT NULL,
  default_timezone text NOT NULL,
  default_currency char(3) NOT NULL,
  status text NOT NULL CHECK (status IN ('active','suspended','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.tenants FORCE ROW LEVEL SECURITY;

-- Application actor mapped to authentication identity.
CREATE TABLE rounds.principals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_subject uuid UNIQUE,
  display_name text NOT NULL,
  preferred_locale text NOT NULL DEFAULT 'th-TH',
  disabled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.principals ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.principals FORCE ROW LEVEL SECURITY;

-- Business membership, independent of driver work relationship.
CREATE TABLE rounds.memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  principal_id uuid NOT NULL,
  role_code text NOT NULL,
  status text NOT NULL CHECK (status IN ('invited','active','suspended','revoked')),
  permission_revision bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, principal_id)
);
ALTER TABLE rounds.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.memberships FORCE ROW LEVEL SECURITY;

-- Configured service area; city label is not security authority.
CREATE TABLE rounds.cities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  name text NOT NULL,
  country_code char(2) NOT NULL,
  timezone text NOT NULL,
  service_boundary geography(MultiPolygon,4326),
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.cities FORCE ROW LEVEL SECURITY;

-- Explicit membership access to a city.
CREATE TABLE rounds.city_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  membership_id uuid NOT NULL,
  city_id uuid NOT NULL,
  capabilities text[] NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, membership_id, city_id)
);
ALTER TABLE rounds.city_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.city_grants FORCE ROW LEVEL SECURITY;

-- Tenant-owned brand and customer tracking identity.
CREATE TABLE rounds.brands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  name text NOT NULL,
  logo_asset_id uuid,
  tracking_style jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.brands FORCE ROW LEVEL SECURITY;

-- Pickup/hub/base/site identity; geographic source and verification are explicit.
CREATE TABLE rounds.sites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  city_id uuid NOT NULL,
  name text NOT NULL,
  site_type text NOT NULL,
  address_text text NOT NULL,
  point geography(Point,4326),
  contact_principal_id uuid,
  access_notes text,
  timezone text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.sites FORCE ROW LEVEL SECURITY;

-- Capability eligibility distinct from operator feature preferences.
CREATE TABLE rounds.feature_entitlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  feature_key text NOT NULL,
  enabled boolean NOT NULL,
  effective_at timestamptz NOT NULL,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, feature_key)
);
ALTER TABLE rounds.feature_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.feature_entitlements FORCE ROW LEVEL SECURITY;

-- Immutable typed setting payloads; schema_version identifies validated JSON schema.
CREATE TABLE rounds.policy_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  policy_kind text NOT NULL,
  scope_key text NOT NULL,
  revision integer NOT NULL CHECK (revision>0),
  schema_version integer NOT NULL,
  payload jsonb NOT NULL,
  effective_at timestamptz NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, policy_kind, scope_key, revision)
);
ALTER TABLE rounds.policy_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.policy_versions FORCE ROW LEVEL SECURITY;

-- Current effective pointer; overrides resolve by domain-specific precedence.
CREATE TABLE rounds.policy_bindings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  policy_kind text NOT NULL,
  scope_key text NOT NULL,
  policy_version_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, policy_kind, scope_key)
);
ALTER TABLE rounds.policy_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.policy_bindings FORCE ROW LEVEL SECURITY;

-- Commercial entitlement record; no invented prices.
CREATE TABLE rounds.tenant_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  plan_code text NOT NULL,
  state text NOT NULL CHECK (state IN ('trial','active','past_due','cancelled')),
  currency char(3) NOT NULL,
  billing_provider text,
  provider_reference text,
  current_period_end timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.tenant_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.tenant_subscriptions FORCE ROW LEVEL SECURITY;

-- Metered usage deduplicated by original business event.
CREATE TABLE rounds.usage_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  event_id uuid NOT NULL,
  meter_key text NOT NULL,
  quantity numeric(18,4) NOT NULL,
  unit text NOT NULL,
  occurred_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, event_id, meter_key)
);
ALTER TABLE rounds.usage_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.usage_ledger FORCE ROW LEVEL SECURITY;

-- One driver identity across employers and Network.
CREATE TABLE rounds.drivers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  principal_id uuid NOT NULL UNIQUE,
  network_eligibility text NOT NULL,
  verification_application_id uuid,
  profile_asset_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.drivers FORCE ROW LEVEL SECURITY;

-- Team or known freelancer relationship, not a permanent global category.
CREATE TABLE rounds.driver_relationships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  driver_id uuid NOT NULL,
  relationship_kind text NOT NULL CHECK (relationship_kind IN ('team','known_freelancer')),
  status text NOT NULL CHECK (status IN ('invited','active','suspended','ended')),
  outside_work_allowed boolean NOT NULL DEFAULT false,
  invitation_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, driver_id, relationship_kind)
);
ALTER TABLE rounds.driver_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.driver_relationships FORCE ROW LEVEL SECURITY;

-- Hashed invitation token, actor, expiry and one-time consumption.
CREATE TABLE rounds.invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  token_hash text NOT NULL UNIQUE,
  relationship_kind text NOT NULL,
  invited_contact_hash text,
  expires_at timestamptz NOT NULL,
  used_by uuid,
  used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.invitations FORCE ROW LEVEL SECURITY;

-- Driver-controlled permission per known merchant relationship.
CREATE TABLE rounds.driver_contact_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  relationship_id uuid NOT NULL,
  messages_allowed boolean NOT NULL DEFAULT false,
  availability_requests_allowed boolean NOT NULL DEFAULT false,
  changed_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, relationship_id)
);
ALTER TABLE rounds.driver_contact_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.driver_contact_permissions FORCE ROW LEVEL SECURITY;

-- Revocable device registration, push token reference and session epoch.
CREATE TABLE rounds.driver_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  platform text NOT NULL,
  push_secret_reference text,
  device_key text NOT NULL,
  session_epoch bigint NOT NULL DEFAULT 1,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (driver_id, device_key)
);
ALTER TABLE rounds.driver_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.driver_devices FORCE ROW LEVEL SECURITY;

-- Persisted typed onboarding draft and branch with real evidence references.
CREATE TABLE rounds.onboarding_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  principal_id uuid NOT NULL,
  context text NOT NULL,
  step_key text NOT NULL,
  schema_version integer NOT NULL,
  draft jsonb NOT NULL,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.onboarding_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.onboarding_drafts FORCE ROW LEVEL SECURITY;

-- Application receipt and review state independent of availability.
CREATE TABLE rounds.verification_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  country_code char(2) NOT NULL,
  state text NOT NULL CHECK (state IN ('draft','submitted','pending','approved','rejected','correction_required')),
  submitted_at timestamptz,
  provider text,
  provider_reference text,
  decision_reason_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.verification_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.verification_applications FORCE ROW LEVEL SECURITY;

-- Document/face evidence references and correction lineage.
CREATE TABLE rounds.verification_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL,
  evidence_kind text NOT NULL,
  private_object_key text NOT NULL,
  sha256 text NOT NULL,
  state text NOT NULL CHECK (state IN ('reserved','uploaded','verified','rejected','superseded')),
  replaces_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.verification_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.verification_evidence FORCE ROW LEVEL SECURITY;

-- Tokenized/encrypted bank or PromptPay reference with masked display.
CREATE TABLE rounds.payout_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  method_kind text NOT NULL,
  country_code char(2) NOT NULL,
  currency char(3) NOT NULL,
  secret_reference text NOT NULL,
  masked_label text NOT NULL,
  verification_state text NOT NULL CHECK (verification_state IN ('pending','verified','rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.payout_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.payout_methods FORCE ROW LEVEL SECURITY;

-- Driver intent; freshness and accepted obligations evaluated separately.
CREATE TABLE rounds.availability_declarations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL UNIQUE,
  intent text NOT NULL CHECK (intent IN ('paused','open','open_later')),
  available_after timestamptz,
  declared_at timestamptz NOT NULL,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.availability_declarations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.availability_declarations FORCE ROW LEVEL SECURITY;

-- Opted-in relationship question, never an offer/booking.
CREATE TABLE rounds.availability_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  relationship_id uuid NOT NULL,
  requested_start timestamptz,
  requested_end timestamptz,
  message text,
  expires_at timestamptz NOT NULL,
  response text,
  responded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.availability_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.availability_requests FORCE ROW LEVEL SECURITY;

-- Display catalogue: motorbike_box, tuk_tuk, car, pickup, van; extensible mapping.
CREATE TABLE rounds.vehicle_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  display_key text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.vehicle_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.vehicle_types FORCE ROW LEVEL SECURITY;

-- Named physical capacity dimension with explicit unit.
CREATE TABLE rounds.cargo_classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  code text NOT NULL,
  name text NOT NULL,
  unit text NOT NULL,
  discrete boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, code)
);
ALTER TABLE rounds.cargo_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.cargo_classes FORCE ROW LEVEL SECURITY;

-- Versioned defaults for departure capacity and timing; snapshot on commitments.
CREATE TABLE rounds.vehicle_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  name text NOT NULL,
  vehicle_type_id uuid NOT NULL,
  max_stops integer NOT NULL CHECK (max_stops>0),
  max_total_units numeric(18,4) CHECK (max_total_units>=0),
  load_seconds integer NOT NULL CHECK (load_seconds>=0),
  reload_seconds integer NOT NULL CHECK (reload_seconds>=0),
  return_required boolean NOT NULL,
  revision integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.vehicle_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.vehicle_profiles FORCE ROW LEVEL SECURITY;

-- Class quantity limit; zero prohibits class.
CREATE TABLE rounds.profile_cargo_limits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  profile_id uuid NOT NULL,
  cargo_class_id uuid NOT NULL,
  max_quantity numeric(18,4) NOT NULL CHECK (max_quantity>=0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, profile_id, cargo_class_id)
);
ALTER TABLE rounds.profile_cargo_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.profile_cargo_limits FORCE ROW LEVEL SECURITY;

-- Allowed/preferred/required capability rule using a typed selector.
CREATE TABLE rounds.handling_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  handling_key text NOT NULL,
  profile_id uuid NOT NULL,
  effect text NOT NULL CHECK (effect IN ('allowed','preferred','required','prohibited')),
  rule_version integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.handling_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.handling_rules FORCE ROW LEVEL SECURITY;

-- Tenant vehicle instance, reusable type/profile and service status.
CREATE TABLE rounds.vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  vehicle_type_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  plate text NOT NULL,
  status text NOT NULL CHECK (status IN ('available','unavailable','maintenance','archived')),
  capability_overrides jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.vehicles FORCE ROW LEVEL SECURITY;

-- Driver-owned vehicle; merchant sees authorized capability projection.
CREATE TABLE rounds.freelance_vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  vehicle_type_id uuid NOT NULL,
  plate_secret_reference text,
  masked_plate text,
  capabilities jsonb NOT NULL,
  verified_at timestamptz,
  status text NOT NULL CHECK (status IN ('pending','verified','unavailable','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.freelance_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.freelance_vehicles FORCE ROW LEVEL SECURITY;

-- Recurring schedule, effective dates and explicit overnight local minutes.
CREATE TABLE rounds.shift_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  relationship_id uuid NOT NULL,
  city_id uuid NOT NULL,
  weekdays smallint[] NOT NULL,
  start_minute integer NOT NULL CHECK (start_minute>=0 AND start_minute<1440),
  end_minute integer NOT NULL,
  valid_from date NOT NULL,
  valid_to date,
  timezone text NOT NULL,
  vehicle_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  CHECK (end_minute>start_minute AND end_minute<=2880)
);
ALTER TABLE rounds.shift_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.shift_templates FORCE ROW LEVEL SECURITY;

-- Resolved dated shift, including off-day/one-off override provenance.
CREATE TABLE rounds.shift_occurrences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  template_id uuid,
  relationship_id uuid NOT NULL,
  city_id uuid NOT NULL,
  service_date date NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  state text NOT NULL CHECK (state IN ('scheduled','started','on_break','ended','no_show','cancelled')),
  override_reason text,
  vehicle_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  CHECK (ends_at>starts_at),
  UNIQUE(tenant_id,template_id,service_date)
);
ALTER TABLE rounds.shift_occurrences ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.shift_occurrences FORCE ROW LEVEL SECURITY;

-- Append-only start/end and correction requests/decisions, not payroll.
CREATE TABLE rounds.attendance_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  shift_id uuid NOT NULL,
  driver_id uuid NOT NULL,
  event_kind text NOT NULL,
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL,
  actor_id uuid NOT NULL,
  corrects_event_id uuid,
  reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.attendance_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.attendance_events FORCE ROW LEVEL SECURITY;

-- Named delivery-window identity; historical versions retained.
CREATE TABLE rounds.slot_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  city_id uuid NOT NULL,
  site_id uuid,
  brand_id uuid,
  name text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.slot_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.slot_templates FORCE ROW LEVEL SECURITY;

-- Immutable recurring slot timing and allocation policy in local minutes from service-date midnight.
CREATE TABLE rounds.slot_template_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  template_id uuid NOT NULL,
  revision integer NOT NULL,
  timezone text NOT NULL,
  weekdays smallint[] NOT NULL,
  valid_from date NOT NULL,
  valid_to date,
  window_start_minute integer NOT NULL,
  window_end_minute integer NOT NULL,
  cutoff_minute integer NOT NULL,
  release_minute integer NOT NULL,
  max_orders integer NOT NULL CHECK (max_orders>0),
  policy_version_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, template_id, revision),
  CHECK (window_start_minute>=0 AND window_start_minute<1440),
  CHECK (window_end_minute>window_start_minute AND window_end_minute<=2880),
  CHECK (cutoff_minute<=release_minute AND release_minute<=window_start_minute)
);
ALTER TABLE rounds.slot_template_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.slot_template_versions FORCE ROW LEVEL SECURITY;

-- One dated override per template; closure or complete resolved replacement values.
CREATE TABLE rounds.slot_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  template_id uuid NOT NULL,
  service_date date NOT NULL,
  closed boolean NOT NULL,
  replacement jsonb NOT NULL,
  reason text NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, template_id, service_date)
);
ALTER TABLE rounds.slot_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.slot_overrides FORCE ROW LEVEL SECURITY;

-- Resolved immutable promise basis plus independently versioned admission controls; issued promises stay on delivery snapshot.
CREATE TABLE rounds.slot_occurrences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  template_version_id uuid NOT NULL,
  override_id uuid,
  city_id uuid NOT NULL,
  service_date date NOT NULL,
  window_start_at timestamptz NOT NULL,
  window_end_at timestamptz NOT NULL,
  cutoff_at timestamptz NOT NULL,
  release_at timestamptz NOT NULL,
  max_orders integer NOT NULL CHECK (max_orders>0),
  admission_state text NOT NULL CHECK (admission_state IN ('open','closed','overcommitted','superseded')),
  resolution_revision integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, template_version_id, service_date, resolution_revision),
  CHECK (window_end_at>window_start_at),
  CHECK (cutoff_at<=release_at AND release_at<=window_start_at)
);
ALTER TABLE rounds.slot_occurrences ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.slot_occurrences FORCE ROW LEVEL SECURITY;

-- Atomic capacity reservation for a draft/source delivery; held expiry is server-owned.
CREATE TABLE rounds.slot_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  occurrence_id uuid NOT NULL,
  delivery_id uuid,
  draft_id uuid,
  source_key text NOT NULL,
  state text NOT NULL CHECK (state IN ('held','committed','released','expired')),
  expires_at timestamptz,
  committed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  CHECK (num_nonnulls(delivery_id,draft_id)=1),
  CHECK (state<>'held' OR (draft_id IS NOT NULL AND expires_at IS NOT NULL AND committed_at IS NULL)),
  CHECK (state<>'committed' OR (delivery_id IS NOT NULL AND committed_at IS NOT NULL))
);
ALTER TABLE rounds.slot_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.slot_reservations FORCE ROW LEVEL SECURITY;

-- Commerce connection config, authorization and health independently recorded.
CREATE TABLE rounds.source_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  provider text NOT NULL,
  external_store_key text NOT NULL,
  secret_reference text,
  state text NOT NULL CHECK (state IN ('active','paused','error','disconnected')),
  city_id uuid,
  site_id uuid,
  brand_id uuid,
  permissions jsonb NOT NULL,
  last_received_at timestamptz,
  last_writeback_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, provider, external_store_key)
);
ALTER TABLE rounds.source_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.source_connections FORCE ROW LEVEL SECURITY;

-- Authenticated webhook/request inbox; safely retained minimized payload and processing result.
CREATE TABLE rounds.source_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  connection_id uuid NOT NULL,
  provider_event_key text NOT NULL,
  source_object_key text NOT NULL,
  source_revision text,
  received_at timestamptz NOT NULL,
  payload_hash text NOT NULL,
  payload_reference text,
  state text NOT NULL CHECK (state IN ('received','normalized','review_required','applied','rejected','conflict')),
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, connection_id, provider_event_key)
);
ALTER TABLE rounds.source_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.source_events FORCE ROW LEVEL SECURITY;

-- Manual/import/AI batch job and source evidence reference.
CREATE TABLE rounds.intake_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  created_by uuid NOT NULL,
  input_kind text NOT NULL,
  source_asset_id uuid,
  state text NOT NULL CHECK (state IN ('draft','processing','review_ready','committing','completed','partial_failed','failed')),
  total_rows integer NOT NULL DEFAULT 0,
  processed_rows integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.intake_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.intake_batches FORCE ROW LEVEL SECURITY;

-- Editable normalized draft; original source retained; no assignment effect.
CREATE TABLE rounds.intake_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  batch_id uuid,
  connection_id uuid,
  source_order_key text,
  source_revision text,
  city_id uuid,
  draft_payload jsonb NOT NULL,
  original_payload_reference text,
  review_state text NOT NULL CHECK (review_state IN ('draft','extracting','review_needed','ready','committed','discarded')),
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.intake_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.intake_drafts FORCE ROW LEVEL SECURITY;

-- AI/geocoder candidate with before/after, allowed provenance, expiry and reviewed disposition.
CREATE TABLE rounds.address_suggestions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  draft_id uuid,
  delivery_id uuid,
  input_hash text NOT NULL,
  provider text NOT NULL,
  model_version text,
  changed_fields jsonb NOT NULL,
  suggested_text text,
  point geography(Point,4326),
  confidence numeric(5,4),
  state text NOT NULL CHECK (state IN ('proposed','accepted','edited','rejected','superseded')),
  reviewed_by uuid,
  reviewed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1)
);
ALTER TABLE rounds.address_suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.address_suggestions FORCE ROW LEVEL SECURITY;

-- Building/site entrance identity; recipient unit data stored separately.
CREATE TABLE rounds.entrances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  site_id uuid,
  city_id uuid NOT NULL,
  label text NOT NULL,
  retired_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.entrances ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.entrances FORCE ROW LEVEL SECURITY;

-- Immutable reviewed entrance/access knowledge with attribution and licensed-source metadata.
CREATE TABLE rounds.entrance_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  entrance_id uuid NOT NULL,
  revision integer NOT NULL,
  point geography(Point,4326) NOT NULL,
  access_notes text,
  handoff_notes text,
  vehicle_access jsonb NOT NULL,
  provenance jsonb NOT NULL,
  confirmed_by uuid NOT NULL,
  confirmed_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, entrance_id, revision)
);
ALTER TABLE rounds.entrance_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.entrance_revisions FORCE ROW LEVEL SECURITY;

-- Candidate measured observation; review does not change earlier delivery evidence.
CREATE TABLE rounds.location_observations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid,
  driver_id uuid,
  point geography(Point,4326),
  accuracy_m numeric CHECK (accuracy_m>=0),
  observed_at timestamptz NOT NULL,
  kind text NOT NULL,
  note text,
  state text NOT NULL CHECK (state IN ('proposed','reviewed','accepted','rejected')),
  reviewed_revision_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.location_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.location_observations FORCE ROW LEVEL SECURITY;

-- Stable doorstep obligation; readiness, outcome and evidence dimensions are distinct.
CREATE TABLE rounds.deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  city_id uuid NOT NULL,
  brand_id uuid,
  pickup_site_id uuid NOT NULL,
  source_connection_id uuid,
  source_order_key text,
  human_reference text NOT NULL,
  service_date date NOT NULL,
  timezone text NOT NULL,
  window_start_at timestamptz NOT NULL,
  window_end_at timestamptz NOT NULL,
  slot_occurrence_id uuid,
  address_text text NOT NULL,
  destination geography(Point,4326),
  destination_version integer NOT NULL DEFAULT 1,
  entrance_revision_id uuid,
  private_access_notes text,
  readiness text NOT NULL CHECK (readiness IN ('draft','review_needed','ready','held')),
  outcome text NOT NULL CHECK (outcome IN ('open','delivered','partially_delivered','rescheduled','returned','cancelled','unresolved')),
  evidence_state text NOT NULL CHECK (evidence_state IN ('none','local_only','pending','complete','disputed')),
  current_manifest_id uuid,
  proof_policy_id uuid NOT NULL,
  created_by uuid NOT NULL,
  preparation_state text NOT NULL DEFAULT 'unknown' CHECK (preparation_state IN ('unknown','preparing','ready','blocked')),
  ready_by timestamptz,
  ready_declared_at timestamptz,
  ready_declared_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  CHECK (window_end_at>window_start_at),
  UNIQUE (tenant_id, human_reference)
);
ALTER TABLE rounds.deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.deliveries FORCE ROW LEVEL SECURITY;

-- Buyer, recipient, pickup and alternate are explicit roles; secret contact values encrypted.
CREATE TABLE rounds.delivery_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid NOT NULL,
  role text NOT NULL,
  person_key text,
  display_name text NOT NULL,
  contact_secret_reference text,
  masked_contact text,
  locale text,
  notification_permissions jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.delivery_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.delivery_contacts FORCE ROW LEVEL SECURITY;

-- Immutable physical-content revision; new version before pickup requires explicit revalidation.
CREATE TABLE rounds.manifests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid NOT NULL,
  revision integer NOT NULL,
  source text NOT NULL,
  sealed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, delivery_id, revision)
);
ALTER TABLE rounds.manifests ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.manifests FORCE ROW LEVEL SECURITY;

-- Identified line and expected amount; one quantity two line is not two anonymous taps.
CREATE TABLE rounds.manifest_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  manifest_id uuid NOT NULL,
  line_key text NOT NULL,
  label text NOT NULL,
  quantity numeric(18,4) NOT NULL CHECK (quantity>0),
  unit text NOT NULL,
  cargo_class_id uuid,
  handling_keys text[] NOT NULL DEFAULT ARRAY[]::text[],
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, manifest_id, line_key)
);
ALTER TABLE rounds.manifest_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.manifest_lines FORCE ROW LEVEL SECURITY;

-- Optional independently identified parcel, not inferred from product quantity.
CREATE TABLE rounds.packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  manifest_id uuid NOT NULL,
  package_key text NOT NULL,
  label text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, manifest_id, package_key)
);
ALTER TABLE rounds.packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.packages FORCE ROW LEVEL SECURITY;

-- Identified package contents with line quantities; sums validated transactionally.
CREATE TABLE rounds.package_contents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  package_id uuid NOT NULL,
  line_id uuid NOT NULL,
  quantity numeric(18,4) NOT NULL CHECK (quantity>0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, package_id, line_id)
);
ALTER TABLE rounds.package_contents ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.package_contents FORCE ROW LEVEL SECURITY;

-- City/date draft planning aggregate.
CREATE TABLE rounds.plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  city_id uuid NOT NULL,
  service_date date NOT NULL,
  state text NOT NULL CHECK (state IN ('draft','generating','review_ready','saved','released','superseded')),
  input_revision bigint NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE(tenant_id,city_id,service_date)
);
ALTER TABLE rounds.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.plans FORCE ROW LEVEL SECURITY;

-- Immutable before/after proposal, inputs/policy hashes and allowed route artifact references.
CREATE TABLE rounds.plan_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  plan_id uuid NOT NULL,
  base_version bigint NOT NULL,
  input_hash text NOT NULL,
  policy_hash text NOT NULL,
  proposal jsonb NOT NULL,
  impact jsonb NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.plan_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.plan_proposals FORCE ROW LEVEL SECURITY;

-- Released snapshot; uncovered scope and approval recorded.
CREATE TABLE rounds.plan_releases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  plan_id uuid NOT NULL,
  proposal_id uuid NOT NULL,
  released_by uuid NOT NULL,
  released_at timestamptz NOT NULL,
  snapshot jsonb NOT NULL,
  uncovered_delivery_ids uuid[] NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.plan_releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.plan_releases FORCE ROW LEVEL SECURITY;

-- Local work commitment; pickup/date/city coherent.
CREATE TABLE rounds.rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  city_id uuid NOT NULL,
  service_date date NOT NULL,
  pickup_site_id uuid NOT NULL,
  fulfillment_kind text NOT NULL CHECK (fulfillment_kind IN ('team','freelance')),
  driver_id uuid,
  vehicle_id uuid,
  freelance_vehicle_id uuid,
  state text NOT NULL CHECK (state IN ('draft','planned','staged','released','active','completed','cancelled')),
  planned_start_at timestamptz,
  predicted_free_at timestamptz,
  release_id uuid,
  capacity_snapshot jsonb NOT NULL,
  policy_version_id uuid NOT NULL,
  departure_gate text NOT NULL DEFAULT 'awaiting_preparation' CHECK (departure_gate IN ('awaiting_preparation','awaiting_receipt','discrepancy','ready','blocked')),
  staged_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  CHECK (num_nonnulls(vehicle_id,freelance_vehicle_id)<=1)
);
ALTER TABLE rounds.rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.rounds FORCE ROW LEVEL SECURITY;

-- Pickup, dropoff, return, transfer; stable stop identity survives sequence edits.
CREATE TABLE rounds.stops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  round_id uuid NOT NULL,
  delivery_id uuid,
  kind text NOT NULL CHECK (kind IN ('pickup','dropoff','return','transfer')),
  sequence integer NOT NULL CHECK (sequence>=0),
  destination geography(Point,4326),
  destination_version integer NOT NULL,
  state text NOT NULL CHECK (state IN ('planned','released','en_route','arrived','handed_over','completed','failed','cancelled')),
  service_seconds integer NOT NULL CHECK (service_seconds>=0),
  planned_arrival_at timestamptz,
  actual_arrival_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, round_id, sequence) DEFERRABLE INITIALLY DEFERRED
);
ALTER TABLE rounds.stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.stops FORCE ROW LEVEL SECURITY;

-- Team-issued work and response state with originating release/change.
CREATE TABLE rounds.assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  round_id uuid NOT NULL,
  driver_id uuid NOT NULL,
  state text NOT NULL CHECK (state IN ('issued','received','acknowledged','cannot_comply','withdrawn','superseded','completed')),
  issued_at timestamptz NOT NULL,
  received_at timestamptz,
  acknowledged_at timestamptz,
  release_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.assignments FORCE ROW LEVEL SECURITY;

-- Global exclusion of overlapping committed work without cross-merchant data exposure.
CREATE TABLE rounds.driver_commitments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  tenant_id uuid NOT NULL,
  round_id uuid,
  trip_id uuid,
  busy_range tstzrange NOT NULL,
  state text NOT NULL CHECK (state IN ('pending','committed','cancelled','completed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  CHECK (NOT isempty(busy_range)),
  CHECK (num_nonnulls(round_id,trip_id)=1),
  CHECK (NOT lower_inf(busy_range) AND NOT upper_inf(busy_range) AND lower_inc(busy_range) AND NOT upper_inc(busy_range))
);
ALTER TABLE rounds.driver_commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.driver_commitments FORCE ROW LEVEL SECURITY;

-- Single live assignment/search owner per delivery; settled history in events.
CREATE TABLE rounds.active_delivery_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid NOT NULL,
  claim_kind text NOT NULL,
  round_id uuid,
  broadcast_id uuid,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, delivery_id),
  CHECK (num_nonnulls(round_id,broadcast_id)=1)
);
ALTER TABLE rounds.active_delivery_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.active_delivery_claims FORCE ROW LEVEL SECURITY;

-- Explicit execution attempt, not rewritten by retry/reschedule.
CREATE TABLE rounds.delivery_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid NOT NULL,
  stop_id uuid NOT NULL,
  driver_id uuid NOT NULL,
  attempt_number integer NOT NULL,
  state text NOT NULL CHECK (state IN ('pending','en_route','arrived','handed_over','completed','failed','cancelled')),
  arrived_at timestamptz,
  handoff_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, delivery_id, attempt_number)
);
ALTER TABLE rounds.delivery_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.delivery_attempts FORCE ROW LEVEL SECURITY;

-- Append-only signed-actor physical collection/handoff/return/transfer record.
CREATE TABLE rounds.custody_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  manifest_id uuid NOT NULL,
  attempt_id uuid,
  trip_id uuid,
  event_kind text NOT NULL,
  from_principal_id uuid,
  to_principal_id uuid,
  site_id uuid,
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL,
  actor_id uuid NOT NULL,
  command_id uuid NOT NULL,
  round_id uuid,
  stop_id uuid,
  from_custodian_id uuid,
  to_custodian_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, command_id, manifest_id, event_kind),
  CHECK (num_nonnulls(from_custodian_id,to_custodian_id)>=1),
  CHECK (from_custodian_id IS DISTINCT FROM to_custodian_id)
);
ALTER TABLE rounds.custody_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.custody_events FORCE ROW LEVEL SECURITY;

-- Per-event physical line quantity. Net holdings validated under locked manifest.
CREATE TABLE rounds.custody_event_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  event_id uuid NOT NULL,
  line_id uuid NOT NULL,
  quantity numeric(18,4) NOT NULL CHECK (quantity>0),
  condition_code text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, event_id, line_id)
);
ALTER TABLE rounds.custody_event_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.custody_event_lines FORCE ROW LEVEL SECURITY;

-- Transactional projection of known held quantities by custodian; rebuildable from events.
CREATE TABLE rounds.custody_balances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  line_id uuid NOT NULL,
  quantity numeric(18,4) NOT NULL CHECK (quantity>=0),
  last_event_id uuid NOT NULL,
  custodian_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id,line_id,custodian_id)
);
ALTER TABLE rounds.custody_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.custody_balances FORCE ROW LEVEL SECURITY;

-- Physical delivery handoff separate from durable proof completion.
CREATE TABLE rounds.handoffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  attempt_id uuid NOT NULL,
  receiver_kind text NOT NULL,
  receiver_contact_id uuid,
  place_code text,
  instruction_reference text,
  occurred_at timestamptz NOT NULL,
  actor_id uuid NOT NULL,
  proof_policy_id uuid NOT NULL,
  state text NOT NULL CHECK (state IN ('recorded','disputed','corrected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.handoffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.handoffs FORCE ROW LEVEL SECURITY;

-- Server-owned upload reservation and verified object metadata. No bytes inline.
CREATE TABLE rounds.assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  object_key text NOT NULL UNIQUE,
  kind text NOT NULL,
  state text NOT NULL CHECK (state IN ('reserved','uploading','uploaded','scanning','verified','rejected','expired')),
  mime_type text NOT NULL,
  byte_size bigint NOT NULL CHECK (byte_size>=0),
  sha256 text NOT NULL,
  created_by uuid NOT NULL,
  retention_class text NOT NULL,
  verified_at timestamptz,
  purge_after timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.assets FORCE ROW LEVEL SECURITY;

-- Two-phase evidence submission, policy snapshot and actor.
CREATE TABLE rounds.proof_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  attempt_id uuid NOT NULL,
  handoff_id uuid NOT NULL,
  policy_version_id uuid NOT NULL,
  submitted_by uuid NOT NULL,
  state text NOT NULL CHECK (state IN ('pending','complete','disputed','retained_for_review','rejected')),
  committed_at timestamptz,
  command_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, command_id)
);
ALTER TABLE rounds.proof_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.proof_submissions FORCE ROW LEVEL SECURITY;

-- Manifest confirmation/photo/signature/receiver evidence requirements and durable receipts.
CREATE TABLE rounds.proof_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  submission_id uuid NOT NULL,
  item_kind text NOT NULL,
  asset_id uuid,
  line_id uuid,
  quantity numeric(18,4),
  receiver_contact_id uuid,
  note text CHECK(length(note)<=2000),
  location_observation_id uuid,
  state text NOT NULL CHECK (state IN ('pending','verified','invalidated','rejected')),
  captured_at timestamptz,
  received_at timestamptz,
  invalidated_at timestamptz,
  invalidated_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.proof_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.proof_items FORCE ROW LEVEL SECURITY;

-- Typed incident: recipient/address/package/wait/cannot-complete/emergency.
CREATE TABLE rounds.issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid,
  attempt_id uuid,
  round_id uuid,
  trip_id uuid,
  driver_id uuid,
  issue_type text NOT NULL,
  reason_code text NOT NULL,
  state text NOT NULL CHECK (state IN ('open','investigating','decided','resolved')),
  detail text,
  reported_at timestamptz NOT NULL,
  reported_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.issues FORCE ROW LEVEL SECURITY;

-- Attributed instructions/approval and customer/freelancer consent references.
-- 2026-09-10 ADR-T08: nullable original reason; old rows are not backfilled.
CREATE TABLE rounds.issue_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  issue_id uuid NOT NULL,
  decision_kind text NOT NULL,
  instruction jsonb NOT NULL,
  reason text,
  decided_by uuid NOT NULL,
  decided_at timestamptz NOT NULL,
  supersedes_id uuid,
  customer_agreement_reference text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.issue_decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.issue_decisions FORCE ROW LEVEL SECURITY;

-- Explicit return obligation and receiving site; related line quantities retained.
CREATE TABLE rounds.return_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid NOT NULL,
  manifest_id uuid NOT NULL,
  origin_issue_id uuid,
  round_id uuid,
  destination_site_id uuid NOT NULL,
  state text NOT NULL CHECK (state IN ('planned','in_transit','arrived','receiving','received','disputed','cancelled')),
  agreement_id uuid,
  received_at timestamptz,
  custodian_id uuid,
  receiver_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.return_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.return_tasks FORCE ROW LEVEL SECURITY;

-- Immutable proposed material diff plus consent/ack lifecycle.
CREATE TABLE rounds.change_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  round_id uuid NOT NULL,
  agreement_id uuid,
  base_version bigint NOT NULL,
  change_kind text NOT NULL,
  diff jsonb NOT NULL,
  impact jsonb NOT NULL,
  fare_delta_minor bigint,
  currency char(3),
  state text NOT NULL CHECK (state IN ('pending','applied','acknowledged','accepted','declined','withdrawn','expired','superseded')),
  expires_at timestamptz NOT NULL,
  created_by uuid NOT NULL,
  mode text NOT NULL CHECK(mode IN ('instruct','propose')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.change_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.change_proposals FORCE ROW LEVEL SECURITY;

-- Actor response to a specific change version; cannot acknowledge a newer change.
CREATE TABLE rounds.change_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  proposal_id uuid NOT NULL,
  proposal_version bigint NOT NULL,
  driver_id uuid NOT NULL,
  response text NOT NULL,
  responded_at timestamptz NOT NULL,
  command_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, command_id)
);
ALTER TABLE rounds.change_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.change_responses FORCE ROW LEVEL SECURITY;

-- Operator-started city/pickup/date search with frozen offered revision.
CREATE TABLE rounds.broadcasts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  city_id uuid NOT NULL,
  pickup_site_id uuid NOT NULL,
  service_date date NOT NULL,
  round_id uuid NOT NULL,
  state text NOT NULL CHECK (state IN ('searching','accepted','stopped','expired','no_acceptance')),
  scope_revision integer NOT NULL,
  scope_hash text NOT NULL,
  fare_minor bigint NOT NULL CHECK (fare_minor>=0),
  currency char(3) NOT NULL,
  search_policy_id uuid NOT NULL,
  started_by uuid NOT NULL,
  started_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.broadcasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.broadcasts FORCE ROW LEVEL SECURITY;

-- Durable expansion schedule from operator-approved policy.
CREATE TABLE rounds.broadcast_waves (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  broadcast_id uuid NOT NULL,
  wave_number integer NOT NULL,
  radius_m integer NOT NULL CHECK (radius_m>0),
  starts_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  state text NOT NULL CHECK (state IN ('scheduled','active','closed','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, broadcast_id, wave_number),
  CHECK (expires_at>starts_at)
);
ALTER TABLE rounds.broadcast_waves ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.broadcast_waves FORCE ROW LEVEL SECURITY;

-- Private offer recipient/scope/deadline; redacted pre-acceptance projection.
CREATE TABLE rounds.offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  broadcast_id uuid NOT NULL,
  driver_id uuid NOT NULL,
  scope_revision integer NOT NULL,
  scope_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  state text NOT NULL CHECK (state IN ('offered','accepted','declined','expired','taken','withdrawn')),
  notified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, broadcast_id, driver_id, scope_revision)
);
ALTER TABLE rounds.offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.offers FORCE ROW LEVEL SECURITY;

-- Single accepted scope/economics snapshot; revisions append.
CREATE TABLE rounds.freelance_agreements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  broadcast_id uuid NOT NULL,
  offer_id uuid NOT NULL,
  round_id uuid NOT NULL,
  driver_id uuid NOT NULL,
  accepted_revision integer NOT NULL,
  accepted_scope jsonb NOT NULL,
  fare_minor bigint NOT NULL CHECK (fare_minor>=0),
  currency char(3) NOT NULL,
  accepted_at timestamptz NOT NULL,
  state text NOT NULL CHECK (state IN ('active','completed','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, broadcast_id),
  UNIQUE (tenant_id, offer_id)
);
ALTER TABLE rounds.freelance_agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.freelance_agreements FORCE ROW LEVEL SECURITY;

-- Immutable agreed change/cancellation/return compensation ledger entries.
CREATE TABLE rounds.fare_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  agreement_id uuid NOT NULL,
  change_proposal_id uuid,
  amount_minor bigint NOT NULL,
  currency char(3) NOT NULL,
  reason_code text NOT NULL,
  authorization_reference text NOT NULL,
  event_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, event_id)
);
ALTER TABLE rounds.fare_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.fare_adjustments FORCE ROW LEVEL SECURITY;

-- Earned/due/paid/disputed external settlement facts; no platform-held balance implied.
CREATE TABLE rounds.settlement_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  agreement_id uuid NOT NULL,
  amount_minor bigint NOT NULL,
  currency char(3) NOT NULL,
  state text NOT NULL CHECK (state IN ('open','closed','cancelled')),
  earned_at timestamptz,
  due_at timestamptz,
  paid_at timestamptz,
  payment_reference text,
  proof_asset_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.settlement_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.settlement_records FORCE ROW LEVEL SECURITY;

-- Append-only finance provenance and dispute/correction event.
CREATE TABLE rounds.settlement_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  settlement_id uuid NOT NULL,
  event_kind text NOT NULL,
  actor_id uuid NOT NULL,
  occurred_at timestamptz NOT NULL,
  detail jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.settlement_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.settlement_events FORCE ROW LEVEL SECURITY;

-- Optional intercity physical leg; local city Round is separate.
CREATE TABLE rounds.transport_trips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  origin_site_id uuid NOT NULL,
  destination_site_id uuid NOT NULL,
  driver_id uuid,
  vehicle_id uuid,
  service_date date NOT NULL,
  planned_departure_at timestamptz NOT NULL,
  planned_arrival_at timestamptz NOT NULL,
  actual_departure_at timestamptz,
  actual_arrival_at timestamptz,
  state text NOT NULL CHECK (state IN ('draft','scheduled','loading','departed','arrived','receiving','closed','cancelled')),
  capacity_snapshot jsonb NOT NULL,
  receiving_principal_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  CHECK (origin_site_id<>destination_site_id),
  CHECK (planned_arrival_at>planned_departure_at)
);
ALTER TABLE rounds.transport_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.transport_trips FORCE ROW LEVEL SECURITY;

-- Manifest reservation on a trip, independent of loading/receipt.
CREATE TABLE rounds.trip_bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  trip_id uuid NOT NULL,
  delivery_id uuid NOT NULL,
  manifest_id uuid NOT NULL,
  state text NOT NULL CHECK (state IN ('booked','partially_loaded','loaded','partially_received','received','disputed','cancelled')),
  booked_by uuid NOT NULL,
  custodian_id uuid,
  receiver_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, trip_id, delivery_id)
);
ALTER TABLE rounds.trip_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.trip_bookings FORCE ROW LEVEL SECURITY;

-- Destination receiving record with explicit discrepancies.
CREATE TABLE rounds.trip_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  booking_id uuid NOT NULL,
  receiver_id uuid NOT NULL,
  received_at timestamptz NOT NULL,
  state text NOT NULL CHECK (state IN ('partial','complete','disputed')),
  custody_event_id uuid NOT NULL,
  discrepancies jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.trip_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.trip_receipts FORCE ROW LEVEL SECURITY;

-- Either authorized relationship context or job context; no universal cross-tenant room.
CREATE TABLE rounds.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  kind text NOT NULL,
  round_id uuid,
  relationship_id uuid,
  subject text,
  closed_at timestamptz,
  trip_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  CHECK (num_nonnulls(round_id,relationship_id,trip_id)=1)
);
ALTER TABLE rounds.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.conversations FORCE ROW LEVEL SECURITY;

-- Explicit participant and expiry; server recomputes access after reassignment.
CREATE TABLE rounds.conversation_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  conversation_id uuid NOT NULL,
  principal_id uuid NOT NULL,
  access_kind text NOT NULL,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, conversation_id, principal_id)
);
ALTER TABLE rounds.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.conversation_participants FORCE ROW LEVEL SECURITY;

-- Human/system messages with source context and idempotent send.
CREATE TABLE rounds.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  client_message_id uuid NOT NULL,
  kind text NOT NULL,
  body text,
  state text NOT NULL CHECK (state IN ('received','delivered','read','failed')),
  occurred_at timestamptz NOT NULL,
  received_at timestamptz,
  system_event_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, sender_id, client_message_id)
);
ALTER TABLE rounds.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.messages FORCE ROW LEVEL SECURITY;

-- Staged/sent attachment relation; location is typed, not arbitrary executable content.
CREATE TABLE rounds.message_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  message_id uuid NOT NULL,
  asset_id uuid,
  kind text NOT NULL,
  location geography(Point,4326),
  accuracy_m numeric,
  observed_at timestamptz,
  caption text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.message_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.message_attachments FORCE ROW LEVEL SECURITY;

-- Participant received/read acknowledgements only from valid channel/client evidence.
CREATE TABLE rounds.message_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  message_id uuid NOT NULL,
  principal_id uuid NOT NULL,
  received_at timestamptz,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, message_id, principal_id)
);
ALTER TABLE rounds.message_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.message_receipts FORCE ROW LEVEL SECURITY;

-- Provider session/caller/callee; incoming/outgoing state and current job context.
CREATE TABLE rounds.call_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  conversation_id uuid NOT NULL,
  caller_id uuid NOT NULL,
  callee_id uuid,
  contact_id uuid,
  provider text,
  provider_reference text,
  state text NOT NULL CHECK (state IN ('initiated','ringing','connected','declined','missed','ended','failed')),
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.call_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.call_sessions FORCE ROW LEVEL SECURITY;

-- Manual outcomes separate from provider-observed state.
CREATE TABLE rounds.call_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  call_id uuid NOT NULL,
  event_kind text NOT NULL,
  provenance text NOT NULL,
  actor_id uuid,
  occurred_at timestamptz NOT NULL,
  provider_event_key text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.call_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.call_events FORCE ROW LEVEL SECURITY;

-- In-app actionable pointer; fetch current state on open.
CREATE TABLE rounds.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  principal_id uuid NOT NULL,
  event_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  kind text NOT NULL,
  locale text NOT NULL,
  read_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, principal_id, event_id, kind)
);
ALTER TABLE rounds.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.notifications FORCE ROW LEVEL SECURITY;

-- Hashed audience-scoped revocable URL token.
CREATE TABLE rounds.customer_tracking_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid NOT NULL,
  audience text NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  policy_version_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.customer_tracking_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.customer_tracking_tokens FORCE ROW LEVEL SECURITY;

-- Per-event audience/channel attempt identity with actual provider receipts.
CREATE TABLE rounds.notification_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid,
  event_id uuid NOT NULL,
  audience_key text NOT NULL,
  channel text NOT NULL,
  provider text,
  state text NOT NULL CHECK (state IN ('queued','provider_accepted','delivered','failed','unknown')),
  provider_reference text,
  last_attempt_at timestamptz,
  received_at timestamptz,
  idempotency_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, idempotency_key)
);
ALTER TABLE rounds.notification_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.notification_deliveries FORCE ROW LEVEL SECURITY;

-- Deduplicated verified asynchronous provider facts; no automatic causal reinterpretation.
CREATE TABLE rounds.provider_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  provider text NOT NULL,
  provider_account_key text NOT NULL,
  provider_event_key text NOT NULL,
  received_at timestamptz NOT NULL,
  event_kind text NOT NULL,
  payload_hash text NOT NULL,
  related_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, provider, provider_account_key, provider_event_key)
);
ALTER TABLE rounds.provider_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.provider_receipts FORCE ROW LEVEL SECURITY;

-- Normalized delivery result sent to source under permission and version checks.
CREATE TABLE rounds.writeback_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  connection_id uuid NOT NULL,
  delivery_id uuid NOT NULL,
  domain_event_id uuid NOT NULL,
  kind text NOT NULL,
  state text NOT NULL CHECK (state IN ('queued','sending','succeeded','failed','unknown')),
  attempts integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz,
  idempotency_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, idempotency_key)
);
ALTER TABLE rounds.writeback_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.writeback_tasks FORCE ROW LEVEL SECURITY;

-- Licensed provider estimate with explicit profile/input/freshness; no unconditional provider-content storage.
CREATE TABLE rounds.route_estimates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  round_id uuid,
  trip_id uuid,
  provider text NOT NULL,
  profile text NOT NULL,
  input_hash text NOT NULL,
  distance_m numeric CHECK (distance_m>=0),
  duration_seconds integer CHECK (duration_seconds>=0),
  traffic_aware boolean NOT NULL,
  calculated_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  licensed_geometry_reference text,
  warnings jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.route_estimates ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.route_estimates FORCE ROW LEVEL SECURITY;

-- Destination ledger deduplicates remount/retry; real SDK billing observed separately.
CREATE TABLE rounds.navigation_intents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  driver_id uuid NOT NULL,
  stop_id uuid NOT NULL,
  destination_version integer NOT NULL,
  provider text NOT NULL,
  destination_fingerprint text NOT NULL,
  state text NOT NULL CHECK (state IN ('created','opened','superseded','expired','failed')),
  activated_at timestamptz,
  completed_at timestamptz,
  request_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, driver_id, stop_id, destination_version, provider)
);
ALTER TABLE rounds.navigation_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.navigation_intents FORCE ROW LEVEL SECURITY;

-- Server-enforced time/purpose boundary on driver tracking; no permanent team surveillance.
CREATE TABLE rounds.tracking_entitlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  tenant_id uuid,
  round_id uuid,
  trip_id uuid,
  purpose text NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.tracking_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.tracking_entitlements FORCE ROW LEVEL SECURITY;

-- One hot observation per driver; late historical batch cannot rewind it.
CREATE TABLE rounds.current_positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL UNIQUE,
  point geography(Point,4326) NOT NULL,
  observed_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL,
  accuracy_m numeric NOT NULL CHECK (accuracy_m>=0),
  source text NOT NULL,
  device_id uuid NOT NULL,
  sequence bigint NOT NULL,
  tracking_entitlement_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.current_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.current_positions FORCE ROW LEVEL SECURITY;

-- Raw high-volume samples; production time partitions and short retention policy required.
CREATE TABLE rounds.location_samples (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  device_id uuid NOT NULL,
  sample_sequence bigint NOT NULL,
  point geography(Point,4326) NOT NULL,
  observed_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL,
  accuracy_m numeric NOT NULL CHECK (accuracy_m>=0),
  tracking_entitlement_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (device_id, sample_sequence, observed_at)
);
ALTER TABLE rounds.location_samples ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.location_samples FORCE ROW LEVEL SECURITY;

-- Derived Rounds-owned actual trail and quality record where retention permits.
CREATE TABLE rounds.route_trails (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  driver_id uuid NOT NULL,
  round_id uuid,
  trip_id uuid,
  trail geography(LineString,4326),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  quality jsonb NOT NULL,
  purge_after timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.route_trails ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.route_trails FORCE ROW LEVEL SECURITY;

-- Server command dedupe/state; scope_key computed from authenticated actor plus tenant.
CREATE TABLE rounds.command_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope_key text NOT NULL,
  actor_id uuid NOT NULL,
  tenant_id uuid,
  city_id uuid,
  command_key uuid NOT NULL,
  command_type text NOT NULL,
  request_hash text NOT NULL,
  authorization_round_id uuid,
  authorization_assignment_id uuid,
  state text NOT NULL CHECK (state IN ('in_progress','queued','committed','rejected','retained_for_review')),
  result jsonb,
  error_code text,
  started_at timestamptz NOT NULL,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (scope_key, command_key),
  CHECK (city_id IS NULL OR tenant_id IS NOT NULL),
  CHECK ((authorization_round_id IS NULL) = (authorization_assignment_id IS NULL))
);
ALTER TABLE rounds.command_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.command_receipts FORCE ROW LEVEL SECURITY;

-- Append-only authoritative facts plus aggregate version and cause identity.
CREATE TABLE rounds.domain_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  aggregate_type text NOT NULL,
  aggregate_id uuid NOT NULL,
  aggregate_version bigint NOT NULL,
  event_type text NOT NULL,
  schema_version integer NOT NULL,
  actor_id uuid,
  command_id uuid NOT NULL,
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL,
  payload jsonb NOT NULL,
  trace_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, aggregate_type, aggregate_id, aggregate_version, event_type)
);
ALTER TABLE rounds.domain_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.domain_events FORCE ROW LEVEL SECURITY;

-- Transactional enqueue intention, retried until acknowledged; no external call in transaction.
CREATE TABLE rounds.outbox_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  event_id uuid NOT NULL,
  destination text NOT NULL,
  state text NOT NULL CHECK (state IN ('queued','sending','delivered','retry','failed')),
  available_at timestamptz NOT NULL,
  attempt_count integer NOT NULL DEFAULT 0,
  last_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id, event_id, destination)
);
ALTER TABLE rounds.outbox_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.outbox_events FORCE ROW LEVEL SECURITY;

-- Durable scheduled job state; pgmq contains IDs, not sensitive payload copies.
CREATE TABLE rounds.job_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_kind text NOT NULL,
  tenant_id uuid,
  dedupe_key text NOT NULL UNIQUE,
  state text NOT NULL CHECK (state IN ('queued','running','retry','completed','failed','cancelled')),
  available_at timestamptz NOT NULL,
  lease_until timestamptz,
  attempt_count integer NOT NULL DEFAULT 0,
  payload_reference text,
  last_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz
);
ALTER TABLE rounds.job_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.job_runs FORCE ROW LEVEL SECURITY;

-- Idempotent event/job consumer effect receipt; tenant check still required.
CREATE TABLE rounds.consumer_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consumer_key text NOT NULL,
  event_id uuid NOT NULL,
  effect_key text NOT NULL,
  completed_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (consumer_key, event_id, effect_key)
);
ALTER TABLE rounds.consumer_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.consumer_receipts FORCE ROW LEVEL SECURITY;

-- Privileged sensitive read/export/access provenance.
CREATE TABLE rounds.audit_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  actor_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  purpose text NOT NULL,
  occurred_at timestamptz NOT NULL,
  trace_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.audit_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.audit_access FORCE ROW LEVEL SECURITY;

-- Asynchronous scoped history/subject export and signed download lifecycle.
CREATE TABLE rounds.export_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  requested_by uuid NOT NULL,
  kind text NOT NULL,
  filters jsonb NOT NULL,
  as_of_at timestamptz NOT NULL,
  state text NOT NULL CHECK (state IN ('queued','running','ready','failed','expired')),
  asset_id uuid,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.export_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.export_jobs FORCE ROW LEVEL SECURITY;

-- Access/deletion workflow with verified subject scope and retention/legal hold checks.
CREATE TABLE rounds.privacy_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  requested_by uuid NOT NULL,
  subject_reference text NOT NULL,
  kind text NOT NULL,
  state text NOT NULL CHECK (state IN ('requested','reviewing','approved','rejected','executing','completed','held')),
  due_at timestamptz,
  decision jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.privacy_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.privacy_requests FORCE ROW LEVEL SECURITY;

-- Preserve selected evidence for incident/dispute without disabling all purges.
CREATE TABLE rounds.retention_holds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  reason_code text NOT NULL,
  authorized_by uuid NOT NULL,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.retention_holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.retention_holds FORCE ROW LEVEL SECURITY;

-- Single current admission pointer per template/date; lock this row while resolving revisions and reserving capacity. Old occurrences remain promise evidence.
CREATE TABLE rounds.slot_occurrence_bindings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  template_id uuid NOT NULL,
  service_date date NOT NULL,
  occurrence_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE (tenant_id,template_id,service_date)
);
ALTER TABLE rounds.slot_occurrence_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.slot_occurrence_bindings FORCE ROW LEVEL SECURITY;

-- Private account/driver events for commands without a tenant; never publish into a merchant channel.
CREATE TABLE rounds.account_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  principal_id uuid NOT NULL,
  aggregate_type text NOT NULL,
  aggregate_id uuid NOT NULL,
  aggregate_version bigint NOT NULL,
  event_type text NOT NULL,
  schema_version integer NOT NULL,
  actor_id uuid,
  command_id uuid NOT NULL,
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL,
  payload jsonb NOT NULL,
  trace_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (principal_id,aggregate_type,aggregate_id,aggregate_version,event_type)
);
ALTER TABLE rounds.account_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.account_events FORCE ROW LEVEL SECURITY;

-- Durable private account event delivery; separate from tenant outbox.
CREATE TABLE rounds.account_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL,
  destination text NOT NULL,
  state text NOT NULL CHECK (state IN ('queued','sending','delivered','retry','failed')),
  available_at timestamptz NOT NULL,
  attempt_count integer NOT NULL DEFAULT 0,
  last_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (event_id,destination)
);
ALTER TABLE rounds.account_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.account_outbox FORCE ROW LEVEL SECURITY;

-- V2 custodians; see owning command and state contracts.
CREATE TABLE rounds.custodians (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  kind text NOT NULL,
  principal_id uuid,
  site_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  CHECK ((kind='principal' AND principal_id IS NOT NULL AND site_id IS NULL) OR (kind='site' AND site_id IS NOT NULL AND principal_id IS NULL)),
  UNIQUE (tenant_id,principal_id),
  UNIQUE (tenant_id,site_id)
);
ALTER TABLE rounds.custodians ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.custodians FORCE ROW LEVEL SECURITY;

-- V2 custody transfers; see owning command and state contracts.
CREATE TABLE rounds.custody_transfers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  manifest_id uuid NOT NULL,
  from_custodian_id uuid NOT NULL,
  to_custodian_id uuid NOT NULL,
  initiated_by uuid NOT NULL,
  received_by uuid,
  state text NOT NULL CHECK (state IN ('pending','partially_received','received','declined','cancelled','expired')),
  expires_at timestamptz NOT NULL,
  received_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  CHECK (from_custodian_id<>to_custodian_id)
);
ALTER TABLE rounds.custody_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.custody_transfers FORCE ROW LEVEL SECURITY;

-- V2 custody transfer lines; see owning command and state contracts.
CREATE TABLE rounds.custody_transfer_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  transfer_id uuid NOT NULL,
  line_id uuid NOT NULL,
  requested_quantity numeric(18,4) NOT NULL CHECK(requested_quantity>0),
  received_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(received_quantity>=0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE(tenant_id,transfer_id,line_id),
  CHECK(received_quantity<=requested_quantity)
);
ALTER TABLE rounds.custody_transfer_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.custody_transfer_lines FORCE ROW LEVEL SECURITY;

-- V2 return task lines; see owning command and state contracts.
CREATE TABLE rounds.return_task_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  return_task_id uuid NOT NULL,
  line_id uuid NOT NULL,
  expected_quantity numeric(18,4) NOT NULL CHECK(expected_quantity>0),
  received_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(received_quantity>=0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE(tenant_id,return_task_id,line_id),
  CHECK(received_quantity<=expected_quantity)
);
ALTER TABLE rounds.return_task_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.return_task_lines FORCE ROW LEVEL SECURITY;

-- V2 trip booking lines; see owning command and state contracts.
CREATE TABLE rounds.trip_booking_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  trip_booking_id uuid NOT NULL,
  line_id uuid NOT NULL,
  expected_quantity numeric(18,4) NOT NULL CHECK(expected_quantity>0),
  received_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(received_quantity>=0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE(tenant_id,trip_booking_id,line_id),
  CHECK(received_quantity<=expected_quantity)
);
ALTER TABLE rounds.trip_booking_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.trip_booking_lines FORCE ROW LEVEL SECURITY;

-- V2 remaining obligations; see owning command and state contracts.
CREATE TABLE rounds.remaining_obligations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid NOT NULL,
  manifest_id uuid NOT NULL,
  decision_id uuid NOT NULL,
  state text NOT NULL CHECK (state IN ('open','planned','resolved','cancelled')),
  destination_site_id uuid,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id)
);
ALTER TABLE rounds.remaining_obligations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.remaining_obligations FORCE ROW LEVEL SECURITY;

-- V2 remaining obligation lines; see owning command and state contracts.
CREATE TABLE rounds.remaining_obligation_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  obligation_id uuid NOT NULL,
  line_id uuid NOT NULL,
  quantity numeric(18,4) NOT NULL CHECK(quantity>0),
  resolved_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(resolved_quantity>=0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE(tenant_id,obligation_id,line_id),
  CHECK(resolved_quantity<=quantity)
);
ALTER TABLE rounds.remaining_obligation_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.remaining_obligation_lines FORCE ROW LEVEL SECURITY;

-- V2 inbound dependencies; see owning command and state contracts.
CREATE TABLE rounds.inbound_dependencies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  delivery_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  destination_site_id uuid NOT NULL,
  state text NOT NULL CHECK (state IN ('awaiting_receipt','partial','ready','discrepancy','cancelled')),
  expected_available_at timestamptz,
  last_receipt_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE(tenant_id,delivery_id,booking_id)
);
ALTER TABLE rounds.inbound_dependencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.inbound_dependencies FORCE ROW LEVEL SECURITY;

-- V2 realtime grants; see owning command and state contracts.
CREATE TABLE rounds.realtime_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),
  principal_id uuid NOT NULL,
  topic text NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1 CHECK (version>0),
  archived_at timestamptz,
  UNIQUE (tenant_id, id),
  UNIQUE(tenant_id,principal_id,topic)
);
ALTER TABLE rounds.realtime_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.realtime_grants FORCE ROW LEVEL SECURITY;
ALTER TABLE rounds.memberships ADD FOREIGN KEY (principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.memberships (principal_id);
ALTER TABLE rounds.city_grants ADD FOREIGN KEY (tenant_id, membership_id) REFERENCES rounds.memberships(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.city_grants (tenant_id, membership_id);
ALTER TABLE rounds.city_grants ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.city_grants (tenant_id, city_id);
ALTER TABLE rounds.sites ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.sites (tenant_id, city_id);
ALTER TABLE rounds.sites ADD FOREIGN KEY (contact_principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.sites (contact_principal_id);
ALTER TABLE rounds.policy_versions ADD FOREIGN KEY (created_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.policy_versions (created_by);
ALTER TABLE rounds.policy_bindings ADD FOREIGN KEY (tenant_id, policy_version_id) REFERENCES rounds.policy_versions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.policy_bindings (tenant_id, policy_version_id);
ALTER TABLE rounds.drivers ADD FOREIGN KEY (principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.drivers (principal_id);
ALTER TABLE rounds.driver_relationships ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.driver_relationships (driver_id);
ALTER TABLE rounds.invitations ADD FOREIGN KEY (used_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.invitations (used_by);
ALTER TABLE rounds.driver_contact_permissions ADD FOREIGN KEY (tenant_id, relationship_id) REFERENCES rounds.driver_relationships(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.driver_contact_permissions (tenant_id, relationship_id);
ALTER TABLE rounds.driver_contact_permissions ADD FOREIGN KEY (changed_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.driver_contact_permissions (changed_by);
ALTER TABLE rounds.driver_devices ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.driver_devices (driver_id);
ALTER TABLE rounds.onboarding_drafts ADD FOREIGN KEY (principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.onboarding_drafts (principal_id);
ALTER TABLE rounds.verification_applications ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.verification_applications (driver_id);
ALTER TABLE rounds.verification_evidence ADD FOREIGN KEY (application_id) REFERENCES rounds.verification_applications(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.verification_evidence (application_id);
ALTER TABLE rounds.verification_evidence ADD FOREIGN KEY (replaces_id) REFERENCES rounds.verification_evidence(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.verification_evidence (replaces_id);
ALTER TABLE rounds.payout_methods ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.payout_methods (driver_id);
ALTER TABLE rounds.availability_declarations ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.availability_declarations (driver_id);
ALTER TABLE rounds.availability_requests ADD FOREIGN KEY (tenant_id, relationship_id) REFERENCES rounds.driver_relationships(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.availability_requests (tenant_id, relationship_id);
ALTER TABLE rounds.vehicle_profiles ADD FOREIGN KEY (vehicle_type_id) REFERENCES rounds.vehicle_types(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.vehicle_profiles (vehicle_type_id);
ALTER TABLE rounds.profile_cargo_limits ADD FOREIGN KEY (tenant_id, profile_id) REFERENCES rounds.vehicle_profiles(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.profile_cargo_limits (tenant_id, profile_id);
ALTER TABLE rounds.profile_cargo_limits ADD FOREIGN KEY (tenant_id, cargo_class_id) REFERENCES rounds.cargo_classes(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.profile_cargo_limits (tenant_id, cargo_class_id);
ALTER TABLE rounds.handling_rules ADD FOREIGN KEY (tenant_id, profile_id) REFERENCES rounds.vehicle_profiles(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.handling_rules (tenant_id, profile_id);
ALTER TABLE rounds.vehicles ADD FOREIGN KEY (vehicle_type_id) REFERENCES rounds.vehicle_types(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.vehicles (vehicle_type_id);
ALTER TABLE rounds.vehicles ADD FOREIGN KEY (tenant_id, profile_id) REFERENCES rounds.vehicle_profiles(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.vehicles (tenant_id, profile_id);
ALTER TABLE rounds.freelance_vehicles ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.freelance_vehicles (driver_id);
ALTER TABLE rounds.freelance_vehicles ADD FOREIGN KEY (vehicle_type_id) REFERENCES rounds.vehicle_types(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.freelance_vehicles (vehicle_type_id);
ALTER TABLE rounds.shift_templates ADD FOREIGN KEY (tenant_id, relationship_id) REFERENCES rounds.driver_relationships(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.shift_templates (tenant_id, relationship_id);
ALTER TABLE rounds.shift_templates ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.shift_templates (tenant_id, city_id);
ALTER TABLE rounds.shift_templates ADD FOREIGN KEY (tenant_id, vehicle_id) REFERENCES rounds.vehicles(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.shift_templates (tenant_id, vehicle_id);
ALTER TABLE rounds.shift_occurrences ADD FOREIGN KEY (tenant_id, template_id) REFERENCES rounds.shift_templates(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.shift_occurrences (tenant_id, template_id);
ALTER TABLE rounds.shift_occurrences ADD FOREIGN KEY (tenant_id, relationship_id) REFERENCES rounds.driver_relationships(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.shift_occurrences (tenant_id, relationship_id);
ALTER TABLE rounds.shift_occurrences ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.shift_occurrences (tenant_id, city_id);
ALTER TABLE rounds.shift_occurrences ADD FOREIGN KEY (tenant_id, vehicle_id) REFERENCES rounds.vehicles(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.shift_occurrences (tenant_id, vehicle_id);
ALTER TABLE rounds.attendance_events ADD FOREIGN KEY (tenant_id, shift_id) REFERENCES rounds.shift_occurrences(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.attendance_events (tenant_id, shift_id);
ALTER TABLE rounds.attendance_events ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.attendance_events (driver_id);
ALTER TABLE rounds.attendance_events ADD FOREIGN KEY (actor_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.attendance_events (actor_id);
ALTER TABLE rounds.attendance_events ADD FOREIGN KEY (tenant_id, corrects_event_id) REFERENCES rounds.attendance_events(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.attendance_events (tenant_id, corrects_event_id);
ALTER TABLE rounds.slot_templates ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_templates (tenant_id, city_id);
ALTER TABLE rounds.slot_templates ADD FOREIGN KEY (tenant_id, site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_templates (tenant_id, site_id);
ALTER TABLE rounds.slot_templates ADD FOREIGN KEY (tenant_id, brand_id) REFERENCES rounds.brands(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_templates (tenant_id, brand_id);
ALTER TABLE rounds.slot_template_versions ADD FOREIGN KEY (tenant_id, template_id) REFERENCES rounds.slot_templates(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_template_versions (tenant_id, template_id);
ALTER TABLE rounds.slot_template_versions ADD FOREIGN KEY (tenant_id, policy_version_id) REFERENCES rounds.policy_versions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_template_versions (tenant_id, policy_version_id);
ALTER TABLE rounds.slot_overrides ADD FOREIGN KEY (tenant_id, template_id) REFERENCES rounds.slot_templates(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_overrides (tenant_id, template_id);
ALTER TABLE rounds.slot_overrides ADD FOREIGN KEY (created_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_overrides (created_by);
ALTER TABLE rounds.slot_occurrences ADD FOREIGN KEY (tenant_id, template_version_id) REFERENCES rounds.slot_template_versions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_occurrences (tenant_id, template_version_id);
ALTER TABLE rounds.slot_occurrences ADD FOREIGN KEY (tenant_id, override_id) REFERENCES rounds.slot_overrides(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_occurrences (tenant_id, override_id);
ALTER TABLE rounds.slot_occurrences ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_occurrences (tenant_id, city_id);
ALTER TABLE rounds.slot_reservations ADD FOREIGN KEY (tenant_id, occurrence_id) REFERENCES rounds.slot_occurrences(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_reservations (tenant_id, occurrence_id);
ALTER TABLE rounds.slot_reservations ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_reservations (tenant_id, delivery_id);
ALTER TABLE rounds.slot_reservations ADD FOREIGN KEY (tenant_id, draft_id) REFERENCES rounds.intake_drafts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_reservations (tenant_id, draft_id);
ALTER TABLE rounds.source_connections ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.source_connections (tenant_id, city_id);
ALTER TABLE rounds.source_connections ADD FOREIGN KEY (tenant_id, site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.source_connections (tenant_id, site_id);
ALTER TABLE rounds.source_connections ADD FOREIGN KEY (tenant_id, brand_id) REFERENCES rounds.brands(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.source_connections (tenant_id, brand_id);
ALTER TABLE rounds.source_events ADD FOREIGN KEY (tenant_id, connection_id) REFERENCES rounds.source_connections(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.source_events (tenant_id, connection_id);
ALTER TABLE rounds.source_events ADD FOREIGN KEY (reviewed_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.source_events (reviewed_by);
ALTER TABLE rounds.intake_batches ADD FOREIGN KEY (created_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.intake_batches (created_by);
ALTER TABLE rounds.intake_batches ADD FOREIGN KEY (tenant_id, source_asset_id) REFERENCES rounds.assets(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.intake_batches (tenant_id, source_asset_id);
ALTER TABLE rounds.intake_drafts ADD FOREIGN KEY (tenant_id, batch_id) REFERENCES rounds.intake_batches(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.intake_drafts (tenant_id, batch_id);
ALTER TABLE rounds.intake_drafts ADD FOREIGN KEY (tenant_id, connection_id) REFERENCES rounds.source_connections(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.intake_drafts (tenant_id, connection_id);
ALTER TABLE rounds.intake_drafts ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.intake_drafts (tenant_id, city_id);
ALTER TABLE rounds.intake_drafts ADD FOREIGN KEY (created_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.intake_drafts (created_by);
ALTER TABLE rounds.address_suggestions ADD FOREIGN KEY (tenant_id, draft_id) REFERENCES rounds.intake_drafts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.address_suggestions (tenant_id, draft_id);
ALTER TABLE rounds.address_suggestions ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.address_suggestions (tenant_id, delivery_id);
ALTER TABLE rounds.address_suggestions ADD FOREIGN KEY (reviewed_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.address_suggestions (reviewed_by);
ALTER TABLE rounds.entrances ADD FOREIGN KEY (tenant_id, site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.entrances (tenant_id, site_id);
ALTER TABLE rounds.entrances ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.entrances (tenant_id, city_id);
ALTER TABLE rounds.entrance_revisions ADD FOREIGN KEY (tenant_id, entrance_id) REFERENCES rounds.entrances(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.entrance_revisions (tenant_id, entrance_id);
ALTER TABLE rounds.entrance_revisions ADD FOREIGN KEY (confirmed_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.entrance_revisions (confirmed_by);
ALTER TABLE rounds.location_observations ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.location_observations (tenant_id, delivery_id);
ALTER TABLE rounds.location_observations ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.location_observations (driver_id);
ALTER TABLE rounds.location_observations ADD FOREIGN KEY (tenant_id, reviewed_revision_id) REFERENCES rounds.entrance_revisions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.location_observations (tenant_id, reviewed_revision_id);
ALTER TABLE rounds.deliveries ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.deliveries (tenant_id, city_id);
ALTER TABLE rounds.deliveries ADD FOREIGN KEY (tenant_id, brand_id) REFERENCES rounds.brands(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.deliveries (tenant_id, brand_id);
ALTER TABLE rounds.deliveries ADD FOREIGN KEY (tenant_id, pickup_site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.deliveries (tenant_id, pickup_site_id);
ALTER TABLE rounds.deliveries ADD FOREIGN KEY (tenant_id, source_connection_id) REFERENCES rounds.source_connections(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.deliveries (tenant_id, source_connection_id);
ALTER TABLE rounds.deliveries ADD FOREIGN KEY (tenant_id, slot_occurrence_id) REFERENCES rounds.slot_occurrences(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.deliveries (tenant_id, slot_occurrence_id);
ALTER TABLE rounds.deliveries ADD FOREIGN KEY (tenant_id, entrance_revision_id) REFERENCES rounds.entrance_revisions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.deliveries (tenant_id, entrance_revision_id);
ALTER TABLE rounds.deliveries ADD FOREIGN KEY (tenant_id, current_manifest_id) REFERENCES rounds.manifests(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.deliveries (tenant_id, current_manifest_id);
ALTER TABLE rounds.deliveries ADD FOREIGN KEY (tenant_id, proof_policy_id) REFERENCES rounds.policy_versions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.deliveries (tenant_id, proof_policy_id);
ALTER TABLE rounds.deliveries ADD FOREIGN KEY (created_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.deliveries (created_by);
ALTER TABLE rounds.deliveries ADD FOREIGN KEY (ready_declared_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.deliveries (ready_declared_by);
ALTER TABLE rounds.delivery_contacts ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.delivery_contacts (tenant_id, delivery_id);
ALTER TABLE rounds.manifests ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.manifests (tenant_id, delivery_id);
ALTER TABLE rounds.manifest_lines ADD FOREIGN KEY (tenant_id, manifest_id) REFERENCES rounds.manifests(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.manifest_lines (tenant_id, manifest_id);
ALTER TABLE rounds.manifest_lines ADD FOREIGN KEY (tenant_id, cargo_class_id) REFERENCES rounds.cargo_classes(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.manifest_lines (tenant_id, cargo_class_id);
ALTER TABLE rounds.packages ADD FOREIGN KEY (tenant_id, manifest_id) REFERENCES rounds.manifests(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.packages (tenant_id, manifest_id);
ALTER TABLE rounds.package_contents ADD FOREIGN KEY (tenant_id, package_id) REFERENCES rounds.packages(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.package_contents (tenant_id, package_id);
ALTER TABLE rounds.package_contents ADD FOREIGN KEY (tenant_id, line_id) REFERENCES rounds.manifest_lines(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.package_contents (tenant_id, line_id);
ALTER TABLE rounds.plans ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.plans (tenant_id, city_id);
ALTER TABLE rounds.plans ADD FOREIGN KEY (created_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.plans (created_by);
ALTER TABLE rounds.plan_proposals ADD FOREIGN KEY (tenant_id, plan_id) REFERENCES rounds.plans(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.plan_proposals (tenant_id, plan_id);
ALTER TABLE rounds.plan_releases ADD FOREIGN KEY (tenant_id, plan_id) REFERENCES rounds.plans(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.plan_releases (tenant_id, plan_id);
ALTER TABLE rounds.plan_releases ADD FOREIGN KEY (tenant_id, proposal_id) REFERENCES rounds.plan_proposals(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.plan_releases (tenant_id, proposal_id);
ALTER TABLE rounds.plan_releases ADD FOREIGN KEY (released_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.plan_releases (released_by);
ALTER TABLE rounds.rounds ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.rounds (tenant_id, city_id);
ALTER TABLE rounds.rounds ADD FOREIGN KEY (tenant_id, pickup_site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.rounds (tenant_id, pickup_site_id);
ALTER TABLE rounds.rounds ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.rounds (driver_id);
ALTER TABLE rounds.rounds ADD FOREIGN KEY (tenant_id, vehicle_id) REFERENCES rounds.vehicles(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.rounds (tenant_id, vehicle_id);
ALTER TABLE rounds.rounds ADD FOREIGN KEY (freelance_vehicle_id) REFERENCES rounds.freelance_vehicles(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.rounds (freelance_vehicle_id);
ALTER TABLE rounds.rounds ADD FOREIGN KEY (tenant_id, release_id) REFERENCES rounds.plan_releases(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.rounds (tenant_id, release_id);
ALTER TABLE rounds.rounds ADD FOREIGN KEY (tenant_id, policy_version_id) REFERENCES rounds.policy_versions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.rounds (tenant_id, policy_version_id);
ALTER TABLE rounds.stops ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.stops (tenant_id, round_id);
ALTER TABLE rounds.stops ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.stops (tenant_id, delivery_id);
ALTER TABLE rounds.assignments ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.assignments (tenant_id, round_id);
ALTER TABLE rounds.assignments ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.assignments (driver_id);
ALTER TABLE rounds.assignments ADD FOREIGN KEY (tenant_id, release_id) REFERENCES rounds.plan_releases(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.assignments (tenant_id, release_id);
ALTER TABLE rounds.driver_commitments ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.driver_commitments (driver_id);
ALTER TABLE rounds.driver_commitments ADD FOREIGN KEY (tenant_id) REFERENCES rounds.tenants(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.driver_commitments (tenant_id);
ALTER TABLE rounds.active_delivery_claims ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.active_delivery_claims (tenant_id, delivery_id);
ALTER TABLE rounds.active_delivery_claims ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.active_delivery_claims (tenant_id, round_id);
ALTER TABLE rounds.active_delivery_claims ADD FOREIGN KEY (tenant_id, broadcast_id) REFERENCES rounds.broadcasts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.active_delivery_claims (tenant_id, broadcast_id);
ALTER TABLE rounds.delivery_attempts ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.delivery_attempts (tenant_id, delivery_id);
ALTER TABLE rounds.delivery_attempts ADD FOREIGN KEY (tenant_id, stop_id) REFERENCES rounds.stops(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.delivery_attempts (tenant_id, stop_id);
ALTER TABLE rounds.delivery_attempts ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.delivery_attempts (driver_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (tenant_id, manifest_id) REFERENCES rounds.manifests(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (tenant_id, manifest_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (tenant_id, attempt_id) REFERENCES rounds.delivery_attempts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (tenant_id, attempt_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (tenant_id, trip_id) REFERENCES rounds.transport_trips(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (tenant_id, trip_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (from_principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (from_principal_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (to_principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (to_principal_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (tenant_id, site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (tenant_id, site_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (actor_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (actor_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (tenant_id, round_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (tenant_id, stop_id) REFERENCES rounds.stops(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (tenant_id, stop_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (tenant_id, from_custodian_id) REFERENCES rounds.custodians(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (tenant_id, from_custodian_id);
ALTER TABLE rounds.custody_events ADD FOREIGN KEY (tenant_id, to_custodian_id) REFERENCES rounds.custodians(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_events (tenant_id, to_custodian_id);
ALTER TABLE rounds.custody_event_lines ADD FOREIGN KEY (tenant_id, event_id) REFERENCES rounds.custody_events(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_event_lines (tenant_id, event_id);
ALTER TABLE rounds.custody_event_lines ADD FOREIGN KEY (tenant_id, line_id) REFERENCES rounds.manifest_lines(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_event_lines (tenant_id, line_id);
ALTER TABLE rounds.custody_balances ADD FOREIGN KEY (tenant_id, line_id) REFERENCES rounds.manifest_lines(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_balances (tenant_id, line_id);
ALTER TABLE rounds.custody_balances ADD FOREIGN KEY (tenant_id, last_event_id) REFERENCES rounds.custody_events(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_balances (tenant_id, last_event_id);
ALTER TABLE rounds.custody_balances ADD FOREIGN KEY (tenant_id, custodian_id) REFERENCES rounds.custodians(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_balances (tenant_id, custodian_id);
ALTER TABLE rounds.handoffs ADD FOREIGN KEY (tenant_id, attempt_id) REFERENCES rounds.delivery_attempts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.handoffs (tenant_id, attempt_id);
ALTER TABLE rounds.handoffs ADD FOREIGN KEY (tenant_id, receiver_contact_id) REFERENCES rounds.delivery_contacts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.handoffs (tenant_id, receiver_contact_id);
ALTER TABLE rounds.handoffs ADD FOREIGN KEY (actor_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.handoffs (actor_id);
ALTER TABLE rounds.handoffs ADD FOREIGN KEY (tenant_id, proof_policy_id) REFERENCES rounds.policy_versions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.handoffs (tenant_id, proof_policy_id);
ALTER TABLE rounds.assets ADD FOREIGN KEY (created_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.assets (created_by);
ALTER TABLE rounds.proof_submissions ADD FOREIGN KEY (tenant_id, attempt_id) REFERENCES rounds.delivery_attempts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.proof_submissions (tenant_id, attempt_id);
ALTER TABLE rounds.proof_submissions ADD FOREIGN KEY (tenant_id, handoff_id) REFERENCES rounds.handoffs(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.proof_submissions (tenant_id, handoff_id);
ALTER TABLE rounds.proof_submissions ADD FOREIGN KEY (tenant_id, policy_version_id) REFERENCES rounds.policy_versions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.proof_submissions (tenant_id, policy_version_id);
ALTER TABLE rounds.proof_submissions ADD FOREIGN KEY (submitted_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.proof_submissions (submitted_by);
ALTER TABLE rounds.proof_items ADD FOREIGN KEY (tenant_id, submission_id) REFERENCES rounds.proof_submissions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.proof_items (tenant_id, submission_id);
ALTER TABLE rounds.proof_items ADD FOREIGN KEY (tenant_id, asset_id) REFERENCES rounds.assets(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.proof_items (tenant_id, asset_id);
ALTER TABLE rounds.proof_items ADD FOREIGN KEY (tenant_id, line_id) REFERENCES rounds.manifest_lines(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.proof_items (tenant_id, line_id);
ALTER TABLE rounds.proof_items ADD FOREIGN KEY (tenant_id, receiver_contact_id) REFERENCES rounds.delivery_contacts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.proof_items (tenant_id, receiver_contact_id);
ALTER TABLE rounds.proof_items ADD CONSTRAINT proof_item_location_observation_fk FOREIGN KEY (tenant_id,location_observation_id) REFERENCES rounds.location_observations(tenant_id,id);
ALTER TABLE rounds.issues ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.issues (tenant_id, delivery_id);
ALTER TABLE rounds.issues ADD FOREIGN KEY (tenant_id, attempt_id) REFERENCES rounds.delivery_attempts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.issues (tenant_id, attempt_id);
ALTER TABLE rounds.issues ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.issues (tenant_id, round_id);
ALTER TABLE rounds.issues ADD FOREIGN KEY (tenant_id, trip_id) REFERENCES rounds.transport_trips(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.issues (tenant_id, trip_id);
ALTER TABLE rounds.issues ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.issues (driver_id);
ALTER TABLE rounds.issues ADD FOREIGN KEY (reported_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.issues (reported_by);
ALTER TABLE rounds.issue_decisions ADD FOREIGN KEY (tenant_id, issue_id) REFERENCES rounds.issues(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.issue_decisions (tenant_id, issue_id);
ALTER TABLE rounds.issue_decisions ADD FOREIGN KEY (decided_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.issue_decisions (decided_by);
ALTER TABLE rounds.issue_decisions ADD FOREIGN KEY (tenant_id, supersedes_id) REFERENCES rounds.issue_decisions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.issue_decisions (tenant_id, supersedes_id);
ALTER TABLE rounds.return_tasks ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.return_tasks (tenant_id, delivery_id);
ALTER TABLE rounds.return_tasks ADD FOREIGN KEY (tenant_id, manifest_id) REFERENCES rounds.manifests(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.return_tasks (tenant_id, manifest_id);
ALTER TABLE rounds.return_tasks ADD FOREIGN KEY (tenant_id, origin_issue_id) REFERENCES rounds.issues(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.return_tasks (tenant_id, origin_issue_id);
ALTER TABLE rounds.return_tasks ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.return_tasks (tenant_id, round_id);
ALTER TABLE rounds.return_tasks ADD FOREIGN KEY (tenant_id, destination_site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.return_tasks (tenant_id, destination_site_id);
ALTER TABLE rounds.return_tasks ADD FOREIGN KEY (tenant_id, agreement_id) REFERENCES rounds.freelance_agreements(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.return_tasks (tenant_id, agreement_id);
ALTER TABLE rounds.return_tasks ADD FOREIGN KEY (tenant_id, custodian_id) REFERENCES rounds.custodians(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.return_tasks (tenant_id, custodian_id);
ALTER TABLE rounds.return_tasks ADD FOREIGN KEY (receiver_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.return_tasks (receiver_id);
ALTER TABLE rounds.change_proposals ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.change_proposals (tenant_id, round_id);
ALTER TABLE rounds.change_proposals ADD FOREIGN KEY (tenant_id, agreement_id) REFERENCES rounds.freelance_agreements(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.change_proposals (tenant_id, agreement_id);
ALTER TABLE rounds.change_proposals ADD FOREIGN KEY (created_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.change_proposals (created_by);
ALTER TABLE rounds.change_responses ADD FOREIGN KEY (tenant_id, proposal_id) REFERENCES rounds.change_proposals(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.change_responses (tenant_id, proposal_id);
ALTER TABLE rounds.change_responses ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.change_responses (driver_id);
ALTER TABLE rounds.broadcasts ADD FOREIGN KEY (tenant_id, city_id) REFERENCES rounds.cities(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.broadcasts (tenant_id, city_id);
ALTER TABLE rounds.broadcasts ADD FOREIGN KEY (tenant_id, pickup_site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.broadcasts (tenant_id, pickup_site_id);
ALTER TABLE rounds.broadcasts ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.broadcasts (tenant_id, round_id);
ALTER TABLE rounds.broadcasts ADD FOREIGN KEY (tenant_id, search_policy_id) REFERENCES rounds.policy_versions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.broadcasts (tenant_id, search_policy_id);
ALTER TABLE rounds.broadcasts ADD FOREIGN KEY (started_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.broadcasts (started_by);
ALTER TABLE rounds.broadcast_waves ADD FOREIGN KEY (tenant_id, broadcast_id) REFERENCES rounds.broadcasts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.broadcast_waves (tenant_id, broadcast_id);
ALTER TABLE rounds.offers ADD FOREIGN KEY (tenant_id, broadcast_id) REFERENCES rounds.broadcasts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.offers (tenant_id, broadcast_id);
ALTER TABLE rounds.offers ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.offers (driver_id);
ALTER TABLE rounds.freelance_agreements ADD FOREIGN KEY (tenant_id, broadcast_id) REFERENCES rounds.broadcasts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.freelance_agreements (tenant_id, broadcast_id);
ALTER TABLE rounds.freelance_agreements ADD FOREIGN KEY (tenant_id, offer_id) REFERENCES rounds.offers(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.freelance_agreements (tenant_id, offer_id);
ALTER TABLE rounds.freelance_agreements ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.freelance_agreements (tenant_id, round_id);
ALTER TABLE rounds.freelance_agreements ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.freelance_agreements (driver_id);
ALTER TABLE rounds.fare_adjustments ADD FOREIGN KEY (tenant_id, agreement_id) REFERENCES rounds.freelance_agreements(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.fare_adjustments (tenant_id, agreement_id);
ALTER TABLE rounds.fare_adjustments ADD FOREIGN KEY (tenant_id, change_proposal_id) REFERENCES rounds.change_proposals(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.fare_adjustments (tenant_id, change_proposal_id);
ALTER TABLE rounds.settlement_records ADD FOREIGN KEY (tenant_id, agreement_id) REFERENCES rounds.freelance_agreements(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.settlement_records (tenant_id, agreement_id);
ALTER TABLE rounds.settlement_records ADD FOREIGN KEY (tenant_id, proof_asset_id) REFERENCES rounds.assets(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.settlement_records (tenant_id, proof_asset_id);
ALTER TABLE rounds.settlement_events ADD FOREIGN KEY (tenant_id, settlement_id) REFERENCES rounds.settlement_records(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.settlement_events (tenant_id, settlement_id);
ALTER TABLE rounds.settlement_events ADD FOREIGN KEY (actor_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.settlement_events (actor_id);
ALTER TABLE rounds.transport_trips ADD FOREIGN KEY (tenant_id, origin_site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.transport_trips (tenant_id, origin_site_id);
ALTER TABLE rounds.transport_trips ADD FOREIGN KEY (tenant_id, destination_site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.transport_trips (tenant_id, destination_site_id);
ALTER TABLE rounds.transport_trips ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.transport_trips (driver_id);
ALTER TABLE rounds.transport_trips ADD FOREIGN KEY (tenant_id, vehicle_id) REFERENCES rounds.vehicles(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.transport_trips (tenant_id, vehicle_id);
ALTER TABLE rounds.transport_trips ADD FOREIGN KEY (receiving_principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.transport_trips (receiving_principal_id);
ALTER TABLE rounds.trip_bookings ADD FOREIGN KEY (tenant_id, trip_id) REFERENCES rounds.transport_trips(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_bookings (tenant_id, trip_id);
ALTER TABLE rounds.trip_bookings ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_bookings (tenant_id, delivery_id);
ALTER TABLE rounds.trip_bookings ADD FOREIGN KEY (tenant_id, manifest_id) REFERENCES rounds.manifests(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_bookings (tenant_id, manifest_id);
ALTER TABLE rounds.trip_bookings ADD FOREIGN KEY (booked_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_bookings (booked_by);
ALTER TABLE rounds.trip_bookings ADD FOREIGN KEY (tenant_id, custodian_id) REFERENCES rounds.custodians(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_bookings (tenant_id, custodian_id);
ALTER TABLE rounds.trip_bookings ADD FOREIGN KEY (receiver_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_bookings (receiver_id);
ALTER TABLE rounds.trip_receipts ADD FOREIGN KEY (tenant_id, booking_id) REFERENCES rounds.trip_bookings(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_receipts (tenant_id, booking_id);
ALTER TABLE rounds.trip_receipts ADD FOREIGN KEY (receiver_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_receipts (receiver_id);
ALTER TABLE rounds.trip_receipts ADD FOREIGN KEY (tenant_id, custody_event_id) REFERENCES rounds.custody_events(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_receipts (tenant_id, custody_event_id);
ALTER TABLE rounds.conversations ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.conversations (tenant_id, round_id);
ALTER TABLE rounds.conversations ADD FOREIGN KEY (tenant_id, relationship_id) REFERENCES rounds.driver_relationships(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.conversations (tenant_id, relationship_id);
ALTER TABLE rounds.conversations ADD FOREIGN KEY (tenant_id, trip_id) REFERENCES rounds.transport_trips(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.conversations (tenant_id, trip_id);
ALTER TABLE rounds.conversation_participants ADD FOREIGN KEY (tenant_id, conversation_id) REFERENCES rounds.conversations(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.conversation_participants (tenant_id, conversation_id);
ALTER TABLE rounds.conversation_participants ADD FOREIGN KEY (principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.conversation_participants (principal_id);
ALTER TABLE rounds.messages ADD FOREIGN KEY (tenant_id, conversation_id) REFERENCES rounds.conversations(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.messages (tenant_id, conversation_id);
ALTER TABLE rounds.messages ADD FOREIGN KEY (sender_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.messages (sender_id);
ALTER TABLE rounds.message_attachments ADD FOREIGN KEY (tenant_id, message_id) REFERENCES rounds.messages(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.message_attachments (tenant_id, message_id);
ALTER TABLE rounds.message_attachments ADD FOREIGN KEY (tenant_id, asset_id) REFERENCES rounds.assets(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.message_attachments (tenant_id, asset_id);
ALTER TABLE rounds.message_receipts ADD FOREIGN KEY (tenant_id, message_id) REFERENCES rounds.messages(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.message_receipts (tenant_id, message_id);
ALTER TABLE rounds.message_receipts ADD FOREIGN KEY (principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.message_receipts (principal_id);
ALTER TABLE rounds.call_sessions ADD FOREIGN KEY (tenant_id, conversation_id) REFERENCES rounds.conversations(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.call_sessions (tenant_id, conversation_id);
ALTER TABLE rounds.call_sessions ADD FOREIGN KEY (caller_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.call_sessions (caller_id);
ALTER TABLE rounds.call_sessions ADD FOREIGN KEY (callee_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.call_sessions (callee_id);
ALTER TABLE rounds.call_sessions ADD FOREIGN KEY (tenant_id, contact_id) REFERENCES rounds.delivery_contacts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.call_sessions (tenant_id, contact_id);
ALTER TABLE rounds.call_events ADD FOREIGN KEY (tenant_id, call_id) REFERENCES rounds.call_sessions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.call_events (tenant_id, call_id);
ALTER TABLE rounds.call_events ADD FOREIGN KEY (actor_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.call_events (actor_id);
ALTER TABLE rounds.notifications ADD FOREIGN KEY (principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.notifications (principal_id);
ALTER TABLE rounds.customer_tracking_tokens ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.customer_tracking_tokens (tenant_id, delivery_id);
ALTER TABLE rounds.customer_tracking_tokens ADD FOREIGN KEY (tenant_id, policy_version_id) REFERENCES rounds.policy_versions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.customer_tracking_tokens (tenant_id, policy_version_id);
ALTER TABLE rounds.notification_deliveries ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.notification_deliveries (tenant_id, delivery_id);
ALTER TABLE rounds.writeback_tasks ADD FOREIGN KEY (tenant_id, connection_id) REFERENCES rounds.source_connections(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.writeback_tasks (tenant_id, connection_id);
ALTER TABLE rounds.writeback_tasks ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.writeback_tasks (tenant_id, delivery_id);
ALTER TABLE rounds.route_estimates ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.route_estimates (tenant_id, round_id);
ALTER TABLE rounds.route_estimates ADD FOREIGN KEY (tenant_id, trip_id) REFERENCES rounds.transport_trips(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.route_estimates (tenant_id, trip_id);
ALTER TABLE rounds.navigation_intents ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.navigation_intents (driver_id);
ALTER TABLE rounds.navigation_intents ADD FOREIGN KEY (tenant_id, stop_id) REFERENCES rounds.stops(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.navigation_intents (tenant_id, stop_id);
ALTER TABLE rounds.tracking_entitlements ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.tracking_entitlements (driver_id);
ALTER TABLE rounds.tracking_entitlements ADD FOREIGN KEY (tenant_id) REFERENCES rounds.tenants(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.tracking_entitlements (tenant_id);
ALTER TABLE rounds.current_positions ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.current_positions (driver_id);
ALTER TABLE rounds.current_positions ADD FOREIGN KEY (device_id) REFERENCES rounds.driver_devices(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.current_positions (device_id);
ALTER TABLE rounds.current_positions ADD FOREIGN KEY (tracking_entitlement_id) REFERENCES rounds.tracking_entitlements(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.current_positions (tracking_entitlement_id);
ALTER TABLE rounds.location_samples ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.location_samples (driver_id);
ALTER TABLE rounds.location_samples ADD FOREIGN KEY (device_id) REFERENCES rounds.driver_devices(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.location_samples (device_id);
ALTER TABLE rounds.location_samples ADD FOREIGN KEY (tracking_entitlement_id) REFERENCES rounds.tracking_entitlements(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.location_samples (tracking_entitlement_id);
ALTER TABLE rounds.route_trails ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.route_trails (driver_id);
ALTER TABLE rounds.route_trails ADD FOREIGN KEY (tenant_id, round_id) REFERENCES rounds.rounds(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.route_trails (tenant_id, round_id);
ALTER TABLE rounds.route_trails ADD FOREIGN KEY (tenant_id, trip_id) REFERENCES rounds.transport_trips(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.route_trails (tenant_id, trip_id);
ALTER TABLE rounds.command_receipts ADD FOREIGN KEY (actor_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.command_receipts (actor_id);
ALTER TABLE rounds.command_receipts ADD FOREIGN KEY (tenant_id) REFERENCES rounds.tenants(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.command_receipts (tenant_id);
-- v2.3-r1 / 2026-09-08: receipt recovery must preserve original city scope too.
ALTER TABLE rounds.command_receipts ADD FOREIGN KEY (tenant_id,city_id) REFERENCES rounds.cities(tenant_id,id) DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE rounds.domain_events ADD FOREIGN KEY (actor_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.domain_events (actor_id);
ALTER TABLE rounds.outbox_events ADD FOREIGN KEY (tenant_id, event_id) REFERENCES rounds.domain_events(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.outbox_events (tenant_id, event_id);
ALTER TABLE rounds.job_runs ADD FOREIGN KEY (tenant_id) REFERENCES rounds.tenants(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.job_runs (tenant_id);
ALTER TABLE rounds.audit_access ADD FOREIGN KEY (actor_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.audit_access (actor_id);
ALTER TABLE rounds.export_jobs ADD FOREIGN KEY (requested_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.export_jobs (requested_by);
ALTER TABLE rounds.export_jobs ADD FOREIGN KEY (tenant_id, asset_id) REFERENCES rounds.assets(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.export_jobs (tenant_id, asset_id);
ALTER TABLE rounds.privacy_requests ADD FOREIGN KEY (requested_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.privacy_requests (requested_by);
ALTER TABLE rounds.retention_holds ADD FOREIGN KEY (authorized_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.retention_holds (authorized_by);
ALTER TABLE rounds.slot_occurrence_bindings ADD FOREIGN KEY (tenant_id, template_id) REFERENCES rounds.slot_templates(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_occurrence_bindings (tenant_id, template_id);
ALTER TABLE rounds.slot_occurrence_bindings ADD FOREIGN KEY (tenant_id, occurrence_id) REFERENCES rounds.slot_occurrences(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.slot_occurrence_bindings (tenant_id, occurrence_id);
ALTER TABLE rounds.account_events ADD FOREIGN KEY (principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.account_events (principal_id);
ALTER TABLE rounds.account_events ADD FOREIGN KEY (actor_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.account_events (actor_id);
ALTER TABLE rounds.account_outbox ADD FOREIGN KEY (event_id) REFERENCES rounds.account_events(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.account_outbox (event_id);
ALTER TABLE rounds.custodians ADD FOREIGN KEY (principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custodians (principal_id);
ALTER TABLE rounds.custodians ADD FOREIGN KEY (tenant_id, site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custodians (tenant_id, site_id);
ALTER TABLE rounds.custody_transfers ADD FOREIGN KEY (tenant_id, manifest_id) REFERENCES rounds.manifests(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_transfers (tenant_id, manifest_id);
ALTER TABLE rounds.custody_transfers ADD FOREIGN KEY (tenant_id, from_custodian_id) REFERENCES rounds.custodians(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_transfers (tenant_id, from_custodian_id);
ALTER TABLE rounds.custody_transfers ADD FOREIGN KEY (tenant_id, to_custodian_id) REFERENCES rounds.custodians(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_transfers (tenant_id, to_custodian_id);
ALTER TABLE rounds.custody_transfers ADD FOREIGN KEY (initiated_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_transfers (initiated_by);
ALTER TABLE rounds.custody_transfers ADD FOREIGN KEY (received_by) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_transfers (received_by);
ALTER TABLE rounds.custody_transfer_lines ADD FOREIGN KEY (tenant_id, transfer_id) REFERENCES rounds.custody_transfers(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_transfer_lines (tenant_id, transfer_id);
ALTER TABLE rounds.custody_transfer_lines ADD FOREIGN KEY (tenant_id, line_id) REFERENCES rounds.manifest_lines(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.custody_transfer_lines (tenant_id, line_id);
ALTER TABLE rounds.return_task_lines ADD FOREIGN KEY (tenant_id, return_task_id) REFERENCES rounds.return_tasks(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.return_task_lines (tenant_id, return_task_id);
ALTER TABLE rounds.return_task_lines ADD FOREIGN KEY (tenant_id, line_id) REFERENCES rounds.manifest_lines(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.return_task_lines (tenant_id, line_id);
ALTER TABLE rounds.trip_booking_lines ADD FOREIGN KEY (tenant_id, trip_booking_id) REFERENCES rounds.trip_bookings(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_booking_lines (tenant_id, trip_booking_id);
ALTER TABLE rounds.trip_booking_lines ADD FOREIGN KEY (tenant_id, line_id) REFERENCES rounds.manifest_lines(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.trip_booking_lines (tenant_id, line_id);
ALTER TABLE rounds.remaining_obligations ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.remaining_obligations (tenant_id, delivery_id);
ALTER TABLE rounds.remaining_obligations ADD FOREIGN KEY (tenant_id, manifest_id) REFERENCES rounds.manifests(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.remaining_obligations (tenant_id, manifest_id);
ALTER TABLE rounds.remaining_obligations ADD FOREIGN KEY (tenant_id, decision_id) REFERENCES rounds.issue_decisions(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.remaining_obligations (tenant_id, decision_id);
ALTER TABLE rounds.remaining_obligations ADD FOREIGN KEY (tenant_id, destination_site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.remaining_obligations (tenant_id, destination_site_id);
ALTER TABLE rounds.remaining_obligation_lines ADD FOREIGN KEY (tenant_id, obligation_id) REFERENCES rounds.remaining_obligations(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.remaining_obligation_lines (tenant_id, obligation_id);
ALTER TABLE rounds.remaining_obligation_lines ADD FOREIGN KEY (tenant_id, line_id) REFERENCES rounds.manifest_lines(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.remaining_obligation_lines (tenant_id, line_id);
ALTER TABLE rounds.inbound_dependencies ADD FOREIGN KEY (tenant_id, delivery_id) REFERENCES rounds.deliveries(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.inbound_dependencies (tenant_id, delivery_id);
ALTER TABLE rounds.inbound_dependencies ADD FOREIGN KEY (tenant_id, booking_id) REFERENCES rounds.trip_bookings(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.inbound_dependencies (tenant_id, booking_id);
ALTER TABLE rounds.inbound_dependencies ADD FOREIGN KEY (tenant_id, destination_site_id) REFERENCES rounds.sites(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.inbound_dependencies (tenant_id, destination_site_id);
ALTER TABLE rounds.inbound_dependencies ADD FOREIGN KEY (tenant_id, last_receipt_id) REFERENCES rounds.trip_receipts(tenant_id, id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.inbound_dependencies (tenant_id, last_receipt_id);
ALTER TABLE rounds.realtime_grants ADD FOREIGN KEY (principal_id) REFERENCES rounds.principals(id) DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX ON rounds.realtime_grants (principal_id);
ALTER TABLE rounds.driver_commitments ADD FOREIGN KEY (tenant_id,round_id) REFERENCES rounds.rounds(tenant_id,id);
ALTER TABLE rounds.driver_commitments ADD FOREIGN KEY (tenant_id,trip_id) REFERENCES rounds.transport_trips(tenant_id,id);
ALTER TABLE rounds.tracking_entitlements ADD FOREIGN KEY (tenant_id,round_id) REFERENCES rounds.rounds(tenant_id,id);
ALTER TABLE rounds.tracking_entitlements ADD FOREIGN KEY (tenant_id,trip_id) REFERENCES rounds.transport_trips(tenant_id,id);
CREATE UNIQUE INDEX delivery_source_identity ON rounds.deliveries (tenant_id,source_connection_id,source_order_key) WHERE source_connection_id IS NOT NULL AND source_order_key IS NOT NULL;
CREATE INDEX delivery_board ON rounds.deliveries (tenant_id,city_id,service_date,readiness,outcome);
CREATE INDEX stop_round_state ON rounds.stops (tenant_id,round_id,state);
CREATE INDEX position_geo ON rounds.current_positions USING gist(point);
CREATE INDEX sample_driver_time ON rounds.location_samples (driver_id,observed_at DESC);
CREATE INDEX event_aggregate ON rounds.domain_events (tenant_id,aggregate_type,aggregate_id,aggregate_version);
CREATE INDEX job_due ON rounds.job_runs (available_at) WHERE state IN ('queued','retry');
CREATE INDEX offer_driver_deadline ON rounds.offers (driver_id,expires_at) WHERE state='offered';
CREATE INDEX slot_active_capacity ON rounds.slot_reservations (tenant_id,occurrence_id,state,expires_at);
CREATE INDEX message_thread_time ON rounds.messages (tenant_id,conversation_id,created_at,id);
ALTER TABLE rounds.driver_commitments ADD CONSTRAINT no_committed_driver_overlap EXCLUDE USING gist (driver_id WITH =, busy_range WITH &&) WHERE (state='committed') DEFERRABLE INITIALLY IMMEDIATE;
REVOKE ALL ON ALL TABLES IN SCHEMA rounds FROM PUBLIC;
-- No client policies/grants are installed: schema fails closed. API owner role must not be reused as an application role.
-- Authoritative command service sets server-validated tenant/actor context; install restricted role policies only after tenancy tests.

-- V2 physical enforcement
CREATE UNIQUE INDEX one_live_draft_hold ON rounds.slot_reservations(tenant_id,draft_id) WHERE state='held';
CREATE UNIQUE INDEX one_live_delivery_slot ON rounds.slot_reservations(tenant_id,delivery_id) WHERE state IN ('held','committed');
CREATE UNIQUE INDEX one_live_assignment ON rounds.assignments(tenant_id,round_id) WHERE state IN ('issued','received','acknowledged','cannot_comply');
CREATE UNIQUE INDEX one_search_per_round ON rounds.broadcasts(tenant_id,round_id) WHERE state='searching';
CREATE UNIQUE INDEX one_active_agreement ON rounds.freelance_agreements(tenant_id,round_id) WHERE state IN ('active','disputed');
CREATE UNIQUE INDEX one_active_dropoff ON rounds.stops(tenant_id,delivery_id) WHERE kind='dropoff' AND state NOT IN ('completed','failed','cancelled');
CREATE INDEX outbox_poll ON rounds.outbox_events(available_at,id) WHERE state IN ('queued','retry');
CREATE INDEX account_outbox_poll ON rounds.account_outbox(available_at,id) WHERE state IN ('queued','retry');
CREATE INDEX round_board_scope ON rounds.rounds(tenant_id,city_id,service_date);
CREATE INDEX broadcast_scope ON rounds.broadcasts(tenant_id,state,created_at);
CREATE INDEX inbound_delivery_gate ON rounds.inbound_dependencies(tenant_id,delivery_id,state);
CREATE INDEX shift_vehicle_time ON rounds.shift_occurrences(tenant_id,vehicle_id,starts_at,ends_at);
CREATE INDEX grant_principal_topic ON rounds.realtime_grants(principal_id,topic,expires_at) WHERE revoked_at IS NULL;
-- memberships: re-invite reactivates the same identity row with a new invitation/event; it does not insert another row. Historical events retain membership epochs.
-- driver_relationships: re-invite reactivates the same identity row with a new invitation/event; it does not insert another row. Historical events retain membership epochs.
CREATE OR REPLACE FUNCTION rounds.reject_immutable_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'IMMUTABLE_RECORD' USING ERRCODE='23514'; END; $$;
CREATE OR REPLACE FUNCTION rounds.guard_manifest_line() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE sealed timestamptz; parent_id uuid; scope_id uuid;
BEGIN
 parent_id := CASE WHEN TG_OP='INSERT' THEN NEW.manifest_id ELSE OLD.manifest_id END;
 scope_id := CASE WHEN TG_OP='INSERT' THEN NEW.tenant_id ELSE OLD.tenant_id END;
 SELECT sealed_at INTO sealed FROM rounds.manifests WHERE tenant_id=scope_id AND id=parent_id FOR UPDATE;
 IF sealed IS NOT NULL THEN RAISE EXCEPTION 'MANIFEST_SEALED' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' AND (NEW.manifest_id<>OLD.manifest_id OR NEW.tenant_id<>OLD.tenant_id) THEN RAISE EXCEPTION 'MANIFEST_REPARENT_FORBIDDEN'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END; $$;
CREATE TRIGGER sealed_lines BEFORE INSERT OR UPDATE OR DELETE ON rounds.manifest_lines FOR EACH ROW EXECUTE FUNCTION rounds.guard_manifest_line();
CREATE OR REPLACE FUNCTION rounds.guard_manifest_header() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.sealed_at IS NOT NULL THEN RAISE EXCEPTION 'MANIFEST_SEALED' USING ERRCODE='23514'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END; $$;
CREATE TRIGGER sealed_header BEFORE UPDATE OR DELETE ON rounds.manifests FOR EACH ROW EXECUTE FUNCTION rounds.guard_manifest_header();
CREATE TRIGGER immutable_policy_versions BEFORE UPDATE OR DELETE ON rounds.policy_versions FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_usage_ledger BEFORE UPDATE OR DELETE ON rounds.usage_ledger FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_attendance_events BEFORE UPDATE OR DELETE ON rounds.attendance_events FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_slot_template_versions BEFORE UPDATE OR DELETE ON rounds.slot_template_versions FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_entrance_revisions BEFORE UPDATE OR DELETE ON rounds.entrance_revisions FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_plan_proposals BEFORE UPDATE OR DELETE ON rounds.plan_proposals FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_plan_releases BEFORE UPDATE OR DELETE ON rounds.plan_releases FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_custody_events BEFORE UPDATE OR DELETE ON rounds.custody_events FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_custody_event_lines BEFORE UPDATE OR DELETE ON rounds.custody_event_lines FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_issue_decisions BEFORE UPDATE OR DELETE ON rounds.issue_decisions FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_change_responses BEFORE UPDATE OR DELETE ON rounds.change_responses FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_fare_adjustments BEFORE UPDATE OR DELETE ON rounds.fare_adjustments FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_settlement_events BEFORE UPDATE OR DELETE ON rounds.settlement_events FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_trip_receipts BEFORE UPDATE OR DELETE ON rounds.trip_receipts FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_call_events BEFORE UPDATE OR DELETE ON rounds.call_events FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_provider_receipts BEFORE UPDATE OR DELETE ON rounds.provider_receipts FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_location_samples BEFORE UPDATE OR DELETE ON rounds.location_samples FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_domain_events BEFORE UPDATE OR DELETE ON rounds.domain_events FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_consumer_receipts BEFORE UPDATE OR DELETE ON rounds.consumer_receipts FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_audit_access BEFORE UPDATE OR DELETE ON rounds.audit_access FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();
CREATE TRIGGER immutable_account_events BEFORE UPDATE OR DELETE ON rounds.account_events FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();

-- Custodian identity canonicalization; actor fields retain attribution independently.
ALTER TABLE rounds.custody_events DROP COLUMN from_principal_id;
ALTER TABLE rounds.custody_events DROP COLUMN to_principal_id;
ALTER TABLE rounds.custody_events DROP COLUMN site_id;
ALTER TABLE rounds.rounds ADD COLUMN operational_hold boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX one_round_conversation ON rounds.conversations(tenant_id,round_id) WHERE round_id IS NOT NULL;
CREATE UNIQUE INDEX one_trip_conversation ON rounds.conversations(tenant_id,trip_id) WHERE trip_id IS NOT NULL;
CREATE UNIQUE INDEX one_relationship_conversation ON rounds.conversations(tenant_id,relationship_id) WHERE relationship_id IS NOT NULL;
CREATE OR REPLACE FUNCTION rounds.guard_accepted_scope() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.accepted_scope IS DISTINCT FROM OLD.accepted_scope OR NEW.accepted_revision<>OLD.accepted_revision OR NEW.driver_id<>OLD.driver_id OR NEW.fare_minor<>OLD.fare_minor OR NEW.currency<>OLD.currency THEN RAISE EXCEPTION 'ACCEPTED_SCOPE_IMMUTABLE'; END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER immutable_accepted_scope BEFORE UPDATE ON rounds.freelance_agreements FOR EACH ROW EXECUTE FUNCTION rounds.guard_accepted_scope();
CREATE INDEX notification_inbox ON rounds.notifications(tenant_id,principal_id,created_at DESC);

CREATE TABLE rounds.agreement_revisions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),created_at timestamptz NOT NULL DEFAULT now(),agreement_id uuid NOT NULL,revision integer NOT NULL CHECK(revision>0),proposal_id uuid,accepted_by uuid NOT NULL REFERENCES rounds.principals(id),scope jsonb NOT NULL,fare_minor bigint NOT NULL CHECK(fare_minor>=0),currency char(3) NOT NULL,accepted_at timestamptz NOT NULL,UNIQUE(tenant_id,id),UNIQUE(tenant_id,agreement_id,revision),FOREIGN KEY(tenant_id,agreement_id) REFERENCES rounds.freelance_agreements(tenant_id,id),FOREIGN KEY(tenant_id,proposal_id) REFERENCES rounds.change_proposals(tenant_id,id));
ALTER TABLE rounds.agreement_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.agreement_revisions FORCE ROW LEVEL SECURITY;
ALTER TABLE rounds.freelance_agreements ADD COLUMN current_revision_id uuid;
ALTER TABLE rounds.freelance_agreements ADD FOREIGN KEY(tenant_id,current_revision_id) REFERENCES rounds.agreement_revisions(tenant_id,id);
CREATE TRIGGER immutable_agreement_revision BEFORE UPDATE OR DELETE ON rounds.agreement_revisions FOR EACH ROW EXECUTE FUNCTION rounds.reject_immutable_mutation();

-- Consolidated V2.1 integrity corrections (fresh reference schema).
ALTER TABLE rounds.availability_requests ADD COLUMN available_after timestamptz;
ALTER TABLE rounds.availability_requests ADD CHECK (response IS NULL OR response IN ('available','unavailable','later'));
ALTER TABLE rounds.availability_requests ADD CHECK ((response='later' AND available_after IS NOT NULL) OR (response IS DISTINCT FROM 'later' AND available_after IS NULL));
ALTER TABLE rounds.custody_transfers ADD CHECK (state NOT IN ('partially_received','received') OR (received_at IS NOT NULL AND received_by IS NOT NULL));
ALTER TABLE rounds.custody_transfers ADD CHECK (expires_at>created_at);
ALTER TABLE rounds.custody_events ADD COLUMN transfer_id uuid;
ALTER TABLE rounds.custody_events ADD FOREIGN KEY(tenant_id,transfer_id) REFERENCES rounds.custody_transfers(tenant_id,id);
ALTER TABLE rounds.custody_events ADD CHECK (num_nonnulls(attempt_id,trip_id,round_id,stop_id,transfer_id)>=1);
ALTER TABLE rounds.custody_events ADD CHECK (event_kind IN ('pickup','handoff','return','transfer','trip_load','trip_receipt','correction'));
DO $$ DECLARE n text; BEGIN FOR n IN SELECT c.conname FROM pg_constraint c WHERE c.conrelid='rounds.realtime_grants'::regclass AND c.contype='u' AND (SELECT array_agg(a.attname::text ORDER BY u.ord) FROM unnest(c.conkey) WITH ORDINALITY u(attnum,ord) JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=u.attnum)=ARRAY['tenant_id','principal_id','topic']::text[] LOOP EXECUTE format('ALTER TABLE rounds.realtime_grants DROP CONSTRAINT %I',n); END LOOP; END $$;
CREATE UNIQUE INDEX active_realtime_grant ON rounds.realtime_grants(tenant_id,principal_id,topic) WHERE revoked_at IS NULL;
ALTER TABLE rounds.realtime_grants ADD CHECK (expires_at>created_at);
DO $$ DECLARE n text; BEGIN FOR n IN SELECT c.conname FROM pg_constraint c WHERE c.conrelid='rounds.plans'::regclass AND c.contype='u' AND (SELECT array_agg(a.attname::text ORDER BY u.ord) FROM unnest(c.conkey) WITH ORDINALITY u(attnum,ord) JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=u.attnum)=ARRAY['tenant_id','city_id','service_date']::text[] LOOP EXECUTE format('ALTER TABLE rounds.plans DROP CONSTRAINT %I',n); END LOOP; END $$;
CREATE UNIQUE INDEX current_plan_for_day ON rounds.plans(tenant_id,city_id,service_date) WHERE state<>'superseded';
CREATE UNIQUE INDEX one_off_shift_identity ON rounds.shift_occurrences(tenant_id,relationship_id,starts_at,ends_at) WHERE template_id IS NULL AND state<>'cancelled';
ALTER TABLE rounds.shift_occurrences ADD CONSTRAINT vehicle_shift_overlap EXCLUDE USING gist (tenant_id WITH =,vehicle_id WITH =,tstzrange(starts_at,ends_at,'[)') WITH &&) WHERE(vehicle_id IS NOT NULL AND state IN ('scheduled','started','on_break')) DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE rounds.agreement_revisions ADD UNIQUE(tenant_id,agreement_id,id);
ALTER TABLE rounds.freelance_agreements ADD CONSTRAINT revision_belongs_to_agreement FOREIGN KEY(tenant_id,id,current_revision_id) REFERENCES rounds.agreement_revisions(tenant_id,agreement_id,id) DEFERRABLE INITIALLY DEFERRED;
CREATE FUNCTION rounds.guard_agreement_revision_pointer() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target_revision integer; previous_revision integer;
BEGIN
 IF NEW.current_revision_id IS NULL THEN
  IF OLD.current_revision_id IS NOT NULL THEN RAISE EXCEPTION 'IMMUTABLE_RECORD'; END IF; RETURN NEW;
 END IF;
 SELECT revision INTO target_revision FROM rounds.agreement_revisions WHERE tenant_id=NEW.tenant_id AND agreement_id=NEW.id AND id=NEW.current_revision_id;
 IF target_revision IS NULL OR target_revision<=NEW.accepted_revision THEN RAISE EXCEPTION 'INVALID_REVISION'; END IF;
 IF OLD.current_revision_id IS NOT NULL AND OLD.current_revision_id<>NEW.current_revision_id THEN
  SELECT revision INTO previous_revision FROM rounds.agreement_revisions WHERE tenant_id=OLD.tenant_id AND id=OLD.current_revision_id;
  IF target_revision<=previous_revision THEN RAISE EXCEPTION 'INVALID_REVISION'; END IF;
 END IF; RETURN NEW;
END; $$;
CREATE TRIGGER current_agreement_revision BEFORE UPDATE OF current_revision_id ON rounds.freelance_agreements FOR EACH ROW EXECUTE FUNCTION rounds.guard_agreement_revision_pointer();
CREATE FUNCTION rounds.guard_booking_manifest_line() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE b uuid; l uuid;
BEGIN
 SELECT manifest_id INTO b FROM rounds.trip_bookings WHERE tenant_id=NEW.tenant_id AND id=NEW.trip_booking_id;
 SELECT manifest_id INTO l FROM rounds.manifest_lines WHERE tenant_id=NEW.tenant_id AND id=NEW.line_id;
 IF b IS NULL OR l IS NULL OR b<>l THEN RAISE EXCEPTION 'MANIFEST_MISMATCH'; END IF; RETURN NEW;
END; $$;
CREATE TRIGGER booking_line_manifest BEFORE INSERT OR UPDATE ON rounds.trip_booking_lines FOR EACH ROW EXECUTE FUNCTION rounds.guard_booking_manifest_line();
CREATE FUNCTION rounds.guard_current_manifest() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.current_manifest_id IS DISTINCT FROM NEW.current_manifest_id AND EXISTS(SELECT 1 FROM rounds.manifests WHERE tenant_id=OLD.tenant_id AND id=OLD.current_manifest_id AND sealed_at IS NOT NULL) THEN RAISE EXCEPTION 'IMMUTABLE_RECORD'; END IF; RETURN NEW;
END; $$;
CREATE TRIGGER delivery_manifest_pointer BEFORE UPDATE OF current_manifest_id ON rounds.deliveries FOR EACH ROW EXECUTE FUNCTION rounds.guard_current_manifest();
CREATE FUNCTION rounds.guard_package_seal() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE tenant uuid; mid uuid; pid uuid; line_manifest uuid; body jsonb;
BEGIN
 body:=CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
 tenant:=(body->>'tenant_id')::uuid;
 IF TG_TABLE_NAME='packages' THEN
  mid:=(body->>'manifest_id')::uuid;
  IF TG_OP='UPDATE' AND (NEW.tenant_id<>OLD.tenant_id OR NEW.manifest_id<>OLD.manifest_id) THEN RAISE EXCEPTION 'IMMUTABLE_RECORD'; END IF;
 ELSE
  pid:=(body->>'package_id')::uuid;
  SELECT manifest_id INTO mid FROM rounds.packages WHERE tenant_id=tenant AND id=pid FOR UPDATE;
  IF TG_OP='UPDATE' AND (NEW.tenant_id<>OLD.tenant_id OR NEW.package_id<>OLD.package_id) THEN RAISE EXCEPTION 'IMMUTABLE_RECORD'; END IF;
  SELECT manifest_id INTO line_manifest FROM rounds.manifest_lines WHERE tenant_id=tenant AND id=(body->>'line_id')::uuid;
  IF mid IS DISTINCT FROM line_manifest THEN RAISE EXCEPTION 'MANIFEST_MISMATCH'; END IF;
 END IF;
 PERFORM 1 FROM rounds.manifests WHERE tenant_id=tenant AND id=mid FOR UPDATE;
 IF EXISTS(SELECT 1 FROM rounds.manifests WHERE tenant_id=tenant AND id=mid AND sealed_at IS NOT NULL) THEN RAISE EXCEPTION 'IMMUTABLE_RECORD'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END; $$;
CREATE TRIGGER packages_seal BEFORE INSERT OR UPDATE OR DELETE ON rounds.packages FOR EACH ROW EXECUTE FUNCTION rounds.guard_package_seal();
CREATE TRIGGER package_contents_seal BEFORE INSERT OR UPDATE OR DELETE ON rounds.package_contents FOR EACH ROW EXECUTE FUNCTION rounds.guard_package_seal();
ALTER TABLE rounds.handoffs ADD CHECK (receiver_kind IN ('recipient','alternate','unattended'));
ALTER TABLE rounds.custodians ADD CHECK (kind IN ('principal','site'));
CREATE TABLE rounds.driver_tracking_grants(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL REFERENCES rounds.tenants(id),driver_id uuid NOT NULL,purpose text NOT NULL CHECK(purpose IN ('team_shift','accepted_round','accepted_trip','recovery')),round_id uuid,trip_id uuid,shift_id uuid,starts_at timestamptz NOT NULL,ends_at timestamptz NOT NULL,revoked_at timestamptz,created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),version bigint NOT NULL DEFAULT 1,archived_at timestamptz,UNIQUE(tenant_id,id),CHECK(ends_at>starts_at),CHECK(num_nonnulls(round_id,trip_id,shift_id)=1));
ALTER TABLE rounds.driver_tracking_grants ADD FOREIGN KEY (driver_id) REFERENCES rounds.drivers(id);
ALTER TABLE rounds.driver_tracking_grants ADD FOREIGN KEY (tenant_id,round_id) REFERENCES rounds.rounds(tenant_id,id);
ALTER TABLE rounds.driver_tracking_grants ADD FOREIGN KEY (tenant_id,trip_id) REFERENCES rounds.transport_trips(tenant_id,id);
ALTER TABLE rounds.driver_tracking_grants ADD FOREIGN KEY (tenant_id,shift_id) REFERENCES rounds.shift_occurrences(tenant_id,id);
ALTER TABLE rounds.driver_tracking_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds.driver_tracking_grants FORCE ROW LEVEL SECURITY;
CREATE INDEX tracking_grant_scope ON rounds.driver_tracking_grants(tenant_id,driver_id,ends_at) WHERE revoked_at IS NULL;

ALTER TABLE rounds.driver_tracking_grants ADD COLUMN tracking_entitlement_id uuid NOT NULL REFERENCES rounds.tracking_entitlements(id);
