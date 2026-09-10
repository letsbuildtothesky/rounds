part of 'encrypted_work_store.dart';

/// Encrypted checklist/intent, not a custody receipt. One per original
/// assignment revision and pickup stop. No plaintext preferences or legacy IDs.
class StoredPickupCollection {
  StoredPickupCollection._(this._json);
  final String _json;
  Map<String, dynamic> _value() => jsonDecode(_json) as Map<String, dynamic>;
  String get id => _value()['id'] as String;
  String get observationId => _value()['observation_id'] as String;
  String get arrivalObservationId => _value()['arrival_id'] as String;
  bool get confirmedLocally => _value()['observed_at'] != null;
  Set<String> get selected =>
      Set.unmodifiable((_value()['selected'] as List).cast<String>());
  DriverPickupSnapshot get snapshot =>
      DriverPickupSnapshot.parse(_value()['snapshot'] as Map<String, dynamic>);
  @override
  String toString() => 'StoredPickupCollection(redacted)';
}

const _pickupCollectionType = 'pickup_collection_v1';

extension NativePickupCollection on EncryptedDriverStore {
  Future<StoredPickupCollection> openPickupCollection(
    AuthorizedPickup pickup, {
    required String arrivalObservationId,
  }) => _serial(() async {
    final context = pickup.originalContext.toJson();
    final displayContext = pickup.snapshot.execution.context.toJson();
    String authority(Map<String, dynamic> c) => _freezeJson(
      Map<String, dynamic>.from(c)
        ..remove('fetched_at')
        ..remove('expected_versions'),
    );
    if (context['principal_id'] != _device.principalId ||
        authority(context) != authority(displayContext)) {
      throw const EncryptedStoreException('PICKUP_SCOPE_MISMATCH');
    }
    final data = pickup.snapshot.toJson()['data'] as Map<String, dynamic>;
    final stop = data['execution']['pickup_stop_id'] as String;
    final packageIds = _pickupPackages(data);
    final id =
        '${context['assignment_id']}:${context['assignment_version']}:$stop';
    final identity = _freezeJson({
      'context': context,
      'orders': data['execution']['orders'],
      'packages': {
        for (final order in data['orders'] as List)
          order['delivery_id'] as String: {
            for (final parcel in order['packages'] as List)
              parcel['package_id'] as String: parcel['contents'],
          },
      },
    });
    final prior = _pickupCollectionRow(id);
    if (prior != null) {
      final value = jsonDecode(prior) as Map<String, dynamic>;
      if (value['identity'] != identity ||
          value['arrival_id'] != arrivalObservationId) {
        throw const EncryptedStoreException('PICKUP_COLLECTION_CHANGED');
      }
      // Preserve selection, original display, intent time and ID, including
      // terminal/unknown commands. A new arrival cannot create a second pickup.
      return StoredPickupCollection._(prior);
    }
    final arrival = _pickupArrival(arrivalObservationId, context, stop);
    if (!_fenceCurrent(arrival)) {
      throw const EncryptedStoreException('EXECUTION_FENCE_CHANGED');
    }
    final value = <String, dynamic>{
      'format': 1,
      'id': id,
      'identity': identity,
      'context': context,
      'snapshot': pickup.snapshot.toJson(),
      'arrival_id': arrivalObservationId,
      'observation_id': _newPickupObservationId(),
      'device_id': _device.deviceId,
      'session_epoch': _device.epoch,
      'package_ids': packageIds,
      'selected': <String>[],
      'observed_at': null,
    };
    _savePickupCollection(value);
    await _boundary('pickup_collection_created');
    return StoredPickupCollection._(_encodePickupCollection(value));
  });

  Future<StoredPickupCollection> readPickupCollection(String id) => _serial(
    () async => StoredPickupCollection._(_requirePickupCollection(id)),
  );

  /// Explicit desired value makes repeated checkbox events idempotent.
  Future<StoredPickupCollection> setPickupPackageSelected(
    String id,
    String packageId, {
    required bool selected,
  }) => _serial(() async {
    final value =
        jsonDecode(_requirePickupCollection(id)) as Map<String, dynamic>;
    if (value['observed_at'] != null) {
      throw const EncryptedStoreException('PICKUP_ALREADY_RECORDED');
    }
    _currentPickupCollection(value);
    if (!(value['package_ids'] as List).contains(packageId)) {
      throw const EncryptedStoreException('PICKUP_PACKAGE_UNKNOWN');
    }
    final selection = (value['selected'] as List).cast<String>().toSet();
    selected ? selection.add(packageId) : selection.remove(packageId);
    value['selected'] = selection.toList()..sort();
    _savePickupCollection(value);
    await _boundary('pickup_selection_committed');
    return StoredPickupCollection._(_encodePickupCollection(value));
  });

