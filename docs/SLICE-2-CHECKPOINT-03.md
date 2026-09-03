# Slice 2 · Checkpoint 03

**Status:** real route-duration and promised-window planning guard implemented; Slice 2 remains in progress

**Date:** 2026-09-03

## Canonical UX contract

- Operations continues to implement `ux/operations/rounds-operations-current-v45.html` as the canonical visual and interaction contract.
- The v45 planning composition remains intact: unplanned queue, real Mapbox workspace, persistent planning timeline, Driver/vehicle lanes, explicit decision explanation and deliberate approval.
- Route truth is calculated on the server and normalized behind a provider-neutral interface. The current Mapbox adapter does not decide the final production routing-provider selection.

## Implemented

- `POST /v1/operations/planning/route-preview` authenticates the Operations tenant and evaluates an ordered Stop proposal against current server truth.
- The server loads the tenant pickup coordinate, ordered destination coordinates, effective Driver shift, vehicle profile and promised windows.
- The Mapbox Directions `driving-traffic` adapter returns real road geometry, per-leg travel time, total duration and distance. Provider credentials stay server-side.
- Early arrivals wait until the promise starts; arrivals after the promise ends and finishes after the shift become hard blocking reasons.
- Motorbike proposals explicitly warn that the current profile models driving traffic rather than motorcycle-specific road restrictions.
- The Operations map draws the proposed provider route only on the matching Mapbox basemap.
- The planning decision strip shows routing progress, provider failure, promise conflict or verified route/window fit. Approval stays disabled until a matching fit exists.
- The timeline horizon is derived from effective Driver shifts instead of a fixed 08:00–20:00 scale, and the routed proposal is placed mathematically on the selected Driver lane.
- Round approval recalculates the route on the server; it never trusts a client preview.
- Remote migration `202609030007` requires a matching `fits` route snapshot before the transactional Round command can commit. It persists timing, per-Stop ETA, promise result and provider provenance without persisting route geometry.

## Verification

- All workspace typechecks pass.
- 107 TypeScript tests pass: 33 contracts, 59 API, 5 domain, 6 location ingest and 4 Operations web tests.
- API tests cover early-arrival waiting, promise lateness blocking, Mapbox response normalization and the rule that a blocked server route never reaches the database command gateway.
- Live signed-in browser acceptance calculated a real Bangkok route of 3.8 km / 15 min, rendered its road geometry, showed `ROUTE + WINDOW FIT`, enabled approval, committed `ROUND-20260901-094250`, and removed its Stop from the unplanned pool.
- A direct post-commit database read confirmed the durable snapshot has status `fits`, provider `mapbox`, one Stop and no persisted geometry.
- The remote database accepted migration `202609030007`. The local pgTAP suite remains unavailable until Docker/Supabase Postgres is running; no pgTAP pass is claimed.

## Known limits

- Destination handoff/service dwell is not configured, so the result explicitly says it evaluates routed road time plus early-arrival waiting only.
- Cargo classification and vehicle cargo limits are still unverified.
- Provider call metering, cache policy and final production routing-provider selection remain later engineering gates.

## References

- Mapbox Directions API: <https://docs.mapbox.com/api/navigation/directions/>
- Mapbox Matrix API: <https://docs.mapbox.com/api/navigation/matrix/>

## Next checkpoint

- Add explicit cargo classification and vehicle cargo-limit evaluation.
- Continue canonical v45 Round-management states and connect route timing to live Driver/Round projections.
- Continue corresponding Driver flow states against the English UX contracts before the Thai localization pass.
