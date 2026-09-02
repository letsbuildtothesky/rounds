# Slice 1 checkpoint 11 — server-backed Deliveries workspace

## Delivered

- Added `GET /v1/operations/deliveries`, protected by the same bearer identity and tenant authorization boundary as other Operations projections.
- Added a canonical delivery projection covering lifecycle state, promise, pickup, recipient and buyer, destination pin, Stop version, current manifest items and Round assignment.
- Added the v45 Deliveries workspace with live counts, lifecycle filters, search, list selection and a detailed operational readout.
- Connected an unplanned delivery directly back to the matching service date and reference in Dispatch planning.
- Connected `+ Add delivery` to the existing real manual-intake drawer without replacing the list.
- Added responsive phone behavior with explicit list-to-detail and detail-to-list navigation.

## Acceptance evidence

- The authenticated UrbanFlowers tenant returned five canonical deliveries across unplanned, active and delivered states.
- Browser acceptance verified All and Unplanned filters, selected-detail synchronization, physical manifest content, Round/driver execution state and the planning handoff.
- The unplanned `E2E-20260901-01` item opened Dispatch Plan on its exact service date with its exact reference search applied.
- Desktop acceptance was checked at 1280 × 900; phone list and detail were checked at 390 × 844.
- Opening and closing the real intake drawer from Deliveries was verified without submitting a synthetic command.

## Verification

- `npm run typecheck --workspace @rounds/api`
- `npm test --workspace @rounds/api`
- `npm run typecheck --workspace @rounds/operations-web`
- `npm test --workspace @rounds/operations-web`
- `npm run build --workspace @rounds/operations-web`

## Deliberate boundary

This workspace is read-only operational truth plus navigation to already-authorized commands. It does not introduce fake edit, cancel, reassignment or proof actions.
