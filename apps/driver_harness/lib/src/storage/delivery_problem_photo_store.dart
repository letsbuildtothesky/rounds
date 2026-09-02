import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryProblemPhotoStore {
  DeliveryProblemPhotoStore({
    required SharedPreferences preferences,
    required Directory supportDirectory,
  }) : _preferences = preferences,
       _supportDirectory = supportDirectory;

  final SharedPreferences _preferences;
  final Directory _supportDirectory;

  static Future<DeliveryProblemPhotoStore> create() async =>
      DeliveryProblemPhotoStore(
        preferences: await SharedPreferences.getInstance(),
        supportDirectory: await getApplicationSupportDirectory(),
      );

  Future<File?> restore(String stopId) async {
    final savedPath = _preferences.getString(_key(stopId));
    if (savedPath == null) return null;
    final file = File(savedPath);
    if (!await file.exists() || await file.length() == 0) {
      await _preferences.remove(_key(stopId));
      return null;
    }
    return file;
  }

  String restoreNote(String stopId) =>
      _preferences.getString(_noteKey(stopId)) ?? '';

  Future<void> saveNote(String stopId, String note) async {
    if (note.isEmpty) {
      await _preferences.remove(_noteKey(stopId));
      return;
    }
    await _preferences.setString(_noteKey(stopId), note);
  }

  Future<File> retain(String stopId, String capturedPath) async {
    final source = File(capturedPath);
    if (!await source.exists() || await source.length() == 0) {
      throw const FileSystemException('The captured damage photo is empty');
    }
    final directory = Directory(
      path.join(_supportDirectory.path, 'delivery_problem_drafts', stopId),
    );
    await directory.create(recursive: true);
    final extension = path.extension(capturedPath).toLowerCase() == '.png'
        ? '.png'
        : '.jpg';
    final retained = File(path.join(directory.path, 'damage$extension'));
    final temporary = File('${retained.path}.pending');
    if (await temporary.exists()) await temporary.delete();
    await source.copy(temporary.path);
    if (await retained.exists()) await retained.delete();
    await temporary.rename(retained.path);
    await _preferences.setString(_key(stopId), retained.path);
    return retained;
  }

  Future<void> clear(String stopId) async {
    final savedPath = _preferences.getString(_key(stopId));
    if (savedPath != null) {
      final file = File(savedPath);
      if (await file.exists()) await file.delete();
    }
    await Future.wait([
      _preferences.remove(_key(stopId)),
      _preferences.remove(_noteKey(stopId)),
    ]);
  }

  String _key(String stopId) => 'delivery_problem_photo_$stopId';
  String _noteKey(String stopId) => 'delivery_problem_note_$stopId';
}
