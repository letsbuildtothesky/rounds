import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

import 'device_registration_client.dart';
import 'device_wire.dart';
import 'command_wire.dart';
import 'execution_query.dart';
import 'generated/local_schema.g.dart';
import 'private_filesystem.dart';
import 'sqlcipher_database.dart';

part 'offline_observation_store.dart';
part 'camera_capture_store.dart';
part 'offline_command_store.dart';
part 'photo_transfer_store.dart';
part 'pickup_collection_store.dart';
part 'pickup_issue_store.dart';
part 'pickup_photo_transfer_store.dart';
part 'pickup_issue_form_store.dart';

/// New, opt-in per-principal storage. Never opens/migrates rounds_phase_zero.db.
/// No generic SQL, plaintext export, deletion, automatic legacy import or sender.
/// The UI must not instantiate this until mobile/backup/upgrade gates pass.
class EncryptedDriverStore {
  EncryptedDriverStore._(
    this._device,
    this._db,
    this._mediaKey,
    this.directory,
    this._fs,
    this._release,
    this._checkpoint,
    this._commandClock,
  );

  final RegisteredDriverDevice _device;
  final sql.Database _db;
  final SecretKeyData _mediaKey;
  final String directory;
  final PrivateFilesystem _fs;
  final void Function() _release;
  final Future<void> Function(String)? _checkpoint;
  final DateTime Function() _commandClock;
  void Function()? _unsubscribe;
  bool _closed = false;
  Future<void> _tail = Future<void>.value();
  static const maxEvidenceBytes = 20 * 1024 * 1024;
  static const _magic = [82, 78, 68, 69, 86, 68, 48, 49]; // RNDEVD01
  static final _cipher = AesGcm.with256bits();

