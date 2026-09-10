# Command contracts — V2.3-r1

Generated from COMMAND-CATALOG and mirrored to OpenAPI. Ready does not mean implemented. See decisions/02 for engineering decisions and Build Spec DEC-01 for the gated workspace endpoint.

## CreateTenant

Capability: `authenticated.create_workspace`. Input: `CreateTenantPayload`. Result: `CreateTenantData`.

name:string country_code:country timezone:string currency:currency

DEC-01 pending: endpoint disabled with FEATURE_NOT_ENABLED and no domain writes. Existing tenants continue working. Once authority is chosen, create owner membership/settings atomically and dedupe onboarding intent.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: []

Errors: FEATURE_NOT_ENABLED, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, POLICY_NOT_CONFIGURED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: tenant.created

## InviteMember

Capability: `members.manage`. Input: `InviteMemberPayload`. Result: `InviteMemberData`.

tenant_id:uuid contact:string role_code:enum city_ids:uuids

Store hashed token and pending invitation; send through outbox

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "tenant_id", "aggregate_type": "tenants", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: membership.invited

## AcceptInvitation

Capability: `authenticated.invite_accept`. Input: `AcceptInvitationPayload`. Result: `AcceptInvitationData`.

invitation_token:string

Lock invitation; match authenticated identity; consume once and link driver/relationship

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: []

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: membership.joined

## ChangeMemberAccess

Capability: `members.manage`. Input: `ChangeMemberAccessPayload`. Result: `ChangeMemberAccessData`.

membership_id:uuid role_code:enum city_ids:uuids enabled:boolean

Update grants/revision; revoke subscriptions and new command authority; preserve work recovery

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "membership_id", "aggregate_type": "memberships", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: membership.access_changed

## SaveCity

Capability: `workspace.configure`. Input: `SaveCityPayload`. Result: `SaveCityData`.

city_id?:optional_uuid name:string timezone:string country_code:country

Validate named timezone and unique scope; audit

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "city_id", "aggregate_type": "cities", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: city.saved

## SaveSite

Capability: `workspace.configure`. Input: `SaveSitePayload`. Result: `SaveSiteData`.

site_id?:optional_uuid city_id:uuid name:string address_text:string point?:optional_point site_type:enum

Validate city/site scope and existing-work consequences

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "site_id", "aggregate_type": "sites", "when": "when non-null and record already exists"}, {"payload_field": "city_id", "aggregate_type": "cities", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: site.saved

## SaveBrand

Capability: `workspace.configure`. Input: `SaveBrandPayload`. Result: `SaveBrandData`.

brand_id?:optional_uuid name:string

Tenant-scoped brand update

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "brand_id", "aggregate_type": "brands", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: brand.saved

## SetFeature

Capability: `workspace.configure`. Input: `SetFeaturePayload`. Result: `SetFeatureData`.

feature_key:string enabled:boolean consequence_ack:boolean tenant_id:uuid

Check entitlement; preserve accepted work and recovery; emit invalidation

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "tenant_id", "aggregate_type": "tenants", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: feature.changed

## SavePolicy

Capability: `policy.manage`. Input: `SavePolicyPayload`. Result: `SavePolicyData`.

policy_kind:enum scope_key:string schema_version:positive_integer policy:policy effective_at:instant binding_id?:optional_uuid

Insert immutable typed revision and compare-and-swap binding; check policy-specific impact

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "binding_id", "aggregate_type": "policy_bindings", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, POLICY_OUT_OF_BOUNDS, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: policy.revised

## CreateIntakeBatch

Capability: `deliveries.create`. Input: `CreateIntakeBatchPayload`. Result: `CreateIntakeBatchData`.

input_kind:enum asset_ids:uuids text?:optional_string

Reserve input references; schedule parse job; no delivery/assignment

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: []

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: intake.batch_created

## SaveDeliveryDraft

Capability: `deliveries.create`. Input: `SaveDeliveryDraftPayload`. Result: `SaveDeliveryDraftData`.

draft_id?:optional_uuid draft:delivery_draft

Validate typed draft under current deliveries.create city authority. Creation without draft_id has zero expected roots and is serialized by the original command receipt; a supplied draft_id is update-only and requires exactly its current intake_drafts version. Preserve each submitted manual revision and original text immutably; invalidate dependent suggestions/review on edit. A save creates no delivery, slot hold, preparation/custody fact or assignment. Unmapped existing and source-backed drafts remain unchanged until their compatibility adapter exists (ADR-T09).

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "draft_id", "aggregate_type": "intake_drafts", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: intake.draft_saved

## ExtractDraft

Capability: `deliveries.create`. Input: `ExtractDraftPayload`. Result: `OperationResult`.

draft_id:uuid input_hash:string

Schedule parser/AI; result must match current input hash

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "draft_id", "aggregate_type": "intake_drafts", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, PROVIDER_UNAVAILABLE, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: intake.extraction_requested

## ReviewAddress

Capability: `deliveries.review`. Input: `ReviewAddressPayload`. Result: `ReviewAddressData`.

draft_id:uuid suggestion_id?:optional_uuid input_hash:string decision:review_decision address_text:string point?:optional_point

Record before/after source and reviewer; do not infer entrance confirmation

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "draft_id", "aggregate_type": "intake_drafts", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: address.reviewed, round.readiness_changed

## CommitDelivery

Capability: `deliveries.create`. Input: `CommitDeliveryPayload`. Result: `CommitDeliveryData`.

draft_id:uuid reservation_id?:optional_uuid

Lock draft/slot/source identity; normalize contacts/manifest; consume hold/create delivery atomically

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "draft_id", "aggregate_type": "intake_drafts", "when": "required"}, {"payload_field": "reservation_id", "aggregate_type": "slot_reservations", "when": "when non-null and record already exists"}]

Errors: ADDRESS_REVIEW_REQUIRED, HOLD_EXPIRED, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, POLICY_NOT_CONFIGURED, SLOT_CLOSED, SLOT_EXPIRED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: delivery.created

## CommitIntakeBatch

Capability: `deliveries.create`. Input: `CommitIntakeBatchPayload`. Result: `OperationResult`.

batch_id:uuid drafts:versioned_ids

Per-row idempotent commit; explicit partial results and stable child command identities

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "batch_id", "aggregate_type": "intake_batches", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: intake.batch_committed

## DiscardDraft

Capability: `deliveries.create`. Input: `DiscardDraftPayload`. Result: `DiscardDraftData`.

draft_id:uuid

Release hold; retain permitted source/audit; committed delivery unaffected

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "draft_id", "aggregate_type": "intake_drafts", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: intake.draft_discarded

## SaveSlotTemplate

Capability: `calendar.manage`. Input: `SaveSlotTemplatePayload`. Result: `SaveSlotTemplateData`.

template_id?:optional_uuid city_id:uuid site_id?:optional_uuid brand_id?:optional_uuid name:string slot:slot_rule

Create immutable effective version; impact open occurrences; do not rewrite promises

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "city_id", "aggregate_type": "cities", "when": "required"}, {"payload_field": "site_id", "aggregate_type": "sites", "when": "when non-null and record already exists"}, {"payload_field": "brand_id", "aggregate_type": "brands", "when": "when non-null and record already exists"}, {"payload_field": "template_id", "aggregate_type": "slot_templates", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: slot.template_revised

## SetSlotOverride

Capability: `calendar.manage`. Input: `SetSlotOverridePayload`. Result: `SetSlotOverrideData`.

template_id:uuid service_date:date closed:boolean replacement?:optional_slot reason:string

Lock template/date; new occurrence revision; retain existing commitments and show overcommit

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "template_id", "aggregate_type": "slot_templates", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: slot.override_saved

## RemoveSlotOverride

Capability: `calendar.manage`. Input: `RemoveSlotOverridePayload`. Result: `RemoveSlotOverrideData`.

override_id:uuid reason:string consequence_ack:boolean

Resolve recurring fallback; existing promise snapshots preserved

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "override_id", "aggregate_type": "slot_overrides", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: slot.override_removed

## HoldSlot

Capability: `deliveries.create`. Input: `HoldSlotPayload`. Result: `SlotReservationResult`.

occurrence_id:uuid draft_id:uuid source_key:string

Lock occurrence/admission revision; expire due holds; validate cap/cutoff; dedupe draft

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "occurrence_id", "aggregate_type": "slot_occurrences", "when": "required"}, {"payload_field": "draft_id", "aggregate_type": "intake_drafts", "when": "required"}]

Errors: CUTOFF_PASSED, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, SLOT_CLOSED, SLOT_EXPIRED, SLOT_FULL, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: slot.reserved

## ReleaseSlotHold

Capability: `deliveries.create`. Input: `ReleaseSlotHoldPayload`. Result: `SlotReservationResult`.

reservation_id:uuid

