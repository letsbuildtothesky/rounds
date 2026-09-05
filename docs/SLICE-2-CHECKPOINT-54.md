# Slice 2 Checkpoint 54 — canonical own-driver quick contact

Date: 2026-09-05

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/product/ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `ux/operations/rounds-operations-current-v45.html`

The supplied Operations board gives an own-driver marker two distinct actions:
primary click opens the Round, while desktop right-click or touch long-press
opens the compact driver contact menu. The live app previously had only the
primary-click path.

## Implemented

- Primary marker click still opens the deterministic authoritative Round.
- Desktop right-click and a 520 ms non-mouse long-press open the supplied v45
  menu at the interaction point.
- The menu preserves the canonical labels, hierarchy, measurements, shortcut
  hints and narrow-layout behavior.
- The subtitle uses authoritative Round, vehicle and state context.
- Message driver opens only the selected Round's real private conversation.
- Voice note opens that same conversation and requests real microphone capture;
  it does not auto-send.
- Center on driver eases Mapbox to the server-reported driver coordinate using
  the supplied zoom, pitch, bearing and timing.
- Show full Round opens the existing authoritative Round drawer.
- Call driver remains disabled and explains that calling is not connected.
- Outside click and Escape close the menu.

## Acceptance

The signed-in localhost board showed one menu from the real `DT` driver marker.
Center closed the menu and retained the marker at the focused coordinate. Show
full Round opened `ROUND-20260901-094250`. Message driver opened that exact
Round's existing conversation. Voice note opened the same conversation and
started a real browser microphone recording; the recording was stopped and its
unsent preview removed, so the acceptance check created no message. Call was
present but disabled.

## Verification

- All 29 Operations tests pass.
- Operations TypeScript typecheck passes.
- Operations production build passes.
- Signed-in browser interaction acceptance passes for every connected desktop
  menu action.

## Still open

- Physical touch-device long-press acceptance.
- Live planned-route, active-navigation and actual-trail evidence remain
  separate and must not be fabricated.
- Current/future Stop emphasis and responsive-device comparison remain open.
