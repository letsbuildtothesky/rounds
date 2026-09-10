-- Proposed Flutter SQLite working store. Not a server authority.
-- Encryption/key management and OS file protection are required integration work.
PRAGMA foreign_keys = ON;
PRAGMA user_version = 2;
CREATE TABLE account_context (
 principal_id TEXT PRIMARY KEY, device_id TEXT NOT NULL, session_epoch INTEGER NOT NULL,
 schema_version INTEGER NOT NULL DEFAULT 1, locked INTEGER NOT NULL DEFAULT 0 CHECK(locked IN(0,1)),
 last_authenticated_at TEXT, created_at TEXT NOT NULL
);
CREATE TABLE work_cache (
 principal_id TEXT NOT NULL REFERENCES account_context(principal_id), entity_type TEXT NOT NULL,
 entity_id TEXT NOT NULL, tenant_id TEXT, server_version INTEGER NOT NULL CHECK(server_version>=0),
 projection_json TEXT NOT NULL CHECK(json_valid(projection_json)), fetched_at TEXT NOT NULL, expires_at TEXT,
 PRIMARY KEY(principal_id,entity_type,entity_id)
);
CREATE TABLE pending_commands (
 command_id TEXT PRIMARY KEY, principal_id TEXT NOT NULL REFERENCES account_context(principal_id),
 tenant_id TEXT, command_type TEXT NOT NULL, payload_json TEXT NOT NULL CHECK(json_valid(payload_json)),
 request_hash TEXT NOT NULL, expected_versions_json TEXT NOT NULL CHECK(json_valid(expected_versions_json)),
 occurred_at TEXT NOT NULL, queued_at TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN('queued','blocked','sending','unknown','committed','rejected','retained_for_review','needs_review')),
 attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts>=0), next_retry_at TEXT, error_code TEXT, server_receipt_json TEXT
);
CREATE TABLE command_dependencies (
 command_id TEXT NOT NULL REFERENCES pending_commands(command_id),
 depends_on_command_id TEXT NOT NULL REFERENCES pending_commands(command_id),
 PRIMARY KEY(command_id,depends_on_command_id), CHECK(command_id<>depends_on_command_id)
);
CREATE TABLE local_assets (
 asset_id TEXT PRIMARY KEY, principal_id TEXT NOT NULL REFERENCES account_context(principal_id),
 purpose_entity_id TEXT NOT NULL, purpose_kind TEXT NOT NULL, local_private_path TEXT NOT NULL UNIQUE,
 sha256 TEXT NOT NULL, byte_size INTEGER NOT NULL CHECK(byte_size>=0), mime_type TEXT NOT NULL,
 captured_at TEXT NOT NULL, state TEXT NOT NULL CHECK(state IN('capturing','saved','uploading','uploaded','verified','needs_recovery','invalidated')),
 server_asset_id TEXT, verified_at TEXT, retention_due_at TEXT
);
CREATE TABLE upload_sessions (
 session_id TEXT PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES local_assets(asset_id),
 upload_capability_secret_ref TEXT NOT NULL, offset_bytes INTEGER NOT NULL DEFAULT 0 CHECK(offset_bytes>=0),
 expires_at TEXT NOT NULL, state TEXT NOT NULL CHECK(state IN('active','expired','completed','unknown','failed')),
 provider_receipt_json TEXT, updated_at TEXT NOT NULL
);
CREATE TABLE draft_messages (
 client_message_id TEXT PRIMARY KEY, principal_id TEXT NOT NULL REFERENCES account_context(principal_id),
 tenant_id TEXT NOT NULL, conversation_id TEXT NOT NULL, text_body TEXT,
 attachment_ids_json TEXT NOT NULL CHECK(json_valid(attachment_ids_json)),
 command_id TEXT REFERENCES pending_commands(command_id), updated_at TEXT NOT NULL
);
CREATE TABLE local_observations (
 observation_id TEXT PRIMARY KEY, principal_id TEXT NOT NULL REFERENCES account_context(principal_id),
 kind TEXT NOT NULL, entity_id TEXT, payload_json TEXT NOT NULL CHECK(json_valid(payload_json)),
 observed_at TEXT NOT NULL, session_epoch INTEGER NOT NULL,
 command_id TEXT REFERENCES pending_commands(command_id), reconciled_at TEXT, expires_at TEXT
);
CREATE TABLE sync_cursor (
 principal_id TEXT NOT NULL REFERENCES account_context(principal_id), channel_key TEXT NOT NULL,
 last_event_id TEXT, as_of TEXT NOT NULL, requires_full_fetch INTEGER NOT NULL DEFAULT 0 CHECK(requires_full_fetch IN(0,1)),
 PRIMARY KEY(principal_id,channel_key)
);
CREATE TABLE dead_letters (
 id TEXT PRIMARY KEY, principal_id TEXT NOT NULL REFERENCES account_context(principal_id),
 command_id TEXT REFERENCES pending_commands(command_id), asset_id TEXT REFERENCES local_assets(asset_id),
 reason_code TEXT NOT NULL, recovery_state TEXT NOT NULL, created_at TEXT NOT NULL, resolved_at TEXT,
 CHECK(command_id IS NOT NULL OR asset_id IS NOT NULL)
);
CREATE INDEX pending_due ON pending_commands(state,next_retry_at);
CREATE INDEX observations_pending ON local_observations(principal_id,reconciled_at);
-- Service validates acyclic dependency graph and account ownership for every reference.
-- Secure evidence files cannot be deleted until server verification AND retention policy permit it.
-- Database/asset atomicity uses staged file writes, checksums, fsync where supported and orphan reconciliation.