Only own authorized uncommitted hold released; no physical work cancellation

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "reservation_id", "aggregate_type": "slot_reservations", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: slot.reservation_released

## MoveDeliveryWindow

Capability: `deliveries.change`. Input: `MoveDeliveryWindowPayload`. Result: `SlotReservationResult`.

delivery_id:uuid target_occurrence_id?:optional_uuid window:window reason:string customer_agreement_reference?:optional_string

Lock both slot capacities and delivery; released work requires change proposal/consent, otherwise atomic move

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "required"}]

Errors: CONSENT_REQUIRED, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, SLOT_FULL, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: delivery.window_changed

## SaveShiftTemplate

Capability: `fleet.manage`. Input: `SaveShiftTemplatePayload`. Result: `SaveShiftTemplateData`.

template_id?:optional_uuid relationship_id:uuid city_id:uuid weekdays:weekdays start_minute:minute end_minute:extended_minute timezone:string valid_from:date valid_to?:optional_date vehicle_id?:optional_uuid

Validate date/overnight recurrence and dependent work

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "relationship_id", "aggregate_type": "driver_relationships", "when": "required"}, {"payload_field": "city_id", "aggregate_type": "cities", "when": "required"}, {"payload_field": "vehicle_id", "aggregate_type": "vehicles", "when": "when non-null and record already exists"}, {"payload_field": "template_id", "aggregate_type": "shift_templates", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: shift.template_saved

## SetShiftOccurrence

Capability: `fleet.manage`. Input: `SetShiftOccurrencePayload`. Result: `SetShiftOccurrenceData`.

shift_id?:optional_uuid relationship_id:uuid city_id:uuid service_date:date window:window enabled:boolean vehicle_id?:optional_uuid reason:string

Resolve override; validate overlap and impact; retain attendance

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "shift_id", "aggregate_type": "shift_occurrences", "when": "when non-null and record already exists"}, {"payload_field": "relationship_id", "aggregate_type": "driver_relationships", "when": "required"}, {"payload_field": "city_id", "aggregate_type": "cities", "when": "required"}, {"payload_field": "vehicle_id", "aggregate_type": "vehicles", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: shift.changed

## SaveVehicle

Capability: `fleet.manage`. Input: `SaveVehiclePayload`. Result: `SaveVehicleData`.

vehicle_id?:optional_uuid vehicle_type_id:uuid profile_id:uuid plate:string status:string

Validate capability profile and affected commitments

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "vehicle_id", "aggregate_type": "vehicles", "when": "when non-null and record already exists"}, {"payload_field": "profile_id", "aggregate_type": "vehicle_profiles", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: vehicle.saved

## SaveVehicleProfile

Capability: `fleet.manage`. Input: `SaveVehicleProfilePayload`. Result: `SaveVehicleProfileData`.

profile_id?:optional_uuid name:string vehicle_type_id:uuid max_stops:positive_integer load_seconds:nonnegative_integer reload_seconds:nonnegative_integer return_required:boolean cargo_limits:cargo_limits

Version profile; class units/zero-prohibited semantics; snapshot current commitments

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "profile_id", "aggregate_type": "vehicle_profiles", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, UNSUPPORTED_PROFILE, VALIDATION_FAILED

Fact outcomes: vehicle.profile_saved

## SaveCargoClass

Capability: `fleet.manage`. Input: `SaveCargoClassPayload`. Result: `SaveCargoClassData`.

cargo_class_id?:optional_uuid code:string name:string unit:string discrete:boolean

Do not silently change existing physical quantity unit

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "cargo_class_id", "aggregate_type": "cargo_classes", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: cargo.class_saved

## SaveHandlingRule

Capability: `fleet.manage`. Input: `SaveHandlingRulePayload`. Result: `SaveHandlingRuleData`.

rule_id?:optional_uuid handling_key:string profile_id:uuid effect:handling_effect

Differentiate preferred, required, prohibited and allowed; detect contradictory rules

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "rule_id", "aggregate_type": "handling_rules", "when": "when non-null and record already exists"}, {"payload_field": "profile_id", "aggregate_type": "vehicle_profiles", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: handling.rule_saved

## SaveDriverRelationship

Capability: `fleet.manage`. Input: `SaveDriverRelationshipPayload`. Result: `SaveDriverRelationshipData`.

relationship_id?:optional_uuid driver_id:uuid relationship_kind:relationship_kind outside_work_allowed:boolean status?:enum

Authenticated invite/join required; cannot manufacture global verification status=active/suspended is explicit (default active); suspension preserves current duties and prevents new assignment. Ending uses ArchiveFleetResource(resource_type=driver_relationship,archived=true).

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "relationship_id", "aggregate_type": "driver_relationships", "when": "when non-null and record already exists"}, {"payload_field": "driver_id", "aggregate_type": "drivers", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: driver.relationship_saved, fleet.resource_archived

## ArchiveFleetResource

Capability: `fleet.manage`. Input: `ArchiveFleetResourcePayload`. Result: `ArchiveFleetResourceData`.

resource_type:fleet_resource_type resource_id:uuid archived:boolean reason:string

Outstanding obligations require explicit resolution; immutable references retained

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "resource_id", "aggregate_type_by_discriminator": {"driver_relationship": "driver_relationships", "vehicle": "vehicles"}, "when": "required; resource_type selects table"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: fleet.resource_archived

## GeneratePlan

Capability: `plans.edit`. Input: `GeneratePlanPayload`. Result: `OperationResult`.

city_id:uuid service_date:date delivery_ids?:uuids fulfillment_unit_ids?:array

Capture input/policy hash; async planner result cannot overwrite current plan Whole-delivery selection only; one fulfillment unit per delivery; split selectors cannot create residual work.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "city_id", "aggregate_type": "cities", "when": "required"}, {"payload_field": "delivery_ids[]", "aggregate_type": "deliveries", "when": "each supplied existing ID"}, {"payload_field": "fulfillment_unit_ids[]", "aggregate_type": "fulfillment_units", "when": "every selected existing ID"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: plan.generation_requested

## PreviewPlanMove

Capability: `plans.edit`. Input: `PreviewPlanMovePayload`. Result: `PreviewPlanMoveData`.

plan_id:uuid move:plan_move

No operational mutation; return expiring proposal with before/after impact and hash

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "plan_id", "aggregate_type": "plans", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: plan.move_previewed

## ApplyPlanProposal

Capability: `plans.edit`. Input: `ApplyPlanProposalPayload`. Result: `ApplyPlanProposalData`.

plan_id:uuid proposal_id:uuid input_hash:string override_reason?:optional_string

Lock affected work/driver rows; revalidate versions/constraints; atomic draft apply

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "plan_id", "aggregate_type": "plans", "when": "required"}, {"payload_field": "proposal_id", "aggregate_type": "plan_proposals", "when": "required"}]

Errors: DRIVER_CONFLICT, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, PHYSICAL_INCOMPATIBILITY, STALE_VERSION, VALIDATION_FAILED, VEHICLE_CONFLICT, VEHICLE_INCOMPATIBLE

Fact outcomes: plan.changed, round.readiness_changed

## SavePlan

Capability: `plans.edit`. Input: `SavePlanPayload`. Result: `SavePlanData`.

plan_id:uuid

Persist current draft; do not release work

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "plan_id", "aggregate_type": "plans", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: plan.saved

## ReleasePlan

Capability: `plans.release`. Input: `ReleasePlanPayload`. Result: `StagedPlanResult`.

plan_id:uuid proposal_id:uuid uncovered_delivery_ids:uuids consequence_ack:boolean round_ids:uuids input_hash:hash

Lock claims/driver commitments; write release and assignments/outbox atomically Reuse the current staged team assignment when present, updating its release reference/version; create only if none exists. Validate input_hash against proposal and current inputs.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "plan_id", "aggregate_type": "plans", "when": "required"}, {"payload_field": "proposal_id", "aggregate_type": "plan_proposals", "when": "required"}, {"payload_field": "round_ids[]", "aggregate_type": "rounds", "when": "each supplied existing ID"}]

Errors: ADDRESS_REVIEW_REQUIRED, CLAIM_TAKEN, DRIVER_CONFLICT, IDEMPOTENCY_CONFLICT, INBOUND_DISCREPANCY, INBOUND_NOT_RECEIVED, NOT_AUTHORIZED, PHYSICAL_INCOMPATIBILITY, PICKUP_NOT_READY, STALE_VERSION, VALIDATION_FAILED, VEHICLE_CONFLICT, VEHICLE_INCOMPATIBLE

Fact outcomes: plan.released, round.readiness_changed

## AcknowledgeAssignment

Capability: `driver.assigned_work`. Input: `AcknowledgeAssignmentPayload`. Result: `AcknowledgeAssignmentData`.

