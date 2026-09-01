# Rounds · Phase 0 Field Validation Specification

**Version:** 1.2  
**Date:** 2026-09-01  
**Status:** READY TO EXECUTE — Driver UX sync complete; no product redesign dependency remains  
**Controlling architecture:** `ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md`  
**Purpose:** Prove or invalidate the two irreducible Driver-product assumptions before feature construction: (1) embedded Google `TWO_WHEELER` navigation is good enough for Bangkok motorcycle delivery, and (2) Rounds can maintain honest operational location under the same real device load without unacceptable lifecycle/battery failure.

---

# 1. Gate statement

Phase 0 is **one combined Driver Field Harness**, not separate navigation and tracking demos.

The harness must run:

```text
Embedded Google Navigation
+
Rounds operational telemetry
+
Rounds chrome/actions
+
real phone lifecycle interruptions
```

at the same time on physical devices and on a real motorcycle in Bangkok.

A navigation-only test and a location-only test are insufficient because both can pass independently while production fails under combined GPS, rendering, network and background-service load.

---

# 2. Decisions Phase 0 is allowed to change

Phase 0 may change only these selected decisions if evidence requires it:

1. **Flutter integration path**
   - Flutter plugin remains preferred.
   - If the plugin/event bridge fails while Google's native Navigation SDK performs correctly, keep Flutter and introduce a thin Swift/Kotlin navigation bridge.
   - Reconsider the cross-platform framework only if Flutter itself—not merely the plugin—fails the field requirements.

2. **Embedded Google Navigation product decision**
   - If Google `TWO_WHEELER` itself performs materially poorly for the Bangkok rider workflow, reopen the navigation product/vendor decision.

3. **Location source while active navigation is running**
   - Prefer one location consumer.
   - Phase 0 must determine whether Rounds can consume a navigation-sourced location stream while guidance is active, or whether an independent Rounds tracker is required.

Phase 0 does **not** reopen Supabase/Postgres, Next.js Operations, server authority, PGMQ, Broadcast architecture, provider adapters, or the planning engine.

---

# 3. Non-goals

Do not build the production Driver App in Phase 0.

Do not build:

- full onboarding;
- Network marketplace;
- earnings;
- full communications;
- full pickup/POD evidence pipeline;
- automated fleet optimization;
- Lalamove;
- customer tracking;
- production billing;
- full Operations board.

The harness should contain only enough Rounds UI and backend plumbing to test the field-critical architecture.

---

# 4. Physical device matrix

Minimum test fleet:

| Class | Requirement |
|---|---|
| iPhone | Current supported iPhone on iOS 16+ |
| Mainstream Android | Current Samsung/Pixel-class device |
| Aggressive-OEM Android | Lower-cost Xiaomi/Oppo/Vivo-class device representative of the Thailand rider fleet |

The low-cost/aggressive-OEM device is **part of the gate**, not a later QA nice-to-have.

Record for every device:

- model;
- OS version;
- battery health where available;
- battery-optimization settings;
- location permission state;
- cellular provider;
- app build SHA/version.

---

# 5. Thin harness UX

Required flow:

```text
Demo login
→ Assigned Round
→ Current Stop
→ Start navigation
→ Embedded Google Navigation · TWO_WHEELER
→ Rounds telemetry active simultaneously
→ Operations telemetry viewer receives fresh position
→ Arrival
→ simple Rounds arrival state
→ simple POD-transition placeholder
→ Next Stop / end test
```

The UI is not disposable developer chrome. It should exercise the same interaction geometry expected in the production Driver App.

Required Rounds controls during navigation:

- current Stop identity;
- recipient/location context sufficient for the rider;
- contact Operations;
- exception entry;
- arrival transition.

These controls must remain reachable without obscuring Google's required current-location, maneuver/lane or safety UI.

---

# 6. Navigation implementation

Use Google Navigation SDK through the current official Flutter integration first.

Travel mode:

```text
TWO_WHEELER
```

Thailand must be verified at test time against Google's Navigation SDK coverage documentation before the field run.

The app must instrument:

- Stop ID;
- `destination_version`;
- local `nav_session_id`;
- time destination intent was requested;
- whether the request was new or reattached/recovered;
- navigation started/paused/resumed/stopped;
- reroute count;
- arrival callback/state;
- route request errors;
- plugin/native errors.

---

# 7. Destination billing/idempotency test

The harness must include a local destination/session ledger.

Minimum identity:

```text
stop_id
destination_version
nav_session_id
destination_fingerprint
created_at
last_attached_at
```

Test all of these:

1. start navigation normally;
2. background/foreground;
3. lock/unlock;
4. temporary network loss;
5. Flutter page navigation that unmounts/remounts the navigation view;
6. app UI recreation;
7. process crash/relaunch where technically recoverable;
8. navigation restart to the same unchanged Stop;
9. destination change with a new destination version.

Required behavior:

- screen/widget remount must not itself create a new billable destination intent; the logical navigation intent is keyed by `stop_id + destination_version` and recovered/reattached using the safest mechanism the SDK permits;
- reconnect/relaunch must not blindly create a new destination intent for an unchanged Stop;
- a real destination change creates a new versioned intent;
- instrumentation must make **navigation destinations / completed Stop** measurable;
- any Stop creating more than two destination intents during the controlled test must be investigated before passing the gate.

---

# 8. Location-consumer experiment

The most important technical finding Phase 0 must return is:

> Does the Navigation SDK expose a usable location stream through the Flutter integration on iOS and Android that Rounds can use for operational telemetry while guidance is active?

Test modes:

### Mode A — navigation-sourced telemetry

Use location information exposed by the navigation stack where available.

Measure:

- callback cadence;
- timestamp freshness;
- accuracy;
- road snapping;
- background continuity;
- battery;
- behavior after reroute;
- behavior after phone call/lock/unlock.

### Mode B — Rounds-owned tracker fallback

Run the independent Rounds tracker when navigation location callbacks are unavailable or insufficient.

Measure the same properties.

### Mode C — two consumers, comparison only

If technically possible, run both only long enough to quantify the penalty.

Two hot GPS consumers are **not** the preferred production design.

The Phase 0 report must recommend one production source strategy for:

- navigation active;
- navigation inactive but driver on active work;
- driver not entitled to active tracking.

---

# 9. Telemetry path in the harness

Use the production-shaped boundary without overbuilding it:

```text
location source
→ local SQLite buffer
→ batched HTTPS ingest
→ hot current position
→ tenant-aggregated Supabase Broadcast
→ minimal Operations telemetry viewer
```

Do not use high-frequency Postgres Changes.

Do not insert every raw point into normal audited business tables.

Each position must carry:

- driver ID;
- tenant/job context;
- source;
- lat/lng;
- captured timestamp;
- accuracy;
- freshness;
- optional heading/speed where legitimately produced by the chosen source.

The viewer must explicitly distinguish:

```text
LIVE
STALE / LAST KNOWN
UNKNOWN
```

Never show stale data as live.

---

# 10. Broadcast test shape

Supabase counts WebSocket events per client delivery. Therefore the harness must exercise **aggregated fanout**, not one Broadcast per raw location point.

Presence layer should coalesce changed positions into a tenant snapshot/delta payload before Broadcast.

For the field harness with one rider this may contain one driver, but the implementation contract must support N changed drivers in one payload so the same design can later scale to 1,000 active drivers.

Instrument:

- ingest requests/sec;
- samples/request;
- Broadcasts/sec;
- delivered Realtime events/sec;
- viewer count;
- end-to-end position latency;
- stale transitions.

---

# 11. Bangkok route corpus

Use real routes, not a simulator-only course.

Minimum categories:

- narrow sois;
- one-way streets;
- difficult/legal U-turn situations;
- condominium entrances and wrong-gate scenarios;
- mall/office loading entrances;
- elevated roads;
- underpasses/tunnels or GPS-obstructed roads;
- dense Sukhumvit-style urban canyons;
- peak traffic;
- off-peak traffic;
- deliberate wrong turns;
- weak-cellular areas where available.

Use an experienced Bangkok rider as the human comparator.

Record for every leg:

- Google route chosen;
- whether rider followed it;
- every rider deviation;
- deviation reason;
- reroute quality;
- arrival quality;
- rider qualitative rating.

Deviation taxonomy should distinguish at least:

```text
routing error / illegal-impractical turn
local rider shortcut
building/gate access issue
traffic judgement
road closure/flood/construction
GPS error
preference only
other
```

A high deviation rate is not automatically a failure; the reasons determine whether the navigation product is useful. A systemic routing-error category is materially worse than stable local-preference deviations.

---

# 12. Lifecycle scenarios

Run while guidance and Rounds telemetry are both active:

- screen lock for several minutes;
- unlock;
- app background;
- return foreground;
- incoming phone call;
- notification arrival;
- weak network;
- network loss;
- network recovery;
- battery saver / OEM optimization where testable;
- process crash/relaunch;
- device rotation where relevant;
- permission denied then restored;
- GPS temporarily unavailable.

For each scenario record:

- navigation continuity;
- telemetry continuity;
- Operations freshness;
- user-visible state;
- whether any action falsely claimed server success;
- recovery time;
- duplicate destination intents;
- crash/error logs.

---

# 13. Thai-first + language-selection validation

Phase 0 must test the Driver experience in Thai, not only English, using the production localization architecture.

Required:

- A01 → A01B language selection path;
- `ไทย` primary Thailand locale and English alternative;
- language preference survives app relaunch, offline state and authentication transition;
- L01/Profile language change applies without clearing current Round/outbox state;
- Thai voice guidance;
- Thai recipient names;
- Thai addresses;
- Thai Stop/action labels in the Rounds chrome;
- small-screen Thai line wrapping;
- no clipped buttons/text on the low-cost Android;
- switching language does not mutate operational state or command identifiers.

