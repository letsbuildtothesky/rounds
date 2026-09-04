# Rounds · History Operating Memory

**Version:** 1.5
**Status:** Canonical — H1 Overview, H2 Deliveries, H3 Drivers and H4 Incidents complete  
**Canonical UX checkpoint:** `ux/operations/rounds-operations-current-v45.html`

## Changelog

- **v1.5 — 2026-09-04:** Removed stale phase language that still described
  H3/H4 as pending after their canonical sections were completed. The four
  History workspaces remain distinct and complete at the product/UX level.

## 1. Product purpose

History is not only a completed-delivery archive. It is Rounds' operating memory: the durable evidence of what happened, why it happened, who or what caused operational deviation, what it cost, and what deserves management attention.

History must answer three questions quickly:

1. **How are we operating?**
2. **What needs attention?**
3. **Why did it happen?**

## 2. Canonical information architecture

Primary History navigation is:

- **Overview**
- **Deliveries**
- **Drivers**
- **Incidents**

Own fleet / Rounds Network / External courier are fulfillment scopes and filters inside the relevant records. They are not the primary History information architecture.

History remains one unified operational record across all fulfillment sources.

## 3. Fair attribution principle

Rounds must not label a driver as poor or penalize a driver for events outside the driver's control.

Operational deviations must preserve cause attribution when evidence supports it. Canonical cause families include:

- Driver
- Recipient
- Traffic
- Weather
- Merchant / Operations
- Courier provider
- Process / custody
- Under review / unknown

Examples:

- Recipient unavailable → remains in delivery history, excluded from driver performance.
- Traffic +22 min → remains in delivery history, excluded from driver performance when route evidence supports the attribution.
- Driver starts a 09:00 shift at 09:17 → driver-attributed reliability event.
- POD missing until evidence is supplied → process/custody event; attribution may remain under review until evidence is complete.

Attribution must remain inspectable through underlying evidence such as delivery record, timeline, route state, communications, POD, shift/activity record, and exception history.

## 4. Driver history dimensions

Driver history is multidimensional. Rounds must not collapse this into one opaque driver score.

### 4.1 Attendance & reliability
- scheduled shift vs actual online/start time;
- late shift starts;
- missed/no-show shifts;
- early departure;
- overtime;
- attendance corrections.

### 4.2 Delivery execution
- deliveries / Rounds / Stops;
- pickup punctuality;
- delivery punctuality;
- driver-attributed late events;
- failed attempts;
- route completion.

### 4.3 Physical handling / custody
- pickup verification compliance;
- handoff verification compliance;
- POD compliance;
- missing-item events;
- damage events;
- custody transfer/return issues.

### 4.4 Operational responsiveness
- route-change acknowledgement;
- dispatcher call/message events during active work;
- emergency/escalation events.

This is operational evidence, not surveillance. Rounds should measure behavior required to execute delivery work, not irrelevant personal activity.

### 4.5 Workload context
- hours worked;
- active delivery time;
- Rounds / Stops;
- distance;
- overtime;
- workload/capacity context.

Workload context must not become a naive leaderboard because different vehicles, cargo, areas and delivery types are not directly comparable.

## 5. Phase H1 · History Overview

The H1 Overview is the management readout for the operating record.

### 5.1 Top operating readout
Default period is 30 days. The prototype also supports 7 / 30 / 90 day views.

The overview surfaces:
- delivery volume;
- on-time rate;
- exceptions;
- driver-attributed exception count;
- blended average delivery cost;
- POD compliance.

### 5.2 Needs attention
Only evidence-backed management signals appear here. Each signal must explain the evidence and why it is being surfaced.

Canonical examples:
- repeated late shift starts;
- punctuality trend below a driver's own baseline;
- external courier cost materially above blended fulfillment baseline.

Signals open an actual evidence surface or related driver/delivery record. No decorative/ghost CTAs.

### 5.3 Exception attribution
The Overview explicitly separates driver-attributed exceptions from recipient, traffic/weather, Operations/provider and other causes.

The UI should make the fairness rule visible: non-driver causes remain in the operational record but do not automatically count against driver performance.

### 5.4 Recent operational evidence
A chronological evidence feed shows recent incidents/deviations with:
- time;
- driver;
- event;
- cause;
- impact;
- performance treatment.

Every row opens the evidence drawer.

## 6. Evidence drawer

Incident evidence drawer contains:
- event and attributed cause;
- explanation;
- impact;
- driver-performance treatment;
- available evidence chain;
- direct navigation to delivery record and/or driver record when available.

## 7. Export

History Export must produce a real machine-readable export rather than a decorative success toast. The current prototype exports CSV containing delivery records and operational incidents.

## 8. Phase boundaries

Approved controlled phases:
- **H1 — Overview**: completed.
- **H2 — Deliveries history**: completed as unified delivery record, source filters, search, economics and evidence detail.
- **H3 — Driver history**: completed as the evidence-based driver operating record with live context separated from durable performance.
- **H4 — Incidents**: completed as the incident ledger with cause-attribution
  filters, review state and evidence workflow.

Existing Driver/Incident records remain functional until those dedicated visual/product phases are approved.


## 9. Phase H2 · Delivery operating record

The Deliveries surface is a unified evidence workspace rather than a generic completion table.

Canonical H2 behavior:

- one record surface covers Own fleet, Rounds Network and External courier work;
- the top readout summarizes completed deliveries, on-time outcome, exceptions, POD completion and average completed-delivery cost;
- operators can search by order, recipient, driver, source or exception;
- fulfillment-source filtering is `All / Own / Network / External`;
- result filtering separates delivered work from open/exception work;
- an `Exceptions only` filter provides immediate audit focus;
- each delivery row surfaces recipient/reference/date, promise vs actual state, fulfillment source/driver/vehicle, POD/exception evidence, distance/cost and result;
- POD and exception evidence must be visible before opening the record where space permits;
- opening a delivery record shows outcome, promise/actual/cost, fulfillment/custody facts, traffic/weather/exception context, communication evidence and performance treatment;
- driver performance treatment must preserve the fair-attribution rules from H1;
- delivery evidence reports are real downloadable records in the prototype, not ghost/export-toast controls.

Deliveries does not absorb Driver History or Incidents. Those remain dedicated
workspaces governed by sections 11 and H4 below.

## 10. Pre-H3 driver availability and performance lock

Before the dedicated H3 Drivers redesign, History adopts the live-availability/contact rules defined in `ROUNDS-SPEC-10-DRIVERS-LIVE-AVAILABILITY-CONTACT-v1.4.md`.

### Own driver history

Own-driver reliability may include scheduled operating obligations such as:

- shift start vs actual online/start time;
- missed/no-show shift;
- early departure;
- overtime;
- driver-attributed pickup/delivery lateness;
- accepted route-change acknowledgement and execution;
- custody/POD incidents.

### Network driver history

Network history must **not** penalize a driver for simply being:

- offline;
- `Not accepting jobs`;
- outside an active Network availability period;
- unavailable before any job is accepted.

Network-driver evidence should instead emphasize:

- Offers received where relevant;
- response/acceptance behavior;
- accepted-job cancellation/no-show;
- pickup and delivery execution after acceptance;
- custody/POD compliance;
- accepted-work incidents;
- merchant-specific successful work history.

Availability changes may remain in the audit trail for reconstruction, but they are context rather than a performance score.

### Current state vs History

The dedicated **Drivers** product surface owns the driver's current live status (`Open for jobs`, on shift, on a Round, next available, offline). History owns durable operating evidence and trends. H3 may show a compact current-state link/context, but it must not confuse live presence with historical performance.


## 11. Phase H3 · Driver operating record

The Drivers History surface is an evidence workspace, not a leaderboard.

### 11.1 Scope

H3 uses two explicit history scopes:

- **Own team**
- **Network relationships**

The scope changes the evidence model. Own-team attendance obligations are valid performance evidence; Network availability before acceptance is not.

### 11.2 Compact live context

H3 may show current operating context so a manager can understand the record in the moment, including:

- current shift / Round;
- `Open for jobs`, busy, paused or unavailable state where applicable;
- projected next availability;
- presence freshness;
- permitted contact action.

This live context is visually separated from the historical evidence and must not be treated as the history score itself.

### 11.3 Own-team evidence

Own-driver rows and details surface the following dimensions where evidence exists:

- 30-day deliveries and on-time delivery rate;
- driver-attributed late deliveries;
- late shift starts;
- missed/no-show shifts;
- average route-change acknowledgement;
- overtime/workload context;
- pickup verification;
- handoff verification;
- POD compliance;
- custody incidents;
- recent evidence with cause and performance treatment.

A `Watch` or `Stable` trend is descriptive evidence, not a hidden composite score.

### 11.4 Network evidence

Network-driver history focuses on the merchant relationship and accepted commitments:

- merchant-specific completed jobs;
- on-time accepted work;
- Offer acceptance/response context;
- post-accept cancellation/no-show;
- POD/custody compliance;
- accepted-work incidents;
- recent merchant work history.

`Open for jobs`, `On a Round`, `Not accepting jobs`, stale presence or offline state remain context only and do not lower Network performance.

### 11.5 Contact visibility

H3 exposes the currently permitted merchant action without inventing access:

- Own team: Message / Call when team policy/current work allows it.
- Preferred/known Network: `Ask availability`; relationship Message only where direct-contact opt-in exists.
- Accepted work: normal job-linked Message / Call contract.
- Unknown Network supply: Offer/Broadcast only; no casual chat.

Every visible H3 contact control must invoke a real prototype behavior or route to the real operating surface. No ghost controls.

### 11.6 Network location privacy

Before an accepted tracking relationship exists, H3 may show only approximate distance/area and availability context. Exact live Network coordinates remain protected.

### 11.7 Fair-attribution note

H3 must make the causal treatment explicit:

- traffic, recipient, weather, Operations/provider and unresolved events stay visible;
- they are not automatically counted against driver reliability;
- under-review handling/custody events remain under review until evidence supports attribution.

Driver History does not absorb the Incidents ledger. Incidents remains the
separate H4 workspace below.


## H4 · Incidents workspace

- Incidents is a first-class History view, not a placeholder.
- Every incident records event, severity, actor/provider, cause attribution, operational impact, resolution state and performance treatment.
- Cause attribution may be Driver, Recipient, Traffic/Weather, Operations, Provider or Under review.
- Driver performance must distinguish counted events from excluded external causes and unresolved attribution.
- Incidents support search plus severity, cause and performance-treatment filters.
- Selecting an incident opens an evidence drawer with attribution, operational impact and a chronological evidence trail.
- Where linked, the evidence drawer opens the canonical delivery record.
- Incident records are exportable/downloadable for audit.
- A late delivery caused by traffic/recipient/provider must not silently count against an own driver.