assignment_id:uuid response:assignment_response reason?:optional_string

Actor must be assigned driver; no fabricated acknowledgement

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "assignment_id", "aggregate_type": "assignments", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: assignment.responded

## StartShift

Capability: `driver.team_shift`. Input: `StartShiftPayload`. Result: `StartShiftData`.

shift_id:uuid

Validate driver/shift policy and dedupe attendance; no automatic open Network

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "shift_id", "aggregate_type": "shift_occurrences", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: shift.started

## EndShift

Capability: `driver.team_shift`. Input: `EndShiftPayload`. Result: `EndShiftData`.

shift_id:uuid

Check outstanding work/custody; clock-out event separate from declaration

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "shift_id", "aggregate_type": "shift_occurrences", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: shift.ended

## RequestAttendanceCorrection

Capability: `driver.team_shift`. Input: `RequestAttendanceCorrectionPayload`. Result: `RequestAttendanceCorrectionData`.

shift_id:uuid corrected_end_at:instant reason:string

Append request; original attendance unchanged

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "shift_id", "aggregate_type": "shift_occurrences", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: attendance.correction_requested

## DecideAttendanceCorrection

Capability: `attendance.review`. Input: `DecideAttendanceCorrectionPayload`. Result: `DecideAttendanceCorrectionData`.

request_event_id:uuid approved:boolean reason:string shift_id:uuid

Append manager decision; recompute derived totals

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "shift_id", "aggregate_type": "shift_occurrences", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: attendance.correction_decided

## SetAvailability

Capability: `driver.availability`. Input: `SetAvailabilityPayload`. Result: `SetAvailabilityData`.

intent:availability_intent available_after?:optional_instant driver_id:uuid

Verify global actor eligibility and employer policy; no cancellation of accepted work

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "driver_id", "aggregate_type": "drivers", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: driver.availability_changed

## SetContactPermissions

Capability: `driver.relationship_preferences`. Input: `SetContactPermissionsPayload`. Result: `SetContactPermissionsData`.

relationship_id:uuid messages_allowed:boolean requests_allowed:boolean

Driver-only scoped consent and revocation; never global unknown merchant opt-in

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "relationship_id", "aggregate_type": "driver_relationships", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: driver.contact_permission_changed

## AskAvailability

Capability: `drivers.contact_known`. Input: `AskAvailabilityPayload`. Result: `AskAvailabilityData`.

relationship_id:uuid requested_window?:optional_window message:string requested_duration_seconds:positive_integer

Check opt-in; notify without reservation

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "relationship_id", "aggregate_type": "driver_relationships", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: availability.requested

## ReplyAvailability

Capability: `driver.relationship_preferences`. Input: `ReplyAvailabilityPayload`. Result: `ReplyAvailabilityData`.

request_id:uuid response:enum available_after?:optional_instant

Check driver/deadline; no work commitment

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "request_id", "aggregate_type": "availability_requests", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: availability.responded

## SaveDriverProfile

Capability: `driver.self`. Input: `SaveDriverProfilePayload`. Result: `SaveDriverProfileData`.

display_name:string preferred_locale:string photo_asset_id?:optional_uuid driver_id:uuid

Own principal only; locale change preserves work

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "driver_id", "aggregate_type": "drivers", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: driver.profile_saved

## SaveDriverVehicle

Capability: `driver.self`. Input: `SaveDriverVehiclePayload`. Result: `SaveDriverVehicleData`.

vehicle_id?:optional_uuid vehicle_type_id?:uuid plate?:string capabilities?:vehicle_capabilities action?:enum reason?:string

Validate country rules and effect on eligibility/current job; protected plate storage action=archive is authenticated owner-only, requires no unresolved assignment/custody obligations and preserves historical references. Default save cannot reactivate an archived vehicle; register a new record and verification instead.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "vehicle_id", "aggregate_type": "freelance_vehicles", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: driver.vehicle_saved

## SubmitVerification

Capability: `driver.self`. Input: `SubmitVerificationPayload`. Result: `SubmitVerificationData`.

application_id?:optional_uuid country_code:country evidence:verification_refs

Verify secure evidence receipts; submit/receive idempotently; approval separate

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "application_id", "aggregate_type": "verification_applications", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: verification.submitted

## SubmitVerificationCorrection

Capability: `driver.self`. Input: `SubmitVerificationCorrectionPayload`. Result: `SubmitVerificationCorrectionData`.

application_id:uuid evidence:verification_refs

Replace only requested evidence; preserve valid prior evidence; unknown reconciliation

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "application_id", "aggregate_type": "verification_applications", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: verification.correction_submitted

## SavePayoutMethod

Capability: `driver.self`. Input: `SavePayoutMethodPayload`. Result: `SavePayoutMethodData`.

method_id?:optional_uuid kind:payout_kind secure_token:string masked_label:string country_code:country currency:currency

Validate provider token/ownership; protect sensitive data; no payment

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "method_id", "aggregate_type": "payout_methods", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: payout_method.saved

## StartBroadcast

Capability: `broadcasts.start`. Input: `StartBroadcastPayload`. Result: `BroadcastResult`.

round_id?:optional_uuid search_policy_id:uuid fare_minor:nonnegative_integer currency:currency delivery_ids:uuids requested_duration_seconds:positive_integer fulfillment_unit_ids?:array

Reserve delivery claims and scope snapshot; operator explicit start; no own-capacity gate Whole-delivery selection only; one fulfillment unit per delivery; split selectors cannot create residual work.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "round_id", "aggregate_type": "rounds", "when": "when non-null and record already exists"}, {"payload_field": "delivery_ids[]", "aggregate_type": "deliveries", "when": "each supplied existing ID"}, {"payload_field": "fulfillment_unit_ids[]", "aggregate_type": "fulfillment_units", "when": "every selected existing ID"}]

Errors: ADDRESS_REVIEW_REQUIRED, CLAIM_TAKEN, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED, VEHICLE_INCOMPATIBLE

Fact outcomes: broadcast.started

## ExpandBroadcast

Capability: `broadcasts.manage`. Input: `ExpandBroadcastPayload`. Result: `BroadcastResult`.

broadcast_id:uuid target_wave:positive_integer

Validate current revision and configured maximum; enqueue compatible invitations

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "broadcast_id", "aggregate_type": "broadcasts", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: broadcast.expanded

## ReviseBroadcast

Capability: `broadcasts.manage`. Input: `ReviseBroadcastPayload`. Result: `BroadcastResult`.

broadcast_id:uuid fare_minor:nonnegative_integer delivery_ids:uuids reason:string

Only unaccepted search; new scope/hash; invalidate old offers; claims updated atomically

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "broadcast_id", "aggregate_type": "broadcasts", "when": "required"}, {"payload_field": "delivery_ids[]", "aggregate_type": "deliveries", "when": "each supplied existing ID"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: broadcast.revised

## StopBroadcast

Capability: `broadcasts.manage`. Input: `StopBroadcastPayload`. Result: `BroadcastResult`.

broadcast_id:uuid reason:string

Unaccepted only; release claims; accepted job goes through cancellation contract

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "broadcast_id", "aggregate_type": "broadcasts", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: broadcast.stopped

## RespondOffer

Capability: `driver.offer_recipient`. Input: `RespondOfferPayload`. Result: `OfferResponseResult`.

offer_id:uuid scope_revision:positive_integer scope_hash:string response:offer_response

For response accept, lock current offer/broadcast, selected fulfillment-unit claims, Round/stops, accepted-scope snapshot and global driver guard. Exactly one winner creates agreement, acknowledged origin=freelance assignment with agreement_id, released Round/stops, unit ownership, committed driver range and open settlement. release_id stays null; no own-team plan/proposal is required. Grant location only within accepted work entitlement. Departure gate may remain awaiting preparation/receipt; acceptance is not custody. Other still-offered rows become taken; decline changes only the responding offer. Notify only after commit.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "offer_id", "aggregate_type": "offers", "when": "required"}]

Errors: CLAIM_TAKEN, DRIVER_CONFLICT, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, OFFER_EXPIRED, OFFER_WITHDRAWN, SCOPE_CHANGED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: offer.declined, offer.taken, work.accepted

## ProposeChange

Capability: `deliveries.change`. Input: `ProposeChangePayload`. Result: `ProposeChangeData`.

round_id:uuid agreement_id?:optional_uuid change:work_change mode:change_mode requested_duration_seconds?:['integer', 'null']

Snapshot base scope/impact; preserve current agreement pending consent

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "round_id", "aggregate_type": "rounds", "when": "required"}, {"payload_field": "agreement_id", "aggregate_type": "freelance_agreements", "when": "when non-null and record already exists"}]

Errors: CONSENT_REQUIRED, IDEMPOTENCY_CONFLICT, INVALID_REVISION, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: work.change_proposed

## RespondChange

