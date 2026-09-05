# Slice 2 Checkpoint 43 — Durable rich-message restart recovery

Date: 2026-09-05

## Canonical sources used

- `specs/build/BS-10.md`
- `specs/product/ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `ux/driver/en/screens/ROUNDS-H01-OPERATOR-CHAT-v4-10OF10.html`
- `ux/driver/en/screens/ROUNDS-N02-OFFLINE-RECONNECTING-v2-10OF10.html`

No new screen or interaction was introduced. This checkpoint corrects the
durable data and sync-truth path behind the supplied H01 and N02 boards.

## Delivered

- N02 now counts pending and partially uploading rich messages from the
  durable `message_media_outbox`. It can no longer claim that messages are
  synced while an attachment still waits on this phone.
- The rich-message outbox is verified against a real file-backed SQLite close
  and reopen. The retained local media path, verified asset identity and TUS
  upload offset all survive process-style restart.
- A new Driver API recovery test recreates the client after database shutdown,
  resumes only the remaining attachment bytes from the server-reported TUS
  offset, verifies the uploaded asset and commits the original message once
  with its stable idempotency key.

## Automated verification

- Flutter analysis passes.
- All 154 Driver Flutter tests pass.
- All 100 API tests and API typecheck pass.
- All 13 Operations tests and Operations typecheck pass.
- The Operations production build passes.
- The configured debug APK builds and the behavior-equivalent build is
  installed on Samsung SM-S928B.

## Still open

- Complete the physical Samsung network-loss → queued file message → force
  stop → offline reopen → reconnect run and confirm one Dispatch receipt.
- Record and commit a real Operations-originated voice note in a browser with
  microphone support, then accept it on Samsung.
- Complete a normal-browser new-tab file-open pass.
- Add secure push/realtime delivery, call-event persistence and the complete
  filtered contact-history ledger.
- Resolve GAP-009 before claiming a production committed-media retention rule.
