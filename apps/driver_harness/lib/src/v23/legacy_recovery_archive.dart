import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as legacy;
import 'package:sqlite3/sqlite3.dart' as cipher;

import 'device_registration_client.dart';
import 'legacy_upgrade_inventory.dart';
import 'private_filesystem.dart';
import 'sqlcipher_database.dart';

part 'legacy_recovery_source.dart';

/// Preservation ONLY. No account principal, plaintext read/export, upload,
/// replay, deletion, or cutover API. Unknown old owners stay unassigned.
/// The lifecycle broker must pause/close ALL old writers before invocation.
/// The default-off startup checkpoint calls this before creating legacy workers;
/// a running old client cannot be paused safely by this archive module alone.
class LegacyRecoveryArchive {
  static const _chunkBytes = 256 * 1024;
  static const _schema = '''
    CREATE TABLE archive_format (id INTEGER PRIMARY KEY CHECK(id=1), scope TEXT NOT NULL, version INTEGER NOT NULL CHECK(version=1));
    CREATE TABLE snapshots (id TEXT PRIMARY KEY, manifest TEXT NOT NULL, state TEXT NOT NULL CHECK(state IN ('copying','sealed')), sealed_at TEXT);
    CREATE TABLE entries (snapshot_id TEXT NOT NULL REFERENCES snapshots(id), name TEXT NOT NULL, sha256 TEXT NOT NULL, byte_size INTEGER NOT NULL, PRIMARY KEY(snapshot_id,name));
    CREATE TABLE chunks (snapshot_id TEXT NOT NULL, name TEXT NOT NULL, ordinal INTEGER NOT NULL, bytes BLOB NOT NULL, PRIMARY KEY(snapshot_id,name,ordinal), FOREIGN KEY(snapshot_id,name) REFERENCES entries(snapshot_id,name));
    PRAGMA user_version=1;
  ''';

