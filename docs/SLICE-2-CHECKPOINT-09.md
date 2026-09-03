# Slice 2 · Checkpoint 09

**Status:** typed G02 Operations hold implemented and remotely verified; G02 remains partial because correction authority is intentionally blocked

**Date:** 2026-09-03

## Implemented

- G02 now submits `stop.report_location_problem` instead of reducing the report to a chat message.
- The command is authenticated, tenant-scoped, versioned, idempotent and retained in the Driver SQLite outbox across restart or lost connectivity.
- The Driver sends one of four typed categories and may attach real OS latitude, longitude, accuracy and source evidence.
- The database independently verifies the assigned Team driver, active custody stage, current Stop version and matching manifest version/state.
- The server snapshots the authoritative pickup or delivery address and coordinate before opening the exception. It does not overwrite the address, move a pin, increment the destination version or mutate the locked physical manifest.
- The report puts the Stop and delivery into an explicit Operations hold, writes audit and outbox events, and creates a system entry in the existing Driver–Operations thread.
- Operations v45 projects the authoritative and observed coordinates with reported accuracy. It explains why correction is blocked instead of offering a fake resolution.
- A database trigger prevents older generic exception resolvers or direct status updates from closing these location exceptions while GAP-006/GAP-007 remain open.

## Verification

- The two migrations were applied successfully to the linked Supabase development project.
- Remote lint of the `public` schema reports no errors.
- The transactional remote database acceptance fixture reaches assertion 26 and rolls back all fixture data. It covers authorization grants, validation, stale version rejection, GPS evidence, custody hold, immutable manifest/destination truth, audit/outbox/thread projection, resolution blocking and idempotent retry.
- All 124 TypeScript tests and all 67 Flutter tests pass; both full typechecking/static analysis gates are clean.
- The Operations production build succeeds.
- The Android debug APK builds and installs successfully over the existing app on the connected Samsung SM-S928B while preserving local data.

## Honest remaining boundary

- This is a durable observation and hold, not an approved address or pin correction.
- GAP-006 does not yet define all address-exception outcomes and custody dispositions.
- GAP-007 does not yet define which post-pickup fields Operations may change or when Driver acknowledgement is mandatory.
- Until those decisions are recorded, the system must not update route truth or implement E04–E06 from a location report.

## Next safe work

- Continue with a different durable Checkpoint C exception whose policy can be completed without inventing authority, or close GAP-006/GAP-007 with UrbanFlowers Operations before building location correction.
