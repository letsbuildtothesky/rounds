# E08 — Security Permissions and Data Lifecycle

Rounds engineering specification · Consolidated V2.3-r1 · 10 September 2026

## Changelog

- 2026-09-10 · v2.3-r1 Dispatch drafts: ADR-Q05 permits bounded tab/login-scoped text/attempt recovery only after fresh authorization, with no tokens/projections/grants and explicit logout erasure/failure. This is not encrypted Driver evidence or a browser security certification.
- 2026-09-09 · v2.3-r1: ADR-M03 defines finite upload capabilities, create-only Supabase objects, bounded private-bucket checks and explicit RLS/edge/retention activation gates.

- 2026-09-08 · v2.3-r1 device registration: adopt ADR-A02 hashed-installation enrollment/renewal, irreversible self-revocation, atomic private audit and principal-scoped abuse bound; strengthen identity acceptance without claiming native/provider execution.
- 2026-09-08 · v2.3-r1 HTTP increment: narrow portable principal resolver, short-lived device capability and receipt-original-job status checks; isolated API migration and tests, not Supabase session/phone certification (ADR-A01).
- 2026-09-08 · v2.3-r1: command receipt RLS requires original tenant/city as well as actor; live authorization gates replay/status, and migration cannot guess missing original scope.

## Dispatcher driver access and realtime identity

The API role reads active related/accepted drivers through relationship-scoped SELECT policies. Exact current position/trail additionally requires a server-issued driver_tracking_grants window for team shift, accepted Round/trip or supervised recovery. Relationship alone never grants off-duty GPS. Device credentials remain driver-self only; operator connection status is a minimized authorized projection.

The trusted entitlement service creates/revokes grant windows in the same business transition. Clients cannot write grants or set database context. Notification inbox rows require current tenant and principal. Tenant/reference vehicle reads have explicit policies. Global broker is reserved for constrained server conflict/matching checks, not an unrestricted board query.

Supabase auth UID is mapped through principals.auth_subject to the application principal ID. Active topic grants have partial uniqueness and finite expiry; revoked historical grants can be replaced. SUPABASE-REALTIME-POLICIES.sql is separate from portable role SQL. Active-channel disconnect and refetch denial must be proved on the actual deployed service; expiry alone does not certify immediate revocation.

## Enforcement model

All tenant-owned rows use indexed tenant scope and same-tenant foreign keys. Private schema fails closed with RLS enabled/forced and no client grants. Command API runs under a reviewed restricted service role and resolves authenticated identity/capability/city/job before mutation; no raw client tenant header grants access. If any database role bypasses RLS, the service must still enforce context and minimization and its credentials remain server-side. Supabase administrative secret/service roles can bypass RLS and must not be exposed in clients. [Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security)

Proposed DB pattern: API opens transaction and sets LOCAL validated actor/tenant context, then runs TypeScript-owned transactions under a restricted role (ADR-T01). Context is never set from unverified request data. Connection pooling must clear state; use transaction-local settings, not session-persistent tenant state. Worker has limited queue/domain effect permissions; migrations use a separate privileged role. Revoke direct UPDATE/DELETE on immutable history/manifest seals; retention service has separately audited controlled procedures. Supabase Auth/Storage internal schemas are not altered casually.

Core v2.3 command connections reject a superuser/BYPASSRLS login even if SET ROLE could hide it; rounds_api must also be a non-owner. Command receipts require actor_id=context_principal(), tenant_id IS NOT DISTINCT FROM context_tenant() and city_id IS NOT DISTINCT FROM context_city() in USING and WITH CHECK. NULL means an explicitly authorized tenant-wide/global command, not a wildcard. Server-derived current authorization is rechecked before replay/status, not only before first execution. A full-schema same-tenant city FK binds non-null scope. Legacy receipts without provable original scope remain in the old path or reviewed recovery; never backfill a guessed city.

## Permissions and read projections

