import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../driver/driver_auth_boundary.dart';
import '../driver/evidence_camera.dart';
import 'driver_storage_lifecycle.dart';
import 'encrypted_work_store.dart';
import 'execution_query.dart';

/// Connects legacy Auth events to the NEW store only. No account import, command
/// replay, camera redirection or background/offline unlock is authorized here.
class DriverStorageAuth implements DriverAuthBoundary {
  DriverStorageAuth(this.lifecycle, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DriverStorageLifecycle lifecycle;
  final DateTime Function() _now;
  String? _bearer;
  String? _pendingBearer;
  Future<void>? _pending;
  DriverStorageLease? _lease;
  DateTime? _expiresAt;
  Timer? _expiry;
  int _generation = 0;
  int _cameraGeneration = 0;
  bool _cameraBusy = false;

  DriverStorageLease get currentLease {
    final lease = _lease;
    if (lease == null) throw const StorageLifecycleException('SESSION_LOCKED');
    lease.requireCurrent();
    return lease;
  }

  @override
  void lock() => _lock();

  void _lock({bool invalidateCamera = true}) {
    if (invalidateCamera) _cameraGeneration++;
    _generation++;
    _expiry?.cancel();
    _expiry = null;
    _bearer = null;
    _pendingBearer = null;
    _pending = null;
    _expiresAt = null;
    _lease = null;
    lifecycle.lock();
  }

  /// Uses the actual proof-screen camera adapter but never the legacy draft
  /// store or combined completion endpoint. This is local capture only. Callers
  /// must obtain the job context from fetchExecutionContext before launch.
  Future<StoredObservation?> captureExecutionPhoto({
    required String bearer,
    required LocalObservationDraft draft,
    required String assetId,
    Future<XFile?> Function() camera = openDeliveryEvidenceCamera,
  }) => _capturePhoto(
    bearer: bearer,
    prepare: (lease) => lease.prepareCameraCapture(draft, assetId: assetId),
    finish: (lease, intent, photo) =>
        lease.finishCameraCapture(intent.captureId, photo: photo),
    camera: camera,
  );

  /// Original immutable pickup report; no legacy draft or automatic submission.
  Future<StoredObservation?> capturePickupIssuePhoto({
    required String bearer,
    required LocalPickupIssueDraft draft,
    Future<XFile?> Function() camera = openDeliveryEvidenceCamera,
  }) => _capturePhoto(
    bearer: bearer,
    prepare: (lease) => lease.preparePickupIssueCameraCapture(draft),
    finish: (lease, intent, photo) =>
        lease.finishCameraCapture(intent.captureId, photo: photo),
    camera: camera,
  );

  /// G03 photo candidate, still editable and NEVER queued by camera return.
  Future<StoredPickupIssueForm?> capturePickupFormPhoto({
    required String bearer,
    required String formId,
    required DateTime observedAt,
    Future<XFile?> Function() camera = openDeliveryEvidenceCamera,
  }) => _capturePhoto(
    bearer: bearer,
    prepare: (lease) =>
        lease.preparePickupFormCamera(formId, observedAt: observedAt),
    finish: (lease, intent, photo) =>
        lease.finishPickupFormCamera(intent.captureId, photo: photo),
    camera: camera,
  );

  Future<T?> _capturePhoto<T>({
    required String bearer,
    required Future<CameraCaptureIntent> Function(DriverStorageLease) prepare,
    required Future<T> Function(
      DriverStorageLease,
      CameraCaptureIntent,
      ObservationPhoto,
    )
    finish,
    required Future<XFile?> Function() camera,
  }) async {
    if (_cameraBusy) throw const StorageLifecycleException('CAMERA_BUSY');
    _cameraBusy = true;
    Uint8List? bytes;
    ObservationPhoto? photo;
    try {
      await authenticate(bearer);
      final original = _lease!;
      final generation = _cameraGeneration;
      void guard() {
        if (generation != _cameraGeneration ||
            (_bearer != bearer && _pendingBearer != bearer)) {
          throw const StorageLifecycleException('SESSION_LOCKED');
        }
      }

      final intent = await prepare(original);
      if (!intent.isNew) {
        throw const StorageLifecycleException('CAMERA_CAPTURE_UNRESOLVED');
      }
      guard();
      original.requireCurrent();
      final file = await camera();
      guard();
      await lifecycle.awaitForeground();
      guard();
      await authenticate(
        bearer,
      ); // Reverify SAME account after background lock.
      guard();
      final current = _lease!;
      if (current.principalId != original.principalId) {
        lock();
        throw const StorageLifecycleException('SESSION_LOCKED');
      }
      if (file == null) {
        await current.cancelCameraCapture(intent.captureId);
        guard();
        return null;
      }
      // Bound before and during reading; don't trust extension or MIME labels.
      final size = await file.length();
      if (size < 1 || size > EncryptedDriverStore.maxEvidenceBytes) {
        throw const EncryptedStoreException('INVALID_EVIDENCE');
      }
      bytes = Uint8List(size);
      var offset = 0;
      await for (final chunk in file.openRead()) {
        guard();
        current.requireCurrent();
        if (offset + chunk.length > size) {
          throw const EncryptedStoreException('INVALID_EVIDENCE');
        }
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      if (offset != size) {
        throw const EncryptedStoreException('INVALID_EVIDENCE');
      }
      final mime =
          bytes.length >= 3 &&
              bytes[0] == 255 &&
              bytes[1] == 216 &&
              bytes[2] == 255
          ? 'image/jpeg'
          : bytes.length >= 8 &&
                base64Encode(bytes.sublist(0, 8)) == 'iVBORw0KGgo='
          ? 'image/png'
          : null;
      if (mime == null) throw const EncryptedStoreException('INVALID_EVIDENCE');
      photo = ObservationPhoto(
        assetId: intent.assetId,
        mimeType: mime,
        bytes: bytes,
      );
      final saved = await finish(current, intent, photo);
      guard();
      return saved; // local_recorded, NEVER server-verified/delivered.
    } finally {
      photo?.dispose();
      bytes?.fillRange(0, bytes.length, 0);
      _cameraBusy = false;
    }
  }

  Future<ExecutionCaptureContext> fetchExecutionContext({
    required String bearer,
    required String tenantId,
    required String cityId,
    required String roundId,
  }) async {
    await authenticate(bearer);
    final lease = _lease;
    if (lease == null) throw const StorageLifecycleException('SESSION_LOCKED');
    return lease.fetchExecutionContext(
      bearer: bearer,
      tenantId: tenantId,
      cityId: cityId,
      roundId: roundId,
    );
  }

  Future<AuthorizedPickup> fetchPickup({
    required String bearer,
    required String tenantId,
    required String cityId,
    required String roundId,
  }) async {
    await authenticate(bearer);
    final lease = _lease;
    if (lease == null) throw const StorageLifecycleException('SESSION_LOCKED');
    return lease.fetchPickup(
      bearer: bearer,
      tenantId: tenantId,
      cityId: cityId,
      roundId: roundId,
    );
  }

  @override
  Future<void> authenticate(String bearer) {
    if (_bearer == bearer && _expiresAt!.isAfter(_now())) {
      try {
        _lease!.requireCurrent();
        return Future<void>.value();
      } on StorageLifecycleException {
        // Background/remote lock invalidates even a cached same-token lease.
      }
    }
    if (_pendingBearer == bearer && _pending != null) return _pending!;
    _lock(invalidateCamera: _bearer != bearer);
    final ticket = _generation;
    final operation = () async {
      try {
        final expires = _lockDeadline(bearer);
        // exp is only a conservative LOCK deadline. Identity/permission still
        // comes from GET /auth/v1/user + independent server registration.
        final lease = await lifecycle.authenticate(bearer);
        if (ticket != _generation || !expires.isAfter(_now())) {
          throw const StorageLifecycleException('SESSION_LOCKED');
        }
        lease.requireCurrent();
        _lease = lease;
        _bearer = bearer;
        _expiresAt = expires;
        _expiry = Timer(expires.difference(_now()), lock);
      } catch (_) {
        if (ticket == _generation) lock();
        rethrow;
      }
    }();
    _pendingBearer = bearer;
    _pending = operation;
    operation.then<void>((_) {
      if (ticket == _generation) {
        _pending = null;
        _pendingBearer = null;
      }
    }, onError: (Object _, StackTrace _) {});
    return operation;
  }

  DateTime _lockDeadline(String bearer) {
    try {
      if (bearer.length > 16384) throw const FormatException();
      final parts = bearer.split('.');
      if (parts.length != 3) throw const FormatException();
      final payload = jsonDecode(utf8.decode(base64Url.decode(parts[1])));
      final exp = (payload as Map<String, dynamic>)['exp'];
      if (exp is! int || exp < 0 || exp > 8640000000000) {
        throw const FormatException();
      }
      final expires = DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
        isUtc: true,
      );
      final now = _now();
      if (!expires.isAfter(now)) throw const FormatException();
      // A malformed/overlong expiry cannot leave local access open indefinitely.
      final cap = now.add(const Duration(hours: 1));
      return expires.isBefore(cap) ? expires : cap;
    } catch (_) {
      throw const StorageLifecycleException('AUTH_EXPIRY_UNAVAILABLE');
    }
  }

  Future<void> dispose() {
    lock();
    return lifecycle.dispose();
  }
}
