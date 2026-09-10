# Rounds driver app — style guide

Version 1 · Agreed direction through Refresh 05 · 7 September 2026

This guide records the design already agreed for Rounds. Its purpose is consistency as each pair of HTML screens is refreshed and later implemented in the app.

## 1. Product rule

Clarity comes first. A driver must be able to identify the destination, understand the next action and reach the controls quickly. Preserve large task and map surfaces. Favor familiar layouts, strong contrast, concise copy and generous touch targets. Premium means precise spacing, legible type and consistent behavior.

Compare every screen with its predecessor before changing it. Preserve useful information and working states. Improve a specific problem; do not redesign just to make a page look different. Continue in pairs.

## 2. Color system

Blue and orange are the two brand colors. Green and red express operational states, rather than additional brand themes.

| Token | Value | Role |
|---|---|---|
| `--blue` | `#1754A6` | Rounds wordmark, primary navigation, action buttons, active tabs, current route |
| `--blue-deep` | `#14488D` | Blue hover/pressed emphasis |
| `--blue-soft` | `#EDF4FD` | Information panels, selected rows, supporting controls |
| `--orange` | `#FF6420` | Brand accent, pickup/current destination, narrow emphasis rule |
| `--orange-soft` | `#FFF2E8` | Handling emphasis where needed |
| `--ink` | `#17283F` | Main text, dark labels on orange |
| `--muted` | `#526278` | Supporting text that still needs to be read |
| `--line` | `#DCE4ED` | Dividers and quiet borders |
| `--paper` | `#FFFFFF` | Main app surface |
| `--canvas` | `#E9EDF2` | Review background outside the phone |
| `--green` | `#167344` | Completed, collected, signed, ready to confirm |
| `--green-soft` | `#EDF7F1` | Supporting completed-state surface |
| `--red` | `#A22F2F` | Problems and exception actions |
| `--route-later` | `#668EBC` | Later route legs, secondary to the next leg |
| `--care-ink` | `#98400F` | Readable fragile/handling labels |

Use labels, icons or numbers alongside state colors. Keep ordinary text dark. Do not make every section a saturated color block. White space and pale surfaces support the blue/orange identity.

Calculated solid-color contrast: white on blue **7.36:1**; ink on orange **5.03:1**; muted on white **6.22:1**; green on white **5.88:1**. Use dark ink for small text on orange. Provider-rendered map labels need separate inspection; these figures do not constitute a full accessibility audit.

## 3. Wordmark and icons

- Use the existing **Rounds** wordmark in blue with its small orange square accent. Preserve its proportions; do not alternate between black and blue by screen.
- Current HTML wordmark: Arial, 24px, weight 800, letter spacing −1.1px; orange accent 6×6px. The status/navigation screens use their contextual header instead of repeating the logo.
- Use crisp inline SVG icons. Default 24×24px, 2px stroke, rounded line ends and joins. Primary direction symbols are 44×44px with a stronger stroke.
- Icons must describe an action or status. No emoji, decorative illustrations, generated mockups or ornamental badges.
- Keep icon artwork separate from the touch target: a 24px icon sits inside a 52px control.

## 4. Typography

Current HTML stack: `Arial, Helvetica, sans-serif`. Weights 400, 600 and 700; reserve 800 for the wordmark. Avoid the previous widespread 800–900 weights.

| Use | Size | Treatment |
|---|---:|---|
| Main completion statement | 40–44px | 700, line height about 1.08 |
| Shift time / large numerical total | 44px | 600–700, tabular figures |
| Navigation distance | 36px | 700; units must remain legible |
| Main screen heading | 28–30px | 700, line height 1.12 |
| Destination building | 22–25px | 600–700, allowed to wrap |
| Turn instruction | 20px | 600, line height 1.25 |
| Primary action | 18px | 600 |
| Handoff choice | 19–20px | 600 |
| Package title / important row | 17–18px | 600, line height 1.25–1.3 |
| Address / secondary action | 15–16px | 400–600 |
| Operational metadata | 14px | 400–600 |
| Compact context / care label | 13px | Only when subordinate to the task |

Use readable units: `13 min`, `2.9 km`, `200 m`, `1h 52m`. Keep figures and units together when possible. Never truncate the important part of an address or recipient name. Let rows grow or scroll rather than shrinking task text.

At 320–350px widths, reduce horizontal padding before reducing type. Important task copy stays at least 14px. Mock OS chrome and map-provider attribution are exceptions; they are not driver instructions.

Thai font selection and long Thai address wrapping remain to be validated. Preserve the hierarchy and remeasure the actual text; do not assume Latin metrics transfer unchanged.

## 5. Spacing and geometry

