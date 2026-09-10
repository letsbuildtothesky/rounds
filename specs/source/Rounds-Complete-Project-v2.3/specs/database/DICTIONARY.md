# Database dictionary — V2.3

Fresh reference schema, not a deployed/live migration. Apply base DDL, V22-INVARIANTS, V23-COMPLETE-ORDER, ROLE-POLICIES, V22-ROLE-POLICIES in that order; Supabase realtime file follows in a Supabase environment. Common metadata and constraints are authoritative in SQL.

V2.3-r1 changelog · 2026-09-10: preserve nullable original issue-decision reason and add only city/capability-scoped original-report SELECT via isolated migration0008 (ADR-T08); retain old immutable records and actor-only report writes. 2026-09-09: preserve exact proof notes and explicit arrival-observation identity (ADR-T06); nullable fields and same-tenant FK also upgrade through isolated migration0005 without evidence backfill. 2026-09-08: synchronize original-city receipt metadata and deferred complete-order enforcement/application order.

## tenants

Owner P01; scope global. Business identity and lifecycle; fixture names never define product logic.

```sql
name text NOT NULL
country_code char(2) NOT NULL
default_timezone text NOT NULL
default_currency char(3) NOT NULL
status text NOT NULL CHECK (status IN ('active','suspended','closed'))
```

Rules: See SQL constraints and command rules.

## principals

Owner P01; scope global. Application actor mapped to authentication identity.

```sql
auth_subject uuid UNIQUE
display_name text NOT NULL
preferred_locale text NOT NULL DEFAULT 'th-TH'
disabled_at timestamptz
```

Rules: See SQL constraints and command rules.

## memberships

Owner P01; scope tenant. Business membership, independent of driver work relationship.

```sql
principal_id uuid NOT NULL
role_code text NOT NULL
status text NOT NULL CHECK (status IN ('invited','active','suspended','revoked'))
permission_revision bigint NOT NULL DEFAULT 1
```

Rules: UNIQUE (tenant_id, principal_id)

## cities

Owner P01; scope tenant. Configured service area; city label is not security authority.

```sql
name text NOT NULL
country_code char(2) NOT NULL
timezone text NOT NULL
service_boundary geography(MultiPolygon,4326)
enabled boolean NOT NULL DEFAULT true
```

Rules: See SQL constraints and command rules.

## city_grants

Owner P01; scope tenant. Explicit membership access to a city.

```sql
membership_id uuid NOT NULL
city_id uuid NOT NULL
capabilities text[] NOT NULL
```

Rules: UNIQUE (tenant_id, membership_id, city_id)

## brands

Owner P01; scope tenant. Tenant-owned brand and customer tracking identity.

```sql
name text NOT NULL
logo_asset_id uuid
tracking_style jsonb NOT NULL DEFAULT '{}'::jsonb
```

Rules: See SQL constraints and command rules.

## sites

Owner P01; scope tenant. Pickup/hub/base/site identity; geographic source and verification are explicit.

```sql
city_id uuid NOT NULL
name text NOT NULL
site_type text NOT NULL
address_text text NOT NULL
point geography(Point,4326)
contact_principal_id uuid
access_notes text
timezone text NOT NULL
```

Rules: See SQL constraints and command rules.

## feature_entitlements

Owner P01; scope tenant. Capability eligibility distinct from operator feature preferences.

```sql
feature_key text NOT NULL
enabled boolean NOT NULL
effective_at timestamptz NOT NULL
expires_at timestamptz
```

Rules: UNIQUE (tenant_id, feature_key)

## policy_versions

Owner P13; scope tenant. Immutable typed setting payloads; schema_version identifies validated JSON schema.

```sql
policy_kind text NOT NULL
scope_key text NOT NULL
revision integer NOT NULL CHECK (revision>0)
schema_version integer NOT NULL
payload jsonb NOT NULL
effective_at timestamptz NOT NULL
created_by uuid NOT NULL
```

Rules: UNIQUE (tenant_id, policy_kind, scope_key, revision)

## policy_bindings

Owner P13; scope tenant. Current effective pointer; overrides resolve by domain-specific precedence.

```sql
policy_kind text NOT NULL
scope_key text NOT NULL
policy_version_id uuid NOT NULL
```

Rules: UNIQUE (tenant_id, policy_kind, scope_key)

## tenant_subscriptions

Owner P15; scope tenant. Commercial entitlement record; no invented prices.

```sql
plan_code text NOT NULL
state text NOT NULL CHECK (state IN ('trial','active','past_due','cancelled'))
currency char(3) NOT NULL
billing_provider text
provider_reference text
current_period_end timestamptz
```

Rules: See SQL constraints and command rules.

## usage_ledger

Owner P15; scope tenant. Metered usage deduplicated by original business event.

```sql
event_id uuid NOT NULL
meter_key text NOT NULL
quantity numeric(18,4) NOT NULL
unit text NOT NULL
occurred_at timestamptz NOT NULL
```

Rules: UNIQUE (tenant_id, event_id, meter_key)

## drivers

Owner P06; scope global. One driver identity across employers and Network.

```sql
principal_id uuid NOT NULL UNIQUE
network_eligibility text NOT NULL
verification_application_id uuid
profile_asset_id uuid
```

Rules: See SQL constraints and command rules.

## driver_relationships

Owner P06; scope tenant. Team or known freelancer relationship, not a permanent global category.

```sql
driver_id uuid NOT NULL
relationship_kind text NOT NULL CHECK (relationship_kind IN ('team','known_freelancer'))
status text NOT NULL CHECK (status IN ('invited','active','suspended','ended'))
outside_work_allowed boolean NOT NULL DEFAULT false
invitation_id uuid
```

Rules: UNIQUE (tenant_id, driver_id, relationship_kind)

## invitations

Owner P06; scope tenant. Hashed invitation token, actor, expiry and one-time consumption.

```sql
token_hash text NOT NULL UNIQUE
relationship_kind text NOT NULL
invited_contact_hash text
expires_at timestamptz NOT NULL
used_by uuid
used_at timestamptz
revoked_at timestamptz
```

Rules: See SQL constraints and command rules.

## driver_contact_permissions

Owner P06; scope tenant. Driver-controlled permission per known merchant relationship.

```sql
relationship_id uuid NOT NULL
messages_allowed boolean NOT NULL DEFAULT false
availability_requests_allowed boolean NOT NULL DEFAULT false
changed_by uuid NOT NULL
```

Rules: UNIQUE (tenant_id, relationship_id)

## driver_devices

Owner E06; scope global. Revocable device registration, push token reference and session epoch.

```sql
driver_id uuid NOT NULL
platform text NOT NULL
push_secret_reference text
device_key text NOT NULL
session_epoch bigint NOT NULL DEFAULT 1
last_seen_at timestamptz
revoked_at timestamptz
```

Rules: UNIQUE (driver_id, device_key)

## onboarding_drafts

Owner P06; scope global. Persisted typed onboarding draft and branch with real evidence references.

```sql
principal_id uuid NOT NULL
context text NOT NULL
step_key text NOT NULL
schema_version integer NOT NULL
draft jsonb NOT NULL
expires_at timestamptz
```

Rules: See SQL constraints and command rules.

## verification_applications

Owner P06; scope global. Application receipt and review state independent of availability.

```sql
driver_id uuid NOT NULL
country_code char(2) NOT NULL
state text NOT NULL CHECK (state IN ('draft','submitted','pending','approved','rejected','correction_required'))
submitted_at timestamptz
provider text
provider_reference text
decision_reason_code text
```

Rules: See SQL constraints and command rules.

## verification_evidence

Owner P06; scope global. Document/face evidence references and correction lineage.

```sql
application_id uuid NOT NULL
evidence_kind text NOT NULL
private_object_key text NOT NULL
sha256 text NOT NULL
state text NOT NULL CHECK (state IN ('reserved','uploaded','verified','rejected','superseded'))
replaces_id uuid
```

Rules: See SQL constraints and command rules.

## payout_methods

Owner P15; scope global. Tokenized/encrypted bank or PromptPay reference with masked display.

