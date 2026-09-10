# P13 — Settings Policy and Administration

Rounds specification set · Consolidated V2.3 · 8 September 2026

Feature scope: ST-01–14; all SET families. Database ownership: policy_versions, policy_bindings.

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## Complete configuration surface

The typed policy families in contracts/POLICY-SCHEMAS.json and named entity editors in COMMAND-CATALOG.json define this edition’s field coverage. Retain workspace/cities/brands/pickups, own-fleet posture, vehicle/cargo/handling, return/reload/service/wait, shifts/recurrence/special days, named/direct windows, freelance search/accepted-change boundaries, source permissions, customer tracking/privacy/channels, driver relationship preferences, language, identity/payout, maps and native permissions. No hidden global UI sample constant substitutes for a setting.

Policy is a typed immutable version plus current binding for a declared tenant/city/site/brand scope. JSON payload has a registered schema and range/unit validation. Domain specs determine override precedence and snapshot timing. Do not implement one generic arbitrary JSON editor or let two conflicting brand/site rules silently race.

## Configuration and snapshots

| Policy family | Effective behavior |
| --- | --- |
| Admission slot/calendar | Resolve for service date; existing delivery promises retain occurrence snapshot |
| Capacity/handling | Revalidate new plan/release; accepted work retains scope and triggers impact review if vehicle becomes unsuitable |
| Proof/handoff | Snapshot when work is committed/released; emergency policy change is explicit and cannot erase already required evidence |
| Freelance search | Snapshot at operator Start; deliberate new revision for material search/fare changes |
| Customer notification/privacy | Apply current minimum privacy to future sends; retain provenance of prior authorized messages |
| Membership/contact permission | Revocation takes effect promptly; retained history does not imply future contact right |
| Commercial compensation | Accepted agreement includes applicable terms revision; no retroactive fee change |

## Save contract

Simple safe switches may commit immediately with pending/confirmed/failure feedback; rollback optimistic paint if rejected. Structured editors are drafts until Save. Numeric values include units and configured bounds. Reject invalid data rather than silently clamp. Dirty draft close/Escape/section switch offers Keep editing/Discard. Discarded new entity never survives as a ghost row. Duplicate creates a real editable copy with unique identity.

Save includes expected binding/entity revision. A conflict shows current changed fields and preserves local draft for reapplication; never last-write-wins. Batch policy changes either commit coherently or return explicit per-scope outcomes; no ambiguous half-saved authority. Audit actor, reason where material, previous/new revision and effective time.

## High-impact controls

Consequence review is required for disabling Network/Intercity, closing a populated slot, moving named slots to direct windows, disconnecting sources, deleting dated overrides, tracking off, removing surprise protection and archiving a resource with affected work. Show what new work stops, what existing commitments remain and what re-enabling restores. Active custody/history remains intact.

Owner/admin controls membership, API keys, subscription capability and service setup. Driver controls voluntary availability and opt-in relationship contact. Neither tenant owner nor a policy flag can bypass consent, impersonate receiving actor, overwrite sealed manifest or turn local evidence into server proof. Remove legacy own-capacity-gated/automatic broadcast and active Lalamove settings from current core scope.

## Administration and operations

Expose setup attention for missing city/pickup/policies/permissions/connection configuration. No credentials or identity-document content in ordinary settings summaries. Unconnected optional services are calm setup states; failed previously connected service is degraded with reason/recovery. Policy preview uses isolated fixture inputs and performs no real release, broadcast, external send or billing action. Maintain clear distinction between saved configuration and validated live service.

## Map and weather policies

SavePolicy.policy_kind equals policy.kind across all 16 families. Map uses map, never maps. Weather uses weather and controls enabled mode, provider freshness and separately justified handling buffer. Traffic already reflecting congestion must not be charged the same rain delay again. Missing/invalid configuration blocks the dependent automatic action; manual review remains available where product rules permit it.

### QA-WS-03

Actor: Authorized actor for SetFeature; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SetFeature under the condition in expected outcome; query affected records and compare committed events..

Then: Disable Intercity: local Plan still opens and existing trip history remains reachable; new trip creation returns NOT_AUTHORIZED..

Status: written requirement; application execution pending.

### QA-IN-08

Actor: Authorized actor for SavePolicy; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SavePolicy under the condition in expected outcome; query affected records and compare committed events..

Then: Save city/site/window intake defaults: new draft uses selected tenant values; a draft explicitly set to another permitted site is not overwritten..

Status: written requirement; application execution pending.

### QA-IN-11

Actor: Authorized actor for SavePolicy; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SavePolicy under the condition in expected outcome; query affected records and compare committed events..

Then: Set max_batch_drafts501 or upload20971521 bytes: reject POLICY_OUT_OF_BOUNDS/VALIDATION_FAILED; previous policy and draft remain unchanged..

Status: written requirement; application execution pending.

### QA-CM-08

Actor: Authorized actor for SavePolicy; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SavePolicy under the condition in expected outcome; query affected records and compare committed events..

Then: Configure eight named customer events: unknown event name rejects schema; each configured recipient/channel receives at most one deduped effect..

Status: written requirement; application execution pending.

### QA-ST-01

Actor: Authorized actor for SavePolicy; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SavePolicy under the condition in expected outcome; query affected records and compare committed events..

Then: Own-fleet auto insertion within bounds applies through ApplyOwnFleetAutomation; it never invokes StartBroadcast..

Status: written requirement; application execution pending.

### QA-ST-03

Actor: Authorized actor for SavePolicy; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SavePolicy under the condition in expected outcome; query affected records and compare committed events..

Then: Broadcast config with decreasing radii or response0 rejects; accepted work is unaffected by disabling new searches..

Status: written requirement; application execution pending.

### QA-ST-04

Actor: Authorized actor for SetFeature; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SetFeature under the condition in expected outcome; query affected records and compare committed events..

Then: Intercity off hides new-trip controls, preserves local city switching and in-flight recovery; temperature remains off..

Status: written requirement; application execution pending.

### QA-ST-08

Actor: Authorized actor for ReceiveIntegrationEvent; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReceiveIntegrationEvent under the condition in expected outcome; query affected records and compare committed events..

Then: Same provider event ID/hash returns same receipt; same ID/changed hash quarantines with IDEMPOTENCY_CONFLICT..

Status: written requirement; application execution pending.

### QA-ST-10

Actor: Authorized actor for SavePolicy; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SavePolicy under the condition in expected outcome; query affected records and compare committed events..

Then: Concurrent edits of policy revision2: one wins revision3, other STALE_VERSION; invalid bound leaves revision2/3 unchanged..

Status: written requirement; application execution pending.

### QA-ST-11

Actor: Authorized actor for GetDelivery; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetDelivery under the condition in expected outcome; query affected records and compare committed events..

Then: Forged tenant/city context and private object IDs are rejected at command/query and database scope; no service credentials reach client bundle..

Status: written requirement; application execution pending.
