# Slice 2 Checkpoint 40 — Shared communications unread/read state

Date: 2026-09-05

## Canonical sources used

- `specs/02-functional/SPEC-6-Communication-Driver-Support-Emergency.md`
- `specs/08-behavior/ROUNDS-DRIVER-APP-UX-BEHAVIOR-MASTER.md`
- `specs/02-functional/SPEC-8-Exception-Management-Safety.md`
- `ux/driver/en/screens/ROUNDS-H01-CONTACT-OPERATIONS-v2-10OF10.html`
- `ux/operations/rounds-operations-current-v45.html`

No new board or communication interaction was introduced. The implementation
connects the unread/read behavior already specified by those sources to the
existing H01 and v45 surfaces.

## Delivered

- Added a private, tenant-scoped, per-person read cursor for each communication
  thread. Cursors move only forward and do not represent message delivery.
- Added authenticated Driver and Operations read commands through the existing
  private API boundary.
- Added unread count, first-unread message, unread-voice and latest-read state
  to the shared communication projections.
- Made one Operations projection drive the canonical v45 top-bar badge, Driver
  map-marker badge, minimized conversation tray and compact conversation
  window.
- Preserved the supplied focus rule: an incoming message updates the badges and
  tray but never opens or focuses a minimized conversation.
- Added the supplied H01 unread divider at the first unread Operations message.
  Opening the visible thread advances the Driver cursor while retaining the
  divider for that screen session, so the boundary does not visually jump.
- Voice unread is visually distinct from ordinary unread in Operations, using
  the existing v45 status language rather than a new screen.

## Database

- Applied migration `202609050001_communication_read_cursors.sql` to the linked
  Supabase project.
- Direct anonymous/authenticated table and RPC access remains revoked; the
  service-role API is the only client boundary.
- The migration and extended pgTAP suite cover monotonic cursors, tenant and
  Driver assignment authorization, first-unread boundaries and voice unread.

## Verification

- Repository TypeScript typecheck passes.
- All repository JavaScript/TypeScript tests pass: Operations 13, contracts 49,
  domain 5, API 100 and location-ingest 6.
- Operations production build passes.
- Flutter analysis passes.
- All 149 Driver Flutter tests pass.
- Linked migration push passes.
- Linked database lint reports only the pre-existing PostGIS extension findings
  and no new public-schema error.

The extended pgTAP file could not execute on this Mac because the Supabase CLI
requires Docker for `supabase test db`; Docker is not installed. That is an
environment gate, not a claimed database-test pass.

## Still open

- Physical end-to-end unread/read acceptance between browser and Samsung.
- Operations-originated Photo, File, current Location and Voice physical
  acceptance plus actual playback/download.
- Secure push/realtime delivery. The current product truth remains five-second
  foreground polling and app-resume refresh.
- Real call-event persistence and the complete filtered contact-history ledger.
- GAP-009 committed-media retention policy.
