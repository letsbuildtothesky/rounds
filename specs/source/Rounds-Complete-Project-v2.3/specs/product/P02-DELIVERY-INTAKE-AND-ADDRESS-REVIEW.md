# P02 — Delivery Intake and Address Review

Rounds specification set · Consolidated V2.3-r1 · 8 September 2026

## Changelog

- 2026-09-10 · v2.3-r1: ADR-T10 implements independent deliveries.review, exact input/version decisions and immutable before/proposed/selected history. Correct TR-090: address approval alone remains review_needed; timing/commit and entrance confirmation remain independent. Extend QA-AD-01/02 below.
- 2026-09-10 · v2.3-r1: connect the finite authorized manual context/revision read and original-form draft recovery under ADR-Q08; extend QA-IN-02. Final creation/admission and visual acceptance remain separate.
- 2026-09-10 · v2.3-r1: define the manual SaveDeliveryDraft create/update boundary, preserved submitted revisions and closed-client compatibility (ADR-T09). Correct the creation root minimum and allow repeated review-needed edits; approved form and CommitDelivery remain separate.
- 2026-09-08 · v2.3-r1: clarify the existing local preparation path independently of deferred Intercity execution; preparation and planning never create custody or receipt facts.

Feature scope: IN-01–11; AD-01–08. Database ownership: intake_batches, intake_drafts, address_suggestions.

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## Entry methods and canonical draft

Manual Add Delivery stays directly reachable through the existing plus/action. Optional paste, screenshot/image drop, multi-file, CSV and PDF use the same normalized draft. AI assistance does not replace manual fields or silently create/release work. A batch is a review workspace: each row independently reports ready, needs review, duplicate, rejected or omitted. Selected ready rows may commit with explicit per-row outcomes; do not show one success for a partially failed batch.

Canonical draft fields are city, pickup, brand, external source identity/version where present, buyer and recipient roles, recipient contact, original written address, proposed/confirmed operating point, delivery service date, direct or named window, product/physical manifest, handling requirements and permitted instructions. Unknown fields stay null with a review reason. Buyer equals recipient is an explicit relationship, not a fuzzy name match. Nonessential buyer detail must not block valid manual work.

### Manual draft persistence

SaveDeliveryDraft creates a server ID when draft_id is absent/null. There are no existing expected roots on creation; the original actor/tenant/command receipt serializes duplicates. A supplied draft_id is update-only, with exactly that intake_drafts ID/current version, never an upsert. Preserve each exact typed manual submission with schema version, input hash, field provenance, authenticated actor and received/occurred times in immutable revision history. Do not normalize away original whitespace/Unicode or combine buyer/recipient. Incomplete typed drafts may save; required planning/commit fields are validated later. A supplied point is a proposal and preparation_state/ready_by are draft intent, not an entrance confirmation, SetPickupReadiness fact or custody.

An edit to draft, extracting, review_needed or ready advances its version to review_needed and supersedes dependent address suggestions while retaining their original text/point/reviewer/time. Repeated edits while review_needed remain possible; old callbacks must match current revision/input hash before any later extraction adapter can apply them. Committed/discarded/archived drafts cannot be rewritten. The initial R1 adapter accepts only new manual drafts and its own verifiable revision chain; imported, source-backed or old unmapped drafts reject VALIDATION_FAILED without changing any source/evidence. Their explicit compatibility adapter is separate, not a guessed backfill. Save creates no delivery, reservation, manifest, assignment or physical state change. Retry lost responses through original CommandStatus before another POST.

## Parsing and review pipeline

ADR-Q08 binds the manual form to an explicit Workspace manual_intake context and exact editable draft revision. A returned city-local day/site list is not a selected pickup or admission promise. Preserve edits across drawer close/reopen and same-login tab reload, check current permission before hydration, and settle original pending saves before another write. Source Create delivery stays unavailable until CommitDelivery exists; SaveDeliveryDraft is not a completed order. In-progress draft status/error uses existing components, with visual review still required.

