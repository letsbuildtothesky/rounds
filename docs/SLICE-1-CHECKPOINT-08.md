# Slice 1 Checkpoint 08 — Physical Android POD acceptance

Date: 2026-09-02

## Delivered

- Retained each captured POD draft photo in application-support storage before enabling completion, instead of depending on the camera provider's temporary file.
- Restored the retained photo by Stop after a full Android process stop and relaunch.
- Kept draft evidence isolated per Stop and removed it only after the server committed the POD handoff.
- Added explicit checking, saving and recovery-error states so the Driver cannot submit while local evidence is unresolved.
- Granted the server service identity the missing read-only permission for the latest driver-position projection used by live Operations planning. Browser roles remain default-deny.

## Physical-device acceptance

- Device: Samsung SM-S928B running Android 16 / API 36.
- Used the server-backed English Driver flow with the existing synthetic `ROUND-DEMO-001` / `UF-DEMO-001` fixture.
- Confirmed arrival through the real Driver app, captured a real camera photo, fully stopped the app, reopened it and confirmed the same photo was restored.
- Completed the delivery after relaunch. The Driver app showed the canonical completed-Stop result and advanced to the next assigned work.
- Remote verification confirmed `UF-DEMO-001` is `delivered`, its POD handoff type is `recipient`, and its JPEG media asset is `committed` with a server-verified byte size.
- The separately created `ROUND-CAMERA-1409` remains assigned behind the older fixture; this checkpoint does not claim that Round was delivered.

## Automated verification

- Flutter analysis completed with no issues.
- All 47 Flutter tests passed, including retained-photo restoration and stale-metadata cleanup.
- The migration is least privilege: only `SELECT` on `public.driver_position_current` is granted to `service_role`.

## Remaining

- This is a controlled bench acceptance, not a motorcycle field run. Route, battery, OEM-background and degraded-network gates remain tracked in `field/ROUNDS-PHASE-0-FIELD-RESULTS-v1.md`.
- Operations navigation at narrow browser widths still needs a dedicated responsive pass; it does not affect the committed POD record.
- Thai localization and the final security/production-readiness phase remain deferred until the English Slice 1 workflow is closed.
