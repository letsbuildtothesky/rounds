# Security hardening backlog

**Gate:** Complete before real customer data or production pilot activation.

The current development build keeps server secrets out of Git and client bundles, uses authenticated role checks for Slice 1 commands, default-deny database privileges and tenant-scoped server projections. The following intentionally deferred work remains a production gate:

- replace Phase 0 location-ingest publishable-key authorization with authenticated Driver/device authorization;
- restrict location-ingest CORS and return only sanitized client errors;
- add rate limits for authentication, command and telemetry boundaries;
- define and enforce PII, location and evidence retention/deletion policies;
- add audited access paths for sensitive evidence and short-lived media URLs;
- rotate any database credential disclosed during development setup;
- complete abuse-case, cross-tenant, replay and authorization tests;
- run production secret scanning and dependency/security review in release CI.

Until this gate is complete, use synthetic development records only.
