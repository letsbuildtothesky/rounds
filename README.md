# Rounds — Codex Build Pack v2.0

This folder is the single implementation handoff for Rounds.

It contains:
- the current canonical product specs;
- Engineering Architecture v1.1;
- Phase 0 field spec;
- complete Engineering Build Specs for the product-complete V1 design;
- the current Operations HTML reference;
- all 47 English Driver HTML boards;
- a dedicated Thai Driver board folder;
- Codex build-order and repository instructions.

## Start here
1. `AGENTS.md`
2. `CODEX-BUILD-ORDER.md`
3. `CODEX-FIRST-TASK.md`

## Important
The Build Specs are complete enough to define how later Rounds slices are built, but **Codex must still implement sequentially**. Future-slice Build Specs are not permission to skip Phase 0 or build all screens/features at once.

When Thai boards are ready, place them under `ux/driver/th/` with the same screen IDs/behavior as English.
