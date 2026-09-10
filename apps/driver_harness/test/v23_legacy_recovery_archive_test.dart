import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/driver/driver_operations_thread.dart';
import 'package:rounds_driver_harness/src/storage/harness_database.dart';
import 'package:rounds_driver_harness/src/storage/driver_command_outbox.dart';
import 'package:rounds_driver_harness/src/storage/pod_evidence_outbox.dart';
import 'package:rounds_driver_harness/src/storage/delivery_exception_evidence_outbox.dart';
import 'package:rounds_driver_harness/src/storage/message_media_outbox.dart';
import 'package:rounds_driver_harness/src/v23/device_registration_client.dart';
import 'package:rounds_driver_harness/src/v23/legacy_recovery_archive.dart';
import 'package:rounds_driver_harness/src/v23/sqlcipher_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as old;
import 'package:sqlite3/sqlite3.dart' as sql;

class Vault implements DeviceSecretBackend {
  final values = <String, String>{};
  bool failAfterWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
    if (failAfterWrite) {
      throw StateError('synthetic lost write acknowledgement');
    }
  }
}

void main() {
  old.sqfliteFfiInit();
  old.databaseFactory = old.databaseFactoryFfi;
  late Directory temp, support, output;
  late String sourcePath;
  late File photo, orphan;
  late Map<String, Object?> preferences;
  late Vault vault;
  late Map<String, List<int>> originals;
  late String prefBefore;
  setUp(() async {
    final created = await Directory.systemTemp.createTemp(
      'rounds-legacy-archive-',
    );
    temp = Directory(created.resolveSymbolicLinksSync());
    support = Directory('${temp.path}/support')..createSync();
    output = Directory('${temp.path}/new-private')..createSync();
    final databases = Directory('${temp.path}/databases')..createSync();
    await old.databaseFactory.setDatabasesPath(databases.path);
    final db = (await HarnessDatabase.open()).database;
    sourcePath = db.path;
    Directory('${support.path}/pod_evidence').createSync();
    Directory(
      '${support.path}/pod_drafts/old-stop',
    ).createSync(recursive: true);
    photo = File('${support.path}/pod_evidence/photo.jpg')
      ..writeAsBytesSync(List.generate(600000, (i) => i % 251));
    orphan = File('${support.path}/pod_drafts/old-stop/delivery.jpg.pending')
      ..writeAsStringSync('PRIVATE-ORPHAN-CANARY');
    final digest = sha256.convert(photo.readAsBytesSync()).toString();
    final command = await DriverCommandOutbox(db).enqueue(
      commandType: 'stop.confirm_pickup',
      aggregateId: 'old-stop',
      expectedVersion: 7,
      idempotencyKey: 'original-frozen-id',
      endpoint: '/v1/driver/stops/old-stop/pickup',
      payload: {'manifestId': 'old-manifest'},
      dependencyIds: ['old-predecessor'],
    );
    await DriverCommandOutbox(db).markSending(command);
    await db.update('driver_command_outbox', {
      'payload_json':
          '{ "manifestId" : "old-manifest", "note":"PRIVATE-COMMAND-CANARY" }',
    });
    final pod = await PodEvidenceOutbox(db).saveLocal(
      stopId: 'old-stop',
      expectedStopVersion: 7,
      manifestId: 'old-manifest',
      manifestVersion: 3,
      confirmedLineNumbers: [1],
      localPath: photo.path,
      sha256: digest,
      byteSize: 600000,
      contentType: 'image/jpeg',
      handoffType: 'recipient',
    );
    await PodEvidenceOutbox(db).markOffset(pod.id, 123456);
    await PodEvidenceOutbox(
      db,
    ).markUploadUrl(pod.id, 'https://synthetic.invalid/tus/PRIVATE-URL-CANARY');
    final damage = await DeliveryExceptionEvidenceOutbox(db).saveLocal(
      stopId: 'old-stop',
      expectedStopVersion: 7,
      manifestId: 'old-manifest',
      manifestVersion: 3,
      category: 'damaged_item',
      localPath: photo.path,
      sha256: digest,
      byteSize: 600000,
      contentType: 'image/jpeg',
    );
    await DeliveryExceptionEvidenceOutbox(db).markOffset(damage.id, 456);
    await MessageMediaOutbox(db).save(
      roundId: 'old-round',
      stopId: 'old-stop',
      body: 'PRIVATE-MESSAGE-CANARY',
      attachments: [
        DriverMessageAttachmentModel.media(
          kind: 'image',
          fileName: 'photo.jpg',
          contentType: 'image/jpeg',
          byteSize: 600000,
          localPath: photo.path,
          sha256: digest,
          uploadOffset: 98765,
          uploadUrl: 'https://synthetic.invalid/tus/original',
        ),
      ],
    );
    await db.close();
    preferences = {
      'pod_draft_photo_path_old-stop': photo.path,
      'pod_draft_photo_captured_at_old-stop': '2026-09-01T12:34:56Z',
      'delivery_problem_note_old-stop': '  PRIVATE-NOTE-CANARY  ',
      'delivery_problem_category_old-stop': 'damaged_item',
      'operations_message_draft_v1_old-stop': 'PRIVATE-DRAFT-CANARY',
      'operations_message_media_draft_v1_old-stop': jsonEncode([
        {
          'kind': 'image',
          'localPath': photo.path,
          'sha256': digest,
          'byteSize': 600000,
          'uploadOffset': 98765,
        },
      ]),
      'rounds_driver_access_token': 'MUST-NOT-COPY-AUTH',
    };
    prefBefore = jsonEncode(preferences);
    vault = Vault();
    originals = {
      for (final f in [File(sourcePath), photo, orphan])
        f.path: f.readAsBytesSync(),
    };
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  }); // Only this test's fixture.
  Future<LegacyRecoveryReceipt> preserve({
    Future<void> Function(String)? checkpoint,
  }) => LegacyRecoveryArchive.preserve(
    databasePath: sourcePath,
    factory: old.databaseFactoryFfi,
    supportDirectory: support,
    archiveParent: output,
    readDraftPreferences: () async => Map.of(preferences),
    secrets: vault,
    checkpoint: checkpoint,
  );
  File archiveFile() => output
      .listSync(recursive: true)
      .whereType<File>()
      .singleWhere((f) => f.path.endsWith('/recovery.db'));
  sql.Database inspectArchive() {
    final record = jsonDecode(vault.values.values.single) as Map;
    return openCipherDatabase(
      archiveFile().path,
      base64Decode(record['key'] as String),
    );
  }

  List<int> archivedBytes(sql.Database db, String snapshot, String name) => db
      .select(
        'SELECT bytes FROM chunks WHERE snapshot_id=? AND name=? ORDER BY ordinal',
        [snapshot, name],
      )
      .expand((r) => r['bytes'] as Uint8List)
      .toList();
  Matcher fails(String code) => throwsA(
    isA<LegacyRecoveryException>().having((e) => e.code, 'code', code),
  );
  void unchanged() {
    for (final entry in originals.entries) {
      expect(File(entry.key).readAsBytesSync(), entry.value);
    }
    expect(jsonEncode(preferences), prefBefore);
  }

  test(
    'real Driver5 bytes, upload offsets, drafts and orphan files are encrypted without account adoption',
    () async {
      final receipt = await preserve();
      expect(receipt.filesPreserved, 3);
      expect(receipt.rowsPreserved, 4);
      expect(receipt.preferencesPreserved, 6);
      expect(
        receipt.sourceIssues,
        1,
      ); // Original orphan retained, not silently adopted.
      expect(receipt.disposition, 'quarantined_unassigned');
      expect(receipt.maySwitchClient, isFalse);
      expect(receipt.eligibleForAutomaticReplay, isFalse);
      final db = inspectArchive();
      try {
        expect(
          archivedBytes(db, receipt.snapshotId, 'database'),
          originals[sourcePath],
        );
        expect(
          archivedBytes(db, receipt.snapshotId, 'media/pod_evidence/photo.jpg'),
          originals[photo.path],
        );
        expect(
          archivedBytes(
            db,
            receipt.snapshotId,
            'media/pod_drafts/old-stop/delivery.jpg.pending',
          ),
          originals[orphan.path],
        );
        final snapshot = db.select('SELECT * FROM snapshots').single;
        final manifest = jsonDecode(snapshot['manifest'] as String) as Map;
        expect(snapshot['state'], 'sealed');
        expect(manifest['ownership'], 'unproven');
        expect(
          (manifest['preferences'] as Map)['delivery_problem_note_old-stop'],
          '  PRIVATE-NOTE-CANARY  ',
        );
        expect(
          (snapshot['manifest'] as String).contains('MUST-NOT-COPY-AUTH'),
          isFalse,
        );
        expect(
          (manifest['rows'] as List).every(
            (r) =>
                (r['recovery'] as List).contains('ORIGINAL_PRINCIPAL_UNPROVEN'),
          ),
          isTrue,
        );
      } finally {
        db.close();
      }
      final bytes = latin1.decode(archiveFile().readAsBytesSync());
      for (final canary in [
        'SQLite format 3',
        'PRIVATE-ORPHAN-CANARY',
        'PRIVATE-COMMAND-CANARY',
        'PRIVATE-URL-CANARY',
        'PRIVATE-DRAFT-CANARY',
        'PRIVATE-NOTE-CANARY',
      ]) {
        expect(bytes.contains(canary), isFalse);
      }
      final plain = sql.sqlite3.open(archiveFile().path);
      try {
        expect(
          () => plain.select('SELECT * FROM snapshots'),
          throwsA(anything),
        );
      } finally {
        plain.close();
      }
      unchanged();
    },
  );

  for (final boundary in [
    'manifest_committed',
    'chunk_written',
    'file_committed',
    'before_source_recheck',
    'receipt_committed',
  ]) {
    test(
      'interruption at $boundary resumes exact snapshot without source deletion or duplicate receipt',
      () async {
        var hit = false;
        await expectLater(
          preserve(
            checkpoint: (name) async {
              if (name == boundary && !hit) {
                hit = true;
                throw StateError('synthetic interruption');
              }
            },
          ),
          fails('ARCHIVE_REQUIRES_RECOVERY'),
        );
        expect(hit, isTrue);
        final retried = await preserve();
        final again = await preserve();
        expect(again.snapshotId, retried.snapshotId);
        final db = inspectArchive();
        try {
          expect(
            db.select('SELECT count(*) AS n FROM snapshots').single['n'],
            1,
          );
          expect(
            archivedBytes(db, again.snapshotId, 'database'),
            originals[sourcePath],
          );
          expect(
            archivedBytes(db, again.snapshotId, 'media/pod_evidence/photo.jpg'),
            originals[photo.path],
          );
        } finally {
          db.close();
        }
        unchanged();
      },
    );
  }

  test(
    'changed preferences block sealing; retry preserves both old and new snapshots',
    () async {
      await expectLater(
        preserve(
          checkpoint: (step) async {
            if (step == 'before_source_recheck') {
              preferences['operations_message_draft_v1_old-stop'] = 'new draft';
            }
          },
        ),
        fails('LEGACY_SOURCE_CHANGED'),
      );
      final db = inspectArchive();
      try {
        expect(
          db.select('SELECT state FROM snapshots').single['state'],
          'copying',
        );
      } finally {
        db.close();
      }
      await preserve();
      final after = inspectArchive();
      try {
        expect(
          after
              .select('SELECT state FROM snapshots ORDER BY state')
              .map((r) => r['state']),
          ['copying', 'sealed'],
        );
      } finally {
        after.close();
      }
    },
  );

  test(
    'changed media during copy cannot be sealed as the original bytes',
    () async {
      await expectLater(
        preserve(
          checkpoint: (step) async {
            if (step == 'manifest_committed') {
              photo.writeAsBytesSync(List.filled(600000, 9));
            }
          },
        ),
        fails('ARCHIVE_CONTENT_MISMATCH'),
      );
      final db = inspectArchive();
      try {
        expect(
          db.select('SELECT state FROM snapshots').single['state'],
          'copying',
        );
      } finally {
        db.close();
      }
    },
  );

  test(
    'missing, mismatched, malformed and outside references are retained with explicit issues',
    () async {
      preferences['pod_draft_photo_path_missing'] =
          '${support.path}/pod_drafts/missing.jpg';
      preferences['operations_message_media_draft_v1_broken'] =
          '{ malformed original';
      preferences['operations_message_media_draft_v1_mismatch'] = jsonEncode([
        {
          'kind': 'image',
          'localPath': photo.path,
          'sha256': 'wrong',
          'byteSize': 1,
        },
      ]);
      preferences['delivery_problem_photo_outside'] =
          '${temp.path}/outside.txt';
      File('${temp.path}/outside.txt').writeAsStringSync('DO-NOT-READ');
      final receipt = await preserve();
      expect(receipt.sourceIssues, 5);
      final db = inspectArchive();
      try {
        final manifest =
            db.select('SELECT manifest FROM snapshots').single['manifest']
                as String;
        expect(manifest.contains('malformed original'), isTrue);
        expect(
          db
              .select('SELECT name FROM entries')
              .any((r) => (r['name'] as String).contains('outside')),
          isFalse,
        );
      } finally {
        db.close();
      }
    },
  );

  test(
    'media symlinks are inventoried but never followed, including nested outside directories',
    () async {
      final outside = Directory('${temp.path}/outside')..createSync();
      File('${outside.path}/secret.txt').writeAsStringSync('OUTSIDE-SECRET');
      Link('${support.path}/pod_drafts/link').createSync(outside.path);
      final receipt = await preserve();
      expect(receipt.sourceIssues, greaterThan(1));
      final db = inspectArchive();
      try {
        expect(db.select('SELECT name FROM entries').length, 3);
      } finally {
        db.close();
      }
      expect(
        File('${outside.path}/secret.txt').readAsStringSync(),
        'OUTSIDE-SECRET',
      );
    },
  );

  test(
    'missing archive key never resets or rewrites encrypted evidence',
    () async {
      await preserve();
      final bytes = archiveFile().readAsBytesSync();
      vault.values.clear();
      await expectLater(preserve(), fails('ARCHIVE_KEY_MISSING'));
      expect(archiveFile().readAsBytesSync(), bytes);
      expect(vault.values, isEmpty);
      unchanged();
    },
  );

  test(
    'lost key-write acknowledgement retries with the same key before copying',
    () async {
      vault.failAfterWrite = true;
      await expectLater(preserve(), fails('ARCHIVE_REQUIRES_RECOVERY'));
      final key = vault.values.values.single;
      vault.failAfterWrite = false;
      await preserve();
      expect(vault.values.values.single, key);
      unchanged();
    },
  );

  test(
    'corrupt encrypted content is not overwritten or silently recopied',
    () async {
      await preserve();
      final db = inspectArchive();
      db.execute(
        "UPDATE chunks SET bytes=x'00' WHERE name='media/pod_evidence/photo.jpg' AND ordinal=0",
      );
      db.close();
      final bytes = archiveFile().readAsBytesSync();
      await expectLater(preserve(), fails('ARCHIVE_CONTENT_MISMATCH'));
      expect(archiveFile().readAsBytesSync(), bytes);
      unchanged();
    },
  );

  test(
    'unknown legacy schema and active journal are refused without new archive data',
    () async {
      final journal = File('$sourcePath-journal')
        ..writeAsStringSync('retain interrupted journal');
      await expectLater(preserve(), fails('LEGACY_WRITER_NOT_QUIESCENT'));
      journal.renameSync('${temp.path}/retained-journal-fixture');
      final db = await old.databaseFactoryFfi.openDatabase(sourcePath);
      await db.execute('PRAGMA user_version=99');
      await db.close();
      await expectLater(preserve(), fails('UNSUPPORTED_LEGACY_VERSION'));
      expect(output.listSync(), isEmpty);
    },
  );

  test(
    'a missing archive database cannot be recreated over its creation marker',
    () async {
      await preserve();
      final file = archiveFile();
      file.renameSync('${temp.path}/retained-encrypted-copy');
      await expectLater(preserve(), fails('ARCHIVE_DATABASE_MISSING'));
      expect(file.existsSync(), isFalse);
      unchanged();
    },
  );

  test(
    'wrong and malformed keys refuse existing bytes without repair',
    () async {
      await preserve();
      final bytes = archiveFile().readAsBytesSync();
      final keyName = vault.values.keys.single;
      final valid = vault.values[keyName]!;
      vault.values[keyName] = '{bad';
      await expectLater(preserve(), fails('ARCHIVE_KEY_CORRUPT'));
      final record = jsonDecode(valid) as Map<String, dynamic>;
      record['key'] = base64Encode(List.filled(32, 0));
      vault.values[keyName] = jsonEncode(record);
      await expectLater(preserve(), fails('ARCHIVE_REQUIRES_RECOVERY'));
      expect(archiveFile().readAsBytesSync(), bytes);
      vault.values[keyName] = valid;
      await preserve();
      unchanged();
    },
  );

  test(
    'a second writer is excluded without replacing the first archive or key',
    () async {
      var checked = false;
      await preserve(
        checkpoint: (step) async {
          if (step == 'manifest_committed' && !checked) {
            checked = true;
            final key = vault.values.values.single;
            await expectLater(preserve(), fails('ARCHIVE_REQUIRES_RECOVERY'));
            expect(vault.values.values.single, key);
          }
        },
      );
      expect(checked, isTrue);
      unchanged();
    },
  );

  test(
    'database mutation before the receipt is detected and never seals old/new mixed state',
    () async {
      await expectLater(
        preserve(
          checkpoint: (step) async {
            if (step == 'before_source_recheck') {
              final db = await old.databaseFactoryFfi.openDatabase(sourcePath);
              await db.update('driver_command_outbox', {'status': 'completed'});
              await db.close();
            }
          },
        ),
        fails('LEGACY_SOURCE_CHANGED'),
      );
      final db = inspectArchive();
      try {
        expect(
          db.select('SELECT state FROM snapshots').single['state'],
          'copying',
        );
      } finally {
        db.close();
      }
    },
  );

  test(
    'native preference adapter reloads only known drafts without clearing malformed values',
    () async {
      SharedPreferences.setMockInitialValues(
        preferences.cast<String, Object>(),
      );
      final selected = await readLegacyDraftPreferences();
      expect(selected.keys, isNot(contains('rounds_driver_access_token')));
      expect(selected.length, 6);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'rounds_driver_access_token',
        ),
        'MUST-NOT-COPY-AUTH',
      );
    },
  );
}