```sql
driver_id uuid NOT NULL
method_kind text NOT NULL
country_code char(2) NOT NULL
currency char(3) NOT NULL
secret_reference text NOT NULL
masked_label text NOT NULL
verification_state text NOT NULL CHECK (verification_state IN ('pending','verified','rejected'))
```

Rules: See SQL constraints and command rules.

## availability_declarations

Owner P06; scope global. Driver intent; freshness and accepted obligations evaluated separately.

```sql
driver_id uuid NOT NULL UNIQUE
intent text NOT NULL CHECK (intent IN ('paused','open','open_later'))
available_after timestamptz
declared_at timestamptz NOT NULL
expires_at timestamptz
```

Rules: See SQL constraints and command rules.

## availability_requests

Owner P06; scope tenant. Opted-in relationship question, never an offer/booking.

```sql
relationship_id uuid NOT NULL
requested_start timestamptz
requested_end timestamptz
message text
expires_at timestamptz NOT NULL
response text
responded_at timestamptz
available_after timestamptz
```

Rules: CHECK (response IS NULL OR response IN ('available','unavailable','later')); CHECK ((response='later' AND available_after IS NOT NULL) OR (response IS DISTINCT FROM 'later' AND available_after IS NULL))

## vehicle_types

Owner P06; scope global. Display catalogue: motorbike_box, tuk_tuk, car, pickup, van; extensible mapping.

```sql
code text NOT NULL UNIQUE
display_key text NOT NULL
enabled boolean NOT NULL DEFAULT true
```

Rules: See SQL constraints and command rules.

## cargo_classes

Owner P04; scope tenant. Named physical capacity dimension with explicit unit.

```sql
code text NOT NULL
name text NOT NULL
unit text NOT NULL
discrete boolean NOT NULL DEFAULT true
```

Rules: UNIQUE (tenant_id, code)

## vehicle_profiles

Owner P04; scope tenant. Versioned defaults for departure capacity and timing; snapshot on commitments.

```sql
name text NOT NULL
vehicle_type_id uuid NOT NULL
max_stops integer NOT NULL CHECK (max_stops>0)
max_total_units numeric(18,4) CHECK (max_total_units>=0)
load_seconds integer NOT NULL CHECK (load_seconds>=0)
reload_seconds integer NOT NULL CHECK (reload_seconds>=0)
return_required boolean NOT NULL
revision integer NOT NULL
```

Rules: See SQL constraints and command rules.

## profile_cargo_limits

Owner P04; scope tenant. Class quantity limit; zero prohibits class.

```sql
profile_id uuid NOT NULL
cargo_class_id uuid NOT NULL
max_quantity numeric(18,4) NOT NULL CHECK (max_quantity>=0)
```

Rules: UNIQUE (tenant_id, profile_id, cargo_class_id)

## handling_rules

Owner P04; scope tenant. Allowed/preferred/required capability rule using a typed selector.

```sql
handling_key text NOT NULL
profile_id uuid NOT NULL
effect text NOT NULL CHECK (effect IN ('allowed','preferred','required','prohibited'))
rule_version integer NOT NULL
```

Rules: See SQL constraints and command rules.

## vehicles

Owner P06; scope tenant. Tenant vehicle instance, reusable type/profile and service status.

```sql
vehicle_type_id uuid NOT NULL
profile_id uuid NOT NULL
plate text NOT NULL
status text NOT NULL CHECK (status IN ('available','unavailable','maintenance','archived'))
capability_overrides jsonb NOT NULL DEFAULT '{}'::jsonb
```

Rules: See SQL constraints and command rules.

## freelance_vehicles

Owner P06; scope global. Driver-owned vehicle; merchant sees authorized capability projection.

```sql
driver_id uuid NOT NULL
vehicle_type_id uuid NOT NULL
plate_secret_reference text
masked_plate text
capabilities jsonb NOT NULL
verified_at timestamptz
status text NOT NULL CHECK (status IN ('pending','verified','unavailable','archived'))
```

Rules: See SQL constraints and command rules.

## shift_templates

Owner P04; scope tenant. Recurring schedule, effective dates and explicit overnight local minutes.

```sql
relationship_id uuid NOT NULL
city_id uuid NOT NULL
weekdays smallint[] NOT NULL
start_minute integer NOT NULL CHECK (start_minute>=0 AND start_minute<1440)
end_minute integer NOT NULL
valid_from date NOT NULL
valid_to date
timezone text NOT NULL
vehicle_id uuid
```

Rules: CHECK (end_minute>start_minute AND end_minute<=2880)

## shift_occurrences

Owner P04; scope tenant. Resolved dated shift, including off-day/one-off override provenance.

```sql
template_id uuid
relationship_id uuid NOT NULL
city_id uuid NOT NULL
service_date date NOT NULL
starts_at timestamptz NOT NULL
ends_at timestamptz NOT NULL
state text NOT NULL CHECK (state IN ('scheduled','started','on_break','ended','no_show','cancelled'))
override_reason text
vehicle_id uuid
```

Rules: CHECK (ends_at>starts_at); UNIQUE(tenant_id,template_id,service_date)

## attendance_events

Owner P06; scope tenant. Append-only start/end and correction requests/decisions, not payroll.

```sql
shift_id uuid NOT NULL
driver_id uuid NOT NULL
event_kind text NOT NULL
occurred_at timestamptz NOT NULL
received_at timestamptz NOT NULL
actor_id uuid NOT NULL
corrects_event_id uuid
reason text
```

Rules: See SQL constraints and command rules.

## slot_templates

Owner P03; scope tenant. Named delivery-window identity; historical versions retained.

```sql
city_id uuid NOT NULL
site_id uuid
brand_id uuid
name text NOT NULL
enabled boolean NOT NULL DEFAULT true
```

Rules: See SQL constraints and command rules.

## slot_template_versions

Owner P03; scope tenant. Immutable recurring slot timing and allocation policy in local minutes from service-date midnight.

```sql
template_id uuid NOT NULL
revision integer NOT NULL
timezone text NOT NULL
weekdays smallint[] NOT NULL
valid_from date NOT NULL
valid_to date
window_start_minute integer NOT NULL
window_end_minute integer NOT NULL
cutoff_minute integer NOT NULL
release_minute integer NOT NULL
max_orders integer NOT NULL CHECK (max_orders>0)
policy_version_id uuid NOT NULL
```

Rules: UNIQUE (tenant_id, template_id, revision); CHECK (window_start_minute>=0 AND window_start_minute<1440); CHECK (window_end_minute>window_start_minute AND window_end_minute<=2880); CHECK (cutoff_minute<=release_minute AND release_minute<=window_start_minute)

## slot_overrides

Owner P03; scope tenant. One dated override per template; closure or complete resolved replacement values.

```sql
template_id uuid NOT NULL
service_date date NOT NULL
closed boolean NOT NULL
replacement jsonb NOT NULL
reason text NOT NULL
created_by uuid NOT NULL
```

Rules: UNIQUE (tenant_id, template_id, service_date)

## slot_occurrences

Owner P03; scope tenant. Resolved immutable promise basis plus independently versioned admission controls; issued promises stay on delivery snapshot.

```sql
template_version_id uuid NOT NULL
override_id uuid
city_id uuid NOT NULL
service_date date NOT NULL
window_start_at timestamptz NOT NULL
window_end_at timestamptz NOT NULL
cutoff_at timestamptz NOT NULL
release_at timestamptz NOT NULL
max_orders integer NOT NULL CHECK (max_orders>0)
admission_state text NOT NULL CHECK (admission_state IN ('open','closed','overcommitted','superseded'))
resolution_revision integer NOT NULL
```

Rules: UNIQUE (tenant_id, template_version_id, service_date, resolution_revision); CHECK (window_end_at>window_start_at); CHECK (cutoff_at<=release_at AND release_at<=window_start_at)

## slot_reservations

Owner P03; scope tenant. Atomic capacity reservation for a draft/source delivery; held expiry is server-owned.

```sql
occurrence_id uuid NOT NULL
delivery_id uuid
draft_id uuid
source_key text NOT NULL
state text NOT NULL CHECK (state IN ('held','committed','released','expired'))
expires_at timestamptz
committed_at timestamptz
```