Capability: `driver.assigned_work`. Input: `RespondChangePayload`. Result: `RespondChangeData`.

proposal_id:uuid proposal_version:positive_integer response:change_response reason?:optional_string

Actor/version/deadline; atomic acceptance only if current feasible; no old ack for newer version

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "proposal_id", "aggregate_type": "change_proposals", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, INVALID_REVISION, NOT_AUTHORIZED, SCOPE_CHANGED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: round.readiness_changed, work.change_responded

## WithdrawChange

Capability: `deliveries.change`. Input: `WithdrawChangePayload`. Result: `WithdrawChangeData`.

proposal_id:uuid reason:string

Pending proposal only; prior agreement unaffected

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "proposal_id", "aggregate_type": "change_proposals", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: work.change_withdrawn

## ConfirmArrival

Capability: `driver.assigned_work`. Input: `ConfirmArrivalPayload`. Result: `ConfirmArrivalData`.

stop_id:uuid point?:optional_point accuracy_m?:optional_number override_reason?:optional_string

Explicit driver arrival; P05/ADR-T05 checks coordinate/accuracy pairing or explicit captured-policy GPS override. No invented geofence threshold, automatic GPS arrival, readiness, receipt or custody. Atomically record stop/actual dropoff attempt, proposed location observation and fact. Genuine stale offline physical evidence is retained through the separate retained_for_review branch with incident ID; it does not execute current-assignment transitions. That branch emits evidence.retained_stale only for the newly retained observation, once per idempotency key.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "stop_id", "aggregate_type": "stops", "when": "required"}]

Errors: CUSTODY_MISMATCH, EXECUTION_FENCE_CHANGED, IDEMPOTENCY_CONFLICT, IMMUTABLE_RECORD, NOT_AUTHORIZED, POLICY_NOT_CONFIGURED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: stop.arrived

## ConfirmPickup

Capability: `driver.assigned_work`. Input: `ConfirmPickupPayload`. Result: `PickupResultData`.

round_id:uuid manifest_ids:uuids quantities:line_quantities approval_decision_id?:null pickup_stop_id:uuid fulfillment_unit_ids:array

Exactly one internal unit contains every current manifest line of one customer delivery. No split, child, residual unit or independent portion assignment at launch. CommitDelivery creates that whole unit; ConfirmPickup only changes an existing open whole unit to collected after full line equality, preparation readiness and actual inbound availability. Collected allocation is frozen. Delivered requires complete actual handoff and verified required proof; returned/cancelled require actual custody disposition. Preserve original delivery identity. Validate the entire selected batch before any custody/attempt writes; no implicit skipping. Non-ready preparation returns PICKUP_NOT_READY; unequal full quantities return COMPLETE_ORDER_REQUIRED.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "round_id", "aggregate_type": "rounds", "when": "required"}, {"payload_field": "pickup_stop_id", "aggregate_type": "stops", "when": "required"}, {"payload_field": "manifest_ids[]", "aggregate_type": "manifests", "when": "each supplied existing ID"}, {"payload_field": "fulfillment_unit_ids[]", "aggregate_type": "fulfillment_units", "when": "every selected existing ID"}]

Errors: COMPLETE_ORDER_REQUIRED, CUSTODY_MISMATCH, EXECUTION_FENCE_CHANGED, IDEMPOTENCY_CONFLICT, IMMUTABLE_RECORD, INBOUND_DISCREPANCY, INBOUND_NOT_RECEIVED, MANIFEST_MISMATCH, NOT_AUTHORIZED, PICKUP_NOT_READY, QUANTITY_ALREADY_ALLOCATED, QUANTITY_EXCEEDED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: pickup.confirmed, round.readiness_changed

## ReportIssue

Capability: `driver.assigned_work`. Input: `ReportIssuePayload`. Result: `ReportIssueData`.

delivery_id?:optional_uuid round_id?:optional_uuid trip_id?:optional_uuid issue_type:issue_type reason_code:string detail?:optional_string affected_lines:observed_line_quantities asset_ids:uuids point?:optional_point

Persist typed actual report under its original execution fence; empty affected_lines assert no measured quantity. ADR-T07 R1 pre-pickup package reports hold the affected order and synchronously block departure; waiting reports do not invent receipt/preparation or money. ADR-M04 requires exactly one verified issue_photo for damaged/wrong reports, bound to the original actor/order/pickup/unit/manifest/assignment/report observation and time before any operational write. Missing/wait remains photo-free. No automatic approval, split pickup or custody movement.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "when non-null and record already exists"}, {"payload_field": "round_id", "aggregate_type": "rounds", "when": "when non-null and record already exists"}, {"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "when non-null and record already exists"}]

Errors: ASSET_NOT_VERIFIED, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED, EXECUTION_FENCE_CHANGED, FEATURE_NOT_ENABLED, MANIFEST_MISMATCH, QUANTITY_EXCEEDED

Fact outcomes: issue.reported, round.readiness_changed

## ResolveIssue

Capability: `issues.decide`. Input: `ResolveIssuePayload`. Result: `ResolveIssueData`.

issue_id:uuid decision:issue_decision reason:string

ADR-T08 R1 accepts original pre-pickup wait/escalate instructions only under issues.decide. Require exact issue version, nonblank reason/instructions and empty quantities, no consent/change selectors. Atomically append immutable attributed decision/reason, advance issue to decided, and emit issue.decided/outbox/receipt; never resolve physically, release holds or fabricate readiness/custody. Supersession uses the validated current decision chain. Other actions, including partial_pickup, fail FEATURE_NOT_ENABLED after authorization; later change/return/disposition commands remain gated.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "issue_id", "aggregate_type": "issues", "when": "required"}]

Errors: FEATURE_NOT_ENABLED, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, SOURCE_STALE, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: issue.decided, round.readiness_changed

## RecordHandoff

Capability: `driver.assigned_work`. Input: `RecordHandoffPayload`. Result: `HandoffResultData`.

attempt_id:uuid receiver_kind:receiver_kind receiver_contact_id?:optional_uuid place_code?:optional_string instruction_reference?:optional_string quantities:line_quantities

Validate original assignment, arrived attempt, captured effective proof policy and exact complete-manifest custody; missing or invalid policy returns POLICY_NOT_CONFIGURED. Physical handoff is distinct from proof completion. Genuine stale offline physical evidence is retained through the separate retained_for_review branch with incident ID; it does not execute current-assignment transitions. That branch emits evidence.retained_stale only for the newly retained observation, once per idempotency key.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "attempt_id", "aggregate_type": "delivery_attempts", "when": "required"}]

Errors: CUSTODY_MISMATCH, EXECUTION_FENCE_CHANGED, IDEMPOTENCY_CONFLICT, IMMUTABLE_RECORD, NOT_AUTHORIZED, POLICY_NOT_CONFIGURED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: handoff.recorded

## ReserveAsset

Capability: `actor.allowed_upload`. Input: `ReserveAssetPayload`. Result: `UploadCapabilityResult`.

kind:asset_kind mime_type:string byte_size:nonnegative_integer sha256:hash purpose_entity_id:uuid pickup_context?:PickupIssueAssetContext

Authorize purpose/actor; issue restricted upload capability; no inline bytes. ADR-M02 delivery_photo/signature binds an actual handoff. ADR-M04 issue_photo binds the original delivery/pickup/unit/manifest/assignment/report observation using required pickup_context; other kinds forbid that context. Persist immutable scope and identity; attach fresh staging capabilities only after commit/replay/status authorization. General attachments remain disabled.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: []

Errors: EXECUTION_FENCE_CHANGED, FEATURE_NOT_ENABLED, IDEMPOTENCY_CONFLICT, IMMUTABLE_RECORD, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: asset.reserved

## VerifyAsset

Capability: `actor.allowed_upload`. Input: `VerifyAssetPayload`. Result: `VerifyAssetData`.

asset_id:uuid sha256:hash

Server confirms actual object/hash/type/scan; client metadata alone insufficient. ADR-M02 POD and ADR-M04 pre-pickup issue photos use the same bounded JPEG/PNG byte decoder and sealed-copy verifier, with distinct immutable purposes. Recheck current authorization, original binding and version after provider IO before verified state/fact/receipt commit. No scanning state is called verified. General attachment malware scanning and configured provider integration remain separate dependencies.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "asset_id", "aggregate_type": "assets", "when": "required"}]

Errors: EXECUTION_FENCE_CHANGED, ASSET_NOT_VERIFIED, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: asset.verified

## SubmitProof

Capability: `driver.assigned_work`. Input: `SubmitProofPayload`. Result: `SubmitProofData`.

attempt_id:uuid handoff_id:uuid policy_version_id:uuid evidence:proof_refs

