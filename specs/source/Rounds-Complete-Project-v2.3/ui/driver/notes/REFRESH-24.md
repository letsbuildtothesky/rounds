# Refresh 24 — About you: Team and Independent

42 of 47 original app files refreshed; 5 remain original. This pair updates A06 and A06B only. All other 45 app files, prior review pages, style guide and shared tokens remain unchanged, including the approved A09 scanning-motion polish. The ZIP contains all 47 app files.

## Design

The two About you screens use the same onboarding header, 44px heading, restrained blue/orange colors, 17px lead and pinned 68px primary action as the approved recent screens. The original large 30px name entry is preserved inside a clearly bounded 72px field. Its visible label increases from 12px uppercase to 18px. Back grows from 40px to 52px. Narrow or short screens scroll without shrinking the name, controls or task surfaces.

A06 keeps the UrbanFlowers Team context and requires both a name and a profile photo. The previous 154px square photo and small beside-photo control become a full-width 196px photo surface and separate 60px full-width Replace photo button. The photo state is a readable 14px Required/Added label. Add photo opens two explicit 76px choices: Take photo and Choose from phone. Added photos open a 340px full-image review. All previews use contain-fit, keeping the complete selected photo visible.

A06B retains the distinct Independent/Network path. It asks only for the displayed name. A quiet pale-blue panel with an orange edge explains that the later live face check supplies the profile photo. It has no gallery/camera action and no premature verified badge. The panel title is 22px, body 17px. Extra verification fields and new work-mode toggles have not been added.

The original 17:46 sample clock is retained on both screens. There is no fabricated saved toast, new success animation or extra confirmation step before vehicle selection. Sample profile photos are text placeholders, not generated face images.

## Interaction behavior

The original requirement of at least two trimmed name characters is retained. Names are not constrained to Latin letters: spaces, punctuation and Thai input remain supported. A brief inline error appears after leaving an incomplete field. The ready state updates as the driver types. Inputs remain large; long values use the native text-input scrolling behavior rather than reducing the font.

Team Continue requires a name, a decoded image and a connection. Photo selection never counts as Added until image decoding succeeds. An invalid or cancelled replacement retains the current photo. Late callbacks cannot replace a newer image. Team photo review and source dialogs preserve focus, support Escape and trap Tab. Photo URLs stay in memory and are released on replacement or non-cached page exit. Network Continue needs a name and connection only. Offline editing/photo selection remains possible; reconnecting never advances automatically.

Back opens a leave confirmation if local details have been entered. Team returns to the entry flow’s invite screen. Independent returns to its actual `screen=path` state; the original `screen=role` fallback did not match any entry-flow state and opened the phone screen instead. This corrects the route without changing the entry-flow file.

Continue opens A07 with explicit `context=team` or `context=network`, preserving its existing split: Team proceeds toward permissions and Network toward identity verification. Navigation is between independent HTML samples. No name, image bytes, merchant membership or profile save is transferred or persisted by these prototypes. Production must securely retain the real onboarding draft and use the authenticated merchant/driver relationship; the visible UrbanFlowers name is the original sample context.

## Validation

DOM checks cover required-name/photo gates, source selection, image decoding, cancellation/replacement, full-image review, late callbacks, modal focus, offline reconnection and the correct Team/Network routes. Static checks cover IDs, scripts, local links, original clocks, font/control dimensions, 320/360/393px key text widths, unchanged earlier files, 47-file coverage and ZIP integrity.

Browser visual/device QA remains unavailable under the earlier security restriction. Source/DOM/font checks do not establish phone rendering, native picker behavior, Thai typography, keyboard viewport behavior or glove/daylight usability.

Sources: original A06 v3 and A06B v3; entry A02–A05 v6 and A07 v4 route contracts; approved Refresh 22 photo controls and Refresh 23 onboarding; canonical v42 Driver UX Behavior Master v3.0 and Driver UI Constitution v1.1; unchanged style guide v1.

Remaining original files: A01, A01B, combined A02–A05, A07, and combined E04–E06. Suggested next: A07 Your vehicle, with its Team and Network variants.