The base Driver component system must be capable of Thai text layout before vertical feature construction begins. The production build remains one localized app.

---

# 14. Battery/performance measurement

Measure on each device:

- battery percentage before/after controlled runs;
- run duration;
- device temperature if available;
- CPU/memory via development tooling;
- frame/jank observations;
- navigation-only baseline;
- navigation + Rounds telemetry result;
- two-consumer comparison if Mode C is possible.

The critical metric is the **incremental Rounds telemetry cost over navigation alone**, not an arbitrary absolute battery number across different phones.

Phase 0 fails the location design if adding Rounds telemetry causes a large, sustained battery/lifecycle penalty that would make a normal delivery shift operationally unrealistic.

Any production threshold should be locked from these measured baselines rather than guessed before the test.

---

# 15. Provisional pass/fail criteria

The gate may pass only when all of these are true:

1. Google `TWO_WHEELER` navigation is useful enough that the experienced rider does not routinely abandon it because of systemic Bangkok routing errors.
2. Rerouting and arrival behavior are operationally usable.
3. Thai voice guidance is usable.
4. Required Rounds actions coexist with Google safety UI.
5. No repeatable crash/memory/lifecycle failure occurs on any of the three device classes.
6. Rounds can provide honest live/stale location while navigation is active.
7. The recommended one-consumer/fallback location strategy is identified with measured evidence.
8. Offline/network recovery preserves telemetry buffers and does not create false success.
9. Same-Stop recovery does not blindly create repeated navigation destination intents.
10. Combined navigation + telemetry battery behavior is acceptable for a normal rider shift relative to the navigation-only baseline.

If a criterion is uncertain, the gate does not silently pass. The report names the uncertainty and the smallest additional test required.

---

# 16. Gate outcomes

## Outcome 1 — PASS

Flutter + official plugin + Google Navigation + chosen telemetry source work well.

Action:

- change Flutter and embedded Google Navigation in Engineering Architecture from `SELECTED — gate` to `LOCKED`;
- start the first real vertical Rounds slice.

## Outcome 2 — PLUGIN BRIDGE REQUIRED

Google native Navigation is good, but Flutter plugin/event bridge is insufficient.

Action:

- retain Flutter;
- implement a thin Swift/Kotlin Navigation bridge/platform channel;
- repeat the failed scenarios only;
- then lock.

## Outcome 3 — NAVIGATION PRODUCT FAILURE

Google `TWO_WHEELER` itself is not good enough for Rounds Bangkok motorcycle work.

Action:

- reopen the embedded-navigation decision;
- do not switch framework as a reflex;
- compare alternatives using the same route corpus.

## Outcome 4 — LOCATION DESIGN FAILURE

Navigation is good but combined telemetry produces unacceptable battery/lifecycle behavior.

Action:

- revise source/cadence/background strategy using measured evidence;
- keep the rest of the architecture frozen.

---

# 17. Required Phase 0 report

Codex/human testers must produce:

```text
ROUNDS-PHASE-0-FIELD-RESULTS-v1.md
```

It must include:

- build commit SHA;
- device matrix;
- route corpus;
- field dates/times;
- navigation deviations + reasons;
- Thai guidance result;
- plugin/native limitations;
- location-source comparison;
- battery/performance comparison;
- lifecycle failures;
- destination-intent counts;
- telemetry freshness metrics;
- Broadcast metrics;
- screenshots/video references where useful;
- explicit PASS / BRIDGE REQUIRED / NAV FAILURE / LOCATION FAILURE decision;
- exact architecture changes required, if any.

No architecture decision changes merely because a developer prefers another technology.

---

# 18. Execution boundary

The final Driver board package has returned and Product Specs v43 are implementation-ready. This Phase 0 specification and `ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md` are the engineering baseline for the field harness.

Before Phase 0:

- do not redesign Rounds Operations or the Driver product;
- do not reopen the selected stack without new vendor facts;
- do not implement public Network, KYC/face-check, Network earnings, Lalamove, production commerce connectors, advanced Address Intelligence or Rounds Direct;
- use the current Driver boards only to reproduce the minimal harness geometry needed for navigation, contact/exception access and arrival transition.

After Phase 0:

1. record PASS / BRIDGE REQUIRED / NAV FAILURE / LOCATION FAILURE;
2. if PASS or BRIDGE REQUIRED after remediation, lock the validated Driver navigation/location path;
3. write only the Build Specs required for Pilot/Slice 1;
4. begin the first vertical production slice defined by `ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md`.

Phase 0 is the next evidence-producing step. Do not create another architecture/spec-review cycle before running it unless vendor terms materially change.

---

*End of Rounds Phase 0 Field Validation Specification v1.2.*
