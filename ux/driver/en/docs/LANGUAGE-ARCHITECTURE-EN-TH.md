# Rounds Driver App · EN / TH Language Architecture

## Product behavior

First run:

`A01 Splash → A01B Choose Language → A02–A05 Entry Flow`

Language is an app-level preference. It is not selected again on individual onboarding screens.

Later change:

`L01 Profile → Language → English / ไทย`

## Board strategy

- English and Thai boards keep identical IDs and flows.
- No feature, state, button, evidence requirement, or role rule changes between languages.
- Thai is designed screen-by-screen, not treated as a mechanical string replacement.
- Thai QA must explicitly check natural line-height, wrapping, hierarchy, touch targets, Thai date conventions, and 320 px behavior.
- Production implementation should use one localized app rather than two separate codebases; the separate EN/TH board folders are design/handoff artifacts.
