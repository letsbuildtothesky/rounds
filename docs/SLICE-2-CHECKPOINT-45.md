# Slice 2 Checkpoint 45 — Private Operations communications realtime

Date: 2026-09-05

## Canonical sources used

- `specs/build/BS-10.md`
- `specs/product/ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `specs/architecture/ROUNDS-ARCHITECTURE.md`
- `ux/driver/en/screens/ROUNDS-H01-OPERATOR-CHAT-v4-10OF10.html`
- `ux/operations/rounds-operations-current-v45.html`

No new UX was introduced. The existing canonical v45 communications window,
tray, map markers and top-bar unread indicator still consume one shared store.

## Implemented

- Migration `202609050002` emits a private `communications.changed` Broadcast
  hint when an Operations thread is inserted or its version advances.
- The hint contains only a versioned tenant/aggregate envelope. Message body,
  attachment metadata and signed media URLs are excluded.
- `realtime.messages` SELECT authorization resolves the authenticated Supabase
  identity through `auth_identities` and permits only active Operations roles
  on the exact `tenant:{tenant_id}:dispatch` topic.
- Team Drivers and cross-tenant Operations identities are denied the
  tenant-wide Dispatch topic.
- The browser authenticates Realtime with the current access token, joins a
  private tenant channel, validates every received hint and refetches the
  purpose-limited authoritative API projection.
- The existing API refresh remains a 30-second degraded fallback; Broadcast is
  never treated as durable truth.

## Acceptance

Migration `202609050002` was applied to the linked Supabase project and remote
schema lint found no new application-schema issue. With the canonical v45
board freshly reloaded and its fallback timer therefore 30 seconds away, the
connected Samsung Driver sent `Realtime-hint-proof-2026-09-05-D` through H01.
The unopened Dispatch conversation tray changed to that exact message in about
50 ms of browser wait, rendered it once, updated unread state without stealing
focus and produced no browser warnings or errors.

## Automated verification

- Operations: 16 tests pass, typecheck passes and the production Next build
  passes.
- API: all 100 tests and typecheck pass.
- A new pgTAP test locks the exact-topic Operations authorization and explicit
  Team Driver/cross-tenant denials. The CLI still cannot execute pgTAP on this
  workstation because Docker Desktop is absent; the migration itself was
  parsed and applied successfully by the linked Supabase database.

## Still open

- Add an equally private Driver-scoped Broadcast subscription so
  Operations-to-H01 messages no longer rely on foreground polling.
- Record and commit a real Operations-originated voice note in a browser with
  microphone support, then accept it on Samsung.
- Complete a normal-browser new-tab file-open pass.
- Add call-event persistence and the complete filtered contact-history ledger.
- Resolve GAP-009 before claiming a production committed-media retention rule.
