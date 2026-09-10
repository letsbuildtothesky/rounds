# Useful details recovered from the older specs

Reviewed the product and engineering material in the supplied specs(1).zip. The old build/ documents are not copied into this revision. Latest user decisions take precedence over old feature scope, branding and provider assumptions.

| Older source | Detail retained/refined | Current destination |
| --- | --- | --- |
| Spec 6 — Dispatch route editing/comms v1.11 | Click driver on map to contact; persistent conversations; minimize versus close; drafts/unread state survive switching; incoming messages do not steal focus | P09; QA-V21-CHAT-FOCUS |
| Spec 6; Spec 10 — Drivers availability/contact v1.4 | Center a driver separately from fit a complete Round; availability now/unavailable/later; availability reply is not accepting a job | P06/P09; ReplyAvailability; QA-V21-LATER-AVAILABILITY |
| Spec 2 — Business master v2.36; Spec 6 | Capacity shows binding dimension and used/max, including tied limits; per-departure loading, depot return/reload and genuine free-after | P04; RoundView; QA-V21-CAPACITY-READOUT |
| Spec 6; Spec 8 — Operations visual system v1.15 | Touch timeline behavior, constrained-width contextual panels, rotation/layout preservation and accessible actions | P04/P14; QA-V21-IPAD-ROTATION |
| Spec 4 — Mapping/address intelligence v1.8 | Traffic/weather accounting avoids duplicate congestion; independent handling delay has an explicit reason; failed recipient contact does not invalidate a correct entrance | P10; WeatherPolicy; QA-V21-WEATHER-DOUBLECOUNT / ENTRANCE-CAUSE |
| Spec 9 — History operating memory v1.5 | Readable operational metrics with numerator/denominator/exclusions; evidence-backed attention items; avoid one unexplained driver score | P11; HistoryProjection |
| Spec 13 — Operations edge states v1.0 | Distinguish operator connection failure, driver telemetry staleness, missing permission, empty result and system failure | P14; E06/E08 |
| Driver UX master v3.1; UI constitution v1.2; localization v1.0 | Stable next action, state honesty, Thai/English long text and field recovery; preserve approved visual hierarchy | P05/P14; driver recovery cases |
| Phase 0 field validation v1.2 | Combined navigation and location test; navigation-only battery baseline; one-consumer/fallback comparison; low-cost Android and real Bangkok route/access corpus | E06; existing QA-SYSTEM-NATIVE-R0 |
| Implementation scope ladder v1.0; engineering architecture v1.1 | Prove device/local execution before expanding providers and intercity; keep provider behavior behind adapters | E01/E06/E09/E10 |

## Latest decisions deliberately preserved

- Operators may start a freelance broadcast at any time they are authorized, without an own-fleet capacity test. Only opted-in freelancers receive it. Nearest-first expansion is a configured broadcast behavior, not automatic allocation authority.
- One SaaS can support single-city operation and optional Intercity; a city-only customer need not see national tools.
- Destination routes are fully plannable before truck arrival. Actual custody remains separately gated. The older local-only model cannot remove this approved capability.
- Manual Add Delivery remains available beside optional pasted-text/image AI assistance. Corrections to material address facts require visible review.
- Preserve approved logo geometry and restrained blue. Old color tokens and historical drawer layouts do not override the approved board.
- Do not restore Lalamove/external courier dispatch, temperature hardware, ranking-led matching, COD/payment execution or other deferred surfaces merely because an old document describes them.

This is a requirements carry-forward review, not a claim of pixel-by-pixel parity or an import of every old rule. Exact current behavior lives in product/, engineering/ and contracts/.
