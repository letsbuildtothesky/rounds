import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// POSIX durability/locking for our dedicated private working directory only.
/// No deletion API. Unsupported hosts fail closed. Real mobile/OEM tests remain
/// required: a successful fsync is not a guarantee against faulty hardware.
class PrivateFilesystem {
  PrivateFilesystem() {
    if (!Platform.isAndroid &&
        !Platform.isIOS &&
        !Platform.isMacOS &&
        !Platform.isLinux) {
      throw const PrivateFilesystemException();
    }
  }
  static final _lib = DynamicLibrary.process();
  static final _open = _lib
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32),
        int Function(Pointer<Utf8>, int)
      >('open');
  static final _close = _lib
      .lookupFunction<Int32 Function(Int32), int Function(int)>('close');
  static final _sync = _lib
      .lookupFunction<Int32 Function(Int32), int Function(int)>('fsync');
  static final _flock = _lib
      .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
        'flock',
      );
  static final _chmod = _lib
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Uint32),
        int Function(Pointer<Utf8>, int)
      >('chmod');

  int _openRead(String path) {
    final name = path.toNativeUtf8();
    try {
      final fd = _open(name, 0); // O_RDONLY on supported POSIX platforms.
      if (fd < 0) throw const PrivateFilesystemException();
      return fd;
    } finally {
      calloc.free(name);
    }
  }

  void syncDirectory(String path) {
    final fd = _openRead(path);
    try {
      if (_sync(fd) != 0) throw const PrivateFilesystemException();
    } finally {
      _close(fd);
    }
  }

  void protect(String path, {required bool directory}) {
    final name = path.toNativeUtf8();
    try {
      if (_chmod(name, directory ? 448 : 384) != 0) {
        throw const PrivateFilesystemException(); //0700 /0600
      }
    } finally {
      calloc.free(name);
    }
  }

  /// flock locks independent opens even in separate isolates in one process.
  /// Never unlink the lock file: that would permit two owners on different inodes.
  void Function() acquire(String path) {
    // existsSync follows links: testing it before the link type could create a
    // dangling symlink's target outside our private directory.
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      File(path).writeAsBytesSync([], flush: true);
    } else if (type != FileSystemEntityType.file) {
      throw const PrivateFilesystemException();
    }
    if (FileSystemEntity.typeSync(path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const PrivateFilesystemException();
    }
    protect(path, directory: false);
    final fd = _openRead(path);
    if (_flock(fd, 2 | 4) != 0) {
      _close(fd);
      throw const PrivateFilesystemException();
    }
    var released = false;
    return () {
      if (!released) {
        released = true;
        _close(fd);
      }
    };
  }
}

class PrivateFilesystemException implements Exception {
  const PrivateFilesystemException();
  @override
  String toString() => 'PrivateFilesystemException(STORAGE_IO_FAILED)';
}