P01 role bundles expand to named capabilities. Tenant/city permissions apply to list, detail, exports, realtime and media, not just buttons. Global driver self access never implies access to arbitrary tenant rows. Cross-tenant matching uses server-only eligibility/conflict computation and minimized results. Pre-acceptance supply excludes exact GPS/other merchant details; accepted job grants minimum needed identity/contact/location. Reassignment/revocation recomputes participant/subscription/media authorization without deleting history.

Customer tracking uses unguessable hashed audience token, expiry, revocation, rate limits and response minimization. Possession gives only the intended delivery audience projection, not generic query access. Contact numbers may use server-mediated masking/provider link; raw secrets never enter logs/events. Administrative sensitive read/export has purpose and audit event.

## Asset security and privacy

Separate storage buckets/purposes for POD, message media, imports/exports and verification. Identity documents/live face and financial method references have stricter access than ordinary delivery proof. Server allocates keys, validates type/size/hash, scans general attachments and issues short-lived read/upload capabilities. Do not log signed URLs. Revoke future access when relationship/retention changes; already downloaded copies cannot be technically recalled and should be covered by handling policy.

Local Driver evidence is encrypted/protected and bound to principal. Another account cannot unlock it. Loss of auth does not erase pending physical evidence; secure recovery is required. Device revocation prevents future server activity; local key lifecycle/deletion must preserve incident recovery under approved policy.

ADR-Q05's operator draft/attempt journal is separate: bounded sessionStorage text and exact ResolveIssue bytes, scoped to API origin/principal/tenant/city/date and a verified host login lifetime. Do not store bearer tokens, returned report projections, allowed actions or media capabilities. Hydrate only after a fresh authorized scoped query. Clear login-owned journals on Auth teardown, report failures, and never clear unrelated storage. Ordinary drawer unmount preserves drafts; unknown result remains frozen and status-first after reopen. Same-origin scripts can read sessionStorage: this is not encrypted at-rest storage or an XSS boundary. Actual browser CSP/storage denial, logout/login rotation and lifecycle tests remain activation requirements. No existing Driver/legacy evidence store or pending media is changed.

ADR-M03's upload-only grant binds original staging key/MIME/size/hash and deployment audience for four minutes. It cannot read objects, write sealed evidence or complete delivery. Direct Storage access for anon/authenticated users must be denied on dedicated buckets; keys remain server-only. Metadata checks do not certify RLS. Expiry bounds an existing grant while original device/job authorization still gates verification/commands. Test private policies, query redaction at Node and proxy, create-only collision recovery and bounded cancellation before activation. This is not a retention duration or permission to purge.

## Retention and deletion

Define category, purpose, subject references, owner, retention period, hold exceptions, purge method and export rule before production. Raw GPS short-lived; reviewed derived trail only where justified. POD, contacts/messages, identity evidence, financial records and auth/access audit have different classes. Exact lawful periods are not invented here; production configuration requires approved retention policy reference and numeric duration. Until approved, production use of the affected data class is gated—not retained forever by default.

Deletion job checks open custody/dispute/retention holds, performs scoped redaction/anonymization/object purge and records non-PII completion audit. Avoid breaking referential integrity by deleting a driver ID with operational history. Privacy request workflow verifies subject/authority, gathers scoped data, distinguishes multiple tenant roles and retains decision/evidence. Cross-border Singapore processing and controller/processor roles need the business's privacy review; this document does not certify compliance.

## Threat and acceptance matrix

Test tenant/city IDOR, JWT claim forgery, revoked membership, forged receiving actor, wrong-driver offer response, signed URL reuse/cross-purpose upload, webhook signature/replay, stored XSS through notes, CSV formula injection, unsafe file parsing, OTP abuse, command payload reuse with changed hash, stale offline overwrite and SQL role bypass. Rate limits protect enumeration/ingest/AI cost while preserving active-driver recovery. Secrets rotate through managed secret storage; source control/sample HTML credentials are not production secret management.

Logs and tracing use IDs/codes, not full addresses, bank details, message bodies or raw photos. Security monitoring must not become unbounded duplicate PII retention. Backups/object copies obey the documented recovery/retention posture and access policy.



