# Slice 2 · Checkpoint 28

**Status:** authenticated Driver language preference synchronization implemented

**Date:** 2026-09-04

## Implemented

- Preserved the canonical Thai-first A01B and L01 local preference as the
  immediate, offline-safe UI truth.
- Authenticated Drivers now synchronize that choice to
  `driver_profiles.preferred_locale` through one typed API command.
- The server command verifies the active Team relationship, expected Driver
  profile version and idempotency key before updating the profile. It records
  audit evidence and a domain event without changing Round, navigation,
  assignment, custody or outbox state.
- A device with no explicit local choice adopts the authenticated profile. A
  device with an explicit local choice keeps it and synchronizes it instead.
- A stale profile version causes one authoritative session refresh and retry.
  Offline or failed synchronization never blocks work, and rapid language
  changes are serialized so an older response cannot revert the newest choice.
- Applied migration `202609040003_driver_preferred_locale.sql` to the linked
  Supabase project.

## Verification

- All workspace TypeScript tests pass: Operations 8, contracts 45, domain 5,
  API 93 and location ingest 6.
- All 132 Driver Flutter tests pass, including stale-version refresh/retry,
  offline behavior, profile version persistence and legacy `en-US` handling.
- Workspace TypeScript typechecking and Flutter static analysis pass.
- The linked Supabase `public` schema passes error-level database lint with no
  findings.

## Honest remaining boundary

- A01B remains `PARTIAL`: complete active-flow translation-key coverage,
  physical Thai/English layout acceptance and a signed-in cross-device
  preference run are still required.
- This checkpoint does not claim that every Driver screen is localized or that
  Android installation alone is physical bilingual acceptance.

## Next safe work

- Continue the supplied-board active-screen localization audit, then perform
  signed-in cross-device and physical Thai/English acceptance without inventing
  UX outside the canonical boards.