  /// Returns only aggregate preservation evidence, never old row/file contents.
  /// [readDraftPreferences] must reload the allowlisted preferences each time.
  /// Explicit paths must be app-private; tests supply owned temporary fixtures.
  static Future<LegacyRecoveryReceipt> preserve({
    required String databasePath,
    required legacy.DatabaseFactory factory,
    required Directory supportDirectory,
    required Directory archiveParent,
    required Future<Map<String, Object?>> Function() readDraftPreferences,
    required DeviceSecretBackend secrets,
    Future<void> Function(String)? checkpoint,
  }) async {
    cipher.Database? db;
    void Function()? release;
    try {
      final source = _LegacySource(
        databasePath,
        supportDirectory,
        factory,
        readDraftPreferences,
      );
      final before = await source.scan();
      final fs = PrivateFilesystem();
      final parent = archiveParent.resolveSymbolicLinksSync();
      // Never put destination bytes inside a scanned media root/source database.
      if (_LegacySource.mediaRoots.any(
        (root) =>
            p.equals(p.join(source.support, root), parent) ||
            p.isWithin(p.join(source.support, root), parent),
      )) {
        throw const LegacyRecoveryException('UNSAFE_ARCHIVE_PATH');
      }
      final scope = _digest(
        utf8.encode(
          'rounds-legacy-archive-v1\n${source.database}\n${source.support}',
        ),
      );
      var directory = parent;
      for (final part in ['rounds_v23_recovery', scope]) {
        final next = p.join(directory, part);
        final type = FileSystemEntity.typeSync(next, followLinks: false);
        if (type == FileSystemEntityType.notFound) {
          Directory(next).createSync();
        } else if (type != FileSystemEntityType.directory) {
          throw const LegacyRecoveryException('UNSAFE_ARCHIVE_PATH');
        }
        fs.protect(next, directory: true);
        fs.syncDirectory(directory);
        directory = next;
      }
      release = fs.acquire(p.join(directory, '.writer.lock'));
      fs.syncDirectory(directory);
      final keyRef = 'legacy-recovery.v1.$scope';
      var raw = await secrets.read(keyRef);
      if (raw == null) {
        if (Directory(
          directory,
        ).listSync().any((e) => p.basename(e.path) != '.writer.lock')) {
          throw const LegacyRecoveryException('ARCHIVE_KEY_MISSING');
        }
        final random = Random.secure();
        raw = jsonEncode({
          'version': 1,
          'scope': scope,
          'key': base64Encode(List.generate(32, (_) => random.nextInt(256))),
        });
        await secrets.write(keyRef, raw);
        if (await secrets.read(keyRef) != raw) {
          throw const LegacyRecoveryException('ARCHIVE_KEY_NOT_DURABLE');
        }
      }
      final path = p.join(directory, 'recovery.db');
      final existing = FileSystemEntity.typeSync(path, followLinks: false);
      for (final name in [
        'recovery.db',
        'recovery.db-journal',
        'recovery.db-wal',
        'recovery.db-shm',
      ]) {
        final type = FileSystemEntity.typeSync(
          p.join(directory, name),
          followLinks: false,
        );
        if (type != FileSystemEntityType.file &&
            type != FileSystemEntityType.notFound) {
          throw const LegacyRecoveryException('UNSAFE_ARCHIVE_PATH');
        }
      }
      if (existing == FileSystemEntityType.notFound &&
          Directory(
            directory,
          ).listSync().any((e) => p.basename(e.path) != '.writer.lock')) {
        throw const LegacyRecoveryException('ARCHIVE_DATABASE_MISSING');
      }
      // A durable, non-secret creation marker distinguishes first creation
      // from a lost database. A crash after the marker but before creation is
      // conservatively recovery-required, never permission to replace data.
      final marker = File(p.join(directory, 'archive.created'));
      if (existing == FileSystemEntityType.notFound) {
        marker.writeAsStringSync('rounds-legacy-recovery-v1', flush: true);
        fs.protect(marker.path, directory: false);
        fs.syncDirectory(directory);
      } else if (FileSystemEntity.typeSync(marker.path, followLinks: false) !=
              FileSystemEntityType.file ||
          marker.lengthSync() != 25 ||
          marker.readAsStringSync() != 'rounds-legacy-recovery-v1') {
        throw const LegacyRecoveryException('ARCHIVE_FORMAT_UNSUPPORTED');
      }
      db = openCipherDatabase(path, _key(raw, scope));
      if (existing == FileSystemEntityType.notFound) {
        _transaction(db, () {
          db!.execute(_schema);
          db.execute('INSERT INTO archive_format VALUES (1,?,1)', [scope]);
        });
      }
      final format = db.select('SELECT * FROM archive_format');
      if (db.userVersion != 1 ||
          format.length != 1 ||
          format.single['scope'] != scope ||
          format.single['version'] != 1) {
        throw const LegacyRecoveryException('ARCHIVE_FORMAT_UNSUPPORTED');
      }
      _integrity(db);
      fs.protect(path, directory: false);
      fs.syncDirectory(directory);
      final prior = db.select(
        'SELECT manifest,state FROM snapshots WHERE id=?',
        [before.id],
      );
      if (prior.isNotEmpty && prior.single['manifest'] != before.manifest) {
        throw const LegacyRecoveryException('ARCHIVE_SNAPSHOT_CONFLICT');
      }
      if (prior.isEmpty) {
        _transaction(
          db,
          () => db!.execute(
            'INSERT INTO snapshots (id,manifest,state) VALUES (?,?,\'copying\')',
            [before.id, before.manifest],
          ),
        );
        fs.syncDirectory(directory);
      }
      await checkpoint?.call('manifest_committed');
      for (final file in before.files.where((f) => f['status'] == 'file')) {
        final name = file['name'] as String;
        final saved = db.select(
          'SELECT * FROM entries WHERE snapshot_id=? AND name=?',
          [before.id, name],
        );
        if (saved.isEmpty) {
          // One file/chunk transaction: a failed copy never leaves a partial entry.
          // Chunked BLOBs stay encrypted by SQLCipher; no plaintext temp files.
          db.execute('BEGIN IMMEDIATE');
          try {
            db.execute('INSERT INTO entries VALUES (?,?,?,?)', [
              before.id,
              name,
              file['sha256'],
              file['size'],
            ]);
            source.requireSafeFile(file['path'] as String);
            final input = File(file['path'] as String).openSync();
            try {
              var ordinal = 0;
              while (true) {
                final bytes = input.readSync(_chunkBytes);
                if (bytes.isEmpty) break;
                try {
                  if (ordinal * _chunkBytes + bytes.length >
                      (file['size'] as int)) {
                    throw const LegacyRecoveryException(
                      'LEGACY_SOURCE_CHANGED',
                    );
                  }
                  db.execute('INSERT INTO chunks VALUES (?,?,?,?)', [
                    before.id,
                    name,
                    ordinal++,
                    bytes,
                  ]);
                } finally {
                  bytes.fillRange(0, bytes.length, 0);
                }
                await checkpoint?.call('chunk_written');
              }
            } finally {
              input.closeSync();
            }
            _verifyEntry(db, before.id, file);
            db.execute('COMMIT');
          } catch (_) {
            db.execute('ROLLBACK');
            rethrow;
          }
          fs.syncDirectory(directory);
        } else {
          _verifyEntry(db, before.id, file);
        }
        await checkpoint?.call('file_committed');
      }
      if (db.select('SELECT count(*) AS n FROM entries WHERE snapshot_id=?', [
            before.id,
          ]).single['n'] !=
          before.fileCount) {
        throw const LegacyRecoveryException('ARCHIVE_CONTENT_MISMATCH');
      }
      await checkpoint?.call('before_source_recheck');
      final after = await source.scan();
      if (before.manifest != after.manifest) {
        throw const LegacyRecoveryException('LEGACY_SOURCE_CHANGED');
      }
      _integrity(db);
      _transaction(
        db,
        () => db!.execute(
          "UPDATE snapshots SET state='sealed',sealed_at=coalesce(sealed_at,?) WHERE id=?",
          [DateTime.now().toUtc().toIso8601String(), before.id],
        ),
      );
      fs.syncDirectory(directory);
      await checkpoint?.call('receipt_committed');
      return LegacyRecoveryReceipt._(
        before.id,
        before.fileCount,
        before.rowCount,
        before.preferenceCount,
        before.issueCount,
      );
    } on LegacyRecoveryException {
      rethrow;
    } on LegacyInventoryException catch (error) {
      throw LegacyRecoveryException(error.code);
    } catch (_) {
      // Native SQL/path/key/provider details must not escape to UI/logs.
      throw const LegacyRecoveryException('ARCHIVE_REQUIRES_RECOVERY');
    } finally {
      try {
        db?.close();
      } finally {
        release?.call();
      }
    }
  }

