# P04 — Planning Routing and Team Release

Rounds specification set · Consolidated V2.3 · 8 September 2026

## Planning scope and information

Plan belongs to tenant, city and service date. A current Plan contains locally ready deliveries and inbound bookings expected at the selected destination hub. The destination hub is the originating pickup site for its local Rounds. A trip, booking or delivery does not need to be physically received to appear in Plan.

Operators can generate complete routes, assign eligible drivers and vehicles, move stops or whole unstarted Rounds, change departure/service time, save and stage them before the truck arrives. Preserve stable delivery/stop/Round IDs. Each local Round has one originating pickup; additional collection is an explicit task/change. Brands, pickup sites, promised windows, required handling and expected preparation/inbound readiness remain visible.

Plan uses reviewed destinations, actual dated driver/vehicle shifts, cargo limits, current commitments, travel/service estimates and required return/reload. Physical/legal feasibility and protected commitments come first; then reduce uncovered work and missed promises; then travel and idle time. Never trade a hard vehicle or custody restriction for a shorter route. Store provider provenance, input hash and calculation time; unavailable travel time is not zero.

## Timeline, capacity and editing

The visible horizon follows shifts, promises and Round start/finish with padding. Overnight work continues across midnight with clear next-day labels. A selected empty date stays empty; never reuse today's driver hours. Driver/vehicle labels remain sticky while the timeline scrolls horizontally; height is adjustable with mouse or touch.

Each departure checks stop count plus cargo class quantity/space constraints. Show relevant used/maximum values and identify the highest utilization as the limiting dimension; ties show both. A prohibited class with maximum zero is an incompatibility, never a percentage. For example Stops 3/3 and Cakes 1/1 explain why adding another delivery fails. Hide irrelevant zero-value classes.

Use a dedicated stop drag handle and explicit insertion targets; selection is not movement. Offer Move up/down/to Round and explicit driver/departure selectors on touch/keyboard. Current/performed/custody steps cannot be reordered as ordinary future stops. Current destination corrections use the versioned live-change flow. Moving all unstarted stops may remove an empty draft shell; never delete execution history.

Preview shows old/new assignment, changed capacity dimensions, departure, ETAs, downstream late minutes, return, reload, free-after and shift impact. Recalculate following Rounds for each affected driver. Physical incompatibility blocks; configurable timing risk may allow an explicit authorized override. Stale input hash/version requires a refreshed preview. PreviewPlanMove produces a proposal; ApplyPlanProposal commits it. SaveRound edits draft/planned team metadata; SaveStopPlanningFields changes service duration under the same rules.

## Fulfillment portions and planning identity

Launch rule: each delivery is collected as its complete current manifest. One internal fulfillment unit represents the whole delivery; it cannot be split or independently assigned in portions. Missing required quantities block that delivery only. Other complete deliveries may proceed after explicit route/assignment adjustment. Pre-arrival planning remains allowed. Partial inbound/return receipts and actual damage or loss are recorded truthfully; they never authorize short pickup or automatic remainder delivery.

## Save, Stage and Release

Save preserves the future plan without issuing work. StagePlan publishes provisional team allocation and reserves the relevant driver busy range, even when goods are still inbound. Driver preview clearly says Awaiting inbound or Awaiting preparation. Staging is not receipt, pickup or departure.

ReleasePlan checks only selected Rounds. Required goods must be actually received at their pickup site, preparation ready, vehicle/shift compatible and address/consent/issue gates satisfied. It creates current assignment/release snapshots and durable notification events atomically. Device received and driver acknowledged are distinct. Acknowledging uncovered deliveries does not make them assigned.

Departure-gate priority is blocked, discrepancy, awaiting receipt, awaiting preparation, ready. Recompute for each Round after an affecting command in the same transaction. It is not a timer or a client-computed authorization decision.

## Morning inbound example and delayed-truck playbook

At 07:00 Hua Hin expects five deliveries on T1 at 09:00. Build R1 for D1–D3 and R2 for D4–D5, assign compatible drivers and stage both. The hub is their pickup. When the truck ETA changes to 10:00, retain the routes/stop IDs and ordering; show revised readiness, promise risk and provisional reservation conflicts. Do not silently reserve a driver indefinitely or shift another accepted job.

The operator may keep the allocation, preview a later departure, assign another eligible team driver, or withdraw the provisional allocation to use that driver on ready local work. WithdrawRelease on a staged Round removes the provisional assignment/reservation while retaining its planned route and inbound links. Re-stage after a new allocation is chosen. Reallocation previews return/reload and the driver's subsequent commitments. Existing freelancer commitments use consent and compensation rules, not team withdrawal.