ADR-T06: validate original assignment, actual whole-order handoff, captured policy and every typed durable reference. Store immutable pending submission/items including exact note and actual arrival-observation reference; increment attempt version. Incomplete valid submissions stay pending without completing delivery. New genuine evidence creates another immutable submission using the successor attempt version. Genuine stale offline physical evidence uses the separate retained_for_review branch with incident identity, never refreshed assignment authority.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "attempt_id", "aggregate_type": "delivery_attempts", "when": "required"}]

Errors: ASSET_NOT_VERIFIED, CUSTODY_MISMATCH, EXECUTION_FENCE_CHANGED, IDEMPOTENCY_CONFLICT, IMMUTABLE_RECORD, NOT_AUTHORIZED, POLICY_NOT_CONFIGURED, PROOF_INCOMPLETE, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: proof.submitted

## CompleteDelivery

Capability: `driver.assigned_work`. Input: `CompleteDeliveryPayload`. Result: `CompleteDeliveryData`.

attempt_id:uuid proof_submission_id:uuid

ADR-T06: lock original assignment, attempt, whole-delivery unit, manifest/custody and selected pending proof. Revalidate all actual references and captured required policy; synchronously verify pending items under those locks. Reject invalidated or wrongly attributed evidence. Complete proof, whole unit quantities, stop, attempt and delivery and archive active claim atomically with distinct fulfillment/delivery facts. Independent complete orders may finish without unrelated orders; Round closure additionally requires all its own stops, returns, custody and required duties resolved. Own-team commitment release uses narrowly scoped state-only authority, not broker access. Older immutable pending candidates remain history, not extra physical obligations. No mixed quantities or fabricated remainder delivery. Earn only a genuinely accepted commercial agreement in its separately enabled scope.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "attempt_id", "aggregate_type": "delivery_attempts", "when": "required"}]

Errors: ASSET_NOT_VERIFIED, CUSTODY_MISMATCH, EVIDENCE_PENDING, EXECUTION_FENCE_CHANGED, IDEMPOTENCY_CONFLICT, IMMUTABLE_RECORD, NOT_AUTHORIZED, POLICY_NOT_CONFIGURED, PROOF_INCOMPLETE, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: delivery.completed, delivery.outcome_changed, fulfillment.completed, obligation.resolved, round.completed, settlement.balance_changed, settlement.closed, settlement.earned

## CancelDelivery

Capability: `deliveries.cancel`. Input: `CancelDeliveryPayload`. Result: `CancelDeliveryData`.

delivery_id:uuid reason:string disposition:cancellation_disposition agreement_reference?:optional_string fulfillment_unit_ids?:array

Lock original delivery and all unit allocations. Optional fulfillment_unit_ids selects only those residual units; validate they belong to delivery_id and are uncollected or have completed return/disposition. Cancel selected remaining responsibility under customer/freelance consent, preserve delivered units and immutable evidence. Release only affected claims/slot admission when whole-order rules permit; derive partially_delivered if delivered plus cancelled portions. Never cancel every unit merely because they share delivery_id. Whole-delivery selection only; one fulfillment unit per delivery; split selectors cannot create residual work.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "required"}, {"payload_field": "fulfillment_unit_ids[]", "aggregate_type": "fulfillment_units", "when": "each selected existing unit"}]

Errors: CONSENT_REQUIRED, CUSTODY_MISMATCH, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: delivery.cancelled, delivery.outcome_changed, obligation.resolved, round.completed, settlement.balance_changed, settlement.closed, settlement.earned

## RescheduleDelivery

Capability: `deliveries.change`. Input: `RescheduleDeliveryPayload`. Result: `RescheduleDeliveryData`.

delivery_id:uuid window:window customer_agreement_reference:string reason:string target_occurrence_id:optional_uuid

Preserve attempt; atomic admission move where relevant; accepted work change contract applies

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: delivery.rescheduled

## CreateReturn

Capability: `issues.decide`. Input: `CreateReturnPayload`. Result: `CreateReturnData`.

delivery_id:uuid destination_site_id:uuid quantities:line_quantities agreement_reference?:optional_string receiver_id:uuid custodian_id:uuid

Explicit custodian/destination/quantities; no silent scope or fee change

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: return.created

## ReceiveReturn

Capability: `custody.receive`. Input: `ReceiveReturnPayload`. Result: `PhysicalReceiptResult`.

return_task_id:uuid quantities:line_quantities asset_ids:uuids discrepancies?:optional_string receipt_reference:string

Quantities are positive increments against outstanding lines, not cumulative totals. Same command_id replay adds zero; new command increments, locks balance/booking and rejects over-receipt. Receipt reference deduplicates the same physical receipt per receiver/booking. Authorized receiver confirms actual quantities; balanced custody; partial remains unresolved Genuine stale offline physical evidence is retained through the separate retained_for_review branch with incident ID; it does not execute current-assignment transitions. That branch emits evidence.retained_stale only for the newly retained observation, once per idempotency key.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "return_task_id", "aggregate_type": "return_tasks", "when": "required"}]

Errors: CUSTODY_MISMATCH, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, QUANTITY_EXCEEDED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: delivery.outcome_changed, obligation.resolved, return.received, round.completed, settlement.balance_changed, settlement.closed, settlement.earned

## SaveTrip

Capability: `intercity.manage`. Input: `SaveTripPayload`. Result: `SaveTripData`.

trip_id?:optional_uuid origin_site_id:uuid destination_site_id:uuid driver_id:uuid vehicle_id:uuid service_date:date planned_window:window receiver_id:uuid

Cross-city permissions and timing/capacity; global driver commitment review

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "when non-null and record already exists"}, {"payload_field": "driver_id", "aggregate_type": "drivers", "when": "required"}, {"payload_field": "vehicle_id", "aggregate_type": "vehicles", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: trip.saved

## BookTrip

Capability: `intercity.manage`. Input: `BookTripPayload`. Result: `BookTripData`.

trip_id:uuid delivery_id:uuid manifest_id:uuid quantities:line_quantities receiver_id:uuid

Lock trip capacity and delivery leg dependency; booking is not load

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "required"}, {"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "required"}, {"payload_field": "manifest_id", "aggregate_type": "manifests", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, MANIFEST_MISMATCH, NOT_AUTHORIZED, PHYSICAL_INCOMPATIBILITY, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: trip.booked

## ConfirmTripLoad

Capability: `driver.assigned_trip`. Input: `ConfirmTripLoadPayload`. Result: `PhysicalReceiptResult`.

trip_id:uuid manifest_ids:uuids quantities:line_quantities

Confirmed actual quantities/custody; partial discrepancy remains explicit

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "required"}, {"payload_field": "manifest_ids[]", "aggregate_type": "manifests", "when": "each supplied existing ID"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: trip.loaded

## DepartTrip

Capability: `driver.assigned_trip`. Input: `DepartTripPayload`. Result: `DepartTripData`.

trip_id:uuid

Required load/manifest closure or explicit partial approval; no booking-only departure

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: trip.departed

## ArriveTrip

Capability: `driver.assigned_trip`. Input: `ArriveTripPayload`. Result: `ArriveTripData`.

trip_id:uuid point?:optional_point

Explicit arrival; destination receipt remains separate

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: trip.arrived

## ReceiveTrip

Capability: `custody.receive`. Input: `ReceiveTripPayload`. Result: `PhysicalReceiptResult`.

booking_id:uuid quantities:line_quantities asset_ids:uuids discrepancies?:optional_string receipt_reference:string

Quantities are positive increments against outstanding lines, not cumulative totals. Same command_id replay adds zero; new command increments, locks balance/booking and rejects over-receipt. Receipt reference deduplicates the same physical receipt per receiver/booking. Authorized site receiver; receipt/custody/local readiness only actual quantities Genuine stale offline physical evidence is retained through the separate retained_for_review branch with incident ID; it does not execute current-assignment transitions. That branch emits evidence.retained_stale only for the newly retained observation, once per idempotency key.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "booking_id", "aggregate_type": "trip_bookings", "when": "required"}]

Errors: CUSTODY_MISMATCH, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, QUANTITY_EXCEEDED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: round.readiness_changed, trip.received

## ChangeTrip

Capability: `intercity.manage`. Input: `ChangeTripPayload`. Result: `ChangeTripData`.

trip_id:uuid planned_window:window reason:string

Impact dependent local promises; preserve loaded work and driver agreement

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: trip.changed

## CancelTrip

Capability: `intercity.manage`. Input: `CancelTripPayload`. Result: `CancelTripData`.

trip_id:uuid reason:string disposition:cancellation_disposition

Resolve booked/loaded quantities; no silent removal

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: trip.cancelled

## SendMessage

Capability: `conversation.participate`. Input: `SendMessagePayload`. Result: `SendMessageData`.

conversation_id:uuid client_message_id:uuid text?:optional_string attachments:message_refs

