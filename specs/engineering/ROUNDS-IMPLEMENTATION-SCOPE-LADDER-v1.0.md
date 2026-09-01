# Rounds · Implementation Scope Ladder

**Version:** 1.0  
**Date:** 2026-09-01  
**Status:** Controlling implementation scope boundary  
**Purpose:** Separate the product-complete Rounds V1 design from the first deployable system and prevent implementation agents from treating the entire design library as one release.

---

## 1. Core rule

The canonical product specs and UX boards describe **what Rounds is allowed to become**. This document controls **what is built now**.

A capability can be canonical product behavior and still be intentionally parked for a later slice.

No implementation agent may promote a parked capability merely because a board or product spec exists for it.

---

## 2. Phase 0 — field architecture validation

Phase 0 is not a production release.

Build only the combined Driver Field Harness defined by `ROUNDS-PHASE-0-FIELD-VALIDATION-SPEC-v1.2.md`:

```text
Demo identity
→ assigned Round/Stop
→ embedded Google TWO_WHEELER navigation
→ Rounds telemetry under the same device load
→ minimal Operations telemetry viewer
→ lifecycle / network / battery interruption tests
→ arrival / POD-transition placeholder
```

Phase 0 proves or invalidates the selected Driver navigation/location path. It does not build Network, Lalamove, commerce integrations, full POD, full Dispatch or the 47-board Driver product.

---

## 3. Pilot / Slice 1 — one real UrbanFlowers delivery loop

### Goal

Prove one real end-to-end delivery using Rounds as the system of record.

### Merchant scope

- one pilot merchant: UrbanFlowers;
- one merchant/location configuration;
- Team/Own drivers only;
- Thai-first Driver app with English selectable;
- no public/open Network dependency.

### Required business path

```text
merchant login
→ create/import a delivery through the canonical internal delivery contract
→ assign Team driver / manually sequence a small Round
→ driver receives work
→ pickup manifest verification
→ custody committed
→ embedded navigation
→ live/stale driver location visible to Operations
→ arrival
→ handoff verification
→ POD evidence upload/commit
→ delivery completed
→ History/evidence visible in Operations
```

### Round scope

Slice 1 must use the real Round/Stop domain model. It may support a manually ordered small multi-stop Round so the core unit of work is proven, but **automated fleet optimization is not a Slice 1 dependency**.

### Required reliability

- server-authoritative commands;
- aggregate versions / stale-command handling;
- idempotency;
- offline outbox for Driver actions;
- resumable POD evidence path;
- honest live/stale/unknown location;
- tenant isolation;
- Thai/English locale persistence;
- audit/history for the completed delivery.

### Explicitly NOT Slice 1

- Open/public Rounds Network;
- preferred-driver marketplace behavior;
- A08/A09 public-network identity verification / live face check;
- A10/K01 Get Paid / Network earnings as a money product;
- Network settlement automation;
- Network Supply map;
- broad Rounds trust/safety admin product;
- Lalamove production adapter;
- Shopify/WooCommerce production connectors;
- public developer API productization beyond the internal canonical delivery contract needed by the pilot;
- Rounds Direct;
- Street View / Mapillary workflow;
- 3D site inspection as a pilot dependency;
- learned entrance graph / advanced Address Intelligence;
- generalized AI intake;
- automated VRP/large-scale optimizer;
- consumer marketplace features.

### Pilot admin boundary

Do **not** build a third full Rounds Admin app for Slice 1. Use narrow, protected internal support/admin controls in the Operations/admin boundary only where the pilot genuinely requires them. A broader admin product is promoted before public Network rollout.

---

## 4. Slice 2 — Own-fleet operations depth

Promote after Slice 1 is stable.

Typical scope:

- planning workspace against real deliveries;
- multi-stop plan generation/adjustment/approval;
- shifts and vehicle profiles;
- cargo/capacity validation;
- delivery windows/special days;
- richer own-driver states;
- batch intake;
- operational exceptions;
- communications/live changes;
- responsive/edge behavior in production components.