- Primary spacing rhythm: **4 / 8 / 12 / 16 / 20 / 24 / 32px**.
- Standard phone content inset: **18px**; use **14px** on narrower screens. Home/shift layouts may retain their existing 22px inset.
- Content gaps: 12–16px. Row separators: 1px. Emphasis rule: 4px.
- Buttons and compact panels: **7px radius**; checkboxes 6px; sheets 12px at the top and 8px at the bottom.
- Map markers can be circles/pins because the shape communicates a location. Do not introduce pill-shaped action buttons.
- No heavy shadows on content cards. A restrained shadow is permitted for floating map controls and modal separation. The phone-frame shadow belongs only to the review presentation.
- Reference review phone: **393×852px**. It is not a fixed production viewport. On a phone, use available width, dynamic viewport height and safe-area insets.

## 6. Controls

| Control | Minimum size / behavior |
|---|---|
| Header / map icon control | **52×52px** |
| Supporting contact action | **60px** high; use a text label when space allows |
| Primary navigation action | **64px** high |
| Collection / proof completion | **68px** high |
| Secondary list / “All stops” action | **56px** high |
| Modal action row | **68px** high |
| Package check row | **88–100px**; whole row is tappable |
| Handoff choice | **96–104px**; whole row is tappable |
| Checkbox artwork | **34×34px**, within its large row target |
| Photo capture surface | **196–212px** high or larger |
| Signature pad | **220–360px** high, dedicated signing panel |

Use one clearly dominant action per state. Navigation/actions are blue; final ready-to-confirm actions can be green. Disabled controls use a pale neutral surface and readable muted text, with actual disabled behavior. Never show ready styling when required evidence is missing.

Keyboard focus uses a visible 3px orange outline with space around it. Use native buttons/links, accessible names, pressed state on toggles, and hidden attributes for inactive content. Modal sheets move focus inside, trap Tab, support Escape, and return focus when closed. The background is inert while a modal is open.

## 7. Screen structure

**Navigation:** contextual header → full-width blue direction panel with orange rule → large real map → destination/ETA and primary action. The map takes remaining space. Controls must not cover the destination or provider attribution.

**Pickup / proof:** fixed context/progress → scrollable task content → pinned completion action. Keep large package rows and direct feedback. Use pale blue for selection and green for ready/complete states.

**Handoff:** location and package context → three large handoff choices → reachable contacts and unavailable action. Preserve “Only when instructed” for unattended handoff.

**Stop complete:** concise green confirmation → next route/map → next destination, travel estimate and primary navigation action. Keep the next task prominent; no full-screen celebration.

**Round complete:** delivered total and merchant → shift continuation or network fare → one next action. Keep team and network contexts distinct.

Use flex/grid flow, minimum heights and a defined content scroller. Avoid absolute fixed-height docks whose content can grow beyond their box. Do not shrink controls to fit a short screen. Never place instructions beneath a fixed footer.

## 8. Maps and data

- Use real map imagery and road geometry. No decorative/fabricated street maps.
- Next route: 6px blue with a white casing. Later legs: about 4px secondary blue.
- Current pickup/delivery: orange. Other stops: blue. Delivered stop: green with a number/check. Show enough labels to explain the markers.
- Pan, pinch, zoom and recenter when interactive maps are available. Keep a saved real map when they are not. Maintain logo/attribution visibility.
- Destination, marker, distance, ETA and external navigation must agree. Use one captured route source for this prototype; do not mix legacy hard-coded figures with new geometry.
- Demo coordinates, job records and captured route estimates are not live GPS or traffic. Keep these implementation limitations in the review notes rather than repetitive driver instructions.
- These prototypes currently use a driving profile. Vehicle routing, entrance verification and real location behavior require implementation work.

## 9. Copy and behavior

Write the action directly: “Navigate to Stop 2,” “Call recipient,” “Use signature,” “Complete Stop 1.” Remove explanatory copy that repeats what the driver can already see.

Preserve instructions that change handling or delivery decisions: “Fragile,” “Keep cool,” “Only when instructed.” Never manufacture “saved,” GPS verification, on-time status or payment status. Use fixture data honestly in the design review and real application state in production.

Counts must reconcile across pickup, handoff, proof and completion. One physical package equals one selectable item. Retaking a photo must not discard a valid image until a replacement succeeds. Signature resizing must preserve the accepted drawing. Changing the receiver invalidates that receiver's signature.

## 10. Future changes and handoff

Carry this guide, `design-tokens.css` and cumulative design notes into each new pack. The tokens describe the visual system; existing HTML pages remain the implementation references for behavior.

Before calling a pair finished, check the predecessor, selected/disabled/error states, navigation targets, numerical consistency, small-width wrapping and unchanged earlier screens. Browser/phone visual verification is still pending in this environment, including sunlight, gloves, camera behavior, touch signing and Thai text. Do not label the work 10/10 or production-ready without that evidence.

Flutter implementation should reproduce these tokens, hierarchy and behavior in shared native components. HTML/CSS is the visual reference; pixel values alone do not replace layout and device validation.
