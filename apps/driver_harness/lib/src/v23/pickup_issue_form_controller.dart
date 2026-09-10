import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../driver/evidence_camera.dart';
import 'device_wire.dart';
import 'driver_storage_auth.dart';
import 'driver_storage_lifecycle.dart';
import 'encrypted_work_store.dart';
import 'execution_query.dart';
import 'pickup_issue_recovery.dart';
import 'pickup_presentation.dart';

/// G03 draft -> explicit submit -> actual existing media/command transports.
/// No background auto-send, Operations decision or legacy-route activation.
class PickupIssueFormController extends ChangeNotifier {
  PickupIssueFormController._(
    this._auth,
    this._bearer,
    this._form,
    this._principal,
    this._clock,
  );
  final DriverStorageAuth _auth;
  final String Function() _bearer;
  final String _principal;
  final DateTime Function() _clock;
  StoredPickupIssueForm _form;
  StoredExecutionCommand? command;
  StoredPhotoTransfer? transfer;
  String? errorCode;
  bool busy = false, _disposed = false;
  Future<void> _edits = Future.value();
  String? _editError;
  Uint8List? preview;
  String? _previewId;
  PickupIssueRecovery _recovery = const PickupIssueRecovery();
  DriverStorageLease? _recoveryLease;
  Future<void>? _replyRequest;

  PickupIssueRecovery get recovery {
    requireCurrent();
    try {
      _recoveryLease?.requireCurrent();
    } on StorageLifecycleException {
      // A completed read belongs to its Auth generation too. Reauthentication
      // cannot revive last session's cached instructions as a current reply.
      _recovery = const PickupIssueRecovery();
      _recoveryLease = null;
    }
    return _recovery;
  }

  StoredPickupIssueForm get form => _form;
  bool get committed => command?.state == 'committed';
  String get state =>
      command?.state ??
      transfer?.state ??
      (_form.frozen ? 'local_recorded' : 'draft');
  DriverStorageLease get _lease {
    if (_disposed) throw const StorageLifecycleException('SESSION_LOCKED');
    final lease = _auth.currentLease;
    if (lease.principalId != _principal) {
      throw const StorageLifecycleException('SESSION_LOCKED');
    }
    return lease;
  }

  void requireCurrent() => _lease.requireCurrent();

  /// Explicit read-only refresh of the committed ORIGINAL report. Coalesce
  /// taps; never retry submission, rebase work or follow a new assignment here.
  Future<void> refreshInstructions() {
    requireCurrent();
    if (!committed) {
      throw const EncryptedStoreException('ISSUE_NOT_REPORTED');
    }
    if (_replyRequest != null) return _replyRequest!;
    final lease = _lease;
    final previous = recovery.snapshot;
    _recoveryLease = lease;
    final request = Future<void>.microtask(
      () => _readInstructions(lease),
    ).whenComplete(() => _replyRequest = null);
    _replyRequest = request;
    _recovery = PickupIssueRecovery(
      phase: PickupIssueReadPhase.loading,
      snapshot: previous,
    );
    _notifyCurrent();
    return request;
  }

  Future<void> _readInstructions(DriverStorageLease lease) async {
    // Pin this Auth generation before scheduling, not only across the await.
    final previous = _recovery.snapshot;
    try {
      lease.requireCurrent();
      requireCurrent();
      final result = await lease.fetchPickupIssue(
        bearer: _bearer(),
        observationId: form.observationId,
      );
      lease.requireCurrent();
      requireCurrent();
      final data = result.toJson()['data'] as Map<String, dynamic>;
      final previousVersion =
          previous?.toJson()['data']['issue_version'] as int?;
      if (previousVersion != null && data['issue_version'] < previousVersion) {
        throw const DeviceEnrollmentException('SOURCE_STALE');
      }
      _recovery = PickupIssueRecovery(
        phase: (data['decisions'] as List).isEmpty
            ? PickupIssueReadPhase.waiting
            : PickupIssueReadPhase.instructions,
        snapshot: result,
      );
    } catch (error) {
      try {
        lease.requireCurrent();
        requireCurrent();
      } catch (_) {
        // Also discard a late response after sign-out + SAME-account sign-in.
        _recovery = const PickupIssueRecovery();
        rethrow;
      }
      _recovery = PickupIssueRecovery(
        phase: PickupIssueReadPhase.failed,
        snapshot: previous,
        errorCode: _code(error),
      );
    } finally {
      _notifyCurrent();
    }
  }

  static Future<PickupIssueFormController> open(
    DriverStorageAuth auth,
    String Function() bearer,
    AuthorizedPickup pickup, {
    required String deliveryId,
    DateTime Function()? clock,
  }) async {
    await auth.authenticate(bearer());
    final lease = auth.currentLease;
    final form = await lease.openPickupIssueForm(
      pickup,
      deliveryId: deliveryId,
    );
    return _load(auth, bearer, form, lease.principalId, clock);
  }

  static Future<PickupIssueFormController> resume(
    DriverStorageAuth auth,
    String Function() bearer,
    String id, {
    DateTime Function()? clock,
  }) async {
    await auth.authenticate(bearer());
    final lease = auth.currentLease;
    final form = await lease.readPickupIssueForm(id);
    return _load(auth, bearer, form, lease.principalId, clock);
  }

