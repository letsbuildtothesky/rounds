import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_auth.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';
import 'package:rounds_driver_harness/src/v23/execution_query.dart';

import 'v23_device_registration_test.dart' as f;
import 'v23_driver_auth_test.dart' as a;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_execution_query_test.dart' as query;
import 'v23_offline_command_test.dart' as q;
import 'v23_offline_observation_test.dart' as o;
import 'v23_photo_transfer_test.dart' as media;
import 'v23_pickup_issue_test.dart' as issue;

// Actual SQLCipher/AES-GCM/files/command transport; camera bytes, Auth, vault,
// and server are explicit fixtures, not real-phone/provider acceptance.
void main() {
  late media.PhotoFixture fx;
  late AuthorizedPickup pickup;
  final obs = q.id(701), asset = media.photoId;
  setUp(() async {
    final snapshot = DriverPickupSnapshot.parse(issue.issueProjection());
    pickup = (snapshot: snapshot, originalContext: snapshot.execution.context);
    fx = media.PhotoFixture();
    await fx.open(context: pickup.originalContext);
    fx.intercept = (r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/ReportIssue')) {
        final w = jsonDecode(r.body) as Map<String, dynamic>;
        return f.jsonResponse(
          fx.receipts.putIfAbsent(
            w['command_id'] as String,
            () => issue.issueReceipt(w),
          ),
        );
      }
      return null;
    };
  });
  tearDown(() => fx.close());

  LocalPickupIssueDraft draft({
    String? id,
    String? localAsset,
    String reason = 'damaged',
    String? parent,
  }) => LocalPickupIssueDraft(
    pickup: pickup,
    observationId: id ?? obs,
    observedAt: o.when,
    reason: reason,
    deliveryId: e.entity,
    localAssetId: localAsset ?? asset,
    detail: '  Broken label\nKeep exact.  ',
    affectedLines: [
      {'line_id': query.manifest, 'quantity': 2},
    ],
    predecessorObservationId: parent,
  );
  Future<StoredObservation> capture({
    LocalPickupIssueDraft? input,
    String? localAsset,
  }) async {
    final intent = await fx.store.preparePickupIssueCameraCapture(
      input ?? draft(),
    );
    final photo = ObservationPhoto(
      assetId: localAsset ?? asset,
      mimeType: 'image/png',
      bytes: media.png,
    );
    try {
      return await fx.store.finishCameraCapture(intent.captureId, photo: photo);
    } finally {
      photo.dispose();
    }
  }

  Future<StoredPhotoTransfer> advance() =>
      fx.store.advancePhotoTransfer(obs, transport: fx.transport, bearer: 'A');
  Future<void> verify() async {
    await fx.store.preparePhotoTransfer(obs);
    expect((await advance()).state, 'upload');
    expect((await advance()).state, 'verify');
    expect((await advance()).state, 'verified');
  }

  Future<StoredExecutionCommand> send() => fx.store.synchronizeObservation(
    obs,
    transport: fx.transport,
    bearer: 'A',
  );
  List<Map<String, dynamic>> requests(String type) => fx.auth.requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/$type'))
      .map((r) => jsonDecode(r.body) as Map<String, dynamic>)
      .toList();

  for (final reason in ['damaged', 'wrong']) {
    test(
      '$reason camera -> private transfer -> verified report; no fake arrival/handoff; TS checks actual bytes',
      () async {
        final saved = await capture(input: draft(reason: reason));
        expect(saved.state, 'local_recorded');
        expect(saved.toJson()['kind'], 'issue');
        await expectLater(
          fx.store.materializeObservation(obs),
          e.fails('ASSET_NOT_VERIFIED'),
        );
        await verify();
        expect(await fx.store.observationCommand(obs), isNull);
        expect(fx.puts.single.bodyBytes, media.png);
        expect(
          fx.puts.single.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
        final reserve = requests('ReserveAsset').single;
        expect(reserve['occurred_at'], o.when.toIso8601String());
        expect(reserve['expected_versions'], isEmpty);
        expect(reserve['payload']['purpose_entity_id'], e.entity);
        expect(reserve['payload']['kind'], 'issue_photo');
        expect(reserve['payload']['pickup_context'], {
          'round_id': e.entity,
          'pickup_stop_id': o.stop,
          'fulfillment_unit_id': e.entity,
          'manifest_id': query.manifest,
          'execution_fence': {
            'assignment_id': o.assignment,
            'assignment_version': 1,
            'observation_id': obs,
          },
        });
        final command = await fx.store.materializeObservation(obs);
        expect((await send()).state, 'committed');
        final report = requests('ReportIssue').single;
        expect(report['payload']['asset_ids'], [media.serverAsset]);
        expect(report['payload']['reason_code'], reason);
        expect(report['payload']['detail'], '  Broken label\nKeep exact.  ');
        expect(
          report['execution_fence'],
          reserve['payload']['pickup_context']['execution_fence'],
        );
        expect(report['occurred_at'], reserve['occurred_at']);
        await fx.reopen();
        expect(
          (await fx.store.materializeObservation(obs)).commandId,
          command.commandId,
        );
        expect((await fx.store.photoTransfer(obs))!.state, 'verified');
        expect((await send()).state, 'committed');
        expect(requests('ReportIssue'), hasLength(1));
        expect(await fx.store.readEvidence(asset), media.png);
        final db = fx.raw();
        try {
          expect(db.select('SELECT * FROM local_observations'), hasLength(1));
          expect(db.select('SELECT * FROM observation_bindings'), isEmpty);
          expect(db.select('SELECT * FROM command_dependencies'), hasLength(2));
          final rows = db
              .select(
                'SELECT command_type,payload_json,request_hash,server_receipt_json FROM pending_commands',
              )
              .map((r) => Map.from(r))
              .toList();
          final cache = db
              .select('SELECT projection_json FROM work_cache')
              .map((r) => r['projection_json'])
              .join();
          expect(cache, isNot(contains('ephemeral-secret')));
          expect(jsonEncode(rows), isNot(contains('upload_url')));
          final t =
              jsonDecode(
                    db
                            .select(
                              "SELECT projection_json FROM work_cache WHERE entity_type='pod_transfer_v1'",
                            )
                            .single['projection_json']
                        as String,
                  )
                  as Map;
          expect(t['report_binding']['command_id'], command.commandId);
          expect(
            t['report_binding']['payload_pointer'],
            '/payload/asset_ids/0',
          );
          expect(t['report_binding']['resolved_value'], media.serverAsset);
          expect(
            db.select('SELECT state FROM local_assets').single['state'],
            'saved',
          );
          final probe = Process.runSync('node', [
            '--import',
            'tsx',
            'services/api/test/v23/native-command-contract-probe.ts',
            base64Encode(utf8.encode(jsonEncode(rows))),
          ], workingDirectory: '../..');
          expect(probe.exitCode, 0, reason: '${probe.stdout}\n${probe.stderr}');
        } finally {
          db.close();
        }
      },
    );
  }

  test('photo-required draft cannot be recorded without camera', () async {
    await expectLater(
      fx.store.recordPickupIssue(draft()),
      e.fails('PICKUP_ISSUE_CAMERA_REQUIRED'),
    );
    expect(await fx.store.observationCommand(obs), isNull);
  });
  test('cancelled retake preserves earlier saved encrypted photo', () async {
    await capture();
    final retake = await fx.store.preparePickupIssueCameraCapture(
      draft(id: q.id(702), localAsset: q.id(93)),
    );
    await fx.store.cancelCameraCapture(retake.captureId);
    expect(await fx.store.readEvidence(asset), media.png);
    expect((await fx.store.readObservation(obs)).state, 'local_recorded');
  });
  test(
    'camera return must match original local asset; unresolved intent blocks relaunch',
    () async {
      await fx.store.preparePickupIssueCameraCapture(draft());
      await expectLater(
        capture(localAsset: q.id(93)),
        e.fails('CAMERA_INTENT_CONFLICT'),
      );
      await expectLater(
        fx.store.preparePickupIssueCameraCapture(
          draft(id: q.id(702), localAsset: q.id(93)),
        ),
        e.fails('CAMERA_CAPTURE_UNRESOLVED'),
      );
      await expectLater(
        fx.store.preparePhotoTransfer(obs),
        e.fails('OBSERVATION_NOT_FOUND'),
      );
    },
  );
  test('photo reference is not supported for missing/wait reports', () {
    for (final reason in ['missing', 'awaiting_goods']) {
      expect(
        () => draft(reason: reason),
        e.fails('OBSERVATION_AUTHORITY_OVERRIDE'),
      );
    }
  });
  test(
    'reassignment during camera retains evidence without new authority',
    () async {
      await fx.store.preparePickupIssueCameraCapture(draft());
      await fx.store.invalidateExecutionContext(o.assignment, 1);
      await capture();
      expect(await fx.store.readEvidence(asset), media.png);
      await expectLater(
        fx.store.preparePhotoTransfer(obs),
        e.fails('EXECUTION_FENCE_CHANGED'),
      );
      await expectLater(
        fx.store.materializeObservation(obs),
        e.fails('EXECUTION_FENCE_CHANGED'),
      );
    },
  );
  test(
    'scope invalidated after reservation prevents upload and retains bytes',
    () async {
      await capture();
      await fx.store.preparePhotoTransfer(obs);
      await advance();
      await fx.store.invalidateExecutionContext(o.assignment, 1);
      expect((await advance()).state, 'needs_review');
      expect(fx.puts, isEmpty);
      expect(await fx.store.readEvidence(asset), media.png);
    },
  );
  test(
    'lost PUT response verifies original bytes without second upload',
    () async {
      await capture();
      await fx.store.preparePhotoTransfer(obs);
      await advance();
      await fx.reopen(
        checkpoint: (n) async {
          if (n == 'photo_upload_returned') {
            throw StateError('lost PUT acknowledgement');
          }
        },
      );
      await expectLater(advance(), e.fails('STORAGE_IO_FAILED'));
      await fx.reopen();
      expect((await advance()).state, 'verified');
      expect(fx.puts, hasLength(1));
    },
  );
  for (final boundary in [
    'photo_before_prepare',
    'photo_prepared',
    'photo_before_upload',
    'photo_upload_returned',
    'photo_before_verified',
    'photo_verified',
  ]) {
    test(
      '$boundary interruption/reopen retains report identity and reaches verification',
      () async {
        await capture();
        var fired = false;
        await fx.reopen(
          checkpoint: (n) async {
            if (!fired && n == boundary) {
              fired = true;
              throw StateError('interruption');
            }
          },
        );
        try {
          await fx.store.preparePhotoTransfer(obs);
          for (var i = 0; i < 4; i++) {
            await advance();
            fx.tick();
          }
        } on EncryptedStoreException catch (error) {
          expect(error.code, 'STORAGE_IO_FAILED');
        }
        expect(fired, isTrue);
        await fx.reopen();
        await fx.store.preparePhotoTransfer(obs);
        for (
          var i = 0;
          i < 8 && (await fx.store.photoTransfer(obs))!.state != 'verified';
          i++
        ) {
          fx.tick();
          await advance();
        }
        expect((await fx.store.photoTransfer(obs))!.state, 'verified');
        expect(await fx.store.readEvidence(asset), media.png);
        expect(
          requests('ReserveAsset').map((w) => w['command_id']).toSet(),
          hasLength(1),
        );
      },
    );
  }
  for (final boundary in ['command_before_commit', 'command_queued']) {
    test('$boundary atomic report asset binding and restart', () async {
      await capture();
      await verify();
      await fx.reopen(
        checkpoint: (n) async {
          if (n == boundary) throw StateError('interruption');
        },
      );
      await expectLater(
        fx.store.materializeObservation(obs),
        e.fails('STORAGE_IO_FAILED'),
      );
      await fx.reopen();
      final command = await fx.store.materializeObservation(obs);
      expect((await send()).state, 'committed');
      expect(
        (await fx.store.materializeObservation(obs)).commandId,
        command.commandId,
      );
      expect((await fx.store.photoTransfer(obs))!.state, 'verified');
      final db = fx.raw();
      try {
        expect(
          db.select(
            "SELECT * FROM pending_commands WHERE command_type='ReportIssue'",
          ),
          hasLength(1),
        );
      } finally {
        db.close();
      }
    });
  }
  test(
    'SQL failure rolls back report command, dependency and photo binding together',
    () async {
      await capture();
      await verify();
      final db = fx.raw();
      try {
        db.execute(
          "CREATE TRIGGER fail_report_binding BEFORE UPDATE ON work_cache WHEN NEW.entity_type='pod_transfer_v1' AND json_extract(NEW.projection_json,'\$.report_binding') IS NOT NULL BEGIN SELECT RAISE(ABORT, 'injected'); END",
        );
        await expectLater(
          fx.store.materializeObservation(obs),
          e.fails('STORAGE_IO_FAILED'),
        );
        expect(
          db.select(
            "SELECT * FROM pending_commands WHERE command_type='ReportIssue'",
          ),
          isEmpty,
        );
        expect(
          db
              .select('SELECT command_id FROM local_observations')
              .single['command_id'],
          isNull,
        );
        expect(db.select('SELECT * FROM command_dependencies'), hasLength(1));
        expect((await fx.store.photoTransfer(obs))!.state, 'verified');
        db.execute('DROP TRIGGER fail_report_binding');
        await fx.store.materializeObservation(obs);
        expect((await send()).state, 'committed');
      } finally {
        db.close();
      }
    },
  );
  test(
    'lost report response recovers original status, never another report',
    () async {
      await capture();
      await verify();
      final command = await fx.store.materializeObservation(obs);
      final original = fx.intercept;
      fx.intercept = (r) async {
        final reply = await original!(r);
        if (r.method == 'POST' && r.url.path.endsWith('/ReportIssue')) {
          throw TimeoutException('lost report response');
        }
        return reply;
      };
      expect((await send()).state, 'unknown');
      await fx.reopen();
      fx.tick();
      expect((await send()).state, 'committed');
      expect(requests('ReportIssue'), hasLength(1));
      expect(
        (await fx.store.materializeObservation(obs)).commandId,
        command.commandId,
      );
      expect(await fx.store.readEvidence(asset), media.png);
    },
  );
  test('unverified or rejected photo cannot materialize report', () async {
    await capture();
    await fx.store.preparePhotoTransfer(obs);
    await advance();
    await advance();
    await expectLater(
      fx.store.materializeObservation(obs),
      e.fails('ASSET_NOT_VERIFIED'),
    );
    fx.intercept = (r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/VerifyAsset')) {
        final wire = jsonDecode(r.body) as Map;
        return f.jsonResponse({
          'command_id': wire['command_id'],
          'command_type': 'VerifyAsset',
          'state': 'rejected',
          'error': q.error('VALIDATION_FAILED'),
        });
      }
      return null;
    };
    expect((await advance()).state, 'rejected');
    await expectLater(
      fx.store.materializeObservation(obs),
      e.fails('ASSET_NOT_VERIFIED'),
    );
    expect(requests('ReportIssue'), isEmpty);
    expect(await fx.store.readEvidence(asset), media.png);
  });
  for (final field in [
    'asset_id',
    'handoff_observation_id',
    'photo_kind',
    'receipt_bindings',
    'report_binding',
  ]) {
    test('tampered $field transfer cannot be reused', () async {
      await capture();
      await verify();
      await fx.store.materializeObservation(obs);
      fx.store.close();
      final db = fx.raw();
      try {
        final row = db
            .select(
              "SELECT projection_json FROM work_cache WHERE entity_type='pod_transfer_v1'",
            )
            .single;
        final t = jsonDecode(row['projection_json'] as String) as Map;
        t[field] = field == 'receipt_bindings' || field == 'report_binding'
            ? <String, dynamic>{}
            : q.id(998);
        db.execute(
          "UPDATE work_cache SET projection_json=? WHERE entity_type='pod_transfer_v1'",
          [jsonEncode(t)],
        );
      } finally {
        db.close();
      }
      await fx.reopen();
      await expectLater(
        fx.store.photoTransfer(obs),
        throwsA(isA<EncryptedStoreException>()),
      );
      expect(await fx.store.readEvidence(asset), media.png);
    });
  }
  for (final outcome in ['saved', 'cancelled', 'signed_out']) {
    test(
      'pickup camera uses actual Auth/lifecycle adapter: $outcome',
      () async {
        final dir = Directory.systemTemp.createTempSync('rounds-issue-camera-');
        final fixture = f.Fixture();
        fixture.override = (r) async {
          if (r.url.path == '/auth/v1/user') {
            return f.jsonResponse({'id': f.subjectA});
          }
          if (r.url.path == '/v1/queries/DriverRound') {
            return f.jsonResponse(issue.issueProjection());
          }
          return f.jsonResponse(f.wire());
        };
        final life = DriverStorageLifecycle(
          registration: fixture.make(),
          secrets: fixture.secrets,
          resolveRoot: () async => dir,
          prepareLegacy: (_) async {},
        );
        final auth = DriverStorageAuth(life, now: () => f.instant);
        final token = a.bearer(f.instant.add(const Duration(minutes: 30)));
        try {
          await life.start();
          final lease = await life.authenticate(token);
          final authorized = await lease.fetchPickup(
            bearer: token,
            tenantId: e.entity,
            cityId: e.entity,
            roundId: e.entity,
          );
          final result = auth.capturePickupIssuePhoto(
            bearer: token,
            draft: LocalPickupIssueDraft(
              pickup: authorized,
              observationId: obs,
              observedAt: o.when,
              reason: 'damaged',
              deliveryId: e.entity,
              localAssetId: asset,
            ),
            camera: () async {
              life.didChangeAppLifecycleState(AppLifecycleState.paused);
              if (outcome == 'signed_out') auth.lock();
              life.didChangeAppLifecycleState(AppLifecycleState.resumed);
              return outcome == 'cancelled'
                  ? null
                  : XFile.fromData(media.png, name: 'camera.png');
            },
          );
          if (outcome == 'signed_out') {
            await expectLater(
              result,
              throwsA(isA<StorageLifecycleException>()),
            );
          } else {
            final saved = await result;
            expect(saved?.state, outcome == 'saved' ? 'local_recorded' : null);
            final reopened = await life.authenticate(token);
            expect(await reopened.pendingCameraCaptures(), isEmpty);
            if (saved != null) {
              expect(saved.toJson()['kind'], 'issue');
              expect(await reopened.readEvidence(asset), media.png);
              expect(await reopened.observationCommand(obs), isNull);
            }
          }
        } finally {
          await auth.dispose();
          dir.deleteSync(recursive: true);
        }
      },
    );
  }
}
