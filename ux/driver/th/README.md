# Thai Driver UX Boards

**Status:** complete Thai visual board package received and synchronized on 2026-09-03.

This folder contains 46 Thai-specific HTML boards. `A01 Splash` is the shared language-neutral board in `../en/screens/`, completing parity with the 47-board English inventory.

Rules:
- Thai (`th-TH`) is the primary Thailand Driver locale.
- English is the secondary first-class locale.
- Thai boards are localization/visual-QA references, not a separate product or state machine.
- Screen IDs, commands, domain states, evidence requirements, permissions and workflow must remain equivalent to the English canonical boards unless a human explicitly changes the product specification.
- If a Thai board appears to change product behavior rather than presentation, stop and report the conflict.
- Implementation must follow the board geometry, hierarchy, drawers and interaction intent; implementation convenience is not permission to redesign a screen.
