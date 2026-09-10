part of 'encrypted_work_store.dart';

/// G03 editable local draft. It is NOT a ReportIssue observation until the
/// explicit submit boundary. Retakes keep every earlier encrypted asset.
class StoredPickupIssueForm {
  StoredPickupIssueForm._(this._json);
  final String _json;
  Map<String, dynamic> _value() => jsonDecode(_json) as Map<String, dynamic>;
  String get id => _value()['id'] as String;
  String get observationId => _value()['observation_id'] as String;
  String get deliveryId => _value()['delivery_id'] as String;
  String? get reason => _value()['reason'] as String?;
  String get detail => _value()['detail'] as String;
  bool get frozen => _value()['frozen_draft'] != null;
  String? get photoId => _value()['photo']?['asset_id'] as String?;
  DriverPickupSnapshot get snapshot =>
      DriverPickupSnapshot.parse(_value()['snapshot']);
  @override
  String toString() => 'StoredPickupIssueForm(redacted)';
}

const _pickupFormType = 'pickup_issue_form_v1';

extension NativePickupIssueForm on EncryptedDriverStore {
  Future<StoredPickupIssueForm> openPickupIssueForm(
    AuthorizedPickup pickup, {
    required String deliveryId,
  }) => _serial(() async {
    final context = pickup.originalContext.toJson();
    // Reuse exact scope/manifest/version validation, without creating a report.
    LocalPickupIssueDraft(
      pickup: pickup,
      observationId: _newPickupObservationId(),
      observedAt: DateTime.parse(context['fetched_at']),
      reason: 'missing',
      deliveryId: deliveryId,
    );
    _cacheContext(pickup.originalContext);
    final id =
        '${context['assignment_id']}:${context['assignment_version']}:$deliveryId';
    final old = _formRow(id);
    if (old != null) {
      if (_freezeJson(old['context']) != _freezeJson(context) ||
          _freezeJson(old['snapshot']['data']['execution']) !=
              _freezeJson(pickup.snapshot.toJson()['data']['execution'])) {
        throw const EncryptedStoreException('PICKUP_FORM_CHANGED');
      }
      return _readForm(id);
    }
    final form = <String, dynamic>{
      'format': 1,
      'id': id,
      'context': context,
      'snapshot': pickup.snapshot.toJson(),
      'delivery_id': deliveryId,
      'observation_id': _newPickupObservationId(),
      'device_id': _device.deviceId,
      'session_epoch': _device.epoch,
      'reason': null,
      'detail': '',
      'photo': null,
      'capture_id': null,
      'frozen_draft': null,
    };
    _currentForm(form);
    _commit(() => _writeForm(form));
    return _formSummary(form);
  });

  Future<StoredPickupIssueForm> readPickupIssueForm(String id) =>
      _serial(() => _readForm(id));

  Future<StoredPickupIssueForm> editPickupIssueForm(
    String id, {
    required String reason,
    required String detail,
  }) => _serial(() async {
    final form = _requireForm(id);
    _editableForm(form);
    if (!{'damaged', 'missing', 'wrong'}.contains(reason) ||
        detail.runes.length > 240) {
      throw const EncryptedStoreException('INVALID_OBSERVED_ACTION');
    }
    if (form['reason'] != reason) {
      form['photo'] = null; // retain bytes, not selection
    }
    form['reason'] = reason;
    form['detail'] = detail;
    _commit(() => _writeForm(form));
    await _boundary('pickup_form_edit_committed');
    return _formSummary(form);
  });