  static Future<PickupIssueFormController> _load(
    DriverStorageAuth auth,
    String Function() bearer,
    StoredPickupIssueForm form,
    String principal,
    DateTime Function()? clock,
  ) async {
    final data = form.snapshot.toJson()['data'] as Map;
    final order =
        (data['orders'] as List).singleWhere(
              (order) => order['delivery_id'] == form.deliveryId,
            )
            as Map;
    if ((order['packages'] as List).isEmpty) {
      throw const PickupPresentationException(
        'PICKUP_PACKAGE_DISPLAY_UNAVAILABLE',
      );
    }
    final c = PickupIssueFormController._(
      auth,
      bearer,
      form,
      principal,
      clock ?? () => DateTime.now().toUtc(),
    );
    await c._reload();
    return c;
  }

  Future<void> _reload() async {
    final lease = _lease;
    final fresh = await lease.readPickupIssueForm(form.id);
    final nextCommand = await lease.observationCommand(form.observationId);
    final nextTransfer = await lease.photoTransfer(form.observationId);
    Uint8List? bytes;
    try {
      if (fresh.photoId != _previewId && fresh.photoId != null) {
        bytes = await lease.readEvidence(fresh.photoId!);
      }
      requireCurrent();
      if (fresh.photoId != _previewId) {
        preview?.fillRange(0, preview!.length, 0);
        preview = bytes;
        bytes = null;
        _previewId = fresh.photoId;
      }
      _form = fresh;
      command = nextCommand;
      transfer = nextTransfer;
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
    }
  }

  Future<void> choose(String reason) => _run(() async {
    _form = await _lease.editPickupIssueForm(
      form.id,
      reason: reason,
      detail: reason == form.reason ? form.detail : '',
    );
  });

  /// Queue every text edit; submit waits for the last durable save. A failed
  /// write must not silently submit the previously saved note.
  Future<void> editDetail(String detail) {
    requireCurrent();
    if (busy || form.frozen || form.reason == null) return Future.value();
    final lease = _lease, id = form.id, reason = form.reason!;
    _edits = _edits.then((_) async {
      try {
        final saved = await lease.editPickupIssueForm(
          id,
          reason: reason,
          detail: detail,
        );
        requireCurrent();
        _form = saved;
        _editError = null;
        errorCode = null;
      } catch (error) {
        _editError = _code(error);
        errorCode = _editError;
      }
      _notifyCurrent();
    });
    return _edits;
  }

  Future<void> capture({
    Future<XFile?> Function() camera = openDeliveryEvidenceCamera,
  }) => _run(() async {
    await _auth.capturePickupFormPhoto(
      bearer: _bearer(),
      formId: form.id,
      observedAt: _clock(),
      camera: camera,
    );
  });
  Future<void> submit() => _run(() async {
    // An existing uncertain command must still use original status recovery
    // after reassignment. Re-entering draft validation would incorrectly block
    // even the read-only probe. The sender itself forbids any stale resubmit.
    if (await _lease.observationCommand(form.observationId) != null) {
      command = await _lease.synchronizeObservation(
        form.observationId,
        bearer: _bearer(),
      );
      return;
    }
    await _lease.submitPickupIssueForm(form.id, observedAt: _clock());
    await _send();
  });
  Future<void> _send() async {
    // At most reserve/PUT/verify; do not spin or bypass retry due times after
    // uncertainty. Repeated submit resumes the SAME frozen report and IDs.
    if (form.photoId != null) {
      var t = await _lease.preparePhotoTransfer(form.observationId);
      for (
        var step = 0;
        step < 4 && {'reserve', 'upload', 'verify'}.contains(t.state);
        step++
      ) {
        final before = t.state;
        t = await _lease.advancePhotoTransfer(
          form.observationId,
          bearer: _bearer(),
        );
        if (t.state == before) break;
      }
      transfer = t;
      if (t.state != 'verified') return;
    }
    command = await _lease.materializeObservation(form.observationId);
    command = await _lease.synchronizeObservation(
      form.observationId,
      bearer: _bearer(),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    requireCurrent();
    if (busy) return;
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      await _edits;
      requireCurrent();
      if (_editError != null) throw EncryptedStoreException(_editError!);
      await action();
      requireCurrent();
    } catch (error) {
      requireCurrent();
      errorCode = _code(error);
    } finally {
      try {
        await _reload();
      } catch (error) {
        errorCode ??= _code(error);
      }
      busy = false;
      _notifyCurrent();
    }
  }

  void _notifyCurrent() {
    if (_disposed) return;
    try {
      requireCurrent();
      notifyListeners();
    } on StorageLifecycleException {
      _recovery = const PickupIssueRecovery();
      preview?.fillRange(0, preview!.length, 0);
      preview = null;
      _previewId = null;
      // Parent Auth gate owns removal of inaccessible UI.
    }
  }

  static String _code(Object error) => switch (error) {
    final EncryptedStoreException e => e.code,
    final StorageLifecycleException e => e.code,
    final DeviceEnrollmentException e => e.code,
    _ => 'PICKUP_REPORT_REQUIRES_RECOVERY',
  };
  @override
  void dispose() {
    _disposed = true;
    _recovery = const PickupIssueRecovery();
    preview?.fillRange(0, preview!.length, 0);
    preview = null;
    super.dispose();
  }
}
