import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugAcceptancePhoto {
  const DebugAcceptancePhoto({required this.path, required this.capturedAt});

  final String path;
  final DateTime capturedAt;
}

class DebugAcceptancePhotoStore {
  DebugAcceptancePhotoStore({
    required SharedPreferences preferences,
    required Directory supportDirectory,
  }) : _preferences = preferences,
       _supportDirectory = supportDirectory;

  static const _pathKey = 'debug_acceptance_photo_path';
  static const _capturedAtKey = 'debug_acceptance_photo_captured_at';

  final SharedPreferences _preferences;
  final Directory _supportDirectory;

  static Future<DebugAcceptancePhotoStore> create() async =>
      DebugAcceptancePhotoStore(
        preferences: await SharedPreferences.getInstance(),
        supportDirectory: await getApplicationSupportDirectory(),
      );

  Future<DebugAcceptancePhoto?> restore() async {
    final savedPath = _preferences.getString(_pathKey);
    final capturedAt = DateTime.tryParse(
      _preferences.getString(_capturedAtKey) ?? '',
    );
    if (savedPath == null || capturedAt == null) return null;
    final file = File(savedPath);
    if (!await file.exists() || await file.length() == 0) {
      await _clearPreferences();
      return null;
    }
    return DebugAcceptancePhoto(path: savedPath, capturedAt: capturedAt);
  }

  Future<DebugAcceptancePhoto> retain(String capturedPath) async {
    final source = File(capturedPath);
    if (!await source.exists() || await source.length() == 0) {
      throw const FileSystemException('The captured photo is empty');
    }

    final directory = Directory(
      path.join(_supportDirectory.path, 'debug_acceptance'),
    );
    await directory.create(recursive: true);
    final extension = path.extension(capturedPath).toLowerCase() == '.png'
        ? '.png'
        : '.jpg';
    final retainedPath = path.join(directory.path, 'latest$extension');
    final temporaryPath = '$retainedPath.pending';
    final retained = File(retainedPath);
    final temporary = File(temporaryPath);
    if (await temporary.exists()) await temporary.delete();
    await source.copy(temporaryPath);
    if (await retained.exists()) await retained.delete();
    await temporary.rename(retainedPath);

    final previousPath = _preferences.getString(_pathKey);
    if (previousPath != null && previousPath != retainedPath) {
      final previous = File(previousPath);
      if (await previous.exists()) await previous.delete();
    }

    final capturedAt = DateTime.now().toUtc();
    await _preferences.setString(_pathKey, retainedPath);
    await _preferences.setString(_capturedAtKey, capturedAt.toIso8601String());
    return DebugAcceptancePhoto(path: retainedPath, capturedAt: capturedAt);
  }

  Future<void> clear() async {
    final savedPath = _preferences.getString(_pathKey);
    if (savedPath != null) {
      final file = File(savedPath);
      if (await file.exists()) await file.delete();
    }
    await _clearPreferences();
  }

  Future<void> _clearPreferences() async {
    await _preferences.remove(_pathKey);
    await _preferences.remove(_capturedAtKey);
  }
}