  static Uint8List _key(String raw, String scope) {
    try {
      if (raw.length > 512) throw const FormatException();
      final record = jsonDecode(raw) as Map<String, dynamic>;
      final key = base64Decode(record['key'] as String);
      if (record.length != 3 ||
          record['version'] != 1 ||
          record['scope'] != scope ||
          key.length != 32 ||
          base64Encode(key) != record['key']) {
        throw const FormatException();
      }
      return key;
    } catch (_) {
      throw const LegacyRecoveryException('ARCHIVE_KEY_CORRUPT');
    }
  }

  static void _transaction(cipher.Database db, void Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      action();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static void _integrity(cipher.Database db) {
    if (db.select('PRAGMA cipher_integrity_check').isNotEmpty ||
        db.select('PRAGMA integrity_check').single.values.single != 'ok' ||
        db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw const LegacyRecoveryException('ARCHIVE_CONTENT_MISMATCH');
    }
  }

  static void _verifyEntry(
    cipher.Database db,
    String snapshot,
    Map<String, Object?> file,
  ) {
    final entries = db.select(
      'SELECT * FROM entries WHERE snapshot_id=? AND name=?',
      [snapshot, file['name']],
    );
    if (entries.length != 1 ||
        entries.single['sha256'] != file['sha256'] ||
        entries.single['byte_size'] != file['size']) {
      throw const LegacyRecoveryException('ARCHIVE_CONTENT_MISMATCH');
    }
    final output = _HashSink();
    final hash = sha256.startChunkedConversion(output);
    var ordinal = 0, size = 0;
    while (true) {
      final rows = db.select(
        'SELECT ordinal,bytes FROM chunks WHERE snapshot_id=? AND name=? AND ordinal>=? ORDER BY ordinal LIMIT 1',
        [snapshot, file['name'], ordinal],
      );
      if (rows.isEmpty) break;
      final row = rows.single;
      final bytes = row['bytes'] as Uint8List;
      try {
        if (row['ordinal'] != ordinal ||
            bytes.isEmpty ||
            bytes.length > _chunkBytes) {
          throw const LegacyRecoveryException('ARCHIVE_CONTENT_MISMATCH');
        }
        size += bytes.length;
        if (size > (file['size'] as int)) {
          throw const LegacyRecoveryException('ARCHIVE_CONTENT_MISMATCH');
        }
        hash.add(bytes);
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
      ordinal++;
    }
    hash.close();
    if (size != file['size'] || output.value.toString() != file['sha256']) {
      throw const LegacyRecoveryException('ARCHIVE_CONTENT_MISMATCH');
    }
  }
}

class _HashSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

String _digest(List<int> bytes) => sha256.convert(bytes).toString();

class LegacyRecoveryReceipt {
  const LegacyRecoveryReceipt._(
    this.snapshotId,
    this.filesPreserved,
    this.rowsPreserved,
    this.preferencesPreserved,
    this.sourceIssues,
  );
  final String snapshotId;
  final int filesPreserved, rowsPreserved, preferencesPreserved, sourceIssues;
  String get disposition => 'quarantined_unassigned';
  bool get maySwitchClient => false;
  bool get eligibleForAutomaticReplay => false;
}

class LegacyRecoveryException implements Exception {
  const LegacyRecoveryException(this.code);
  final String code;
  @override
  String toString() => 'LegacyRecoveryException($code)';
}
