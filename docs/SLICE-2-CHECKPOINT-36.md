# Slice 2 · Checkpoint 36

**Status:** Dispatch Communications returned to the canonical v45 surface

**Date:** 2026-09-04

## Correction

- Removes the separate full-page Communications board and its desktop/mobile
  navigation entry.
- Keeps Dispatch and the real Mapbox operating map visible while contacting a
  driver.
- Opens the existing server-backed thread as the v45 compact 438 px window.
- Keeps the Round/exception drawer beside Communications on wide desktop.
- Uses the constrained-width overlay rule rather than squeezing two permanent
  panels onto a smaller board.
- Implements minimize into, and reopen from, the bottom conversation tray.
- Preserves the real Photo, File, Location, Map context and voice composer,
  IndexedDB drafts, private uploads and atomic message commit from checkpoint
  35.
- Leaves the Call control visibly disabled and truthful until VoIP is actually
  connected; no simulated call behavior is shipped.

## Verification

- Operations TypeScript typecheck passes.
- Operations tests pass.
- Next.js production build passes.
- Localhost browser inspection confirms there is no Communications navigation
  page, the widget overlays Dispatch, and minimize → tray → reopen works.

## Remaining communication gaps

- Physical browser-to-Samsung Photo/File/Location/voice acceptance.
- Durable per-dispatcher unread/read state synchronized across driver marker,
  conversation tray and top-bar icon.
- Real call lifecycle and call-event persistence.
- Complete filtered contact-history ledger.