  /// privateParent must be the application's private support directory, never
  /// external/shared storage. Tests supply only their own temporary directory.
  /// Native no-backup/file-protection integration remains an activation gate.
  static Future<EncryptedDriverStore> open({
    required RegisteredDriverDevice device,
    required Directory privateParent,
    required DeviceSecretBackend secrets,
    Future<void> Function(String)? checkpoint,
    DateTime Function()? commandClock,
  }) async {
    sql.Database? db;
    SecretKeyData? mediaKey;
    void Function()? release;
    try {
      device.requireCurrentSession();
      // Resolve the app-private parent once; refuse links in owned descendants.
      final parent = privateParent.resolveSymbolicLinksSync();
      final fs = PrivateFilesystem();
      final scope = hash.sha256
          .convert(
            utf8.encode(
              'rounds-store-v1\n${device.storageNamespace}\n${device.principalId}',
            ),
          )
          .toString();
      var dir = parent;
      for (final segment in ['rounds_v23', scope]) {
        final child = p.join(dir, segment);
        final type = FileSystemEntity.typeSync(child, followLinks: false);
        if (type == FileSystemEntityType.notFound) {
          Directory(child).createSync();
        } else if (type != FileSystemEntityType.directory) {
          throw const EncryptedStoreException('UNSAFE_STORAGE_PATH');
        }
        fs.protect(child, directory: true);
        fs.syncDirectory(dir);
        dir = child;
      }
      release = fs.acquire(p.join(dir, '.writer.lock'));
      fs.syncDirectory(dir);
      final keyRef = 'working-store.v1.$scope';
      var raw = await secrets.read(keyRef);
      device.requireCurrentSession();
      if (raw == null) {
        if (Directory(
          dir,
        ).listSync().any((f) => p.basename(f.path) != '.writer.lock')) {
          throw const EncryptedStoreException('ENCRYPTION_KEY_MISSING');
        }
        final random = Random.secure();
        String key() =>
            base64Encode(List.generate(32, (_) => random.nextInt(256)));
        raw = jsonEncode({
          'format': 1,
          'scope': scope,
          'principal': device.principalId,
          'database': key(),
          'media': key(),
        });
        await secrets.write(keyRef, raw);
        if (await secrets.read(keyRef) != raw) {
          throw const EncryptedStoreException('KEY_PERSISTENCE_FAILED');
        }
      }
      device.requireCurrentSession();
      final key = _decodeKeys(raw, scope, device.principalId);
      mediaKey = SecretKeyData(base64Decode(key['media'] as String));
      final dbPath = p.join(dir, 'work.db');
      final type = FileSystemEntity.typeSync(dbPath, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.notFound) {
        throw const EncryptedStoreException('UNSAFE_STORAGE_PATH');
      }
      for (final sidecar in [
        'work.db-journal',
        'work.db-wal',
        'work.db-shm',
        'media',
      ]) {
        if (FileSystemEntity.typeSync(
              p.join(dir, sidecar),
              followLinks: false,
            ) ==
            FileSystemEntityType.link) {
          throw const EncryptedStoreException('UNSAFE_STORAGE_PATH');
        }
      }
      if (type == FileSystemEntityType.notFound &&
          Directory(
            dir,
          ).listSync().any((f) => p.basename(f.path) != '.writer.lock')) {
        throw const EncryptedStoreException('DATABASE_MISSING_WITH_EVIDENCE');
      }
      try {
        db = openCipherDatabase(
          dbPath,
          base64Decode(key['database'] as String),
        );
      } on CipherStorageException catch (error) {
        throw EncryptedStoreException(error.code);
      }
      if (type == FileSystemEntityType.notFound) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(localSchemaSql);
          db.execute(
            'CREATE TABLE store_format (version INTEGER PRIMARY KEY CHECK(version=1), source_sha256 TEXT NOT NULL, scope TEXT NOT NULL)',
          );
          db.execute('INSERT INTO store_format VALUES (1, ?, ?)', [
            localSchemaSha256,
            scope,
          ]);
          db.execute(
            'INSERT INTO account_context (principal_id,device_id,session_epoch,encryption_key_reference,created_at) VALUES (?,?,?,?,?)',
            [
              device.principalId,
              device.deviceId,
              device.epoch,
              keyRef,
              DateTime.now().toUtc().toIso8601String(),
            ],
          );
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      final format = db.select('SELECT * FROM store_format');
      final accounts = db.select('SELECT * FROM account_context');
      if (format.length != 1 ||
          format.single['version'] != 1 ||
          format.single['source_sha256'] != localSchemaSha256 ||
          format.single['scope'] != scope ||
          db.userVersion != 2 ||
          accounts.length != 1 ||
          accounts.single['principal_id'] != device.principalId ||
          accounts.single['device_id'] != device.deviceId ||
          accounts.single['encryption_key_reference'] != keyRef ||
          (accounts.single['session_epoch'] as int) > device.epoch) {
        throw const EncryptedStoreException('STORAGE_REQUIRES_RECOVERY');
      }
      if (db.select('PRAGMA cipher_integrity_check').isNotEmpty ||
          db.select('PRAGMA integrity_check').single.values.single != 'ok' ||
          db.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw const EncryptedStoreException('STORAGE_REQUIRES_RECOVERY');
      }
      fs.protect(dbPath, directory: false);
      fs.syncDirectory(dir);
      final media = p.join(dir, 'media');
      if (!Directory(media).existsSync()) Directory(media).createSync();
      fs.protect(media, directory: true);
      fs.syncDirectory(dir);
      device.requireCurrentSession();
      final store = EncryptedDriverStore._(
        device,
        db,
        mediaKey,
        dir,
        fs,
        release,
        checkpoint,
        commandClock ?? DateTime.now,
      );
      store._unsubscribe = device.onStorageLock(store.close);
      return store;
    } on DeviceEnrollmentException {
      db?.close();
      mediaKey?.destroy();
      release?.call();
      rethrow;
    } on EncryptedStoreException {
      db?.close();
      mediaKey?.destroy();
      release?.call();
      rethrow;
    } catch (_) {
      db?.close();
      mediaKey?.destroy();
      release?.call();
      throw const EncryptedStoreException('STORAGE_REQUIRES_RECOVERY');
    }
  }

