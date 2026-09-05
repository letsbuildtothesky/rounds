# Slice 2 Checkpoint 41 — Canonical communication-media presentation

Date: 2026-09-05

## Canonical sources used

- `specs/build/BS-10.md`
- `specs/product/ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `ux/driver/en/screens/ROUNDS-H01-OPERATOR-CHAT-v4-10OF10.html`
- `ux/operations/rounds-operations-current-v45.html`

No new page, message type or media workflow was introduced. This checkpoint
connects the existing signed private-media projection to the media cards drawn
in the two canonical communication surfaces.

## Delivered

- Replaced the generic Dispatch signed-link rows with the v45 media
  presentation inside the existing compact conversation window.
- Photos render inline at the v45 132 px card height without exposing the
  signed Storage URL as the visible interaction.
- Voice notes use an actual play/pause control, waveform and duration. The
  player retains its current media source while the five-second thread refresh
  rotates signed URLs, so polling does not interrupt playback.
- Files use the canonical file card and `Open file` action. Opening first
  retrieves the authorized bytes and hands a temporary browser object URL to
  the new tab instead of navigating the user to a Supabase token URL.
- Replaced the Driver H01 generic media row with its supplied presentation:
  118 px inline photo preview, unchanged 38 px photo/file row, and a separate
  34 px voice play/pause control with the nine-bar waveform and duration.
- Driver H01 keeps a stable signed source across foreground polling and shows
  truthful local error feedback if playback or opening fails.

## Verification

- Operations typecheck passes.
- All 13 Operations tests pass.
- Operations production build passes.
- Localhost browser inspection confirms the real inline photo, canonical file
  card and voice card inside the v45 conversation window.
- Localhost browser acceptance confirms the real voice asset changes from Play
  to Pause while playing, with no runtime error.
- Flutter analysis passes.
- All 150 Driver Flutter tests pass, including exact 118 px photo, 34 × 34 px
  voice-control, nine-bar waveform and duration assertions.
- A configured debug APK builds, installs and launches successfully on the
  connected Samsung SM-S928B.

## Still open

- Physical Samsung acceptance of Operations-originated Photo, File and Voice,
  including Driver playback/open behavior.
- Physical browser acceptance of the file-open handoff and Operations-originated
  browser Photo/File/Voice sends.
- Queued rich-message recovery under real network loss/process death.
- Secure push/realtime delivery, call-event persistence and the complete
  filtered contact-history ledger.
- GAP-009 committed-media retention policy.
