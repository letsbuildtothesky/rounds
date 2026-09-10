part of 'encrypted_work_store.dart';

/// Frozen, explicitly observed package or pickup-wait report. This is
/// not a merchant receipt, measured shortage, Operations decision or UI state.
/// Required photos bind only through the original camera/verified transfer.
class LocalPickupIssueDraft {
  LocalPickupIssueDraft._(this._json);
  final String _json;

  factory LocalPickupIssueDraft({
    required AuthorizedPickup pickup,
    required String observationId,
    required DateTime observedAt,
    required String reason,
    String? deliveryId,
    String? detail,
    Map<String, Object?>? point,
    List<Map<String, Object?>> affectedLines = const [],
    String? predecessorObservationId,
    String? localAssetId,
  }) {
    final context = pickup.originalContext.toJson();
    final execution = pickup.snapshot.execution.toJson();
    if (!{'missing', 'awaiting_goods', 'damaged', 'wrong'}.contains(reason)) {
      throw const EncryptedStoreException('INVALID_OBSERVED_ACTION');
    }
    if (reason != 'awaiting_goods' && deliveryId == null ||
        detail != null && detail.runes.length > 240) {
      throw const EncryptedStoreException('INVALID_OBSERVED_ACTION');
    }
    final orders = execution['data']['orders'] as List;
    final order = deliveryId == null
        ? orders.first as Map
        : orders.where((o) => o['delivery_id'] == deliveryId).singleOrNull
              as Map?;
    if (order == null) {
      throw const EncryptedStoreException('OBSERVATION_OUTSIDE_CONTEXT');
    }
    final payload = <String, dynamic>{
      'delivery_id': ?deliveryId,
      'issue_type': reason == 'awaiting_goods' ? 'pickup_wait' : 'package',
      'reason_code': reason,
      'detail': ?detail,
      'point': ?point,
      'affected_lines': affectedLines,
    };
    final draft = LocalObservationDraft(
      observationId: observationId,
      assignmentId: context['assignment_id'] as String,
      assignmentVersion: context['assignment_version'] as int,
      kind: 'issue',
      stopId: execution['data']['pickup_stop_id'] as String,
      fulfillmentUnitId: order['fulfillment_unit_id'] as String,
      observedAt: observedAt,
      observedPayload: {
        'command_payload': payload,
        'pickup_execution': execution,
        'local_asset_id': ?localAssetId,
      },
      predecessorObservationIds: [?predecessorObservationId],
    );
    // Validate now and again at materialization. No caller-owned mutable maps
    // survive construction; the ORIGINAL cached versions are the authority.
    _pickupIssuePayload(
      jsonDecode(draft._json) as Map<String, dynamic>,
      context,
    );
    return LocalPickupIssueDraft._(
      _freezeJson(
        {'draft': jsonDecode(draft._json), 'context': context},
        maxBytes: 192 * 1024,
        maxDepth: 20,
      ),
    );
  }

  @override
  String toString() => 'LocalPickupIssueDraft(redacted)';
}

extension NativePickupIssues on EncryptedDriverStore {
  Future<StoredObservation> recordPickupIssue(LocalPickupIssueDraft draft) =>
      _serial(() async {
        final value = jsonDecode(draft._json) as Map<String, dynamic>;
        // Preserve an existing first context exactly, never replace its missing
        // versions with a more recent online query or a current assignment.
        _cacheContext(
          ExecutionCaptureContext.fromJson(
            value['context'] as Map<String, dynamic>,
          ),
        );
        final observation = value['draft'] as Map<String, dynamic>;
        _pickupIssuePayload(
          observation,
          value['context'] as Map<String, dynamic>,
        );
        if (_pickupPhotoId(observation) != null) {
          throw const EncryptedStoreException('PICKUP_ISSUE_CAMERA_REQUIRED');
        }
        return _recordObservation(
          LocalObservationDraft._(_freezeJson(observation)),
          null,
          null,
        );
      });

  Future<CameraCaptureIntent> preparePickupIssueCameraCapture(
    LocalPickupIssueDraft draft,
  ) => _serial(() async {
    final value = jsonDecode(draft._json) as Map<String, dynamic>;
    _cacheContext(
      ExecutionCaptureContext.fromJson(
        value['context'] as Map<String, dynamic>,
      ),
    );
    final observation = value['draft'] as Map<String, dynamic>;
    _pickupIssuePayload(observation, value['context'] as Map<String, dynamic>);
    final asset = _pickupPhotoId(observation);
    if (asset == null) {
      throw const EncryptedStoreException('PICKUP_ISSUE_PHOTO_NOT_REQUIRED');
    }
    return _prepareCameraCapture(
      LocalObservationDraft._(_freezeJson(observation)),
      asset,
    );
  });
}

