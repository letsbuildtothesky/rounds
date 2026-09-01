import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/navigation/route_attempt_gate.dart';

void main() {
  test('a failed automatic attempt is never repeated by location updates', () {
    final gate = RouteAttemptGate();

    final first = gate.claimAutomatic();
    expect(first?.number, 1);
    gate.complete();

    expect(gate.claimAutomatic(), isNull);
    expect(gate.claimAutomatic(), isNull);

    final retry = gate.claimManual(RouteAttemptTrigger.manualTwoWheeler);
    expect(retry?.number, 2);
  });

  test('only one route request can be in flight', () {
    final gate = RouteAttemptGate();

    expect(gate.claimAutomatic(), isNotNull);
    expect(gate.claimManual(RouteAttemptTrigger.drivingDiagnostic), isNull);

    gate.complete();
    expect(gate.claimManual(RouteAttemptTrigger.drivingDiagnostic)?.number, 2);
  });

  test('reattached guidance suppresses a new automatic destination', () {
    final gate = RouteAttemptGate()..restoreActiveNavigation();

    expect(gate.claimAutomatic(), isNull);
    expect(gate.attemptCount, 0);
  });
}
