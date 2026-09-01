# Rounds · Engineering Stack & Architecture Decision

**Version:** 1.1  
**Date:** 2026-09-01  
**Status:** FROZEN after final Driver UX/localization sync; Phase 0/build-spec baseline  
**Product baseline:** Rounds Product Specs v42 + 47-screen Driver App English canonical board set (2026-09-01)  
**Purpose:** Define the engineering spine that Codex/AI agents and human reviewers must follow before production feature construction.

---

# 0. Freeze status and final amendments

Engineering Architecture v1.0 freezes the stack after adversarial review by Claude, Gemini and Grok plus current vendor-document checks. There are **no known pre-Phase-0 blockers**. Do not reopen framework/database/vendor debates unless the Phase 0 field gate returns evidence that invalidates a selected assumption.

Final amendments incorporated at freeze:

- Flutter remains the selected Driver framework, but **not because Google Navigation is Flutter-exclusive**. Google now publishes open-source Navigation plugins for both Flutter and React Native; both are pre-1.0 and not covered by Google Maps Platform plugin SLA/support.
- Flutter is therefore selected for Rounds because of the field-app UI model, predictable cross-platform rendering, our existing mobile UX direction and a clean Swift/Kotlin escape hatch. It becomes fully locked only after the Bangkok navigation/background-location gate.
- Supabase Postgres remains the system of record, with an explicit design target of **at least 1,000 simultaneously active drivers**.
- High-frequency GPS telemetry is separated from normal transactional domain writes.
- Supabase **Broadcast** becomes the default realtime delivery mechanism; naive Postgres Changes is not the fleet-stream architecture.
- Consequential commands use aggregate versions + idempotency keys; no last-write-wins for custody/dispatch.
- POD becomes a two-phase evidence commit with resumable upload.
- Cross-tenant Rounds Network access is server-mediated; RLS is the tenant safety wall, not the mechanism for broad cross-tenant data sharing.
- Supabase Queues / `pgmq` + Cron are selected for V1 durable background jobs, with one TypeScript worker service deployed as at least two production tasks/consumers.
- Planned route, active navigation route and actual trail are separate concepts.
- Thai-first Driver UX, PDPA/privacy architecture, retention, observability and total maps/address cost are first-class requirements.
- The production Driver App is **one localized application**, never separate Thai and English codebases. Thailand launches Thai-first with English selectable at first run and later in Profile → Language.
- The returned 47-screen Driver App board set is the canonical functional/layout reference; Thai boards are translation/layout-QA artifacts and must preserve the same IDs, states, commands and evidence rules one-to-one.
- Commerce integration is adapter-first around one canonical Rounds delivery contract: Shopify App, WooCommerce/WordPress extension and Public Rounds API/webhooks all normalize into the same server-side delivery intake/writeback model.
- Phase 0 is one **combined Driver Field Harness** that exercises embedded navigation and Rounds telemetry concurrently; separate navigation-only and tracking-only tests are insufficient.
- Realtime location fanout is tenant-aggregated/delta-aggregated because Supabase counts WebSocket messages per delivery to each subscriber, not once per logical broadcast.
- Google Maps Platform content restrictions are a first-class vendor-coherence constraint: Geocoding/Routes/Navigation/Places content cannot be casually persisted or rendered with a non-Google map beyond product-specific permitted exceptions.
- Vercel Functions that touch Singapore-region data must be pinned to Singapore (`sin1`) rather than relying on the US default.
- The V1 TypeScript worker is one service deployed with at least two tasks/consumers in production for availability.
- Phase 0 is reduced to the genuinely irreducible device/field gate. Other foundation work is built as part of the first vertical slice.

---

# 1. Architectural requirements — these come before vendors

The stack is acceptable only if it preserves these Rounds invariants:

1. A merchant cannot read another merchant's private operational data.
2. Cross-tenant Network exposure is field-minimized and explicitly authorized.
3. Consequential actions execute on the server, not by trusting browser/mobile state.
4. Pickup-confirmed physical custody cannot be silently reassigned or rewritten.
5. A stale offline command cannot overwrite a newer delivery/Round/Stop state.
6. Offline clients never display server success before the server commits it.
7. POD evidence cannot be marked complete when required evidence bytes are not durably stored.
8. Duplicate commands/webhooks cannot duplicate bookings, custody events, delivery completion or POD.
9. Live driver location always carries freshness; stale location is never represented as live.
10. GPS telemetry cannot overload or bloat the transactional database/realtime path.
11. Operations and Driver must not silently treat different route geometries as one truth.
12. Driver tracking occurs only inside defined operational/privacy windows.
13. All provider secrets remain server-side.
14. Every consequential mutation is traceable end-to-end.
15. Thai riders can use the Driver App as a first-class Thai product from day one.

Every later build spec and acceptance test must trace back to these requirements.

---

# 2. Decision matrix

| Area | Decision | Status |
|---|---|---|
| System of record | Supabase PostgreSQL | **LOCKED** |
| Geospatial DB | PostGIS | **LOCKED** |
| Auth | Supabase Auth | **LOCKED** |
| File/POD storage | Supabase Storage | **LOCKED** |
| Realtime domain delivery | Supabase Broadcast | **LOCKED** |
| High-frequency GPS | Dedicated batched ingest + hot current-position state | **LOCKED** |
| Background jobs | Supabase Queues / pgmq + Cron + one TS worker service (≥2 production tasks) | **LOCKED for V1** |
| Operations client | Next.js + React + TypeScript | **LOCKED** |
| Driver client | Flutter + Dart | **SELECTED — hard Phase 0 gate** |
| Driver localization | one app; `th-TH` primary for Thailand, `en` secondary; first-run + Profile language selection | **LOCKED** |
| Native mobile layer | Swift/Kotlin platform channels where required | **EXPECTED** |
| Driver navigation | Embedded Google Navigation SDK | **SELECTED — hard Phase 0 gate** |
| Motorcycle mode | Google TWO_WHEELER in supported markets; Thailand supported currently | **SELECTED — field validation required** |
| Operations basemap | Mapbox GL JS | **SELECTED for V1 — subject to maps-vendor coherence decision before production address/routing integration** |
| MapLibre evaluation | Non-blocking future/vendor-cost evaluation | **DEFERRED** |
| Server routing/matrix provider | Provider abstraction | **LOCKED abstraction; provider DEFERRED** |
| Fleet optimization implementation | Build spec after representative workload exists | **DEFERRED** |
| Maps/address/routing vendor posture | Google-coherent vs non-Google-coherent architecture; provider abstraction retained | **DEFERRED until Bangkok address/routing evaluation before first production integration** |
| Push | FCM + APNs | **LOCKED** |
| Customer Email/SMS/LINE | Provider adapters | **LOCKED architecture; providers configurable** |
| API/domain services | TypeScript | **LOCKED** |
| Commerce ingestion | canonical Rounds Delivery API + adapters for Shopify / WooCommerce / custom systems | **LOCKED architecture; exact API Build Spec next** |
| Production data/API region | Singapore / `ap-southeast-1` | **LOCKED** |
| API + worker runtime | AWS ECS/Fargate `ap-southeast-1` | **LOCKED for V1** |
| Operations web hosting | Vercel (frontend delivery) | **LOCKED for V1** |
| Backup/recovery | Supabase paid production backups + PITR before meaningful live volume | **LOCKED requirement** |
| Observability | Sentry + OpenTelemetry-compatible tracing + structured logs | **LOCKED requirement** |