Rules: CHECK (num_nonnulls(delivery_id,draft_id)=1); CHECK (state<>'held' OR (draft_id IS NOT NULL AND expires_at IS NOT NULL AND committed_at IS NULL)); CHECK (state<>'committed' OR (delivery_id IS NOT NULL AND committed_at IS NOT NULL))

## source_connections

Owner P12; scope tenant. Commerce connection config, authorization and health independently recorded.

```sql
provider text NOT NULL
external_store_key text NOT NULL
secret_reference text
state text NOT NULL CHECK (state IN ('active','paused','error','disconnected'))
city_id uuid
site_id uuid
brand_id uuid
permissions jsonb NOT NULL
last_received_at timestamptz
last_writeback_at timestamptz
```

Rules: UNIQUE (tenant_id, provider, external_store_key)

## source_events

Owner P12; scope tenant. Authenticated webhook/request inbox; safely retained minimized payload and processing result.

```sql
connection_id uuid NOT NULL
provider_event_key text NOT NULL
source_object_key text NOT NULL
source_revision text
received_at timestamptz NOT NULL
payload_hash text NOT NULL
payload_reference text
state text NOT NULL CHECK (state IN ('received','normalized','review_required','applied','rejected','conflict'))
reviewed_by uuid
reviewed_at timestamptz
```

Rules: UNIQUE (tenant_id, connection_id, provider_event_key)

## intake_batches

Owner P02; scope tenant. Manual/import/AI batch job and source evidence reference.

```sql
created_by uuid NOT NULL
input_kind text NOT NULL
source_asset_id uuid
state text NOT NULL CHECK (state IN ('draft','processing','review_ready','committing','completed','partial_failed','failed'))
total_rows integer NOT NULL DEFAULT 0
processed_rows integer NOT NULL DEFAULT 0
```

Rules: See SQL constraints and command rules.

## intake_drafts

Owner P02; scope tenant. Editable normalized draft; original source retained; no assignment effect.

```sql
batch_id uuid
connection_id uuid
source_order_key text
source_revision text
city_id uuid
draft_payload jsonb NOT NULL
original_payload_reference text
review_state text NOT NULL CHECK (review_state IN ('draft','extracting','review_needed','ready','committed','discarded'))
created_by uuid NOT NULL
```

Rules: See SQL constraints and command rules.

## address_suggestions

Owner P02; scope tenant. AI/geocoder candidate with before/after, allowed provenance, expiry and reviewed disposition.

```sql
draft_id uuid
delivery_id uuid
input_hash text NOT NULL
provider text NOT NULL
model_version text
changed_fields jsonb NOT NULL
suggested_text text
point geography(Point,4326)
confidence numeric(5,4)
state text NOT NULL CHECK (state IN ('proposed','accepted','edited','rejected','superseded'))
reviewed_by uuid
reviewed_at timestamptz
expires_at timestamptz
```

Rules: CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1)

## entrances

Owner P10; scope tenant. Building/site entrance identity; recipient unit data stored separately.

```sql
site_id uuid
city_id uuid NOT NULL
label text NOT NULL
retired_at timestamptz
```

Rules: See SQL constraints and command rules.

## entrance_revisions

Owner P10; scope tenant. Immutable reviewed entrance/access knowledge with attribution and licensed-source metadata.

```sql
entrance_id uuid NOT NULL
revision integer NOT NULL
point geography(Point,4326) NOT NULL
access_notes text
handoff_notes text
vehicle_access jsonb NOT NULL
provenance jsonb NOT NULL
confirmed_by uuid NOT NULL
confirmed_at timestamptz NOT NULL
```

Rules: UNIQUE (tenant_id, entrance_id, revision)

## location_observations

Owner P10; scope tenant. Candidate measured observation; review does not change earlier delivery evidence.

```sql
delivery_id uuid
driver_id uuid
point geography(Point,4326)
accuracy_m numeric CHECK (accuracy_m>=0)
observed_at timestamptz NOT NULL
kind text NOT NULL
note text
state text NOT NULL CHECK (state IN ('proposed','reviewed','accepted','rejected'))
reviewed_revision_id uuid
```

Rules: See SQL constraints and command rules.

## deliveries

Owner P05; scope tenant. Stable doorstep obligation; readiness, outcome and evidence dimensions are distinct.

```sql
city_id uuid NOT NULL
brand_id uuid
pickup_site_id uuid NOT NULL
source_connection_id uuid
source_order_key text
human_reference text NOT NULL
service_date date NOT NULL
timezone text NOT NULL
window_start_at timestamptz NOT NULL
window_end_at timestamptz NOT NULL
slot_occurrence_id uuid
address_text text NOT NULL
destination geography(Point,4326)
destination_version integer NOT NULL DEFAULT 1
entrance_revision_id uuid
private_access_notes text
readiness text NOT NULL CHECK (readiness IN ('draft','review_needed','ready','held'))
outcome text NOT NULL CHECK (outcome IN ('open','delivered','partially_delivered','rescheduled','returned','cancelled','unresolved'))
evidence_state text NOT NULL CHECK (evidence_state IN ('none','local_only','pending','complete','disputed'))
current_manifest_id uuid
proof_policy_id uuid NOT NULL
created_by uuid NOT NULL
preparation_state text NOT NULL DEFAULT 'unknown' CHECK (preparation_state IN ('unknown','preparing','ready','blocked'))
ready_by timestamptz
ready_declared_at timestamptz
ready_declared_by uuid
```

Rules: CHECK (window_end_at>window_start_at); UNIQUE (tenant_id, human_reference)

## delivery_contacts

Owner P05; scope tenant. Buyer, recipient, pickup and alternate are explicit roles; secret contact values encrypted.

```sql
delivery_id uuid NOT NULL
role text NOT NULL
person_key text
display_name text NOT NULL
contact_secret_reference text
masked_contact text
locale text
notification_permissions jsonb NOT NULL
```

Rules: See SQL constraints and command rules.

## manifests

Owner P05; scope tenant. Immutable physical-content revision; new version before pickup requires explicit revalidation.

```sql
delivery_id uuid NOT NULL
revision integer NOT NULL
source text NOT NULL
sealed_at timestamptz
```

Rules: UNIQUE (tenant_id, delivery_id, revision)

## manifest_lines

Owner P05; scope tenant. Identified line and expected amount; one quantity two line is not two anonymous taps.

```sql
manifest_id uuid NOT NULL
line_key text NOT NULL
label text NOT NULL
quantity numeric(18,4) NOT NULL CHECK (quantity>0)
unit text NOT NULL
cargo_class_id uuid
handling_keys text[] NOT NULL DEFAULT ARRAY[]::text[]
```

Rules: UNIQUE (tenant_id, manifest_id, line_key)

## packages

Owner P05; scope tenant. Optional independently identified parcel, not inferred from product quantity.

```sql
manifest_id uuid NOT NULL
package_key text NOT NULL
label text NOT NULL
```

Rules: UNIQUE (tenant_id, manifest_id, package_key)

## package_contents

Owner P05; scope tenant. Identified package contents with line quantities; sums validated transactionally.

```sql
package_id uuid NOT NULL
line_id uuid NOT NULL
quantity numeric(18,4) NOT NULL CHECK (quantity>0)
```

Rules: UNIQUE (tenant_id, package_id, line_id)

## plans

Owner P04; scope tenant. City/date draft planning aggregate.

```sql
city_id uuid NOT NULL
service_date date NOT NULL
state text NOT NULL CHECK (state IN ('draft','generating','review_ready','saved','released','superseded'))
input_revision bigint NOT NULL
created_by uuid NOT NULL
```

Rules: See SQL constraints and command rules.

## plan_proposals

Owner P04; scope tenant. Immutable before/after proposal, inputs/policy hashes and allowed route artifact references.

```sql
plan_id uuid NOT NULL
base_version bigint NOT NULL
input_hash text NOT NULL
policy_hash text NOT NULL
proposal jsonb NOT NULL
impact jsonb NOT NULL
expires_at timestamptz NOT NULL
version bigint NOT NULL DEFAULT 1 CHECK(version=1)
```

Rules: See SQL constraints and command rules.

## plan_releases

