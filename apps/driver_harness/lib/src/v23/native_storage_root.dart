import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Android supplies its own no-backup root; callers cannot send a path to native.
/// No cache/external/support fallback. iOS remains unsupported by this bridge.
Future<Directory> nativeStorageRoot() async {
  try {
    final value = await const MethodChannel(
      'app.rounds/v23_private_storage',
    ).invokeMapMethod<String, Object?>('rootV1');
    if (value == null ||
        value.length != 3 ||
        value['format'] != 1 ||
        value['policy'] != 'android_no_backup' ||
        value['path'] is! String) {
      throw const FormatException();
    }
    final path = value['path']! as String;
    if (!p.isAbsolute(path) ||
        p.normalize(path) != path ||
        path == p.separator) {
      throw const FormatException();
    }
    final root = Directory(path);
    if (FileSystemEntity.typeSync(path, followLinks: false) !=
            FileSystemEntityType.directory ||
        root.resolveSymbolicLinksSync() != path) {
      throw const FormatException();
    }
    return root;
  } catch (_) {
    throw const NativeStorageRootException();
  }
}

class NativeStorageRootException implements Exception {
  const NativeStorageRootException();
  @override
  String toString() =>
      'NativeStorageRootException(PRIVATE_STORAGE_UNAVAILABLE)';
}
