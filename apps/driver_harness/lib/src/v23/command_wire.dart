import 'dart:convert';

import 'device_wire.dart';
import 'generated/command_wire.g.dart';

final _schemas = jsonDecode(commandWireSchemaJson) as Map<String, dynamic>;
const nativeExecutionCommands = {
  'ConfirmArrival',
  'ConfirmPickup',
  'RecordHandoff',
  'ReserveAsset',
  'VerifyAsset',
  'SubmitProof',
  'CompleteDelivery',
  'ReportIssue',
};
const _invalid = DeviceEnrollmentException('INVALID_COMMAND_WIRE');

/// Exact generated finite schemas, never coercion/defaults or receipt authority.
void validateCommandWire(String name, Object? value) {
  if (!_schemas.containsKey(name)) throw _invalid;
  if (utf8.encode(canonicalNativeCommand(value)).length > 1024 * 1024) {
    throw _invalid;
  }
  _validate(_schemas[name], value, 0);
}

void _validate(Map<String, dynamic> s, Object? v, int depth) {
  if (depth > 24) throw _invalid;
  if (s['type'] is List) {
    final types = s['type'] as List;
    if (v == null && types.contains('null')) return;
    if (types.length != 2 || !types.contains('null')) throw _invalid;
    _validate(
      {...s, 'type': types.firstWhere((t) => t != 'null')},
      v,
      depth + 1,
    );
    return;
  }
  if (s.containsKey(r'$ref')) {
    _validate(_schemas[(s[r'$ref'] as String).split('/').last], v, depth + 1);
  }
  if (s.containsKey('const') && v != s['const']) throw _invalid;
  if (s.containsKey('enum') && !(s['enum'] as List).contains(v)) throw _invalid;
  if (s.containsKey('anyOf')) {
    var matches = false;
    for (final branch in s['anyOf'] as List) {
      try {
        _validate(branch, v, depth + 1);
        matches = true;
      } on DeviceEnrollmentException {
        /* Try the other explicit branch. */
      }
    }
    if (!matches) throw _invalid;
  }
  switch (s['type']) {
    case 'object':
      final props = s['properties'] as Map;
      if (v is! Map<String, dynamic> ||
          !(s['required'] as List).every(v.containsKey) ||
          v.keys.any((k) => !props.containsKey(k))) {
        throw _invalid;
      }
      for (final e in v.entries) {
        _validate(props[e.key], e.value, depth + 1);
      }
    case 'array':
      if (v is! List ||
          v.length < (s['minItems'] as int? ?? 0) ||
          v.length > (s['maxItems'] as int? ?? 1000)) {
        throw _invalid;
      }
      for (final item in v) {
        _validate(s['items'], item, depth + 1);
      }
    case 'integer':
    case 'number':
      if (v is! num ||
          !v.isFinite ||
          v.abs() > 9007199254740991 ||
          (s['type'] == 'integer' && v != v.truncateToDouble()) ||
          (s['minimum'] != null && v < s['minimum']) ||
          (s['maximum'] != null && v > s['maximum']) ||
          (s['exclusiveMinimum'] != null && v <= s['exclusiveMinimum']) ||
          (s['multipleOf'] != null && (v * 10000).round() / 10000 != v)) {
        throw _invalid;
      }
    case 'string':
      if (v is! String ||
          v.runes.length < (s['minLength'] as int? ?? 0) ||
          v.runes.length > (s['maxLength'] as int? ?? 1048576)) {
        throw _invalid;
      }
      if (s['format'] == 'uuid' && (!isDeviceUuid(v) || v != v.toLowerCase())) {
        throw _invalid;
      }
      if (s['format'] == 'date-time' && !isDeviceInstant(v)) throw _invalid;
      if (s['pattern'] != null && !RegExp(s['pattern'] as String).hasMatch(v)) {
        throw _invalid;
      }
    case 'boolean':
      if (v is! bool) throw _invalid;
    case 'null':
      if (v != null) throw _invalid;
  }
}

/// ADR-T02 sorted UTF-16 keys and ECMAScript number thresholds. The finite
/// native contract rejects non-finite/unsafe-magnitude numbers and surrogates.
/// Frozen bytes, not a second jsonEncode, are used for every transport retry.
String canonicalNativeCommand(Object? value) {
  var nodes = 0;
  String encode(Object? v, int depth) {
    if (++nodes > 50000 || depth > 24) throw _invalid;
    if (v == null || v is bool) return '$v';
    if (v is String) {
      if (v.runes.any((r) => r >= 0xd800 && r <= 0xdfff)) throw _invalid;
      return jsonEncode(v);
    }
    if (v is num) {
      if (!v.isFinite || v.abs() > 9007199254740991) throw _invalid;
      if (v == 0) return '0';
      if (v == v.truncateToDouble()) return v.toInt().toString();
      var text = v.toString();
      if (text.contains('e')) {
        final parts = text.split('e');
        final exponent = int.parse(parts[1]);
        var mantissa = parts[0];
        if (mantissa.endsWith('.0')) {
          mantissa = mantissa.substring(0, mantissa.length - 2);
        }
        if (exponent >= -6) {
          final sign = mantissa.startsWith('-') ? '-' : '';
          final digits = mantissa.replaceAll('-', '').replaceAll('.', '');
          final point = 1 + exponent;
          return point <= 0
              ? '${sign}0.${'0' * -point}$digits'
              : '$sign${digits.substring(0, point)}.${digits.substring(point)}';
        }
        text = '${mantissa}e$exponent';
      }
      return text;
    }
    if (v is List) return '[${v.map((e) => encode(e, depth + 1)).join(',')}]';
    if (v is Map<String, dynamic>) {
      final keys = v.keys.toList()..sort();
      return '{${keys.map((k) => '${encode(k, depth + 1)}:${encode(v[k], depth + 1)}').join(',')}}';
    }
    throw _invalid;
  }

  return encode(value, 0);
}