  static Map<String, dynamic> _decodeKeys(
    String raw,
    String scope,
    String principal,
  ) {
    try {
      if (raw.length > 1024) throw const FormatException();
      final key = jsonDecode(raw) as Map<String, dynamic>;
      if (key.length != 5 ||
          key['format'] != 1 ||
          key['scope'] != scope ||
          key['principal'] != principal) {
        throw const FormatException();
      }
      for (final field in ['database', 'media']) {
        final bytes = base64Decode(key[field] as String);
        if (bytes.length != 32 || base64Encode(bytes) != key[field]) {
          throw const FormatException();
        }
      }
      return key;
    } catch (_) {
      throw const EncryptedStoreException('ENCRYPTION_KEY_CORRUPT');
    }
  }

  void _active() {
    if (_closed) throw const EncryptedStoreException('STORE_LOCKED');
    _device.requireCurrentSession();
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) async {
      _active();
      try {
        return await operation();
      } on EncryptedStoreException {
        rethrow;
      } on DeviceEnrollmentException {
        rethrow;
      } catch (_) {
        throw const EncryptedStoreException('STORAGE_IO_FAILED');
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _boundary(String name) async {
    await _checkpoint?.call(name);
    _active();
  }

  void _commit(void Function() operation) {
    _active();
    _db.execute('BEGIN IMMEDIATE');
    try {
      operation();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    _fs.syncDirectory(directory);
  }

  /// Supply freshly captured bytes and a stable capture ID, NOT an old outbox
  /// or another account's file. No server proof/verified state is fabricated.
  Future<StoredEvidence> saveEvidence({
    required String assetId,
    required String purposeKind,
    required String purposeEntityId,
    required String mimeType,
    required DateTime capturedAt,
    required Uint8List bytes,
  }) {
    if (!isDeviceUuid(assetId) ||
        assetId != assetId.toLowerCase() ||
        !isDeviceUuid(purposeEntityId) ||
        purposeKind.isEmpty ||
        purposeKind.length > 64 ||
        !{'image/jpeg', 'image/png'}.contains(mimeType) ||
        !capturedAt.isUtc ||
        bytes.isEmpty ||
        bytes.length > maxEvidenceBytes) {
      return Future.error(const EncryptedStoreException('INVALID_EVIDENCE'));
    }
    // Freeze mutable caller bytes before the first await/queue boundary.
    final snapshot = Uint8List.fromList(bytes);
    return _serial(
      () => _persistEvidence(
        assetId: assetId,
        purposeKind: purposeKind,
        purposeEntityId: purposeEntityId,
        mimeType: mimeType,
        capturedAt: capturedAt,
        snapshot: snapshot,
      ),
    ).whenComplete(() => snapshot.fillRange(0, snapshot.length, 0));
  }

  Future<StoredEvidence> _persistEvidence({
    required String assetId,
    required String purposeKind,
    required String purposeEntityId,
    required String mimeType,
    required DateTime capturedAt,
    required Uint8List snapshot,
    void Function()? insertObservation,
  }) async {
    try {
      final row = <String, Object?>{
        'asset_id': assetId,
        'principal_id': _device.principalId,
        'purpose_entity_id': purposeEntityId,
        'purpose_kind': purposeKind,
        'local_private_path': 'media/$assetId.sealed',
        'sha256': hash.sha256.convert(snapshot).toString(),
        'byte_size': snapshot.length,
        'mime_type': mimeType,
        'captured_at': capturedAt.toIso8601String(),
      };
      var prior = _row(assetId);
      if (prior != null) {
        if (_aad(prior) != _aad(row)) {
          throw const EncryptedStoreException('EVIDENCE_ID_CONFLICT');
        }
        if (prior['state'] == 'saved') {
          final verified = await _decrypt(prior);
          verified.fillRange(0, verified.length, 0);
          return StoredEvidence._(prior);
        }
        if (prior['state'] != 'capturing') {
          throw const EncryptedStoreException('EVIDENCE_REQUIRES_RECOVERY');
        }
        if (_file(assetId, false).existsSync() ||
            _file(assetId, true).existsSync()) {
          await _recoverOne(prior);
          return StoredEvidence._(_row(assetId)!);
        }
      } else {
        _commit(() {
          insertObservation?.call();
          _db.execute(
            'INSERT INTO local_assets (${row.keys.join(',')},state) VALUES (${List.filled(row.length, '?').join(',')},\'capturing\')',
            row.values.toList(),
          );
        });
      }
      await _boundary('metadata_committed');
      final box = await _cipher.encrypt(
        snapshot,
        secretKey: _mediaKey,
        aad: utf8.encode(_aad(row)),
      );
      _active();
      final staged = _file(assetId, true);
      if (staged.existsSync() || _file(assetId, false).existsSync()) {
        throw const EncryptedStoreException('EVIDENCE_REQUIRES_RECOVERY');
      }
      final encoded = Uint8List.fromList([
        ..._magic,
        ...box.nonce,
        ...box.mac.bytes,
        ...box.cipherText,
      ]);
      staged.writeAsBytesSync(encoded, flush: true);
      _fs.protect(staged.path, directory: false);
      _fs.syncDirectory(p.dirname(staged.path));
      await _boundary('file_staged');
      staged.renameSync(_file(assetId, false).path);
      _fs.syncDirectory(p.dirname(staged.path));
      await _boundary('file_renamed');
      prior = _row(assetId)!;
      final verified = await _decrypt(prior);
      verified.fillRange(0, verified.length, 0);
      _markSaved(assetId);
      await _boundary('saved_committed');
      return StoredEvidence._(_row(assetId)!);
    } finally {
      snapshot.fillRange(0, snapshot.length, 0);
    }
  }

  // Offline observation methods share this store's queue, SQLCipher connection
  // and transaction with capturing metadata. They never run a second writer.
  Future<void> cacheExecutionContext(ExecutionCaptureContext context) =>
      _serial(() async => _cacheContext(context));

  /// Online adapter only: preserve the first snapshot; invalidate obsolete
  /// authority without modifying any observations or commands.
  Future<ExecutionCaptureContext> acceptOnlineExecutionContext(
    ExecutionCaptureContext context,
  ) => _serial(() async => _acceptOnlineContext(context));

  Future<void> invalidateExecutionContext(
    String assignmentId,
    int version,
  ) => _serial(() async {
    _requireId(assignmentId);
    _requireVersion(version);
    if (_db.select(
      'SELECT 1 FROM execution_fences WHERE principal_id=? AND assignment_id=? AND assignment_version=?',
      [_device.principalId, assignmentId, version],
    ).isEmpty) {
      throw const EncryptedStoreException('EXECUTION_CONTEXT_MISSING');
    }
    _commit(
      () => _db.execute(
        'UPDATE execution_fences SET invalidated_at=COALESCE(invalidated_at,?) WHERE principal_id=? AND assignment_id=? AND assignment_version=?',
        [
          DateTime.now().toUtc().toIso8601String(),
          _device.principalId,
          assignmentId,
          version,
        ],
      ),
    );
  });

  Future<StoredObservation> recordObservation(
    LocalObservationDraft draft, {
    ObservationPhoto? photo,
  }) {
    if (photo?._disposed ?? false) {
      return Future.error(const EncryptedStoreException('INVALID_EVIDENCE'));
    }
    // Copy at invocation, before queuing, and erase our private copy on all exits.
    final snapshot = photo == null ? null : Uint8List.fromList(photo._bytes);
    return _serial(
      () => _recordObservation(draft, photo, snapshot),
    ).whenComplete(() => snapshot?.fillRange(0, snapshot.length, 0));
  }

  Future<StoredObservation> readObservation(String observationId) =>
      _serial(() async {
        _requireId(observationId);
        final row = _observationRow(observationId);
        if (row == null) {
          throw const EncryptedStoreException('OBSERVATION_NOT_FOUND');
        }
        return _inspectObservation(row);
      });

  Future<CameraCaptureIntent> prepareCameraCapture(
    LocalObservationDraft draft, {
    required String assetId,
  }) => _serial(() async => _prepareCameraCapture(draft, assetId));

  Future<void> cancelCameraCapture(String captureId) =>
      _serial(() async => _cancelCameraCapture(captureId));

  Future<List<CameraCaptureIntent>> pendingCameraCaptures() =>
      _serial(() async => _pendingCameraCaptures());

  Future<StoredObservation> finishCameraCapture(
    String captureId, {
    required ObservationPhoto photo,
  }) {
    if (photo._disposed) {
      return Future.error(const EncryptedStoreException('INVALID_EVIDENCE'));
    }
    final snapshot = Uint8List.fromList(photo._bytes);
    return _serial(
      () => _finishCameraCapture(captureId, photo, snapshot),
    ).whenComplete(() => snapshot.fillRange(0, snapshot.length, 0));
  }

  Future<List<StoredObservation>> observations({
    int limit = 100,
    int offset = 0,
  }) => _serial(() async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw const EncryptedStoreException('INVALID_OBSERVATION');
    }
    final rows = _db.select(
      'SELECT * FROM local_observations WHERE principal_id=? ORDER BY observed_at,observation_id LIMIT ? OFFSET ?',
      [_device.principalId, limit, offset],
    );
    final result = <StoredObservation>[];
    for (final row in rows) {
      result.add(await _inspectObservation(row));
    }
    return List.unmodifiable(result);
  });

  Map<String, Object?>? _row(String id) {
    _active();
    final rows = _db.select(
      'SELECT * FROM local_assets WHERE asset_id=? AND principal_id=?',
      [id, _device.principalId],
    );
    return rows.isEmpty ? null : Map<String, Object?>.of(rows.single);
  }

  static String _aad(Map<String, Object?> row) => jsonEncode({
    'format': 'rounds-evidence-v1',
    for (final field in [
      'asset_id',
      'principal_id',
      'purpose_entity_id',
      'purpose_kind',
      'local_private_path',
      'sha256',
      'byte_size',
      'mime_type',
      'captured_at',
    ])
      field: row[field],
  });

  File _file(String id, bool staged) {
    if (!isDeviceUuid(id) || id != id.toLowerCase()) {
      throw const EncryptedStoreException('INVALID_EVIDENCE');
    }
    final media = p.join(directory, 'media');
    if (FileSystemEntity.typeSync(media, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const EncryptedStoreException('UNSAFE_STORAGE_PATH');
    }
    final file = File(p.join(media, '$id.${staged ? 'stage' : 'sealed'}'));
    final type = FileSystemEntity.typeSync(file.path, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.notFound) {
      throw const EncryptedStoreException('UNSAFE_STORAGE_PATH');
    }
    return file;
  }

  Future<Uint8List> _decrypt(
    Map<String, Object?> row, {
    bool staged = false,
  }) async {
    _active();
    final id = row['asset_id'] as String;
    if (row['local_private_path'] != 'media/$id.sealed' ||
        row['principal_id'] != _device.principalId) {
      throw const EncryptedStoreException('EVIDENCE_AUTHENTICATION_FAILED');
    }
    final file = _file(id, staged);
    if (!file.existsSync()) {
      throw const EncryptedStoreException('EVIDENCE_MISSING');
    }
    if (file.lengthSync() != (row['byte_size'] as int) + 36 ||
        file.lengthSync() > maxEvidenceBytes + 36) {
      throw const EncryptedStoreException('EVIDENCE_AUTHENTICATION_FAILED');
    }
    final bytes = file.readAsBytesSync();
    if (!_magic.asMap().entries.every((e) => bytes[e.key] == e.value)) {
      throw const EncryptedStoreException('EVIDENCE_AUTHENTICATION_FAILED');
    }
    List<int> plain;
    try {
      plain = await _cipher.decrypt(
        SecretBox(
          bytes.sublist(36),
          nonce: bytes.sublist(8, 20),
          mac: Mac(bytes.sublist(20, 36)),
        ),
        secretKey: _mediaKey,
        aad: utf8.encode(_aad(row)),
      );
    } catch (_) {
      _active();
      throw const EncryptedStoreException('EVIDENCE_AUTHENTICATION_FAILED');
    }
    final result = Uint8List.fromList(plain);
    try {
      _active();
      if (hash.sha256.convert(result).toString() != row['sha256']) {
        throw const EncryptedStoreException('EVIDENCE_AUTHENTICATION_FAILED');
      }
      return result;
    } catch (_) {
      result.fillRange(0, result.length, 0);
      rethrow;
    }
  }

  Future<Uint8List> readEvidence(String id) => _serial(() async {
    final row = _row(id);
    if (row == null || row['state'] != 'saved') {
      throw const EncryptedStoreException('EVIDENCE_NOT_SAVED');
    }
    return _decrypt(row);
  });

  void _markSaved(String id) => _commit(
    () => _db.execute(
      "UPDATE local_assets SET state='saved' WHERE asset_id=? AND principal_id=? AND state='capturing'",
      [id, _device.principalId],
    ),
  );

  Future<void> _recoverOne(Map<String, Object?> row) async {
    final id = row['asset_id'] as String;
    final finalFile = _file(id, false), stage = _file(id, true);
    if (finalFile.existsSync() && stage.existsSync()) {
      throw const EncryptedStoreException('EVIDENCE_REQUIRES_RECOVERY');
    }
    final plain = await _decrypt(row, staged: !finalFile.existsSync());
    plain.fillRange(0, plain.length, 0);
    _active();
    if (!finalFile.existsSync()) stage.renameSync(finalFile.path);
    _fs.syncDirectory(p.dirname(finalFile.path));
    _markSaved(id);
  }

  /// Explicit restart reconciliation: verifies all saved/pending files and
  /// reports every unreferenced entry. Never deletes or silently adopts orphans.
  Future<EvidenceRecoveryReport> recoverEvidence() => _serial(() async {
    final recovered = <String>[], needsRecovery = <String>[];
    final rows = _db
        .select(
          "SELECT * FROM local_assets WHERE principal_id=? AND state IN ('capturing','saved','needs_recovery')",
          [_device.principalId],
        )
        .map((r) => Map<String, Object?>.of(r))
        .toList();
    for (final row in rows) {
      final id = row['asset_id'] as String;
      try {
        if (row['state'] == 'capturing') {
          await _recoverOne(row);
          recovered.add(id);
        } else if (row['state'] == 'saved') {
          final plain = await _decrypt(row);
          plain.fillRange(0, plain.length, 0);
        } else {
          needsRecovery.add(id);
        }
      } on EncryptedStoreException catch (error) {
        if (!{
          'EVIDENCE_MISSING',
          'EVIDENCE_AUTHENTICATION_FAILED',
          'EVIDENCE_REQUIRES_RECOVERY',
          'UNSAFE_STORAGE_PATH',
        }.contains(error.code)) {
          rethrow;
        }
        _active();
        _commit(
          () => _db.execute(
            "UPDATE local_assets SET state='needs_recovery' WHERE asset_id=?",
            [id],
          ),
        );
        needsRecovery.add(id);
      }
    }
    final referenced = _db
        .select('SELECT local_private_path FROM local_assets')
        .map((r) => r['local_private_path'])
        .toSet();
    // A staged leftover is an orphan too if its final path is already saved.
    final orphans = Directory(p.join(directory, 'media'))
        .listSync(followLinks: false)
        .where((f) => !referenced.contains('media/${p.basename(f.path)}'))
        .length;
    _active();
    return EvidenceRecoveryReport(
      List.unmodifiable(recovered),
      List.unmodifiable(needsRecovery),
      orphans,
    );
  });

  void close() {
    if (_closed) return;
    _closed = true;
    _unsubscribe?.call();
    try {
      _db.close();
    } finally {
      _mediaKey.destroy();
      _release();
    }
  }
}

class StoredEvidence {
  StoredEvidence._(Map<String, Object?> row)
    : assetId = row['asset_id'] as String,
      sha256 = row['sha256'] as String,
      byteSize = row['byte_size'] as int;
  final String assetId, sha256;
  final int byteSize;
  String get state =>
      'saved'; // Local durable bytes only, never server verified.
}

class EvidenceRecoveryReport {
  const EvidenceRecoveryReport(
    this.recovered,
    this.needsRecovery,
    this.orphanCount,
  );
  final List<String> recovered, needsRecovery;
  final int orphanCount;
  bool get maySwitchClient =>
      false; // Legacy migration/activation is independent.
}

class EncryptedStoreException implements Exception {
  const EncryptedStoreException(this.code);
  final String code;
  @override
  String toString() => 'EncryptedStoreException($code)';
}
