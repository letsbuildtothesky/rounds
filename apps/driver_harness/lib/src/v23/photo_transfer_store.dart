part of 'encrypted_work_store.dart';

/// Upload status is independent of local photo integrity and delivery outcome.
class StoredPhotoTransfer {
  StoredPhotoTransfer._(Map<String, dynamic> value)
    : state = value['stage'] as String,
      errorCode = value['error'] as String?,
      localAssetId = value['asset_id'] as String;
  final String state, localAssetId;
  final String? errorCode;
  @override
  String toString() => 'StoredPhotoTransfer($state)';
}

extension NativePhotoTransfers on EncryptedDriverStore {
  /// One saved delivery photo on the proof observation. No legacy conversion,
  /// new physical observations, arbitrary remote asset ID or temporary plaintext.
  Future<StoredPhotoTransfer> preparePhotoTransfer(String observationId) =>
      _serial(() async {
        final row = _observationRow(observationId);
        if (row == null) {
          throw const EncryptedStoreException('OBSERVATION_NOT_FOUND');
        }
        final saved = await _inspectObservation(row), o = saved.toJson();
        if (saved.state != 'local_recorded') {
          throw const EncryptedStoreException('EVIDENCE_REQUIRES_RECOVERY');
        }
        final existing = _photoTransfer(observationId);
        if (existing != null) return StoredPhotoTransfer._(existing);
        if (o['kind'] == 'issue') return _preparePickupPhotoTransfer(o);
        if (o['kind'] != 'proof' ||
            (o['assets'] as List).length != 1 ||
            !_selectedPhoto(o) ||
            (o['predecessor_observation_ids'] as List).length != 1 ||
            !_fenceCurrent(o)) {
          throw const EncryptedStoreException('PHOTO_TRANSFER_NOT_READY');
        }
        final parentId =
            (o['predecessor_observation_ids'] as List).single as String;
        final parent = _observationRow(parentId);
        if (parent == null || parent['command_id'] == null) {
          throw const EncryptedStoreException('DEPENDENCY_UNRESOLVED');
        }
        final h =
            jsonDecode(parent['payload_json'] as String)
                as Map<String, dynamic>;
        if (h['kind'] != 'handoff' ||
            h['stop_id'] != o['stop_id'] ||
            h['fulfillment_unit_id'] != o['fulfillment_unit_id'] ||
            h['device_id'] != o['device_id'] ||
            h['session_epoch'] != o['session_epoch'] ||
            canonicalNativeCommand(h['execution_context']) !=
                canonicalNativeCommand(o['execution_context'])) {
          throw const EncryptedStoreException('DEPENDENCY_SCOPE_MISMATCH');
        }
        final handoff = _committedCommand(parent['command_id'] as String);
        if (handoff['command_type'] != 'RecordHandoff') {
          throw const EncryptedStoreException('DEPENDENCY_UNRESOLVED');
        }
        final asset = _row(o['assets'][0]['asset_id'] as String)!;
        final payload = {
          'kind': 'delivery_photo',
          'mime_type': asset['mime_type'],
          'byte_size': asset['byte_size'],
          'sha256': asset['sha256'],
          'purpose_entity_id': handoff['data']['handoff_id'],
        };
        final id = _newCommandId();
        final wire = _mediaRequest(o, id, payload, const []);
        validateCommandWire('ReserveAssetRequest', wire);
        final transfer = <String, dynamic>{
          'format': 1,
          'observation_id': observationId,
          'asset_id': asset['asset_id'],
          'handoff_observation_id': parentId,
          'reserve_command_id': id,
          'verify_command_id': null,
          'stage': 'reserve',
          'next_attempt_at': null,
          'error': null,
        };
        await _boundary('photo_before_prepare');
        _commit(() {
          _insertMediaCommand('ReserveAsset', wire, [
            handoff['command_id'] as String,
          ]);
          _writePhotoTransfer(transfer);
          _mediaBinding(
            transfer,
            '/media/reserve/payload/purpose_entity_id',
            '/data/handoff_id',
            payload['purpose_entity_id'],
            handoff['command_id'] as String,
          );
        });
        await _boundary('photo_prepared');
        return StoredPhotoTransfer._(transfer);
      });

