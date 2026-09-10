import 'dart:convert';

import 'device_wire.dart';
import 'encrypted_work_store.dart';
import 'generated/execution_wire.g.dart';

final _schemas = jsonDecode(executionWireSchemaJson) as Map<String, dynamic>;
const _invalid = DeviceEnrollmentException('INVALID_RESPONSE');

/// Exact generated finite query shape plus cross-object identity checks. This
/// parser isn't authentication: only the registration transport supplies it to
/// a current account lease. Snapshots never expose transport secrets.
class DriverExecutionSnapshot {
  DriverExecutionSnapshot._(this._json, this.context);
  factory DriverExecutionSnapshot.parse(Map<String, dynamic> value) {
    final json = jsonEncode(value);
    if (utf8.encode(json).length > 65536) throw _invalid;
    _validate(_schemas['DriverRoundExecutionQueryResult'], value, 0);
    final data = value['data'] as Map<String, dynamic>;
    final wire = data['context'] as Map<String, dynamic>;
    if (wire['fetched_at'] != value['as_of']) throw _invalid;
    final orders = (data['orders'] as List).cast<Map<String, dynamic>>();
    final scopes = (wire['stop_units'] as List).cast<Map<String, dynamic>>();
    final policies = (wire['proof_policies'] as List)
        .cast<Map<String, dynamic>>();
    final units = orders.map((o) => o['fulfillment_unit_id']).toSet();
    if (units.length != orders.length ||
        orders.map((o) => o['delivery_id']).toSet().length != orders.length ||
        orders.map((o) => o['manifest_id']).toSet().length != orders.length ||
        scopes.map((s) => s['stop_id']).toSet().length != scopes.length ||
        scopes.length != orders.length + 1 ||
        policies.length != orders.length ||
        policies.map((p) => p['fulfillment_unit_id']).toSet().length !=
            policies.length ||
        policies.any((p) => !units.contains(p['fulfillment_unit_id']))) {
      throw _invalid;
    }
    final stopUnits = <String, Object?>{};
    for (final s in scopes) {
      final ids = s['fulfillment_unit_ids'] as List;
      if (ids.toSet().length != ids.length ||
          ids.any((id) => !units.contains(id))) {
        throw _invalid;
      }
      stopUnits[s['stop_id'] as String] = ids;
    }
    final pickup = stopUnits[data['pickup_stop_id']] as List?;
    if (pickup == null || pickup.length != units.length) throw _invalid;
    final roots = <String>{
      'assignments:${wire['assignment_id']}',
      'rounds:${wire['round_id']}',
    };
    for (final s in scopes) {
      roots.add('stops:${s['stop_id']}');
    }
    for (final o in orders) {
      final ids = stopUnits[o['dropoff_stop_id']] as List?;
      if (o['dropoff_stop_id'] == data['pickup_stop_id'] ||
          ids == null ||
          ids.length != 1 ||
          ids.single != o['fulfillment_unit_id']) {
        throw _invalid;
      }
      final lines = o['quantities'] as List;
      if (lines.map((q) => q['line_id']).toSet().length != lines.length) {
        throw _invalid;
      }
      roots.add('manifests:${o['manifest_id']}');
      roots.add('fulfillment_units:${o['fulfillment_unit_id']}');
    }
    final versions = wire['expected_versions'] as List;
    // Old encrypted snapshots have no delivery roots. Keep them readable,
    // but never invent/backfill versions for new issue observations. A new
    // response must contain ALL selected deliveries or none, never a subset.
    if (versions.any((v) => v['aggregate_type'] == 'deliveries')) {
      roots.addAll(orders.map((o) => 'deliveries:${o['delivery_id']}'));
    }
    if (versions.length != roots.length ||
        versions
                .map((v) => '${v['aggregate_type']}:${v['id']}')
                .toSet()
                .length !=
            roots.length ||
        versions.any(
          (v) => !roots.contains('${v['aggregate_type']}:${v['id']}'),
        )) {
      throw _invalid;
    }
    final context = ExecutionCaptureContext.fromJson(
      {
        ...wire,
        'stop_units': stopUnits,
        'proof_policy': {
          for (final p in policies)
            p['fulfillment_unit_id'] as String: {
              'policy_version_id': p['policy_version_id'],
              'policy': p['policy'],
            },
        },
      }..remove('proof_policies'),
    );
    return DriverExecutionSnapshot._(json, context);
  }
  final String _json;
  final ExecutionCaptureContext context;
  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  @override
  String toString() => 'DriverExecutionSnapshot(redacted)';
}