Owner P04; scope tenant. Released snapshot; uncovered scope and approval recorded.

```sql
plan_id uuid NOT NULL
proposal_id uuid NOT NULL
released_by uuid NOT NULL
released_at timestamptz NOT NULL
snapshot jsonb NOT NULL
uncovered_delivery_ids uuid[] NOT NULL
```

Rules: See SQL constraints and command rules.

## rounds

Owner P04; scope tenant. Local work commitment; pickup/date/city coherent.

```sql
city_id uuid NOT NULL
service_date date NOT NULL
pickup_site_id uuid NOT NULL
fulfillment_kind text NOT NULL CHECK (fulfillment_kind IN ('team','freelance'))
driver_id uuid
vehicle_id uuid
freelance_vehicle_id uuid
state text NOT NULL CHECK (state IN ('draft','planned','staged','released','active','completed','cancelled'))
planned_start_at timestamptz
predicted_free_at timestamptz
release_id uuid
capacity_snapshot jsonb NOT NULL
policy_version_id uuid NOT NULL
departure_gate text NOT NULL DEFAULT 'awaiting_preparation' CHECK (departure_gate IN ('awaiting_preparation','awaiting_receipt','discrepancy','ready','blocked'))
staged_at timestamptz
operational_hold boolean NOT NULL DEFAULT false
```

Rules: CHECK (num_nonnulls(vehicle_id,freelance_vehicle_id)<=1)

## stops

Owner P05; scope tenant. Pickup, dropoff, return, transfer; stable stop identity survives sequence edits.

```sql
round_id uuid NOT NULL
delivery_id uuid
kind text NOT NULL CHECK (kind IN ('pickup','dropoff','return','transfer'))
sequence integer NOT NULL CHECK (sequence>=0)
destination geography(Point,4326)
destination_version integer NOT NULL
state text NOT NULL CHECK (state IN ('planned','released','en_route','arrived','handed_over','completed','failed','cancelled'))
service_seconds integer NOT NULL CHECK (service_seconds>=0)
planned_arrival_at timestamptz
actual_arrival_at timestamptz
fulfillment_unit_id uuid
```

Rules: UNIQUE (tenant_id, round_id, sequence) DEFERRABLE INITIALLY DEFERRED

## assignments

Owner P04; scope tenant. Team-issued work and response state with originating release/change.

```sql
round_id uuid NOT NULL
driver_id uuid NOT NULL
state text NOT NULL CHECK (state IN ('issued','received','acknowledged','cannot_comply','withdrawn','superseded','completed'))
issued_at timestamptz NOT NULL
received_at timestamptz
acknowledged_at timestamptz
release_id uuid
agreement_id uuid
origin text NOT NULL DEFAULT 'team' CHECK(origin IN ('team','freelance'))
```

Rules: See SQL constraints and command rules.

## driver_commitments

Owner E04; scope global. Global exclusion of overlapping committed work without cross-merchant data exposure.

```sql
driver_id uuid NOT NULL
tenant_id uuid NOT NULL
round_id uuid
trip_id uuid
busy_range tstzrange NOT NULL
state text NOT NULL CHECK (state IN ('pending','committed','cancelled','completed'))
```

Rules: CHECK (NOT isempty(busy_range)); CHECK (num_nonnulls(round_id,trip_id)=1); CHECK (NOT lower_inf(busy_range) AND NOT upper_inf(busy_range) AND lower_inc(busy_range) AND NOT upper_inc(busy_range))

## active_delivery_claims

Owner E04; scope tenant. Single live assignment/search owner per delivery; settled history in events.

```sql
delivery_id uuid NOT NULL
claim_kind text NOT NULL
round_id uuid
broadcast_id uuid
expires_at timestamptz
fulfillment_unit_id uuid NOT NULL
```

Rules: UNIQUE (tenant_id, fulfillment_unit_id); CHECK (num_nonnulls(round_id,broadcast_id)=1)

## delivery_attempts

Owner P05; scope tenant. Explicit execution attempt, not rewritten by retry/reschedule.

```sql
delivery_id uuid NOT NULL
stop_id uuid NOT NULL
driver_id uuid NOT NULL
attempt_number integer NOT NULL
state text NOT NULL CHECK (state IN ('pending','en_route','arrived','handed_over','completed','failed','cancelled'))
arrived_at timestamptz
handoff_at timestamptz
closed_at timestamptz
fulfillment_unit_id uuid NOT NULL
```

Rules: UNIQUE (tenant_id, delivery_id, attempt_number)

## custody_events

Owner P05; scope tenant. Append-only signed-actor physical collection/handoff/return/transfer record.

```sql
manifest_id uuid NOT NULL
attempt_id uuid
trip_id uuid
event_kind text NOT NULL
occurred_at timestamptz NOT NULL
received_at timestamptz NOT NULL
actor_id uuid NOT NULL
command_id uuid NOT NULL
round_id uuid
stop_id uuid
from_custodian_id uuid
to_custodian_id uuid
transfer_id uuid
```

Rules: UNIQUE (tenant_id, command_id, manifest_id, event_kind); CHECK (num_nonnulls(from_custodian_id,to_custodian_id)>=1); CHECK (from_custodian_id IS DISTINCT FROM to_custodian_id); CHECK (num_nonnulls(attempt_id,trip_id,round_id,stop_id,transfer_id)>=1); CHECK (event_kind IN ('pickup','handoff','return','transfer','trip_load','trip_receipt','correction'))

## custody_event_lines

Owner P05; scope tenant. Per-event physical line quantity. Net holdings validated under locked manifest.

```sql
event_id uuid NOT NULL
line_id uuid NOT NULL
quantity numeric(18,4) NOT NULL CHECK (quantity>0)
condition_code text NOT NULL
```

Rules: UNIQUE (tenant_id, event_id, line_id)

## custody_balances

Owner E04; scope tenant. Transactional projection of known held quantities by custodian; rebuildable from events.

```sql
line_id uuid NOT NULL
quantity numeric(18,4) NOT NULL CHECK (quantity>=0)
last_event_id uuid NOT NULL
custodian_id uuid NOT NULL
```

Rules: UNIQUE (tenant_id,line_id,custodian_id)

## handoffs

Owner P05; scope tenant. Physical delivery handoff separate from durable proof completion.

```sql
attempt_id uuid NOT NULL
receiver_kind text NOT NULL
receiver_contact_id uuid
place_code text
instruction_reference text
occurred_at timestamptz NOT NULL
actor_id uuid NOT NULL
proof_policy_id uuid NOT NULL
state text NOT NULL CHECK (state IN ('recorded','disputed','corrected'))
```

Rules: CHECK (receiver_kind IN ('recipient','alternate','unattended'))

## assets

Owner E05; scope tenant. Server-owned upload reservation and verified object metadata. No bytes inline.

```sql
object_key text NOT NULL UNIQUE
kind text NOT NULL
state text NOT NULL CHECK (state IN ('reserved','uploading','uploaded','scanning','verified','rejected','expired'))
mime_type text NOT NULL
byte_size bigint NOT NULL CHECK (byte_size>=0)
sha256 text NOT NULL
created_by uuid NOT NULL
retention_class text NOT NULL
verified_at timestamptz
purge_after timestamptz
```

Rules: See SQL constraints and command rules.

## proof_submissions

Owner P05; scope tenant. Two-phase evidence submission, policy snapshot and actor.

```sql
attempt_id uuid NOT NULL
handoff_id uuid NOT NULL
policy_version_id uuid NOT NULL
submitted_by uuid NOT NULL
state text NOT NULL CHECK (state IN ('pending','complete','disputed','retained_for_review','rejected'))
committed_at timestamptz
command_id uuid NOT NULL
```

Rules: UNIQUE (tenant_id, command_id)

## proof_items

Owner E05; scope tenant. Manifest confirmation/photo/signature/receiver evidence requirements and durable receipts.

```sql
submission_id uuid NOT NULL
item_kind text NOT NULL
asset_id uuid
line_id uuid
quantity numeric(18,4)
receiver_contact_id uuid
note text CHECK(length(note)<=2000)
location_observation_id uuid
state text NOT NULL CHECK (state IN ('pending','verified','invalidated','rejected'))
captured_at timestamptz
received_at timestamptz
invalidated_at timestamptz
invalidated_reason text
```