  Future<StoredPhotoTransfer?> photoTransfer(String id) => _serial(() async {
    final transfer = _photoTransfer(id);
    return transfer == null ? null : StoredPhotoTransfer._(transfer);
  });

  /// One foreground stage: reservation/status, fresh-capability + signed PUT,
  /// or verification/status. No loop, timer, deletion, public URL or auto-proof.
  Future<StoredPhotoTransfer> advancePhotoTransfer(
    String id, {
    required DriverDeviceRegistrationClient transport,
    required String bearer,
  }) => _serial(() async {
    final t = _photoTransfer(id);
    final observation = _observationRow(id);
    if (t == null || observation == null) {
      throw const EncryptedStoreException('PHOTO_TRANSFER_NOT_READY');
    }
    final o = (await _inspectObservation(observation));
    if (o.state != 'local_recorded') {
      throw const EncryptedStoreException('EVIDENCE_REQUIRES_RECOVERY');
    }
    if ({'verified', 'rejected', 'needs_review'}.contains(t['stage'])) {
      return StoredPhotoTransfer._(t);
    }
    final now = _commandClock().toUtc();
    if (t['next_attempt_at'] != null &&
        DateTime.parse(t['next_attempt_at'] as String).isAfter(now)) {
      return StoredPhotoTransfer._(t);
    }
    final reserve = _commandRow(t['reserve_command_id'] as String);
    if (t['stage'] == 'reserve') {
      final result = await _synchronizeCommand(
        reserve,
        observation,
        transport: transport,
        bearer: bearer,
      );
      if (result.state == 'committed') {
        final receipt = _committedCommand(result.commandId);
        final asset = _row(t['asset_id'] as String)!;
        final commandId = _newCommandId();
        final wire = _mediaRequest(
          o.toJson(),
          commandId,
          {'asset_id': receipt['data']['asset_id'], 'sha256': asset['sha256']},
          List<Map<String, dynamic>>.from(
            (receipt['resources'] as List).map(
              (r) => Map<String, dynamic>.from(r as Map),
            ),
          ),
        );
        validateCommandWire('VerifyAssetRequest', wire);
        _commit(() {
          _insertMediaCommand('VerifyAsset', wire, [result.commandId]);
          t['verify_command_id'] = commandId;
          t['stage'] = 'upload';
          _writePhotoTransfer(t);
          _mediaBinding(
            t,
            '/media/verify/payload/asset_id',
            '/data/asset_id',
            receipt['data']['asset_id'],
            result.commandId,
          );
          _mediaBinding(
            t,
            '/media/verify/expected_versions/0/version',
            '/resources/0/version',
            receipt['resources'][0]['version'],
            result.commandId,
          );
        });
      } else if ({'rejected', 'needs_review'}.contains(result.state)) {
        _photoStage(t, result.state, error: result.errorCode);
      }
    } else if (t['stage'] == 'upload') {
      if (!_fenceCurrent(o.toJson())) {
        _photoStage(t, 'needs_review', error: 'EXECUTION_FENCE_CHANGED');
        return StoredPhotoTransfer._(t);
      }
      try {
        final response = await transport.exchangeExecutionCommand(
          device: _device,
          bearer: bearer,
          commandType: 'ReserveAsset',
          frozenRequest: reserve['payload_json'] as String,
          statusOnly: true,
        );
        _active();
        if (response.httpStatus != 200 || response.upload == null) {
          _photoStage(
            t,
            'upload',
            error: 'UPLOAD_CAPABILITY_UNAVAILABLE',
            retry: true,
            seconds: response.retryAfterSeconds,
          );
          return StoredPhotoTransfer._(t);
        }
        _checkReceipt(reserve, response.toJson());
        if (canonicalNativeCommand(response.toJson()) !=
            reserve['server_receipt_json']) {
          throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
        }
        final asset = _row(t['asset_id'] as String)!;
        final bytes = await _decrypt(asset);
        try {
          // Before IO, uncertain bytes must go to server verification first.
          _commit(() {
            t['stage'] = 'verify';
            t['error'] = null;
            t['next_attempt_at'] = null;
            _writePhotoTransfer(t);
            _db.execute(
              "INSERT INTO upload_sessions(session_id,asset_id,upload_capability_secret_ref,expires_at,state,updated_at) VALUES(?,?,?,?,'unknown',?) ON CONFLICT(session_id) DO UPDATE SET state='unknown',updated_at=excluded.updated_at",
              [
                t['reserve_command_id'],
                t['asset_id'],
                'memory-only:renew-via-reservation',
                now.toIso8601String(),
                now.toIso8601String(),
              ],
            );
          });
          await _boundary('photo_before_upload');
          await transport.uploadPhoto(
            device: _device,
            capability: response.upload!,
            assetId: response.toJson()['data']['asset_id'] as String,
            mimeType: asset['mime_type'] as String,
            sha256: asset['sha256'] as String,
            bytes: bytes,
          );
          _active();
          await _boundary('photo_upload_returned');
          _commit(
            () => _db.execute(
              "UPDATE upload_sessions SET state='completed',offset_bytes=?,updated_at=? WHERE session_id=?",
              [
                asset['byte_size'],
                _commandClock().toUtc().toIso8601String(),
                t['reserve_command_id'],
              ],
            ),
          );
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
      } on DeviceEnrollmentException catch (error) {
        _active();
        _photoStage(t, t['stage'] as String, error: error.code, retry: true);
      }
    } else if (t['stage'] == 'verify') {
      final before = _commandRow(t['verify_command_id'] as String);
      final result = await _synchronizeCommand(
        before,
        observation,
        transport: transport,
        bearer: bearer,
      );
      if (result.state == 'committed') {
        _committedCommand(result.commandId);
        await _boundary('photo_before_verified');
        _photoStage(t, 'verified');
        await _boundary('photo_verified');
      } else if ({'rejected', 'needs_review'}.contains(result.state)) {
        _photoStage(t, result.state, error: result.errorCode);
      } else if ({'unknown', 'sending'}.contains(before['state']) &&
          result.state == 'queued') {
        // Only authenticated missing CommandStatus permits another PUT attempt.
        _photoStage(t, 'upload', retry: true);
      }
    } else {
      throw const EncryptedStoreException('PHOTO_TRANSFER_REQUIRES_RECOVERY');
    }
    return StoredPhotoTransfer._(_photoTransfer(id)!);
  });

  Map<String, dynamic> _committedCommand(String id) {
    final row = _commandRow(id);
    if (row['state'] != 'committed' || row['server_receipt_json'] == null) {
      throw const EncryptedStoreException('DEPENDENCY_UNRESOLVED');
    }
    final result =
        jsonDecode(row['server_receipt_json'] as String)
            as Map<String, dynamic>;
    _checkReceipt(row, result);
    return result;
  }

  bool _selectedPhoto(Map<String, dynamic> o) {
    final action = o['observed_payload'];
    if (action is! Map ||
        action.length != 1 ||
        action['command_payload'] is! Map) {
      return false;
    }
    final payload = action['command_payload'] as Map;
    if (payload.length != 1 || payload['evidence'] is! List) return false;
    final refs = payload['evidence'] as List;
    if (refs.any((r) => r is! Map || r['kind'] == 'signature')) return false;
    final photos = refs.where((r) => r['kind'] == 'photo').toList();
    return photos.length == 1 &&
        photos.single.length == 2 &&
        photos.single['local_asset_id'] == o['assets'][0]['asset_id'];
  }

  Map<String, dynamic>? _photoTransfer(String id) {
    final rows = _db.select(
      "SELECT projection_json FROM work_cache WHERE principal_id=? AND entity_type='pod_transfer_v1' AND entity_id=?",
      [_device.principalId, id],
    );
    if (rows.isEmpty) return null;
    final t =
        jsonDecode(rows.single['projection_json'] as String)
            as Map<String, dynamic>;
    if (t['format'] != 1 ||
        t['observation_id'] != id ||
        _row(t['asset_id'] as String) == null) {
      throw const EncryptedStoreException('PHOTO_TRANSFER_REQUIRES_RECOVERY');
    }
    final row = _commandRow(t['reserve_command_id'] as String);
    if (row['command_type'] != 'ReserveAsset') {
      throw const EncryptedStoreException('PHOTO_TRANSFER_REQUIRES_RECOVERY');
    }
    final source = _observationRow(id);
    if (source == null) {
      throw const EncryptedStoreException('PHOTO_TRANSFER_REQUIRES_RECOVERY');
    }
    final o =
        jsonDecode(source['payload_json'] as String) as Map<String, dynamic>;
    if (t['photo_kind'] == 'issue_photo') {
      _checkPickupPhotoTransfer(t, o, row);
      return t;
    }
    final parent = _observationRow(t['handoff_observation_id'] as String);
    if (o['kind'] != 'proof' ||
        (o['assets'] as List).length != 1 ||
        !_selectedPhoto(o) ||
        o['assets'][0]['asset_id'] != t['asset_id'] ||
        parent == null ||
        parent['command_id'] == null ||
        (o['predecessor_observation_ids'] as List).length != 1 ||
        o['predecessor_observation_ids'][0] != t['handoff_observation_id']) {
      throw const EncryptedStoreException('PHOTO_TRANSFER_REQUIRES_RECOVERY');
    }
    final handoff = _committedCommand(parent['command_id'] as String);
    final asset = _row(t['asset_id'] as String)!;
    final expected = _mediaRequest(o, t['reserve_command_id'] as String, {
      'kind': 'delivery_photo',
      'mime_type': asset['mime_type'],
      'sha256': asset['sha256'],
      'byte_size': asset['byte_size'],
      'purpose_entity_id': handoff['data']['handoff_id'],
    }, const []);
    if (canonicalNativeCommand(expected) != row['payload_json']) {
      throw const EncryptedStoreException('PHOTO_TRANSFER_REQUIRES_RECOVERY');
    }
    if (t['verify_command_id'] != null) {
      final reservation = _committedCommand(t['reserve_command_id'] as String);
      final verify = _commandRow(t['verify_command_id'] as String);
      final expectedVerify = _mediaRequest(
        o,
        t['verify_command_id'] as String,
        {
          'asset_id': reservation['data']['asset_id'],
          'sha256': asset['sha256'],
        },
        List<Map<String, dynamic>>.from(
          (reservation['resources'] as List).map(
            (r) => Map<String, dynamic>.from(r as Map),
          ),
        ),
      );
      if (verify['command_type'] != 'VerifyAsset' ||
          canonicalNativeCommand(expectedVerify) != verify['payload_json']) {
        throw const EncryptedStoreException('PHOTO_TRANSFER_REQUIRES_RECOVERY');
      }
    }
    return t;
  }

  Map<String, dynamic> _requireVerifiedPhoto(
    String observationId,
    Object? assetId,
  ) {
    final t = _photoTransfer(observationId);
    if (t == null || t['asset_id'] != assetId || t['stage'] != 'verified') {
      throw const EncryptedStoreException('ASSET_NOT_VERIFIED');
    }
    final reserve = _committedCommand(t['reserve_command_id'] as String);
    final verify = _committedCommand(t['verify_command_id'] as String);
    if (verify['command_type'] != 'VerifyAsset' ||
        verify['data']['resource']['id'] != reserve['data']['asset_id']) {
      throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
    }
    return {
      'asset_id': verify['data']['resource']['id'],
      'command': verify['command_id'],
      'transfer': t,
    };
  }

  Map<String, dynamic> _mediaRequest(
    Map<String, dynamic> o,
    String id,
    Map<String, Object?> payload,
    List<Map<String, dynamic>> roots,
  ) => {
    'command_id': id,
    'context': {
      'tenant_id': o['execution_context']['tenant_id'],
      'city_id': o['execution_context']['city_id'],
    },
    'occurred_at': o['observed_at'],
    'expected_versions': roots,
    'payload': payload,
  };

  void _insertMediaCommand(
    String type,
    Map<String, dynamic> wire,
    List<String> dependencies,
  ) {
    final id = wire['command_id'];
    _db.execute(
      "INSERT INTO pending_commands(command_id,principal_id,tenant_id,command_type,payload_json,request_hash,expected_versions_json,occurred_at,queued_at,state) VALUES(?,?,?,?,?,?,?,?,?,'queued')",
      [
        id,
        _device.principalId,
        wire['context']['tenant_id'],
        type,
        canonicalNativeCommand(wire),
        _requestDigest(type, wire),
        canonicalNativeCommand(wire['expected_versions']),
        wire['occurred_at'],
        _commandClock().toUtc().toIso8601String(),
      ],
    );
    for (final root in wire['expected_versions'] as List) {
      _db.execute('INSERT INTO command_roots VALUES(?,?,?,?)', [
        id,
        root['aggregate_type'],
        root['id'],
        root['version'],
      ]);
    }
    for (final dependency in dependencies) {
      _db.execute('INSERT INTO command_dependencies VALUES(?,?)', [
        id,
        dependency,
      ]);
    }
  }

  void _writePhotoTransfer(Map<String, dynamic> t) {
    final observation = _observationRow(t['observation_id'] as String)!;
    final o = jsonDecode(observation['payload_json'] as String) as Map;
    _db.execute(
      "INSERT INTO work_cache(principal_id,entity_type,entity_id,tenant_id,server_version,projection_json,fetched_at) VALUES(?,'pod_transfer_v1',?,?,0,?,?) ON CONFLICT(principal_id,entity_type,entity_id) DO UPDATE SET projection_json=excluded.projection_json,fetched_at=excluded.fetched_at",
      [
        _device.principalId,
        t['observation_id'],
        o['execution_context']['tenant_id'],
        canonicalNativeCommand(t),
        _commandClock().toUtc().toIso8601String(),
      ],
    );
  }

  void _photoStage(
    Map<String, dynamic> t,
    String stage, {
    String? error,
    bool retry = false,
    int seconds = 30,
  }) => _commit(() {
    t['stage'] = stage;
    t['error'] = error;
    t['next_attempt_at'] = retry
        ? _commandClock()
              .toUtc()
              .add(Duration(seconds: max(30, seconds)))
              .toIso8601String()
        : null;
    _writePhotoTransfer(t);
  });
  void _mediaBinding(
    Map<String, dynamic> t,
    String target,
    String pointer,
    Object? value,
    String command,
  ) {
    if (t['photo_kind'] == 'issue_photo') {
      (t['receipt_bindings'] as Map)[target] = {
        'result_pointer': pointer,
        'resolved_value': value,
        'resolved_by_command_id': command,
      };
      _writePhotoTransfer(t);
      return;
    }
    _db.execute('INSERT INTO observation_bindings VALUES(?,?,?,?,?,?,?)', [
      _device.principalId,
      t['observation_id'],
      t['handoff_observation_id'],
      pointer,
      target,
      canonicalNativeCommand(value),
      command,
    ]);
  }
}
