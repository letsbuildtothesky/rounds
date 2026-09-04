# Slice 2 · Checkpoint 34

**Status:** canonical H01 Camera, Photo, File and Voice implemented

**Date:** 2026-09-04

## Implemented

- Replaces hidden rich-chat actions with the supplied H01 bottom drawer:
  Camera, Photo, File and Location, plus the first-class microphone action.
- Stages multiple attachments before Send and keeps optional message text.
- Records voice as record → stop → preview/play → add; recording never sends
  automatically.
- Retains selected/captured bytes and attachment drafts per Stop across process
  restart.
- Adds a dedicated SQLite media outbox with persisted upload identity, URL and
  offset, including expired-upload restart behavior.
- Creates a private `communication-media` Supabase bucket and tenant/thread-
  scoped asset registry.
- Requires exact server-side SHA-256 and byte-length verification before a
  media reference can enter the shared thread.
- Commits the message and all verified assets in one database transaction.
- Returns short-lived signed URLs to authorized Driver and Operations thread
  projections; neither client receives a public bucket URL.
- Renders photo, file and voice cards in Driver and Operations and projects
  truthful attachment references into H03 Contact History.
- Restores the private debug one-tap Team-driver Sign in without committing its
  credential to the repository.

## Verification

- Remote Supabase migration `202609040005` applied successfully.
- Remote schema lint reports only pre-existing PostGIS extension-body findings
  plus the existing unrelated Round-planning warning.
- TypeScript typecheck passes.
- All 164 JavaScript/TypeScript workspace tests pass.
- Flutter static analysis passes with no issues.
- All 147 Driver tests pass, including rich draft/outbox persistence, canonical
  drawer exposure and H03 rich-media labels.
- Debug APK builds and installs successfully on Samsung `SM-S928B`.
- Physical inspection confirms one-tap Sign in, the real H01 thread, microphone
  and the canonical Camera / Photo / File / Location bottom drawer. Android
  logs contain no fatal application exception.

## Honest remaining boundary

- Physical end-to-end capture/send/restart/resume for each of Camera, gallery
  Photo, File and Voice is the next acceptance pass; automated boundaries and
  real native control exposure are complete, but this checkpoint does not
  claim those four manual sends were exercised.
- Operations can receive and open Driver rich media; Operations-originated rich
  attachment composition is not implemented.
- Unread/read semantics remain open and no delivery-receipt behavior is
  invented.
- GAP-009 still requires a business/legal committed-media retention period.
  Uncommitted assets expire after 24 hours; committed expiry remains explicitly
  policy-pending.

## Next safe work

- Run the four physical Driver rich-message sends, then return to the
  supplied v45 Operations board gap list without inventing UI.