---

# 3. High-level system

```text
                         ┌─────────────────────────┐
                         │   Rounds Operations     │
                         │ Next.js / React / TS    │
                         │ Mapbox operational map  │
                         └───────────┬─────────────┘
                                     │
                          reads / commands / events
                                     │
                    ┌────────────────▼────────────────┐
                    │       Rounds Server Layer       │
                    │ TypeScript command API          │
                    │ location ingest endpoint        │
                    │ provider adapters               │
                    │ one background worker           │
                    └──────────┬─────────────┬────────┘
                               │             │
                 domain truth  │             │ provider APIs
                               │             ├── Lalamove
              ┌────────────────▼──────────┐  ├── Shopify/etc.
              │       Supabase            │  ├── Email/SMS/LINE
              │ Postgres + PostGIS        │  └── FCM/APNs
              │ Auth                      │
              │ Storage                   │
              │ Broadcast                 │
              │ Queues / pgmq + Cron      │
              └───────────────┬────────────┘
                              │
                       state / auth / files
                              │
                   ┌──────────▼────────────┐
                   │  Rounds Driver App   │
                   │ Flutter / Dart       │
                   │ Google Navigation   │
                   │ SQLite/offline      │
                   │ native iOS/Android  │
                   └──────────────────────┘
```

---

# 4. Why Supabase is the Rounds system of record

Rounds is a relational logistics system:

- merchant / tenant;
- locations;
- users / roles;
- drivers;
- shifts;
- vehicles;
- deliveries;
- Stops;
- sequential Rounds;
- manifests;
- custody;
- POD;
- incidents;
- communications;
- Network relationships/offers;
- external courier jobs;
- audit/history.

PostgreSQL fits this model better than using Firestore as the primary source of truth.

Supabase gives Rounds managed:

- PostgreSQL;
- PostGIS;
- Auth;
- Storage;
- Realtime/Broadcast;
- Row Level Security;
- local Docker development;
- migrations;
- Queues / pgmq;
- Cron;
- managed compute growth.

Firebase remains useful selectively for FCM/mobile push. It is not the primary database architecture.

## 4.1 Scale position

**Rounds must be designed and load-tested for at least 1,000 simultaneously active drivers without changing the core architecture.**

The hosted Supabase Realtime limits currently document 10,000 concurrent connections and 2,500 messages/sec on Pro without spend cap / Team, with larger configurable Enterprise limits. The hosted quota—not a laboratory benchmark—is the design ceiling Rounds must engineer against.

Supabase counts an event as a WebSocket message delivered to, or sent from, a client. Therefore one logical broadcast delivered to 100 subscribers consumes 100 events. That makes per-driver/per-sample fanout the wrong shape even when connection count is safe.

That does **not** justify sending every GPS sample through normal Postgres Changes or broadcasting each point independently. Scale comes from the architecture below.

## 4.2 Scale checkpoints

- **100 active drivers:** normal early production.
- **1,000 active drivers:** mandatory staging load-test acceptance target before operating at this scale.
- **5,000–10,000 active drivers:** repeat capacity testing; live telemetry/broadcast service may be extracted if economically/operationally useful while Supabase Postgres remains system of record.
- **50,000+ active drivers:** expect a dedicated fleet-telemetry platform (streaming/MQTT/Kinesis/Kafka/Redis-class architecture or equivalent) while transactional Rounds truth may still remain in PostgreSQL.

Do not prematurely build the 50,000-driver platform. Do design the GPS boundary correctly now.

---

# 5. Client/server authority boundary

## 5.1 Rule

> **Clients display, collect and request. The server decides and commits.**

RLS protects data. It must not become the whole business-rule engine.

## 5.2 Direct client access matrix

| Operation | Client direct? | Authoritative path |
|---|---:|---|
| Authenticate / refresh session | Yes | Supabase Auth |
| Read permitted tenant-owned state | Yes where safe | RLS-protected reads |
| Subscribe to realtime topic | Yes | Authorized Broadcast |
| Upload POD bytes | Via server-issued/signed upload path | Supabase Storage |
| Buffer GPS | Yes, local only | location ingest service |
| Create/update core delivery state | **No direct table writes** | server command |
| Confirm pickup / custody | **No** | server command + transaction |
| Complete delivery / POD | **No** | server command + evidence validation |
| Accept Network offer | **No** | server command + lock/version/audit |
| Cross-tenant Network read | **No broad direct read** | server-mediated projection |
| Book/cancel Lalamove | **Never** | server provider adapter |
| Approve plan/reassign Stop | **No** | server command |

Safe direct read scopes can be refined in build specs. The default for consequential writes is server-only.

---

# 6. Multi-tenancy, RLS and Network boundaries

## 6.1 Tenant isolation

Every tenant-owned table carries `tenant_id` and uses indexed RLS policies.

Prefer inexpensive claims for the active tenant/role rather than repeatedly joining large membership graphs inside every RLS policy. Exact token-claim design belongs in the Auth/Tenancy build spec.

## 6.2 Rounds Network

Network is an intentional cross-tenant feature and therefore receives stricter treatment.

Do **not** make Network work by broadly relaxing tenant RLS.

Cross-tenant Network data is exposed through explicit server-side projections/commands that return only fields permitted by current relationship and job state.

Example pre-acceptance projection:

```text
Network driver N-883
Motorbike
~2.4 km
Open for jobs
Generalized location
```

Not automatically exposed:

- exact GPS;
- private phone number;
- other merchant identity;
- other merchant route/Stops;
- recipient/customer information;
- unrelated history.

Accepted work creates a narrower job-linked authorization relationship and audit trail.

---

# 7. Driver App framework decision

## 7.1 Selected framework: Flutter

Use **Flutter + Dart** for the Driver App, subject to the Phase 0 field gate.

