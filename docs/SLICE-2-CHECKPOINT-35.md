# Slice 2 · Checkpoint 35

**Status:** v45 Dispatch rich-message composition implemented

**Date:** 2026-09-04

## Implemented

- Replaces the Operations text-only reply row with the canonical v45 composer:
  `[ + ] [ Message driver… ] [ Mic ] [ Send ]`.
- Adds the specified `Photo`, `File`, `Location` and `Map context` attachment
  menu. There is no invented Link action; URLs remain normal message text.
- Supports multiple staged attachments, independent removal, optional text,
  image paste and desktop file drop. Selection never sends automatically.
- Uses the Stop's authoritative destination pin for `Map context`; it does not
  invent a coordinate from address text.
- Records browser voice through an explicit record → stop → staged preview →
  Send path. Stopping a recording does not send it.
- Keeps unsent text and staged Blob/location drafts in browser local storage
  and IndexedDB per tenant/thread across refresh.
- Blocks outbound Send while the Operations browser is offline and preserves
  the draft rather than appending a fake message.
- Extends the private `communication-media` path to authorized tenant owners,
  Operations admins and dispatchers while keeping viewers read-only.
- Prepares resumable TUS uploads, verifies exact SHA-256 and byte length on the
  server, and commits verified assets with the shared thread message in one
  database transaction.
- Accepts browser-native WebM/Opus voice media without weakening the existing
  Driver MIME boundary.

## Verification

- Remote Supabase migration `202609040006` applied successfully.
- Remote public-schema database lint returns zero errors.
- Contracts, API and Operations TypeScript typechecks pass.
- Operations tests cover file classification/limits and readable media labels.
- API tests cover Operations media preparation/verification, attachment-only
  commands and viewer rejection.
- The pgTAP communication suite now covers Operations prepare/verify/commit,
  WebM voice, viewer denial and direct-RPC privilege denial.
- The real localhost board exposes the canonical menu and visible mic.
- Browser verification confirms authoritative map context stages without
  sending and survives a full page refresh from IndexedDB.

## Honest remaining boundary

- A physical browser-to-Samsung acceptance pass is still required for Photo,
  File, current Location and voice recording/upload/playback.
- The current React communications workspace has not yet reached the v45
  floating-window/tray/marker synchronization and visual parity.
- Call-event persistence, synchronized unread/read state and the complete
  filtered contact-history ledger remain open.
- GAP-009 still owns the final committed-media retention period; no expiry is
  invented here.

## Next safe work

- Finish the v45 floating communications/live-context gap, then run one real
  Operations rich message through to the installed Driver build.