/// Current display metadata plus an independently validated execution snapshot.
/// Parsing is not authorization. Only the registered, current account lease may
/// expose this data to the screen. No package IDs are inferred from quantities.
class DriverPickupSnapshot {
  DriverPickupSnapshot._(this._json, this.execution);

  factory DriverPickupSnapshot.parse(Map<String, dynamic> value) {
    final json = jsonEncode(value);
    if (utf8.encode(json).length > 65536) throw _invalid;
    _validate(_schemas['DriverRoundPickupQueryResult'], value, 0);
    final data = value['data'] as Map<String, dynamic>;
    final execution = DriverExecutionSnapshot.parse({
      'as_of': value['as_of'],
      'next_cursor': null,
      'data': data['execution'],
    });
    final original = (execution.toJson()['data']['orders'] as List)
        .cast<Map<String, dynamic>>();
    final display = (data['orders'] as List).cast<Map<String, dynamic>>();
    final deliveries = <String>{}, parcels = <String>{}, sequences = <int>{};
    if (display.length != original.length) throw _invalid;
    for (final name in [data['merchant'], data['pickup_site_name']]) {
      if ((name as String).trim().isEmpty) throw _invalid;
    }
    var previousSequence = 0;
    for (final order in display) {
      final id = order['delivery_id'] as String;
      if (!deliveries.add(id)) throw _invalid;
      final base = original.where((o) => o['delivery_id'] == id).singleOrNull;
      final sequence = order['stop_sequence'] as int;
      if (base == null ||
          base['manifest_id'] != order['manifest_id'] ||
          !sequences.add(sequence) ||
          sequence <= previousSequence) {
        throw _invalid;
      }
      previousSequence = sequence;
      for (final name in [order['reference'], order['recipient_name']]) {
        if ((name as String).trim().isEmpty) throw _invalid;
      }
      final expected = {
        for (final q in base['quantities'] as List)
          q['line_id'] as String: _quanta(q['quantity']),
      };
      final lines = <String>{};
      for (final line in order['lines'] as List) {
        if (!lines.add(line['line_id'] as String) ||
            expected[line['line_id']] != _quanta(line['quantity']) ||
            (line['label'] as String).trim().isEmpty ||
            (line['unit'] as String).trim().isEmpty ||
            (line['handling_keys'] as List).any(
              (k) => (k as String).trim().isEmpty,
            )) {
          throw _invalid;
        }
      }
      if (lines.length != expected.length) throw _invalid;
      final totals = <String, int>{};
      for (final p in order['packages'] as List) {
        if (!parcels.add(p['package_id'] as String) ||
            (p['label'] as String).trim().isEmpty) {
          throw _invalid;
        }
        final seen = <String>{};
        for (final c in p['contents'] as List) {
          final line = c['line_id'] as String;
          if (!expected.containsKey(line) || !seen.add(line)) throw _invalid;
          totals[line] = (totals[line] ?? 0) + _quanta(c['quantity']);
        }
        if (seen.isEmpty) throw _invalid;
      }
      if ((order['packages'] as List).isNotEmpty &&
          expected.entries.any((e) => totals[e.key] != e.value)) {
        throw _invalid;
      }
    }
    return DriverPickupSnapshot._(json, execution);
  }

  final String _json;
  final DriverExecutionSnapshot execution;
  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  @override
  String toString() => 'DriverPickupSnapshot(redacted)';
}

