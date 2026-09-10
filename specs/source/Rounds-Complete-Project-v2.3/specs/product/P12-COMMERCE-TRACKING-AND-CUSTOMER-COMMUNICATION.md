# P12 — Commerce Tracking and Customer Communication

Rounds specification set · Consolidated V2.3 · 8 September 2026

Feature scope: IN source intake; ST-05–09; CM-06–10. Database ownership: source_connections, source_events, customer_tracking_tokens, notification_deliveries, provider_receipts, writeback_tasks.

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## Adapter architecture and setup

WooCommerce/WordPress, Shopify and Custom API normalize into one canonical delivery contract. Plugins contain authentication/configuration/transport glue, never their own route/manifest/custody engine. Pilot proves the UrbanFlowers source through the same contract. Manual/batch intake works independently of integration state. Multiple stores retain distinct tenant/provider/store identity and defaults.

Setup stores configuration separately from successful authorization. Show unconnected, authenticating, connected, degraded, paused and revoked with last received/sent/reconciliation times. Secrets are server-side and rotated. A test preview cannot import an order, contact a customer or mark connection healthy without actual validation. Disconnect explains what inbound/outbound work stops and preserves existing deliveries and evidence.

## Inbound contract

Verify signed webhook/authenticated API using provider-specific adapter and raw-body rules, timestamp/replay checks where supported. Persist event identity and hash, acknowledge durable acceptance and process normalization idempotently. Same provider event with changed payload is a conflict/security investigation, not a second event. External source revision and modified time are provider semantics, not blind lexical string ordering.

Create/update uses city/pickup/brand defaults, buyer/recipient distinction, promised date/window, manifest/handling and source order identity. Missing or contradictory values create review-needed draft. Source does not bypass address/cargo/slot rules. Optional paid-order hold blocks release under configured rules; payment status itself does not mean delivery completed. An old update cannot overwrite operator-reviewed destination or loaded manifest.

## Independent permissions and outbound writeback

Separate intake, fulfillment writeback, tracking-reference writeback and exception writeback. Normalized Rounds events map to source-supported statuses; never send internal wave/timer/driver-private fields as fulfillment. Adapter declares mapping and unsupported states. Writeback retains outbound idempotency, source event/version, attempt and provider response. Failed or uncertain writeback reconciles before retry; disconnect pauses effects without undoing physical delivery. Reconnecting checks current source state and ignores stale queued overwrite.

Public API/outbound webhooks use stable event IDs, schema version, signed delivery, retry/backoff and subscription permissions. Replayed event never repeats physical fulfillment. Outbound public event payloads are minimal; consumers can fetch authorized detail. Revocation stops future delivery but preserves prior receipt/audit.

## Buyer, recipient and surprise privacy

Customer tracking page uses hashed, audience-scoped, expiring/revocable token. Buyer/sender and recipient see separate allowed fields. Gift/surprise protection can hide buyer/item/value details from recipient while still showing necessary delivery progress. No other stops, internal issue notes, private driver phone or full route appears. Same verified contact identity may receive deduplicated communication; name similarity alone cannot merge audiences.

Tracking status derives from committed events and pending-evidence definition. ETA is sourced/freshness-labelled; unknown stays unknown. Driver contact, if enabled, uses controlled job-linked communication and expiry. Tracking page off invalidates future public access under policy and explains change; it does not cancel delivery.

## Customer channels

Email, SMS and LINE adapters use separately configured audience/event rules. Proposed canonical events: scheduled, out_for_delivery, eta_changed, action_required, delivered, failed, retry and returned. Exact copy/templates are localized and previewable for each audience; event routing permission is saved independently. Internal Operations↔Driver chat/call remains separate.

State: queued → provider_accepted → delivered where supported, or failed/unknown. Provider acceptance is not actual reading, and channels without delivery receipt never invent it. Dedupe by event + audience identity + channel + kind. Template version is recorded at first enqueue and never changes retry identity. Template/privacy changes revalidate unsent jobs; do not replay notifications for already resolved obsolete events. Disabling all channels shows configuration state without falsifying operational status.

### QA-ST-05

Actor: Authorized actor for SaveConnection; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveConnection under the condition in expected outcome; query affected records and compare committed events..

Then: Two WooCommerce stores in tenant A keep independent source keys/city defaults; provider replay keys include connection ID..

Status: written requirement; application execution pending.

### QA-ST-06

Actor: Authorized actor for SaveConnection; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SaveConnection under the condition in expected outcome; query affected records and compare committed events..

Then: Read-only intake permission rejects writeback even when connection otherwise active; paid-order hold remains a distinct policy..

Status: written requirement; application execution pending.

### QA-ST-07

Actor: Authorized actor for ReviewSourceRevision; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReviewSourceRevision under the condition in expected outcome; query affected records and compare committed events..

Then: Older source update is ignored/audited; changed dispatched destination creates review/proposal and cannot overwrite collected manifest..

Status: written requirement; application execution pending.

### QA-ST-09

Actor: Authorized actor for SetConnectionState; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SetConnectionState under the condition in expected outcome; query affected records and compare committed events..

Then: Pause/disconnect blocks new source work while existing delivery, proof and history remain accessible..

Status: written requirement; application execution pending.

### QA-V21-TRACKING-EXPIRY

Actor: Recipient.

Given: Tracking token expires10:00 server time.

When: Read09:59; advance server10:00; read again.

Then: First allowed audience view; second410 TRACKING_EXPIRED; no private payload.

Status: written requirement; application execution pending.
