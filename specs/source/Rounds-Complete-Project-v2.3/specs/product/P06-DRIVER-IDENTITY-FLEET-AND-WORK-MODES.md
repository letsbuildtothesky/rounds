# P06 — Driver Identity Fleet and Work Modes

Rounds specification set · Consolidated V2.3 · 8 September 2026

Feature scope: FL-01–08; DR-01–04/09/10. Database ownership: drivers, driver_relationships, invitations, driver_contact_permissions, onboarding_drafts, verification_applications, verification_evidence, availability_declarations, availability_requests, vehicle_types, vehicles, freelance_vehicles, attendance_events.

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## Identity and entry

One global driver principal has employer memberships, known-merchant relationships and Network eligibility separately. Phone OTP authenticates; team invite/independent path follows authentication. Proposed OTP guard: per-number/device/IP rate limits, short-lived codes, bounded attempts and resend cooldown; exact provider limits remain configured and abuse-tested. Do not disclose account existence through errors. Invalid/expired/revoked/already-used invitations have distinct useful recovery without joining the wrong tenant. Team identity comes from signed invitation, never a query-string business name.

A06 Team requires name/profile photo per current flow; A06B independent name uses later live face capture. Persist the secure onboarding draft across pages/restart. A07 preserves five display types: motorbike+box, tuk-tuk, car, pickup and van. Vehicle type is not proof of load/navigation capability. Additional historical types are mapped explicitly; trucks require their own profile and field-supported routing. Plate formatting supports Thai/Latin and composition; local character length does not verify ownership.

Network verification: identity document + license + live face evidence, country policy and payout setup. Capture is not liveness. Provider results are authenticated and application-versioned. Submitted means receipt, not approved. Correction replaces only requested evidence; valid prior evidence remains. Face correction returns to its application rather than continuing ordinary payout onboarding. Approval enables eligibility only; driver still chooses whether to open for work. Unknown submission/save uses status reconciliation before resending.

## Team employment context and scheduling

Own fleet directory shows current/date-specific driver and vehicle state, current/upcoming Rounds, contact and projected free-after. Create/edit defaults, recurring shifts and date exceptions with explicit service date. Archive preserves history and requires resolving outstanding work. Vehicle changes preview affected plans, physical compatibility and commitments. Team partners in historical UI must map to an explicit team relationship or freelance acceptance; label alone never bypasses consent.

Start shift is explicit. Before-shift availability follows configured early-start policy; no timer clocks in. Waiting, assigned, ending soon, overtime and ended are distinct home states. Driver can contact employer without active Round using a relationship thread. End shift requires no unresolved active work/custody or an authorized handoff/recovery decision. Clock-out unknown state is reconciled. Recorded attendance, scheduled duration and paid hours remain different facts.

Missed clock-out correction proposes date/time/reason, shows resulting total and submits as an auditable amendment. Proposed default: driver requests, permitted manager approves; original event stays visible. No clock correction changes operational delivery history. Overtime is duration beyond the relevant scheduled interval, not a fixed decorative bar or inferred payroll rate.

## Freelance availability and relationships

Open, paused, open-later, accepted-work and stale are independent concepts. Driver controls open/paused. Open-later carries earliest start and expiry, compared to existing global commitments. During team shift outside freelance work defaults off unless employer policy and driver choice both permit. End shift does not automatically publish Network availability.

Unknown update shows last confirmed state plus pending intent; reconnection never assumes open. Supply projection protects exact pre-acceptance GPS and other merchants' details. Pausing/declining while uncommitted does not create a reliability strike. Existing accepted job stays accessible and finishable even when future offers pause.

Known-merchant directory supports scoped Ask availability if opted in. Reply means interest/availability, not accepted job, reserved slot or permission to track exactly. Proposed V1 includes structured requests; relationship chat is available only when the driver separately opted in. Unknown businesses reach driver by job offer. Profile shows these preferences separately with revocation behavior.

## Known-driver availability reply

Ask availability is a structured request with merchant identity, requested window and server expiry. ReplyAvailability returns available, unavailable or later; later requires available_after. The response creates no job acceptance, reservation, custody or payout liability. Declining has no reliability penalty. Contact rights remain separately opted in.

Presence freshness, willingness to work, current commitment and projected free-after remain separate facts. When estimated timing is uncertain, show Available after current Round rather than an unjustified exact minute. Recompute following accepted changes, traffic/handling impacts and shift changes. Ending a team shift does not automatically publish freelance availability.

## Profile, permissions and recovery

