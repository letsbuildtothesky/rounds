import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/permissions/driver_permissions_screen.dart';
import 'package:rounds_driver_harness/src/permissions/location_access.dart';

void main() {
  testWidgets(
    'N01 follows canonical geometry and requests real location access',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final gateway = _FakeLocationGateway(
        state: DriverLocationAccessState.denied,
        requestedState: DriverLocationAccessState.whileInUse,
      );

      await tester.pumpWidget(
        MaterialApp(home: DriverPermissionsScreen(gateway: gateway)),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(const Key('n01-topbar'))).height, 58);
      expect(tester.getTopLeft(find.byKey(const Key('n01-main'))).dx, 0);
      expect(
        tester.getSize(find.byKey(const Key('n01-icon'))),
        const Size(72, 72),
      );
      expect(find.text('Allow location'), findsOneWidget);
      expect(find.text('Allow notifications'), findsNothing);
      expect(find.textContaining('Camera is requested only'), findsOneWidget);

      await tester.tap(find.byKey(const Key('n01-primary')));
      await tester.pumpAndSettle();

      expect(gateway.requestCalls, 1);
      expect(find.text('Done'), findsOneWidget);
      expect(
        find.textContaining('Route and arrival access is ready'),
        findsOneWidget,
      );
    },
  );

  testWidgets('N01 sends disabled services to device location settings', (
    tester,
  ) async {
    final gateway = _FakeLocationGateway(
      state: DriverLocationAccessState.serviceDisabled,
    );
    await tester.pumpWidget(
      MaterialApp(home: DriverPermissionsScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open location settings'), findsOneWidget);
    await tester.tap(find.byKey(const Key('n01-primary')));
    await tester.pumpAndSettle();

    expect(gateway.locationSettingsCalls, 1);
  });

  test(
    'operational access throws a typed permanently-blocked failure',
    () async {
      final gateway = _FakeLocationGateway(
        state: DriverLocationAccessState.deniedForever,
      );

      await expectLater(
        requireOperationalLocationAccess(gateway: gateway),
        throwsA(
          isA<DriverLocationAccessException>().having(
            (error) => error.state,
            'state',
            DriverLocationAccessState.deniedForever,
          ),
        ),
      );
      expect(gateway.requestCalls, 0);
    },
  );

  testWidgets('camera denial opens the contextual recovery drawer', (
    tester,
  ) async {
    expect(
      isCameraPermissionError(PlatformException(code: 'camera_access_denied')),
      isTrue,
    );
    expect(
      isCameraPermissionError(PlatformException(code: 'camera_unavailable')),
      isFalse,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCameraPermissionRecovery(context),
              child: const Text('Recover camera'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Recover camera'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('n01-camera-sheet')), findsOneWidget);
    expect(find.text('Open app settings'), findsOneWidget);
    expect(
      find.textContaining('No photo or delivery completion'),
      findsOneWidget,
    );

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('n01-camera-sheet')), findsNothing);
  });
}

class _FakeLocationGateway implements DriverLocationAccessGateway {
  _FakeLocationGateway({required this.state, this.requestedState});

  DriverLocationAccessState state;
  final DriverLocationAccessState? requestedState;
  int requestCalls = 0;
  int appSettingsCalls = 0;
  int locationSettingsCalls = 0;

  @override
  Future<DriverLocationAccessSnapshot> inspect() async =>
      DriverLocationAccessSnapshot(state);

  @override
  Future<DriverLocationAccessSnapshot> request() async {
    requestCalls += 1;
    state = requestedState ?? state;
    return DriverLocationAccessSnapshot(state);
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsCalls += 1;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsCalls += 1;
    return true;
  }
}
