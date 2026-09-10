import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_auth.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';

import 'v23_device_registration_test.dart' as f;
import 'v23_driver_auth_test.dart' as a;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_execution_query_test.dart' as q;
import 'v23_offline_observation_test.dart' as o;

final jpeg = Uint8List.fromList([255, 216, 255, ...e.photo]);
XFile image([Uint8List? bytes]) =>
    XFile.fromData(bytes ?? jpeg, name: 'capture.jpg');
Matcher locked([String code = 'SESSION_LOCKED']) => throwsA(
  isA<StorageLifecycleException>().having((v) => v.code, 'safe code', code),
);

class SizedCameraFile extends XFile {
  SizedCameraFile(this.reportedSize) : super.fromData(jpeg);
  final int reportedSize;
  @override
  Future<int> length() async => reportedSize;
}

void main() {
  late Directory dir;
  late f.Fixture transport;
  late DriverStorageLifecycle life;
  late DriverStorageAuth auth;
  late String token, otherToken;
  late Map<String, dynamic> projection;
  Future<void> Function(String)? checkpoint;
  var deny = false;
  var epoch = 1;
  late DateTime currentTime;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('rounds-camera-tests-');
    transport = f.Fixture();
    token = a.bearer(f.instant.add(const Duration(minutes: 30)));
    otherToken = a.bearer(f.instant.add(const Duration(minutes: 40)));
    projection = q.projection();
    deny = false;
    epoch = 1;
    currentTime = f.instant;
    checkpoint = null;
    transport.override = (r) async {
      if (deny) return f.jsonResponse({'error': 'denied'}, 401);
      final other = r.headers['authorization'] == 'Bearer $otherToken';
      if (r.url.path == '/auth/v1/user') {
        return f.jsonResponse({'id': other ? f.subjectB : f.subjectA});
      }
      if (r.url.path == '/v1/queries/DriverRound') {
        return f.jsonResponse(projection);
      }
      return f.jsonResponse(
        f.wire(principal: other ? f.principalB : f.principalA, epoch: epoch),
      );
    };
    life = DriverStorageLifecycle(
      registration: transport.make(),
      secrets: transport.secrets,
      resolveRoot: () async => dir,
      prepareLegacy: (_) async {},
      storageCheckpoint: (name) async => checkpoint?.call(name),
    );
    auth = DriverStorageAuth(life, now: () => currentTime);
    await life.start();
    await auth.fetchExecutionContext(
      bearer: token,
      tenantId: e.entity,
      cityId: e.entity,
      roundId: e.entity,
    );
  });
  tearDown(() async {
    await auth.dispose();
    dir.deleteSync(recursive: true); // Only this test's temporary fixture.
  });
  Future<StoredObservation?> capture({
    Future<XFile?> Function()? camera,
    String id = o.obs,
    String asset = e.asset,
  }) => auth.captureExecutionPhoto(
    bearer: token,
    draft: o.draft(id: id),
    assetId: asset,
    camera: camera ?? () async => image(),
  );
  Future<DriverStorageLease> reopen([String? bearer]) =>
      life.authenticate(bearer ?? token);

  test(
    'query -> durable intent -> camera background/resume -> encrypted observation -> reopen',
    () async {
      final before = transport.posts.length;
      final saved = await capture(
        camera: () async {
          life.didChangeAppLifecycleState(AppLifecycleState.inactive);
          life.didChangeAppLifecycleState(AppLifecycleState.paused);
          life.didChangeAppLifecycleState(AppLifecycleState.resumed);
          return image();
        },
      );
      expect(saved!.state, 'local_recorded');
      expect(
        transport.posts.length,
        before + 1,
      ); // Reverified enrollment after camera lock.
      final lease = await reopen();
      expect(await lease.readEvidence(e.asset), jpeg);
      expect((await lease.readObservation(o.obs)).toJson(), saved.toJson());
      expect(await lease.pendingCameraCaptures(), isEmpty);
      expect(saved.toJson()['session_epoch'], 1);
      expect(
        saved.toJson()['execution_context']['assignment_id'],
        o.assignment,
      );
      expect(saved.toJson()['command_id'], isNull);
    },
  );

  test(
    'plugin result arriving before resumed waits without background authentication',
    () async {
      final cameraResult = Completer<XFile?>(), launched = Completer<void>();
      final result = capture(
        camera: () {
          life.didChangeAppLifecycleState(AppLifecycleState.paused);
          launched.complete();
          return cameraResult.future;
        },
      );
      await launched.future;
      final requests = transport.requests.length;
      cameraResult.complete(image());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(transport.requests.length, requests);
      life.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect((await result)!.state, 'local_recorded');
    },
  );

  test(
    'cancellation and successful retake preserve previous good image',
    () async {
      await capture();
      expect(
        await capture(id: o.next, asset: e.asset2, camera: () async => null),
        isNull,
      );
      final lease = await reopen();
      expect(await lease.readEvidence(e.asset), jpeg);
      expect((await lease.observations()).length, 1);
      expect(await lease.pendingCameraCaptures(), isEmpty);
      final result = await auth.captureExecutionPhoto(
        bearer: token,
        draft: o.draft(id: o.predecessor),
        assetId: q.policy,
        camera: () async => image(),
      );
      expect(result!.state, 'local_recorded');
      final checked = await reopen();
      expect(await checked.readEvidence(e.asset), jpeg);
      expect(await checked.readEvidence(q.policy), jpeg);
    },
  );

  test(
    'failed camera/retake is unresolved, never deletes the prior photo or relaunches blindly',
    () async {
      await capture();
      await expectLater(
        capture(
          id: o.next,
          asset: e.asset2,
          camera: () async => throw StateError('camera failed'),
        ),
        throwsStateError,
      );
      final lease = await reopen();
      expect(await lease.readEvidence(e.asset), jpeg);
      expect((await lease.pendingCameraCaptures()).single.captureId, o.next);
      var launches = 0;
      await expectLater(
        capture(
          id: o.next,
          asset: e.asset2,
          camera: () async {
            launches++;
            return image();
          },
        ),
        locked('CAMERA_CAPTURE_UNRESOLVED'),
      );
      expect(launches, 0);
    },
  );

  test(
    'sign-out during camera blocks late bytes and preserves unresolved intent',
    () async {
      await expectLater(
        capture(
          camera: () async {
            auth.lock();
            return image();
          },
        ),
        locked(),
      );
      final lease = await reopen();
      expect(await lease.observations(), isEmpty);
      expect((await lease.pendingCameraCaptures()).single.captureId, o.obs);
      await expectLater(
        lease.readEvidence(e.asset),
        e.fails('EVIDENCE_NOT_SAVED'),
      );
    },
  );

  test(
    'different account cannot receive the camera result or inspect original pending capture',
    () async {
      await expectLater(
        capture(
          camera: () async {
            await auth.authenticate(otherToken);
            return image();
          },
        ),
        locked(),
      );
      final other = await reopen(otherToken);
      expect(await other.pendingCameraCaptures(), isEmpty);
      expect(await other.observations(), isEmpty);
      await expectLater(
        other.finishCameraCapture(o.obs, photo: o.photo()),
        e.fails('CAMERA_INTENT_NOT_FOUND'),
      );
      expect(
        (await (await reopen()).pendingCameraCaptures()).single.captureId,
        o.obs,
      );
    },
  );

  test('Auth denial on resume cannot mark a photo saved', () async {
    await expectLater(
      capture(
        camera: () async {
          life.didChangeAppLifecycleState(AppLifecycleState.paused);
          deny = true;
          life.didChangeAppLifecycleState(AppLifecycleState.resumed);
          return image();
        },
      ),
      f.failure('UNAUTHENTICATED'),
    );
    deny = false;
    expect(await (await reopen()).observations(), isEmpty);
  });

  test(
    'device epoch change cannot rewrite original capture attribution',
    () async {
      await expectLater(
        capture(
          camera: () async {
            life.didChangeAppLifecycleState(AppLifecycleState.paused);
            epoch = 2;
            life.didChangeAppLifecycleState(AppLifecycleState.resumed);
            return image();
          },
        ),
        e.fails('CAMERA_INTENT_CONFLICT'),
      );
      final lease = await reopen();
      expect(await lease.observations(), isEmpty);
      expect((await lease.pendingCameraCaptures()).single.captureId, o.obs);
    },
  );

  test(
    'reassignment during camera retains only original evidence; no new execution authority',
    () async {
      final saved = await capture(
        camera: () async {
          projection = q.projection(version: 2);
          await auth.fetchExecutionContext(
            bearer: token,
            tenantId: e.entity,
            cityId: e.entity,
            roundId: e.entity,
          );
          return image();
        },
      );
      expect(saved!.toJson()['execution_context']['assignment_version'], 1);
      final lease = await reopen();
      await expectLater(
        lease.recordObservation(o.draft(id: o.next)),
        e.fails('EXECUTION_CONTEXT_INVALIDATED'),
      );
      expect(await lease.readEvidence(e.asset), jpeg);
    },
  );

  test('unrecognized camera bytes never produce a saved observation', () async {
    await expectLater(
      capture(camera: () async => image(Uint8List.fromList([1, 2, 3]))),
      e.fails('INVALID_EVIDENCE'),
    );
    final lease = await reopen();
    expect(await lease.observations(), isEmpty);
    expect((await lease.pendingCameraCaptures()).single.captureId, o.obs);
  });

  test(
    'same-bearer foreground poll racing camera return coalesces safely',
    () async {
      Future<void>? poll;
      final saved = await capture(
        camera: () async {
          life.didChangeAppLifecycleState(AppLifecycleState.paused);
          life.didChangeAppLifecycleState(AppLifecycleState.resumed);
          poll = auth.authenticate(token);
          return image();
        },
      );
      await poll;
      expect(saved!.state, 'local_recorded');
    },
  );

  for (final size in [
    EncryptedDriverStore.maxEvidenceBytes + 1,
    2,
    jpeg.length + 1,
  ]) {
    test(
      'camera byte bound rejects declared size $size without a saved observation',
      () async {
        await expectLater(
          capture(camera: () async => SizedCameraFile(size)),
          e.fails('INVALID_EVIDENCE'),
        );
        expect(await (await reopen()).observations(), isEmpty);
      },
    );
  }

  test(
    'expired Auth while camera is open cannot silently reopen the account',
    () async {
      await expectLater(
        capture(
          camera: () async {
            currentTime = f.instant.add(const Duration(hours: 2));
            return image();
          },
        ),
        locked('AUTH_EXPIRY_UNAVAILABLE'),
      );
      expect(await (await reopen()).observations(), isEmpty);
    },
  );

  test('second concurrent launch is denied', () async {
    final launched = Completer<void>(), cameraResult = Completer<XFile?>();
    final pending = capture(
      camera: () {
        launched.complete();
        return cameraResult.future;
      },
    );
    await launched.future;
    await expectLater(
      capture(id: o.next, asset: e.asset2),
      locked('CAMERA_BUSY'),
    );
    cameraResult.complete(null);
    expect(await pending, isNull);
  });

  test(
    'lost save acknowledgement retries exact original bytes and IDs once',
    () async {
      checkpoint = (name) async {
        if (name == 'camera_photo_saved') {
          throw StateError('injected acknowledgement loss');
        }
      };
      await expectLater(capture(), throwsA(anything));
      checkpoint = null;
      final lease = await reopen();
      expect((await lease.pendingCameraCaptures()).single.captureId, o.obs);
      expect((await lease.readObservation(o.obs)).state, 'local_recorded');
      final photo = ObservationPhoto(
        assetId: e.asset,
        mimeType: 'image/jpeg',
        bytes: jpeg,
      );
      try {
        expect(
          (await lease.finishCameraCapture(o.obs, photo: photo)).state,
          'local_recorded',
        );
        expect(
          (await lease.finishCameraCapture(o.obs, photo: photo)).state,
          'local_recorded',
        );
      } finally {
        photo.dispose();
      }
      expect((await lease.observations()).length, 1);
      expect(await lease.pendingCameraCaptures(), isEmpty);
    },
  );

  test(
    'prepared intent survives closing storage before camera returns without claiming a photo',
    () async {
      final lease = await reopen();
      await lease.prepareCameraCapture(o.draft(), assetId: e.asset);
      life.lock();
      final next = await reopen();
      expect(
        (await next.pendingCameraCaptures()).single.state,
        'awaiting_camera',
      );
      expect(await next.observations(), isEmpty);
      await expectLater(
        next.prepareCameraCapture(o.draft(id: o.next), assetId: e.asset2),
        e.fails('CAMERA_CAPTURE_UNRESOLVED'),
      );
      await expectLater(
        next.prepareCameraCapture(
          o.draft(payload: {'changed': true}),
          assetId: e.asset,
        ),
        e.fails('CAMERA_INTENT_CONFLICT'),
      );
    },
  );

  test(
    'unknown scope, missing parent and invalidated assignment deny camera launch',
    () async {
      final lease = await reopen();
      await expectLater(
        lease.prepareCameraCapture(o.draft(stopId: e.asset), assetId: e.asset),
        e.fails('OBSERVATION_OUTSIDE_CONTEXT'),
      );
      await expectLater(
        lease.prepareCameraCapture(
          o.draft(parents: [o.predecessor]),
          assetId: e.asset,
        ),
        e.fails('OBSERVATION_DEPENDENCY_MISSING'),
      );
      await lease.invalidateExecutionContext(o.assignment, 1);
      await expectLater(
        lease.prepareCameraCapture(o.draft(), assetId: e.asset),
        e.fails('EXECUTION_CONTEXT_INVALIDATED'),
      );
      expect(await lease.pendingCameraCaptures(), isEmpty);
    },
  );
}