Rules: Same-tenant arrival-observation FK; a location item must reference this actual stop's observation/fact. Never infer location from a current map. Note text is preserved exactly. Isolated migration0005 freezes original submission/item content, revokes deletion and provides narrowly scoped state-only own-team commitment completion; older null fields remain null, never guessed or marked verified. See ADR-T06 and SQL constraints.

## issues

Owner P05; scope tenant. Typed incident: recipient/address/package/wait/cannot-complete/emergency.

```sql
delivery_id uuid
attempt_id uuid
round_id uuid
trip_id uuid
driver_id uuid
issue_type text NOT NULL
reason_code text NOT NULL
state text NOT NULL CHECK (state IN ('open','investigating','decided','resolved'))
detail text
reported_at timestamptz NOT NULL
reported_by uuid NOT NULL
```

Rules: See SQL constraints and command rules.

## issue_decisions

Owner P05; scope tenant. Attributed instructions/approval and customer/freelancer consent references.

```sql
issue_id uuid NOT NULL
decision_kind text NOT NULL
instruction jsonb NOT NULL
reason text
decided_by uuid NOT NULL
decided_at timestamptz NOT NULL
supersedes_id uuid
customer_agreement_reference text
```

Rules: See SQL constraints and command rules.

ADR-T08 · 2026-09-10: preserve the original nonblank Operations reason separately from driver-visible instructions. Migration0008 adds a nullable column without backfilling legacy reasons; existing immutable-row protection remains. Wait/escalate commits a decided issue, not completed physical recovery.

## return_tasks

Owner P05; scope tenant. Explicit return obligation and receiving site; related line quantities retained.

```sql
delivery_id uuid NOT NULL
manifest_id uuid NOT NULL
origin_issue_id uuid
round_id uuid
destination_site_id uuid NOT NULL
state text NOT NULL CHECK (state IN ('planned','in_transit','arrived','receiving','received','disputed','cancelled'))
agreement_id uuid
received_at timestamptz
custodian_id uuid
receiver_id uuid NOT NULL
```

Rules: See SQL constraints and command rules.

## change_proposals

Owner P07; scope tenant. Immutable proposed material diff plus consent/ack lifecycle.

```sql
round_id uuid NOT NULL
agreement_id uuid
base_version bigint NOT NULL
change_kind text NOT NULL
diff jsonb NOT NULL
impact jsonb NOT NULL
fare_delta_minor bigint
currency char(3)
state text NOT NULL CHECK (state IN ('pending','applied','acknowledged','accepted','declined','withdrawn','expired','superseded'))
expires_at timestamptz NOT NULL
created_by uuid NOT NULL
mode text NOT NULL CHECK(mode IN ('instruct','propose'))
```

Rules: See SQL constraints and command rules.

## change_responses

Owner P07; scope tenant. Actor response to a specific change version; cannot acknowledge a newer change.

```sql
proposal_id uuid NOT NULL
proposal_version bigint NOT NULL
driver_id uuid NOT NULL
response text NOT NULL
responded_at timestamptz NOT NULL
command_id uuid NOT NULL
```

Rules: UNIQUE (tenant_id, command_id)

## broadcasts

Owner P07; scope tenant. Operator-started city/pickup/date search with frozen offered revision.

```sql
city_id uuid NOT NULL
pickup_site_id uuid NOT NULL
service_date date NOT NULL
round_id uuid NOT NULL
state text NOT NULL CHECK (state IN ('searching','accepted','stopped','expired','no_acceptance'))
scope_revision integer NOT NULL
scope_hash text NOT NULL
fare_minor bigint NOT NULL CHECK (fare_minor>=0)
currency char(3) NOT NULL
search_policy_id uuid NOT NULL
started_by uuid NOT NULL
started_at timestamptz NOT NULL
expires_at timestamptz NOT NULL
```

Rules: See SQL constraints and command rules.

## broadcast_waves

Owner P07; scope tenant. Durable expansion schedule from operator-approved policy.

```sql
broadcast_id uuid NOT NULL
wave_number integer NOT NULL
radius_m integer NOT NULL CHECK (radius_m>0)
starts_at timestamptz NOT NULL
expires_at timestamptz NOT NULL
state text NOT NULL CHECK (state IN ('scheduled','active','closed','cancelled'))
```

Rules: UNIQUE (tenant_id, broadcast_id, wave_number); CHECK (expires_at>starts_at)

## offers

Owner P07; scope tenant. Private offer recipient/scope/deadline; redacted pre-acceptance projection.

```sql
broadcast_id uuid NOT NULL
driver_id uuid NOT NULL
scope_revision integer NOT NULL
scope_hash text NOT NULL
expires_at timestamptz NOT NULL
state text NOT NULL CHECK (state IN ('offered','accepted','declined','expired','taken','withdrawn'))
notified_at timestamptz
```

Rules: UNIQUE (tenant_id, broadcast_id, driver_id, scope_revision)

## freelance_agreements

Owner P07; scope tenant. Single accepted scope/economics snapshot; revisions append.

```sql
broadcast_id uuid NOT NULL
offer_id uuid NOT NULL
round_id uuid NOT NULL
driver_id uuid NOT NULL
accepted_revision integer NOT NULL
accepted_scope jsonb NOT NULL
fare_minor bigint NOT NULL CHECK (fare_minor>=0)
currency char(3) NOT NULL
accepted_at timestamptz NOT NULL
state text NOT NULL CHECK (state IN ('active','completed','cancelled'))
current_revision_id uuid
```

Rules: UNIQUE (tenant_id, broadcast_id); UNIQUE (tenant_id, offer_id)

## fare_adjustments

Owner P15; scope tenant. Immutable agreed change/cancellation/return compensation ledger entries.

```sql
agreement_id uuid NOT NULL
change_proposal_id uuid
amount_minor bigint NOT NULL
currency char(3) NOT NULL
reason_code text NOT NULL
authorization_reference text NOT NULL
event_id uuid NOT NULL
```

Rules: UNIQUE (tenant_id, event_id)

## settlement_records

Owner P15; scope tenant. Earned/due/paid/disputed external settlement facts; no platform-held balance implied.

```sql
agreement_id uuid NOT NULL
amount_minor bigint NOT NULL
currency char(3) NOT NULL
state text NOT NULL CHECK (state IN ('open','closed','cancelled'))
earned_at timestamptz
due_at timestamptz
paid_at timestamptz
payment_reference text
proof_asset_id uuid
earning_state text NOT NULL DEFAULT 'unearned' CHECK(earning_state IN ('unearned','earned','void'))
payment_state text NOT NULL DEFAULT 'unpaid' CHECK(payment_state IN ('unpaid','partially_paid','paid','overpaid'))
earned_minor bigint NOT NULL DEFAULT 0 CHECK(earned_minor>=0)
paid_minor bigint NOT NULL DEFAULT 0 CHECK(paid_minor>=0)
adjustment_minor bigint NOT NULL DEFAULT 0
```

Rules: See SQL constraints and command rules.

## settlement_events

Owner P15; scope tenant. Append-only finance provenance and dispute/correction event.

```sql
settlement_id uuid NOT NULL
event_kind text NOT NULL
actor_id uuid NOT NULL
occurred_at timestamptz NOT NULL
detail jsonb NOT NULL
```

Rules: See SQL constraints and command rules.

## transport_trips

Owner P08; scope tenant. Optional intercity physical leg; local city Round is separate.

```sql
origin_site_id uuid NOT NULL
destination_site_id uuid NOT NULL
driver_id uuid
vehicle_id uuid
service_date date NOT NULL
planned_departure_at timestamptz NOT NULL
planned_arrival_at timestamptz NOT NULL
actual_departure_at timestamptz
actual_arrival_at timestamptz
state text NOT NULL CHECK (state IN ('draft','scheduled','loading','departed','arrived','receiving','closed','cancelled'))
capacity_snapshot jsonb NOT NULL
receiving_principal_id uuid
```

Rules: CHECK (origin_site_id<>destination_site_id); CHECK (planned_arrival_at>planned_departure_at)