Flutter is **not** selected because Google Navigation is Flutter-exclusive. As of 2026-08-31, Google publishes Navigation plugins for both Flutter and React Native; both are open-source/pre-1.0 and the plugin code itself is not covered by Google Maps Platform plugin SLA/support.

Flutter is selected for Rounds because:

1. The Driver App is a dedicated field appliance, not a generic form app.
2. Rounds needs highly consistent iOS/Android visual behavior around map/navigation → Stop → custody → POD transitions.
3. Flutter gives strong control over the UI surfaces we have already designed.
4. Core business authority lives on the server, reducing the value of sharing TypeScript domain code with Operations.
5. Contract generation can keep Dart and TypeScript models synchronized.
6. Native Swift/Kotlin platform channels are a first-class escape hatch for background lifecycle/navigation behavior that the cross-platform plugin does not expose well.

## 7.2 Expected native code

Assume some native Swift/Kotlin exists from day one for areas such as:

- iOS background-location configuration/lifecycle;
- Android foreground service + persistent notification;
- OEM battery-optimization guidance/handling;
- APNs entitlements/background modes;
- platform permission edge cases;
- deeper Navigation SDK integration if the Flutter wrapper becomes the limiting layer.

Do not treat “one codebase” as “zero native engineering.”

## 7.3 React Native fallback rule

Do **not** build Rounds twice.

Build the Phase 0 Driver spike in Flutter first.

- If Flutter + Google plugin passes: **lock Flutter**.
- If the Flutter plugin fails but native Google Navigation SDK works: build a thin Swift/Kotlin bridge and keep Flutter.
- Reconsider React Native/native-only only if Flutter itself demonstrably cannot meet Rounds field requirements.

---

# 8. Embedded Google motorcycle navigation

## 8.1 Product decision

The primary Driver navigation experience stays **inside Rounds from V1**.

External Google Maps / Apple Maps is recovery fallback only.

Intended flow:

```text
Active Round
  → Current Stop
  → Start navigation
  → Rounds navigation screen
       Google Navigation viewport
       next maneuver / lanes / route guidance
       Rounds Stop identity and safe surrounding chrome
       Operations contact / exception access
  → Arrival
  → Handoff / POD
  → Next Stop
```

## 8.2 TWO_WHEELER

Use Google's `TWO_WHEELER` mode for motorcycle/scooter work where supported. Thailand is currently supported.

Two-wheeler routing is currently Beta and may not always produce the rider-preferred path. Required vendor warnings/attribution must be part of the Driver UX/build spec.

## 8.3 Google UI/policy boundary

Rounds may customize the navigation experience only inside Google's permitted boundaries.

Do not:

- cover safety-critical current-location/turn/lane UI;
- persist prohibited navigation content such as road names/speed limits outside the allowed session context;
- assume Google navigation geometry/content can be copied to a non-Google map surface;
- design overlays that interfere with safe navigation.

The Phase 0 spike must prove that required Rounds Stop/exception/POD transitions can coexist with the safety UI.

## 8.4 Navigation destination ledger — billing/idempotency

Billable navigation intent must be server-accounted.

Create a durable concept such as:

```text
navigation_destination
- tenant_id
- stop_id
- destination_version
- driver_id
- nav_session_id
- normalized destination fingerprint
- created_at
- ended_at
- provider
- provider_request metadata where permitted
- request_count
```

Canonical key is effectively `(stop_id, destination_version)` within its tenant/job context.

Reopen/relaunch/reconnect should attach to the existing active intent when possible rather than blindly requesting the same destination again.

Alert when one Stop creates abnormal destination counts.

Headline internal metric:

> **navigation destinations / completed delivery**

Budget assumptions should initially model >1.0 destinations per Stop until field data proves otherwise.

## 8.5 Current pricing reference

As checked 2026-08-31, Google lists Navigation Request with:

- first 1,000 monthly requests free;
- $25 / 1,000 through the first paid tier up to 100,000;
- lower unit prices at larger tiers.

This pricing is an input, not a permanent architectural assumption. Cost alarms and quotas are mandatory.

---

# 9. Route truth model

Map rendering, planning, active navigation and actual movement are separate layers.

Do not collapse them into one `route` concept.

Minimum domain concepts:

## 9.1 Planned route

What Rounds intended when a plan/Round was approved.

Contains normalized provider-independent facts such as:

- Stop sequence;
- planned distance/duration;
- planned geometry only where licensing permits storage/use;
- planner source/provider metadata;
- calculated_at/version.

## 9.2 Active navigation leg

What the Driver navigation engine is currently guiding for the current Stop.

This may diverge from the planned route due to motorcycle restrictions, traffic or rerouting.

Do not assume Google Navigation content may be copied onto Mapbox. Licensing/policy must explicitly permit any field we persist or display outside Google's navigation surface.

## 9.3 Actual trail

Where the driver actually traveled, derived from the Rounds location pipeline.

Actual trail is Rounds-owned telemetry subject to retention/privacy rules.

## 9.4 Operations rule

The Operations basemap is a renderer, **not a route authority**.

No Mapbox Directions call from the browser should decide operational route truth or ETA.

Operations displays server-authoritative planned/actual operational data plus permitted live navigation status/ETA fields.

This makes Mapbox vs MapLibre a basemap/vendor decision rather than a domain-logic decision.

---

# 10. Operations map

Use **Mapbox GL JS for V1 Operations** because the current Rounds UX already depends on:

- custom operational layers;
- Network Supply;
- own / Network / external semantics;
- clustering;
- route/Stop emphasis;
- custom interaction/drawers;
- controlled workstation styling.

Mapbox does **not** own route truth.

A later half-day MapLibre + tile-provider evaluation is allowed if it can remove a commercial dependency without reducing UX/performance. It does not block V1.

---

# 11. Server routing, matrix and planning

## 11.1 Abstraction is locked; provider is not

Create a provider-neutral routing interface capable of normalized:

- point-to-point distance/duration;
- travel-time matrix;
- route geometry where licensing permits;
- traffic-aware timing where applicable;
- warnings/restrictions;
- provider/freshness metadata.

Do not encode provider IDs into the core domain except within provider-specific metadata.

## 11.2 Planning provider

Do not lock Google vs Mapbox vs self-hosted routing solely to align branding.

Active Driver navigation and fleet planning have different cost/scale needs.

A future benchmark should use representative Bangkok production data rather than only synthetic fixtures.

Possible evolution:

- early scale: commercial matrix + deterministic Rounds planner/heuristics;
- later: VRP/OR-Tools or equivalent once real constraints/data justify it;
- very high volume: self-hosted matrix/routing may become economical while commercial Google navigation remains the human-visible active leg.

