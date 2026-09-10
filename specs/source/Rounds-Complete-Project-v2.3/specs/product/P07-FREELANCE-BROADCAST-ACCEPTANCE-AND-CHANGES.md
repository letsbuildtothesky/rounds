# P07 — Freelance Broadcast Acceptance and Changes

Consolidated V2.3 specification · 8 September 2026

## Operator authority and city scope

The operator starts every freelance broadcast. Own-driver capacity is not a prerequisite. Broadcasts target voluntarily open-for-work, eligible freelancers, not the tenant’s own drivers. Different cities can have concurrent broadcasts; one local broadcast has one city/date/pickup context.

Start from selected delivery IDs, exact fulfillment_unit_ids, or one existing Round, exclusively. Delivery selection resolves eligible units under locks. Unplanned work creates a search Round/stops and unit claims atomically. Moving unreleased planned work invalidates its old proposal. Released/collected work requires explicit withdrawal/reassignment/custody review; broadcasting never silently removes goods from a driver.

## Nearest-first search

Snapshot configured expansion radii, wave windows, fare and scope. Geodesic candidate proximity is distinct from road ETA; route/vehicle feasibility is checked before commitment. No review-ranking/preference expansion is enabled initially. Each candidate must have opted in, have current eligible vehicle/verification and no conflicting commitment. Policy missing or invalid blocks start with a specific reason, never a fabricated default.

Broadcast begins searching, without a persisted draft state. Waves are scheduled/active/closed/cancelled. Offers are offered/accepted/declined/taken/expired/withdrawn. Local composer drafts and acceptance-in-progress are UI states only. Server time owns every deadline. Closing the browser does not pause search.

## Acceptance creates usable work

RespondOffer(accept) locks the offer/broadcast scope, unit claims, Round/stops and driver conflict guard. Exactly one winner creates the immutable agreement, an acknowledged origin=freelance assignment with agreement_id, released Round/stops, committed driver interval and open settlement. No own-team plan/proposal/release is required. Return those identities through the command result/resources and GetDriverRound.

The route may be accepted before preparation or truck receipt. Keep its departure gate awaiting the missing prerequisite; the driver can inspect the job but cannot collect until actual readiness. Readiness later updates the same assignment; no second acceptance is required.

Other drivers’ still-offered rows become taken. Decline changes only the responding offer. Expired, withdrawn or changed scope cannot be accepted. Lost response is reconciled using the original command ID; a repeated request does not create another agreement or driver range. Scope-authorized tracking grants are issued only for the appropriate work interval.

## Accepted changes and cancellation

Team instructions apply with acknowledgement; freelancer material changes require explicit consent to the exact amendment. Fare, destinations, extra pickup/return, removed goods, time and distance effects are visible. Zero fare delta does not remove consent requirements. Decline/expiry/withdrawal preserves the original agreement.

A freelancer accepts complete deliveries. Missing items block pickup of the affected delivery. Removing that delivery from accepted work requires the existing consent/compensation process; never split its goods between freelancers.

CancelAgreement resolves the whole remaining accepted scope and applicable compensation. CancelRound additionally requires physical goods disposition. Financial/evidence disputes are separate records; they cannot rewrite completed contractual work. Payment execution, reputation ranking and external courier fallback remain deferred.

## Communication and privacy

Offers disclose the scope/fare needed for consent; exact recipient contact follows accepted-job authorization. Unknown candidates do not become an unrestricted chat directory. The accepted driver is reachable directly from their map marker/Round. Failed notifications do not undo acceptance. Current agreement, assignment and custody remain authoritative on reconnect.

### QA-AD-03

Actor: Authorized actor for StartBroadcast,ReleasePlan; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute StartBroadcast,ReleasePlan under the condition in expected outcome; query affected records and compare committed events..

Then: An unresolved destination correction produces ADDRESS_REVIEW_REQUIRED on both operations; no claim or release is committed..

Status: written requirement; application execution pending.

### QA-DI-09

Actor: Authorized actor for ProposeChange; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ProposeChange under the condition in expected outcome; query affected records and compare committed events..

Then: Team destination instruction changes current target with new version and acknowledgement pending; collected manifest quantity stays5..

Status: written requirement; application execution pending.

### QA-BC-01

Actor: Authorized actor for StartBroadcast; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute StartBroadcast under the condition in expected outcome; query affected records and compare committed events..

Then: Own driver is free but operator broadcasts unplanned D1: create one search Round and claim D1; concurrent team release loses CLAIM_TAKEN..

