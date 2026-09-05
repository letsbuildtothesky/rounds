# Slice 2 Checkpoint 42 — Private attachment handoff acceptance

Date: 2026-09-05

## Canonical sources used

- `specs/build/BS-10.md`
- `specs/build/BS-17.md`
- `specs/product/ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `ux/driver/en/screens/ROUNDS-H01-OPERATOR-CHAT-v4-10OF10.html`
- `ux/operations/rounds-operations-current-v45.html`

No new screen, message type or interaction was introduced. The existing H01
photo/file rows and v45 `Open file` action remain the only user-facing
controls changed by this checkpoint.

## Delivered

- Driver file and photo opens no longer launch the rotating signed Storage URL
  in a browser. The app retrieves the authorized HTTPS bytes into its private
  temporary cache, enforces the 15 MB message limit and trusted byte length,
  sanitizes the local filename and hands the local file to Android.
- Markdown and other common text artifacts are handed to Android as plain text
  so an installed viewer can render them without changing the canonical card.
- Dispatch now creates its blank viewer during the explicit `Open file` click,
  then replaces it with the temporary blob URL after the authorized fetch.
  This preserves the private-blob boundary without relying on a popup created
  after an asynchronous request, which browsers may block.
- Both handoffs keep truthful inline failure feedback and never display or copy
  the signed token URL into the Rounds interface.

## Live acceptance

- A real Operations message on `B2-ROUND-A-0903` / `B2-MOVE-B-0903` containing
  one photo and one file reached the connected Samsung and rendered in the
  supplied H01 card composition.
- Tapping the file opened the downloaded checkpoint Markdown in Android HTML
  Viewer from the sanitized local cache path. No Supabase URL or token appeared
  in the viewer.
- Tapping the photo opened the downloaded image directly in Google Photos,
  rather than opening a signed Storage URL in a browser.
- The existing real 31-second signed voice note changed from Play to Pause on
  the Samsung, confirming Driver H01 playback against the live media projection.

## Automated verification

- Flutter analysis passes.
- All 153 Driver Flutter tests pass. The three new tests cover the secure local
  cache handoff, byte-length rejection and rejection of insecure HTTP URLs.
- A configured debug APK builds, installs and launches on Samsung SM-S928B.
- All 13 Operations tests pass.
- Operations typecheck and production build pass.

## Still open

- Record and commit a real Operations-originated voice note in a browser with
  microphone support, then accept it on Samsung. The Codex in-app browser used
  for this run exposes no `mediaDevices` API, so that proof was not fabricated.
- Complete a manual new-tab file-open pass in a normal browser; the in-app
  browser does not expose its popup as a controllable tab.
- Exercise queued rich-message recovery through real network loss and process
  death.
- Add secure push/realtime delivery, call-event persistence and the complete
  filtered contact-history ledger.
- Resolve GAP-009 before claiming a production committed-media retention rule.
