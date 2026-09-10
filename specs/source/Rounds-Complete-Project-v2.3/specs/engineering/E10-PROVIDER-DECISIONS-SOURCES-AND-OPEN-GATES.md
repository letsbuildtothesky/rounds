# E10 — Provider Decisions Sources and Open Gates

## Reconciliation changelog

- 2026-09-08 · v2.3-r1: Preserve selected Mapbox direction while retaining actual provider/field gates.

Rounds engineering specification · Consolidated V2.3-r1 · 8 September 2026

## Source status

The supplied Engineering Architecture v1.1 is retained for stack direction. Historical prices, product quotas and dated SDK maturity claims are not carried as current facts. The following official sources were checked for this rewrite. They inform the adapter boundaries; account configuration, country coverage, contract terms and field behavior still need implementation verification.

| Source | Verified implication for this design |
| --- | --- |
| [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) | Administrative credentials can bypass RLS; keep them server-side and separately enforce application scope |
| [Supabase pgmq](https://supabase.com/docs/guides/queues/pgmq) | Queue visibility duration expires and messages may be read again; consumer effects must be idempotent |
| [Google cross-platform Navigation](https://developers.google.com/maps/documentation/cross-platform/navigation) | Flutter and React Native integrations exist; retain Flutter choice for Rounds and field-test actual plugin/native behavior |
| [Google Routes policies](https://developers.google.com/maps/documentation/routes/policies) | Routes results shown on a map require Google Map under stated policy; caching/display need explicit provider coherence review |
| [PostgreSQL constraints](https://www.postgresql.org/docs/current/ddl-constraints.html) | Use relational unique/foreign-key/exclusion constraints; cross-row business sums need deliberate transaction design |
| [Supabase resumable uploads](https://supabase.com/docs/guides/storage/uploads/resumable-uploads) | Supported resumable upload path exists; durable evidence completion still requires Rounds receipt/policy validation |

## Concrete provider gates

| Gate | Choice retained / proposed | Evidence required before release |
| --- | --- | --- |
| Navigation | Flutter with embedded Google navigation selected | Combined device tests, supported vehicle/country profile, Thai guidance, native lifecycle and licensing |
| Operations map | Approved Mapbox composition retained | Correct field/source permissions, actual key restrictions, rendering/performance and provider-coherent overlays |
| Server routing/geocoding | Mapbox-derived Operations driving geometry selected by ADR-M01; geocoding adapter and unsupported vehicle profiles remain gated | Bangkok address/route benchmark, vehicle feasibility, cost/account quota and storage/display rights |
| Street View | Embedded authorized Google surface plus external fallback | Key restrictions, coverage/failure lifecycle, correct destination/context and permitted display |
| AI extraction | Server adapter, review-required suggestions | Thai source evaluation, structured output, injection isolation, PII retention and cost limits |
| Voice | Provider adapter unresolved | Incoming/missed/declined semantics, caller context, native safety, masking and actual receipts |
| Identity/face | Country-specific provider review | Secure evidence, liveness/verification authenticity, correction/unknown response and approved retention |
| Payments | Direct settlement record retained; execution adapter not assumed | Commercial/legal scope, approval, idempotent receipt, bank/PromptPay validation and dispute policy |
| Customer channels | Email/SMS/LINE adapter contracts retained | Auth/signature/receipt support, template consent/privacy, country behavior and costs |

These gates do not prevent writing the full specifications. They prevent falsely claiming a provider-specific implementation is complete or approved. Required configuration terms may be unknown yet while behavior of missing/invalid/disabled configuration remains fully specified.

## Review decisions still needing owner acceptance

Confirm commercial tariffs/cancellation/wait/return terms; retention durations and legal purpose; proposed role bundles and override authority; slot hold TTL and operating-date limits; exact proof policy defaults; proposed SLO/RPO/RTO; default availability freshness and expansion policy; attendance correction approval; logo square/dot consistency; pre-job messaging launch switch; identity/voice/routing provider selection. Until configured/accepted, corresponding production capability is gated rather than silently using a made-up value. All proposed numeric defaults in this package are marked and centrally listed in decisions/03-DEFAULTS-AND-OPEN-GATES.md.
