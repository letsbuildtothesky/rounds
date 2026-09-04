# Slice 2 · Checkpoint 25

**Status:** canonical F01/F02 drop-off handoff restored as a separate pre-POD state

**Date:** 2026-09-04

## Implemented

- Authoritative arrival now opens the supplied F01/F02 handoff screen before proof of delivery.
- English and Thai layouts are generated from measurements extracted from the two canonical HTML boards.
- The screen renders the real Stop sequence, recipient, destination address, locked manifest quantities and any real handling note. Missing handling notes are omitted rather than replaced with prototype content.
- Recipient and someone-else selections continue to POD with a typed local handoff selection.
- Left-at-location opens the supplied bottom drawer with Reception, Lobby / entrance, At the door and Other approved place choices before continuing to POD.
- Call recipient, Message Operations and Recipient unavailable reuse the existing real contact and exception surfaces.
- POD no longer asks the handoff question a second time. It consumes the selected handoff, requests the remaining receiver details only when required, and commits the handoff together with photo evidence through the existing atomic server command.
- A debug-only handoff preview allows physical visual acceptance without changing Round, Stop or custody state. Release behavior cannot enter that preview.

## Verification

- Flutter static analysis passes.
- All 119 Flutter tests pass.
- New tests cover the measured 393 × 852 English layout, real-data projection, someone-else routing, left-location drawer/selection and compact 320 × 700 Thai layout.
- The generated Driver UI measurements match the checked-in canonical geometry contract.
- The English 393 × 852 golden baseline passes.
- The configured Android debug APK builds and installs on the connected Samsung SM-S928B.
- The English F01/F02 surface and left-location drawer passed physical Samsung visual inspection without overflow.

## Honest remaining boundary

- Physical acceptance used the debug-only screen preview, so no live Stop or custody state was changed merely to expose the screen.
- The existing server-backed POD authority already validates and commits all three handoff types, but each new UI choice still needs an end-to-end run from a real arrived Stop through committed POD.
- Thai has automated compact-layout coverage but still needs physical-device acceptance.
- This checkpoint does not add an early handoff mutation. Delivery authority remains atomic with POD evidence, preventing a selected-but-unproven handoff from being mistaken for completion.

## Next safe work

- Continue the supplied F03/F04 proof-of-delivery boards: replace the remaining generic proof surface with the canonical measured English/Thai presentation while preserving the accepted camera, retained-draft, resumable-upload and atomic completion behavior.
