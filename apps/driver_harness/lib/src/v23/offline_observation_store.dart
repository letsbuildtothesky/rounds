part of 'encrypted_work_store.dart';

/// Internal snapshot supplied by the authenticated work-query adapter. Validation
/// here is local integrity, NOT proof of remote authorization/release/readiness.
/// Never construct this by filling missing fields from legacy DriverStop data.
class ExecutionCaptureContext {
  ExecutionCaptureContext._(this._json);
  final String _json;

  factory ExecutionCaptureContext.fromJson(Map<String, Object?> input) {
    final encoded = _freezeJson(input);
    final value = jsonDecode(encoded) as Map<String, dynamic>;
    _exactKeys(value, const {
      'principal_id',
      'tenant_id',
      'city_id',
      'round_id',
      'assignment_id',
      'assignment_version',
      'accepted_scope_hash',
      'stop_units',
      'expected_versions',
      'proof_policy',
      'fetched_at',
    });
    for (final field in [
      'principal_id',
      'tenant_id',
      'city_id',
      'round_id',
      'assignment_id',
    ]) {
      _requireId(value[field]);
    }
    _requireVersion(value['assignment_version']);
    if (value['accepted_scope_hash'] is! String ||
        (value['accepted_scope_hash'] as String).length != 64 ||
        !RegExp(
          r'^[a-f0-9]{64}$',
        ).hasMatch(value['accepted_scope_hash'] as String)) {
      _invalidObservation();
    }
    _requireInstant(value['fetched_at']);
    final pairs = value['stop_units'];
    if (pairs is! Map || pairs.isEmpty || pairs.length > 1000) {
      _invalidObservation();
    }
    for (final entry in pairs.entries) {
      _requireId(entry.key);
      final units = entry.value;
      if (units is! List ||
          units.isEmpty ||
          units.length > 1000 ||
          units.toSet().length != units.length) {
        _invalidObservation();
      }
      for (final unit in units) {
        _requireId(unit);
      }
    }
    if (value['proof_policy'] is! Map) _invalidObservation();
    final versions = value['expected_versions'];
    if (versions is! List || versions.isEmpty || versions.length > 1000) {
      _invalidObservation();
    }
    final roots = <String>{};
    for (final root in versions) {
      if (root is! Map<String, dynamic>) _invalidObservation();
      _exactKeys(root, const {'aggregate_type', 'id', 'version'});
      _requireId(root['id']);
      _requireVersion(root['version']);
      final type = root['aggregate_type'];
      if (type is! String ||
          RegExp(r'^[a-z_]{1,64}$').stringMatch(type) != type ||
          !roots.add('$type:${root['id']}')) {
        _invalidObservation();
      }
    }
    // Prevent two competing assignment versions inside a single capture context.
    final assignment = versions
        .where((r) => r['aggregate_type'] == 'assignments')
        .toList();
    if (assignment.length != 1 ||
        assignment.single['id'] != value['assignment_id'] ||
        assignment.single['version'] != value['assignment_version']) {
      _invalidObservation();
    }
    return ExecutionCaptureContext._(encoded);
  }

  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  @override
  String toString() => 'ExecutionCaptureContext(redacted)';
}

/// Immutable observation intent, not a materialized command or server receipt.
class LocalObservationDraft {
  LocalObservationDraft._(this._json);
  final String _json;

  factory LocalObservationDraft({
    required String observationId,
    required String assignmentId,
    required int assignmentVersion,
    required String kind,
    required String stopId,
    required String fulfillmentUnitId,
    required DateTime observedAt,
    required Map<String, Object?> observedPayload,
    List<String> predecessorObservationIds = const [],
  }) {
    for (final id in [observationId, assignmentId, stopId, fulfillmentUnitId]) {
      _requireId(id);
    }
    _requireVersion(assignmentVersion);
    if (!{
          'pickup',
          'arrival',
          'handoff',
          'proof',
          'completion',
          'issue',
        }.contains(kind) ||
        !observedAt.isUtc ||
        predecessorObservationIds.length > 1000 ||
        predecessorObservationIds.toSet().length !=
            predecessorObservationIds.length ||
        predecessorObservationIds.contains(observationId)) {
      _invalidObservation();
    }
    for (final id in predecessorObservationIds) {
      _requireId(id);
    }
    _requireInstant(observedAt.toIso8601String());
    return LocalObservationDraft._(
      _freezeJson({
        'observation_id': observationId,
        'assignment_id': assignmentId,
        'assignment_version': assignmentVersion,
        'kind': kind,
        'stop_id': stopId,
        'fulfillment_unit_id': fulfillmentUnitId,
        'observed_at': observedAt.toIso8601String(),
        'observed_payload': observedPayload,
        'predecessor_observation_ids': predecessorObservationIds,
      }),
    );
  }

