# Slice 2 Checkpoint 56 — canonical v45 responsive workstation

Date: 2026-09-05

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `ux/operations/rounds-operations-current-v45.html`

The supplied v45 board keeps Dispatch as a rail-and-map workstation on compact
laptops and iPad-class portrait widths. At 768 px it uses a two-row top bar; it
does not replace the four global destinations with a custom navigation sheet.

## Implemented

- Removed the custom compact navigation trigger from the authenticated v45
  workstation and retained Dispatch, Drivers, History and Settings in the
  supplied second-row tablet navigation.
- Copied the canonical top-bar, rail, queue, map-header, drawer and control
  dimensions for the 1200–1366 px laptop, 901–1199 px compact-laptop and
  768–900 px portrait ranges.
- At 1024 px, the workspace subtitle and Own Team label collapse exactly as
  the board specifies while the global navigation remains visible.
- Automatic-planning text collapses below 1120 px, compact map-health copy is
  hidden, and the Rounds overview link is hidden at the supplied 790 px
  boundary.
- Map, queue and drawer controls retain their canonical compact hit sizes.

## Browser acceptance

The real React preview and the canonical v45 HTML were rendered side by side
in the in-app browser at the same reference viewport sizes.

- 1280×720: canonical 320 px rail and desktop navigation composition remain
  intact on the signed-in live board.
- 1024×768: 68 px top bar, 282 px rail and 742 px map; no horizontal or
  vertical document overflow.
- 768×1024: 112 px two-row top bar, four visible navigation items, 274 px rail
  and 494 px map; no horizontal or vertical document overflow.

Only canonical connected controls were compared. Network supply, rain and
other disconnected prototype roles remain absent rather than being simulated.

## Still open

- Repeat the compact comparison for each business workspace and open drawer.
- Physical iPad/Safari acceptance remains a release gate.
- No phone layout is claimed; the supplied Operations target is iPad-class or
  larger.