The exact planner is a later engineering decision, not part of Stack v0.3.

---

# 12. Address intelligence / Places / geocoding

Navigation cost is not the entire maps bill.

Rounds also needs:

- address search/autocomplete;
- geocoding;
- potentially reverse geocoding;
- matrix/routing;
- Operations map loads;
- traffic/routing calls.

Provider choice for Bangkok address intelligence remains abstracted until we test real addresses and vendor terms/cost.

The cost model must include Google Places/Geocoding and competing providers where relevant. Persistence/caching rules must comply with the selected provider's terms.

Do not let an autocomplete provider silently become the permanent canonical address model. Rounds stores its own normalized delivery/location entities according to permitted use.

---

# 13. Driver location / telemetry architecture

This is a separate data plane from delivery/custody events.

## 13.1 Client collection

During active work:

- use the best available location source;
- when Google Navigation is active, prefer exposed navigation/location updates where technically appropriate instead of unnecessarily running two hot GPS consumers;
- otherwise use Rounds location tracking;
- attach timestamps, accuracy and source;
- always maintain freshness semantics.

Exact cadence is configurable and tested for battery/operational quality.

Proposed starting behavior for load tests, not immutable product law:

- moving: sample around 3–5 seconds;
- idle: coarser sampling;
- batch/upload around 10–30 seconds when online;
- flush meaningful transitions sooner where required.

## 13.2 Offline buffer

Location samples persist locally through temporary loss of connectivity and are sent as batches.

Do not lose the active Round/POD outbox because Auth or network disappears.

## 13.3 Server ingest

Dedicated endpoint accepts batched position samples.

Do not route every coordinate through a consequential domain-command transaction.

Server validates:

- actor/session;
- active-work tracking entitlement;
- plausible timestamps;
- tenant/job context;
- rate/size limits.

## 13.4 Hot current position

Maintain one hot current-position record/state per driver with:

- lat/lng;
- timestamp;
- accuracy;
- source;
- current Round/job context;
- freshness status.

Dispatch primarily needs this, not a 5-second historical table scan.

## 13.5 Raw samples and trail

Raw sample retention must be short and explicit.

At/after Round completion, derive useful durable evidence such as a simplified PostGIS line/trail if the product/legal retention policy requires it, then purge/downsample raw samples according to policy.

## 13.6 Live map fanout

Use **Supabase Broadcast** on tenant/job-specific private topics for thin live-presence payloads.

**Aggregation rule:** do not send one Broadcast event for every driver sample. The ingest/presence layer should coalesce changed positions into compact tenant snapshots or deltas at an operational cadence (for example ~1–2 seconds when a Dispatch board is actively watching). One payload may contain multiple changed drivers, each with freshness.

This keeps Realtime fanout proportional to active tenant viewers and update ticks rather than raw GPS sample volume. Realtime event accounting must be measured as delivered WebSocket messages, including subscriber multiplicity.

Do not use high-frequency Postgres Changes as the fleet-location bus.

Realtime is a hint/transport. Authoritative state remains server/Postgres/hot-position state.

---

# 14. Realtime architecture

Use Supabase Broadcast as the default production realtime mechanism.

Example private topics:

```text
tenant:{tenant_id}:dispatch
round:{round_id}
driver:{driver_id}
delivery:{delivery_id}
```

Use a versioned event envelope:

```json
{
  "event": "delivery.updated",
  "version": 1,
  "tenant_id": "...",
  "aggregate_type": "delivery",
  "aggregate_id": "...",
  "aggregate_version": 19,
  "occurred_at": "...",
  "payload": {}
}
```

Client receives event → checks version/relevance → reads authoritative state when needed.

Do not make a Broadcast message itself the only durable evidence of a consequential event.

---

# 15. Domain aggregates, concurrency and commands

## 15.1 Aggregate roots

Build specs must explicitly define aggregate/transaction boundaries for at least:

- Delivery;
- Stop;
- Round;
- Manifest;
- Network offer/acceptance;
- External courier job;
- POD/evidence transaction.

## 15.2 Versioning

Consequential aggregate roots carry a monotonically increasing `version`.

Every consequential command includes:

- actor/context;
- command id / idempotency key;
- aggregate id;
- expected version;
- payload;
- client occurred_at where useful.

If current server version differs, return a typed `STALE_VERSION` result with enough current state/version for recovery.

## 15.3 Conflict behavior is command-specific

Examples:

- stale acknowledgment → refresh/retry may be safe;
- stale plan edit → reject and require recalculation;
- POD against a Stop reassigned while driver was offline → **do not merge**; create/review an operational incident;
- duplicate pickup command with same idempotency key → return original successful result;
- duplicate Lalamove webhook → no duplicate state transition.

No generic “last write wins” for operational truth.

---

# 16. Offline-first Driver architecture

Use local SQLite as durable working state/outbox.

Persist:

- active Round;
- current Stop + permitted details;
- Stop sequence;
- manifest;
- acknowledgements;
- message drafts/attachments metadata;
- pending commands;
- pending POD evidence metadata;
- buffered location samples;
- auth/session recovery metadata without treating cached claims as authority.

Every offline-capable command has:

```text
idempotency_key
aggregate_id
expected_version
local_status = pending / sending / confirmed / rejected / conflict
created_at
retry metadata
```

**Never display server-confirmed success while only local.**

Session expiry/sign-out must not delete the local outbox/evidence. After re-authentication, pending work resumes under idempotency/version rules.

---

# 17. POD / evidence architecture

POD is operational evidence and must use a resilient two-phase path.

## 17.1 On device

1. Capture photo/signature/evidence.
2. Downscale/compress according to evidence quality requirements.
3. Hash asset.
4. Persist file + metadata to local outbox before network dependency.
5. Upload using resumable upload where reliability requires it.

Supabase Storage supports TUS resumable uploads and is specifically appropriate when network stability is a concern.

## 17.2 Evidence commit

Do not send image bytes inside the delivery-completion command.

Flow:

```text
upload asset
→ server can verify storage object/key/hash
→ submit CompleteDelivery / CommitPOD command referencing evidence
→ transaction validates manifest/custody/version/evidence
→ delivery commits
```

If operational policy permits acknowledging physical handoff while evidence is still offline, use an explicit state such as:

`delivered_pending_evidence`

Operations must see that distinction. It must not look identical to fully evidenced completion.

Asset hash/idempotency prevents duplicate POD objects on retry.

---

# 18. Background jobs / queue

V1 choice:

- **Supabase Queues / pgmq** for durable queueing;
- **Supabase Cron** for schedules/reconciliation triggers;
- **one TypeScript worker service** in Singapore-region proximity to the database/providers, deployed with **at least two production ECS tasks/consumers** so one task failure does not stop provider retries, notifications or retention work.