  @override
  String toString() => 'LocalObservationDraft(redacted)';
}

/// One fresh JPEG/PNG capture. The caller owns source bytes; this private copy
/// can be explicitly wiped. A stable ID is supplied before recording/retrying.
class ObservationPhoto {
  ObservationPhoto._(this.assetId, this.mimeType, this._bytes);
  factory ObservationPhoto({
    required String assetId,
    required String mimeType,
    required Uint8List bytes,
  }) {
    if (!isDeviceUuid(assetId) ||
        assetId != assetId.toLowerCase() ||
        !{'image/jpeg', 'image/png'}.contains(mimeType) ||
        bytes.isEmpty ||
        bytes.length > EncryptedDriverStore.maxEvidenceBytes) {
      throw const EncryptedStoreException('INVALID_EVIDENCE');
    }
    return ObservationPhoto._(assetId, mimeType, Uint8List.fromList(bytes));
  }
  final String assetId, mimeType;
  final Uint8List _bytes;
  bool _disposed = false;
  void dispose() {
    _disposed = true;
    _bytes.fillRange(0, _bytes.length, 0);
  }

  @override
  String toString() => 'ObservationPhoto(redacted)';
}

class StoredObservation {
  StoredObservation._(this._json, this.state);
  final String _json;

  /// Only local_recorded / needs_recovery. Never uploaded/verified/delivered.
  final String state;
  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  String get observationId => toJson()['observation_id'] as String;
  @override
  String toString() => 'StoredObservation($state)';
}

extension _ObservationPersistence on EncryptedDriverStore {
  ExecutionCaptureContext _acceptOnlineContext(
    ExecutionCaptureContext context,
  ) {
    final value = context.toJson();
    if (value['principal_id'] != _device.principalId) {
      throw const EncryptedStoreException('CONTEXT_OWNER_MISMATCH');
    }
    final rows = _db.select(
      "SELECT c.projection_json,f.invalidated_at FROM work_cache c JOIN execution_fences f ON f.principal_id=c.principal_id AND c.entity_id=f.assignment_id||':'||f.assignment_version WHERE c.principal_id=? AND c.entity_type='execution_capture_context_v1'",
      [_device.principalId],
    );
    ExecutionCaptureContext? original;
    final invalidate = <Map<String, dynamic>>[];
    for (final row in rows) {
      final old =
          jsonDecode(row['projection_json'] as String) as Map<String, dynamic>;
      if (old['tenant_id'] != value['tenant_id'] ||
          old['city_id'] != value['city_id'] ||
          old['round_id'] != value['round_id']) {
        continue;
      }
      if (old['assignment_id'] == value['assignment_id'] &&
          old['assignment_version'] == value['assignment_version']) {
        if (row['invalidated_at'] != null) {
          throw const EncryptedStoreException('EXECUTION_CONTEXT_INVALIDATED');
        }
        String authority(Map<String, dynamic> c) => _freezeJson(
          Map<String, Object?>.of(c)
            ..remove('fetched_at')
            ..remove('expected_versions'),
        );
        if (authority(old) != authority(value)) {
          _commit(
            () => _db.execute(
              'UPDATE execution_fences SET invalidated_at=COALESCE(invalidated_at,?) WHERE principal_id=? AND assignment_id=? AND assignment_version=?',
              [
                value['fetched_at'],
                _device.principalId,
                old['assignment_id'],
                old['assignment_version'],
              ],
            ),
          );
          throw const EncryptedStoreException('CONTEXT_ID_CONFLICT');
        }
        original = ExecutionCaptureContext.fromJson(old);
      } else {
        if (old['assignment_id'] == value['assignment_id'] &&
            (old['assignment_version'] as int) >
                (value['assignment_version'] as int)) {
          throw const EncryptedStoreException('EXECUTION_CONTEXT_INVALIDATED');
        }
        invalidate.add(old);
      }
    }
    // Invalidate obsolete authority before exposing the new snapshot. A crash
    // preserves observations and may require retry, never silent reactivation.
    _commit(() {
      for (final old in invalidate) {
        _db.execute(
          'UPDATE execution_fences SET invalidated_at=COALESCE(invalidated_at,?) WHERE principal_id=? AND assignment_id=? AND assignment_version=?',
          [
            value['fetched_at'],
            _device.principalId,
            old['assignment_id'],
            old['assignment_version'],
          ],
        );
      }
    });
    if (original != null) return original;
    _cacheContext(context);
    return context;
  }

  Map<String, Object?>? _observationRow(String id) {
    _active();
    final rows = _db.select(
      'SELECT * FROM local_observations WHERE observation_id=? AND principal_id=?',
      [id, _device.principalId],
    );
    return rows.isEmpty ? null : Map.of(rows.single);
  }

