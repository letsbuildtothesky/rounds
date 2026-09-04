import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../driver/driver_operations_thread.dart';

class OperationsMessageDraftStore {
  OperationsMessageDraftStore({required SharedPreferences preferences})
    : _preferences = preferences;

  final SharedPreferences _preferences;

  static Future<OperationsMessageDraftStore> create() async =>
      OperationsMessageDraftStore(
        preferences: await SharedPreferences.getInstance(),
      );

  String? restore(String stopId) {
    final value = _preferences.getString(_key(stopId));
    return value == null || value.trim().isEmpty ? null : value;
  }

  Future<void> save(String stopId, String body) async {
    if (body.trim().isEmpty) {
      await clear(stopId);
      return;
    }
    await _preferences.setString(_key(stopId), body);
  }

  Future<void> clear(String stopId) => _preferences.remove(_key(stopId));

  DriverMessageAttachmentModel? restoreLocation(String stopId) {
    final value = _preferences.getString(_locationKey(stopId));
    if (value == null) return null;
    try {
      return DriverMessageAttachmentModel.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }

  Future<void> saveLocation(
    String stopId,
    DriverMessageAttachmentModel attachment,
  ) => _preferences.setString(
    _locationKey(stopId),
    jsonEncode(attachment.toJson()),
  );

  Future<void> clearLocation(String stopId) =>
      _preferences.remove(_locationKey(stopId));

  String _key(String stopId) => 'operations_message_draft_v1_$stopId';
  String _locationKey(String stopId) =>
      'operations_message_location_draft_v1_$stopId';
}
