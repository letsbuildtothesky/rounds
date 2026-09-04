import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/driver/driver_contact_history.dart';
import 'package:rounds_driver_harness/src/driver/driver_operations_thread.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/contact_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('real messages and typed calls compose one chronological ledger', () {
    final history = composeDriverContactHistory(
      messages: [
        DriverOperationsMessageModel(
          id: 'message-1',
          sender: 'driver',
          body: 'I am at the entrance.',
          sentAt: DateTime.utc(2026, 9, 3, 7, 10),
        ),
        DriverOperationsMessageModel(
          id: 'call-system',
          sender: 'system',
          body: 'Recipient call · No answer',
          sentAt: DateTime.utc(2026, 9, 3, 7, 12),
        ),
        DriverOperationsMessageModel(
          id: 'message-2',
          sender: 'operations',
          body: 'Please try once more.',
          sentAt: DateTime.utc(2026, 9, 3, 7, 13),
        ),
        DriverOperationsMessageModel(
          id: 'system-1',
          sender: 'system',
          body: 'Location problem reported · Entrance access wrong',
          sentAt: DateTime.utc(2026, 9, 3, 7, 14),
        ),
      ],
      contactAttempts: [
        DriverContactAttemptModel(
          id: 'call-1',
          target: 'recipient',
          channel: 'native_phone',
          outcome: 'no_answer',
          occurredAt: DateTime.utc(2026, 9, 3, 7, 11),
        ),
      ],
      threadUnavailable: false,
    );

    expect(history.events, hasLength(4));
    expect(history.events.map((event) => event.title), [
      'Message to Operations',
      'Recipient call',
      'Operations message',
      'Location problem reported',
    ]);
    expect(history.events[1].detail, 'No answer');
    expect(history.events[3].detail, 'Entrance access wrong');
    expect(history.savedHistory, isFalse);
  });

  test('pending evidence is labelled as saved history', () {
    final history = composeDriverContactHistory(
      messages: [
        DriverOperationsMessageModel(
          id: 'pending-message',
          sender: 'driver',
          body: 'Saved while offline',
          sentAt: DateTime.utc(2026, 9, 3, 7, 10),
          savedLocally: true,
        ),
      ],
      contactAttempts: const [],
      threadUnavailable: true,
    );

    expect(history.savedHistory, isTrue);
    expect(history.events.single.savedLocally, isTrue);
  });

  test('structured location appears as durable contact evidence', () {
    final history = composeDriverContactHistory(
      messages: [
        DriverOperationsMessageModel(
          id: 'location-message',
          sender: 'driver',
          body: '',
          attachments: [
            DriverMessageAttachmentModel.location(
              label: 'Current location',
              latitude: 13.7306,
              longitude: 100.5697,
              capturedAt: DateTime.utc(2026, 9, 4, 3),
            ),
          ],
          sentAt: DateTime.utc(2026, 9, 4, 3),
        ),
      ],
      contactAttempts: const [],
      threadUnavailable: false,
    );

    expect(history.events.single.title, 'Location shared');
    expect(history.events.single.detail, contains('13.730600, 100.569700'));
  });

  testWidgets('H03 uses canonical regions and only renders real evidence', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await HarnessAppController.create();
    final now = DateTime.now().toUtc();
    final base = AssignedRoundScreen.demoRound;
    final baseStop = base.stops.first;
    final stop = DriverRoundStopModel(
      id: baseStop.id,
      sequence: baseStop.sequence,
      state: baseStop.state,
      version: baseStop.version,
      destinationVersion: baseStop.destinationVersion,
      manifestId: baseStop.manifestId,
      manifestVersion: baseStop.manifestVersion,
      deliveryReference: baseStop.deliveryReference,
      recipientName: baseStop.recipientName,
      recipientPhone: baseStop.recipientPhone,
      rawAddress: baseStop.rawAddress,
      latitude: baseStop.latitude,
      longitude: baseStop.longitude,
      windowStart: baseStop.windowStart,
      windowEnd: baseStop.windowEnd,
      manifestItems: baseStop.manifestItems,
      contactAttempts: [
        DriverContactAttemptModel(
          id: 'attempt-real',
          target: 'recipient',
          channel: 'native_phone',
          outcome: 'no_answer',
          occurredAt: now,
        ),
      ],
    );
    final round = DriverRoundModel(
      id: base.id,
      reference: base.reference,
      serviceDate: base.serviceDate,
      state: base.state,
      version: base.version,
      tenantName: base.tenantName,
      pickup: base.pickup,
      stops: [stop],
    );
    tester.view.physicalSize = const Size(
      DriverReferenceViewport.width,
      DriverReferenceViewport.height,
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: ContactHistoryScreen(
          controller: controller,
          round: round,
          stop: stop,
          historyLoader: () async => composeDriverContactHistory(
            messages: const [],
            contactAttempts: stop.contactAttempts,
            threadUnavailable: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final topbar = tester.getRect(
      find.byKey(const Key('contact-history-topbar')),
    );
    final context = tester.getRect(
      find.byKey(const Key('contact-history-context')),
    );
    final footer = tester.getRect(
      find.byKey(const Key('contact-history-footer')),
    );
    expect(topbar.top, 0);
    expect(topbar.height, DriverH03Metrics.topBarHeight);
    expect(context.top, DriverH03Metrics.topBarHeight);
    expect(context.height, DriverH03Metrics.contextHeight);
    expect(footer.bottom, DriverReferenceViewport.height);
    expect(
      footer.height,
      DriverH03Metrics.footerPaddingTop +
          DriverH03Metrics.primaryHeight +
          DriverH03Metrics.footerPaddingBottom +
          1,
    );
    expect(find.text('Recipient call'), findsOneWidget);
    expect(find.text('No answer'), findsOneWidget);
    expect(find.text('Offline · showing saved history'), findsOneWidget);
    expect(find.text('Pickup verified'), findsNothing);
    expect(find.textContaining('approved'), findsNothing);
  });
}
