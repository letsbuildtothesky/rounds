# P01 — Product Tenancy and Authority

Rounds specification set · Consolidated V2.3-r1 · 8 September 2026

## Changelog

- V2.3-r1: isolate unresolved CreateTenant admission as DEC-01; keep that action disabled while existing configured workspaces proceed. No self-service permission inferred.

Feature scope: WS-01–08; ST-04/11/12/14. Database ownership: tenants, principals, memberships, cities, city_grants, brands, sites, feature_entitlements.

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## Purpose and product boundary

Rounds coordinates customer delivery work with a business's own drivers and voluntary freelance capacity. It supports a single-city business without national operations. Multiple local cities can be enabled without Intercity. Intercity adds physical transport and destination receipt; it is not another name for freelance supply. UrbanFlowers is the pilot tenant, not a special permission model.

The operator owns the decision to start a broadcast. No own-capacity prerequisite, automatic search after overload, or mandatory external courier stage exists. Routine configured own-fleet assistance remains allowed within enumerated authority. Manual intake remains primary and optional AI/paste/image fills the same draft.

## Proposed roles and capability checks

| Role | Scope | Normal capabilities |
| --- | --- | --- |
| Owner | Tenant | Membership/admin, billing, city/capability setup, delegated operations; protected physical rules still apply |
| Admin | Tenant or granted cities | Configure policies, integrations and workforce within grants |
| Dispatcher | Granted cities | Draft/review, plan/release, explicit broadcast, contact and issue decisions |
| Fleet manager | Granted cities | Drivers, vehicles and schedules; operational release only if separately granted |
| Reviewer | Granted cities | Read authorized delivery/incident history; no mutations by default |
| Finance | Tenant or granted scope | Permitted fares/settlement/usage records and exports; no automatic access to identity document bytes |
| Driver | Global identity + current job/employer rights | Own profile, allowed shift/work/availability, evidence, messages and offer response |
| Receiver | Site/trip grant | Receive named manifests and report discrepancies; no general dispatch access |

These are proposed launch roles, implemented as capability bundles. API checks the capability plus tenant, city, object relation and current state. No role can fabricate another person's acceptance, silently transfer parcels, or override proof with a forged driver event. Owner status alone does not bypass those rules. Platform support access is separately granted, short-lived, reasoned and logged; no unrestricted support UI is implied.

Membership deactivation immediately prevents new commands and subscriptions. An already accepted physical obligation enters supervised recovery. Notification links and cached tokens do not retain revoked privilege. A driver with jobs from several tenants receives per-job projections without exposing each merchant's private information to others.

## Workspace and state behavior

Header retains Rounds identity, current business, global Dispatch/Drivers/History/Settings entry points and secondary messages/alerts. City/Intercity and Now/Plan are distinct scope controls. City switching preserves or explicitly resolves a dirty draft, resets incompatible filters and prevents actions against stale city context. Counts come from the current tenant/city/date query and use the same definitions as detail/history.

Feature off hides new-work controls and explains where appropriate. Existing assigned work, custody, returns and history remain reachable. Tenant suspension blocks new commercial intake/search according to the suspension policy but does not delete execution data; emergency/fulfillment recovery uses explicitly permitted access.

## Tenant onboarding and lifecycle

Workspace admission is DEC-01: owner choice pending between self-service creation and team-approved provisioning. CreateTenant is disabled with FEATURE_NOT_ENABLED until resolved; this does not disable existing configured workspaces, tenant editing or isolated fixtures. Do not infer creation authority from the lifecycle administration role or the reserved capability name.

Create tenant identity, timezone/currency, first city, pickup/contact, initial administrator and policies. Sample data is isolated from live data. Save configuration separately from verified connector/service connection. Invitations bind to an authenticated global identity. Closing a tenant requires resolving or explicitly transferring open obligations, exporting eligible records and applying retention rules; it is not cascade delete.

Subscription entitlement and operator preference are separate. Product UI must not offer a payable module that has not been enabled for the tenant. Changes are audited with effective time and policy revision. Country expansion requires the corresponding phone/address, verification/payment, emergency and routing configuration; changing a country code is not a service launch.

### QA-WS-01

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: At 1440×900 the unchanged wordmark geometry uses #1754A6; all four nav links open their named page and active state moves once..

Status: written requirement; application execution pending.

### QA-WS-02

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Switch Bangkok to Hua Hin: no Bangkok delivery, pickup selection or unsaved draft appears in Hua Hin; a one-city tenant has no redundant city chooser..

Status: written requirement; application execution pending.

### QA-WS-04

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Switch Now to Plan for 2026-09-09: date and count equal the returned filtered list, not the prior day's total..

Status: written requirement; application execution pending.

### QA-WS-05

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: At 1440×900 map uses remaining board height and opening/closing timeline restores that height; no permanent debug/footer block is rendered..

Status: written requirement; application execution pending.

### QA-WS-06

Actor: Authorized actor for SaveBrand,SaveSite,SaveCity; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveBrand,SaveSite,SaveCity under the condition in expected outcome; query affected records and compare committed events..

Then: Create brand B2 and site H2 in tenant A: both are selectable only in permitted city; tenant B cannot retrieve them..

Status: written requirement; application execution pending.

### QA-WS-07

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Keyboard Tab reaches every visible control; Escape closes only the top dialog and returns focus to its opener; unsaved draft survives dismiss/cancel..

Status: written requirement; application execution pending.

### QA-WS-08

Actor: Authorized actor for GetDelivery; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetDelivery under the condition in expected outcome; query affected records and compare committed events..

Then: Tenant B requests tenant A delivery/asset/chat IDs: API returns NOT_AUTHORIZED and no contact, URL or text payload..

Status: written requirement; application execution pending.

### QA-IC-11

Actor: Authorized actor for SaveCity; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveCity under the condition in expected outcome; query affected records and compare committed events..

Then: A second country requires explicit timezone/currency/provider coverage; no Thailand-only assumption rewrites its local date..

Status: written requirement; application execution pending.

### QA-ST-12

Actor: Authorized actor for SaveCity; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveCity under the condition in expected outcome; query affected records and compare committed events..

Then: Bangkok and another timezone materialize distinct UTC windows from local dates; DST gap/fold without resolution returns VALIDATION_FAILED..

Status: written requirement; application execution pending.

### QA-ST-14

Actor: Authorized actor for CreateTenant; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CreateTenant under the condition in expected outcome; query affected records and compare committed events..

Then: New tenant has owner/setup state; CommitDelivery before accepted proof policy returns POLICY_NOT_CONFIGURED, never uses sample policy ID..

Status: written requirement; application execution pending.
