# Slice 2 Checkpoint 44 — Physical rich-message restart acceptance

Date: 2026-09-05

## Canonical sources used

- `specs/build/BS-10.md`
- `specs/product/ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `ux/driver/en/screens/ROUNDS-H01-OPERATOR-CHAT-v4-10OF10.html`
- `ux/driver/en/screens/ROUNDS-N02-OFFLINE-RECONNECTING-v2-10OF10.html`
- `ux/operations/rounds-operations-current-v45.html`

No new UX was introduced. This is the physical acceptance follow-up to
Checkpoint 43's durable recovery implementation.

## Samsung acceptance

On Samsung SM-S928B against the live Supabase/API/Operations stack:

1. H01 staged `rounds-restart-proof.txt` with the unique text
   `Offline restart recovery 2026-09-05 11:28`.
2. Wi-Fi and mobile data were disabled before Send.
3. The supplied N02 screen reported `1 message saved on this phone`.
4. The app process was force-stopped and relaunched while still offline.
5. N02 again reported exactly one saved message after process restart.
6. Wi-Fi and mobile data were restored and `Retry connection` was used.
7. N02 changed to `Back online`; both proof/status and message queues showed
   `Nothing waiting on this phone` / `Synced`.
8. The already-open canonical v45 Dispatch conversation refreshed from the
   server and contained exactly one matching message plus exactly one
   `rounds-restart-proof.txt` file card.

The local test file was removed from the Mac and Samsung after acceptance. The
committed server thread record was retained as the audit evidence.

## Verification inherited from Checkpoint 43

- Flutter analysis passes and all 154 Driver tests pass.
- All 100 API tests and API typecheck pass.
- All 13 Operations tests, Operations typecheck and production build pass.

## Still open

- Record and commit a real Operations-originated voice note in a browser with
  microphone support, then accept it on Samsung.
- Complete a normal-browser new-tab file-open pass.
- Add secure push/realtime delivery, call-event persistence and the complete
  filtered contact-history ledger.
- Resolve GAP-009 before claiming a production committed-media retention rule.