  void _cacheContext(ExecutionCaptureContext context) {
    final value = context.toJson();
    if (value['principal_id'] != _device.principalId) {
      throw const EncryptedStoreException('CONTEXT_OWNER_MISMATCH');
    }
    final id = '${value['assignment_id']}:${value['assignment_version']}';
    final existing = _db.select(
      "SELECT projection_json FROM work_cache WHERE principal_id=? AND entity_type='execution_capture_context_v1' AND entity_id=?",
      [_device.principalId, id],
    );
    if (existing.isNotEmpty) {
      if (existing.single['projection_json'] != context._json) {
        throw const EncryptedStoreException('CONTEXT_ID_CONFLICT');
      }
      return; // No refresh, reactivation or overwriting original timestamps.
    }
    _commit(() {
      _db.execute(
        'INSERT INTO execution_fences (principal_id,assignment_id,assignment_version,accepted_scope_hash,cached_at) VALUES (?,?,?,?,?)',
        [
          _device.principalId,
          value['assignment_id'],
          value['assignment_version'],
          value['accepted_scope_hash'],
          value['fetched_at'],
        ],
      );
      _db.execute(
        "INSERT INTO work_cache (principal_id,entity_type,entity_id,tenant_id,server_version,projection_json,fetched_at) VALUES (?,'execution_capture_context_v1',?,?,?,?,?)",
        [
          _device.principalId,
          id,
          value['tenant_id'],
          value['assignment_version'],
          context._json,
          value['fetched_at'],
        ],
      );
    });
  }

  Future<StoredObservation> _recordObservation(
    LocalObservationDraft draft,
    ObservationPhoto? photo,
    Uint8List? snapshot, {
    bool previouslyAuthorizedCamera = false,
    String? stagedPickupFormId,
  }) async {
    final intent = jsonDecode(draft._json) as Map<String, dynamic>;
    final observationId = intent['observation_id'] as String;
    final prior = _observationRow(observationId);
    final contexts = _db.select(
      "SELECT c.projection_json,f.invalidated_at FROM work_cache c JOIN execution_fences f ON f.principal_id=c.principal_id AND c.entity_id=f.assignment_id||':'||f.assignment_version WHERE c.principal_id=? AND c.entity_type='execution_capture_context_v1' AND f.assignment_id=? AND f.assignment_version=?",
      [
        _device.principalId,
        intent['assignment_id'],
        intent['assignment_version'],
      ],
    );
    if (contexts.length != 1) {
      throw const EncryptedStoreException('EXECUTION_CONTEXT_MISSING');
    }
    if (prior == null &&
        contexts.single['invalidated_at'] != null &&
        !previouslyAuthorizedCamera) {
      throw const EncryptedStoreException('EXECUTION_CONTEXT_INVALIDATED');
    }
    final context =
        jsonDecode(contexts.single['projection_json'] as String)
            as Map<String, dynamic>;
    final units = (context['stop_units'] as Map)[intent['stop_id']];
    if (units is! List ||
        !units.contains(intent['fulfillment_unit_id']) ||
        DateTime.parse(
          intent['observed_at'] as String,
        ).isBefore(DateTime.parse(context['fetched_at'] as String))) {
      throw const EncryptedStoreException('OBSERVATION_OUTSIDE_CONTEXT');
    }
    final photoRow = photo == null
        ? null
        : <String, Object?>{
            'asset_id': photo.assetId,
            'principal_id': _device.principalId,
            'purpose_entity_id': intent['fulfillment_unit_id'],
            'purpose_kind': intent['kind'],
            'local_private_path': 'media/${photo.assetId}.sealed',
            'sha256': hash.sha256.convert(snapshot!).toString(),
            'byte_size': snapshot.length,
            'mime_type': photo.mimeType,
            'captured_at': intent['observed_at'],
          };
    final envelope = _freezeJson(
      {
        'format': 1,
        ...intent,
        'principal_id': _device.principalId,
        'device_id': _device.deviceId,
        'session_epoch': _device.epoch,
        'execution_context': context,
        'assets': [?photoRow],
      },
      maxBytes: 192 * 1024,
      maxDepth: 20,
    );
    if (prior != null && prior['payload_json'] != envelope) {
      throw const EncryptedStoreException('OBSERVATION_ID_CONFLICT');
    }
    for (final id in intent['predecessor_observation_ids'] as List) {
      final row = _observationRow(id as String);
      if (row == null) {
        throw const EncryptedStoreException('OBSERVATION_DEPENDENCY_MISSING');
      }
      final parent = jsonDecode(row['payload_json'] as String) as Map;
      if (parent['assignment_id'] != intent['assignment_id'] ||
          parent['assignment_version'] != intent['assignment_version'] ||
          DateTime.parse(
            parent['observed_at'] as String,
          ).isAfter(DateTime.parse(intent['observed_at'] as String))) {
        throw const EncryptedStoreException('OBSERVATION_DEPENDENCY_MISMATCH');
      }
    }
    void insert() => _db.execute(
      'INSERT INTO local_observations (observation_id,principal_id,kind,entity_id,payload_json,observed_at,session_epoch) VALUES (?,?,?,?,?,?,?)',
      [
        observationId,
        _device.principalId,
        intent['kind'],
        intent['fulfillment_unit_id'],
        envelope,
        intent['observed_at'],
        _device.epoch,
      ],
    );
    if (photo != null && stagedPickupFormId != null) {
      _requireStagedFormBinding(stagedPickupFormId, intent, photoRow!);
      // The form camera saved these exact encrypted bytes before submit. Only
      // this private, validated binding may attach an already-existing asset.
      final bytes = await _decrypt(_row(photo.assetId)!);
      bytes.fillRange(0, bytes.length, 0);
      if (prior == null) _commit(insert);
    } else if (photo != null) {
      if (prior == null && _row(photo.assetId) != null) {
        throw const EncryptedStoreException('OBSERVATION_ASSET_CONFLICT');
      }
      if (prior != null && _row(photo.assetId) == null) {
        throw const EncryptedStoreException('OBSERVATION_REQUIRES_RECOVERY');
      }
      await _persistEvidence(
        assetId: photo.assetId,
        purposeKind: intent['kind'] as String,
        purposeEntityId: intent['fulfillment_unit_id'] as String,
        mimeType: photo.mimeType,
        capturedAt: DateTime.parse(intent['observed_at'] as String),
        snapshot: snapshot!,
        insertObservation: prior == null ? insert : null,
      );
    } else if (prior == null) {
      _commit(insert);
    }
    await _boundary('observation_committed');
    return _inspectObservation(_observationRow(observationId)!);
  }