## trip_bookings

Owner P08; scope tenant. Manifest reservation on a trip, independent of loading/receipt.

```sql
trip_id uuid NOT NULL
delivery_id uuid NOT NULL
manifest_id uuid NOT NULL
state text NOT NULL CHECK (state IN ('booked','partially_loaded','loaded','partially_received','received','disputed','cancelled'))
booked_by uuid NOT NULL
custodian_id uuid
receiver_id uuid NOT NULL
```

Rules: UNIQUE (tenant_id, trip_id, delivery_id)

## trip_receipts

Owner P08; scope tenant. Destination receiving record with explicit discrepancies.

```sql
booking_id uuid NOT NULL
receiver_id uuid NOT NULL
received_at timestamptz NOT NULL
state text NOT NULL CHECK (state IN ('partial','complete','disputed'))
custody_event_id uuid NOT NULL
discrepancies jsonb NOT NULL
```

Rules: See SQL constraints and command rules.

## conversations

Owner P09; scope tenant. Either authorized relationship context or job context; no universal cross-tenant room.

```sql
kind text NOT NULL
round_id uuid
relationship_id uuid
subject text
closed_at timestamptz
trip_id uuid
```

Rules: CHECK (num_nonnulls(round_id,relationship_id,trip_id)=1)

## conversation_participants

Owner P09; scope tenant. Explicit participant and expiry; server recomputes access after reassignment.

```sql
conversation_id uuid NOT NULL
principal_id uuid NOT NULL
access_kind text NOT NULL
expires_at timestamptz
```

Rules: UNIQUE (tenant_id, conversation_id, principal_id)

## messages

Owner P09; scope tenant. Human/system messages with source context and idempotent send.

```sql
conversation_id uuid NOT NULL
sender_id uuid NOT NULL
client_message_id uuid NOT NULL
kind text NOT NULL
body text
state text NOT NULL CHECK (state IN ('received','delivered','read','failed'))
occurred_at timestamptz NOT NULL
received_at timestamptz
system_event_id uuid
```

Rules: UNIQUE (tenant_id, sender_id, client_message_id)

## message_attachments

Owner P09; scope tenant. Staged/sent attachment relation; location is typed, not arbitrary executable content.

```sql
message_id uuid NOT NULL
asset_id uuid
kind text NOT NULL
location geography(Point,4326)
accuracy_m numeric
observed_at timestamptz
caption text
```

Rules: See SQL constraints and command rules.

## message_receipts

Owner P09; scope tenant. Participant received/read acknowledgements only from valid channel/client evidence.

```sql
message_id uuid NOT NULL
principal_id uuid NOT NULL
received_at timestamptz
read_at timestamptz
```

Rules: UNIQUE (tenant_id, message_id, principal_id)

## call_sessions

Owner P09; scope tenant. Provider session/caller/callee; incoming/outgoing state and current job context.

```sql
conversation_id uuid NOT NULL
caller_id uuid NOT NULL
callee_id uuid
contact_id uuid
provider text
provider_reference text
state text NOT NULL CHECK (state IN ('initiated','ringing','connected','declined','missed','ended','failed'))
started_at timestamptz
ended_at timestamptz
```

Rules: See SQL constraints and command rules.

## call_events

Owner P09; scope tenant. Manual outcomes separate from provider-observed state.

```sql
call_id uuid NOT NULL
event_kind text NOT NULL
provenance text NOT NULL
actor_id uuid
occurred_at timestamptz NOT NULL
provider_event_key text
```

Rules: See SQL constraints and command rules.

## notifications

Owner P09; scope tenant. In-app actionable pointer; fetch current state on open.

```sql
principal_id uuid NOT NULL
event_id uuid NOT NULL
entity_type text NOT NULL
entity_id uuid NOT NULL
kind text NOT NULL
locale text NOT NULL
read_at timestamptz
expires_at timestamptz
```

Rules: UNIQUE (tenant_id, principal_id, event_id, kind)

## customer_tracking_tokens

Owner P12; scope tenant. Hashed audience-scoped revocable URL token.

```sql
delivery_id uuid NOT NULL
audience text NOT NULL
token_hash text NOT NULL UNIQUE
expires_at timestamptz NOT NULL
revoked_at timestamptz
policy_version_id uuid NOT NULL
```

Rules: See SQL constraints and command rules.

## notification_deliveries

Owner P12; scope tenant. Per-event audience/channel attempt identity with actual provider receipts.

```sql
delivery_id uuid
event_id uuid NOT NULL
audience_key text NOT NULL
channel text NOT NULL
provider text
state text NOT NULL CHECK (state IN ('queued','provider_accepted','delivered','failed','unknown'))
provider_reference text
last_attempt_at timestamptz
received_at timestamptz
idempotency_key text NOT NULL
```

Rules: UNIQUE (tenant_id, idempotency_key)

## provider_receipts

Owner P12; scope tenant. Deduplicated verified asynchronous provider facts; no automatic causal reinterpretation.

```sql
provider text NOT NULL
provider_account_key text NOT NULL
provider_event_key text NOT NULL
received_at timestamptz NOT NULL
event_kind text NOT NULL
payload_hash text NOT NULL
related_id uuid
```

Rules: UNIQUE (tenant_id, provider, provider_account_key, provider_event_key)

## writeback_tasks

Owner P12; scope tenant. Normalized delivery result sent to source under permission and version checks.

```sql
connection_id uuid NOT NULL
delivery_id uuid NOT NULL
domain_event_id uuid NOT NULL
kind text NOT NULL
state text NOT NULL CHECK (state IN ('queued','sending','succeeded','failed','unknown'))
attempts integer NOT NULL DEFAULT 0
next_attempt_at timestamptz
idempotency_key text NOT NULL
```

Rules: UNIQUE (tenant_id, idempotency_key)

## route_estimates

Owner P10; scope tenant. Licensed provider estimate with explicit profile/input/freshness; no unconditional provider-content storage.

```sql
round_id uuid
trip_id uuid
provider text NOT NULL
profile text NOT NULL
input_hash text NOT NULL
distance_m numeric CHECK (distance_m>=0)
duration_seconds integer CHECK (duration_seconds>=0)
traffic_aware boolean NOT NULL
calculated_at timestamptz NOT NULL
expires_at timestamptz NOT NULL
licensed_geometry_reference text
warnings jsonb NOT NULL
```

Rules: See SQL constraints and command rules.

## navigation_intents

Owner P10; scope tenant. Destination ledger deduplicates remount/retry; real SDK billing observed separately.

```sql
driver_id uuid NOT NULL
stop_id uuid NOT NULL
destination_version integer NOT NULL
provider text NOT NULL
destination_fingerprint text NOT NULL
state text NOT NULL CHECK (state IN ('created','opened','superseded','expired','failed'))
activated_at timestamptz
completed_at timestamptz
request_count integer NOT NULL DEFAULT 0
```

Rules: UNIQUE (tenant_id, driver_id, stop_id, destination_version, provider)

## tracking_entitlements

Owner E06; scope global. Server-enforced time/purpose boundary on driver tracking; no permanent team surveillance.

```sql
driver_id uuid NOT NULL
tenant_id uuid
round_id uuid
trip_id uuid
purpose text NOT NULL
starts_at timestamptz NOT NULL
ends_at timestamptz
revoked_at timestamptz
```

Rules: See SQL constraints and command rules.

## current_positions

Owner E06; scope global. One hot observation per driver; late historical batch cannot rewind it.

```sql
driver_id uuid NOT NULL UNIQUE
point geography(Point,4326) NOT NULL
observed_at timestamptz NOT NULL
received_at timestamptz NOT NULL
accuracy_m numeric NOT NULL CHECK (accuracy_m>=0)
source text NOT NULL
device_id uuid NOT NULL
sequence bigint NOT NULL
tracking_entitlement_id uuid NOT NULL
```

Rules: See SQL constraints and command rules.

## location_samples

Owner E06; scope global. Raw high-volume samples; production time partitions and short retention policy required.

