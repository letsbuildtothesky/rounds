# Refresh 26 — Splash and Choose language

45 of the 47 original app files are now visually refreshed. This pair updates A01 and A01B. The other 45 app files, including the recently polished vehicle SVGs, face-check motion and Team onboarding permission route, are unchanged. The ZIP carries all 47 canonical app files, all previous review boards, reusable vehicle SVGs, the shared style guide, design tokens and cumulative notes.

## Design

A01 retains the original simple centered wordmark and clean, lightly tinted background. The mark now uses the approved blue #1754a6 and orange #ff6420 square, matching the proportions and lettering of the recent headers at a larger 54px size. The entrance is a short 420ms fade with only 4px of vertical movement; the square fades in with it. There is no glow, bounce, loop, spinner, progress percentage or new loading claim. Reduced-motion preferences and the explicit reduced-motion review sample show the final mark immediately. The final frame remains visible for review. The splash keeps its original absence of a simulated OS status bar.

A01B retains both languages, the Profile change reminder and one primary Continue action. Thai is first and selected on a new device, as required by the current localization specification. An existing valid English preference is respected. The approved blue wordmark and orange square replace the earlier black mark. The heading follows the 44px onboarding scale, the supporting copy is 17px, and the language labels are 28px. Row targets increase to at least 120px; Continue increases to a minimum 68px. Selection uses the same pale-blue surface, orange edge and blue radio as Your vehicle. Both rows remain visible as direct choices; there is no flag icon or additional picker.

The title, supporting copy, eyebrow, Continue label, document language and radio-group name change together. Native-language row labels remain identifiable in either state: ไทย / Thai and English / อังกฤษ. Redundant English/English copy is removed. Thai has normal letter spacing and more vertical room. Its font stack uses system Thai-capable fonts; no remote font request or generated imagery is required. The original 9:41 example clock is retained on A01B.

The footer sits in flex flow beneath a scrolling content area. A narrow or short viewport does not shrink type, rows or controls; content can grow and scroll. Safe-area padding is retained. The language choice is deliberately uncluttered and does not repeat network, role, merchant or account controls.

## Behavior and handoff

Language selection supports full-row clicks, one selected radio, one tab stop, arrow keys and Home/End. It works offline. Merely opening the screen or selecting a row does not write a preference. Continue in the canonical app file writes only `rounds.language`, then opens the existing A02–A05 entry file with the explicit `?lang=th` or `?lang=en` query. A blocked local-storage write does not prevent continuation: the explicit query still supplies the selected language to the entry flow. It does not claim the preference was saved. The entry file already supports both languages and remains unchanged in this pair.

The embedded review boards use fixed Thai/English samples in memory. They neither read nor overwrite the real device preference. In a review iframe, Continue reports the selected language and next step in the outer review board, without opening the older entry file (which stores a preference when opened). The full canonical HTML files retain actual page navigation. Splash's wordmark is a keyboard-accessible link to A01B; in the paired review it focuses the existing language board.

The old mobile-width 1.25-second splash navigation timer is removed. Animation duration is not an application readiness signal. This HTML prototype advances explicitly through its accessible wordmark link; Play/Final frame/Reduced motion controls belong to the outer review, not the driver screen. Production startup must connect its readiness and session/locale routing to the native launch flow. This pair does not implement native boot, authentication or a session router.

The Thai-first choice follows ROUNDS-SPEC-14-DRIVER-LOCALIZATION-LANGUAGE-v1.0, which places A01B between A01 and the A02–A05 entry flow. It does not convert the entire screen pack into a localized app. Profile → Language remains the later settings route. Account, role, merchant, Network availability and active-work state are not touched.

## Validation

Checks cover Thai-first initialization, a valid saved English preference, invalid/missing/blocked storage, both selection states, keyboard selection, localized copy and document language, offline continuation, storage limited to the explicit language choice, the onward language query, and review samples that leave the real preference unchanged. Source checks cover splash motion and reduced-motion rules, absence of automatic routing timers, semantic links and radio labels, unchanged font/control sizes at narrow widths, valid IDs and scripts, local targets, all 47 canonical filenames, unchanged previous designs/assets and ZIP integrity. Latin label and logo widths are checked with font metrics at 320/360/393px.

Browser/device visual QA remains unavailable under the earlier security restriction. Static, DOM and font checks are not phone rendering validation. The local font inventory does not include a Thai font, so Thai glyph shaping, natural phrasing, wrapping, enlarged text, actual device fallback fonts and outdoor/glove use still require native-speaker and device review. No claim of production readiness is made.

Sources: original A01 v5 and A01B v1; current localization spec v1.0 and canonical manifest; approved Refresh 24/25 onboarding; shared style guide v1 and tokens.

Remaining original visual designs: combined A02–A05 driver entry flow and combined E04–E06 live Round changes. These are two canonical files containing multiple states; their internal views should be reviewed in manageable pairs rather than compressed into two crowded boards.

## Pack coverage sweep — 8 September 2026

The current coverage tracker is `ROUNDS-DRIVER-SCREEN-COVERAGE-v2.md`, linked from the pack index. It supersedes the historical v1 progress counts, separates 47 files from their internal screens/variants, and carries forward the remaining design backlog. All 47 app HTML files and assets are unchanged by this documentation sweep. The two remaining original groups are A02–A05 and E04–E06. Full-set source checks found no missing local files, duplicate static IDs, unresolved static ARIA/label references or inline JavaScript syntax errors. Actual browser/device visual review remains pending.