Validate participant and purpose-bound assets; unique sender/client ID; receipt not read

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "conversation_id", "aggregate_type": "conversations", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: message.received

## MarkMessagesRead

Capability: `conversation.participate`. Input: `MarkMessagesReadPayload`. Result: `MarkMessagesReadData`.

conversation_id:uuid through_message_id:uuid

Participant-specific observed boundary; no acknowledgement of route change

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "conversation_id", "aggregate_type": "conversations", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: conversation.read

## StartCall

Capability: `conversation.call`. Input: `StartCallPayload`. Result: `StartCallData`.

conversation_id:uuid callee_id?:optional_uuid contact_id?:optional_uuid

Provider session intent; no Connected until real callback

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "conversation_id", "aggregate_type": "conversations", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, PROVIDER_UNAVAILABLE, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: call.requested

## RespondCall

Capability: `conversation.call`. Input: `RespondCallPayload`. Result: `RespondCallData`.

call_id:uuid response:call_response

Correct call participant; actual provider lifecycle remains authority

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "call_id", "aggregate_type": "call_sessions", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: call.responded

## LogCallOutcome

Capability: `conversation.participate`. Input: `LogCallOutcomePayload`. Result: `LogCallOutcomeData`.

call_id:uuid outcome:call_outcome note?:optional_string

Manual provenance/time; append correction, never fabricate provider connected

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "call_id", "aggregate_type": "call_sessions", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: call.outcome_reported

## MarkNotificationRead

Capability: `actor.notification`. Input: `MarkNotificationReadPayload`. Result: `MarkNotificationReadData`.

notification_id:uuid

Read marker only; fetch current entity for operational action

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "notification_id", "aggregate_type": "notifications", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: notification.read

## ReportLocationObservation

Capability: `driver.assigned_work`. Input: `ReportLocationObservationPayload`. Result: `ReportLocationObservationData`.

delivery_id:uuid observation_kind:string point?:optional_point accuracy_m?:optional_number note?:optional_string

Candidate observation only; no automatic entrance knowledge write

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: location.observed

## ConfirmEntrance

Capability: `addresses.review`. Input: `ConfirmEntrancePayload`. Result: `ConfirmEntranceData`.

entrance_id?:optional_uuid city_id:uuid label:string point:point access_notes?:optional_string handoff_notes?:optional_string observation_id?:optional_uuid

New immutable reviewed revision with permitted provenance; private unit not shared

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "entrance_id", "aggregate_type": "entrances", "when": "when non-null and record already exists"}, {"payload_field": "city_id", "aggregate_type": "cities", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: entrance.confirmed

## ApplyEntrance

Capability: `addresses.review`. Input: `ApplyEntrancePayload`. Result: `ApplyEntranceData`.

delivery_id:uuid entrance_revision_id:uuid

Snapshot revision; active work requires destination change/ack or consent

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "required"}]

Errors: ADDRESS_REVIEW_REQUIRED, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: delivery.entrance_applied

## CreateNavigationIntent

Capability: `driver.assigned_work`. Input: `CreateNavigationIntentPayload`. Result: `CreateNavigationIntentData`.

stop_id:uuid destination_version:positive_integer provider:string

Dedupe driver/stop/destination/profile; allowed provider display/storage

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "stop_id", "aggregate_type": "stops", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, PROVIDER_UNAVAILABLE, STALE_VERSION, UNSUPPORTED_PROFILE, VALIDATION_FAILED

Fact outcomes: navigation.intent_created

## SaveConnection

Capability: `integrations.manage`. Input: `SaveConnectionPayload`. Result: `SaveConnectionData`.

connection_id?:optional_uuid provider:string store_key:string city_id:uuid site_id:uuid permissions:source_permissions secure_token?:optional_string

Config distinct from verified auth; no credentials in event

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "connection_id", "aggregate_type": "source_connections", "when": "when non-null and record already exists"}, {"payload_field": "city_id", "aggregate_type": "cities", "when": "required"}, {"payload_field": "site_id", "aggregate_type": "sites", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: connection.saved

## SetConnectionState

Capability: `integrations.manage`. Input: `SetConnectionStatePayload`. Result: `SetConnectionStateData`.

connection_id:uuid enabled:boolean consequence_ack:boolean

Revoke/pause inbound/outbound as appropriate; preserve work; reconcile queued stale effects

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "connection_id", "aggregate_type": "source_connections", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: connection.state_changed

## RetryWriteback

Capability: `integrations.manage`. Input: `RetryWritebackPayload`. Result: `RetryWritebackData`.

task_id:uuid

Confirm current permission/source version; ambiguous provider result reconciled before effect

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "task_id", "aggregate_type": "writeback_tasks", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: writeback.retry_requested

## CreateTrackingLink

Capability: `tracking.manage`. Input: `CreateTrackingLinkPayload`. Result: `TrackingLinkResult`.

delivery_id:uuid audience:customer_audience expires_at:instant

Hashed purpose-scoped token; privacy policy bound; no unrelated stop visibility

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, TRACKING_DISABLED, TRACKING_EXPIRED, VALIDATION_FAILED

Fact outcomes: tracking.link_created

## RevokeTrackingLink

Capability: `tracking.manage`. Input: `RevokeTrackingLinkPayload`. Result: `RevokeTrackingLinkData`.

tracking_token_id:uuid reason:string

Immediate future authorization failure; delivery unaffected

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "tracking_token_id", "aggregate_type": "customer_tracking_tokens", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: tracking.link_revoked

## RequestExport

Capability: `history.export`. Input: `RequestExportPayload`. Result: `OperationResult`.

kind:export_kind city_ids:uuids date_from:date date_to:date

Snapshot scope/as-of; async authorized output and expiring download

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: []

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: export.requested

## CorrectIncidentCause

Capability: `history.correct`. Input: `CorrectIncidentCausePayload`. Result: `CorrectIncidentCauseData`.

issue_id:uuid cause_code:string provenance:cause_provenance reason:string

Append attributed correction; no retroactive proof/driver impersonation

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "issue_id", "aggregate_type": "issues", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: incident.cause_corrected

## RecordSettlement

Capability: `finance.manage`. Input: `RecordSettlementPayload`. Result: `RecordSettlementData`.

agreement_id:uuid direction:string amount_minor:integer currency:currency payment_reference:string occurred_at:instant proof_asset_id?:optional_uuid

Record an external payment or refund, never initiate money movement. Lock settlement; validate currency, positive amount, unique external reference and refund<=net paid. Append payment and settlement event, recompute net paid and payment_state against max(0,guaranteed+adjustments). earning_state changes only on agreed work completion or authorized compensation, not this command. Prepayment does not block later earning. due=max(earned-net_paid,0); refund_due=max(net_paid-final_entitlement,0) only after final entitlement is established.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "agreement_id", "aggregate_type": "freelance_agreements", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, PAYMENT_REFERENCE_CONFLICT, REFUND_EXCEEDS_PAID, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: settlement.balance_changed, settlement.closed, settlement.payment_recorded

## RecordFareAdjustment

Capability: `finance.manage`. Input: `RecordFareAdjustmentPayload`. Result: `RecordFareAdjustmentData`.

agreement_id:uuid amount_minor:integer currency:currency reason_code:string authorization_reference:string

Preserve accepted fare; validate agreed terms/change consent; append unique event

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "agreement_id", "aggregate_type": "freelance_agreements", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: fare.adjusted

## OpenDispute

Capability: `disputes.open`. Input: `OpenDisputePayload`. Result: `OpenDisputeData`.

kind:string agreement_id?:uuid proof_submission_id?:uuid reason_code:string asset_ids:array

Financial case requires party/authorized finance scope; evidence case requires assigned party or proof reviewer scope. Create separate dispute case. Financial dispute does not change agreement fulfillment, earned/paid facts or POD. Evidence dispute marks only targeted proof and its derived delivery evidence disputed, preserves physical handoff and prior proof state, records affected IDs. No fabricated custody correction.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "agreement_id", "aggregate_type": "freelance_agreements", "when": "selected typed target"}, {"payload_field": "proof_submission_id", "aggregate_type": "proof_submissions", "when": "selected typed target"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: dispute.opened

## RequestPrivacyAction

Capability: `privacy.request`. Input: `RequestPrivacyActionPayload`. Result: `RequestPrivacyActionData`.

subject_reference:string action:privacy_action

Verify subject and authority; evaluate retention hold before purge/export

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: []

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: privacy.requested

## StagePlan

Capability: `plans.release`. Input: `StagePlanPayload`. Result: `StagedPlanResult`.

plan_id:uuid round_ids:uuids

Assign complete future team routes and provisional busy ranges; preserve inbound gate. Required goods need not have arrived. Emit provisional schedule updates. Create or reuse a provisional team assignment so GetDriverRound can show the staged route; no physical collection authority. Preserve assignment identity on release and issue the new revision. Withdrawal releases provisional driver range and withdraws assignment without deleting the planned route.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "plan_id", "aggregate_type": "plans", "when": "required"}, {"payload_field": "round_ids[]", "aggregate_type": "rounds", "when": "each supplied existing ID"}]

