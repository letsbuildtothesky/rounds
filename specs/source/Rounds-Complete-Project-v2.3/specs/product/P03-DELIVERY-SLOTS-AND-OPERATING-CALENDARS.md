# P03 — Delivery Slots and Operating Calendars

Rounds specification set · Consolidated V2.3 · 8 September 2026

Feature scope: PL-14; ST-02; IN timing. Database ownership: slot_templates, slot_template_versions, slot_overrides, slot_occurrences, slot_reservations, slot_occurrence_bindings.

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## Slot identity and promises

A slot is an admission/timing rule, not a route or a driver's guaranteed throughput. A business may use named windows or direct promised intervals. Direct windows remain valid for planning and own-fleet automation. A delivery stores its resolved promised start/end instants, source slot occurrence/revision and timezone. Later template edits never silently rewrite promises already given to customers.

Each template has tenant/city, optional pickup/brand scope, stable ID/name, enabled state and version history. Each immutable version stores applicable weekdays, effective date range, timezone, promised start/end, cutoff, release, maximum admitted orders and rule/policy references. Distinguish max orders from max stops per vehicle departure and physical cargo capacity.

## Temporal representation and precedence

Service date refers to local date at the applicable operating city/site. Store local minute offsets from its midnight: start 0..1439; end may extend to 2880 for next-day completion; cutoff may be negative for previous-day order deadlines. Resolve to actual UTC instants using named timezone and retained resolution metadata. Proposed bounds: slot length at most 24 hours; larger commitments use explicit multi-day windows outside named-slot V1. DST ambiguous/nonexistent local times require explicit offset resolution or validation error; never rely on machine-local timezone or silently roll forward.

Resolve tenant defaults → city defaults → applicable pickup/brand policy → dated template override. A specific date override replaces the resolved occurrence settings or closes admission for that date; it does not edit recurring template history. If several applicable pickup/brand rules conflict, do not silently choose newest; require a unique explicit binding. One date/template override is allowed. Deleting an override returns future/uncommitted admission to the recurring basis with impact review.

Default temporal validation: cutoff ≤ release ≤ promised start < promised end. Equal cutoff/release is allowed. Actual work may be manually released earlier only through an explicit policy-authorized override; no UI trick changes the promised date. If a commercial use case needs a different timing policy, version it explicitly before enabling rather than relaxing all validation.

## Admission and reservation transaction

A slot view exposes remaining admission, cutoff state, closure and last confirmed availability. This is not a promise of own-driver capacity. Preliminary UI counts are advisory; the server decides.

1. Resolve the current applicable template version and override for service date; identify the current occurrence/admission revision.
2. Lock the occurrence admission row. Materialization also locks the template/date identity or uses a stable advisory lock so duplicate occurrences cannot split capacity.
3. Expire due temporary holds using server time. Count committed reservations plus unexpired held reservations.
4. Reject closed/full/after-cutoff admission unless the caller has explicit override capability with reason. An override does not waive vehicle feasibility or accepted-driver consent.
5. Insert or return the idempotent hold for draft/source key. Proposed hold TTL is five minutes; server response includes exact expires_at. Refresh never creates multiple holds for the same draft.
6. On delivery commit, recheck hold ownership, occurrence revision and expiry under the same lock; convert held → committed with delivery linkage. A lost response reconciles the original reservation/command.
7. On discard, cancel-before-execution or moving to another slot, release the applicable admission count only under the defined policy. A physical return after delivery does not automatically reopen past admission.

A reservation uses one draft or one delivery identity at a time; conversion changes that relation atomically. To move between slots, lock both occurrence IDs in stable order, check target capacity, transfer reservation and update proposed delivery window together. If any check fails, source reservation stays intact. A temporary provider/API outage does not create a second allocation counter.

## Template, override and capacity edits

