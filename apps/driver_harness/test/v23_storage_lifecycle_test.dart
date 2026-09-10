import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/storage/harness_database.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/legacy_recovery_archive.dart';
import 'package:rounds_driver_harness/src/v23/native_storage_root.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as legacy;

import 'v23_device_registration_test.dart' as fixture;
import 'v23_encrypted_work_store_test.dart' as evidence;

Matcher denied(String code) => throwsA(
  isA<StorageLifecycleException>().having((e) => e.code, 'code', code),
);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  legacy.sqfliteFfiInit();
  legacy.databaseFactory = legacy.databaseFactoryFfi;
  late Directory temp;
  late fixture.Fixture auth;
  late DriverStorageLifecycle lifecycle;
  int prepared = 0, resolved = 0;
  Future<void> Function(Directory)? prepare;
  Future<void> Function(String)? checkpoint;
  const channel = MethodChannel('app.rounds/v23_private_storage');

  setUp(() {
    temp = Directory(
      Directory.systemTemp
          .createTempSync('rounds-lifecycle-')
          .resolveSymbolicLinksSync(),
    );
    auth = fixture.Fixture();
    prepared = 0;
    resolved = 0;
    prepare = null;
    checkpoint = null;
    lifecycle = DriverStorageLifecycle(
      registration: auth.make(),
      secrets: auth.secrets,
      resolveRoot: () async {
        resolved++;
        return temp;
      },
      prepareLegacy: (root) async {
        prepared++;
        await prepare?.call(root);
      },
      storageCheckpoint: (point) async => checkpoint?.call(point),
    );
  });
  tearDown(() async {
    await lifecycle.dispose();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    // Only this fixture's directory; never an installed app's files.
    temp.deleteSync(recursive: true);
  });
  Future<Object> save(DriverStorageLease lease, {String id = evidence.asset}) =>
      lease.saveEvidence(
        assetId: id,
        purposeKind: 'proof',
        purposeEntityId: evidence.entity,
        mimeType: 'image/jpeg',
        capturedAt: evidence.captured,
        bytes: evidence.photo,
      );

  test('no registration or storage before completed preparation', () async {
    await expectLater(lifecycle.authenticate('A'), denied('STARTUP_NOT_READY'));
    expect(auth.requests, isEmpty);
    expect(temp.listSync(), isEmpty);
  });

  test(
    'concurrent startup shares one preparation and registers only afterwards',
    () async {
      final wait = Completer<void>();
      prepare = (_) => wait.future;
      final a = lifecycle.start();
      final b = lifecycle.start();
      expect(identical(a, b), isTrue);
      await expectLater(
        lifecycle.authenticate('A'),
        denied('STARTUP_NOT_READY'),
      );
      wait.complete();
      await Future.wait([a, b]);
      await lifecycle.start();
      expect(prepared, 1);
      expect(resolved, 1);
      expect(
        (await lifecycle.authenticate('A')).principalId,
        fixture.principalA,
      );
    },
  );

  test(
    'failed startup stays closed, redacts details and permits explicit retry',
    () async {
      prepare = (_) async => throw StateError('/private/photo.jpg secret');
      await expectLater(lifecycle.start(), denied('STARTUP_REQUIRES_RECOVERY'));
      expect(lifecycle.ready, isFalse);
      expect(auth.requests, isEmpty);
      prepare = null;
      await lifecycle.start();
      expect(prepared, 2);
      expect(lifecycle.ready, isTrue);
    },
  );

  test(
    'actual closed Driver5 archive precedes account opening and remains unassigned',
    () async {
      final oldRoot = Directory('${temp.path}/legacy')..createSync();
      final support = Directory('${oldRoot.path}/support')..createSync();
      final media = Directory('${support.path}/pod_drafts')..createSync();
      File('${media.path}/orphan.pending').writeAsStringSync('retained source');
      await legacy.databaseFactory.setDatabasesPath(oldRoot.path);
      final db = (await HarnessDatabase.open()).database;
      final dbPath = db.path;
      // This fixture explicitly closes the actual legacy writer, not a mock.
      await db.close();
      final original = File(dbPath).readAsBytesSync();
      LegacyRecoveryReceipt? receipt;
      prepare = (root) async {
        expect(auth.requests, isEmpty);
        receipt = await LegacyRecoveryArchive.preserve(
          databasePath: dbPath,
          factory: legacy.databaseFactory,
          supportDirectory: support,
          archiveParent: root,
          readDraftPreferences: () async => {
            'pod_draft_photo_path_old': '${media.path}/orphan.pending',
          },
          secrets: auth.secrets,
        );
      };
      await lifecycle.start();
      expect(receipt!.maySwitchClient, isFalse);
      expect(receipt!.eligibleForAutomaticReplay, isFalse);
      final lease = await lifecycle.authenticate('A');
      expect(lease.recovery.recovered, isEmpty);
      expect(lease.recovery.orphanCount, 0); // Archive never becomes A's photo.
      expect(File(dbPath).readAsBytesSync(), original);
      expect(
        File('${media.path}/orphan.pending').readAsStringSync(),
        'retained source',
      );
    },
  );

  test(
    'sign-out locks old leases, same-owner sign-in recovers exact photo',
    () async {
      await lifecycle.start();
      final a = await lifecycle.authenticate('A');
      await save(a);
      final keys = Map.of(auth.secrets.values);
      lifecycle.lock();
      await expectLater(
        a.readEvidence(evidence.asset),
        denied('SESSION_LOCKED'),
      );
      final next = await lifecycle.authenticate('A');
      expect(await next.readEvidence(evidence.asset), evidence.photo);
      await expectLater(save(a), denied('SESSION_LOCKED'));
      expect(auth.secrets.values, keys);
    },
  );

  test(
    'new account cannot access or capture through previous account lease',
    () async {
      await lifecycle.start();
      final a = await lifecycle.authenticate('A');
      await save(a);
      final b = await lifecycle.authenticate('B');
      expect(b.principalId, fixture.principalB);
      await expectLater(save(a, id: evidence.asset2), denied('SESSION_LOCKED'));
      await expectLater(
        b.readEvidence(evidence.asset),
        evidence.fails('EVIDENCE_NOT_SAVED'),
      );
      final again = await lifecycle.authenticate('A');
      expect(await again.readEvidence(evidence.asset), evidence.photo);
    },
  );

  test('failed account switch never leaves old account unlocked', () async {
    await lifecycle.start();
    final a = await lifecycle.authenticate('A');
    await save(a);
    auth.override = (_) async => fixture.jsonResponse({}, 401);
    await expectLater(lifecycle.authenticate('B'), throwsException);
    await expectLater(a.readEvidence(evidence.asset), denied('SESSION_LOCKED'));
    auth.override = null;
    expect(
      await (await lifecycle.authenticate('A')).readEvidence(evidence.asset),
      evidence.photo,
    );
  });

  test('sign-out during Auth request rejects late enrollment', () async {
    await lifecycle.start();
    final entered = Completer<void>(), release = Completer<void>();
    auth.override = (_) async {
      entered.complete();
      await release.future;
      return fixture.jsonResponse({'id': fixture.subjectA});
    };
    final pending = lifecycle.authenticate('A');
    final failure = expectLater(pending, throwsException);
    await entered.future;
    lifecycle.lock();
    release.complete();
    await failure;
    expect(auth.posts, isEmpty);
    expect(auth.secrets.values, isEmpty);
  });

  test('concurrent authentications return only the latest lease', () async {
    await lifecycle.start();
    final a = lifecycle.authenticate('A');
    final failed = expectLater(a, denied('SESSION_LOCKED'));
    final b = lifecycle.authenticate('B');
    await failed;
    expect((await b).principalId, fixture.principalB);
    expect(auth.posts, hasLength(1));
  });

  test(
    'background during staged capture denies success but restart recovers bytes',
    () async {
      await lifecycle.start();
      final a = await lifecycle.authenticate('A');
      checkpoint = (point) async {
        if (point == 'file_renamed') {
          lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
        }
      };
      await expectLater(save(a), throwsException);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await expectLater(
        a.readEvidence(evidence.asset),
        denied('SESSION_LOCKED'),
      );
      checkpoint = null;
      final next = await lifecycle.authenticate('A');
      expect(await next.readEvidence(evidence.asset), evidence.photo);
    },
  );

  test(
    'Flutter observer locks on background and resume never signs in automatically',
    () async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      lifecycle.observe(binding);
      lifecycle.observe(binding);
      await lifecycle.start();
      final a = await lifecycle.authenticate('A');
      await save(a);
      final count = auth.requests.length;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await expectLater(lifecycle.authenticate('B'), denied('SESSION_LOCKED'));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(auth.requests.length, count);
      await expectLater(
        a.readEvidence(evidence.asset),
        denied('SESSION_LOCKED'),
      );
      expect(
        await (await lifecycle.authenticate('A')).readEvidence(evidence.asset),
        evidence.photo,
      );
    },
  );

  test(
    'explicit revoke retains files and permanently blocks automatic revival',
    () async {
      await lifecycle.start();
      final a = await lifecycle.authenticate('A');
      await save(a);
      final files = temp
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .toList();
      await lifecycle.revoke('A');
      await expectLater(
        a.readEvidence(evidence.asset),
        denied('SESSION_LOCKED'),
      );
      await expectLater(
        lifecycle.authenticate('A'),
        fixture.failure('DEVICE_REQUIRES_RECOVERY'),
      );
      expect(files.every((f) => File(f).existsSync()), isTrue);
    },
  );

  test('dispose during startup cannot reopen; dispose is idempotent', () async {
    final entered = Completer<void>(), release = Completer<void>();
    prepare = (_) async {
      entered.complete();
      await release.future;
    };
    final pending = lifecycle.start();
    final failed = expectLater(pending, denied('DISPOSED'));
    await entered.future;
    lifecycle.dispose();
    lifecycle.dispose();
    release.complete();
    await failed;
    expect(lifecycle.ready, isFalse);
    expect(
      () => lifecycle.authenticate('A'),
      throwsA(isA<StorageLifecycleException>()),
    );
  });

  test(
    'native root requires exact OS policy, canonical directory and no arguments',
    () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'rootV1');
        expect(call.arguments, isNull);
        return {'format': 1, 'policy': 'android_no_backup', 'path': temp.path};
      });
      expect((await nativeStorageRoot()).path, temp.path);
    },
  );

  test(
    'second lifecycle cannot prepare or enroll until first owner releases',
    () async {
      await lifecycle.start();
      final secondAuth = fixture.Fixture();
      var secondPrepared = false;
      final second = DriverStorageLifecycle(
        registration: secondAuth.make(),
        secrets: secondAuth.secrets,
        resolveRoot: () async => temp,
        prepareLegacy: (_) async {
          secondPrepared = true;
        },
      );
      try {
        await expectLater(second.start(), denied('STARTUP_REQUIRES_RECOVERY'));
        expect(secondPrepared, isFalse);
        expect(secondAuth.requests, isEmpty);
        lifecycle
            .lock(); // Sign-out keeps ownership; it is not runtime disposal.
        await expectLater(second.start(), denied('STARTUP_REQUIRES_RECOVERY'));
        await lifecycle.dispose();
        await second.start();
        expect(secondPrepared, isTrue);
      } finally {
        await second.dispose();
      }
    },
  );

  test(
    'missing native root prevents preparation and any registration',
    () async {
      await lifecycle.dispose();
      var called = false;
      lifecycle = DriverStorageLifecycle(
        registration: auth.make(),
        secrets: auth.secrets,
        prepareLegacy: (_) async {
          called = true;
        },
      );
      await expectLater(lifecycle.start(), denied('STARTUP_REQUIRES_RECOVERY'));
      expect(called, isFalse);
      expect(auth.requests, isEmpty);
      expect(auth.secrets.values, isEmpty);
    },
  );

  test(
    'native root rejects missing bridge, wrong policy, files, links and relative paths',
    () async {
      final file = File('${temp.path}/file')..writeAsStringSync('test');
      final link = Link('${temp.path}/link')..createSync(temp.path);
      final invalid = <Object?>[
        null,
        {},
        {'format': 2, 'policy': 'android_no_backup', 'path': temp.path},
        {'format': 1, 'policy': 'support', 'path': temp.path},
        for (final path in [
          'relative',
          '/',
          file.path,
          link.path,
          '${temp.path}/missing',
        ])
          {'format': 1, 'policy': 'android_no_backup', 'path': path},
      ];
      for (final value in invalid) {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => value,
        );
        await expectLater(
          nativeStorageRoot(),
          throwsA(isA<NativeStorageRootException>()),
        );
      }
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await expectLater(
        nativeStorageRoot(),
        throwsA(isA<NativeStorageRootException>()),
      );
    },
  );

  test(
    'disposal holds runtime ownership until in-flight authentication settles',
    () async {
      await lifecycle.start();
      final entered = Completer<void>(), release = Completer<void>();
      auth.override = (_) async {
        entered.complete();
        await release.future;
        return fixture.jsonResponse({'id': fixture.subjectA});
      };
      final pending = lifecycle.authenticate('A');
      final failed = expectLater(pending, throwsException);
      await entered.future;
      final disposed = lifecycle.dispose();
      final otherAuth = fixture.Fixture();
      final other = DriverStorageLifecycle(
        registration: otherAuth.make(),
        secrets: otherAuth.secrets,
        resolveRoot: () async => temp,
        prepareLegacy: (_) async {},
      );
      try {
        await expectLater(other.start(), denied('STARTUP_REQUIRES_RECOVERY'));
        release.complete();
        await failed;
        await disposed;
        await other.start();
        expect(auth.posts, isEmpty);
      } finally {
        if (!release.isCompleted) {
          release.complete();
        }
        await other.dispose();
      }
    },
  );
}