Use durable/logged queues for consequential work.

Examples:

- provider booking/retry;
- notification send/retry;
- webhook reconciliation;
- batch ETA refresh;
- import processing;
- planning jobs;
- route/trail finalization;
- retention/purge jobs.

Every external side-effect remains idempotent even when the queue provides strong delivery semantics. Network failures can occur after a provider accepted a request but before Rounds received the response.

Do not add Kafka/Redis/Temporal on day one without a measured reason.

---

# 19. Provider adapters

All external providers are server-side adapters behind normalized contracts.

Initial categories:

- Lalamove;
- commerce/store;
- customer email;
- SMS;
- LINE;
- FCM/APNs;
- routing/geocoding providers.

Provider webhook flow:

```text
receive
→ authenticate/signature verify
→ idempotency/provider-event ledger
→ normalize
→ versioned domain command/transaction
→ audit
→ Broadcast hint
```

Provider secret keys never ship to browser/Flutter.

---

# 19A. Commerce / store integration architecture

Rounds is not architected around Shopify, WooCommerce or any one commerce platform. Those systems are **sources/adapters** into one canonical Rounds delivery contract.

## 19A.1 Canonical flow

```text
Shopify App ───────────┐
WooCommerce extension ─┼──> Rounds server-side Delivery Intake API ──> normalized Delivery / manifest / service date / promise
Custom ERP / website ──┤
Public Rounds API ──────┤
Manual / AI intake ─────┘

Rounds normalized fulfillment events
        ↓
connector writeback / merchant webhooks
```

Rules:

- plugins/apps never write directly to Rounds Postgres;
- provider secrets and signing credentials remain server-side;
- external source records carry tenant + provider + external source ID and are idempotent;
- create/update/reconciliation all feed the same normalization/validation path;
- connector input never bypasses vehicle/cargo/address/promise validation merely because it came from an API;
- Shopify/WooCommerce/custom systems receive **Rounds normalized fulfillment state**, not internal provider-specific Lalamove/Network states;
- tracking URL / delivered / failed / retry / returned writeback is connector-configurable;
- webhooks from Rounds are signed, versioned and retryable;
- the public API and connector schema are contract-first and generate TypeScript/Dart client models where useful.

## 19A.2 V1 integration order

The first real integration should be the UrbanFlowers commerce source so the complete order → delivery → driver → POD → writeback loop is proven against real operations.

After the canonical contract is proven:

1. Shopify App;
2. WooCommerce / WordPress extension;
3. Public Rounds API + outbound webhooks;
4. later low-code adapters only if commercially useful.

Do not fork business logic into plugins. A plugin is an adapter and onboarding surface, not a second fulfillment engine.

---

# 20. Thai-first localized Driver App

The Driver App is Thai-first for Thailand, but production is **one localized Flutter application**, not an English app plus a separate Thai app.

## 20.1 Language selection contract

First run:

```text
A01 Splash
→ A01B Choose Language
→ A02–A05 Entry / onboarding
```

- Thailand presents `ไทย` first and treats `th-TH` as the primary product locale.
- English remains a first-class selectable locale.
- First-run language choice is explicit; it is not repeated on every onboarding screen.
- Later change lives at `L01 Profile → Language → ไทย / English`.
- Language changes must not change role, permissions, state, command semantics, evidence rules or screen IDs.

## 20.2 Persistence

The effective locale must be available **before authentication** and survive poor connectivity.

Recommended model:

- local device preference (SQLite/preferences) for boot/onboarding;
- authenticated `driver.preferred_locale` profile value for cross-device persistence;
- local choice wins immediately, then syncs safely when authenticated;
- no language change may clear the offline outbox or restart a Round.

## 20.3 Localization implementation

- all product copy uses translation keys;
- enum/state/event/API values remain language-neutral;
- Unicode-safe schema for Thai recipient/address/note content;
- dates/times/numbers render using locale-aware formatters while stored values remain canonical;
- push/local notification copy uses the driver's preferred locale where available;
- Operations must display Thai driver/customer content correctly even when dispatcher chrome is English;
- merchant/recipient free text is not silently machine-translated by default.

## 20.4 Thai UX quality

- Thai is designed and QA'd screen-by-screen, not mechanically string-replaced;
- test Thai line breaking, line height, button growth and hierarchy at 320 px and on lower-cost Android screens;
- do not shrink critical Thai text below the Driver UI Constitution minimums simply to make a translation fit;
- Thai voice guidance in Google Navigation is a Phase 0 acceptance item;
- navigation chrome, exceptions, POD and permissions must all have complete Thai copy before production pilot.

The returned English and Thai design-board folders may exist separately for design handoff, but production must remain one localized app and one behavioral implementation.

---

# 21. Privacy, retention and Thai PDPA architecture

Rounds handles continuous worker/contractor location plus recipient PII and POD imagery. Privacy requirements therefore affect schema and infrastructure from the start.

This section is **engineering architecture, not Thai legal advice**. Exact controller/processor roles, lawful bases and retention periods must be reviewed by qualified Thai privacy counsel before production.

Required architecture:

- explicit data-purpose/category register;
- driver tracking entitlement/consent-or-policy record appropriate to legal basis;
- technically enforced tracking windows;
- live-location access logging;
- subject references on PII-bearing events where needed for access/export requests;
- retention class + purge/downsample policy;
- raw GPS short retention;
- POD evidence retention policy;
- message/customer PII retention policy;
- deletion/anonymization process;
- export/DSAR support path;
- documented Singapore-region/cross-border data decision;
- audit of administrative access to sensitive driver/customer information.

Privacy/retention must become a dedicated Engineering Build Spec before production use.

---

# 22. Authentication / long-offline behavior

Use Supabase Auth.

Driver session behavior must account for short-lived access tokens and refresh-token rotation.

Contract:

- local active-work data/outbox survives token expiry or app crash;
- refresh proactively while network exists;
- losing auth never deletes pending custody/POD/location data;
- when re-authenticated, pending commands resume under idempotency/version checks;
- no cached JWT claim is trusted as authority for consequential server action.

Driver login method is a separate build decision. Phone OTP is plausible for Thailand but has SMS cost/abuse implications and must be modeled if selected.

---

# 23. Production deployment topology

Initial production topology should stay intentionally small.

## 23.1 Region

Keep database, command API and worker in/near **Singapore `ap-southeast-1`** for Bangkok latency and predictable data-location documentation.

Supabase currently offers Singapore as an exact AWS region.

## 23.2 Services

Recommended initial shape:

```text
Vercel
  Operations Next.js frontend
  Functions/SSR that access Singapore data pinned to `sin1`

AWS ap-southeast-1 (Singapore)
  ECS/Fargate: TypeScript command/API service
  ECS/Fargate: TypeScript worker service

Supabase ap-southeast-1 (Singapore)
  Postgres / PostGIS / Auth / Storage / Broadcast / Queues / Cron
```

Use containerized API/worker services so local Docker and production run the same process shapes. The API and worker are intentionally only two long-lived application **services**; production worker service runs at least two tasks. Do not introduce Kubernetes for V1.

Vercel Functions default to a US region on new projects unless configured otherwise. Any SSR/Route Handler/function that touches the Singapore Rounds data plane must be explicitly pinned to **Singapore `sin1`** (or avoided in favor of the Singapore command API) to prevent unnecessary trans-Pacific latency.

Supabase Edge Functions may still be used for narrow functions/webhooks where they materially simplify deployment, but do not force long-running workers into an edge-function lifecycle.

## 23.3 Database connections

Use Supabase's connection pooler/Supavisor appropriately for API/workers. Direct database connections are reserved for components that actually require them. Connection budgets are load-tested rather than assumed.

## 23.4 Backup / recovery / outage posture

Production must not rely only on the default daily backup interval once Rounds is carrying meaningful live delivery/custody data. Supabase currently offers paid Point-in-Time Recovery with much finer restore granularity; enable PITR or an equivalent recovery posture before meaningful production volume.

Before launch, the deployment/recovery build spec must define:

- target RPO and RTO;
- backup/PITR retention;
- restore drill procedure;
- off-platform logical/schema export cadence where appropriate;
- Storage/POD recovery considerations separate from database restore;
- incident procedure for a Supabase/database outage.

V1 Operations does **not** become a second offline-authoritative dispatch system during a primary database/API outage. It may show clearly labeled cached/last-known read-only information where available, but consequential mutations are disabled/queued only where their client contract explicitly supports that. Do not create a shadow source of truth merely for outage optics.

---

# 24. Observability

Observability is part of the stack.

Use:

- Sentry for web/mobile/server error reporting;
- OpenTelemetry-compatible tracing;
- structured logs;
- stable `trace_id` / `command_id` / `delivery_id` / `stop_id` / `round_id` propagation;
- provider request/event IDs;
- metrics/alerts for queues, webhooks, Broadcast, navigation billing and location ingest.

We must be able to reconstruct:

```text
Driver action
→ API command
→ DB transaction
→ queue message
→ provider request
→ provider webhook
→ state update
→ Operations display
```

from one trace/aggregate trail.

Mandatory business/infra metrics include:

- active drivers;
- location sample batches/sec;
- location freshness p50/p95;
- Broadcast events/sec;
- command latency/error rate;
- stale-version conflicts;
- outbox age;
- POD pending-evidence age;
- navigation destinations/completed delivery;
- Google Maps cost per delivery;
- Lalamove/provider failure rate;
- queue depth/oldest message.

---

# 25. Cost architecture

Do not model “maps cost” as only Navigation.

Monthly infrastructure model must include at minimum:

- Supabase compute/database/storage/Realtime;
- API/worker runtime;
- Operations map loads;
- Places/autocomplete;
- geocoding/reverse geocoding;
- route/matrix/traffic;
- navigation destinations;
- push/SMS/LINE/email;
- POD storage + bandwidth;
- observability;
- external provider integration charges where applicable.

Model at:

```text
1,000 deliveries/month
10,000 deliveries/month
100,000 deliveries/month
1,000,000 deliveries/month
```

and at:

```text
100 active drivers
1,000 active drivers
10,000 active drivers
```

Track **cost per completed delivery** and **cost per active driver** from day one.

---

# 26. Failure-mode contract

Every build spec must define degraded behavior. Initial architecture table:

| Dependency/failure | User-visible behavior | System behavior | Data risk policy |
|---|---|---|---|
| Driver has no network | Working state remains available; actions show pending | durable local outbox + buffered location | no fake server success |
| Driver auth expires offline | no evidence deletion | re-auth then resume outbox | pending evidence retained |
| Google Navigation unavailable | degraded navigation + fallback map-app action | Rounds delivery state unaffected | no invented ETA |
| GPS stale | Operations shows last known + age/unknown | stop claiming live | no silent stale position |
| Supabase Realtime disruption | UI indicates stale/live sync degraded | clients can refetch authoritative state | DB remains truth |
| Primary API unavailable | mutations disabled/pending according to client | no direct table bypass | no client-authoritative writes |
| Storage upload interrupted | evidence pending | resumable retry | no completed-evidence claim |
| Lalamove/API failure pre-pickup | explicit failure / Action | retry/alternative workflow | custody not created |
| Lalamove failure post-pickup | custody exception | never silently reassign | custody evidence preserved |
| FCM unavailable | no push | state still exists; fetch on app open | no lost assignment truth |
| Mapbox basemap unavailable | Operations degraded map shell | non-map work remains usable | routes/state not mutated |

A fuller version belongs in Build Specs.

---

# 27. Local development

Everything should be buildable locally on a developer Mac except external vendor cloud behavior, which is mocked/sandboxed.

Local stack:

- Supabase CLI/Docker: Postgres/Auth/Storage/Realtime;
- local API service;
- local worker;
- local Operations web;
- Flutter iOS simulator + Android emulator;
- physical iPhone/Android for device-only tests;
- fake Lalamove;
- fake commerce provider;
- fake notification provider;
- deterministic seed data.

One reset command must rebuild known fixtures with at least two merchants to prove tenant isolation.

---

# 28. Repository

```text
rounds/
  apps/
    operations-web/          # Next.js / TypeScript
    driver-app/              # Flutter / Dart

  services/
    api/                     # TS command/query/location ingest API
    worker/                  # TS queue consumer/background jobs

  packages/
    contracts/               # OpenAPI / JSON Schema / event envelopes
    domain-ts/               # TS utilities, no UI authority
    observability/
    config/

  supabase/
    migrations/
    tests/
    seed.sql

  mocks/
    lalamove/
    commerce/
    notifications/
    routing/

  specs/
    product/
    engineering/
    adr/

  .github/
    workflows/
```

Do not share UI code between Flutter and Next.js. Share contracts and generated models.

---

# 29. Contract-first code generation

Use language-neutral contracts:

- OpenAPI for HTTP APIs;
- JSON Schema/event schema for realtime envelopes where useful;
- SQL migrations/constraints for database truth.

Generate TypeScript and Dart models/clients in CI where practical.

CI fails when generated contracts are stale.