Editing a recurring template creates a new version effective on specified future dates. Show counts of open holds, committed deliveries and already released work affected. Already promised deliveries retain their snapshot unless individually changed through the appropriate customer/driver contract. Capacity may be reduced below existing committed count only as an explicitly acknowledged overcommitted occurrence: preserve reservations, close further admission and surface Action. Do not delete bookings to make counters look compliant.

Closing a slot/date stops new admission. Committed work remains scheduled. Reopening restores admission only under current capacity and cutoff. Duplicate slot copies configuration into a new editable draft with a new ID; discard creates nothing. Special-day override add/edit/delete uses expected revision, unsaved-change protection and a consequence summary.

## Release, planning and shortfall

Release time makes eligible work available to the configured planning/release flow; it is not an automatic freelancer broadcast. Cutoff controls accepting new orders; it does not remove already admitted work. Plan uses actual service time, physical cargo, return/reload and shift constraints after admission. If no driver fits, show unplanned/needs action and allow the operator to broadcast, revise plan or seek agreement on a new window.

Shift templates similarly resolve dated occurrences. Date-specific off/changed hours override recurrence; ad hoc shifts retain source identity. Planned work outside shift is shown as risk/blocked under policy. Attendance records actual start/end separately; templates are not payroll facts.

## Slot capacity examples

| Situation | Result |
| --- | --- |
| Last available slot unit requested concurrently twice | One valid hold/commit wins; second sees full |
| Expired hold and retry of original commit | Reconcile whether committed; otherwise re-admit under current rules; no false guaranteed slot |
| Slot cap 10, eight committed, reduced to six | Eight preserved; visible overcommit and no further admission |
| 23:00–02:00 delivery | Same service date with explicit next-day end; correct actual instants |
| Named slots disabled | New direct-window entry available; previous promised windows remain unchanged |
| Own bike full but slot admission available | Admission may succeed; planning still needs capacity; operator decides whether to broadcast |

## Data, jobs and queries

Occurrence materialization is idempotent, horizon-limited (proposed 90 days) and rerunnable; do not generate infinite recurrence. Expire holds at due time and reconcile any backlog before admission. Release eligibility is computed from server time even if the scheduled wakeup is delayed. Queries return resolved occurrence version, instants, committed/held counts, capacity, closure/cutoff reason and permitted override actions. Domain events distinguish template revised, occurrence overridden/closed, reservation held/committed/released/expired and promise changed.

## Admission revision pointer

`slot_occurrence_bindings` owns the single current occurrence per tenant/template/service date. Materialization takes the template/date advisory lock before creating or replacing this pointer. Existing reservations remain on their occurrence until an explicit atomic migration or expiry; capacity counting across an old/new revision must include all live reservations for the logical template/date. A revision swap cannot reset consumed capacity. Block new admissions while an override reduces capacity below current commitments, report overcommit and preserve issued delivery promises.


## V2 reservations and scope

Resolve one most-specific slot template (site+brand, site, brand, city); reject ambiguous equal-specificity rules. One live hold per draft and one current committed reservation per delivery are database-enforced. RefreshSlotHold extends the existing live hold up to the total-lifetime ceiling and never revives expired rows. MoveSlotHold locks both logical admission keys and updates the same hold. Renewing after expiry creates a new historical identity. A committed reservation cannot be converted back into a draft hold. A new delivery attempt at a new window is a new admission with an explicit prior reservation disposition.

### QA-IC-09

Actor: Authorized actor for MoveDeliveryWindow; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute MoveDeliveryWindow under the condition in expected outcome; query affected records and compare committed events..

Then: Destination cutoff differs from origin: promised delivery window uses destination timezone, transport times retain origin/destination instants..

Status: written requirement; application execution pending.

### QA-ST-02

Actor: Authorized actor for SaveSlotTemplate,SetSlotOverride; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveSlotTemplate,SetSlotOverride under the condition in expected outcome; query affected records and compare committed events..

Then: Site+brand slot wins over city default; ambiguous same-specificity slots reject instead of consuming both counters..

Status: written requirement; application execution pending.