If D3 is missing but D1/D2/D4/D5 arrive, R2 can become ready independently. R1 remains blocked by its own missing line; the operator may move D3 to later work, subject to normal constraints. Never fabricate receipt to free a route.

## Live changes and automation

Started work and accepted freelancer scope remain protected. Own-team instructions are versioned and await driver acknowledgement; changing driver after collection requires physical transfer/disposition. PauseRound sets an operational hold, not a completed state. Withdraw/reassign affects only eligible future scope and never erases performed work.

Own-fleet automation uses the same preview, capacity and timing validator as manual edits, with configured insertion/added-time limits. Outside those limits it requests review. It never starts a freelance broadcast. The operator can broadcast selected eligible work at any time regardless of spare own-driver capacity.

## Transaction and acceptance ownership

TypeScript handlers own pinned database transactions and lock affected plan, claims, Round and commitment roots in canonical order. Database constraints backstop overlap and identity. Exact states, event branches, root versions and errors are in COMMAND-CATALOG.json and TRANSITIONS.json. A generated plan is a proposal, not a guaranteed global optimum. See the numbered acceptance cases for pre-arrival staging, delay/reallocation, capacity and independent partial receipt.


## Proposal and assignment identity

An immutable proposal has its own UUID and constant version 1. base_version is the source plan version. Apply/Release validates both, plus input/policy hash and expiry. Never substitute base_version for proposal version.

StagePlan creates or reuses a provisional team assignment for the driver preview. Own-team release reuses its ID and records a plan_release. Freelance offer acceptance creates origin=freelance assignment with agreement_id and no plan_release; it releases the accepted Round/stops even before preparation/receipt. In both modes actual collection requires the current ready gate. Gates are synchronous derived values; the service registry’s derive:departure_gate is not a queued worker.

PauseRound sets operational_hold; it does not invent a paused lifecycle state or pretend a moving driver has stopped. CancelRound supports active work only after all collected goods have a recorded disposition and agreement cancellation/compensation is resolved. Reassignment preserves stable route/stop IDs when the same portion moves.

### QA-DI-05

Actor: Authorized actor for ReleasePlan,AcknowledgeAssignment; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReleasePlan,AcknowledgeAssignment under the condition in expected outcome; query affected records and compare committed events..

Then: Release R1 then driver reports cannot_comply: assignment stays visible with action required and departure blocked until operator resolution..

Status: written requirement; application execution pending.

### QA-DI-08

Actor: Authorized actor for ReassignRound,ConfirmTransferReceipt; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReassignRound,ConfirmTransferReceipt under the condition in expected outcome; query affected records and compare committed events..

Then: Reassign collected goods from S to N: assignment update alone gives N zero goods; N-authenticated physical receipt transfers the specified balance once..

Status: written requirement; application execution pending.

### QA-PL-01

Actor: Authorized actor for GeneratePlan; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GeneratePlan under the condition in expected outcome; query affected records and compare committed events..

Then: At 07:00 with inbound ETA 09:00, all five expected destination deliveries appear in the Plan pool and can be placed in driver lanes..

Status: written requirement; application execution pending.

### QA-PL-02

Actor: Authorized actor for GeneratePlan; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GeneratePlan under the condition in expected outcome; query affected records and compare committed events..

Then: Request proposal for five deliveries: response is202 with operation ID; completed query identifies planned and uncovered IDs explicitly..

Status: written requirement; application execution pending.

### QA-PL-03

Actor: Authorized actor for SaveRound,SaveStopPlanningFields,PreviewPlanMove,ApplyPlanProposal; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveRound,SaveStopPlanningFields,PreviewPlanMove,ApplyPlanProposal under the condition in expected outcome; query affected records and compare committed events..

Then: Change R1 pickup/driver/time through a current proposal: returned plan shows selected site/driver/vehicle and revised departure, with one revision increment..

Status: written requirement; application execution pending.

### QA-PL-04

Actor: Authorized actor for PreviewPlanMove,ApplyPlanProposal; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute PreviewPlanMove,ApplyPlanProposal under the condition in expected outcome; query affected records and compare committed events..

Then: Move R1 from S to N and one stop back to Unplanned: no duplicate active dropoff remains; old lane no longer owns moved scope..

Status: written requirement; application execution pending.

