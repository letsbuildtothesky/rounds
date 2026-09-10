import 'dart:convert';

import 'generated/device_wire.g.dart';

/// Safe codes only: never include credentials, server bodies or native errors.
class DeviceEnrollmentException implements Exception {
  const DeviceEnrollmentException(this.code);
  final String code;
  @override
  String toString() => 'DeviceEnrollmentException($code)';
}

bool isDeviceUuid(Object? value) =>
    value is String &&
    value.length == 36 &&
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);

final _schemas = jsonDecode(deviceWireSchemaJson) as Map<String, dynamic>;

/// This validator is deliberately limited; the generator rejects unsupported
/// schema keywords instead of letting a future contract silently pass.
Map<String, dynamic> deviceWire(String name, Object? value) {
  const invalid = DeviceEnrollmentException('INVALID_RESPONSE');
  final schema = _schemas[name] as Map<String, dynamic>;
  final properties = schema['properties'] as Map<String, dynamic>;
  if (value is! Map<String, dynamic> ||
      value.length != properties.length ||
      !properties.keys.every(value.containsKey)) {
    throw invalid;
  }
  for (final entry in properties.entries) {
    final rule = entry.value as Map<String, dynamic>;
    final item = value[entry.key];
    if (rule.containsKey('const')) {
      if (item != rule['const']) throw invalid;
    } else if (rule['type'] == 'integer') {
      if (item is! int || item < rule['minimum'] || item > rule['maximum']) {
        throw invalid;
      }
    } else {
      if (item is! String ||
          (rule['maxLength'] != null && item.length > rule['maxLength']) ||
          (rule['enum'] != null && !(rule['enum'] as List).contains(item))) {
        throw invalid;
      }
      if (rule['pattern'] != null) {
        final match = RegExp(rule['pattern'] as String).firstMatch(item);
        if (match == null || match.start != 0 || match.end != item.length) {
          throw invalid;
        }
      }
      if (rule['format'] == 'uuid' && !isDeviceUuid(item)) throw invalid;
      if (rule['format'] == 'date-time' && !_dateTime(item)) {
        throw invalid;
      }
    }
  }
  return value;
}

/// Strict calendar/offset check shared with internal persisted capture times.
bool isDeviceInstant(Object? value) => value is String && _dateTime(value);

bool _dateTime(String value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?(Z|([+-])(\d{2}):(\d{2}))$',
  ).firstMatch(value);
  if (match == null || match.end != value.length) return false;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final calendar = DateTime.utc(year, month, day);
  return calendar.year == year &&
      calendar.month == month &&
      calendar.day == day &&
      int.parse(match[4]!) <= 23 &&
      int.parse(match[5]!) <= 59 &&
      int.parse(match[6]!) <= 59 &&
      (match[10] == null ||
          (int.parse(match[10]!) <= 23 && int.parse(match[11]!) <= 59)) &&
      DateTime.tryParse(value) != null;
}
