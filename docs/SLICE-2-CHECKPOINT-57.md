# Slice 2 Checkpoint 57 — canonical single-delivery intake

Date: 2026-09-05

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/build/BS-08.md`
- `specs/product/ROUNDS-SPEC-2-BUSINESS-PRODUCT-MASTER-v2.26.md`
- `specs/product/ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `ux/operations/rounds-operations-current-v45.html`

The supplied v45 drawer defines the visual hierarchy for intake. Current scope
authorizes the real manual single-delivery command and an operational
destination pin. It does not authorize a simulated AI/file extraction or batch
import workflow.

## Implemented

- Restored the supplied drawer hierarchy: `DELIVERY INTAKE`, delivery-details
  label, Recipient, Order & promise, Items & handling, Pickup, and the final
  Add delivery / Cancel actions.
- Removed the custom green command explainer and the dark blurred workstation
  scrim that were not present in the canonical board.
- Reordered inherited merchant pickup truth to the supplied end-of-form
  position while preserving the real tenant/location selector needed by the
  connected command.
- Replaced editable latitude/longitude boxes with an explicit real Mapbox
  crosshair selector. A coordinate enters the command draft only after the
  dispatcher chooses `Use this pin`; the persisted provenance remains
  `dispatcher_pin`.
- Extracted that selector into one shared client component so new-delivery and
  post-pickup live-change flows use the same operational-pin interaction.
- Portaled the map selector above the complete workstation so its header,
  controls, attribution and outcome cannot be clipped by the v45 top bar.

## Browser acceptance

- Signed-in localhost acceptance opened the real `+ Deliveries` drawer and
  confirmed the canonical header, all four form sections and both final
  actions.
- At 1280×720 the React drawer and supplied v45 drawer both measured 410 px
  wide at x=870, with exact 24/22/21 px header and 0/22/38 px body padding.
- The document remained 1280 px wide with no horizontal overflow and the
  background map remained visually undimmed.
- The real Mapbox selector loaded a canvas, retained Mapbox/OpenStreetMap
  attribution, rendered the orange crosshair and committed a selected draft
  pin. No delivery was submitted during acceptance.

## Verification

- `npm test --workspace @rounds/operations-web` — 32 passing
- `npm run typecheck --workspace @rounds/operations-web`
- `npm run build --workspace @rounds/operations-web`

## Deliberate boundary

Generalized AI extraction, source-file review, CSV/batch ingestion and claimed
address matching remain absent. Production address validation/geocoding still
depends on the approved provider-coherence decision; the manual operational pin
is the truthful Pilot path.
