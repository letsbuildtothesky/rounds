# E06 — Telemetry Realtime and Native Lifecycle

Rounds engineering specification · Consolidated V2.3-r1 · 8 September 2026

## Changelog

- 2026-09-08 · v2.3-r1: ADR-A02 supplies explicit authenticated installation enrollment/refresh/revocation, private security audit and legacy-key preservation. Native storage, configured Auth and field acceptance remain gates.

## Device registration and credential lifecycle

Use the typed EnsureDriverDeviceSession/RevokeDriverDeviceSession authentication transport defined in E03/OpenAPI and ADR-A02. Resolve an existing active driver through verified Auth; registration does not create a principal, membership, shift, job or tracking entitlement. Persist a per-principal cryptographically random installation secret securely before requesting registration. Server stores only its principal-bound hash; retries/refresh return the same device ID and current unrevoked epoch. Never derive an installation secret from a device label, hardware ID, push token or sample UUID.

Refresh capability after expiry with verified bearer and the original secret. Explicit self-revocation invalidates that installation's epoch without deleting server history or local pending evidence; repeat revocation is idempotent. Revoked/archived installations cannot be silently revived or bypassed by client secret rotation. Account-wide compromise requires Auth/account revocation as well. Device switching and evidence recovery remain subject to E05; do not rewrite old command/device/fence IDs. The server implementation is isolated and default-off until native secure storage, legacy upgrade and configured Auth tests pass.

## Separate data plane

High-frequency GPS batches do not run one consequential delivery transaction per point. Driver collection attaches device/sequence, observed time, source, accuracy and tracking entitlement. API validates identity, active purpose/window, plausible timestamps, rate/body size and job context. Duplicate batches/samples are acknowledged without duplicate raw rows. Current hot position advances only when the new observation is more recent and usable; late offline samples may fill history without rewinding live marker.

Initial configurable test cadence retained from architecture: moving samples about every 3–5 seconds, upload batches about every 10–30 seconds; idle coarser. These are measurement hypotheses, not locked battery promises. Field harness must assess navigation/location consumers together and prefer a single suitable source when supported. Cap batches at 500 samples; oversized or invalid samples get explicit per-sample results. Do not return success for rejected tracking beyond entitlement.

## Entitlements and privacy

Track during scheduled authorized team work, accepted job or voluntarily published matching availability under appropriate policy. Off-duty paused freelancer has no blanket background tracking entitlement. Open matching does not grant merchant exact GPS. Purpose/end/revocation record controls ingest and projection; late observations within a legitimate historical window may be handled under policy but cannot claim present availability. Driver understands tracking context; legal basis/retention remains reviewed policy rather than an invented universal consent rule.

## Fanout and reconnect

Coalesce changed positions into tenant/job-authorized deltas at an operational cadence (initial test 1–2 seconds while viewers active). Topics are private and checked against current membership/city/job grant. Do not publish all tenant data to a topic and hide it in browser filters. Global freelancer supply projection generalizes fields before publishing. Subscription revocation and device logout invalidate topic access promptly.

Supabase Broadcast is the selected mechanism; realtime is a hint transport, not the event store. Include aggregate versions, batch cursor/as-of and per-driver freshness. Gap or reconnect triggers authoritative snapshot/refetch, then applies compatible deltas. Out-of-order duplicates are ignored; client never executes a command merely because a push/event arrived. Historical Postgres Changes is not the raw fleet bus.

## Native behavior

Flutter handles navigation plus platform-specific background location, Android foreground-service notification, iOS capability/lifecycle and permission checks through supported SDK/bridge. Test OEM battery restrictions, screen lock, app kill, external call/dialer return, camera/mic recording and navigation interruptions. Google/OS permission grant cannot be simulated by UI toggle. Denied/unavailable GPS offers safe cached-route/current-task recovery with freshness labels; internet and location errors remain separate.

Pause/end tracking flushes legitimate buffered evidence under policy then stops collection; must not stop accepted-work recovery prematurely. Temporary auth expiry preserves local buffer and asks re-auth before ingest. No continuous fake car motion after telemetry expires. Intercity positions use actual geographic anchors and explicit estimated interpolation.

## Combined field validation protocol

Run navigation, Rounds telemetry and real driver controls together on three device classes: supported iPhone, mainstream Android and low-cost aggressive-OEM Android. Record model, OS/build version, permission and battery-optimization state, carrier and test build identity. Confirm provider travel-mode/coverage support at test time; a vehicle icon is not navigation support.

Compare navigation-only baseline with navigation plus telemetry. Test navigation-sourced location, an independent tracker fallback, and—only for comparison—the cost of two simultaneous consumers. Recommend the actual source strategy for active navigation, active work without navigation and no tracking entitlement. Record freshness, accuracy, background continuity, battery, heat/memory/jank and incremental cost over baseline.

Use experienced Bangkok riders on narrow sois, one-way roads, legal U-turns, condo/loading entrances, elevated roads, tunnels/urban canyons, peak/off-peak traffic, deliberate wrong turns and weak coverage. Record each deviation as routing error, local shortcut, gate/access issue, traffic judgement, closure/flood/construction, GPS error or preference. A rider shortcut is not automatically provider failure.

Run the two-hour screen-off/battery-saver/restart acceptance scenario with navigation and telemetry active; also exercise incoming call, permission loss/recovery and network interruption. Measure actual destination requests per completed stop across remount/relaunch; investigate more than two intents for the same unchanged stop/version. Do not promise provider billing deduplication beyond the mechanism supported by the SDK.

Report PASS, BRIDGE REQUIRED, NAVIGATION FAILURE or LOCATION DESIGN FAILURE with device/route data and observed failure traces. Plugin failure calls for the smallest native bridge correction; it does not automatically justify replacing Flutter. Navigation quality failure reopens the navigation choice; excessive telemetry penalty reopens source/cadence. No simulated device run can pass this gate.

## Capacity measurement

Retain architecture target of 1,000 concurrently active drivers as a staging acceptance target, not an achieved performance claim. Model samples/sec = active drivers / sample interval; uploads/sec = active drivers / batch interval; realtime deliveries/sec depends on update ticks × actual subscribed viewers, not just logical events. Test 100, 1,000 and later 5,000+ only when relevant. Measure CPU/IO, connection budget, queue lag, payload size, location freshness, drops, mobile battery and egress cost. Provision provider quotas from the actual account and current docs, not old hardcoded service-plan limits.

### QA-SYSTEM-NATIVE-R0

Actor: Authorized actor for device harness; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: Low/mid Android and iPhone;2h route with screen off, battery saver, navigation and20min poor network; repeat3times/device..

Then: All physical command/evidence IDs survive3 restarts; no false completion; background-permitted segments p95location<=30s; report gaps and battery drain with device/OS. Unsupported profile/OS combination remains disabled..

Status: written requirement; application execution pending.