  Future<CameraCaptureIntent> preparePickupFormCamera(
    String id, {
    required DateTime observedAt,
  }) => _serial(() async {
    final form = _requireForm(id);
    _editableForm(form);
    if (!{'damaged', 'wrong'}.contains(form['reason']) ||
        !observedAt.isUtc ||
        observedAt.isBefore(DateTime.parse(form['context']['fetched_at']))) {
      throw const EncryptedStoreException('INVALID_OBSERVED_ACTION');
    }
    if (_pendingCameraCaptures().isNotEmpty) {
      throw const EncryptedStoreException('CAMERA_CAPTURE_UNRESOLVED');
    }
    final captureId = _newPickupObservationId(),
        assetId = _newPickupObservationId();
    final intent = <String, dynamic>{
      'format': 1,
      'draft_kind': _pickupFormType,
      'draft': {'observation_id': captureId},
      'form_id': id,
      'report_observation_id': form['observation_id'],
      'reason': form['reason'],
      'asset_id': assetId,
      'observed_at': observedAt.toIso8601String(),
      'device_id': _device.deviceId,
      'session_epoch': _device.epoch,
      'state': 'awaiting_camera',
    };
    form['capture_id'] = captureId;
    _commit(() {
      _writeForm(form);
      _db.execute(
        'INSERT INTO work_cache (principal_id,entity_type,entity_id,tenant_id,server_version,projection_json,fetched_at) VALUES (?,?,?,?,?,?,?)',
        [
          _device.principalId,
          _CameraPersistence._cameraType,
          captureId,
          form['context']['tenant_id'],
          form['context']['assignment_version'],
          _freezeJson(intent),
          intent['observed_at'],
        ],
      );
    });
    await _boundary('pickup_form_camera_prepared');
    return CameraCaptureIntent._(
      captureId,
      assetId,
      'awaiting_camera',
      isNew: true,
    );
  });

  Future<StoredPickupIssueForm> finishPickupFormCamera(
    String captureId, {
    required ObservationPhoto photo,
  }) {
    if (photo._disposed) {
      return Future.error(const EncryptedStoreException('INVALID_EVIDENCE'));
    }
    final bytes = Uint8List.fromList(photo._bytes);
    return _serial(() async {
      final capture = _cameraIntent(captureId);
      final form = _requireForm(capture['form_id'] as String);
      _formCapture(form, capture);
      if (photo.assetId != capture['asset_id']) {
        throw const EncryptedStoreException('CAMERA_INTENT_CONFLICT');
      }
      // Original owner may retain a photo after assignment invalidation. Only
      // _currentForm permits editing/submission; retention grants no send rights.
      await _persistEvidence(
        assetId: photo.assetId,
        purposeKind: 'issue',
        purposeEntityId: _formUnit(form),
        mimeType: photo.mimeType,
        capturedAt: DateTime.parse(capture['observed_at']),
        snapshot: bytes,
      );
      await _boundary('pickup_form_photo_saved');
      await _selectFormPhoto(form, capture);
      return _formSummary(form);
    }).whenComplete(() => bytes.fillRange(0, bytes.length, 0));
  }

  /// Freeze the latest note/reason/selected camera candidate before any upload.
  /// Replay after a crash uses these same bytes, IDs and capture time.
  Future<StoredObservation> submitPickupIssueForm(
    String id, {
    required DateTime observedAt,
  }) => _serial(() async {
    final form = _requireForm(id);
    if (form['frozen_draft'] == null) {
      _editableForm(form);
      if (form['reason'] == null) {
        throw const EncryptedStoreException('INVALID_OBSERVED_ACTION');
      }
      final selected = form['photo'] as Map?;
      if (form['reason'] != 'missing' && selected == null) {
        throw const EncryptedStoreException('PICKUP_ISSUE_CAMERA_REQUIRED');
      }
      if (selected != null) _selectedFormPhoto(form);
      final draft = LocalPickupIssueDraft(
        pickup: (
          snapshot: DriverPickupSnapshot.parse(form['snapshot']),
          originalContext: ExecutionCaptureContext.fromJson(form['context']),
        ),
        observationId: form['observation_id'],
        observedAt: selected == null
            ? observedAt
            : DateTime.parse(selected['observed_at']),
        reason: form['reason'],
        deliveryId: form['delivery_id'],
        detail: form['detail'] == '' ? null : form['detail'],
        localAssetId: selected?['asset_id'],
      );
      form['frozen_draft'] = draft._json;
      _commit(() => _writeForm(form));
      await _boundary('pickup_form_submit_frozen');
    }
    _currentForm(form);
    final draft =
        jsonDecode(form['frozen_draft'] as String) as Map<String, dynamic>;
    final intent = LocalObservationDraft._(_freezeJson(draft['draft']));
    final selected = form['photo'] as Map?;
    ObservationPhoto? photo;
    Uint8List? bytes;
    try {
      if (selected != null) {
        final row = _row(selected['asset_id'])!;
        bytes = await _decrypt(row);
        photo = ObservationPhoto(
          assetId: selected['asset_id'],
          mimeType: row['mime_type'] as String,
          bytes: bytes,
        );
      }
      return await _recordObservation(
        intent,
        photo,
        bytes,
        stagedPickupFormId: selected == null ? null : id,
      );
    } finally {
      photo?.dispose();
      bytes?.fillRange(0, bytes.length, 0);
    }
  });

