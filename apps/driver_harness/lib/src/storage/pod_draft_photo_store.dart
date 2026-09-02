import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PodDraftPhoto {
  const PodDraftPhoto({required this.path, required this.capturedAt});

  final String path;
  final DateTime capturedAt;
}

class PodDraftPhotoStore {
  PodDraftPhotoStore({
    required SharedPreferences preferences,
    required Directory supportDirectory,
  }) : _preferences = preferences,
       _supportDirectory = supportDirectory;

  final SharedPreferences _preferences;
  final Directory _supportDirectory;

  static Future<PodDraftPhotoStore> create() async => PodDraftPhotoStore(
    preferences: await SharedPreferences.getInstance(),
    supportDirectory: await getApplicationSupportDirectory(),
  );

  Future<PodDraftPhoto?> restore(String stopId) async {
    final savedPath = _preferences.getString(_pathKey(stopId));
    final capturedAt = DateTime.tryParse(
      _preferences.getString(_capturedAtKey(stopId)) ?? '',
    );
    if (savedPath == null || capturedAt == null) return null;
    final file = File(savedPath);
    if (!await file.exists() || await file.length() == 0) {
      await _clearPreferences(stopId);
      return null;
    }
    return PodDraftPhoto(path: savedPath, capturedAt: capturedAt);
  }

  Future<PodDraftPhoto> retain(String stopId, String capturedPath) async {
    final source = File(capturedPath);
    if (!await source.exists() || await source.length() == 0) {
      throw const FileSystemException('The captured delivery photo is empty');
    }

    final stopDirectory = Directory(
      path.join(_supportDirectory.path, 'pod_drafts', _safeSegment(stopId)),
    );
    await stopDirectory.create(recursive: true);
    final extension = path.extension(capturedPath).toLowerCase() == '.png'
        ? '.png'
        : '.jpg';
    final retainedPath = path.join(stopDirectory.path, 'delivery$extension');
    final temporaryPath = '$retainedPath.pending';
    final retained = File(retainedPath);
    final temporary = File(temporaryPath);
    if (await temporary.exists()) await temporary.delete();
    await source.copy(temporaryPath);
    if (await retained.exists()) await retained.delete();
    await temporary.rename(retainedPath);

    final previousPath = _preferences.getString(_pathKey(stopId));
    if (previousPath != null && previousPath != retainedPath) {
      final previous = File(previousPath);
      if (await previous.exists()) await previous.delete();
    }

    final capturedAt = DateTime.now().toUtc();
    await _preferences.setString(_pathKey(stopId), retainedPath);
    await _preferences.setString(
      _capturedAtKey(stopId),
      capturedAt.toIso8601String(),
    );
    return PodDraftPhoto(path: retainedPath, capturedAt: capturedAt);
  }

  Future<void> clear(String stopId) async {
    final savedPath = _preferences.getString(_pathKey(stopId));
    if (savedPath != null) {
      final file = File(savedPath);
      if (await file.exists()) await file.delete();
    }
    await _clearPreferences(stopId);
  }

  Future<void> _clearPreferences(String stopId) async {
    await _preferences.remove(_pathKey(stopId));
    await _preferences.remove(_capturedAtKey(stopId));
  }

  String _pathKey(String stopId) => 'pod_draft_photo_path_$stopId';
  String _capturedAtKey(String stopId) => 'pod_draft_photo_captured_at_$stopId';

  String _safeSegment(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}
