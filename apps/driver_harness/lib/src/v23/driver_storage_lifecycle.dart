import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'device_registration_client.dart';
import 'device_wire.dart';
import 'encrypted_work_store.dart';
import 'execution_query.dart';
import 'native_storage_root.dart';
import 'private_filesystem.dart';

/// Composes the tested registration, preservation and encrypted-store modules.
/// Construct BEFORE any legacy writers. main/controller connect this only in
/// the default-off debug checkpoint. Camera/background/offline policy and mobile
/// acceptance still gate cutover. Owns its registration client, not HTTP client.
class DriverStorageLifecycle with WidgetsBindingObserver {
  DriverStorageLifecycle({
    required this._registration,
    required this._secrets,
    required this._prepareLegacy,
    this._resolveRoot = nativeStorageRoot,
    this._storageCheckpoint,
    this._commandClock,
  });

  final DriverDeviceRegistrationClient _registration;
  final DeviceSecretBackend _secrets;
  final Future<void> Function(Directory) _prepareLegacy;
  final Future<Directory> Function() _resolveRoot;
  final Future<void> Function(String)? _storageCheckpoint;
  final DateTime Function()? _commandClock;
  Directory? _root;
  void Function()? _releaseOwner;
  EncryptedDriverStore? _store;
  Future<void>? _starting;
  Future<void>? _disposing;
  Future<void> _tail = Future<void>.value();
  WidgetsBinding? _binding;
  int _generation = 0;
  bool _disposed = false;
  bool _foreground = true;
  Completer<void>? _resumed;
  bool get ready => !_disposed && _root != null;

  /// Adapter must acquire exclusive legacy ownership, pause/await/close ALL old
  /// writers, then preserve. It must throw on failure; a sealed archive is not
  /// account adoption/cutover approval. Callback cannot be skipped or deferred.
  /// Concurrent startup callers share one attempt; failure may explicitly retry.
  Future<void> start() {
    _alive();
    if (_root != null) return Future<void>.value();
    if (_starting != null) return _starting!;
    final attempt = () async {
      void Function()? release;
      try {
        final root = await _resolveRoot();
        _alive();
        final fs = PrivateFilesystem();
        release = fs.acquire('${root.path}/rounds_v23_runtime.lock');
        fs.syncDirectory(root.path);
        await _prepareLegacy(root);
        _alive();
        _releaseOwner = release;
        release = null;
        _root = root;
      } on StorageLifecycleException {
        rethrow;
      } catch (_) {
        throw const StorageLifecycleException('STARTUP_REQUIRES_RECOVERY');
      } finally {
        release?.call();
      }
    }();
    _starting = attempt;
    // Do not leave an unhandled error on the cleanup branch.
    attempt.then<void>(
      (_) => _starting = null,
      onError: (Object _, StackTrace _) {
        _starting = null;
      },
    );
    return attempt;
  }

  /// Attaches once to Flutter's actual lifecycle; no network on resume.
  void observe(WidgetsBinding binding) {
    _alive();
    if (_binding != null && !identical(_binding, binding)) {
      throw const StorageLifecycleException('OBSERVER_ALREADY_ATTACHED');
    }
    if (_binding != null) return;
    _binding = binding;
    binding.addObserver(this);
    didChangeAppLifecycleState(
      binding.lifecycleState ?? AppLifecycleState.detached,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _resumed?.complete();
      _resumed = null;
    }
    if (!_foreground) lock();
  }

  /// Camera plugins may resolve just before Flutter emits resumed. Never keep
  /// the database open in the background or authenticate there to avoid a race.
  Future<void> awaitForeground() async {
    _alive();
    if (!_foreground) {
      try {
        await (_resumed ??= Completer<void>()).future.timeout(
          const Duration(seconds: 10),
        );
      } on TimeoutException {
        throw const StorageLifecycleException('SESSION_LOCKED');
      }
    }
    _alive();
    if (!_foreground) throw const StorageLifecycleException('SESSION_LOCKED');
  }

  /// Call on sign-out, Auth expiry, account change or remote revocation BEFORE
  /// awaiting token/UI work. Old leases and in-flight operations stay invalid
  /// even if the same principal subsequently signs in again. Bytes are retained.
  void lock() {
    _generation++;
    final store = _store;
    _store = null;
    try {
      _registration.lock();
    } finally {
      store?.close();
    }
  }