AI coding agents must never invent a second Dart-only or TS-only meaning of a canonical Rounds state.

---

# 30. Testing strategy

## Database/security

- RLS tenant isolation;
- JWT/active-tenant policy tests;
- cross-tenant Network server-projection tests;
- database constraints;
- migrations;
- concurrency/version tests.

## Domain

- delivery/Stop/Round state machines;
- custody/manifest invariants;
- Network consent;
- external custody;
- idempotency;
- stale-version loser behavior.

## Driver

- offline outbox;
- auth-loss recovery;
- background location;
- camera/POD;
- interrupted/resumable upload;
- Thai layout/content;
- push/deep-link;
- embedded navigation lifecycle;
- billing-destination dedupe.

## Provider

- signature verification;
- duplicate/out-of-order webhooks;
- timeout-after-provider-accepted ambiguity;
- retry/dead-letter behavior.

## Scale

Mandatory synthetic staging load profile before claiming 1,000-driver readiness:

- 1,000 concurrently active Driver sessions;
- realistic moving/idle location sample cadence;
- batched ingest;
- Operations subscribers;
- Broadcast fanout;
- command traffic;
- communications;
- provider webhook traffic;
- POD metadata/uploads sampled separately;
- queue jobs.

Acceptance thresholds are defined in the performance build spec. The test must measure latency, error rates, connection/Realtime limits, DB CPU/IO, queue age and location freshness.

---

# 31. Phase 0 — Combined Driver Field Validation Gate

Do **not** run background location and embedded navigation as two isolated prototypes. Production combines them, and separate tests could both pass while the real app fails under combined GPS/render/lifecycle load.

Phase 0 therefore uses **one thin Flutter Driver Field Harness**.

## 31.1 Physical devices

Minimum gate fleet:

- one current iPhone;
- one mainstream Android;
- one lower-cost/aggressively managed Android/OEM representative of the Thailand rider fleet (Xiaomi/Oppo/Vivo-class behavior).

## 31.2 Combined build

```text
Login/demo driver
→ assigned Round
→ select Stop
→ embedded Google Navigation (TWO_WHEELER)
→ Rounds location telemetry simultaneously active
→ Operations telemetry viewer with freshness
→ background / screen lock / calls / weak network
→ arrival
→ simple arrival/POD transition
```

The harness must instrument navigation destination creation, active navigation session identity, raw/source location callbacks, Rounds location batching, Broadcast fanout, CPU/memory, crash state and battery use.

## 31.3 Mandatory location-consumer finding

The gate must explicitly answer:

> **Does Google Navigation expose a usable location stream through the Flutter integration on both iOS and Android that Rounds can consume for operational telemetry while guidance is active?**

Measure:

1. navigation-sourced telemetry / one location consumer;
2. fallback Rounds-owned tracker where navigation callbacks are insufficient;
3. if technically possible, two-consumer behavior only as a comparison—not as the preferred design.

Record battery drain, freshness, OS lifecycle behavior, sampling regularity and road-snapping quality. The production design must avoid two hot GPS consumers unless evidence proves it necessary and acceptable.

## 31.4 Bangkok navigation field test

Use real motorcycle routes including:

- narrow sois;
- one-ways and difficult U-turns;
- condos/malls/gates;
- elevated-road/tunnel GPS conditions;
- peak and off-peak traffic;
- deliberate wrong turns;
- weak/no cellular coverage;
- Thai voice guidance;
- incoming calls;
- screen lock/unlock;
- app background/foreground;
- process crash/relaunch and supported recovery behavior.

Record:

- rider deviation rate and reason taxonomy;
- reroute quality;
- arrival detection;
- Thai voice usability;
- navigation request count and **destinations/completed Stop**;
- ability to reattach/recover without blindly creating a new billable destination intent;
- crash/frame/memory/lifecycle issues;
- Flutter plugin limitations;
- Rounds chrome compliance with Google safety UI;
- battery drain under combined navigation + telemetry;
- Operations location freshness and stale-state behavior.

The Rounds chrome pass/fail requirement is concrete: **Stop identity, Operations contact, exception entry and arrival→POD transition must remain reachable without obscuring Google's current-location puck, maneuver/lane guidance or other required safety UI.**

## 31.5 Gate logic

1. Flutter plugin + native Google SDK + combined telemetry perform well → **lock Flutter + embedded Google Navigation**.
2. Google native SDK is good but Flutter wrapper/event bridge is the blocker → build a thin native Swift/Kotlin bridge, keep Flutter.
3. Google TWO_WHEELER navigation itself performs poorly for Rounds Bangkok motorcycle work → reconsider navigation product/vendor; do not merely switch cross-platform framework.
4. Combined navigation + telemetry causes unacceptable battery/lifecycle failure → change the location-consumer design based on measured evidence before feature development.

No other stack debate blocks this field gate.

---

# 32. First real vertical slice after Phase 0

Build one complete real delivery rather than a horizontal infrastructure layer.

```text
Merchant login
→ create one real delivery
→ assign own driver
→ driver receives Round
→ pickup manifest
→ custody commit
→ embedded navigation
→ live Operations position
→ arrival
→ handoff verification
→ resumable POD evidence
→ delivery completion
→ Operations updates
→ History/audit record
```

This slice must already include:

- multi-tenant/RLS foundation;
- server commands;
- versions/idempotency;
- Broadcast;
- local outbox;
- location ingest;
- basic observability;
- Thai Driver locale path;
- privacy/retention fields needed by the data it creates.

Once this works end-to-end, subsequent Build Specs and slices expand the system: planning, Network, external couriers, communications, customer tracking, etc.

---

# 33. Engineering Build Specs — write just ahead of implementation

Do not produce a 23-document waterfall before code.

Before the first vertical slice, create these foundation specs:

1. **Domain aggregates / state machines / concurrency / idempotency**
2. **Tenancy / Auth / Network authorization / RLS**
3. **Realtime / event envelope / location telemetry**
4. **Driver offline / session recovery / POD evidence**
5. **Maps / navigation / routing / billing / provider-policy boundaries**
6. **Privacy / retention / PDPA controls**
7. **Deployment / queue / observability / backup/recovery**

Then write feature build specs immediately before each vertical slice rather than months in advance.

Every Build Spec includes:

- domain ownership;
- data model;
- constraints;
- states/transitions;
- commands/queries;
- expected aggregate version behavior;
- permissions;
- API/event contracts;
- offline behavior;
- evidence/idempotency;
- errors;
- observability;
- acceptance tests;
- cost/limit considerations where applicable.

---

# 34. AI-assisted engineering workflow

Codex/other agents implement specifications; they do not decide product rules.