Receive source → validate type/size → store permitted source reference → extract text/rows → map canonical fields → propose corrections → validate readiness → review → commit delivery. Parse jobs are cancellable before commit and show per-source failures. Image decode is not OCR success; OCR output is not an address match. Preserve source-to-field provenance and parser/model version where used. Untrusted source text is data, never instructions for the AI or tool execution.

For Thai addresses retain Unicode, house/unit, moo/soi/road, subdistrict/district/province/postcode where present, landmark and user-written instructions. Normalize whitespace/phone formatting conservatively. Do not manufacture a missing unit or move a plausible address to another province to satisfy a geocoder. A geocoder name is a candidate, not a replacement for the supplied delivery address.

Any AI correction to operational content produces a visible review label and before/after changed fields. Operator can accept, edit or reject. Review records input hash and actor/time. If source input changes, invalidate dependent suggestions and previous review; never apply a late AI callback to a newer draft. Low confidence/ambiguous city or missing essential unit stays review-needed. Text approval and entrance confirmation are distinct.

ReviewAddress has independent deliveries.review authority. For the R1 compatible manual revision, input_hash is SHA256 of the exact canonical current delivery_draft payload. Accept without a suggestion must match the current address/point; edit records the explicitly selected pair. With a current nonexpired matching suggestion, accept must match its proposal, reject must keep the original pair and edit records the chosen replacement. Reject without a suggestion is invalid. Preserve original/proposed/selected text and point, decision, input/output revision, actor and time in immutable review history. A consequential review advances the draft revision and supersedes other dependent suggestions; copying unrelated draft fields preserves buyer/recipient and quantities. Subsequent SaveDeliveryDraft invalidates the prior review by advancing the version while retaining its history. Address review alone remains review_needed until the independent required-field, address-policy and timing checks succeed; it neither confirms an entrance nor creates admission, delivery, preparation or custody facts.

## Readiness and commit

Required for normal planning: permitted tenant/city/pickup, valid promised instants, identifiable recipient/authorized contact method, physically described manifest, and an address suitable for planning under configured policy. Precise entrance may remain a visible action item where policy permits an approximate candidate; release to navigation must satisfy the relevant confirmation/exception policy. Do not globally label a merely geocoded point verified.

Commit uses a draft revision, optional slot reservation and source identity under one transaction. Allocate delivery reference server-side; create contact roles, manifest revision and initial attempt-independent obligation; consume valid slot hold if present. A repeated commit returns the original delivery. Partial batch commits identify exactly which rows committed; retry only unchanged unresolved rows. Close/discard after commit cannot undo the actual delivery.

For R1 local own-team work, the configured pickup is local and the order has no required inbound dependency. It can be committed/planned/staged while preparation is unknown or preparing. An authorized merchant/operator uses SetPickupReadiness for that current manifest; ready_by is an estimate and never automatically sets ready. SetPickupReadiness records actor/time and synchronously re-evaluates the Round gate. With other execution guards satisfied, ready preparation allows explicit release; it does not create a trip, trip receipt, custody balance, pickup event or driver attempt. The assigned driver must still confirm actual full quantities at collection. If a required inbound dependency exists, genuine receipt/discrepancy checks remain mandatory even while Intercity execution is deferred; never mark it received or drop it to unblock R1. Use local no-inbound fixtures for the first R1 end-to-end run.

## Duplicate/source handling

Exact connection + external order key is authoritative dedupe within tenant. Similar customer/name/address is a possible duplicate suggestion, not automatic deletion. Manual copy legitimately creates a new delivery only after explicit confirmation. Older source revision is ignored/audited; duplicate event has no new side effect. Source changes after release/pickup become review/proposal work, never direct overwrite of current promise/manifest.

CSV headers map through a reviewed column mapping; quoted commas/newlines, UTF-8 BOM, empty rows and row numbers are handled. Formula-looking cells are treated as text, and exports escape formula injection. PDF/image files have explicit limits and safe server processing. Proposed initial ceilings: 20 MB/source, 100 pages/PDF, 500 drafts/batch; limits are configurable operational settings and must be benchmarked. Unsupported files preserve manual entry and a useful error.

