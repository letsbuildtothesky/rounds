# P08 — Intercity Transport and Handoffs

Rounds specification set · Consolidated V2.3 · 8 September 2026

Feature scope: IC-01–11; DR-12. Database ownership: transport_trips, trip_bookings, trip_receipts, trip_booking_lines, inbound_dependencies.

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## Optional national board

Intercity is a tenant capability independent of local city operations and freelance supply. National map shows permitted cities/hubs, transport legs, actual driver/vehicle identity, observed position/freshness, planned/estimated arrival and remaining duration. City drill-down shows local deliveries and inbound dependencies. Markers stay geographically anchored through zoom/pan; screen-coordinate animations cannot masquerade as vehicle motion. Strategy-game clarity means understandable movement and handoffs, not decorative gameplay or fabricated telemetry.

## Trip and booking contract

Trip contains origin/destination site and timezone, service date, planned departure/arrival, driver/vehicle/capacity, receiving contact, manifest bookings and state. Proposed V1 supports explicit trip creation/copy, not an unreviewed daily recurrence marketplace. Do not assume freelance local offers automatically sell intercity transport. Existing trusted transport partners need an identified authorized driver/receiver and explicit contractual scope.

State: draft → scheduled → loading → departed → arrived → receiving → closed; cancelled is permitted only with disposition of booked/loaded goods. A trip can arrive with unresolved receipts. Closure requires booked goods resolved and required evidence complete. A route involving additional hubs uses linked legs/bookings with explicit handoff events; no implied end-to-end custody transfer.

Booking checks origin/destination/city/date compatibility, expected physical quantities/capacity and receiving availability; pickup readiness gates actual loading, not booking or local planning. Booking reserves capacity but does not load goods. Origin loading confirms actual identified quantities and from/to custody. A driver cannot depart as fully loaded merely because manifests are booked; discrepancy review or approved partial departure is explicit and leaves uncollected work visible.

## Receiving and local delivery

Arrival is explicit observed event; receiver validates manifest lines/quantities/condition. Receipt creates transfer of custody to site/receiver and marks only actually received quantities available for local collection. Missing/wrong/damaged goods open a discrepancy. Partial receipt does not mark the whole delivery ready. Destination operator can plan a future local Round before arrival, with inbound dependency and uncertainty visible; cannot confirm local collection before physical readiness.

Driver/receiver surfaces required beyond the current 47 local files: trip assignment/details, origin load confirmation, active transport leg, destination arrival, receipt/partial discrepancy, local pickup authorization and return/transfer recovery. Reuse current manifest/issue components where suitable while preserving role authority. A receiving operator and transport driver are different actors; one click must not impersonate both.

## Delay, cancellation and transfer

Delay recomputes predicted arrival and dependent local departure/promise risk. Display time remaining only from known estimate; stale/no estimate is honest. Operator reviews affected plans and communicates revised commitments where necessary. Cancellation before load releases bookings; after load every physical quantity needs alternate leg, local hold, return or documented transfer. Disabling Intercity does not erase in-flight trips.

Transfers require actual source and recipient confirmation according to policy, with manifest/line identities and evidence. Carrier change does not itself transfer custody. Receivers need site and trip grants; origin-city operator cannot silently act as a destination receiver without authority. Multi-country expansion requires explicit local policy/provider coverage; Thailand fixtures are not proof of Vietnam/China support.

Goods waiting from early arrival until afternoon retain custodian, site and timestamps. Cooling/temperature standards are deferred; no system claim that an unvalidated holding period is safe. Existing manual handling tags remain supported without implying sensor monitoring.

## Approved morning planning workflow

At the start of the day, GetTrips supplies expected booking lines, destination site, receiving contact and ETA. Each local delivery already has its stable delivery ID and inbound dependency. GeneratePlan includes these deliveries before arrival. Operators can allocate every driver, build every Round, move stops, optimize order, set departure times and save. StagePlan sends provisional routes to own drivers with Awaiting inbound goods. The planning list never hides them because the truck is still travelling.