  Map<String, dynamic>? _formRow(String id) {
    final encoded =
        _db.select(
              'SELECT projection_json FROM work_cache WHERE principal_id=? AND entity_type=? AND entity_id=?',
              [_device.principalId, _pickupFormType, id],
            ).singleOrNull?['projection_json']
            as String?;
    return encoded == null ? null : jsonDecode(encoded) as Map<String, dynamic>;
  }

  Map<String, dynamic> _requireForm(String id) {
    final form = _formRow(id);
    if (form == null ||
        form['format'] != 1 ||
        form['id'] != id ||
        form['context']['principal_id'] != _device.principalId) {
      throw const EncryptedStoreException('PICKUP_FORM_NOT_FOUND');
    }
    return form;
  }

  StoredPickupIssueForm _formSummary(Map<String, dynamic> form) =>
      StoredPickupIssueForm._(_encodePickupCollection(form));
  void _writeForm(Map<String, dynamic> form) => _db.execute(
    'INSERT INTO work_cache (principal_id,entity_type,entity_id,tenant_id,server_version,projection_json,fetched_at) VALUES (?,?,?,?,?,?,?) ON CONFLICT (principal_id,entity_type,entity_id) DO UPDATE SET projection_json=excluded.projection_json',
    [
      _device.principalId,
      _pickupFormType,
      form['id'],
      form['context']['tenant_id'],
      form['context']['assignment_version'],
      _encodePickupCollection(form),
      form['context']['fetched_at'],
    ],
  );
  void _currentForm(Map<String, dynamic> form) {
    final c = form['context'] as Map<String, dynamic>;
    if (form['device_id'] != _device.deviceId ||
        form['session_epoch'] != _device.epoch ||
        !_fenceCurrent({...c, 'execution_context': c})) {
      throw const EncryptedStoreException('EXECUTION_FENCE_CHANGED');
    }
  }

  void _editableForm(Map<String, dynamic> form) {
    _currentForm(form);
    if (form['frozen_draft'] != null) {
      throw const EncryptedStoreException('PICKUP_REPORT_FROZEN');
    }
    final id = form['capture_id'] as String?;
    if (id != null && _cameraIntent(id)['state'] == 'awaiting_camera') {
      throw const EncryptedStoreException('CAMERA_CAPTURE_UNRESOLVED');
    }
  }

  String _formUnit(Map<String, dynamic> form) =>
      (form['snapshot']['data']['execution']['orders'] as List).singleWhere(
            (o) => o['delivery_id'] == form['delivery_id'],
          )['fulfillment_unit_id']
          as String;
  void _formCapture(Map<String, dynamic> form, Map<String, dynamic> capture) {
    if (capture['draft_kind'] != _pickupFormType ||
        capture['form_id'] != form['id'] ||
        capture['report_observation_id'] != form['observation_id'] ||
        capture['reason'] != form['reason'] ||
        form['capture_id'] != capture['draft']['observation_id'] ||
        form['frozen_draft'] != null ||
        capture['state'] == 'cancelled' ||
        capture['device_id'] != _device.deviceId ||
        capture['session_epoch'] != _device.epoch) {
      throw const EncryptedStoreException('CAMERA_INTENT_CONFLICT');
    }
  }