```sql
driver_id uuid NOT NULL
device_id uuid NOT NULL
sample_sequence bigint NOT NULL
point geography(Point,4326) NOT NULL
observed_at timestamptz NOT NULL
received_at timestamptz NOT NULL
accuracy_m numeric NOT NULL CHECK (accuracy_m>=0)
tracking_entitlement_id uuid NOT NULL
expires_at timestamptz NOT NULL
```

Rules: UNIQUE (device_id, sample_sequence, observed_at)

## route_trails

Owner E06; scope tenant. Derived Rounds-owned actual trail and quality record where retention permits.

```sql
driver_id uuid NOT NULL
round_id uuid
trip_id uuid
trail geography(LineString,4326)
starts_at timestamptz NOT NULL
ends_at timestamptz NOT NULL
quality jsonb NOT NULL
purge_after timestamptz
```

Rules: See SQL constraints and command rules.

## command_receipts

Owner E04; scope global. Server command dedupe/state; scope_key computed from authenticated actor plus tenant.

```sql
scope_key text NOT NULL
actor_id uuid NOT NULL
tenant_id uuid
city_id uuid
command_key uuid NOT NULL
command_type text NOT NULL
request_hash text NOT NULL
authorization_round_id uuid
authorization_assignment_id uuid
state text NOT NULL CHECK (state IN ('in_progress','queued','committed','rejected','retained_for_review'))
result jsonb
error_code text
started_at timestamptz NOT NULL
completed_at timestamptz
```

Rules: UNIQUE (scope_key, command_key); CHECK (city_id IS NULL OR tenant_id IS NOT NULL); same-tenant city foreign key. Authorization Round/assignment are both null or both present. V2.3-r1, 2026-09-08: cached results preserve their original actor/tenant/city and job scope. W01.2 HTTP increment stores server-validated original pickup job IDs, never request bodies or device credentials. Existing receipts with no proven job scope are not backfilled; public status fails closed. The isolated API-identity migration makes these scope fields immutable.

## domain_events

Owner E04; scope tenant. Append-only authoritative facts plus aggregate version and cause identity.

```sql
aggregate_type text NOT NULL
aggregate_id uuid NOT NULL
aggregate_version bigint NOT NULL
event_type text NOT NULL
schema_version integer NOT NULL
actor_id uuid
command_id uuid
occurred_at timestamptz NOT NULL
received_at timestamptz NOT NULL
payload jsonb NOT NULL
trace_id text NOT NULL
worker_run_id uuid
```

Rules: UNIQUE (tenant_id, aggregate_type, aggregate_id, aggregate_version, event_type); CHECK(num_nonnulls(command_id,worker_run_id)=1)

## outbox_events

Owner E04; scope tenant. Transactional enqueue intention, retried until acknowledged; no external call in transaction.

```sql
event_id uuid NOT NULL
destination text NOT NULL
state text NOT NULL CHECK (state IN ('queued','sending','delivered','retry','failed'))
available_at timestamptz NOT NULL
attempt_count integer NOT NULL DEFAULT 0
last_error_code text
```

Rules: UNIQUE (tenant_id, event_id, destination)

## job_runs

Owner E07; scope global. Durable scheduled job state; pgmq contains IDs, not sensitive payload copies.

```sql
job_kind text NOT NULL
tenant_id uuid
dedupe_key text NOT NULL UNIQUE
state text NOT NULL CHECK (state IN ('queued','running','retry','completed','failed','cancelled'))
available_at timestamptz NOT NULL
lease_until timestamptz
attempt_count integer NOT NULL DEFAULT 0
payload_reference text
last_error_code text
```

Rules: See SQL constraints and command rules.

## consumer_receipts

Owner E07; scope global. Idempotent event/job consumer effect receipt; tenant check still required.

```sql
consumer_key text NOT NULL
event_id uuid NOT NULL
effect_key text NOT NULL
completed_at timestamptz NOT NULL
```

Rules: UNIQUE (consumer_key, event_id, effect_key)

## audit_access

Owner E08; scope tenant. Privileged sensitive read/export/access provenance.

```sql
actor_id uuid NOT NULL
entity_type text NOT NULL
entity_id uuid
purpose text NOT NULL
occurred_at timestamptz NOT NULL
trace_id text NOT NULL
```

Rules: See SQL constraints and command rules.

## export_jobs

Owner P11; scope tenant. Asynchronous scoped history/subject export and signed download lifecycle.

```sql
requested_by uuid NOT NULL
kind text NOT NULL
filters jsonb NOT NULL
as_of_at timestamptz NOT NULL
state text NOT NULL CHECK (state IN ('queued','running','ready','failed','expired'))
asset_id uuid
expires_at timestamptz
```

Rules: See SQL constraints and command rules.

## privacy_requests

Owner E08; scope tenant. Access/deletion workflow with verified subject scope and retention/legal hold checks.

```sql
requested_by uuid NOT NULL
subject_reference text NOT NULL
kind text NOT NULL
state text NOT NULL CHECK (state IN ('requested','reviewing','approved','rejected','executing','completed','held'))
due_at timestamptz
decision jsonb
```

Rules: See SQL constraints and command rules.

## retention_holds

Owner E08; scope tenant. Preserve selected evidence for incident/dispute without disabling all purges.

```sql
entity_type text NOT NULL
entity_id uuid NOT NULL
reason_code text NOT NULL
authorized_by uuid NOT NULL
expires_at timestamptz
```

Rules: See SQL constraints and command rules.

## slot_occurrence_bindings

Owner P03; scope tenant. Single current admission pointer per template/date; lock this row while resolving revisions and reserving capacity. Old occurrences remain promise evidence.

```sql
template_id uuid NOT NULL
service_date date NOT NULL
occurrence_id uuid NOT NULL
```

Rules: UNIQUE (tenant_id,template_id,service_date)

## account_events

Owner E04; scope global. Private account/driver events for commands without a tenant; never publish into a merchant channel.

```sql
principal_id uuid NOT NULL
aggregate_type text NOT NULL
aggregate_id uuid NOT NULL
aggregate_version bigint NOT NULL
event_type text NOT NULL
schema_version integer NOT NULL
actor_id uuid
command_id uuid NOT NULL
occurred_at timestamptz NOT NULL
received_at timestamptz NOT NULL
payload jsonb NOT NULL
trace_id text NOT NULL
```

Rules: UNIQUE (principal_id,aggregate_type,aggregate_id,aggregate_version,event_type)

## account_outbox

Owner E04; scope global. Durable private account event delivery; separate from tenant outbox.

```sql
event_id uuid NOT NULL
destination text NOT NULL
state text NOT NULL CHECK (state IN ('queued','sending','delivered','retry','failed'))
available_at timestamptz NOT NULL
attempt_count integer NOT NULL DEFAULT 0
last_error_code text
```

Rules: UNIQUE (event_id,destination)

## custodians

Owner P05; scope tenant. V2 custodians; see owning command and state contracts.

```sql
kind text NOT NULL
principal_id uuid
site_id uuid
```

Rules: CHECK ((kind='principal' AND principal_id IS NOT NULL AND site_id IS NULL) OR (kind='site' AND site_id IS NOT NULL AND principal_id IS NULL)); UNIQUE (tenant_id,principal_id); UNIQUE (tenant_id,site_id); CHECK (kind IN ('principal','site'))

## custody_transfers

Owner P05; scope tenant. V2 custody transfers; see owning command and state contracts.

```sql
manifest_id uuid NOT NULL
from_custodian_id uuid NOT NULL
to_custodian_id uuid NOT NULL
initiated_by uuid NOT NULL
received_by uuid
state text NOT NULL CHECK (state IN ('pending','partially_received','received','declined','cancelled','expired'))
expires_at timestamptz NOT NULL
received_at timestamptz
```

Rules: CHECK (from_custodian_id<>to_custodian_id); CHECK (state NOT IN ('partially_received','received') OR (received_at IS NOT NULL AND received_by IS NOT NULL)); CHECK (expires_at>created_at)

## custody_transfer_lines

Owner P05; scope tenant. V2 custody transfer lines; see owning command and state contracts.

```sql
transfer_id uuid NOT NULL
line_id uuid NOT NULL
requested_quantity numeric(18,4) NOT NULL CHECK(requested_quantity>0)
received_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(received_quantity>=0)
```