## Tracking identity and active authorization

A tenant-visible tracking grant references the same tenant, driver and collection entitlement through a composite foreign key. A work guard validates matching started shift or accepted Round/trip and bounds the grant within collection permission. Global opt-in/discovery entitlements may have no tenant; those cannot unlock merchant location reads. Recovery retains historic evidence and does not grant fresh live GPS access.

Read predicates check both grant and backing collection entitlement, including time windows/revocation. Driver may read their own collection entitlement; operator sees only grant-authorized context. Work end/withdrawal revokes grants transactionally. Realtime delivery and refetch require current permission; the Supabase active-session behavior is a deployment test, not proven by SQL text.

## Private notification fanout and identity columns

rounds_api can select its recipient-scoped inbox and update read_at; it cannot insert arbitrary notifications or delete rows. rounds_notifications is a service-only role that inserts event-bound tenant notifications for eligible members/assigned drivers and keeps original service attribution. Validate entity-specific audience before enqueue; database event/tenant/recipient checks are a second boundary. Duplicate identity is constrained. No tenant-wide normal-user inbox read is restored.

Dispatcher principal labels use column grants for id/display_name/preferred_locale, not auth_subject or disabled_at. Device health is a sanitized DriverConnectionView, not driver_devices access. Authentication identity resolver has its own NOLOGIN/NOBYPASSRLS owner, narrow column grants and explicit auth.uid()-scoped FORCE-RLS policy; superuser ownership is not assumed.

For the TypeScript API, isolated migration0002 supplies a separate rounds_api_auth_resolver with id/auth_subject/disabled_at/archived_at SELECT only. rounds.api_principal_id() returns only the active principal for a transaction-local Auth-server-verified subject. Neither the resolver role nor sensitive columns are granted to the API login. The Supabase auth.uid() resolver remains separate and unchanged. Recheck identity, device epoch/revocation, membership/city and original job on command, replay and status. Device-row permission locks precede membership and command locks; a revocation writer must not acquire a global driver lock before that device row. Cross-handler revocation races remain in the release suite.

An ADR-A01 device capability is server-issued, signed and expiring; a raw device ID/header does not prove possession. ADR-A02's explicit authenticated enrollment/refresh requires a cryptographically random installation secret, stores only its principal-bound digest, and denies revival of revoked/archived installations. Neither the secret nor bearer/capability appears in account security audit, command receipts, events or logs. Registration/first revoke are atomic with private account audit; failed audit rolls back and uncertain commit retries preserve installation identity. Existing legacy keys are not backfilled or relabeled by migration0003. No local evidence is deleted.

The isolated registration tests use real SQL/HTTP and the actual registration service, with upstream Auth responses still mocked. They are separate from older seeded-device tests and do not prove configured Supabase session revocation or native secure persistence. Encrypted phone storage, tested old-queue upgrade and real provider verification remain mandatory before activation. Account-wide compromise requires Auth/account-level revocation; installation possession is not hardware attestation. Disabled/archived principals and revoked/archived/changed-epoch devices fail before receipt disclosure. Result lookup rechecks the recorded original assignment and never substitutes a caller-selected active job.

## Raw GPS retention and holds

Raw history requires configured raw_gps_seconds between 3600 and 2592000 as engineering bounds, not a legal recommendation. Ingest snapshots expires_at; absent valid policy disables new raw-history capture while scoped current-position operation can continue. Extending policy does not silently extend existing expiry. Approved legal/operational hold specifies driver and observation interval and blocks deletion until explicitly released.

purge_expired_gps accepts bounded batch size and run ID; selects only server-expired unheld samples; serializes against hold changes; deletes under dedicated retention owner and appends immutable count audit. Raw UPDATE remains prohibited. No user/dispatcher role can execute it or become the retention role. A repeated successful run ID returns its recorded result. Transaction failure rolls back both deletion and audit. Test holds, concurrent insertion, expiry and unauthorized delete before deployment.

