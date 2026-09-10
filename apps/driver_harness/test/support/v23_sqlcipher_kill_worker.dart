// Only driven by tools/verify_v23_sqlcipher_crash.py in its own temp fixture.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:rounds_driver_harness/src/v23/sqlcipher_database.dart';
import 'package:rounds_driver_harness/src/v23/private_filesystem.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2 ||
      !{'init', 'hold', 'verify', 'lock'}.contains(args[0]) ||
      !Directory(args[1])
          .resolveSymbolicLinksSync()
          .split('/')
          .last
          .startsWith('rounds-cipher-kill-') ||
      !File('${args[1]}/fixture-only').existsSync()) {
    exit(2);
  }
  final dir = Directory(args[1]).resolveSymbolicLinksSync();
  final key = base64Decode(
    await stdin.transform(utf8.decoder).transform(const LineSplitter()).first,
  );
  final fs = PrivateFilesystem();
  void Function()? release;
  try {
    release = fs.acquire('$dir/.writer.lock');
  } on PrivateFilesystemException {
    if (args[0] == 'lock') {
      stdout.writeln('LOCK_DENIED');
      return;
    }
    rethrow;
  }
  if (args[0] == 'lock') {
    release();
    exit(3);
  }
  final db = openCipherDatabase('$dir/cipher.db', Uint8List.fromList(key));
  if (args[0] == 'init') {
    db.execute(
      'CREATE TABLE probe (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
    );
    db.execute("INSERT INTO probe VALUES (1,'confirmed-before-kill')");
    db.close();
    fs.syncDirectory(dir);
    release();
    stdout.writeln('INITIALIZED');
  } else if (args[0] == 'hold') {
    db.execute('PRAGMA cache_size = 2');
    db.execute('BEGIN IMMEDIATE');
    db.execute("UPDATE probe SET value='uncommitted-after-kill' WHERE id=1");
    for (var i = 2; i < 128; i++) {
      db.execute('INSERT INTO probe VALUES (?,?)', [
        i,
        'private-journal-canary-' * 512,
      ]);
    }
    stdout.writeln('READY_TO_KILL');
    await stdout.flush();
    Timer.periodic(
      const Duration(seconds: 1),
      (_) {},
    ); // Parent SIGKILLs this process; no finally/close.
    await Completer<void>().future;
  } else {
    final rows = db.select('SELECT * FROM probe');
    if (rows.length != 1 ||
        rows.single['value'] != 'confirmed-before-kill' ||
        db.select('PRAGMA cipher_integrity_check').isNotEmpty ||
        db.select('PRAGMA integrity_check').single.values.single != 'ok') {
      exit(4);
    }
    db.close();
    release();
    stdout.writeln('RECOVERED_ORIGINAL_COMMIT');
  }
}
