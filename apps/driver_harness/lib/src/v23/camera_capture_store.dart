part of 'encrypted_work_store.dart';

/// Durable intent before opening the OS camera. Not a photo, proof, command,
/// completion or server acknowledgement. Identifiers never expose file paths.
class CameraCaptureIntent {
  CameraCaptureIntent._(
    this.captureId,
    this.assetId,
    this.state, {
    this.isNew = false,
  });
  final String captureId, assetId, state;
  final bool isNew;
  @override
  String toString() => 'CameraCaptureIntent($state)';
}

extension _CameraPersistence on EncryptedDriverStore {
  static const _cameraType = 'camera_capture_intent_v1';

  Map<String, dynamic> _cameraIntent(String id) {
    _requireId(id);
    final rows = _db.select(
      'SELECT projection_json FROM work_cache WHERE principal_id=? AND entity_type=? AND entity_id=?',
      [_device.principalId, _cameraType, id],
    );
    if (rows.length != 1) {
      throw const EncryptedStoreException('CAMERA_INTENT_NOT_FOUND');
    }
    return jsonDecode(rows.single['projection_json'] as String)
        as Map<String, dynamic>;
  }

  CameraCaptureIntent _cameraSummary(Map<String, dynamic> data) =>
      CameraCaptureIntent._(
        data['draft']['observation_id'] as String,
        data['asset_id'] as String,
        data['state'] as String,
      );

  void _cameraState(Map<String, dynamic> data, String state) {
    data['state'] = state;
    _commit(
      () => _db.execute(
        'UPDATE work_cache SET projection_json=? WHERE principal_id=? AND entity_type=? AND entity_id=?',
        [
          _freezeJson(data),
          _device.principalId,
          _cameraType,
          data['draft']['observation_id'],
        ],
      ),
    );
  }

  CameraCaptureIntent _prepareCameraCapture(
    LocalObservationDraft draft,
    String assetId,
  ) {
    _requireId(assetId);
    final intent = jsonDecode(draft._json) as Map<String, dynamic>;
    if (!{'proof', 'issue'}.contains(intent['kind'])) {
      throw const EncryptedStoreException('INVALID_OBSERVATION');
    }
    final id = intent['observation_id'] as String;
    // The UI supplies a stable identity before launch, never after camera IO.
    final existing = _db.select(
      'SELECT projection_json FROM work_cache WHERE principal_id=? AND entity_type=? AND entity_id=?',
      [_device.principalId, _cameraType, id],
    );
    if (existing.isNotEmpty) {
      final old =
          jsonDecode(existing.single['projection_json'] as String)
              as Map<String, dynamic>;
      if (_freezeJson(old['draft'] as Map<String, dynamic>) != draft._json ||
          old['asset_id'] != assetId ||
          old['device_id'] != _device.deviceId ||
          old['session_epoch'] != _device.epoch) {
        throw const EncryptedStoreException('CAMERA_INTENT_CONFLICT');
      }
      return _cameraSummary(old);
    }
    if (_row(assetId) != null ||
        _observationRow(id) != null ||
        _db.select(
          r"SELECT 1 FROM work_cache WHERE principal_id=? AND entity_type=? AND json_extract(projection_json,'$.asset_id')=? LIMIT 1",
          [_device.principalId, _cameraType, assetId],
        ).isNotEmpty) {
      throw const EncryptedStoreException('CAMERA_INTENT_CONFLICT');
    }
    final rows = _db.select(
      "SELECT c.projection_json,f.invalidated_at FROM work_cache c JOIN execution_fences f ON f.principal_id=c.principal_id AND c.entity_id=f.assignment_id||':'||f.assignment_version WHERE c.principal_id=? AND c.entity_type='execution_capture_context_v1' AND f.assignment_id=? AND f.assignment_version=?",
      [
        _device.principalId,
        intent['assignment_id'],
        intent['assignment_version'],
      ],
    );
    if (rows.length != 1 || rows.single['invalidated_at'] != null) {
      throw const EncryptedStoreException('EXECUTION_CONTEXT_INVALIDATED');
    }
    final context = jsonDecode(rows.single['projection_json'] as String) as Map;
    if (intent['kind'] == 'issue') {
      _pickupIssuePayload(intent, Map<String, dynamic>.from(context));
      if (_pickupPhotoId(intent) != assetId) {
        throw const EncryptedStoreException('CAMERA_INTENT_CONFLICT');
      }
    }
    final units = (context['stop_units'] as Map)[intent['stop_id']];
    if (units is! List ||
        !units.contains(intent['fulfillment_unit_id']) ||
        DateTime.parse(
          intent['observed_at'] as String,
        ).isBefore(DateTime.parse(context['fetched_at'] as String))) {
      throw const EncryptedStoreException('OBSERVATION_OUTSIDE_CONTEXT');
    }
    for (final parentId in intent['predecessor_observation_ids'] as List) {
      final row = _observationRow(parentId as String);
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
    // An unresolved camera result cannot be silently relabelled as a retake.
    if (_pendingCameraCaptures().isNotEmpty) {
      throw const EncryptedStoreException('CAMERA_CAPTURE_UNRESOLVED');
    }
    final data = <String, Object?>{
      'format': 1,
      'draft': intent,
      'asset_id': assetId,
      'device_id': _device.deviceId,
      'session_epoch': _device.epoch,
      'state': 'awaiting_camera',
    };
    _commit(
      () => _db.execute(
        'INSERT INTO work_cache (principal_id,entity_type,entity_id,tenant_id,server_version,projection_json,fetched_at) VALUES (?,?,?,?,?,?,?)',
        [
          _device.principalId,
          _cameraType,
          id,
          context['tenant_id'],
          intent['assignment_version'],
          _freezeJson(data),
          intent['observed_at'],
        ],
      ),
    );
    return CameraCaptureIntent._(id, assetId, 'awaiting_camera', isNew: true);
  }

  List<CameraCaptureIntent> _pendingCameraCaptures() {
    final rows = _db.select(
      r"SELECT projection_json FROM work_cache WHERE principal_id=? AND entity_type=? AND json_extract(projection_json,'$.state')='awaiting_camera' ORDER BY entity_id LIMIT 2",
      [_device.principalId, _cameraType],
    );
    return List.unmodifiable(
      rows.map(
        (r) => _cameraSummary(
          jsonDecode(r['projection_json'] as String) as Map<String, dynamic>,
        ),
      ),
    );
  }

  void _cancelCameraCapture(String id) {
    final intent = _cameraIntent(id);
    // Only an actual camera cancellation; don't erase an interrupted save.
    if (intent['state'] == 'cancelled') return;
    if (intent['state'] != 'awaiting_camera' ||
        _observationRow(id) != null ||
        intent['draft_kind'] == _pickupFormType &&
            _row(intent['asset_id']) != null) {
      throw const EncryptedStoreException('CAMERA_INTENT_CONFLICT');
    }
    _cameraState(intent, 'cancelled');
  }

  Future<StoredObservation> _finishCameraCapture(
    String id,
    ObservationPhoto photo,
    Uint8List bytes,
  ) async {
    final intent = _cameraIntent(id);
    if (intent['state'] == 'cancelled' ||
        intent['asset_id'] != photo.assetId ||
        intent['device_id'] != _device.deviceId ||
        intent['session_epoch'] != _device.epoch) {
      throw const EncryptedStoreException('CAMERA_INTENT_CONFLICT');
    }
    // The original authorized intent permits ONLY local evidence retention if
    // reassignment happened during capture. It cannot authorize a new command.
    final draft = LocalObservationDraft._(
      _freezeJson(intent['draft'] as Map<String, dynamic>),
    );
    final observation = await _recordObservation(
      draft,
      photo,
      bytes,
      previouslyAuthorizedCamera: true,
    );
    if (observation.state != 'local_recorded') {
      throw const EncryptedStoreException('OBSERVATION_REQUIRES_RECOVERY');
    }
    await _boundary('camera_photo_saved');
    _cameraState(intent, 'saved_locally');
    return observation;
  }
}