### QA-SYSTEM-TRANSFER-ACTOR

Actor: Authorized actor for InitiateTransfer,ConfirmTransferReceipt; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: S proposes LQ5 to N; S attempts destination confirmation..

Then: S gets TRANSFER_NOT_AUTHORIZED/NOT_AUTHORIZED; target balance0. N receives5 once; balances S0,N5..

Status: written requirement; application execution pending.

### QA-SYSTEM-TRACKING-REVOKE

Actor: Authorized actor for RevokeTrackingLink,ExchangeTrackingToken; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: Exchange buyer link, revoke it, then fetch with old session..

Then: HTTP410 TRACKING_REVOKED and zero delivery details; old session cannot continue to read..

Status: written requirement; application execution pending.

### QA-SYSTEM-RLS-CROSS-TENANT

Actor: Authorized actor for SQL SELECT/UPDATE; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: Use rounds_api with verified A context to select/update known B delivery/media/chat IDs. Repeat receipt SELECT/INSERT for the same actor in two tenants, then two authorized cities of one tenant; revoke the original city grant and request original command status/replay.

Then: SELECT0 rows; UPDATE0 rows or policy error; no cross-tenant/city result. Receipt raw SQL is isolated as well as the status endpoint. Revoked scope denies replay/status. Pool reuse after commit/rollback restores no actor/tenant/city scope. Repeat with missing context:0 rows.

Status: written requirement; application execution pending.

### QA-SYSTEM-REALTIME-REVOKE

Actor: Authorized actor for revoke grant; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: OA subscribes A topic then loses city entitlement..

Then: Future subscription denied; current session disconnected/revalidated within60s; no authorized refetch after revoke..

Status: written requirement; application execution pending.

### QA-V21-DRIVER-VISIBILITY

Actor: OA / OB / S.

Given: A owns active team relationship to S; B does not.

When: As OA read S profile; as OB read same ID; as S read self.

Then: OA and S can read permitted profile; OB receives no row; no broad broker board query.

Status: written requirement; application execution pending.

### QA-V21-GPS-WINDOW

Actor: OA / OB.

Given: S location bound to collection entitlement TE1; tenant read grant GA expires 10:00.

When: At 09:00 query exact point as OA; switch B; revoke GA; restore grant with observed point older than starts_at.

Then: Only first query returns point; wrong tenant, revoked grant and pre-window observation return no point.

Status: written requirement; application execution pending.

### QA-V21-INBOX-PRINCIPAL

Actor: OA / OH.

Given: Two notifications in A: one for OA, one OH.

When: OA selects and tries marking OH notification.

Then: No OH row visible or mutable; own notification remains usable.

Status: written requirement; application execution pending.

### QA-V21-REALTIME-IDENTITY

Actor: authenticated S.

Given: S principal UUID differs from auth_subject; one unexpired topic grant.

When: Resolve auth principal; authorize correct topic; revoke; issue new grant for same topic. For the API identity boundary also exercise differing auth/principal UUIDs, disabled/archived identity, tampered/expired/wrong-actor device capability, changed device epoch, revoked device, membership/city revocation and reassigned original pickup status. Register through the authenticated device endpoint, lose its commit response, retry the same secret, race identical enrollments and refresh/revoke, force audit failure, exceed principal registration rate, then use the issued capability for pickup/status and revoke it.

Then: Correct subject maps to S; revoked grant denied; replacement inserts successfully; no duplicate live grant. API invalid identity/device/job scope exposes no result and creates no new custody; dispatcher/API cannot read auth_subject or disabled_at. Registration retries produce one device/registration audit; audit failure produces neither. Refresh preserves identity and revoked installation never revives; unrelated principals cannot refresh/revoke it. Rate bound does not prevent existing-device refresh/revoke. Enrollment grants no tenant/job/tracking authority. Device credentials and installation hashes are absent from receipts/audit/events/logs. Legacy rows, original fences and photos are preserved. Provider/topic, native storage and API database tests have separate evidence.

Status: written requirement; application execution pending.