Language is app preference available before authentication and in Profile; Thailand Thai-first, English supported. Changing language never clears outbox/work. Profile edit, vehicle, verification, payout, work accounts/help and sign-out retain current task context. Camera/microphone permission is requested on explicit use; location/background prompts explain the operational purpose and actual OS state. Recheck cannot grant permission by itself.

Sign-out or auth expiry preserves encrypted pending evidence for the same principal and denies access to another signed-in user. Explicit secure recovery/re-auth is required before sync. Account deactivation with accepted work triggers supervised recovery rather than deleting local/server history. Device switching must reconcile command IDs and current work; no duplicated shift or simultaneous incompatible jobs.

## Freelance vehicle archive

A driver may archive their own vehicle through SaveDriverVehicle(action=archive). Show an explicit reason when active work or physical custody prevents archiving. Preserve historical vehicle references; archiving does not delete verification evidence or reassign work. A later replacement requires its own record and verification.

### QA-DI-11

Actor: Authorized actor for ArchiveFleetResource; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ArchiveFleetResource under the condition in expected outcome; query affected records and compare committed events..

Then: Archive driver after delivery completion: old proof, driver identity and source references still display in History..

Status: written requirement; application execution pending.

### QA-FL-01

Actor: Authorized actor for GetDrivers; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetDrivers under the condition in expected outcome; query affected records and compare committed events..

Then: City fleet search for S returns only permitted relationships, with current and next Round IDs for selected date..

Status: written requirement; application execution pending.

### QA-FL-02

Actor: Authorized actor for SaveDriverRelationship,SetShiftOccurrence; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveDriverRelationship,SetShiftOccurrence under the condition in expected outcome; query affected records and compare committed events..

Then: End then re-invite the same team relationship: reactivate original identity with a new invitation/event; no unique violation or erased history..

Status: written requirement; application execution pending.

### QA-FL-03

Actor: Authorized actor for SetShiftAvailability; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SetShiftAvailability under the condition in expected outcome; query affected records and compare committed events..

Then: Put S on_break: S is unavailable for new commitments; accepted work/custody remains visible and affected planning inputs become stale..

Status: written requirement; application execution pending.

### QA-FL-04

Actor: Authorized actor for SaveVehicle,BindShiftVehicle; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveVehicle,BindShiftVehicle under the condition in expected outcome; query affected records and compare committed events..

Then: Bind same van to overlapping shifts S and N: VEHICLE_CONFLICT; non-overlapping shifts may share it..

Status: written requirement; application execution pending.

### QA-FL-07

Actor: Authorized actor for SetAvailability; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SetAvailability under the condition in expected outcome; query affected records and compare committed events..

Then: Own driver on team shift is not a freelancer broadcast recipient merely because employee identity exists; Network opt-in and eligibility are required..

Status: written requirement; application execution pending.

### QA-FL-08

Actor: Authorized actor for AskAvailability,SetContactPermissions; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute AskAvailability,SetContactPermissions under the condition in expected outcome; query affected records and compare committed events..

Then: Known freelancer opts out: AskAvailability is denied; opt-in request expires on server deadline and does not create a job claim..

Status: written requirement; application execution pending.

### QA-DR-01

Actor: Authorized actor for SaveDriverProfile; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveDriverProfile under the condition in expected outcome; query affected records and compare committed events..

Then: Choose Thai at first run then English in Profile: all visible action labels change without losing active job state..

Status: written requirement; application execution pending.

### QA-DR-02

Actor: Authorized actor for SubmitVerification; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SubmitVerification under the condition in expected outcome; query affected records and compare committed events..

Then: Document/photo correction keeps original evidence chain and provider/reviewer attribution; open-for-work remains blocked until authorized approval..

Status: written requirement; application execution pending.

### QA-DR-03

Actor: Authorized actor for StartShift,SetAvailability; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute StartShift,SetAvailability under the condition in expected outcome; query affected records and compare committed events..

Then: Starting team shift and opening freelance availability are distinct actions; existing commitments prevent overlapping acceptance..

Status: written requirement; application execution pending.

### QA-DR-09

Actor: Authorized actor for GetDriverHome; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetDriverHome under the condition in expected outcome; query affected records and compare committed events..

Then: Driver sees own hours, profile, earnings, notifications and assigned chat; no other merchant's unrelated work appears..

Status: written requirement; application execution pending.

### QA-V21-LATER-AVAILABILITY

Actor: Freelancer F1.

Given: Opted-in known-driver request Q1 expires 11:00.

When: Reply later at 12:00; repeat without available_after.

Then: First preserves later/time and no job commitment; second fails VALIDATION_FAILED.

Status: written requirement; application execution pending.
