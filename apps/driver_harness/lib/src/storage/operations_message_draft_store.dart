import 'package:shared_preferences/shared_preferences.dart';

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

  String _key(String stopId) => 'operations_message_draft_v1_$stopId';
}
