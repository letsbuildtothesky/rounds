# Rounds Phase 0 Field Results

**Status:** NOT YET RUN
**Gate outcome:** Pending physical-device and Bangkok field evidence

This document is the controlled evidence record required by
`specs/engineering/ROUNDS-PHASE-0-FIELD-VALIDATION-SPEC-v1.2.md`.
Simulator, unit-test, compilation and desktop-preview results must not be
represented as motorcycle field evidence.

## Build

- Commit SHA: `83d9b678cc8e0ccef7f9b63bc849b22af9c61ed9`
- App version: `0.1.0+1` (debug)
- Android APK checksum: `6ee72f718df6bc43436acdf77c0c10552d4ec128c384a53fc7e7b081e940cedc`
- iOS build identifier:

## Device matrix

| Class | Model | OS | Battery health | Optimization | Location permission | Carrier | Build SHA |
|---|---|---|---|---|---|---|---|
| iPhone | Pending | | | | | | |
| Mainstream Android | Samsung SM-S928B | Android 16 / API 36 | Android reports good | Pending OEM review | Precise while in use | AIS | `83d9b678cc8e0ccef7f9b63bc849b22af9c61ed9` |
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

## Location-source comparison

| Device/run | Mode | Cadence | Freshness | Accuracy | Background continuity | Battery delta | Notes |
|---|---|---|---|---|---|---|---|
| | Navigation-only baseline | | | | | | |
| | A — navigation sourced | | | | | | |
| | B — Rounds tracker | | | | | | |
| | C — both briefly | | | | | | |

### Recommended production strategy

- Navigation active:
- Active work without guidance:
- Not entitled to tracking:

## Lifecycle scenarios

| Scenario | Navigation | Telemetry | Viewer freshness | User-visible state | Recovery | Duplicate intents | Errors |
|---|---|---|---|---|---|---|---|
| Screen lock/unlock | | | | | | | |
| Background/foreground | | | | | | | |
| Incoming call | | | | | | | |
| Weak/lost/recovered network | | | | | | | |
| Battery/OEM optimization | | | | | | | |
| Process crash/relaunch | | | | | | | |
| Permission denied/restored | | | | | | | |
| GPS unavailable/restored | | | | | | | |

## Destination-intent counts

| Stop | Destination version | New intents | Reattachments | Completed | Investigation |
|---|---|---|---|---|---|
| | | | | | |

## Telemetry and Broadcast metrics

| Run | Ingest req/s | Samples/request | Broadcasts/s | Delivered events/s | Viewers | E2E p50 | E2E p95 | Stale transitions |
|---|---|---|---|---|---|---|---|---|
| | | | | | | | | |

## Battery and performance

| Device/run | Duration | Start/end battery | Increment vs nav-only | Temperature | CPU/memory | Jank/crashes |
|---|---|---|---|---|---|---|
| | | | | | | |

## Media and logs

- Screenshots:
- Video:
- Structured logs:
- Crash reports:

## Gate decision

Choose exactly one only after all required evidence exists:

- PASS
- BRIDGE REQUIRED
- NAV FAILURE
- LOCATION FAILURE

Decision and rationale:
