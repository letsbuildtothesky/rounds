import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';
import 'package:rounds_driver_harness/src/v23/device_registration_client.dart';
import 'package:rounds_driver_harness/src/v23/private_filesystem.dart';

import 'v23_device_registration_test.dart' as fixture;

const asset = '11111111-aaaa-4111-8111-111111111111';
const asset2 = '22222222-aaaa-4222-8222-222222222222';
const entity = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
final captured = DateTime.utc(2026, 9, 8, 12);
final photo = Uint8List.fromList([
  0xff,
  0xd8,
  ...utf8.encode('private-photo-never-on-disk-' * 300),
  0xff,
  0xd9,
]);
Matcher fails(String code) => throwsA(
  isA<EncryptedStoreException>().having((e) => e.code, 'safe code', code),
);

void main() {
  late Directory temp;
  late fixture.Fixture auth;
  late DriverDeviceRegistrationClient client;
  late RegisteredDriverDevice device;
  final stores = <EncryptedDriverStore>[];

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('rounds-v23-encryption-test-');
    auth = fixture.Fixture();
    client = auth.make();
    device = await client.ensureSession('A');
  });
  tearDown(() {
    for (final store in stores) {
      store.close();
    }
    stores.clear();
    client.dispose();
    // Only this test-created directory, never a user's database/evidence.
    temp.deleteSync(recursive: true);
  });

  Future<EncryptedDriverStore> open({
    RegisteredDriverDevice? asDevice,
    Future<void> Function(String)? checkpoint,
  }) async {
    final store = await EncryptedDriverStore.open(
      device: asDevice ?? device,
      privateParent: temp,
      secrets: auth.secrets,
      checkpoint: checkpoint,
    );
    stores.add(store);
    return store;
  }

  Future<StoredEvidence> save(
    EncryptedDriverStore store, {
    String id = asset,
    Uint8List? bytes,
  }) => store.saveEvidence(
    assetId: id,
    purposeKind: 'proof',
    purposeEntityId: entity,
    mimeType: 'image/jpeg',
    capturedAt: captured,
    bytes: bytes ?? photo,
  );

  String keyRecord() => auth.secrets.values.entries
      .singleWhere((e) => e.key.startsWith('working-store.'))
      .value;
  String keyName() => auth.secrets.values.keys.singleWhere(
    (k) => k.startsWith('working-store.'),
  );
  sql.Database rawDatabase(String path, {bool wrongKey = false}) {
    final db = sql.sqlite3.open(path);
    db.execute('PRAGMA cipher_log_level = NONE');
    final bytes = wrongKey
        ? List.filled(32, 99)
        : base64Decode((jsonDecode(keyRecord()) as Map)['database'] as String);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    db.execute('PRAGMA key = "x\'$hex\'"');
    return db;
  }

  test(
    'real SQLCipher / AEAD bytes, correct-key reopen, no plaintext header or photo',
    () async {
      final store = await open();
      final result = await save(store);
      expect(result.state, 'saved');
      expect(result.sha256, sha256.convert(photo).toString());
      expect(await store.readEvidence(asset), photo);
      store.close();
      final dbBytes = File('${store.directory}/work.db').readAsBytesSync();
      expect(latin1.decode(dbBytes).contains('SQLite format 3'), isFalse);
      expect(latin1.decode(dbBytes).contains(fixture.principalA), isFalse);
      expect(
        latin1
            .decode(
              File('${store.directory}/media/$asset.sealed').readAsBytesSync(),
            )
            .contains('private-photo-never'),
        isFalse,
      );
      final unkeyed = sql.sqlite3.open('${store.directory}/work.db');
      try {
        expect(
          () => unkeyed.select('SELECT * FROM account_context'),
          throwsA(isA<sql.SqliteException>()),
        );
      } finally {
        unkeyed.close();
      }
      final wrong = rawDatabase('${store.directory}/work.db', wrongKey: true);
      try {
        expect(
          () => wrong.select('SELECT * FROM account_context'),
          throwsA(isA<sql.SqliteException>()),
        );
      } finally {
        wrong.close();
      }
      final reopened = await open();
      expect(await reopened.readEvidence(asset), photo);
      expect((await reopened.recoverEvidence()).needsRecovery, isEmpty);
    },
  );

  test('actual cipher runtime is reported without key material', () async {
    final db = sql.sqlite3.openInMemory();
    try {
      final cipher = db.select('PRAGMA cipher_version').single.values.single;
      expect(cipher, startsWith('4.'));
      // Runtime provenance, not an Android/iOS or FIPS certification.
      // ignore: avoid_print
      print('Storage test: SQLCipher $cipher / SQLite ${sql.sqlite3.version}');
    } finally {
      db.close();
    }
  });

  for (final boundary in [
    'metadata_committed',
    'file_staged',
    'file_renamed',
    'saved_committed',
  ]) {
    test(
      'restart after $boundary preserves committed metadata and recovers only authenticated files',
      () async {
        final store = await open(
          checkpoint: (step) async {
            if (step == boundary) throw StateError('simulated interruption');
          },
        );
        await expectLater(save(store), fails('STORAGE_IO_FAILED'));
        store.close();
        final resumed = await open();
        final report = await resumed.recoverEvidence();
        if (boundary == 'metadata_committed') {
          expect(report.needsRecovery, [asset]);
          await expectLater(
            resumed.readEvidence(asset),
            fails('EVIDENCE_NOT_SAVED'),
          );
        } else {
          expect(report.needsRecovery, isEmpty);
          expect(await resumed.readEvidence(asset), photo);
          expect((await save(resumed)).assetId, asset);
        }
        expect(report.maySwitchClient, isFalse);
        expect((await resumed.recoverEvidence()).recovered, isEmpty);
      },
    );
  }

  test(
    'retry exact ID is idempotent; changed bytes or metadata never overwrite',
    () async {
      final store = await open();
      await save(store);
      final file = File('${store.directory}/media/$asset.sealed');
      final before = file.readAsBytesSync();
      await save(store);
      await expectLater(
        save(store, bytes: Uint8List.fromList([1, 2, 3])),
        fails('EVIDENCE_ID_CONFLICT'),
      );
      await expectLater(
        store.saveEvidence(
          assetId: asset,
          purposeKind: 'damage',
          purposeEntityId: entity,
          mimeType: 'image/jpeg',
          capturedAt: captured,
          bytes: photo,
        ),
        fails('EVIDENCE_ID_CONFLICT'),
      );
      expect(file.readAsBytesSync(), before);
    },
  );

  test(
    'ciphertext alteration, truncation, and substitution fail authentication; originals retained',
    () async {
      final store = await open();
      await save(store);
      await save(store, id: asset2);
      final file = File('${store.directory}/media/$asset.sealed');
      final original = file.readAsBytesSync();
      final altered = Uint8List.fromList(original)..[40] ^= 1;
      file.writeAsBytesSync(altered, flush: true);
      await expectLater(
        store.readEvidence(asset),
        fails('EVIDENCE_AUTHENTICATION_FAILED'),
      );
      file.writeAsBytesSync(original.sublist(0, 35), flush: true);
      await expectLater(
        store.readEvidence(asset),
        fails('EVIDENCE_AUTHENTICATION_FAILED'),
      );
      file.writeAsBytesSync(
        File('${store.directory}/media/$asset2.sealed').readAsBytesSync(),
        flush: true,
      );
      await expectLater(
        store.readEvidence(asset),
        fails('EVIDENCE_AUTHENTICATION_FAILED'),
      );
      expect((await store.recoverEvidence()).needsRecovery, [asset]);
      expect(file.existsSync(), isTrue);
      expect(await store.readEvidence(asset2), photo);
    },
  );

  test(
    'AAD prevents metadata/purpose tampering even after SQL-level edit',
    () async {
      final store = await open();
      await save(store);
      store.close();
      final db = rawDatabase('${store.directory}/work.db');
      db.execute("UPDATE local_assets SET purpose_kind='damage'");
      db.close();
      final reopened = await open();
      await expectLater(
        reopened.readEvidence(asset),
        fails('EVIDENCE_AUTHENTICATION_FAILED'),
      );
    },
  );

  test(
    'unknown encrypted or staged orphans are counted and never deleted/adopted',
    () async {
      final store = await open();
      final orphan = File('${store.directory}/media/orphan.stage')
        ..writeAsBytesSync([1, 2, 3], flush: true);
      final report = await store.recoverEvidence();
      expect(report.orphanCount, 1);
      expect(report.maySwitchClient, isFalse);
      expect(orphan.readAsBytesSync(), [1, 2, 3]);
    },
  );

  test(
    'key loss/corruption/wrong key fail closed without replacing DB or original secret',
    () async {
      final store = await open();
      await save(store);
      store.close();
      final db = File('${store.directory}/work.db');
      final before = db.readAsBytesSync(),
          record = keyRecord(),
          name = keyName();
      auth.secrets.values.remove(name);
      await expectLater(open(), fails('ENCRYPTION_KEY_MISSING'));
      expect(auth.secrets.values.containsKey(name), isFalse);
      auth.secrets.values[name] = 'corrupt';
      await expectLater(open(), fails('ENCRYPTION_KEY_CORRUPT'));
      final wrong = jsonDecode(record) as Map<String, dynamic>;
      wrong['database'] = base64Encode(List.filled(32, 0));
      auth.secrets.values[name] = jsonEncode(wrong);
      await expectLater(open(), fails('STORAGE_REQUIRES_RECOVERY'));
      expect(db.readAsBytesSync(), before);
      auth.secrets.values[name] = record;
      expect(await (await open()).readEvidence(asset), photo);
    },
  );

  test(
    'key write failure never creates a database; lost acknowledgment reuses stored key',
    () async {
      auth.secrets.throwAfterWrite = true;
      await expectLater(open(), fails('STORAGE_REQUIRES_RECOVERY'));
      final record = keyRecord();
      expect(
        temp.listSync(recursive: true).where((f) => f.path.endsWith('work.db')),
        isEmpty,
      );
      auth.secrets.throwAfterWrite = false;
      final store = await open();
      await save(store);
      expect(keyRecord(), record);
    },
  );

  test(
    'one native writer lock; unlock on close permits recovery, never deletes lock file',
    () async {
      final store = await open();
      await expectLater(open(), fails('STORAGE_REQUIRES_RECOVERY'));
      expect(File('${store.directory}/.writer.lock').existsSync(), isTrue);
      store.close();
      expect((await open()).directory, store.directory);
    },
  );

  test(
    'sign-out invalidates handles, closes database, retains files and keys',
    () async {
      final store = await open();
      await save(store);
      final keys = Map.of(auth.secrets.values);
      client.lock();
      await expectLater(store.readEvidence(asset), fails('STORE_LOCKED'));
      await expectLater(open(), fixture.failure('SESSION_CHANGED'));
      expect(auth.secrets.values, keys);
      device = await client.ensureSession('A');
      expect(await (await open()).readEvidence(asset), photo);
    },
  );

  test(
    'different verified principal gets separate keys/files and cannot read previous asset',
    () async {
      final first = await open();
      await save(first);
      final other = await client.ensureSession('B');
      await expectLater(first.readEvidence(asset), fails('STORE_LOCKED'));
      final second = await open(asDevice: other);
      expect(second.directory, isNot(first.directory));
      await expectLater(
        second.readEvidence(asset),
        fails('EVIDENCE_NOT_SAVED'),
      );
      await save(second, bytes: Uint8List.fromList([9, 8, 7]));
      expect(
        auth.secrets.values.keys
            .where((k) => k.startsWith('working-store.'))
            .length,
        2,
      );
      device = await client.ensureSession('A');
      expect(await (await open()).readEvidence(asset), photo);
    },
  );

  test(
    'lock during encryption/write boundary never reports saved; restart recovers staged file',
    () async {
      final gate = Completer<void>(), release = Completer<void>();
      final store = await open(
        checkpoint: (step) async {
          if (step == 'file_staged') {
            gate.complete();
            await release.future;
          }
        },
      );
      final work = save(store);
      final assertion = expectLater(work, fails('STORE_LOCKED'));
      await gate.future;
      client.lock();
      release.complete();
      await assertion;
      device = await client.ensureSession('A');
      final resumed = await open();
      expect((await resumed.recoverEvidence()).recovered, [asset]);
      expect(await resumed.readEvidence(asset), photo);
    },
  );

  test(
    'frozen caller bytes survive concurrent mutation and duplicate requests serialize',
    () async {
      final store = await open();
      final bytes = Uint8List.fromList(photo);
      final work = save(store, bytes: bytes);
      bytes.fillRange(0, bytes.length, 0);
      await work;
      await Future.wait([save(store), save(store)]);
      expect(await store.readEvidence(asset), photo);
    },
  );

  test('size/id limits reject before any photo metadata write', () async {
    final store = await open();
    await expectLater(save(store, id: '../escape'), fails('INVALID_EVIDENCE'));
    await expectLater(
      save(store, bytes: Uint8List(0)),
      fails('INVALID_EVIDENCE'),
    );
    await expectLater(
      save(store, bytes: Uint8List(EncryptedDriverStore.maxEvidenceBytes + 1)),
      fails('INVALID_EVIDENCE'),
    );
    expect(Directory('${store.directory}/media').listSync(), isEmpty);
  });

  test('symlink photo target is refused without altering its target', () async {
    final store = await open();
    final target = File('${temp.path}/unrelated')
      ..writeAsStringSync('leave alone');
    Link('${store.directory}/media/$asset.stage').createSync(target.path);
    await expectLater(save(store), fails('UNSAFE_STORAGE_PATH'));
    expect(target.readAsStringSync(), 'leave alone');
  });

  test(
    'schema hash/version mismatch never migrates or replaces unknown database',
    () async {
      final store = await open();
      await save(store);
      store.close();
      final db = rawDatabase('${store.directory}/work.db');
      db.userVersion = 99;
      db.close();
      final before = File('${store.directory}/work.db').readAsBytesSync();
      await expectLater(open(), fails('STORAGE_REQUIRES_RECOVERY'));
      expect(File('${store.directory}/work.db').readAsBytesSync(), before);
    },
  );

  test(
    'revocation locks open stores before network outcome and cannot reopen old handle',
    () async {
      final store = await open();
      await save(store);
      await client.revoke('A');
      await expectLater(store.readEvidence(asset), fails('STORE_LOCKED'));
      await expectLater(open(), fixture.failure('SESSION_CHANGED'));
      expect(
        File('${store.directory}/media/$asset.sealed').existsSync(),
        isTrue,
      );
    },
  );

  test(
    'old verified handles never revive after switching accounts and switching back',
    () async {
      final old = device;
      final first = await open();
      await save(first);
      await client.ensureSession('B');
      device = await client.ensureSession('A');
      await expectLater(
        open(asDevice: old),
        fixture.failure('SESSION_CHANGED'),
      );
      expect(await (await open()).readEvidence(asset), photo);
    },
  );

  test(
    'missing database with retained ciphertext refuses to recreate an empty working store',
    () async {
      final store = await open();
      await save(store);
      store.close();
      File(
        '${store.directory}/work.db',
      ).renameSync('${store.directory}/work.db.retained-test-copy');
      await expectLater(open(), fails('DATABASE_MISSING_WITH_EVIDENCE'));
      expect(File('${store.directory}/work.db').existsSync(), isFalse);
      expect(
        File('${store.directory}/media/$asset.sealed').existsSync(),
        isTrue,
      );
    },
  );

  test(
    'new namespace does not touch legacy DB, draft or partially uploaded file fixtures',
    () async {
      final oldDb = File('${temp.path}/rounds_phase_zero.db')
        ..writeAsStringSync('untouched legacy fixture');
      final oldMedia = File('${temp.path}/legacy-uploading.jpg')
        ..writeAsBytesSync(photo);
      final oldPrefs = File('${temp.path}/legacy-prefs.fixture')
        ..writeAsStringSync('{"uploadOffset":512,"status":"sending"}');
      final originals = {
        for (final f in [oldDb, oldMedia, oldPrefs])
          f.path: f.readAsBytesSync(),
      };
      final store = await open();
      await save(store);
      await store.recoverEvidence();
      store.close();
      for (final entry in originals.entries) {
        expect(File(entry.key).readAsBytesSync(), entry.value);
      }
      // Separate v23_legacy_upgrade_inventory_test uses actual schema5/outboxes.
    },
  );

  test(
    'directory fsync and lock path guards reject missing paths and dangling symlinks',
    () {
      final fs = PrivateFilesystem();
      expect(
        () => fs.syncDirectory('${temp.path}/missing'),
        throwsA(isA<PrivateFilesystemException>()),
      );
      final outside = File('${temp.path}/must-not-be-created');
      final danglingLock = Link('${temp.path}/dangling-writer.lock')
        ..createSync(outside.path);
      expect(
        () => fs.acquire(danglingLock.path),
        throwsA(isA<PrivateFilesystemException>()),
      );
      expect(outside.existsSync(), isFalse);
      expect(danglingLock.targetSync(), outside.path);
    },
  );
}
