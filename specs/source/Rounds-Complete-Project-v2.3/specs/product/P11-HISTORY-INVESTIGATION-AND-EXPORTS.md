# P11 — History Investigation and Exports

Rounds specification set · Consolidated V2.3 · 8 September 2026

Feature scope: HI-01–10. Database ownership: export_jobs.

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## One operating memory

History presents Overview, Deliveries, Drivers and Incidents with scope/date filters, source/fulfillment/outcome, evidence and conversation links. Every list count and detail uses the same definitions. Use stable tenant/city/delivery/attempt/round/driver keys, not display names. Include local and Intercity references without silently filtering to Bangkok.

Delivery detail shows original/current promise, source revisions, attempt timeline, driver assignment/accepted agreement, pickup/custody, actual handoff and required proof status, issue decisions, returns and notifications. Completed, returned, cancelled and rescheduled are different outcomes. Physical handoff pending proof is visible, not included as fully evidenced Delivered. Historical revisions remain accessible according to permission/retention.

## Metrics and causality

On-time definition uses the stored promise metric/version (proposed handoff completion). Report denominator and excluded/unresolved/pending items. Driver performance separates team obligations, accepted freelance work, unaccepted declines, merchant waiting, recipient issues and unknown causes. Paused freelance availability/off-duty absence is not a failure metric. Do not rank on tiny sample size without showing denominator; initial reputation-based matching remains deferred.

Incident cause is confirmed, reported or inferred with source. Congestion/rain/temperature sample values do not prove blame. Operator records a reviewed cause and optional explanation; later corrections append attribution. Own-fleet hours/cost assumptions are not externally paid freelance settlement and must be shown as estimated where applicable. No invented precision from sample routes.

## Management readout

Overview shows completed volume, on-time rate, exceptions, driver-attributed exceptions, average delivery cost and POD compliance for selected scope/period. Every ratio includes numerator, denominator and exclusions; unavailable data is blank/unavailable, never fabricated zero. HistoryProjection returns metric definitions and evidence-backed attention alongside records.

Own-team history separates attendance/reliability, delivery execution, custody/proof, operational acknowledgement and workload context. Network history concerns this merchant's accepted commitments; paused/unavailable/declined unaccepted work is not a penalty. Avoid a single opaque score or cross-vehicle workload leaderboard.

Attention signals such as repeated late shift starts or worsening punctuality require a minimum sample, comparison interval and linked evidence. They open the actual records. A cause may be confirmed, reported, inferred or under review; excluding external causes from driver performance does not remove those incidents from operational history.

## Investigation and action

Open incident from history or current delivery. Keep linked messages/calls, route updates, source events, proof/manifest and custody chain together. Present available next action only under current permission/state; historical old actions cannot be replayed as if still valid. Driver/merchant availability contact follows P06 permissions even when reached from History. Export/detail read of sensitive records is logged where required.

## Corrections and retention

Corrections retain original event, reason, actor/time and causal reference. Changes to displayed address/profile do not change evidence snapshots. Exports honor current audience/role and retention holds. Privacy anonymization can redact PII after its approved lifecycle while preserving necessary non-identifying operational relationships. Do not promise immutable personal data forever; retention and evidentiary integrity are reconciled through explicit policy.

## Export contract

CSV/structured delivery report includes applied filters, business timezone, as-of instant, status definitions and safe rows. Formula-like user text is escaped. Large export runs asynchronously, keeps snapshot cutoff/cursor and returns a short-lived authorized download. Failure resumes without duplicate charge/notification; permission revocation invalidates further downloads. Downloaded file integrity/audit references do not expose live signed storage URLs for unrelated assets.

### QA-HI-01

Actor: Authorized actor for GetHistory; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetHistory under the condition in expected outcome; query affected records and compare committed events..

Then: Filter period/driver/incident: returned rows and totals use identical filters with stable cursor pagination..

Status: written requirement; application execution pending.

### QA-HI-02

Actor: Authorized actor for GetHistory; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetHistory under the condition in expected outcome; query affected records and compare committed events..

Then: On-time metric names handoff versus promise and denominator; missing actual time is excluded and shown as missing, never zero-minute delivery..

Status: written requirement; application execution pending.

### QA-HI-03

Actor: Authorized actor for GetDelivery; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetDelivery under the condition in expected outcome; query affected records and compare committed events..

Then: Two attempts for D1 show original and rescheduled windows separately with their own proof/return references..

Status: written requirement; application execution pending.

### QA-HI-04

Actor: Authorized actor for GetAssetAccess; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetAssetAccess under the condition in expected outcome; query affected records and compare committed events..

Then: Authorized proof download returns short-lived purpose URL; another tenant receives NOT_AUTHORIZED and no URL..

Status: written requirement; application execution pending.

### QA-HI-05

Actor: Authorized actor for CorrectIncidentCause; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CorrectIncidentCause under the condition in expected outcome; query affected records and compare committed events..

Then: Merchant waiting corrected by reviewer keeps original cause event and appends correction; driver score is not automatically reduced..

Status: written requirement; application execution pending.

### QA-HI-06

Actor: Authorized actor for GetHistory; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetHistory under the condition in expected outcome; query affected records and compare committed events..

Then: Freelancer paused outside an agreement is not counted as failed attendance or poor delivery performance..

Status: written requirement; application execution pending.

### QA-HI-07

Actor: Authorized actor for GetHistory; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetHistory under the condition in expected outcome; query affected records and compare committed events..

Then: Investigation displays current assignment, physical custodian and unresolved obligation separately for cancelled-after-pickup D1..

Status: written requirement; application execution pending.

### QA-HI-08

Actor: Authorized actor for GetConversation; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetConversation under the condition in expected outcome; query affected records and compare committed events..

Then: Only messages explicitly linked to D1 appear in D1 history; full related conversation opens separately with permission checks..

Status: written requirement; application execution pending.

### QA-HI-09

Actor: Authorized actor for RequestExport; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute RequestExport under the condition in expected outcome; query affected records and compare committed events..

Then: Export query returns operation ID; ready export references one authorized asset and includes stable event IDs in CSV..

Status: written requirement; application execution pending.

### QA-HI-10

Actor: Authorized actor for GetHistory; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetHistory under the condition in expected outcome; query affected records and compare committed events..

Then: Reused customer order number across two source connections resolves by immutable delivery/source IDs; old evidence does not attach to new order..

Status: written requirement; application execution pending.
