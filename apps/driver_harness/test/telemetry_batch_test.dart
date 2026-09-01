import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/telemetry/telemetry_batch.dart';

void main() {
  test('batch preserves contiguous sequence and production-shaped context', () {
    final batch = locationBatchFromRows([
      {
        'sequence': 41,
        'captured_at': '2026-09-01T10:00:00.000Z',
        'latitude': 13.73,
        'longitude': 100.56,
        'accuracy_meters': 8.0,
        'source': 'rounds_os',
        'heading_degrees': null,
        'speed_meters_per_second': 4.0,
      },
      {
        'sequence': 42,
        'captured_at': '2026-09-01T10:00:03.000Z',
        'latitude': 13.731,
        'longitude': 100.561,
        'accuracy_meters': 7.0,
        'source': 'rounds_os',
        'heading_degrees': 90.0,
        'speed_meters_per_second': 5.0,
      },
    ], traceId: 'trace-1');

    expect(batch['firstSequence'], 41);
    expect(batch['lastSequence'], 42);
    expect(batch['tenantId'], phaseZeroTenantId);
    expect(batch['driverId'], phaseZeroDriverId);
    expect((batch['samples'] as List).length, 2);
  });

  test('empty batch is rejected', () {
    expect(
      () => locationBatchFromRows(const [], traceId: 'trace-1'),
      throwsArgumentError,
    );
  });
}
