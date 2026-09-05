import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/driver/driver_operations_realtime.dart';

void main() {
  const driverId = '00000000-0000-4000-8000-000000000010';

  test('uses the Supabase WebSocket endpoint', () {
    expect(
      driverRealtimeEndpoint('https://project.supabase.co'),
      'wss://project.supabase.co/realtime/v1',
    );
  });

  test('uses the private driver-scoped communications topic', () {
    expect(driverCommunicationsTopic(driverId), 'driver:$driverId');
  });

  test('accepts a versioned same-driver communications hint', () {
    expect(
      isDriverCommunicationsHint({
        'event': driverCommunicationsEvent,
        'payload': {
          'schemaVersion': 1,
          'event': driverCommunicationsEvent,
          'driverId': driverId,
          'aggregateType': 'operations_thread',
          'aggregateId': '00000000-0000-4000-8000-000000000020',
          'aggregateVersion': 4,
          'occurredAt': '2026-09-05T05:00:00Z',
        },
      }, driverId),
      isTrue,
    );
  });

  test('rejects another driver and malformed hints', () {
    final hint = {
      'event': driverCommunicationsEvent,
      'payload': {
        'schemaVersion': 1,
        'event': driverCommunicationsEvent,
        'driverId': driverId,
        'aggregateType': 'operations_thread',
        'aggregateId': '00000000-0000-4000-8000-000000000020',
        'aggregateVersion': 4,
        'occurredAt': '2026-09-05T05:00:00Z',
      },
    };

    expect(
      isDriverCommunicationsHint(hint, '10000000-0000-4000-8000-000000000010'),
      isFalse,
    );
    expect(
      isDriverCommunicationsHint({
        ...hint,
        'payload': {...hint['payload']! as Map, 'aggregateVersion': '4'},
      }, driverId),
      isFalse,
    );
    expect(
      isDriverCommunicationsHint({...hint, 'event': 'message.body'}, driverId),
      isFalse,
    );
  });
}