The local Round pickup_site_id equals the destination hub. Estimate earliest local departure from inbound ETA + receiving/handling + load time and display uncertainty. If the truck is delayed, keep the route and flag affected timing; do not unplan it. Received quantities update the existing dependency and card in place. Ready Rounds can be released independently. Missing goods remain visible as blockers with exact lines/quantities; no operator override may pretend that unreceived goods exist. A partially received customer order remains blocked until its complete required manifest is received and prepared. Independently complete orders can proceed. No partial-pickup approval bypass exists.

ReleasePlan is a departure authorization, not the mechanism that makes the preplan visible. That visibility comes from StagePlan and is available before arrival. ConfirmPickup independently verifies readiness, receipt, custody and current assignment even after release.

### QA-IC-01

Actor: Authorized actor for GetTrips; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetTrips under the condition in expected outcome; query affected records and compare committed events..

Then: National city drill-down retains selected trip and shows permitted origin/destination sites only..

Status: written requirement; application execution pending.

### QA-IC-02

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Zoom/pan/pitch national map: marker geography stays fixed; stale sample is labelled stale and remaining time uses current ETA provenance..

Status: written requirement; application execution pending.

### QA-IC-03

Actor: Authorized actor for SaveTrip,ScheduleTrip; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveTrip,ScheduleTrip under the condition in expected outcome; query affected records and compare committed events..

Then: Trip requires explicit origin/destination, driver/vehicle, window and receiver; schedule creates one committed driver range..

Status: written requirement; application execution pending.

### QA-IC-04

Actor: Authorized actor for BookTrip; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute BookTrip under the condition in expected outcome; query affected records and compare committed events..

Then: Book5 units against capacity 4: PHYSICAL_INCOMPATIBILITY; no partial booking. Booking while preparation unknown is allowed when expected capacity/time valid..

Status: written requirement; application execution pending.

### QA-IC-05

Actor: Authorized actor for ReceiveTrip,StagePlan; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReceiveTrip,StagePlan under the condition in expected outcome; query affected records and compare committed events..

Then: Stage all routes at 07:00; at 09:00 receive 4 of 5 units: ready independent Rounds may release, missing line stays staged with a receipt blocker..

Status: written requirement; application execution pending.

### QA-IC-07

Actor: Authorized actor for GetHistory; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetHistory under the condition in expected outcome; query affected records and compare committed events..

Then: Trip activity separates booked5, loaded5, received4 and one discrepancy with receiver actor and timestamps..

Status: written requirement; application execution pending.

### QA-IC-08

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Open Intercity handoffs from city Plan and return: selected service date, city and planned routes remain unchanged..

Status: written requirement; application execution pending.

### QA-IC-10

Actor: Authorized actor for Deferred; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute Deferred under the condition in expected outcome; query affected records and compare committed events..

Then: No temperature threshold, refrigerated holding safety or cold-chain guarantee is enabled by a receipt event..

Status: written requirement; application execution pending.

### QA-DR-12

Actor: Authorized actor for ReceiveTrip,ConfirmTransferReceipt; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReceiveTrip,ConfirmTransferReceipt under the condition in expected outcome; query affected records and compare committed events..

Then: Destination receiver can read booking IDs/lines and authenticate receipt; local driver sees dependency-ready state only for actual received goods..

Status: written requirement; application execution pending.

### QA-V21-RECEIPT-INDEPENDENCE

Actor: Receiver RH / OH.

Given: T1 carries D1–D5; R1=D1–D3 and R2=D4–D5.

When: Receive L1,L2,L4,L5; attempt release R1; release R2.

Then: R1 returns INBOUND_NOT_RECEIVED for L3; R2 ready/released; all five original delivery IDs preserved.

Status: written requirement; application execution pending.
