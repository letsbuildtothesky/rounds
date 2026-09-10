part of 'encrypted_work_store.dart';

/// ADR-S09: purpose adapter only. Capture, encryption, uploader, HTTP/status
/// and retry machinery remain shared with POD; no fake physical predecessor.
extension _PickupPhotoTransfers on EncryptedDriverStore {
  Map<String, dynamic> _pickupPhotoReservation(Map<String, dynamic> o) {
    if (o['kind'] != 'issue') {
      throw const EncryptedStoreException('PHOTO_TRANSFER_NOT_READY');
    }
    _requirePickupPhoto(o);
    final action = o['observed_payload'] as Map<String, dynamic>;
    final delivery = action['command_payload']['delivery_id'];
    final order =
        (action['pickup_execution']['data']['orders'] as List).singleWhere(
              (v) => v['delivery_id'] == delivery,
            )
            as Map;
    final asset = _row(_pickupPhotoId(o)!)!;
    return {
      'kind': 'issue_photo',
      'mime_type': asset['mime_type'],
      'byte_size': asset['byte_size'],
      'sha256': asset['sha256'],
      'purpose_entity_id': delivery,
      'pickup_context': {
        'round_id': o['execution_context']['round_id'],
        'pickup_stop_id': o['stop_id'],
        'fulfillment_unit_id': o['fulfillment_unit_id'],
        'manifest_id': order['manifest_id'],
        'execution_fence': {
          'assignment_id': o['assignment_id'],
          'assignment_version': o['assignment_version'],
          'observation_id': o['observation_id'],
        },
      },
    };
  }

  Future<StoredPhotoTransfer> _preparePickupPhotoTransfer(
    Map<String, dynamic> o,
  ) async {
    if (!_fenceCurrent(o)) {
      throw const EncryptedStoreException('EXECUTION_FENCE_CHANGED');
    }
    final id = _newCommandId();
    final wire = _mediaRequest(o, id, _pickupPhotoReservation(o), const []);
    validateCommandWire('ReserveAssetRequest', wire);
    final transfer = <String, dynamic>{
      'format': 1,
      'photo_kind': 'issue_photo',
      'observation_id': o['observation_id'],
      'asset_id': _pickupPhotoId(o),
      'handoff_observation_id': null,
      'reserve_command_id': id,
      'verify_command_id': null,
      'receipt_bindings': <String, dynamic>{},
      'stage': 'reserve',
      'next_attempt_at': null,
      'error': null,
    };
    await _boundary('photo_before_prepare');
    _commit(() {
      _insertMediaCommand('ReserveAsset', wire, const []);
      _writePhotoTransfer(transfer);
    });
    await _boundary('photo_prepared');
    return StoredPhotoTransfer._(transfer);
  }

  Map<String, dynamic> _pickupMediaBinding(
    String command,
    String pointer,
    Object? value,
  ) => {
    'result_pointer': pointer,
    'resolved_value': value,
    'resolved_by_command_id': command,
  };

  void _checkPickupPhotoTransfer(
    Map<String, dynamic> t,
    Map<String, dynamic> o,
    Map<String, Object?> reserveRow,
  ) {
    void require(bool ok) {
      if (!ok) {
        throw const EncryptedStoreException('PHOTO_TRANSFER_REQUIRES_RECOVERY');
      }
    }

    require(
      t['handoff_observation_id'] == null && t['asset_id'] == _pickupPhotoId(o),
    );
    final linkedReport = _observationRow(
      o['observation_id'] as String,
    )!['command_id'];
    require((linkedReport != null) == (t['report_binding'] != null));
    final expected = _mediaRequest(
      o,
      t['reserve_command_id'] as String,
      _pickupPhotoReservation(o),
      const [],
    );
    require(canonicalNativeCommand(expected) == reserveRow['payload_json']);
    final bindings = <String, dynamic>{};
    if (t['verify_command_id'] != null) {
      final reserve = _committedCommand(t['reserve_command_id'] as String);
      final verifyId = t['verify_command_id'] as String,
          verify = _commandRow(verifyId);
      final expectedVerify = _mediaRequest(
        o,
        verifyId,
        {
          'asset_id': reserve['data']['asset_id'],
          'sha256': _row(t['asset_id'] as String)!['sha256'],
        },
        List<Map<String, dynamic>>.from(
          (reserve['resources'] as List).map(
            (r) => Map<String, dynamic>.from(r as Map),
          ),
        ),
      );
      require(
        verify['command_type'] == 'VerifyAsset' &&
            canonicalNativeCommand(expectedVerify) == verify['payload_json'],
      );
      bindings['/media/verify/payload/asset_id'] = _pickupMediaBinding(
        reserve['command_id'] as String,
        '/data/asset_id',
        reserve['data']['asset_id'],
      );
      bindings['/media/verify/expected_versions/0/version'] =
          _pickupMediaBinding(
            reserve['command_id'] as String,
            '/resources/0/version',
            reserve['resources'][0]['version'],
          );
      if (t['report_binding'] != null) {
        final verified = _committedCommand(verifyId);
        final linked = _observationRow(
          o['observation_id'] as String,
        )!['command_id'];
        require(linked != null);
        final report = _commandRow(linked as String);
        final w = jsonDecode(report['payload_json'] as String) as Map;
        require(
          report['command_type'] == 'ReportIssue' &&
              w['execution_fence']['observation_id'] == o['observation_id'] &&
              canonicalNativeCommand(w['payload']['asset_ids']) ==
                  canonicalNativeCommand([verified['data']['resource']['id']]),
        );
        require(
          canonicalNativeCommand(t['report_binding']) ==
              canonicalNativeCommand({
                'command_id': linked,
                'payload_pointer': '/payload/asset_ids/0',
                ..._pickupMediaBinding(
                  verifyId,
                  '/data/resource/id',
                  verified['data']['resource']['id'],
                ),
              }),
        );
      }
    } else {
      require(t['report_binding'] == null);
    }
    require(
      canonicalNativeCommand(t['receipt_bindings']) ==
          canonicalNativeCommand(bindings),
    );
  }

  void _bindPickupPhotoReport(
    Map<String, dynamic> o,
    String command,
    Map<String, dynamic> media,
  ) {
    // Within the SAME transaction as the new ReportIssue command/link.
    final t = media['transfer'] as Map<String, dynamic>;
    t['report_binding'] = {
      'command_id': command,
      'payload_pointer': '/payload/asset_ids/0',
      ..._pickupMediaBinding(
        media['command'] as String,
        '/data/resource/id',
        media['asset_id'],
      ),
    };
    _writePhotoTransfer(t);
  }
}