  Future<StoredObservation> _inspectObservation(
    Map<String, Object?> row,
  ) async {
    final encoded = row['payload_json'] as String;
    final value = jsonDecode(encoded) as Map<String, dynamic>;
    if (value['format'] != 1 ||
        value['principal_id'] != _device.principalId ||
        value['observation_id'] != row['observation_id'] ||
        value['session_epoch'] != row['session_epoch']) {
      throw const EncryptedStoreException('OBSERVATION_REQUIRES_RECOVERY');
    }
    var state = 'local_recorded';
    for (final metadata in value['assets'] as List) {
      final asset = _row(metadata['asset_id'] as String);
      if (asset == null ||
          asset['state'] != 'saved' ||
          EncryptedDriverStore._aad(asset) !=
              EncryptedDriverStore._aad(
                Map<String, Object?>.from(metadata as Map),
              )) {
        state = 'needs_recovery';
        continue;
      }
      try {
        final plain = await _decrypt(asset);
        plain.fillRange(0, plain.length, 0);
      } on EncryptedStoreException catch (error) {
        if (!{
          'EVIDENCE_MISSING',
          'EVIDENCE_AUTHENTICATION_FAILED',
          'UNSAFE_STORAGE_PATH',
        }.contains(error.code)) {
          rethrow;
        }
        state = 'needs_recovery';
      }
    }
    _active();
    return StoredObservation._(encoded, state);
  }
}

Never _invalidObservation() =>
    throw const EncryptedStoreException('INVALID_OBSERVATION');
void _requireId(Object? id) {
  if (id is! String || !isDeviceUuid(id) || id != id.toLowerCase()) {
    _invalidObservation();
  }
}

void _requireVersion(Object? value) {
  if (value is! int || value < 1 || value > 9007199254740991) {
    _invalidObservation();
  }
}

void _requireInstant(Object? value) {
  if (!isDeviceInstant(value)) {
    _invalidObservation();
  }
}

void _exactKeys(Map<String, dynamic> value, Set<String> keys) {
  if (value.length != keys.length || !keys.every(value.containsKey)) {
    _invalidObservation();
  }
}

String _freezeJson(
  Object? input, {
  int maxBytes = 64 * 1024,
  int maxDepth = 16,
}) {
  var nodes = 0;
  Object? copy(Object? value, int depth) {
    if (++nodes > 20000 || depth > maxDepth) _invalidObservation();
    if (value == null || value is bool) return value;
    if (value is String) {
      if (value.length > maxBytes) _invalidObservation();
      return value;
    }
    if (value is num && value.isFinite) return value;
    if (value is List) return value.map((v) => copy(v, depth + 1)).toList();
    if (value is Map) {
      if (value.keys.any((k) => k is! String || k.length > maxBytes)) {
        _invalidObservation();
      }
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: copy(value[key], depth + 1)};
    }
    _invalidObservation();
  }

  final encoded = jsonEncode(copy(input, 0));
  if (utf8.encode(encoded).length > maxBytes) _invalidObservation();
  return encoded;
}