The planner may begin with a simple, explainable heuristic. Provider/optimizer selection remains abstracted until real delivery data justifies a stronger solver.

---

## 5. Slice 3 — UrbanFlowers commerce integration + API foundation

Goal: remove duplicate entry for the pilot merchant.

- canonical Rounds Delivery API contract;
- idempotent inbound order/delivery creation;
- UrbanFlowers source adapter first;
- normalized update/writeback contract;
- signed outbound webhooks where needed;
- reconciliation and failure visibility.

Shopify and WooCommerce are adapters to this same contract, not separate domain models.

---

## 6. Slice 4 — External courier fallback

Promote when Own-fleet operation is reliable and real overflow data exists.

- Lalamove merchant-account connection;
- quote → approve/automatic-within-limit → booking;
- provider state normalization;
- external live job inside Dispatch;
- pre-pickup cancellation/failure;
- post-pickup custody exception behavior;
- provider POD/final-cost reconciliation;
- History/economics.

---

## 7. Slice 5 — Preferred / invited Network pilot

Test the Network thesis without opening a public marketplace.

- known/preferred invited riders;
- explicit availability;
- approximate pre-accept location/privacy;
- fixed guaranteed fare offer;
- accept/decline;
- accepted-work exact tracking contract;
- direct relationship/contact rules;
- simple settlement record without Rounds-held wallet funds.

Commercial validation with real riders should run before and during this slice.

---

## 8. Slice 6 — Open Rounds Network

Only after preferred/invited Network behavior and local supply economics are proven.

May promote:

- one global Network identity;
- open Network eligibility;
- identity/document verification;
- live face check only if legally/operationally justified;
- public offer waves;
- Network Supply map;
- Network earnings/settlement views;
- network fee accounting;
- cross-tenant server projections;
- trust/safety and suspension tooling;
- broader Rounds admin surface.

A09 Live Face Check is **designed future behavior**, not permission to implement biometrics before the relevant privacy/security Build Spec and legal review exist.

---

## 9. Slice 7 — General SaaS connectors

After the canonical API has been proven against UrbanFlowers:

- Shopify app;
- WooCommerce / WordPress extension;
- documented Public Rounds API;
- developer webhooks;
- connection/reconciliation tooling;
- onboarding for non-UrbanFlowers merchants.

All integrations normalize into the same Rounds Delivery/Stop/Manifest contracts.

---

## 10. Later / evidence-triggered capabilities

These remain valid product ideas but are not automatically part of the first SaaS release:

- Rounds Direct;
- advanced AI intake/extraction;
- learned cross-delivery entrance intelligence;
- Street imagery / richer 3D site workflows;
- broad public driver acquisition;
- regulated payment custody / wallet;
- advanced autonomous dispatch;
- self-hosted routing/matrix infrastructure;
- sophisticated VRP solver beyond what measured delivery density requires;
- consumer discovery/marketplace products.

---

## 11. Promotion rule

A feature moves from a later slice only when one of these is true:

1. the previous slice cannot operate reliably without it;
2. UrbanFlowers evidence demonstrates material operational value;
3. merchant/rider interviews validate the commercial assumption;
4. a production dependency requires it;
5. a human explicitly changes this scope ladder.

A board existing is **not** a promotion trigger.

---

## 12. Evidence running in parallel with code

While Phase 0 and Slice 1 are built, UrbanFlowers should collect real baseline data for future decisions:

- deliveries by hour/day;
- Stops per own-driver hour;
- actual compatible multi-stop density;
- rider idle time;
- overflow events;
- Lalamove jobs and real cost;
- promise failures and causes;
- typical pickup/hand-off dwell;
- distance from overflow rider to pickup;
- rider willingness to accept nearby fixed-fare work.

Network pricing and expansion rules are not settled by another product-spec revision. They are settled by evidence.

---

*End of Rounds Implementation Scope Ladder v1.0.*