CREATE TABLE location_buffer (sample_id TEXT PRIMARY KEY, principal_id TEXT NOT NULL REFERENCES account_context(principal_id), observed_at TEXT NOT NULL, latitude REAL NOT NULL CHECK(latitude BETWEEN -90 AND 90), longitude REAL NOT NULL CHECK(longitude BETWEEN -180 AND 180), accuracy_m REAL CHECK(accuracy_m>=0), session_epoch INTEGER NOT NULL, expires_at TEXT NOT NULL, uploaded_at TEXT);
CREATE TABLE command_roots (command_id TEXT NOT NULL REFERENCES pending_commands(command_id), aggregate_type TEXT NOT NULL, aggregate_id TEXT NOT NULL, expected_version INTEGER NOT NULL CHECK(expected_version>=1), PRIMARY KEY(command_id,aggregate_type,aggregate_id));
ALTER TABLE account_context ADD COLUMN encryption_key_reference TEXT;
ALTER TABLE local_assets ADD COLUMN invalidated_at TEXT;
ALTER TABLE local_assets ADD COLUMN invalidated_reason TEXT;
-- Encryption key reference stores a keystore alias, never raw key material. SQL does not encrypt bytes.

CREATE TABLE observation_bindings (
 principal_id TEXT NOT NULL REFERENCES account_context(principal_id), observation_id TEXT NOT NULL REFERENCES local_observations(observation_id),
 dependency_observation_id TEXT NOT NULL REFERENCES local_observations(observation_id), result_pointer TEXT NOT NULL, payload_pointer TEXT NOT NULL,
 resolved_value_json TEXT CHECK(resolved_value_json IS NULL OR json_valid(resolved_value_json)), resolved_by_command_id TEXT,
 PRIMARY KEY(principal_id,observation_id,payload_pointer), CHECK(observation_id<>dependency_observation_id)
);
CREATE TABLE execution_fences (
 principal_id TEXT NOT NULL REFERENCES account_context(principal_id), assignment_id TEXT NOT NULL, assignment_version INTEGER NOT NULL CHECK(assignment_version>0),
 accepted_scope_hash TEXT NOT NULL, cached_at TEXT NOT NULL, invalidated_at TEXT,
 PRIMARY KEY(principal_id,assignment_id,assignment_version)
);
-- Materialize payload_json/request_hash only after required bindings resolve. Thereafter pending_commands bytes are immutable across retries.