Status: written requirement; application execution pending.

### QA-BC-02

Actor: Authorized actor for StartBroadcast; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute StartBroadcast under the condition in expected outcome; query affected records and compare committed events..

Then: Single and five-stop searches expose pickup ready-by, windows, vehicle/load, scope hash and guaranteed total fare before accept..

Status: written requirement; application execution pending.

### QA-BC-03

Actor: Authorized actor for ExpandBroadcast; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ExpandBroadcast under the condition in expected outcome; query affected records and compare committed events..

Then: Wave radius advances from configured1000m to3000m; deadlines come from server and wrong/older wave requests do not resend expired offers..

Status: written requirement; application execution pending.

### QA-BC-04

Actor: Authorized actor for GetBroadcasts; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetBroadcasts under the condition in expected outcome; query affected records and compare committed events..

Then: Bangkok and Hua Hin searches run concurrently; city filter shows correct jobs and acceptance opens the matching city context..

Status: written requirement; application execution pending.

### QA-BC-05

Actor: Authorized actor for StopBroadcast,RestartBroadcast; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute StopBroadcast,RestartBroadcast under the condition in expected outcome; query affected records and compare committed events..

Then: Stop search then restart: new broadcast/offer IDs, old offers remain withdrawn, no old offer can win..

Status: written requirement; application execution pending.

### QA-BC-06

Actor: Authorized actor for RespondOffer; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute RespondOffer under the condition in expected outcome; query affected records and compare committed events..

Then: F1/F2 accept same scope concurrently: exactly one agreement/claim owner/committed range; loser sees taken or CLAIM_TAKEN, never another tenant's job..

Status: written requirement; application execution pending.

### QA-BC-07

Actor: Authorized actor for GetNetworkSupply; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetNetworkSupply under the condition in expected outcome; query affected records and compare committed events..

Then: Before acceptance supply returns area/distance-band aggregates and no exact freelancer latitude, recipient address or other merchant route..

Status: written requirement; application execution pending.

### QA-BC-10

Actor: Authorized actor for ProposeChange,ReceiveReturn; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ProposeChange,ReceiveReturn under the condition in expected outcome; query affected records and compare committed events..

Then: Freelancer accepts return scope; base arrival alone leaves return open; receiver records actual quantities before completion..

Status: written requirement; application execution pending.

### QA-BC-11

Actor: Authorized actor for ProposeChange; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ProposeChange under the condition in expected outcome; query affected records and compare committed events..

Then: mode propose exposes old/new stop scope, fare delta and deadline; original accepted revision remains current before consent..

Status: written requirement; application execution pending.

### QA-BC-12

Actor: Authorized actor for RespondChange; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute RespondChange under the condition in expected outcome; query affected records and compare committed events..

Then: Expired, wrong-driver or duplicate response cannot partially apply amendment; duplicate original acceptance replays same revision ID..

Status: written requirement; application execution pending.

### QA-BC-13

Actor: Authorized actor for CancelAgreement,InitiateTransfer; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CancelAgreement,InitiateTransfer under the condition in expected outcome; query affected records and compare committed events..

Then: Unable-to-continue after pickup creates explicit remaining goods obligations and compensation; no simple unassign loses custody..

Status: written requirement; application execution pending.

### QA-BC-14

Actor: Authorized actor for Deferred; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute Deferred under the condition in expected outcome; query affected records and compare committed events..

Then: Reputation ranking/on-route matching absent from current eligibility ordering; nearest-first rules remain deterministic..

Status: written requirement; application execution pending.

### QA-ST-13

Actor: Authorized actor for RespondOffer; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute RespondOffer under the condition in expected outcome; query affected records and compare committed events..

Then: Client clock ±10min cannot extend server offer deadline; duplicate/stale retries preserve one winner and original command result..

Status: written requirement; application execution pending.

### QA-DR-04

Actor: Authorized actor for RespondOffer; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute RespondOffer under the condition in expected outcome; query affected records and compare committed events..

Then: Expired offer shows expired and disables accept; late server response cannot resurrect the offer or duplicate a job..

Status: written requirement; application execution pending.

### QA-DR-06

Actor: Authorized actor for ProposeChange,RespondChange; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ProposeChange,RespondChange under the condition in expected outcome; query affected records and compare committed events..

Then: Team instruction requires acknowledgement; freelance proposal requires consent with old/new scope visible..

Status: written requirement; application execution pending.
