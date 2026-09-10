# W01 — private POD provider connection

Version 1.0 · 2026-09-09 · Implemented locally; configured cloud/phone acceptance NOT_RUN.

## Changelog

- 1.0 (2026-09-09): implement ADR-M03 Supabase REST adapter, finite signed-PUT gateway and default-off runtime selection. Preserve existing data, endpoints and UI.

## Code and compatibility

Baseline: `19d6c1e7dc570546026cfb41135fae74c6b4e23e`. Current hashes/results: [checkpoint evidence](generated/test-results.json).

- [Supabase adapter](../../services/api/src/v23/supabase-pod-storage.ts): private bucket checks, bounded authenticated reads, create-only upload/seal and exact reread; sanitized failures.
- [Capability signer](../../services/api/src/v23/pod-upload-capability.ts): four-minute purpose/audience/key/MIME/size/hash-bound grant; no provider credential on phone.
- [Runtime](../../services/api/src/v23/runtime.ts): explicit isolated/local provider selection feeds ReserveAsset, VerifyAsset and status hydration.
- [Node ingress](../../services/api/src/v23/node-boundary.ts): separate20MiB raw image path, two upload slots, deadline/disconnect handling and capability-query redaction. Commands remain1MiB.

No new schema/OpenAPI command/dependency, source UI, Thai implementation, legacy endpoint rewrite or installed-client switch. Existing native signed-PUT adapter is reused unchanged. Upload acknowledgment never replaces server VerifyAsset, SubmitProof or CompleteDelivery. Photos and staged/sealed objects are retained, never overwritten/deleted for recovery.

## Later isolated configuration — not enabled by this checkpoint

Use a dedicated development account/project and synthetic evidence. Do not paste secrets into chat or commit populated configuration. Provider selection requires existing ROUNDS_V23_HTTP_MODE=isolated, APP_ENV=local and a loopback restricted command DB.

| Variable | Explicit input |
| --- | --- |
| ROUNDS_V23_POD_MODE | supabase; absent/disabled stays unavailable |
| ROUNDS_V23_POD_STORAGE_ORIGIN | HTTPS Supabase origin without path/query/redirect |
| ROUNDS_V23_POD_SERVICE_KEY | Server-only credential, no legacy fallback |
| ROUNDS_V23_POD_STAGING_BUCKET | Dedicated private create-only staging bucket |
| ROUNDS_V23_POD_VERIFIED_BUCKET | Different private server-write-only evidence bucket |
| ROUNDS_V23_POD_UPLOAD_ORIGIN | HTTPS origin routing the upload gateway to this API |
| ROUNDS_V23_POD_SIGNING_KEY_ID / ROUNDS_V23_POD_SIGNING_KEY | Dedicated key ID and random32byte lowercase hex secret, different from device key |
| ROUNDS_V23_POD_RETENTION_CLASS | Explicit class identifier; no invented production duration |

Buckets must already exist: public=false, file_size_limit at most20MiB and sufficient for the photo, allowed_mime_types exactly image/png and image/jpeg. Independently review/test RLS: direct anon/authenticated select/insert/update/delete denied, sealed writes server-only. Metadata does not prove policy. Configure HTTPS/proxy query redaction, time/rate bounds, credential rotation and approved retention/restore. No code here creates buckets, grants privileges, alters shared configuration or purges media.

## Evidence and remaining gates

[Adapter tests](../../services/api/test/v23/supabase-pod-storage.test.ts) use a labelled [Supabase REST double](../../services/api/test/v23/supabase-storage-fixture.ts), not cloud Storage. Cover private buckets, capabilities/expiry/alteration/audience, hash/type/header denial, create-only collisions, lost response, redirects/abort and bounded streams plus actual local Node ingress. [PostGIS tests](../../services/api/test/v23/pod-assets.postgis.ts) run actual registration/arrival/pickup/handoff, this adapter/gateway, verification, proof and completion under restricted SQL. Assert no IO under SQL locks, capabilities absent from receipts and both evidence copies retained. See generated run statuses; ready does not mean accepted.

NOT_RUN: configured Supabase policies/credentials/proxy, live interrupted upload/replay/expiry, retention/restore, physical-phone TLS/weak-network/OS recovery and screenshot parity. Signatures, multiple-photo/candidate/branched native flows and approved English UI remain separate. Next: authorized isolated provider fixture and approved English route binding. No shared migration, installation, deployment or push.
