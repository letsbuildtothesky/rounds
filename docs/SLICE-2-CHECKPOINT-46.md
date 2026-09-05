# Slice 2 Checkpoint 46 — Private Driver communications realtime

Date: 2026-09-05

## Canonical sources used

- `specs/build/BS-10.md`
- `specs/product/ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `specs/engineering/ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md`
- `ux/driver/en/screens/ROUNDS-H01-OPERATOR-CHAT-v4-10OF10.html`
- `ux/operations/rounds-operations-current-v45.html`

No new screen, message treatment or interaction was introduced. The change is
the private delivery path behind the existing canonical English H01 surface.

## Implemented

- Migration `202609050003` extends each versioned Operations-thread change with
  a private `communications.changed` Broadcast hint to the exact
  `driver:{driver_id}` topic while preserving the existing tenant Dispatch hint.
- The Driver hint contains only the versioned aggregate envelope. Message body,
  attachment metadata and signed media URLs are excluded.
- `realtime.messages` SELECT authorization resolves the authenticated Supabase
  identity to an active Driver profile, active Team membership and active Team
  relationship. It admits only that Driver's exact topic; another Driver,
  inactive relationship and Operations identity are denied.
- H01 authenticates the WebSocket with the current Driver access token, validates
  the hint and refetches the authoritative purpose-limited API projection.
- A refresh already in progress coalesces a received hint into one follow-up
  refresh, so a concurrent update is not lost. A 30-second API refresh remains
  the degraded fallback; Broadcast never becomes durable truth.
- The Driver client uses Supabase's required `wss://.../realtime/v1` endpoint.
  Token changes are applied explicitly, avoiding the dependency's initial
  async-provider rejoin defect without weakening private-channel authorization.

## Acceptance

Migration `202609050003` is applied to the linked Supabase project. On the
Samsung SM-S928B, the private Driver channel connected and reported subscribed
in under one second. While the canonical H01 thread remained open, Operations
committed `Driver-realtime-proof-2026-09-05-F` through the audited versioned
command. The phone accepted the private hint immediately and visibly rendered
the authoritative message about two seconds after the command, well before the
30-second fallback.

## Automated verification

- Flutter analysis passes and all 158 Driver tests pass.
- All 100 API tests and API typecheck pass.
- A new endpoint/topic/envelope unit test locks the Driver client contract.
- The new nine-assertion pgTAP suite passes on the linked database and locks
  exact-topic Driver authorization plus the explicit another-Driver,
  inactive-relationship and Operations denials.
- Linked-schema lint reports no new application-schema issue; output remains the
  pre-existing PostGIS extension findings and unused planning variable warning.
- The new debug APK builds, installs and runs on the connected Samsung.

## Still open

- Record and commit a real Operations-originated voice note in a normal browser,
  then accept it on Samsung.
- Complete a normal-browser new-tab file-open pass.
- Add call-event persistence and the complete filtered contact-history ledger.
- Resolve GAP-009 before claiming a production committed-media retention rule.