Rules: UNIQUE(tenant_id,transfer_id,line_id); CHECK(received_quantity<=requested_quantity)

## return_task_lines

Owner P05; scope tenant. V2 return task lines; see owning command and state contracts.

```sql
return_task_id uuid NOT NULL
line_id uuid NOT NULL
expected_quantity numeric(18,4) NOT NULL CHECK(expected_quantity>0)
received_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(received_quantity>=0)
```

Rules: UNIQUE(tenant_id,return_task_id,line_id); CHECK(received_quantity<=expected_quantity)

## trip_booking_lines

Owner P08; scope tenant. V2 trip booking lines; see owning command and state contracts.

```sql
trip_booking_id uuid NOT NULL
line_id uuid NOT NULL
expected_quantity numeric(18,4) NOT NULL CHECK(expected_quantity>0)
received_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(received_quantity>=0)
```

Rules: UNIQUE(tenant_id,trip_booking_id,line_id); CHECK(received_quantity<=expected_quantity)

## remaining_obligations

Owner P05; scope tenant. V2 remaining obligations; see owning command and state contracts.

```sql
delivery_id uuid NOT NULL
manifest_id uuid NOT NULL
decision_id uuid NOT NULL
state text NOT NULL CHECK (state IN ('open','planned','resolved','cancelled'))
destination_site_id uuid
resolved_at timestamptz
```

Rules: See SQL constraints and command rules.

## remaining_obligation_lines

Owner P05; scope tenant. V2 remaining obligation lines; see owning command and state contracts.

```sql
obligation_id uuid NOT NULL
line_id uuid NOT NULL
quantity numeric(18,4) NOT NULL CHECK(quantity>0)
resolved_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(resolved_quantity>=0)
```

Rules: UNIQUE(tenant_id,obligation_id,line_id); CHECK(resolved_quantity<=quantity)

## inbound_dependencies

Owner P08; scope tenant. V2 inbound dependencies; see owning command and state contracts.

```sql
delivery_id uuid NOT NULL
booking_id uuid NOT NULL
destination_site_id uuid NOT NULL
state text NOT NULL CHECK (state IN ('awaiting_receipt','partial','ready','discrepancy','cancelled'))
expected_available_at timestamptz
last_receipt_id uuid
```

Rules: UNIQUE(tenant_id,delivery_id,booking_id)

## realtime_grants

Owner E08; scope tenant. V2 realtime grants; see owning command and state contracts.

```sql
principal_id uuid NOT NULL
topic text NOT NULL
expires_at timestamptz NOT NULL
revoked_at timestamptz
```

Rules: CHECK (expires_at>created_at)

## agreement_revisions

Owner P07; scope tenant. Append-only accepted amendments; the agreement initial accepted snapshot never changes.

```sql
agreement_id uuid NOT NULL
revision integer NOT NULL CHECK(revision>0)
proposal_id uuid
accepted_by uuid NOT NULL
scope jsonb NOT NULL
fare_minor bigint NOT NULL CHECK(fare_minor>=0)
currency char(3) NOT NULL
accepted_at timestamptz NOT NULL
```

Rules: UNIQUE(tenant_id,agreement_id,revision); UNIQUE(tenant_id,agreement_id,id)

## driver_tracking_grants

Owner E08; scope tenant. Server-issued purpose/time limited entitlement to an operating driver location; a relationship alone grants no off-duty GPS.

```sql
driver_id uuid NOT NULL
purpose text NOT NULL CHECK(purpose IN ('team_shift','accepted_round','accepted_trip','recovery'))
round_id uuid
trip_id uuid
shift_id uuid
starts_at timestamptz NOT NULL
ends_at timestamptz NOT NULL
revoked_at timestamptz
tracking_entitlement_id uuid NOT NULL
```

Rules: CHECK(ends_at>starts_at); CHECK(num_nonnulls(round_id,trip_id,shift_id)=1)

## fulfillment_units

Owner P05; scope tenant. One whole-delivery execution identity at launch. Split/child units are prohibited.

```sql
delivery_id uuid NOT NULL
manifest_id uuid NOT NULL
parent_unit_id uuid
remaining_obligation_id uuid
state text NOT NULL CHECK(state IN ('open','collected','delivered','returned','cancelled'))
collected_at timestamptz
completed_at timestamptz
```

Rules: UNIQUE(tenant_id,delivery_id); CHECK(parent_unit_id IS NULL AND remaining_obligation_id IS NULL)

## fulfillment_unit_lines

Owner P05; scope tenant. V2.3 fulfillment unit lines; see consolidated domain specification.

```sql
unit_id uuid NOT NULL
line_id uuid NOT NULL
allocated_quantity numeric(18,4) NOT NULL CHECK(allocated_quantity>0)
delivered_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(delivered_quantity>=0)
returned_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(returned_quantity>=0)
cancelled_quantity numeric(18,4) NOT NULL DEFAULT 0 CHECK(cancelled_quantity>=0)
```

Rules: UNIQUE(tenant_id,unit_id,line_id); CHECK(delivered_quantity+returned_quantity+cancelled_quantity<=allocated_quantity)

## offline_evidence_observations

Owner E05; scope tenant. V2.3 offline evidence observations; see consolidated domain specification.

```sql
principal_id uuid NOT NULL
device_id uuid NOT NULL
observation_id uuid NOT NULL
assignment_id uuid NOT NULL
assignment_version bigint NOT NULL
kind text NOT NULL
observed_at timestamptz NOT NULL
observation jsonb NOT NULL
asset_ids uuid[] NOT NULL
incident_id uuid NOT NULL
```

Rules: UNIQUE(tenant_id,device_id,observation_id)

## settlement_payments

Owner P15; scope tenant. V2.3 settlement payments; see consolidated domain specification.

```sql
settlement_id uuid NOT NULL
amount_minor bigint NOT NULL CHECK(amount_minor>0)
direction text NOT NULL CHECK(direction IN ('payment','refund'))
currency char(3) NOT NULL
external_reference text NOT NULL
occurred_at timestamptz NOT NULL
recorded_by uuid NOT NULL
command_id uuid NOT NULL
proof_asset_id uuid
```

Rules: UNIQUE(tenant_id,command_id); UNIQUE(tenant_id,settlement_id,direction,external_reference)

## dispute_cases

Owner P15; scope tenant. V2.3 dispute cases; see consolidated domain specification.

```sql
kind text NOT NULL CHECK(kind IN ('financial','evidence'))
agreement_id uuid
proof_submission_id uuid
state text NOT NULL CHECK(state IN ('open','investigating','decided','closed'))
opened_by uuid NOT NULL
reason_code text NOT NULL
decision text
decided_by uuid
decided_at timestamptz
prior_proof_state text
replacement_proof_submission_id uuid
```

Rules: CHECK((kind='financial' AND agreement_id IS NOT NULL AND proof_submission_id IS NULL) OR (kind='evidence' AND proof_submission_id IS NOT NULL AND agreement_id IS NULL))

## gps_retention_holds

Owner E08; scope global. Restricted retention administration; no dispatcher access.

```sql
driver_id uuid NOT NULL
starts_at timestamptz NOT NULL
ends_at timestamptz NOT NULL
reason text NOT NULL
authorized_by uuid NOT NULL
released_at timestamptz
```

Rules: See SQL constraints and command rules.

## gps_purge_audit

Owner E08; scope global. Restricted retention administration; no dispatcher access.

```sql
run_id uuid NOT NULL UNIQUE
deleted_count integer NOT NULL CHECK(deleted_count>=0)
occurred_at timestamptz NOT NULL DEFAULT now()
```

Rules: See SQL constraints and command rules.

## Complete-order enforcement

V23-COMPLETE-ORDER.sql makes fulfillment_units one-to-one with deliveries and prohibits child/residual units. Deferred checks from deliveries, units, manifests, manifest lines and unit lines enforce full allocation of every current line, including omitted allocations and manifest-only quantity edits. Matching pre-collection revisions can commit atomically. ConfirmPickup must additionally check exact submitted quantities and physical readiness. Fresh reference only; production migration remains a build/release task.
