import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'harness_database.dart';

class HarnessEventLog {
  HarnessEventLog(this.database, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final HarnessDatabase database;
  final Uuid _uuid;

  Future<void> record(
    String eventType, {
    Map<String, Object?> payload = const {},
  }) => database.database.insert('harness_events', {
    'event_type': eventType,
    'occurred_at': DateTime.now().toUtc().toIso8601String(),
    'trace_id': _uuid.v4(),
    'payload_json': jsonEncode(payload),
  });
}