### QA-PL-05

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Zoom timeline and fit R1 at tablet width: shift boundary, stop details and return/reload gap remain visible and selected route stays selected..

Status: written requirement; application execution pending.

### QA-PL-06

Actor: Authorized actor for ApplyPlanProposal; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ApplyPlanProposal under the condition in expected outcome; query affected records and compare committed events..

Then: Bike max_stops 3 receives proposed fourth stop or prohibited cargo: PHYSICAL_INCOMPATIBILITY, no partial plan change..

Status: written requirement; application execution pending.

### QA-PL-07

Actor: Authorized actor for GeneratePlan; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GeneratePlan under the condition in expected outcome; query affected records and compare committed events..

Then: Travel back20min plus reload10min after last stop10:00 yields free_after10:30; next Round cannot be planned at 10:05..

Status: written requirement; application execution pending.

### QA-PL-08

Actor: Authorized actor for PreviewPlanMove; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute PreviewPlanMove under the condition in expected outcome; query affected records and compare committed events..

Then: Two route proposals return different distance/duration with provider/time: only the explicitly selected proposal can be applied..

Status: written requirement; application execution pending.

### QA-PL-09

Actor: Authorized actor for PreviewPlanMove; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute PreviewPlanMove under the condition in expected outcome; query affected records and compare committed events..

Then: Move adds12min lateness: preview names affected delivery IDs, driver load and old/new free_after, not only a generic warning..

Status: written requirement; application execution pending.

### QA-PL-10

Actor: Authorized actor for ApplyPlanProposal; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ApplyPlanProposal under the condition in expected outcome; query affected records and compare committed events..

Then: Input hash/version changes after preview: STALE_VERSION; stored plan remains unchanged until recheck..

Status: written requirement; application execution pending.

### QA-PL-11

Actor: Authorized actor for ApplyPlanProposal; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ApplyPlanProposal under the condition in expected outcome; query affected records and compare committed events..

Then: Timing warn policy permits authorized reasoned override; physical cargo violation still rejects under the same policy..

Status: written requirement; application execution pending.

### QA-PL-12

Actor: Authorized actor for StagePlan,ReleasePlan; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute StagePlan,ReleasePlan under the condition in expected outcome; query affected records and compare committed events..

Then: Stage complete inbound routes before arrival: driver sees Awaiting inbound goods; ReleasePlan rejects INBOUND_NOT_RECEIVED until required receipt..

Status: written requirement; application execution pending.

### QA-PL-13

Actor: Authorized actor for ReleasePlan; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReleasePlan under the condition in expected outcome; query affected records and compare committed events..

Then: Release only ready R2 while R1 awaits one parcel: R2 assigned, R1 remains staged, existing active R3 unchanged..

Status: written requirement; application execution pending.

### QA-PL-14

Actor: Authorized actor for SaveShiftTemplate,SetShiftOccurrence; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveShiftTemplate,SetShiftOccurrence under the condition in expected outcome; query affected records and compare committed events..

Then: Override one overnight shift ending next day: materialized UTC end is after start and adjacent service dates do not duplicate the template occurrence..

Status: written requirement; application execution pending.

### QA-FL-05

Actor: Authorized actor for SaveVehicleProfile; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveVehicleProfile under the condition in expected outcome; query affected records and compare committed events..

Then: Change bike profile max_stops 3 and cargo limit5: future plan validates against both; existing released capacity snapshot remains unchanged..

Status: written requirement; application execution pending.

### QA-FL-06

Actor: Authorized actor for SaveVehicleProfile; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveVehicleProfile under the condition in expected outcome; query affected records and compare committed events..

Then: Configure truck type/profile: catalogue displays truck; unsupported routing returns UNSUPPORTED_PROFILE rather than falsely claiming motorcycle/truck guidance..

Status: written requirement; application execution pending.

### QA-V21-TRUCK-REALLOCATION

Actor: Operator OH.

Given: R1 staged to S, T1 ETA 09:00 then10:00; N available.

When: Withdraw staged S allocation; assign eligible N using current plan; stage again.

Then: R1 and stop IDs retained; S provisional range released; N allocated only after conflict/capacity check; no receipt fabricated.

Status: written requirement; application execution pending.

### QA-V21-CAPACITY-READOUT

Actor: OH.

Given: Round uses Stops3/3 and Cakes1/1.

When: Inspect route and attempt to add one stop.

Then: Both binding dimensions visible; move blocked; maximum 0 is prohibited not percent.

Status: written requirement; application execution pending.
