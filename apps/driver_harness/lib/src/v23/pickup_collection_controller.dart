import 'package:flutter/foundation.dart';

import 'device_wire.dart';
import 'driver_storage_lifecycle.dart';
import 'encrypted_work_store.dart';
import 'execution_query.dart';
import 'pickup_presentation.dart';

/// Foreground, original-lease coordinator. No automatic network, fake arrival,
/// receipt timer, new auth, route activation or legacy outbox writes.
class PickupCollectionController extends ChangeNotifier {
  PickupCollectionController._(this._lease, this._collection, this._clock);
  final DriverStorageLease _lease;
  final DateTime Function() _clock;
  StoredPickupCollection _collection;
  StoredExecutionCommand? command;
  String? errorCode;
  bool busy = false;
  bool _disposed = false;

  static Future<PickupCollectionController> open(
    DriverStorageLease lease,
    AuthorizedPickup pickup, {
    required String arrivalObservationId,
    DateTime Function()? clock,
  }) async {
    final collection = await lease.openPickupCollection(
      pickup,
      arrivalObservationId: arrivalObservationId,
    );
    return _load(lease, collection, clock);
  }

  /// Resume from encrypted display/selection/intent, not a fresh assignment.
  static Future<PickupCollectionController> resume(
    DriverStorageLease lease,
    String id, {
    DateTime Function()? clock,
  }) async => _load(lease, await lease.readPickupCollection(id), clock);

  static Future<PickupCollectionController> _load(
    DriverStorageLease lease,
    StoredPickupCollection collection,
    DateTime Function()? clock,
  ) async {
    final c = PickupCollectionController._(
      lease,
      collection,
      clock ?? () => DateTime.now().toUtc(),
    );
    c.command = await lease.observationCommand(collection.observationId);
    lease.requireCurrent();
    return c;
  }

  String get id => _collection.id;
  String get observationId => _collection.observationId;
  PickupPresentation get presentation =>
      PickupPresentation.fromSnapshot(_collection.snapshot);
  Set<String> get selected => _collection.selected;
  bool get frozen => _collection.confirmedLocally;
  bool get committed => command?.state == 'committed';
  bool get canConfirm =>
      !busy && !frozen && selected.length == presentation.packages.length;
  String get state =>
      command?.state ?? (frozen ? 'local_recorded' : 'collecting');

  void requireCurrent() {
    if (_disposed) throw const StorageLifecycleException('SESSION_LOCKED');
    _lease.requireCurrent();
  }

  Future<void> setSelected(String packageId, bool selected) => _run(() async {
    _collection = await _lease.setPickupPackageSelected(
      id,
      packageId,
      selected: selected,
    );
  });

  /// Same method for the first tap and explicit recovery. A pending arrival
  /// stays DEPENDENCY_UNRESOLVED; this never invents or sends an arrival for it.
  Future<void> confirm({required String bearer}) => _run(() async {
    await _lease.confirmPickupCollection(id, observedAt: _clock());
    _collection = await _lease.readPickupCollection(id);
    command = await _lease.materializeObservation(observationId);
    command = await _lease.synchronizeObservation(
      observationId,
      bearer: bearer,
    );
  });

  Future<void> _run(Future<void> Function() action) async {
    requireCurrent();
    if (busy) return; // Synchronous gate covers repeated UI taps.
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      await action();
      requireCurrent();
    } catch (error) {
      requireCurrent(); // Never publish a result into a disposed/other account.
      errorCode = switch (error) {
        final EncryptedStoreException e => e.code,
        final DeviceEnrollmentException e => e.code,
        final StorageLifecycleException e => e.code,
        _ => 'PICKUP_REQUIRES_RECOVERY',
      };
      // A checkpoint can fail AFTER committing intent/receipt. Re-read durable
      // truth, preserving the error and never silently retrying a network call.
      _collection = await _lease.readPickupCollection(id);
      command = await _lease.observationCommand(observationId);
      requireCurrent();
    } finally {
      busy = false;
      if (!_disposed) {
        try {
          _lease.requireCurrent();
          notifyListeners();
        } on StorageLifecycleException {
          /* Host Auth gate owns locked UI. */
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
