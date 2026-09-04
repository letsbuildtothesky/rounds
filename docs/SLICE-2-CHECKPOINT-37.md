# Slice 2 · Checkpoint 37

**Status:** Dispatch v45 visual correction and real Mapbox mode controls

**Date:** 2026-09-04

## Correction

- Uses the final canonical v45 CSS override as the Dispatch visual source,
  correcting the earlier use of an obsolete smaller Communications variant.
- Restores the final 438 × 650 px desktop conversation surface, header,
  context strip, thread, composer, staged-attachment and tray measurements.
- Restores the canonical flat Live/Plan switch, responsive rail/drawer
  geometry, map-mode menu sizing, marker language and four-part legend.
- Uses Mapbox Standard with the canonical faded Operations treatment and
  Mapbox Standard Satellite for real aerial imagery.
- Adds real building-level 3D site focus and direct zoom, rotate, north,
  2D/3D pitch and operational-bounds focus controls.
- Opens the selected saved operational coordinate in Google Street View and
  states Mapillary as the coverage fallback; it does not draw fake street
  imagery inside Mapbox.
- Keeps Weather and Network supply visibly disabled until approved live feeds
  are connected. No sample feed is presented as operational truth.

## Verification

- Operations TypeScript typecheck passes.
- Operations unit tests and production build pass.
- Browser acceptance confirms Standard Operations, Satellite, 3D Site and
  Street mode switching without a Mapbox style-load error.
- Browser acceptance confirms 3D entry, 20-degree rotation and return to 2D.
- Browser inspection confirms the corrected v45 Communications surface
  remains embedded over the real Dispatch map.

## Remaining map gaps

- Weather requires an approved forecast/radar provider and data contract.
- Network supply requires an approved partner-capacity feed and data contract.
- Street View remains an explicit external-provider handoff; an embedded
  panorama would require separate provider approval, key restrictions and
  commercial review.
