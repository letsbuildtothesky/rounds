import 'dart:typed_data';
import 'package:sqlite3/sqlite3.dart' as sql;

/// Shared production/test opener. Never falls back to unencrypted SQLite or
/// repairs/rekeys an unreadable database. Caller owns its dedicated path/lock.
sql.Database openCipherDatabase(String path, Uint8List key) {
  sql.Database? db;
  try {
    if (key.length != 32) throw const CipherStorageException('INVALID_KEY');
    final probe = sql.sqlite3.openInMemory();
    try {
      final version = probe.select('PRAGMA cipher_version');
      if (version.length != 1 ||
          !(version.single.values.single as String).startsWith('4.')) {
        throw const CipherStorageException('SQLCIPHER_UNAVAILABLE');
      }
    } finally {
      probe.close();
    }
    db = sql.sqlite3.open(path);
    final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    db.execute('PRAGMA key = "x\'$hex\'"');
    db.execute('PRAGMA cipher_memory_security = ON');
    db.execute('PRAGMA cipher_log_level = NONE');
    db.execute('PRAGMA cipher_compatibility = 4');
    db.select('SELECT count(*) FROM sqlite_master');
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA temp_store = MEMORY');
    db.execute('PRAGMA synchronous = FULL');
    db.execute('PRAGMA fullfsync = ON');
    if (db.select('PRAGMA journal_mode = DELETE').single.values.single !=
            'delete' ||
        db.select('PRAGMA synchronous').single.values.single != 2 ||
        db.select('PRAGMA temp_store').single.values.single != 2 ||
        db.select('PRAGMA foreign_keys').single.values.single != 1) {
      throw const CipherStorageException('UNSAFE_DATABASE_SETTINGS');
    }
    return db;
  } on CipherStorageException {
    db?.close();
    rethrow;
  } catch (_) {
    db?.close();
    throw const CipherStorageException('STORAGE_REQUIRES_RECOVERY');
  } finally {
    key.fillRange(0, key.length, 0);
  }
}

class CipherStorageException implements Exception {
  const CipherStorageException(this.code);
  final String code;
  @override
  String toString() => 'CipherStorageException($code)';
}