Errors: DRIVER_CONFLICT, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED, VEHICLE_INCOMPATIBLE

Fact outcomes: plan.staged

## WithdrawRelease

Capability: `plans.release`. Input: `WithdrawReleasePayload`. Result: `StagedPlanResult`.

round_id:uuid stop_ids:uuids reason:string

Only unstarted uncollected stops may be withdrawn. Lock plan/claims/assignment/commitments, free their active claims and shrink busy range. Preserve completed work and goods already held.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "round_id", "aggregate_type": "rounds", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: assignment.withdrawn

## PauseRound

Capability: `plans.release`. Input: `PauseRoundPayload`. Result: `PauseRoundData`.

round_id:uuid action:pause_state reason:string

action pause sets operational_hold=true; resume clears that flag after authority checks. Lifecycle state remains released/active/etc. Recompute departure gate synchronously; no paused lifecycle code. On-road driver gets safe-stop instruction/acknowledgement, not an assumption they physically stopped. No custody or completed stops reset.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "round_id", "aggregate_type": "rounds", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: round.hold_changed, round.readiness_changed

## ReassignRound

Capability: `plans.release`. Input: `ReassignRoundPayload`. Result: `ReassignRoundData`.

round_id:uuid target_driver_id:uuid target_vehicle_id:uuid reason:string

Team instruction only. Check old/new driver and vehicle guards; supersede prior assignment, issue new one. Collected goods require independent transfer receipt before new driver pickup.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "round_id", "aggregate_type": "rounds", "when": "required"}]

Errors: CONSENT_REQUIRED, DRIVER_CONFLICT, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED, VEHICLE_INCOMPATIBLE

Fact outcomes: assignment.reassigned

## ApplyOwnFleetAutomation

Capability: `plans.automate`. Input: `ApplyOwnFleetAutomationPayload`. Result: `ApplyOwnFleetAutomationData`.

plan_id:uuid proposal_id:uuid input_hash:hash

Apply only unstarted within configured insertion/time/cargo limits through same command transaction as human apply; never starts a freelancer broadcast.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "plan_id", "aggregate_type": "plans", "when": "required"}, {"payload_field": "proposal_id", "aggregate_type": "plan_proposals", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, PHYSICAL_INCOMPATIBILITY, STALE_VERSION, VALIDATION_FAILED, VEHICLE_CONFLICT

Fact outcomes: plan.automation_applied

## SetPickupReadiness

Capability: `deliveries.prepare`. Input: `SetPickupReadinessPayload`. Result: `ReadinessResult`.

delivery_id:uuid preparation_state:ready_state ready_by:optional_instant reason:optional_string

Merchant actor changes preparation estimate/state, records source/time and re-evaluates departure gates. This is not a physical pickup.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: pickup.readiness_changed, round.readiness_changed

## ApprovePartialPickup

Capability: `issues.decide`. Input: `ApprovePartialPickupPayload`. Result: `PartialPickupApprovalResult`.

issue_id:uuid manifest_id:uuid quantities:line_quantities customer_agreement_reference:string agreement_id:optional_uuid reason:string

Disabled at launch: reject FEATURE_NOT_ENABLED before any domain mutation. No setting, customer approval or operator privilege bypasses this restriction.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "issue_id", "aggregate_type": "issues", "when": "required"}, {"payload_field": "agreement_id", "aggregate_type": "freelance_agreements", "when": "when non-null and record already exists"}, {"payload_field": "manifest_id", "aggregate_type": "manifests", "when": "required"}]

Errors: CONSENT_REQUIRED, CUSTODY_MISMATCH, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, QUANTITY_EXCEEDED, STALE_VERSION, VALIDATION_FAILED, FEATURE_NOT_ENABLED

Fact outcomes: 

## InitiateTransfer

Capability: `custody.transfer`. Input: `InitiateTransferPayload`. Result: `TransferInitiatedResult`.

manifest_id:uuid from_custodian_id:uuid to_custodian_id:uuid quantities:line_quantities reason:string

Validate source authority and available goods; reserve proposed lines against competing transfer; no target credit yet.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "manifest_id", "aggregate_type": "manifests", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: custody.transfer_pending

## ConfirmTransferReceipt

Capability: `custody.receive`. Input: `ConfirmTransferReceiptPayload`. Result: `PhysicalReceiptResult`.

transfer_id:uuid quantities:line_quantities asset_ids:uuids

Quantities are positive increments against outstanding lines, not cumulative totals. Same command_id replay adds zero; new command increments, locks balance/booking and rejects over-receipt. Receipt reference deduplicates the same physical receipt per receiver/booking. Authenticated destination custodian/site receiver records incremental actual receipt. Debit source and credit destination atomically; extra quantities reject. Offline receipt reconciles before authoritative balances change. Genuine stale offline physical evidence is retained through the separate retained_for_review branch with incident ID; it does not execute current-assignment transitions. That branch emits evidence.retained_stale only for the newly retained observation, once per idempotency key.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "transfer_id", "aggregate_type": "custody_transfers", "when": "required"}]

Errors: CUSTODY_MISMATCH, IDEMPOTENCY_CONFLICT, MANIFEST_MISMATCH, NOT_AUTHORIZED, QUANTITY_EXCEEDED, STALE_VERSION, TRANSFER_NOT_AUTHORIZED, VALIDATION_FAILED

Fact outcomes: custody.transfer_received

## CancelTransfer

Capability: `custody.transfer`. Input: `CancelTransferPayload`. Result: `TransferInitiatedResult`.

transfer_id:uuid reason:string

Cancel only outstanding proposed quantities. Keep credited quantities and their receipt evidence immutable.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "transfer_id", "aggregate_type": "custody_transfers", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: custody.transfer_cancelled

## CancelAgreement

Capability: `agreements.cancel`. Input: `CancelAgreementPayload`. Result: `CancelAgreementData`.

agreement_id:uuid reason:string compensation_minor:nonnegative_integer currency:currency authorization_reference:string

Resolve all remaining stops and custody obligations in one cancellation transaction; retain accepted economics and explicit compensation, release/shrink driver range only after remaining obligations are assigned.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "agreement_id", "aggregate_type": "freelance_agreements", "when": "required"}]

Errors: CUSTODY_MISMATCH, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: agreement.cancelled, settlement.balance_changed, settlement.closed

## RestartBroadcast

Capability: `broadcasts.start`. Input: `RestartBroadcastPayload`. Result: `BroadcastResult`.

broadcast_id:uuid search_policy_id:uuid requested_duration_seconds:positive_integer fare_minor:nonnegative_integer currency:currency

Only closed search with no active agreement. Create fresh search/offer revision with new server deadline; old offer IDs stay invalid.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "broadcast_id", "aggregate_type": "broadcasts", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: broadcast.restarted

## ScheduleTrip

Capability: `intercity.manage`. Input: `ScheduleTripPayload`. Result: `ScheduleTripData`.

trip_id:uuid

Check driver/vehicle/receiver/timing and commit global busy range. Preplanning local routes remains available regardless of actual loading.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: trip.scheduled

## CloseTrip

Capability: `intercity.manage`. Input: `CloseTripPayload`. Result: `CloseTripData`.

trip_id:uuid

All booked quantities received or explicitly disposed, required evidence complete and unresolved balance zero. Arrival alone fails closure.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: trip.closed

## RefreshSlotHold

Capability: `deliveries.create`. Input: `RefreshSlotHoldPayload`. Result: `SlotReservationResult`.

reservation_id:uuid

Refresh same live hold before expiry under logical template/date lock; server limits total lifetime from initial creation.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "reservation_id", "aggregate_type": "slot_reservations", "when": "required"}]

Errors: HOLD_EXPIRED, HOLD_LIMIT, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, SLOT_CLOSED, SLOT_EXPIRED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: slot.hold_refreshed

## MoveSlotHold

Capability: `deliveries.create`. Input: `MoveSlotHoldPayload`. Result: `SlotReservationResult`.

reservation_id:uuid target_occurrence_id:uuid

Lock source and target logical admission keys in sorted order and update one live hold atomically; failure preserves source.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "reservation_id", "aggregate_type": "slot_reservations", "when": "required"}]

Errors: CUTOFF_PASSED, HOLD_EXPIRED, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, SLOT_CLOSED, SLOT_EXPIRED, SLOT_FULL, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: slot.hold_moved

## ReviewSourceRevision

Capability: `deliveries.change`. Input: `ReviewSourceRevisionPayload`. Result: `SourceReviewResult`.

