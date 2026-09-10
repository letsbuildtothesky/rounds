import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';
import 'package:rounds_driver_harness/src/v23/execution_query.dart';

import 'v23_device_registration_test.dart' as f;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_offline_observation_test.dart' as o;
import 'v23_photo_transfer_test.dart' as media;
import 'v23_pickup_issue_test.dart' as issue;

// Actual SQLCipher/files and transport with labelled Auth/camera/server doubles.
void main() {
  late media.PhotoFixture fx;
  late AuthorizedPickup pickup;
  late StoredPickupIssueForm form;
  setUp(() async {
    final snapshot = DriverPickupSnapshot.parse(issue.issueProjection());
    pickup = (snapshot: snapshot, originalContext: snapshot.execution.context);
    fx = media.PhotoFixture();
    await fx.open(context: pickup.originalContext);
    fx.intercept = (r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/ReportIssue')) {
        final w = jsonDecode(r.body) as Map<String, dynamic>;
        return f.jsonResponse(
          fx.receipts.putIfAbsent(w['command_id'], () => issue.issueReceipt(w)),
        );
      }
      return null;
    };
    form = await fx.store.openPickupIssueForm(pickup, deliveryId: e.entity);
  });
  tearDown(() => fx.close());
  Future<void> edit(String reason, [String note = '']) async {
    form = await fx.store.editPickupIssueForm(
      form.id,
      reason: reason,
      detail: note,
    );
  }

  Future<CameraCaptureIntent> prepare() =>
      fx.store.preparePickupFormCamera(form.id, observedAt: o.when);
  Future<void> finish(CameraCaptureIntent capture) async {
    final photo = ObservationPhoto(
      assetId: capture.assetId,
      mimeType: 'image/png',
      bytes: media.png,
    );
    try {
      form = await fx.store.finishPickupFormCamera(
        capture.captureId,
        photo: photo,
      );
    } finally {
      photo.dispose();
    }
  }

  Future<StoredObservation> submit() => fx.store.submitPickupIssueForm(
    form.id,
    observedAt: o.when.add(const Duration(minutes: 5)),
  );
  Future<StoredExecutionCommand> send() => fx.store.synchronizeObservation(
    form.observationId,
    transport: fx.transport,
    bearer: 'A',
  );

  test(
    'draft edits persist through reopen without observations or commands',
    () async {
      await edit('missing', '  Two boxes\nnot here  ');
      await fx.reopen();
      final restored = await fx.store.openPickupIssueForm(
        pickup,
        deliveryId: e.entity,
      );
      expect(restored.observationId, form.observationId);
      expect(restored.reason, 'missing');
      expect(restored.detail, '  Two boxes\nnot here  ');
      expect(restored.frozen, isFalse);
      expect(await fx.store.observations(), isEmpty);
      expect(await fx.store.observationCommand(form.observationId), isNull);
      expect(restored.toString(), 'StoredPickupIssueForm(redacted)');
    },
  );
  test(
    'missing submits latest exact details once without camera or asset',
    () async {
      await edit('missing', 'initial');
      await edit('missing', 'final\n😀');
      final saved = await submit();
      expect(
        saved.toJson()['observed_payload']['command_payload']['detail'],
        'final\n😀',
      );
      expect(saved.toJson()['assets'], isEmpty);
      final command = await fx.store.materializeObservation(form.observationId);
      expect((await send()).state, 'committed');
      await fx.reopen();
      await submit();
      expect(
        (await fx.store.materializeObservation(form.observationId)).commandId,
        command.commandId,
      );
      expect((await send()).state, 'committed');
      expect(
        fx.auth.requests.where((r) => r.url.path.endsWith('/ReportIssue')),
        hasLength(1),
      );
      await expectLater(edit('wrong'), e.fails('PICKUP_REPORT_FROZEN'));
    },
  );
  test(
    'photo draft stays editable; exact selected encrypted bytes bind only at submit',
    () async {
      await edit('damaged', 'before camera');
      final capture = await prepare();
      await finish(capture);
      expect(await fx.store.observations(), isEmpty);
      expect(await fx.store.pendingCameraCaptures(), isEmpty);
      await edit('damaged', 'after camera — latest detail');
      await fx.reopen();
      form = await fx.store.readPickupIssueForm(form.id);
      expect(form.photoId, capture.assetId);
      final saved = await submit();
      expect(saved.toJson()['observed_at'], o.when.toIso8601String());
      expect(
        saved.toJson()['observed_payload']['command_payload']['detail'],
        'after camera — latest detail',
      );
      expect(saved.toJson()['assets'].single['asset_id'], capture.assetId);
      final db = fx.raw();
      try {
        expect(db.select('SELECT * FROM local_assets'), hasLength(1));
      } finally {
        db.close();
      }
      await fx.store.preparePhotoTransfer(form.observationId);
      for (var i = 0; i < 3; i++) {
        await fx.store.advancePhotoTransfer(
          form.observationId,
          transport: fx.transport,
          bearer: 'A',
        );
      }
      expect(
        (await fx.store.photoTransfer(form.observationId))!.state,
        'verified',
      );
      await fx.store.materializeObservation(form.observationId);
      expect((await send()).state, 'committed');
      expect(fx.puts.single.bodyBytes, media.png);
      expect(await fx.store.readEvidence(capture.assetId), media.png);
    },
  );
  test('cancelled retake retains selection and every earlier photo', () async {
    await edit('wrong');
    final first = await prepare();
    await finish(first);
    final second = await prepare();
    await fx.store.cancelCameraCapture(second.captureId);
    form = await fx.store.readPickupIssueForm(form.id);
    expect(form.photoId, first.assetId);
    await edit('wrong', 'keep old');
    await submit();
    expect(await fx.store.readEvidence(first.assetId), media.png);
  });
  test(
    'successful retake replaces selection, never erases prior evidence',
    () async {
      await edit('damaged');
      final first = await prepare();
      await finish(first);
      final second = await prepare();
      await finish(second);
      expect(form.photoId, second.assetId);
      expect(await fx.store.readEvidence(first.assetId), media.png);
      expect(await fx.store.readEvidence(second.assetId), media.png);
      expect(
        (await submit()).toJson()['assets'].single['asset_id'],
        second.assetId,
      );
    },
  );
  test(
    'changing reason clears selection, preserves old file, requires new purpose evidence',
    () async {
      await edit('damaged');
      final first = await prepare();
      await finish(first);
      await edit('wrong');
      expect(form.photoId, isNull);
      await expectLater(submit(), e.fails('PICKUP_ISSUE_CAMERA_REQUIRED'));
      expect(await fx.store.readEvidence(first.assetId), media.png);
      await edit('missing');
      expect((await submit()).toJson()['assets'], isEmpty);
    },
  );
  test(
    'pending camera locks edit/submit/relaunch, cancellation restores edit',
    () async {
      await edit('damaged');
      final capture = await prepare();
      await fx.reopen();
      await expectLater(edit('missing'), e.fails('CAMERA_CAPTURE_UNRESOLVED'));
      await expectLater(submit(), e.fails('CAMERA_CAPTURE_UNRESOLVED'));
      await expectLater(prepare(), e.fails('CAMERA_CAPTURE_UNRESOLVED'));
      await fx.store.cancelCameraCapture(capture.captureId);
      await edit('missing');
      await submit();
    },
  );
  test(
    'unknown/long reason or note rejects; 240 unicode scalar values survive',
    () async {
      await expectLater(edit('invented'), e.fails('INVALID_OBSERVED_ACTION'));
      await expectLater(
        edit('missing', List.filled(241, '😀').join()),
        e.fails('INVALID_OBSERVED_ACTION'),
      );
      await edit('missing', List.filled(240, '😀').join());
      expect(form.detail.runes.length, 240);
      await submit();
    },
  );
  test('wrong delivery cannot create a report form', () async {
    await expectLater(
      fx.store.openPickupIssueForm(pickup, deliveryId: o.stop),
      e.fails('OBSERVATION_OUTSIDE_CONTEXT'),
    );
  });
  test(
    'a tampered photo selection cannot attach another existing capture',
    () async {
      await edit('damaged');
      final first = await prepare();
      await finish(first);
      final second = await prepare();
      await finish(second);
      fx.store.close();
      final db = fx.raw();
      try {
        final row = db
            .select(
              "SELECT projection_json FROM work_cache WHERE entity_type='pickup_issue_form_v1'",
            )
            .single;
        final value = jsonDecode(row['projection_json'] as String) as Map;
        value['photo']['asset_id'] = first.assetId;
        db.execute(
          "UPDATE work_cache SET projection_json=? WHERE entity_type='pickup_issue_form_v1'",
          [jsonEncode(value)],
        );
      } finally {
        db.close();
      }
      await fx.reopen();
      await expectLater(submit(), e.fails('PICKUP_FORM_PHOTO_CONFLICT'));
      expect(await fx.store.observations(), isEmpty);
      expect(await fx.store.readEvidence(first.assetId), media.png);
    },
  );
  test(
    'assignment change during camera retains bytes but cannot submit',
    () async {
      await edit('damaged');
      final capture = await prepare();
      await fx.store.invalidateExecutionContext(o.assignment, 1);
      await finish(capture);
      expect(await fx.store.readEvidence(capture.assetId), media.png);
      await expectLater(submit(), e.fails('EXECUTION_FENCE_CHANGED'));
      expect(await fx.store.observations(), isEmpty);
    },
  );
  for (final boundary in [
    'metadata_committed',
    'file_staged',
    'file_renamed',
    'saved_committed',
    'pickup_form_photo_saved',
  ]) {
    test(
      'interruption at $boundary preserves old choice and recovers only exact saved capture',
      () async {
        await edit('damaged');
        final first = await prepare();
        await finish(first);
        final second = await prepare();
        var failed = false;
        await fx.reopen(
          checkpoint: (name) async {
            if (name == boundary && !failed) {
              failed = true;
              throw StateError('fixture crash');
            }
          },
        );
        await expectLater(
          finish(second),
          throwsA(isA<EncryptedStoreException>()),
        );
        await fx.reopen();
        await fx.store.recoverEvidence();
        form = await fx.store.readPickupIssueForm(form.id);
        expect(await fx.store.readEvidence(first.assetId), media.png);
        if (boundary == 'metadata_committed') {
          expect(form.photoId, first.assetId);
          await expectLater(submit(), e.fails('CAMERA_CAPTURE_UNRESOLVED'));
        } else {
          expect(form.photoId, second.assetId);
          await submit();
        }
      },
    );
  }
  for (final boundary in [
    'pickup_form_submit_frozen',
    'observation_committed',
  ]) {
    test(
      'interruption at $boundary freezes same note/time/ID for retry',
      () async {
        await edit('missing', 'Original note');
        await fx.reopen(
          checkpoint: (name) async {
            if (name == boundary) throw StateError('fixture crash');
          },
        );
        await expectLater(submit(), throwsA(isA<EncryptedStoreException>()));
        await fx.reopen();
        form = await fx.store.readPickupIssueForm(form.id);
        expect(form.frozen, isTrue);
        await expectLater(
          edit('missing', 'different'),
          e.fails('PICKUP_REPORT_FROZEN'),
        );
        final saved = await fx.store.submitPickupIssueForm(
          form.id,
          observedAt: o.when.add(const Duration(hours: 1)),
        );
        expect(
          saved.toJson()['observed_at'],
          o.when.add(const Duration(minutes: 5)).toIso8601String(),
        );
        expect(saved.toJson()['observation_id'], form.observationId);
        expect(
          saved.toJson()['observed_payload']['command_payload']['detail'],
          'Original note',
        );
      },
    );
  }
  test(
    'lost report response keeps frozen draft and recovers status once',
    () async {
      await edit('missing');
      await submit();
      await fx.store.materializeObservation(form.observationId);
      final original = fx.intercept;
      fx.intercept = (r) async {
        final reply = await original!(r);
        if (r.url.path.endsWith('/ReportIssue')) {
          throw TimeoutException('fixture lost response');
        }
        return reply;
      };
      expect((await send()).state, 'unknown');
      await fx.reopen();
      fx.tick();
      expect((await send()).state, 'committed');
      expect(
        fx.auth.requests.where((r) => r.url.path.endsWith('/ReportIssue')),
        hasLength(1),
      );
    },
  );
}