  /// Persist intent BEFORE creating the observation. An interruption between
  /// those commits resumes the SAME ID, time, scope and complete quantities.
  /// Receipt/HTTP work is deliberately delegated to the existing command queue.
  Future<StoredObservation> confirmPickupCollection(
    String id, {
    required DateTime observedAt,
  }) => _serial(() async {
    final value =
        jsonDecode(_requirePickupCollection(id)) as Map<String, dynamic>;
    final observationId = value['observation_id'] as String;
    final existing = _observationRow(observationId);
    if (existing != null) return _inspectObservation(existing);
    _currentPickupCollection(value);
    if ((value['selected'] as List).length !=
        (value['package_ids'] as List).length) {
      throw const EncryptedStoreException('PICKUP_COLLECTION_INCOMPLETE');
    }
    final context = value['context'] as Map<String, dynamic>;
    final data = value['snapshot']['data']['execution'] as Map<String, dynamic>;
    final arrival = _pickupArrival(
      value['arrival_id'] as String,
      context,
      data['pickup_stop_id'] as String,
    );
    if (value['observed_at'] == null) {
      if (!observedAt.isUtc ||
          observedAt.isBefore(
            DateTime.parse(arrival['observed_at'] as String),
          )) {
        throw const EncryptedStoreException('PICKUP_OBSERVATION_TIME_INVALID');
      }
      value['observed_at'] = observedAt.toIso8601String();
      _savePickupCollection(value);
      await _boundary('pickup_confirmation_intent_committed');
    }
    final orders = data['orders'] as List;
    return _recordObservation(
      LocalObservationDraft(
        observationId: observationId,
        assignmentId: context['assignment_id'] as String,
        assignmentVersion: context['assignment_version'] as int,
        kind: 'pickup',
        stopId: data['pickup_stop_id'] as String,
        fulfillmentUnitId: orders.first['fulfillment_unit_id'] as String,
        observedAt: DateTime.parse(value['observed_at'] as String),
        predecessorObservationIds: [value['arrival_id'] as String],
        observedPayload: {
          'command_payload': {
            'manifest_ids': [for (final o in orders) o['manifest_id']],
            'fulfillment_unit_ids': [
              for (final o in orders) o['fulfillment_unit_id'],
            ],
            'quantities': [for (final o in orders) ...o['quantities'] as List],
          },
        },
      ),
      null,
      null,
    );
  });

  Map<String, dynamic> _pickupArrival(
    String id,
    Map<String, dynamic> context,
    String stop,
  ) {
    _requireId(id);
    final row = _observationRow(id);
    if (row == null) {
      throw const EncryptedStoreException('PICKUP_ARRIVAL_REQUIRED');
    }
    final arrival =
        jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
    if (arrival['kind'] != 'arrival' ||
        arrival['stop_id'] != stop ||
        _freezeJson(arrival['execution_context']) != _freezeJson(context) ||
        arrival['device_id'] != _device.deviceId ||
        arrival['session_epoch'] != _device.epoch) {
      throw const EncryptedStoreException('PICKUP_ARRIVAL_SCOPE_MISMATCH');
    }
    return arrival;
  }

  void _currentPickupCollection(Map<String, dynamic> value) {
    final context = value['context'] as Map<String, dynamic>;
    final arrival = _pickupArrival(
      value['arrival_id'] as String,
      context,
      value['snapshot']['data']['execution']['pickup_stop_id'] as String,
    );
    if (value['device_id'] != _device.deviceId ||
        value['session_epoch'] != _device.epoch ||
        !_fenceCurrent(arrival)) {
      throw const EncryptedStoreException('EXECUTION_FENCE_CHANGED');
    }
  }

  String? _pickupCollectionRow(String id) =>
      _db.select(
            'SELECT projection_json FROM work_cache WHERE principal_id=? AND entity_type=? AND entity_id=?',
            [_device.principalId, _pickupCollectionType, id],
          ).singleOrNull?['projection_json']
          as String?;

  String _requirePickupCollection(String id) {
    final row = _pickupCollectionRow(id);
    if (row == null) {
      throw const EncryptedStoreException('PICKUP_COLLECTION_NOT_FOUND');
    }
    return row;
  }

  void _savePickupCollection(Map<String, dynamic> value) => _commit(
    () => _db.execute(
      'INSERT INTO work_cache (principal_id,entity_type,entity_id,tenant_id,server_version,projection_json,fetched_at) VALUES (?,?,?,?,?,?,?) ON CONFLICT (principal_id,entity_type,entity_id) DO UPDATE SET projection_json=excluded.projection_json',
      [
        _device.principalId,
        _pickupCollectionType,
        value['id'],
        value['context']['tenant_id'],
        value['context']['assignment_version'],
        _encodePickupCollection(value),
        value['context']['fetched_at'],
      ],
    ),
  );
}

// Two bounded query copies (display + physical identity) and one original
// context, under the same encrypted working-store size cap; no schema change.
String _encodePickupCollection(Map<String, dynamic> value) =>
    _freezeJson(value, maxBytes: 256 * 1024);
List<String> _pickupPackages(Map<String, dynamic> data) {
  final ids = <String>[];
  for (final order in data['orders'] as List) {
    if ((order['packages'] as List).isEmpty) {
      throw const EncryptedStoreException('PICKUP_PACKAGE_DISPLAY_UNAVAILABLE');
    }
    ids.addAll([
      for (final p in order['packages'] as List) p['package_id'] as String,
    ]);
  }
  if (ids.isEmpty) {
    throw const EncryptedStoreException('PICKUP_COLLECTION_INCOMPLETE');
  }
  return ids..sort();
}

String _newPickupObservationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