source_event_id:uuid delivery_id:uuid decision:source_review_decision reason:string

Compare original/current/proposed source; explicit apply follows change/consent and custody protection. Rejected revision stays auditable.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "source_event_id", "aggregate_type": "source_events", "when": "required"}, {"payload_field": "delivery_id", "aggregate_type": "deliveries", "when": "required"}]

Errors: ADDRESS_REVIEW_REQUIRED, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, SOURCE_STALE, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: source.revision_reviewed

## DecideDispute

Capability: `disputes.decide`. Input: `DecideDisputePayload`. Result: `DecideDisputeData`.

dispute_id:uuid decision:string adjustment_minor?:integer currency?:currency replacement_proof_submission_id?:uuid authorization_reference:string reason:string

Lock typed dispute and affected records. Financial adjustment requires finance.decide; append adjustment/recompute settlement, never alter proof. Evidence decision requires proof.review; uphold restores stored prior proof state; rejection marks proof rejected and requires genuine replacement; replacement must already be verified for the same attempt/handoff/policy. Dismissal restores prior valid evidence only for evidence case. Close case atomically after effects. Agreement completion and paid facts survive every dispute outcome.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "dispute_id", "aggregate_type": "dispute_cases", "when": "required"}]

Errors: DISPUTE_OUTCOME_INVALID, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: dispute.resolved, settlement.balance_changed, settlement.closed

## SuspendTenant

Capability: `tenant.manage`. Input: `SuspendTenantPayload`. Result: `SuspendTenantData`.

tenant_id:uuid reason:string

Block new intake/broadcast while preserving restricted active-custody recovery, proofs and history.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "tenant_id", "aggregate_type": "tenants", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: tenant.suspended

## CloseTenant

Capability: `tenant.manage`. Input: `CloseTenantPayload`. Result: `CloseTenantData`.

tenant_id:uuid reason:string

Require no unresolved goods/commitments and completed export/retention disposition. No cascade destruction of evidence.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "tenant_id", "aggregate_type": "tenants", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: tenant.closed

## RestoreTenant

Capability: `tenant.manage`. Input: `RestoreTenantPayload`. Result: `RestoreTenantData`.

tenant_id:uuid reason:string

Suspended only; revalidate membership/policies before opening new work.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "tenant_id", "aggregate_type": "tenants", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: tenant.restored

## OpenConversation

Capability: `conversation.open`. Input: `OpenConversationPayload`. Result: `ConversationOpenResult`.

round_id:optional_uuid trip_id:optional_uuid relationship_id:optional_uuid

Exactly one context. Authorized get-or-create by immutable job/relationship context with unique key; return participants and existing messages cursor.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "round_id", "aggregate_type": "rounds", "when": "when non-null and record already exists"}, {"payload_field": "trip_id", "aggregate_type": "transport_trips", "when": "when non-null and record already exists"}, {"payload_field": "relationship_id", "aggregate_type": "driver_relationships", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: conversation.opened

## SetShiftAvailability

Capability: `fleet.manage`. Input: `SetShiftAvailabilityPayload`. Result: `SetShiftAvailabilityData`.

shift_id:uuid state:enum reason:string

Only started/on_break/no_show transitions from defined state table. Block new commitments while unavailable; retain current goods/assignments for operator handling.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "shift_id", "aggregate_type": "shift_occurrences", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: shift.availability_changed

## BindShiftVehicle

Capability: `fleet.manage`. Input: `BindShiftVehiclePayload`. Result: `BindShiftVehicleData`.

shift_id:uuid vehicle_id:uuid reason:string

Lock vehicle scheduling guard; no overlapping active shifts use same vehicle; revalidate assigned cargo and estimated timing.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "shift_id", "aggregate_type": "shift_occurrences", "when": "required"}, {"payload_field": "vehicle_id", "aggregate_type": "vehicles", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: shift.vehicle_bound

## ReserveVerificationEvidence

Capability: `driver.self`. Input: `ReserveVerificationEvidencePayload`. Result: `UploadCapabilityResult`.

application_id:uuid evidence_kind:enum mime_type:string byte_size:positive_integer sha256:hash

Purpose-bound global private upload; authentication ties evidence to this driver/application. No public object URL.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "application_id", "aggregate_type": "verification_applications", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: verification.evidence_reserved

## DecideVerification

Capability: `verification.review`. Input: `DecideVerificationPayload`. Result: `DecideVerificationData`.

application_id:uuid approved:boolean reason:string provider_receipt_id:optional_uuid

Restricted reviewer only; require validated evidence and explicit attributed override reason when provider did not decide. Never imply provider approval.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "application_id", "aggregate_type": "verification_applications", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: verification.decided

## RetireEntrance

Capability: `addresses.manage`. Input: `RetireEntrancePayload`. Result: `RetireEntranceData`.

entrance_id:uuid reason:string

Retire the shared entrance version for future selection. Preserve historical revisions and snapshots; flag affected unstarted deliveries for review. Never silently move their pin.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "entrance_id", "aggregate_type": "entrances", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: entrance.retired

## SaveRound

Capability: `plans.manage`. Input: `SaveRoundPayload`. Result: `SaveRoundData`.

round_id:optional_uuid city_id:uuid service_date:string pickup_site_id:uuid planned_start_at:optional_instant driver_id:optional_uuid vehicle_id:optional_uuid

Create or edit draft/planned team Round metadata only. Staged, released, active or freelance-accepted scopes require withdrawal or the change/consent flow. Lock existing Round and affected driver/vehicle commitments; validate city/site/vehicle/cargo and recompute route timing. An unassigned draft may omit both driver and vehicle; populated vehicle must be valid for that driver/shift. Receipt is not a planning gate.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "round_id", "aggregate_type": "rounds", "when": "when non-null and record already exists"}, {"payload_field": "city_id", "aggregate_type": "cities", "when": "required"}, {"payload_field": "driver_id", "aggregate_type": "drivers", "when": "when non-null and record already exists"}, {"payload_field": "vehicle_id", "aggregate_type": "vehicles", "when": "when non-null and record already exists"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: round.saved

## SaveStopPlanningFields

Capability: `plans.manage`. Input: `SaveStopPlanningFieldsPayload`. Result: `SaveStopPlanningFieldsData`.

stop_id:uuid service_seconds:integer

Edit service duration on a draft/planned team Round only, lock stop and parent Round, recompute downstream ETA, return/reload and predicted free time. Customer window changes use MoveDeliveryWindow; sequence/driver changes use PreviewPlanMove/ApplyPlanProposal. Staged or accepted scopes require the existing withdrawal/change flow.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "stop_id", "aggregate_type": "stops", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: stop.planning_changed

## RetainOfflineObservations

Capability: `driver.own_evidence`. Input: `RetainOfflineObservationsPayload`. Result: `RetainedObservationData`.

device_id:uuid observations:array reason:string

Authenticated original driver/device may append their genuine observations from their historical assignment. Validate chain ownership, source timestamps and assets; quarantine under incident without changing current work. No substituted current assignment or fake successful physical command. Duplicate observation ID with differing bytes rejects IDEMPOTENCY_CONFLICT.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: []

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: evidence.retained_stale

## DeclineTransfer

Capability: `custody.receive`. Input: `DeclineTransferPayload`. Result: `EntitySummary`.

transfer_id:uuid reason:string

Authenticated named receiving custodian declines only a pending transfer with zero received quantity. Source keeps custody; no receipt is inferred; record reason and inform source.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "transfer_id", "aggregate_type": "custody_transfers", "when": "required"}]

Errors: IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, TRANSFER_NOT_AUTHORIZED, VALIDATION_FAILED

Fact outcomes: custody.transfer_declined

## CancelRound

Capability: `plans.release`. Input: `CancelRoundPayload`. Result: `EntitySummary`.

round_id:uuid reason:string agreement_cancellation_id?:optional_uuid

Explicit operator cancellation of draft/planned/staged/released/active Round. Active cancellation requires every collected quantity delivered or received back/transferred, required evidence resolved, and freelance cancellation consent/compensation recorded. Release unit claims and future driver ranges; preserve executed stops and history. Unresolved physical custody blocks cancellation.

Each selected existing mutable root requires its current version. Immutable plan_proposals require version=1 plus independent source-plan base_version/hash/expiry validation. Resolve and lock dependent unit/manifest/claim records atomically. Physical replay preserves original assignment fence; only successful own predecessors supply successor resource versions. Never blindly refresh a stale assignment.

Roots: [{"payload_field": "round_id", "aggregate_type": "rounds", "when": "required"}]

Errors: CUSTODY_MISMATCH, IDEMPOTENCY_CONFLICT, NOT_AUTHORIZED, STALE_VERSION, VALIDATION_FAILED

Fact outcomes: round.cancelled