  Future<void> _selectFormPhoto(
    Map<String, dynamic> form,
    Map<String, dynamic> capture,
  ) async {
    _formCapture(form, capture);
    final row = _row(capture['asset_id']);
    if (row == null ||
        row['state'] != 'saved' ||
        row['purpose_kind'] != 'issue' ||
        row['purpose_entity_id'] != _formUnit(form) ||
        row['captured_at'] != capture['observed_at']) {
      throw const EncryptedStoreException('EVIDENCE_NOT_SAVED');
    }
    final bytes = await _decrypt(row);
    bytes.fillRange(0, bytes.length, 0);
    form['photo'] = {
      'asset_id': capture['asset_id'],
      'observed_at': capture['observed_at'],
      'capture_id': capture['draft']['observation_id'],
    };
    capture['state'] = 'saved_locally';
    _commit(() {
      _writeForm(form);
      _db.execute(
        'UPDATE work_cache SET projection_json=? WHERE principal_id=? AND entity_type=? AND entity_id=?',
        [
          _freezeJson(capture),
          _device.principalId,
          _CameraPersistence._cameraType,
          capture['draft']['observation_id'],
        ],
      );
    });
  }

  Future<StoredPickupIssueForm> _readForm(String id) async {
    final form = _requireForm(id), captureId = form['capture_id'] as String?;
    if (captureId != null && form['frozen_draft'] == null) {
      final capture = _cameraIntent(captureId);
      // Recover only the exact prepared capture with durable verified local
      // bytes. A missing camera result stays unresolved, never silently retaken.
      if (capture['state'] == 'awaiting_camera' &&
          _row(capture['asset_id'])?['state'] == 'saved') {
        await _selectFormPhoto(form, capture);
      }
    }
    return _formSummary(form);
  }

  void _requireStagedFormBinding(
    String id,
    Map<String, dynamic> intent,
    Map<String, Object?> photoRow,
  ) {
    final form = _requireForm(id);
    _currentForm(form);
    _selectedFormPhoto(form);
    if (form['frozen_draft'] == null ||
        _freezeJson(jsonDecode(form['frozen_draft'])['draft']) !=
            _freezeJson(intent) ||
        form['photo']?['asset_id'] != photoRow['asset_id'] ||
        photoRow['purpose_kind'] != 'issue' ||
        photoRow['purpose_entity_id'] != _formUnit(form)) {
      throw const EncryptedStoreException('OBSERVATION_ASSET_CONFLICT');
    }
    final asset = _row(photoRow['asset_id'] as String);
    if (asset == null ||
        asset['state'] != 'saved' ||
        EncryptedDriverStore._aad(asset) !=
            EncryptedDriverStore._aad(photoRow)) {
      throw const EncryptedStoreException('EVIDENCE_REQUIRES_RECOVERY');
    }
  }

  void _selectedFormPhoto(Map<String, dynamic> form) {
    final photo = form['photo'] as Map?;
    if (photo == null || photo['capture_id'] is! String) {
      throw const EncryptedStoreException('PICKUP_FORM_PHOTO_CONFLICT');
    }
    final capture = _cameraIntent(photo['capture_id']);
    if (capture['draft_kind'] != _pickupFormType ||
        capture['form_id'] != form['id'] ||
        capture['report_observation_id'] != form['observation_id'] ||
        capture['reason'] != form['reason'] ||
        capture['asset_id'] != photo['asset_id'] ||
        capture['observed_at'] != photo['observed_at'] ||
        capture['state'] != 'saved_locally' ||
        capture['device_id'] != form['device_id'] ||
        capture['session_epoch'] != form['session_epoch']) {
      throw const EncryptedStoreException('PICKUP_FORM_PHOTO_CONFLICT');
    }
  }
}
