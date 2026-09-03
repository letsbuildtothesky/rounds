# Slice 2 · Checkpoint 01

**Status:** own-team capacity foundation implemented; Slice 2 remains in progress

**Date:** 2026-09-03

## Authorized scope

This checkpoint starts Slice 2 with the real Own-Team capacity foundation: versioned vehicle profiles, recurring driver schedules, date-specific shift overrides, an Operations Drivers projection and the canonical v45 Own team/Schedule workspace. Network capacity is visible only as stable information architecture and is explicitly deferred; no partner availability, price, ETA or routing result is simulated.

## Implemented

- Tenant-scoped, versioned vehicle profiles with explicit vehicle group, departure pattern, maximum Stops per departure, planning throughput and pickup turnaround.
- Conservative migration of existing free-text Driver vehicle labels into review-required one-Stop profiles. No larger operational capacity is inferred.
- Default vehicle assignments, recurring weekly schedules and date-specific shift/off exceptions.
- Default-deny browser access to the new tables; only the API service can read them.
- Server-only `operations.set_driver_recurring_schedule` command with active Operations-role authorization, active own-team relationship validation, vehicle-profile validation, expected-version concurrency, idempotency, audit and transactional outbox event.
- Purpose-limited `GET /v1/operations/drivers?serviceDate=YYYY-MM-DD` projection covering own-team identity, current Round, completed deliveries, presence freshness, effective shift, vehicle profile and truthful schedule-based availability.
- v45 Drivers workspace with stable Own team, Network and Schedule navigation; live summary metrics; date/search controls; current-work actions; recurring schedule editing; and conservative-profile warnings.
- The schedule editor follows the existing interaction system: a right drawer on desktop and a bottom drawer on mobile.

## Verification

- Remote migrations `202609030002` and `202609030003` applied successfully and local/remote migration history aligns.
- The linked schema lint reports no issue in the new public function. Reported lint issues are Supabase/PostGIS extension internals plus one pre-existing unrelated warning.
- Contract, API and web typechecks pass.
- 95 TypeScript tests pass, including recurring-schedule validation, tenant/date authorization and viewer mutation denial.
- Operations production build passes.
- The signed-in localhost UI loaded the real `Demo Team Driver`, current approved Round, presence freshness and conservative vehicle profile from the linked Supabase project.
- Through the rendered schedule drawer, a synthetic every-day 08:00–18:00 acceptance schedule was created and then version-updated for the Driver with the note `TEST FIXTURE — recurring own-team schedule configured by Johannes for Slice 2 acceptance.` The refreshed projection reported one scheduled Driver and the effective shift.
- The committed pgTAP file contains 15 transactional assertions for tables, privileges, authorization, canonical weekdays/timezone, versioning, audit/outbox and idempotency. It could not execute on this Mac because the Supabase test command requires Docker Desktop; this is not claimed as passed.

## Boundary and next checkpoint

- Network Driver availability remains deferred and is not fabricated.
- Availability is a schedule/current-work projection, not a promised ETA. Route-completion forecasting waits for a real server routing/capacity engine.
- Existing conservative vehicle profiles require Operations review before production planning.
- Date-exception storage is ready; the Operations exception editor is the next own-team scheduling increment.
- Next: connect these capacity rules to Round planning validation and planning guidance, then add the date-exception editor before any Network capacity work.
