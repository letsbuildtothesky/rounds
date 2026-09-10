import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/storage/harness_database.dart';
import 'package:rounds_driver_harness/src/storage/legacy_startup_gate.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_startup.dart';
import 'package:rounds_driver_harness/src/v23/legacy_recovery_archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as legacy;

import 'v23_device_registration_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  legacy.sqfliteFfiInit();
  legacy.databaseFactory = legacy.databaseFactoryFfi;

  test(
    'real controller and DB entry points refuse preparation overlap',
    () async {
      await LegacyStartupGate.process.prepare(() async {
        await expectLater(HarnessDatabase.open(), throwsStateError);
        await expectLater(HarnessAppController.create(), throwsStateError);
      });
      SharedPreferences.setMockInitialValues({});
      final controller = await HarnessAppController.create();
      controller.dispose();
      await expectLater(
        LegacyStartupGate.process.prepare(() async {}),
        throwsStateError,
      );
    },
  );

  test('default entry does not touch native paths, HTTP, or secrets', () async {
    // No channel/path-provider/secure-storage mocks: a native attempt would fail.
    expect(await DriverStorageStartup.startNative(), isNull);
  });

  test(
    'debug Android cohort rejects release, profile and iOS before startup',
    () {
      DriverStorageStartup.validateCohort(debug: true, android: true);
      for (final pair in [(false, true), (true, false), (false, false)]) {
        expect(
          () => DriverStorageStartup.validateCohort(
            debug: pair.$1,
            android: pair.$2,
          ),
          throwsA(isA<StorageLifecycleException>()),
        );
      }
    },
  );

  test(
    'cold gate blocks concurrent/late preparation and keeps failure closed',
    () async {
      final gate = LegacyStartupGate();
      final pending = Completer<void>();
      final started = gate.prepare(() => pending.future);
      expect(gate.claimLegacyUse, throwsStateError);
      await expectLater(gate.prepare(() async {}), throwsStateError);
      final failure = expectLater(started, throwsStateError);
      pending.completeError(StateError('copy failed'));
      await failure;
      expect(gate.claimLegacyUse, throwsStateError);
      await expectLater(gate.prepare(() async {}), throwsStateError);
      final used = LegacyStartupGate()..claimLegacyUse();
      await expectLater(used.prepare(() async {}), throwsStateError);
    },
  );

  test(
    'actual Driver5 copy seals before legacy release; bytes and raw drafts survive',
    () async {
      final temp = Directory(
        Directory.systemTemp
            .createTempSync('rounds-startup-')
            .resolveSymbolicLinksSync(),
      );
      final old = Directory('${temp.path}/old')..createSync();
      final support = Directory('${old.path}/support')..createSync();
      final photos = Directory('${support.path}/pod_drafts')..createSync();
      final photo = File('${photos.path}/pending.jpg')
        ..writeAsStringSync('original bytes');
      final private = Directory('${temp.path}/no-backup')..createSync();
      await legacy.databaseFactory.setDatabasesPath(old.path);
      final db = (await HarnessDatabase.open()).database;
      final dbPath = db.path;
      await db.close();
      final dbBytes = File(dbPath).readAsBytesSync();
      SharedPreferences.setMockInitialValues({
        'pod_draft_photo_path_stop': photo.path,
        'operations_message_draft_v1_round_stop': '  unsent draft  ',
        'unrelated_preference': 'untouched',
      });
      final f = fixture.Fixture();
      final gate = LegacyStartupGate();
      LegacyRecoveryReceipt? receipt;
      var transportClosed = 0;
      final startup = DriverStorageStartup(
        gate: gate,
        closeTransport: () {
          transportClosed++;
        },
        lifecycle: DriverStorageLifecycle(
          registration: f.make(),
          secrets: f.secrets,
          resolveRoot: () async => private,
          prepareLegacy: (root) async {
            expect(gate.claimLegacyUse, throwsStateError);
            expect(f.requests, isEmpty);
            receipt = await LegacyRecoveryArchive.preserve(
              databasePath: dbPath,
              factory: legacy.databaseFactory,
              supportDirectory: support,
              archiveParent: root,
              readDraftPreferences: readLegacyDraftPreferences,
              secrets: f.secrets,
            );
          },
        ),
      );
      try {
        await expectLater(
          HarnessAppController.create(storageStartup: startup),
          throwsStateError,
        );
        await startup.start();
        expect(receipt!.sourceIssues, 0);
        expect(receipt!.preferencesPreserved, 2);
        expect(receipt!.maySwitchClient, isFalse);
        gate.claimLegacyUse(); // Only after the awaited archive sealed.
        expect(File(dbPath).readAsBytesSync(), dbBytes);
        expect(photo.readAsStringSync(), 'original bytes');
        expect(
          (await SharedPreferences.getInstance()).getString(
            'unrelated_preference',
          ),
          'untouched',
        );
        expect(f.requests, isEmpty); // Startup alone never enrolls.
        await startup.dispose();
        await startup.dispose();
        expect(transportClosed, 1);
      } finally {
        await startup.dispose();
        temp.deleteSync(
          recursive: true,
        ); // Only this test's owned temporary tree.
      }
    },
  );

  test('failed startup never releases legacy workers or enrolls', () async {
    final temp = Directory(
      Directory.systemTemp
          .createTempSync('rounds-startup-failure-')
          .resolveSymbolicLinksSync(),
    );
    final f = fixture.Fixture();
    final gate = LegacyStartupGate();
    var closed = false;
    final startup = DriverStorageStartup(
      gate: gate,
      closeTransport: () {
        closed = true;
      },
      lifecycle: DriverStorageLifecycle(
        registration: f.make(),
        secrets: f.secrets,
        resolveRoot: () async => temp,
        prepareLegacy: (_) async => throw StateError('copy failed'),
      ),
    );
    try {
      await expectLater(
        startup.start(),
        throwsA(isA<StorageLifecycleException>()),
      );
      expect(gate.claimLegacyUse, throwsStateError);
      expect(f.requests, isEmpty);
    } finally {
      await startup.dispose();
      expect(closed, isTrue);
      temp.deleteSync(recursive: true);
    }
  });
}