/// Current server facts/instructions only. There is deliberately no
/// canContinue/ready/complete action derived from this response.
class DriverPickupIssueSnapshot {
  DriverPickupIssueSnapshot._(this._json);
  factory DriverPickupIssueSnapshot.parse(Map<String, dynamic> value) {
    final json = jsonEncode(value);
    if (utf8.encode(json).length > 65536) throw _invalid;
    _validate(_schemas['DriverPickupIssueQueryResult'], value, 0);
    final d = value['data'] as Map<String, dynamic>;
    final decisions = d['decisions'] as List;
    if (['decided', 'resolved'].contains(d['state']) != decisions.isNotEmpty ||
        d['assignment_version'] > 9007199254740991 ||
        d['issue_version'] > 9007199254740991 ||
        decisions.any((v) => (v['instructions'] as String).trim().isEmpty)) {
      throw _invalid;
    }
    return DriverPickupIssueSnapshot._(json);
  }
  final String _json;
  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  void requireOriginalReport(ReportedPickupIssue report) {
    final d = toJson()['data'] as Map<String, dynamic>,
        original = report.toJson();
    for (final key in [
      'principal_id',
      'tenant_id',
      'city_id',
      'round_id',
      'assignment_id',
      'assignment_version',
      'observation_id',
      'issue_id',
    ]) {
      if (d[key] != original[key]) throw _invalid;
    }
    final orders = d['orders'] as List;
    if (original['delivery_id'] == null
        ? orders.isNotEmpty
        : orders.length != 1 ||
              orders.single['delivery_id'] != original['delivery_id']) {
      throw _invalid;
    }
  }

  @override
  String toString() => 'DriverPickupIssueSnapshot(redacted)';
}

int _quanta(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value <= 0 ||
      value > 1000000 ||
      (value * 10000).round() / 10000 != value) {
    throw _invalid;
  }
  return (value * 10000).round();
}

/// Fresh display and FIRST persisted authority are deliberately separate.
typedef AuthorizedPickup = ({
  DriverPickupSnapshot snapshot,
  ExecutionCaptureContext originalContext,
});

void _validate(Map<String, dynamic> rule, Object? value, int depth) {
  if (depth > 20) throw _invalid;
  if (rule.containsKey(r'$ref')) {
    _validate(
      _schemas[(rule[r'$ref'] as String).split('/').last],
      value,
      depth + 1,
    );
  }
  if (rule.containsKey('const') && value != rule['const']) throw _invalid;
  if (rule.containsKey('enum') && !(rule['enum'] as List).contains(value)) {
    throw _invalid;
  }
  switch (rule['type']) {
    case 'object':
      final props = rule['properties'] as Map<String, dynamic>;
      if (value is! Map<String, dynamic> ||
          value.length != props.length ||
          !props.keys.every(value.containsKey)) {
        throw _invalid;
      }
      for (final p in props.entries) {
        _validate(p.value, value[p.key], depth + 1);
      }
    case 'array':
      if (value is! List ||
          value.length < (rule['minItems'] as int? ?? 0) ||
          value.length > (rule['maxItems'] as int? ?? 1000)) {
        throw _invalid;
      }
      for (final item in value) {
        _validate(rule['items'], item, depth + 1);
      }
    case 'integer':
    case 'number':
      if (value is! num ||
          !value.isFinite ||
          (rule['type'] == 'integer' && value is! int) ||
          (rule['minimum'] != null && value < (rule['minimum'] as num)) ||
          (rule['maximum'] != null && value > (rule['maximum'] as num)) ||
          (rule['exclusiveMinimum'] != null &&
              value <= (rule['exclusiveMinimum'] as num)) ||
          (rule['multipleOf'] != null &&
              (value * 10000).round() / 10000 != value)) {
        throw _invalid;
      }
    case 'string':
      if (value is! String) throw _invalid;
      if (rule['format'] == 'uuid' &&
          (!isDeviceUuid(value) || value != value.toLowerCase())) {
        throw _invalid;
      }
      if (rule['format'] == 'date-time' && !isDeviceInstant(value)) {
        throw _invalid;
      }
      if (rule['pattern'] != null) {
        final match = RegExp(
          rule['pattern'] as String,
          unicode: true,
        ).firstMatch(value);
        if (match == null || match.start != 0 || match.end != value.length) {
          throw _invalid;
        }
      }
    case 'boolean':
      if (value is! bool) throw _invalid;
    case 'null':
      if (value != null) throw _invalid;
  }
}
