# Rounds Phase 0 Field Results

**Status:** NOT YET RUN
**Gate outcome:** Pending physical-device and Bangkok field evidence

This document is the controlled evidence record required by
`specs/engineering/ROUNDS-PHASE-0-FIELD-VALIDATION-SPEC-v1.2.md`.
Simulator, unit-test, compilation and desktop-preview results must not be
represented as motorcycle field evidence.

## Build

- Commit SHA: `e38c2f7f72f63f468910f163d7526ce1f8faa9b7`
- App version: `0.1.0+1` (debug)
- Android APK checksum: `88ce974e8d84bb180e515053201df998b2fa9ac6c91e3c98f86aead641ff6a89`
- iOS build identifier:

## Device matrix

| Class | Model | OS | Battery health | Optimization | Location permission | Carrier | Build SHA |
|---|---|---|---|---|---|---|---|
| iPhone | Pending | | | | | | |
| Mainstream Android | Samsung SM-S928B | Android 16 / API 36 | Android reports good | Foreground-location smoke tested; full OEM review pending | Precise while in use | AIS | `e38c2f7f72f63f468910f163d7526ce1f8faa9b7` |
| Aggressive-OEM Android | Pending | | | | | | |

## Route corpus and field runs

| Run | Date/time | Device | Route categories | Traffic | Duration | Rider |
|---|---|---|---|---|---|---|
| | | | | | | |

## Navigation deviations

| Run/leg | Deviation | Reason taxonomy | Reroute quality | Arrival quality | Rider rating |
|---|---|---|---|---|---|
| | | | | | |

## Thai guidance and layout

- Thai voice guidance:
- Thai names/addresses:
- Small-screen wrapping:
- Language persistence across relaunch/offline/auth:
- Operational state unchanged by language switch:

## Plugin and native limitations

- `google_navigation_flutter` 0.11.0 exposes road-snapped and Android raw
  callbacks as latitude/longitude only. Callback payloads do not expose source
  timestamps or accuracy. Phase 0 must therefore measure callback cadence and
  lifecycle, while Mode B supplies complete operational telemetry unless a
  deeper native bridge proves sufficient.
- iOS event delivery remains unverified until Xcode and a physical iPhone are
  available.
- Samsung bench smoke testing initialized the Navigation SDK, rendered the
  Google map, and delivered LIVE operational GPS samples. Before Google Maps
  Platform account activation completed, both `TWO_WHEELER` and a deliberate
  `DRIVING` comparison returned `NavigationRouteStatus.networkError` despite
  validated phone connectivity. After billing, Navigation SDK enablement, and
  the Android key restriction had propagated, a manual `TWO_WHEELER` retry at
  2026-09-01 16:46 ICT recorded `navigation_started` and displayed
  `TWO_WHEELER guidance active`. This clears the external routing blocker but
  is still bench evidence, not motorcycle field evidence.
- The first field build retried a failed route from every road-snapped location
  callback. Build `83d9b678cc8e0ccef7f9b63bc849b22af9c61ed9` bounds the automatic
  request to one attempt, keeps the map visible, and requires an explicit rider
  action for every retry or diagnostic comparison.
- The first background/lock smoke test collected only 10 Rounds OS samples
  across approximately 49 seconds. Build
  `e38c2f7f72f63f468910f163d7526ce1f8faa9b7` adds an Android foreground
  location service with a three-second interval. Repeating the same sequence
  collected 17 samples across approximately 48 seconds while guidance stayed
  active. This is a bench lifecycle result, not a normal-shift battery result.

## Location-source comparison

| Device/run | Mode | Cadence | Freshness | Accuracy | Background continuity | Battery delta | Notes |
|---|---|---|---|---|---|---|---|
| | Navigation-only baseline | | | | | | |
| | A — navigation sourced | | | | | | |
| Samsung bench | B — Rounds tracker | 3 s configured; 17 samples / ~48 s background+lock smoke | Supabase viewer observed ~1 s source age while active | ±7–8 m during stationary Bangkok bench test | Continued through 15 s background and 20 s lock smoke | Full baseline pending | Android foreground service; `rounds_os` source |
| | C — both briefly | | | | | | |

### Recommended production strategy

- Navigation active:
- Active work without guidance:
- Not entitled to tracking:

## Lifecycle scenarios

| Scenario | Navigation | Telemetry | Viewer freshness | User-visible state | Recovery | Duplicate intents | Errors |
|---|---|---|---|---|---|---|---|
| Screen lock/unlock | Guidance remained active | 17 samples across the combined ~48 s lifecycle sequence | Remote viewer path verified separately as LIVE | Foreground location notification active | Immediate on unlock | No new logical ledger row | No crash |
| Background/foreground | Guidance remained active | Samples continued at configured ~3 s cadence | Local buffer remained current | Lifecycle transitions recorded | Immediate on foreground | No new logical ledger row | No crash |
| Incoming call | | | | | | | |
| Weak/lost/recovered network | Guidance stayed active during 20 s forced loss | 12 samples buffered across 35 s loss/recovery sequence | Upload path later caught up to LIVE | No false completed state | Wi-Fi/mobile restored; ping succeeded | No new logical ledger row | No sample loss observed |
| Battery/OEM optimization | | | | | | | |
| Process crash/relaunch | | | | | | | |
| Permission denied/restored | | | | | | | |
| GPS unavailable/restored | | | | | | | |

## Destination-intent counts

| Stop | Destination version | New intents | Reattachments | Completed | Investigation |
|---|---|---|---|---|---|
| STOP-001 | 1 | 1 logical ledger row; historical debug route requests include the pre-fix retry storm | Reused one `nav_session_id` across rebuilds/relaunches | Pending field arrival | Historical total is 262 destination requests / 259 route errors because the first build retried on every callback. The retry storm is fixed; start the controlled field run with a clean database and investigate if the Stop exceeds two requests. |

## Telemetry and Broadcast metrics

| Run | Ingest req/s | Samples/request | Broadcasts/s | Delivered events/s | Viewers | E2E p50 | E2E p95 | Stale transitions |
|---|---|---|---|---|---|---|---|---|
| Samsung bench · live path | ~0.10 | 35.5 overall average including 200-sample reconnect batches | ~0.10 | At least 1 observed in viewer; extended count pending | 1 | Source age ~1 s observed; full E2E calculation pending | Pending | LIVE confirmed; stale transition field test pending |

## Battery and performance

| Device/run | Duration | Start/end battery | Increment vs nav-only | Temperature | CPU/memory | Jank/crashes |
|---|---|---|---|---|---|---|
| Samsung bench snapshot | Not a controlled drain run | 56% while USB connected | Not measurable | 34.9°C snapshot | ~757 MB PSS / ~917 MB RSS with Navigation SDK map and telemetry active | No crash observed; baseline and sustained run pending |

## Media and logs

- Screenshots:
- Video:
- Structured logs: on-device SQLite recorded route/lifecycle/upload events;
  Supabase accepted watermark 637 during the live bench run.
- Crash reports:

## Gate decision

Choose exactly one only after all required evidence exists:

- PASS
- BRIDGE REQUIRED
- NAV FAILURE
- LOCATION FAILURE

Decision and rationale:
