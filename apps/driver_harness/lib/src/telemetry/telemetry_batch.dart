const phaseZeroTenantId = '00000000-0000-4000-8000-000000000001';
const phaseZeroDriverId = '00000000-0000-4000-8000-000000000002';
const phaseZeroDeviceId = '00000000-0000-4000-8000-000000000003';
const phaseZeroRoundId = '00000000-0000-4000-8000-000000000004';
const phaseZeroStopId = '00000000-0000-4000-8000-000000000005';
const phaseZeroTelemetrySessionId = '00000000-0000-4000-8000-000000000006';

Map<String, Object?> locationBatchFromRows(
  List<Map<String, Object?>> rows, {
  required String traceId,
}) {
  if (rows.isEmpty) {
    throw ArgumentError.value(rows, 'rows', 'must not be empty');
  }

  Map<String, Object?> sample(Map<String, Object?> row) {
    final value = <String, Object?>{
      'sequence': row['sequence'],
      'capturedAt': row['captured_at'],
      'latitude': row['latitude'],
      'longitude': row['longitude'],
      'accuracyMeters': row['accuracy_meters'],
      'source': row['source'],
    };
    if (row['heading_degrees'] != null) {
      value['headingDegrees'] = row['heading_degrees'];
    }
    if (row['speed_meters_per_second'] != null) {
      value['speedMetersPerSecond'] = row['speed_meters_per_second'];
    }
    return value;
  }

  return {
    'schemaVersion': 1,
    'traceId': traceId,
    'tenantId': phaseZeroTenantId,
    'driverId': phaseZeroDriverId,
    'deviceId': phaseZeroDeviceId,
    'sessionId': phaseZeroTelemetrySessionId,
    'roundId': phaseZeroRoundId,
    'stopId': phaseZeroStopId,
    'firstSequence': rows.first['sequence'],
    'lastSequence': rows.last['sequence'],
    'samples': rows.map(sample).toList(growable: false),
  };
}
