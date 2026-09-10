# Error and retained-outcome contract — V2.3

Each command binds allowed errors in OpenAPI x-errors and COMMAND-CATALOG. A business rejection rolls back all operational mutations; original command result is retained for idempotent replay. Common authentication/context/validation errors may be enforced before a domain transaction. Query errors are separately listed in QUERY-ERRORS.json.

| Database condition | API meaning |
| --- | --- |
| Named unique active unit claim / accepted broadcast winner | CLAIM_TAKEN; inspect named constraint, not every unique error |
| Driver/vehicle interval exclusion | DRIVER_CONFLICT / VEHICLE_CONFLICT according to constraint |
| Manifest/header/line ownership mismatch | MANIFEST_MISMATCH |
| Sealed manifest/package, changed immutable evidence/accepted scope | IMMUTABLE_RECORD |
| Unit allocation or physical receipt exceeds available quantity | QUANTITY_EXCEEDED |
| Invalid agreement revision sequence / pointer | INVALID_REVISION |
| Invalid tracking entitlement/driver/work scope | TRACKING_GRANT_INVALID |
| Same command ID with different canonical payload | IDEMPOTENCY_CONFLICT |
| Unknown check/foreign key/constraint failure | VALIDATION_FAILED with sanitized field/constraint reason; never leak SQL or private IDs |

Normalize named invariant failures to SQLSTATE 23514 where explicitly raised; built-in unique/FK/exclusion SQLSTATEs remain their native values. Map by named constraint/error token, never by matching arbitrary provider text. Unspecified P0001 messages are sanitized VALIDATION_FAILED and recorded internally.

PHYSICAL_INCOMPATIBILITY is cargo/handling suitability. VEHICLE_CONFLICT is time overlap. UNSUPPORTED_PROFILE is a provider/profile capability gate. They are distinct conditions. Address review failure is ADDRESS_REVIEW_REQUIRED at both StartBroadcast and ReleasePlan.

Genuine stale physical observations are retained, not silently discarded as ordinary STALE_VERSION. A retained response carries incident identity and preserves the historical assignment fence; it does not authorize current work. RetainOfflineObservations accepts unresolved local chains without inventing server attempt IDs. EVIDENCE_RETAINED is retained-outcome classification, not an instruction to resend a rejected proof forever.