  /// Verified subject comes only from registration's Auth-server check. Never
  /// infer account identity from a cached driver ID or preserved legacy rows.
  Future<DriverStorageLease> authenticate(String bearer) {
    _alive();
    lock(); // Account A locks synchronously, even when B authentication fails.
    final ticket = _generation;
    final operation = _tail.then((_) async {
      _check(ticket);
      if (_root == null) {
        throw const StorageLifecycleException('STARTUP_NOT_READY');
      }
      EncryptedDriverStore? opened;
      try {
        final device = await _registration.ensureSession(bearer);
        _check(ticket);
        opened = await EncryptedDriverStore.open(
          device: device,
          privateParent: _root!,
          secrets: _secrets,
          checkpoint: _storageCheckpoint,
          commandClock: _commandClock,
        );
        _check(ticket);
        // Recovery must finish before giving a caller any access. Recovery
        // findings remain explicit; they do not imply upload/verified success.
        final recovery = await opened.recoverEvidence();
        _check(ticket);
        _store = opened;
        return DriverStorageLease._(
          this,
          opened,
          ticket,
          device.principalId,
          recovery,
          device,
        );
      } catch (_) {
        opened?.close();
        if (ticket == _generation) lock();
        rethrow;
      }
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  /// Explicit action only. Lost response leaves the registration client's
  /// durable revoke_pending latch. No automatic retry/secret rotation here.
  Future<void> revoke(String bearer) {
    _alive();
    lock();
    final ticket = _generation;
    final operation = _tail.then((_) async {
      _check(ticket);
      if (_root == null) {
        throw const StorageLifecycleException('STARTUP_NOT_READY');
      }
      await _registration.revoke(bearer);
      _check(ticket);
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  void _alive() {
    if (_disposed) throw const StorageLifecycleException('DISPOSED');
  }

  void _check(int ticket) {
    _alive();
    if (ticket != _generation || !_foreground) {
      throw const StorageLifecycleException('SESSION_LOCKED');
    }
  }

  /// Locks synchronously. Await completion before replacing the runtime owner:
  /// an in-flight native key write/registration must settle before lock release.
  Future<void> dispose() {
    if (_disposing != null) return _disposing!;
    lock();
    _disposed = true;
    _resumed?.complete();
    _resumed = null;
    _binding?.removeObserver(this);
    _binding = null;
    _registration.dispose();
    final release = _releaseOwner;
    _releaseOwner = null;
    return _disposing = Future.wait<void>([
      _tail,
      if (_starting != null)
        _starting!.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    ]).then<void>((_) => release?.call());
  }
}

/// A capture started under A cannot be saved via B's new handle. UI/camera and
/// future sender must hold their original lease, never look up 'current store'
/// after an await. No raw DB, filesystem path, key or transport headers exposed.
class DriverStorageLease {
  DriverStorageLease._(
    this._owner,
    this._store,
    this._ticket,
    this.principalId,
    this.recovery,
    this._device,
  );
  final DriverStorageLifecycle _owner;
  final EncryptedDriverStore _store;
  final int _ticket;
  final String principalId;
  final EvidenceRecoveryReport recovery;
  final RegisteredDriverDevice _device;
  int _queryGeneration = 0;
  int _issueQueryGeneration = 0;

  /// Original committed receipt -> current same-owner read. No context cache,
  /// queue, photograph or expected-version updates. Explicit foreground only.
  Future<DriverPickupIssueSnapshot> fetchPickupIssue({
    required String bearer,
    required String observationId,
  }) async {
    requireCurrent();
    final query = ++_issueQueryGeneration;
    try {
      final report = await _store.reportedPickupIssue(observationId);
      requireCurrent();
      if (query != _issueQueryGeneration) {
        throw const StorageLifecycleException('QUERY_SUPERSEDED');
      }
      final snapshot = await _owner._registration.fetchPickupIssue(
        bearer: bearer,
        device: _device,
        report: report,
      );
      requireCurrent();
      if (query != _issueQueryGeneration) {
        throw const StorageLifecycleException('QUERY_SUPERSEDED');
      }
      return snapshot;
    } on DeviceEnrollmentException catch (error) {
      // A late denial from an old lease must not lock a newly signed-in owner.
      requireCurrent();
      if (error.code == 'UNAUTHENTICATED' || error.code == 'NOT_AUTHORIZED') {
        _owner.lock();
      }
      rethrow;
    }
  }

  /// Existing Auth-bound lease -> exact server query -> original encrypted
  /// context. This does not discover work from legacy IDs or start a camera.
  Future<ExecutionCaptureContext> fetchExecutionContext({
    required String bearer,
    required String tenantId,
    required String cityId,
    required String roundId,
  }) async {
    requireCurrent();
    final query = ++_queryGeneration;
    try {
      final snapshot = await _owner._registration.fetchExecution(
        bearer: bearer,
        device: _device,
        tenantId: tenantId,
        cityId: cityId,
        roundId: roundId,
      );
      requireCurrent();
      if (query != _queryGeneration) {
        throw const StorageLifecycleException('QUERY_SUPERSEDED');
      }
      final context = await _store.acceptOnlineExecutionContext(
        snapshot.context,
      );
      requireCurrent();
      if (query != _queryGeneration) {
        throw const StorageLifecycleException('QUERY_SUPERSEDED');
      }
      return context;
    } on DeviceEnrollmentException catch (error) {
      if (error.code == 'UNAUTHENTICATED' || error.code == 'NOT_AUTHORIZED') {
        _owner.lock();
      }
      rethrow;
    }
  }

  /// Read fresh labels, but retain the FIRST encrypted execution fence. A
  /// display refresh must not silently rebase a pending command's authority.
  Future<AuthorizedPickup> fetchPickup({
    required String bearer,
    required String tenantId,
    required String cityId,
    required String roundId,
  }) async {
    requireCurrent();
    final query = ++_queryGeneration;
    try {
      final snapshot = await _owner._registration.fetchPickup(
        bearer: bearer,
        device: _device,
        tenantId: tenantId,
        cityId: cityId,
        roundId: roundId,
      );
      requireCurrent();
      if (query != _queryGeneration) {
        throw const StorageLifecycleException('QUERY_SUPERSEDED');
      }
      final originalContext = await _store.acceptOnlineExecutionContext(
        snapshot.execution.context,
      );
      requireCurrent();
      if (query != _queryGeneration) {
        throw const StorageLifecycleException('QUERY_SUPERSEDED');
      }
      return (snapshot: snapshot, originalContext: originalContext);
    } on DeviceEnrollmentException catch (error) {
      if (error.code == 'UNAUTHENTICATED' || error.code == 'NOT_AUTHORIZED') {
        _owner.lock();
      }
      rethrow;
    }
  }

  /// Allows the Auth adapter to test its cached lease without opening evidence.
  void requireCurrent() {
    _owner._check(_ticket);
    try {
      _device.requireCurrentSession();
    } on DeviceEnrollmentException {
      // Transport denial also invalidates a cached same-token Auth lease.
      throw const StorageLifecycleException('SESSION_LOCKED');
    }
  }

  Future<void> cacheExecutionContext(ExecutionCaptureContext context) async {
    requireCurrent();
    await _store.cacheExecutionContext(context);
    requireCurrent();
  }

  Future<void> invalidateExecutionContext(
    String assignmentId,
    int version,
  ) async {
    requireCurrent();
    await _store.invalidateExecutionContext(assignmentId, version);
    requireCurrent();
  }

  Future<StoredObservation> recordObservation(
    LocalObservationDraft draft, {
    ObservationPhoto? photo,
  }) async {
    requireCurrent();
    final result = await _store.recordObservation(draft, photo: photo);
    requireCurrent();
    return result;
  }

  Future<StoredObservation> recordPickupIssue(
    LocalPickupIssueDraft draft,
  ) async {
    requireCurrent();
    final result = await _store.recordPickupIssue(draft);
    requireCurrent();
    return result;
  }

  Future<StoredPickupCollection> openPickupCollection(
    AuthorizedPickup pickup, {
    required String arrivalObservationId,
  }) async {
    requireCurrent();
    final result = await _store.openPickupCollection(
      pickup,
      arrivalObservationId: arrivalObservationId,
    );
    requireCurrent();
    return result;
  }

  Future<StoredPickupIssueForm> openPickupIssueForm(
    AuthorizedPickup pickup, {
    required String deliveryId,
  }) async {
    requireCurrent();
    final value = await _store.openPickupIssueForm(
      pickup,
      deliveryId: deliveryId,
    );
    requireCurrent();
    return value;
  }

  Future<StoredPickupIssueForm> readPickupIssueForm(String id) async {
    requireCurrent();
    final value = await _store.readPickupIssueForm(id);
    requireCurrent();
    return value;
  }

  Future<StoredPickupIssueForm> editPickupIssueForm(
    String id, {
    required String reason,
    required String detail,
  }) async {
    requireCurrent();
    final value = await _store.editPickupIssueForm(
      id,
      reason: reason,
      detail: detail,
    );
    requireCurrent();
    return value;
  }

  Future<CameraCaptureIntent> preparePickupFormCamera(
    String id, {
    required DateTime observedAt,
  }) async {
    requireCurrent();
    final value = await _store.preparePickupFormCamera(
      id,
      observedAt: observedAt,
    );
    requireCurrent();
    return value;
  }

  Future<StoredPickupIssueForm> finishPickupFormCamera(
    String id, {
    required ObservationPhoto photo,
  }) async {
    requireCurrent();
    final value = await _store.finishPickupFormCamera(id, photo: photo);
    requireCurrent();
    return value;
  }

  Future<StoredObservation> submitPickupIssueForm(
    String id, {
    required DateTime observedAt,
  }) async {
    requireCurrent();
    final value = await _store.submitPickupIssueForm(
      id,
      observedAt: observedAt,
    );
    requireCurrent();
    return value;
  }

  Future<StoredPickupCollection> readPickupCollection(String id) async {
    requireCurrent();
    final result = await _store.readPickupCollection(id);
    requireCurrent();
    return result;
  }

  Future<StoredPickupCollection> setPickupPackageSelected(
    String id,
    String packageId, {
    required bool selected,
  }) async {
    requireCurrent();
    final result = await _store.setPickupPackageSelected(
      id,
      packageId,
      selected: selected,
    );
    requireCurrent();
    return result;
  }

  Future<StoredObservation> confirmPickupCollection(
    String id, {
    required DateTime observedAt,
  }) async {
    requireCurrent();
    final result = await _store.confirmPickupCollection(
      id,
      observedAt: observedAt,
    );
    requireCurrent();
    return result;
  }

  Future<CameraCaptureIntent> prepareCameraCapture(
    LocalObservationDraft draft, {
    required String assetId,
  }) async {
    requireCurrent();
    final result = await _store.prepareCameraCapture(draft, assetId: assetId);
    requireCurrent();
    return result;
  }

  Future<CameraCaptureIntent> preparePickupIssueCameraCapture(
    LocalPickupIssueDraft draft,
  ) async {
    requireCurrent();
    final result = await _store.preparePickupIssueCameraCapture(draft);
    requireCurrent();
    return result;
  }

  Future<void> cancelCameraCapture(String captureId) async {
    requireCurrent();
    await _store.cancelCameraCapture(captureId);
    requireCurrent();
  }

  Future<List<CameraCaptureIntent>> pendingCameraCaptures() async {
    requireCurrent();
    final result = await _store.pendingCameraCaptures();
    requireCurrent();
    return result;
  }

  Future<StoredObservation> finishCameraCapture(
    String captureId, {
    required ObservationPhoto photo,
  }) async {
    requireCurrent();
    final result = await _store.finishCameraCapture(captureId, photo: photo);
    requireCurrent();
    return result;
  }

  Future<StoredObservation> readObservation(String observationId) async {
    requireCurrent();
    final result = await _store.readObservation(observationId);
    requireCurrent();
    return result;
  }

  Future<StoredExecutionCommand> materializeObservation(
    String observationId,
  ) async {
    requireCurrent();
    final result = await _store.materializeObservation(observationId);
    requireCurrent();
    return result;
  }

  Future<StoredExecutionCommand?> observationCommand(
    String observationId,
  ) async {
    requireCurrent();
    final result = await _store.observationCommand(observationId);
    requireCurrent();
    return result;
  }

  Future<StoredExecutionCommand> synchronizeObservation(
    String observationId, {
    required String bearer,
  }) async {
    requireCurrent();
    final result = await _store.synchronizeObservation(
      observationId,
      transport: _owner._registration,
      bearer: bearer,
    );
    requireCurrent();
    return result;
  }

  Future<StoredPhotoTransfer> preparePhotoTransfer(String observationId) async {
    requireCurrent();
    final result = await _store.preparePhotoTransfer(observationId);
    requireCurrent();
    return result;
  }

  Future<StoredPhotoTransfer?> photoTransfer(String observationId) async {
    requireCurrent();
    final result = await _store.photoTransfer(observationId);
    requireCurrent();
    return result;
  }

  Future<StoredPhotoTransfer> advancePhotoTransfer(
    String observationId, {
    required String bearer,
  }) async {
    requireCurrent();
    final result = await _store.advancePhotoTransfer(
      observationId,
      transport: _owner._registration,
      bearer: bearer,
    );
    requireCurrent();
    return result;
  }

  Future<List<StoredObservation>> observations({
    int limit = 100,
    int offset = 0,
  }) async {
    requireCurrent();
    final result = await _store.observations(limit: limit, offset: offset);
    requireCurrent();
    return result;
  }

  Future<StoredEvidence> saveEvidence({
    required String assetId,
    required String purposeKind,
    required String purposeEntityId,
    required String mimeType,
    required DateTime capturedAt,
    required Uint8List bytes,
  }) async {
    _owner._check(_ticket);
    final result = await _store.saveEvidence(
      assetId: assetId,
      purposeKind: purposeKind,
      purposeEntityId: purposeEntityId,
      mimeType: mimeType,
      capturedAt: capturedAt,
      bytes: bytes,
    );
    _owner._check(_ticket);
    return result;
  }

  Future<Uint8List> readEvidence(String assetId) async {
    _owner._check(_ticket);
    final bytes = await _store.readEvidence(assetId);
    try {
      _owner._check(_ticket);
      return bytes;
    } catch (_) {
      bytes.fillRange(0, bytes.length, 0);
      rethrow;
    }
  }
}

class StorageLifecycleException implements Exception {
  const StorageLifecycleException(this.code);
  final String code;
  @override
  String toString() => 'StorageLifecycleException($code)';
}