String? _pickupPhotoId(Map<String, dynamic> observation) =>
    observation['observed_payload']['local_asset_id'] as String?;

void _requirePickupPhoto(Map<String, dynamic> o) {
  _pickupIssuePayload(o, o['execution_context'] as Map<String, dynamic>);
  final id = _pickupPhotoId(o), assets = o['assets'] as List;
  if (id == null ||
      assets.length != 1 ||
      assets.single['asset_id'] != id ||
      assets.single['purpose_kind'] != 'issue' ||
      assets.single['purpose_entity_id'] != o['fulfillment_unit_id']) {
    throw const EncryptedStoreException('PHOTO_TRANSFER_NOT_READY');
  }
}

Map<String, dynamic> _pickupIssuePayload(
  Map<String, dynamic> observation,
  Map<String, dynamic> context,
) {
  final action = observation['observed_payload'] as Map<String, dynamic>;
  if (action.keys.any(
        (k) => !{
          'command_payload',
          'pickup_execution',
          'local_asset_id',
        }.contains(k),
      ) ||
      action['command_payload'] is! Map<String, dynamic> ||
      action['pickup_execution'] is! Map<String, dynamic>) {
    throw const EncryptedStoreException('OBSERVATION_FORMAT_UNSUPPORTED');
  }
  final snapshot = DriverExecutionSnapshot.parse(
    action['pickup_execution'] as Map<String, dynamic>,
  );
  String scope(Map<String, dynamic> c) => _freezeJson(
    Map<String, dynamic>.from(c)
      ..remove('fetched_at')
      ..remove('expected_versions'),
  );
  if (scope(snapshot.context.toJson()) != scope(context)) {
    throw const EncryptedStoreException('PICKUP_SCOPE_MISMATCH');
  }
  final data = snapshot.toJson()['data'] as Map<String, dynamic>;
  final p = Map<String, dynamic>.from(action['command_payload'] as Map);
  if (p.keys.any(
    (k) => !{
      'delivery_id',
      'issue_type',
      'reason_code',
      'detail',
      'point',
      'affected_lines',
    }.contains(k),
  )) {
    throw const EncryptedStoreException('OBSERVATION_AUTHORITY_OVERRIDE');
  }
  if (!(p['issue_type'] == 'package' &&
              {'missing', 'damaged', 'wrong'}.contains(p['reason_code']) &&
              p['delivery_id'] != null ||
          p['issue_type'] == 'pickup_wait' &&
              p['reason_code'] == 'awaiting_goods') ||
      observation['stop_id'] != data['pickup_stop_id'] ||
      p['detail'] != null &&
          (p['detail'] is! String ||
              (p['detail'] as String).runes.length > 240)) {
    throw const EncryptedStoreException('INVALID_OBSERVED_ACTION');
  }
  final orders = data['orders'] as List;
  final selected = p['delivery_id'] == null
      ? null
      : orders.where((o) => o['delivery_id'] == p['delivery_id']).singleOrNull
            as Map?;
  if (p['delivery_id'] != null &&
      (selected == null ||
          selected['fulfillment_unit_id'] !=
              observation['fulfillment_unit_id'])) {
    throw const EncryptedStoreException('OBSERVATION_OUTSIDE_CONTEXT');
  }
  if (selected != null &&
      !(context['expected_versions'] as List).any(
        (v) =>
            v['aggregate_type'] == 'deliveries' &&
            v['id'] == selected['delivery_id'],
      )) {
    throw const EncryptedStoreException('PICKUP_ISSUE_CONTEXT_UNAVAILABLE');
  }
  p['round_id'] = context['round_id'];
  final needsPhoto = {'damaged', 'wrong'}.contains(p['reason_code']);
  if (needsPhoto) {
    if (action['local_asset_id'] is! String) {
      throw const EncryptedStoreException('PICKUP_ISSUE_PHOTO_REQUIRED');
    }
    _requireId(action['local_asset_id'] as String);
  } else if (action.containsKey('local_asset_id')) {
    throw const EncryptedStoreException('OBSERVATION_AUTHORITY_OVERRIDE');
  }
  // Shape validation only; remote IDs are supplied later by VerifyAsset.
  p['asset_ids'] = <String>[];
  validateCommandWire('ReportIssuePayload', p);
  final quantities = {
    if (selected != null)
      for (final q in selected['quantities'] as List)
        q['line_id']: q['quantity'] as num,
  };
  final seen = <String>{};
  for (final q in p['affected_lines'] as List) {
    final expected = quantities[q['line_id']];
    if (!seen.add(q['line_id'] as String) ||
        expected == null ||
        (q['quantity'] as num) > expected) {
      throw const EncryptedStoreException('INVALID_OBSERVED_QUANTITY');
    }
  }
  return p;
}