For every phase:

1. Current product spec identified.
2. Engineering Build Spec written.
3. Tests/acceptance criteria written.
4. Agent implements **only that slice**.
5. Agent runs migrations/tests/builds.
6. Human/product review operates the real software.
7. Contradiction → spec corrected first.
8. Code/tests updated.
9. Merge only when acceptance criteria pass.

Example agent instruction:

```text
Implement Engineering Slice X from /specs/engineering/X.md.
Do not implement later slices.
Do not invent behavior where the specification is silent.
Use existing domain/event contracts.
Run all named tests and report failures.
If a product rule conflicts with implementation constraints, stop and report the contradiction.
```

---

# 35. Decisions deliberately deferred

| Decision | Why deferred | Trigger to decide |
|---|---|---|
| Maps vendor posture: **Google-coherent vs non-Google-coherent** | Google Maps Platform terms couple Geocoding/Places/Routes/Navigation content to Google-map use and caching rules; do not choose address/routing providers independently of the Operations basemap | Bangkok address-quality + route-quality + licensing/cost evaluation before first production address/routing integration |
| Final matrix/routing provider | Needs representative workload + chosen vendor posture | planning build / real operational dataset |
| Final optimization engine | Needs measured constraints/volume | planner build + real data |
| Mapbox → MapLibre inside a non-Google-coherent posture | Basemap renderer only after vendor posture permits it | cost/vendor review |
| Extract GPS service from Supabase-adjacent topology | Premature at 1k target | measured telemetry/realtime limits/cost |
| Advanced workflow engine beyond pgmq | unnecessary until complexity proves it | pgmq/Cron limits or workflow-operability pain |
| Google Fleet Engine / Mobility Services | may duplicate parts of Rounds and can add commercial constraints | enterprise-scale/buy-vs-build review |

Deferral is explicit so AI agents do not silently choose these technologies.

---

# 36. Frozen v1.0 recommendation

**Build Rounds on this spine:**

```text
OPERATIONS
Next.js + React + TypeScript
Mapbox GL JS as V1 basemap/operational renderer

DRIVER
Flutter + Dart
Google Navigation embedded in-app
TWO_WHEELER for motorcycle work in Thailand
SQLite offline outbox
Swift/Kotlin native layer where needed
FCM/APNs

SERVER
TypeScript command API
Dedicated batched location ingest
One TypeScript worker service (≥2 production tasks)
Provider adapters

DATA
Supabase PostgreSQL + PostGIS
Supabase Auth
Supabase Storage
Supabase Broadcast
Supabase Queues / pgmq
Supabase Cron

DEPLOYMENT
Vercel for Operations web; Singapore-facing Functions pinned to `sin1`
AWS ECS/Fargate ap-southeast-1 for API + worker service (≥2 worker tasks)
Supabase ap-southeast-1 for data services
Paid production backup/PITR posture + restore drills

ARCHITECTURAL RULES
Server authoritative consequential commands
Aggregate versions + idempotency
Network cross-tenant data through server projections
POD two-phase evidence commit
GPS is its own data plane
Planned / navigated / actual routes are distinct
Thai-first Driver product
One localized Driver app with first-run + Profile language selection
Canonical commerce Delivery API with Shopify/WooCommerce/custom adapters
PDPA/retention built into schema
Singapore-region production topology
Sentry + distributed trace IDs
1,000 concurrently active drivers is a mandatory load-test target
```

**The stack is not waiting for theoretical perfection.**

Supabase/Postgres and the server/realtime/telemetry architecture are selected now. Flutter + embedded Google Navigation are selected pending the combined real-device Phase 0 field gate. If that gate passes, the framework/navigation choices become locked and implementation proceeds vertically.

---

# 37. Freeze status

Architecture v1.0 is **FROZEN FOR PHASE 0**.

Final adversarial review outcome from Claude, Gemini and Grok: **no pre-Phase-0 blocker**. The final non-stack amendments were incorporated here: combined navigation+telemetry gate, subscriber-multiplicative Broadcast accounting, Vercel `sin1`, worker-service redundancy, Navigation SDK Thailand coverage reference, and maps-vendor coherence/legal constraints.

Do not reopen Flutter vs React Native, Supabase vs AWS/Firebase, pgmq vs Redis/Temporal, Mapbox vs MapLibre, or planning-engine debates before Phase 0 unless new vendor terms materially change or the field harness returns contradictory evidence.

After Phase 0:

- if the gate passes, Flutter + embedded Google Navigation move from SELECTED to LOCKED;
- if the Flutter bridge fails but native Google Navigation succeeds, use the planned Swift/Kotlin escape hatch;
- if Google motorcycle navigation itself fails the Bangkok product test, reopen navigation only;
- maps/address/routing vendor coherence is decided before the first production Operations address/routing integration.

---

# 38. Current vendor references checked 2026-08-31

Primary references used for the current vendor-specific facts in this decision:

- Google Navigation for Flutter and React Native overview: https://developers.google.com/maps/documentation/cross-platform/navigation
- Google Navigation SDK pricing / Google Maps Platform pricing: https://developers.google.com/maps/billing-and-pricing/pricing
- Google two-wheeler coverage: https://developers.google.com/maps/documentation/routes/coverage-two-wheeled
- Google Navigation SDK coverage (including Thailand TWO_WHEELER): https://developers.google.com/maps/documentation/navigation/android-sdk/coverage-nav-sdk
- Google Maps Platform Terms / Service Specific Terms: https://cloud.google.com/maps-platform/terms and https://cloud.google.com/maps-platform/terms/maps-service-terms
- Google Navigation SDK policies: https://developers.google.com/maps/documentation/navigation/ios-sdk/policies
- Supabase Realtime — Broadcast vs Postgres Changes: https://supabase.com/docs/guides/realtime/subscribing-to-database-changes
- Supabase Realtime limits: https://supabase.com/docs/guides/realtime/limits
- Supabase Realtime settings / subscriber-multiplicative event accounting: https://supabase.com/docs/guides/realtime/settings
- Supabase Realtime benchmarks: https://supabase.com/docs/guides/realtime/benchmarks
- Supabase Queues / pgmq: https://supabase.com/docs/guides/queues
- Supabase Storage resumable uploads / TUS: https://supabase.com/docs/guides/storage/uploads/resumable-uploads
- Supabase regions: https://supabase.com/docs/guides/platform/regions
- Supabase database backups / PITR: https://supabase.com/docs/guides/platform/backups
- Vercel Function regions: https://vercel.com/docs/functions/configuring-functions/region

---

*End of Engineering Stack & Architecture Decision v1.0 — Frozen for Phase 0.*