Address memory is tenant-scoped. Reuse suggests a specific reviewed entrance revision. Recipient apartment and private notes do not become shared building information. Production AI/geocoder providers and retention rights must be configured before enabling real extraction.

### QA-IN-01

Actor: Authorized actor for SaveDeliveryDraft; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveDeliveryDraft under the condition in expected outcome; query affected records and compare committed events..

Then: Click Add Delivery: manual fields open immediately; invoking optional autofill leaves manually entered recipient text unchanged until explicit merge..

Status: written requirement; application execution pending.

### QA-IN-02

Actor: Authorized actor for SaveDeliveryDraft; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveDeliveryDraft under the condition in expected outcome; query affected records and compare committed events..

Then: Save a draft with buyer different from recipient, five manifest units and ready_by09:00: reload returns those separate values and unit count5..

Status: written requirement; application execution pending.

#### QA-IN-02 persistence and authorization assertions

Actor: Dispatcher with current deliveries.create for tenant/city; negative actor with only board.read/issues.decide or revoked membership.

Given: A manual draft with separate buyer/recipient, exact Thai address, five units and ready_by; old unmapped/source-backed drafts remain present.

When: Save with zero creation roots, replay concurrently, then race two edits with the same current draft root; recover an intentionally lost response through CommandStatus. Inject a failure after all domain writes; attempt foreign city/tenant/actor status, source rewrite, committed-draft rewrite and revision deletion.

Then: One creation identity, one winning edit and exact immutable submitted history. Stale/foreign/invalid edits leave no partial revision/event/outbox. Current capability and original actor/tenant/city guard replay/status. Unmapped rows remain byte-for-byte unchanged. No delivery, slot hold, custody, preparation fact or assignment is created. A repeated review_needed edit succeeds with its current root; dependent suggestions become superseded without erasing original evidence.

Additional read/browser assertions: the authorized manual_intake view returns exact compatible current revisions, actual city-local day and same-city sites without writes. Cross-city/tenant/insufficient grants and unmapped/closed roots fail closed. Exercise actual browser controller → HTTP → restricted SQL with a lost committed save and controller restart: one draft, original receipt, preserved exact text/quantity and subsequent versioned edit. Bound and verify the login/tab journal before send; corrupt/storage-conflicting journals, foreign/malformed responses, late Auth changes and stale remote revisions cannot overwrite or expose data. Retain the source field grouping and disabled Create action; verify close/reopen/reload, raw Product and quantity in browser fixtures.

Status: required extension of QA-IN-02; local evidence recorded in the Build Spec checkpoint; final commit, visual parity and configured provider activation remain pending.

### QA-IN-03

Actor: Authorized actor for CreateIntakeBatch; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CreateIntakeBatch under the condition in expected outcome; query affected records and compare committed events..

Then: Paste one text source and one image: resulting draft retains both source identities; no outgoing chat message is created..

Status: written requirement; application execution pending.

### QA-IN-04

Actor: Authorized actor for ExtractDraft; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ExtractDraft under the condition in expected outcome; query affected records and compare committed events..

Then: Use a Thai image then an OCR timeout: successful fields remain editable; timeout preserves source and draft and returns processing failure without committing delivery..

Status: written requirement; application execution pending.

### QA-IN-05

Actor: Authorized actor for ExtractDraft,ReviewAddress; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ExtractDraft,ReviewAddress under the condition in expected outcome; query affected records and compare committed events..

Then: AI changes house number12 to21: source12 and suggested21 both display; CommitDelivery returns ADDRESS_REVIEW_REQUIRED until explicit review..

Status: written requirement; application execution pending.

### QA-IN-06

Actor: Authorized actor for CommitIntakeBatch; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CommitIntakeBatch under the condition in expected outcome; query affected records and compare committed events..

