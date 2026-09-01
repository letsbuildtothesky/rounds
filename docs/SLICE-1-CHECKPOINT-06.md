# Pilot / Slice 1 · Checkpoint 06

**Status:** English Own-Team handoff, proof of delivery, completion and Operations History implemented; physical-device acceptance remains

**Date:** 2026-09-01

## Authorized scope

This checkpoint completes the server-authoritative English execution loop after arrival. The Driver confirms the same locked manifest, records the actual recipient or approved location, captures required photo evidence and can recover from an interrupted upload. A Stop, Delivery and final Round become complete only after the server independently verifies the durable media bytes and atomically commits the handoff.

## Implemented

- Shared, validated contracts for POD preparation, handoff completion and the Operations History projection.
- Private `pod-evidence` object storage restricted to the exact server-prepared path owned by the authenticated assigned Team driver.
- Durable `media_assets` lifecycle: `staged → uploaded_uncommitted → committed`, with expected and server-verified SHA-256, byte size and content type.
- Server-only, idempotent `complete_stop_pod_command` transaction with active-Team authorization, Stop version enforcement and exact locked-manifest verification.
- Atomic handoff manifest verification, driver-to-recipient custody event, immutable POD record, media commit, Delivery completion, Stop completion, conditional final-Round completion, audit event and transactional domain-event outbox record.
- English Driver POD screen with Recipient, Someone else and Left at location handoff choices, the locked manifest, required camera photo and optional delivery note.
- The captured photo is copied into application storage and hashed before network work begins.
- SQLite POD evidence outbox persists local path, exact evidence metadata, idempotency key, storage target, resumable upload URL and byte offset across process restart.
- Authenticated TUS upload supports byte-offset resume and safely creates a new upload session after an expired upload URL.
- Network and temporary server failures preserve evidence as pending sync and never claim that the Delivery is complete.
- API-side verification downloads the stored object and independently checks hash and size before allowing the completion transaction.
- Operations History lists only completed POD records backed by committed media and shows Round, Delivery, Driver, handoff recipient/location, manifest version and verified photo count.
- Forward migrations `202609010010_pod_completion_history.sql` and `202609010011_driver_pod_storage_policy.sql` applied to the linked development project.

## Verification

- 31 linked pgTAP assertions pass for private evidence, least-privilege functions, missing-evidence rejection, staged/quarantined/verified/committed media transitions, stale versions, exact manifest handoff, custody, completion, audit/outbox and idempotency.
- Linked migration dry-run reports the remote schema is current and linked `public` schema lint reports no errors.
- 57 TypeScript tests pass across contracts, domain, API, Operations and location ingestion; monorepo typecheck passes.
- Both Next.js production applications build successfully and the production dependency audit reports zero vulnerabilities.
- Flutter analysis reports no issues, all 18 Flutter tests pass, and the Android debug APK builds successfully.
- The SQLite interruption test closes and reopens the database, proves upload URL/offset and local evidence survive, and verifies expired-session reset.
- A live authenticated development flow used the real API and hosted Supabase resumable storage to prepare evidence, upload it, verify it, commit POD and retrieve Operations History. The tested Stop is `completed` and its final Round is `complete`.
- The live test used synthetic development evidence, removed its temporary authentication user/identity link afterward and committed no password, token, publishable key or service secret.

## Remaining acceptance and deferred work

- A real Samsung acceptance pass is still required for camera permission, image capture, interruption/relaunch on the device and final visual usability.
- Thai UX remains intentionally deferred until this English flow is accepted. It will be localized within the same application rather than maintained as a separate codebase.
- Production security, retention, monitoring and evidence-expiry hardening remain tracked in `docs/SECURITY-HARDENING-BACKLOG.md` for the authorized hardening phase.
- Broader exception resolution, communications, recipient tracking and cross-merchant depth remain outside this Slice 1 checkpoint.

## Next checkpoint

Install the debug build on the Samsung, run one complete real-photo delivery acceptance scenario including a restart/resume case, correct any device-specific findings, then begin Thai localization and the final security/production-readiness pass.
