import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/driver/driver_operations_thread.dart';
import 'package:rounds_driver_harness/src/storage/harness_database.dart';
import 'package:rounds_driver_harness/src/storage/driver_command_outbox.dart';
import 'package:rounds_driver_harness/src/storage/pod_evidence_outbox.dart';
import 'package:rounds_driver_harness/src/storage/delivery_exception_evidence_outbox.dart';
import 'package:rounds_driver_harness/src/storage/message_media_outbox.dart';
import 'package:rounds_driver_harness/src/v23/legacy_upgrade_inventory.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late String databasePath;
  late Database db;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'rounds-v23-preservation-',
    );
    await databaseFactory.setDatabasesPath(directory.path);
    // Actual current application onCreate, not a guessed v2.3 reference schema.
    db = (await HarnessDatabase.open()).database;
    databasePath = db.path;
  });
  tearDown(() async {
    if (db.isOpen) await db.close();
    // Only the uniquely created synthetic fixture is removed.
    await directory.delete(recursive: true);
  });
  Future<LegacyUpgradeInventory> inspect() => LegacyUpgradeInventory.inspect(
    databasePath: databasePath,
    factory: databaseFactoryFfi,
  );

  test(
    'read-only preflight preserves real v5 pending/unknown/uploading queues and photo bytes',
    () async {
      final photo = File('${directory.path}/retained.jpg');
      await photo.writeAsBytes(
        List.generate(1024, (i) => i % 256),
        flush: true,
      );
      final digest = sha256.convert(await photo.readAsBytes()).toString();
      final command = await DriverCommandOutbox(db).enqueue(
        commandType: 'stop.confirm_pickup',
        aggregateId: 'original-stop',
        expectedVersion: 7,
        idempotencyKey: 'old-pickup-identity',
        endpoint: '/v1/driver/stops/original-stop/pickup',
        payload: {
          'manifestId': 'old-manifest',
          'lineNumbers': [1],
        },
        dependencyIds: ['old-predecessor'],
      );
      await DriverCommandOutbox(
        db,
      ).markSending(command); // May have committed remotely.
      final pod = await PodEvidenceOutbox(db).saveLocal(
        stopId: 'original-stop',
        expectedStopVersion: 7,
        manifestId: 'old-manifest',
        manifestVersion: 3,
        confirmedLineNumbers: [1],
        localPath: photo.path,
        sha256: digest,
        byteSize: 1024,
        contentType: 'image/jpeg',
        handoffType: 'recipient',
        receiverName: 'Synthetic recipient',
      );
      await PodEvidenceOutbox(db).markOffset(pod.id, 512);
      final damage = await DeliveryExceptionEvidenceOutbox(db).saveLocal(
        stopId: 'original-stop',
        expectedStopVersion: 7,
        manifestId: 'old-manifest',
        manifestVersion: 3,
        category: 'damaged_item',
        note: 'Synthetic damage',
        localPath: photo.path,
        sha256: digest,
        byteSize: 1024,
        contentType: 'image/jpeg',
      );
      await DeliveryExceptionEvidenceOutbox(db).markOffset(damage.id, 128);
      final media = await MessageMediaOutbox(db).save(
        roundId: 'old-round',
        stopId: 'original-stop',
        body: 'Synthetic message',
        attachments: [
          DriverMessageAttachmentModel.media(
            kind: 'image',
            fileName: 'retained.jpg',
            contentType: 'image/jpeg',
            byteSize: 1024,
            localPath: photo.path,
            sha256: digest,
          ),
        ],
      );
      await MessageMediaOutbox(db).updateAttachments(media.id, [
        media.attachments.single.copyWithUpload(
          uploadUrl: 'https://upload.test/private',
          uploadOffset: 256,
        ),
      ]);
      final before = <String, Object?>{};
      for (final table in LegacyUpgradeInventory.requiredColumns.keys) {
        before[table] = await db.query(table);
      }
      await db.close();
      final fileBefore = sha256.convert(await File(databasePath).readAsBytes());
      final result = await inspect();
      final repeated = await inspect();
      expect(result.rows, hasLength(4));
      expect(
        result.rows.map((r) => r.rowSha256),
        repeated.rows.map((r) => r.rowSha256),
      );
      expect(result.rows.every((r) => !r.eligibleForAutomaticReplay), isTrue);
      expect(
        result.rows.every(
          (r) => r.recoveryReasons.contains('ORIGINAL_PRINCIPAL_UNPROVEN'),
        ),
        isTrue,
      );
      expect(result.rows.where((r) => r.requiresOriginalFence), hasLength(3));
      expect(result.maySwitchClient, isFalse);
      expect(
        sha256.convert(await File(databasePath).readAsBytes()),
        fileBefore,
      );
      expect(sha256.convert(await photo.readAsBytes()).toString(), digest);
      db = await databaseFactoryFfi.openDatabase(databasePath);
      for (final table in LegacyUpgradeInventory.requiredColumns.keys) {
        expect(await db.query(table), before[table], reason: table);
      }
      expect((await PodEvidenceOutbox(db).pending()).single.uploadOffset, 512);
      expect(
        (await MessageMediaOutbox(
          db,
        ).pending()).single.attachments.single.uploadOffset,
        256,
      );
      expect(
        (await DriverCommandOutbox(db).readyToSend()).single.id,
        command.id,
      );
    },
  );

  test(
    'full raw row digest detects exact payload-byte change without re-encoding',
    () async {
      final record = await DriverCommandOutbox(db).enqueue(
        commandType: 'test',
        aggregateId: 'old',
        expectedVersion: 1,
        idempotencyKey: 'stable',
        endpoint: '/old',
        payload: {'a': 1},
      );
      await db.close();
      final first = (await inspect()).rows.single.rowSha256;
      db = await databaseFactoryFfi.openDatabase(databasePath);
      await db.update(
        'driver_command_outbox',
        {'payload_json': '{ "a" : 1 }'},
        where: 'id = ?',
        whereArgs: [record.id],
      );
      await db.close();
      expect((await inspect()).rows.single.rowSha256, isNot(first));
    },
  );

  test('multi-page snapshot does not miss pending rows', () async {
    final batch = db.batch();
    for (var i = 0; i < 520; i++) {
      batch.insert('harness_events', {
        'event_type': 'synthetic',
        'occurred_at': '2026-09-08T12:00:00Z',
        'trace_id': 'trace-$i',
        'payload_json': jsonEncode({'sequence': i}),
      });
    }
    await batch.commit(noResult: true);
    await db.close();
    final result = await inspect();
    expect(result.rows, hasLength(520));
    expect(result.rows.map((r) => r.sourceId).toSet(), hasLength(520));
  });

  test(
    'empty database is not evidence of safe cutover or no orphan photos',
    () async {
      await db.close();
      final orphan = File('${directory.path}/orphan.pending');
      await orphan.writeAsString('synthetic staged photo', flush: true);
      final result = await inspect();
      expect(result.rows, isEmpty);
      expect(result.maySwitchClient, isFalse);
      expect(await orphan.readAsString(), 'synthetic staged photo');
    },
  );

  for (final kind in ['version', 'unknownTable', 'missingTable']) {
    test('reject $kind without repair/reset', () async {
      if (kind == 'version') await db.setVersion(6);
      if (kind == 'unknownTable') {
        await db.execute('CREATE TABLE future_queue(id TEXT)');
      }
      if (kind == 'missingTable') {
        await db.execute('DROP TABLE message_media_outbox');
      }
      await db.close();
      final before = await File(databasePath).readAsBytes();
      await expectLater(inspect(), throwsA(isA<LegacyInventoryException>()));
      expect(await File(databasePath).readAsBytes(), before);
    });
  }

  test('missing database is not created', () async {
    final missing = '${directory.path}/missing.db';
    await expectLater(
      LegacyUpgradeInventory.inspect(
        databasePath: missing,
        factory: databaseFactoryFfi,
      ),
      throwsA(isA<LegacyInventoryException>()),
    );
    expect(await File(missing).exists(), isFalse);
  });
}