Then: Batch has three drafts, one invalid phone: two succeed with named child IDs; invalid child returns a field error; retry original command creates zero duplicates..

Status: written requirement; application execution pending.

### QA-IN-07

Actor: Authorized actor for CreateIntakeBatch; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CreateIntakeBatch under the condition in expected outcome; query affected records and compare committed events..

Then: Import a two-row CSV and two-page PDF: both enter the same review queue; unsupported format or page101 rejects before extracting children..

Status: written requirement; application execution pending.

### QA-IN-09

Actor: Authorized actor for CommitDelivery; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CommitDelivery under the condition in expected outcome; query affected records and compare committed events..

Then: Commit an approved draft with preparing goods: delivery exists in Unplanned with preparation state; no assignment/broadcast is created..

Status: written requirement; application execution pending.

### QA-IN-10

Actor: Authorized actor for SaveDeliveryDraft; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveDeliveryDraft under the condition in expected outcome; query affected records and compare committed events..

Then: AI response for draft revision3 arrives after manual revision4: revision4 remains intact and source suggestion is marked stale..

Status: written requirement; application execution pending.

### QA-AD-01

Actor: Authorized actor for ReviewAddress; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReviewAddress under the condition in expected outcome; query affected records and compare committed events..

Then: Review current draft text and point: saved proposal matches explicit operator selection; geocoder suggestion and ReviewAddress both leave separate entrance confirmation false. Independent deliveries.review, exact current root and canonical input hash are required. Duplicate/lost-response status returns the original review once; racing SaveDeliveryDraft cannot overwrite a newer input. Text-only review creates no point, slot, preparation, delivery or custody; incomplete work stays review_needed. Failure after review/revision/event/outbox writes rolls them all back; revoked/foreign actor/city/tenant cannot replay or inspect another receipt. Immutable original history remains intact.

Status: written requirement; application execution pending.

### QA-AD-02

Actor: Authorized actor for ReviewAddress; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReviewAddress under the condition in expected outcome; query affected records and compare committed events..

Then: For a proposed destination change, Keep original preserves original text/point and rejects the suggestion; accept must exactly match the stored proposal; changed text/point requires explicit edit. Preserve before/proposed/selected snapshots and actor/time. Expired, superseded, wrong-draft or wrong-input-hash suggestions reject intact. Later manual edits invalidate the old review without deleting its history. R1 imported/source-backed drafts remain blocked until their compatibility adapter exists.

Status: written requirement; application execution pending.

### QA-AD-04

Actor: Authorized actor for ReviewAddress; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReviewAddress under the condition in expected outcome; query affected records and compare committed events..

Then: Thai house/soi/floor/unit conflict fixture: all original components remain visible; no invented postcode appears in committed address..

Status: written requirement; application execution pending.

### QA-AD-06

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Open Street View for D1, then next D2: Google surface targets D2; close returns to D2 on the existing Operations map..

Status: written requirement; application execution pending.

### QA-AD-07

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Remove key or use a location with unavailable imagery: loading ends in explicit unavailable/retry state; no blank pane labelled ready..

Status: written requirement; application execution pending.

### QA-AD-08

Actor: Authorized actor for GetEntrance; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetEntrance under the condition in expected outcome; query affected records and compare committed events..

Then: Exact address lookup in tenant B returns no tenant A remembered address even when text matches..

Status: written requirement; application execution pending.

### QA-AD-12

Actor: Authorized actor for Deferred; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute Deferred under the condition in expected outcome; query affected records and compare committed events..

Then: Building-level grouping stays outside current release; separate recipients retain separate delivery/manifests/proof; no merged completion command appears..

Status: written requirement; application execution pending.

### QA-DI-04

Actor: Authorized actor for SetPickupReadiness,ConfirmPickup; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SetPickupReadiness,ConfirmPickup under the condition in expected outcome; query affected records and compare committed events..

Then: Five expected units with one unchecked/missing line: normal full pickup rejects; ready signal alone produces no custody movement..

Status: written requirement; application execution pending.
