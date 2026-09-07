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

  test('rich media appears with truthful contact-history labels', () {
    final history = composeDriverContactHistory(
      messages: [
        DriverOperationsMessageModel(
          id: 'voice-message',
          sender: 'driver',
          body: '',
          attachments: const [
            DriverMessageAttachmentModel.media(
              kind: 'voice',
              fileName: 'Voice note.m4a',
              contentType: 'audio/mp4',
              byteSize: 4096,
              durationMilliseconds: 3500,
              mediaAssetId: 'asset-1',
            ),
          ],
          sentAt: DateTime.utc(2026, 9, 4, 3),
        ),
      ],
      contactAttempts: const [],
      threadUnavailable: false,
    );

    expect(history.events.single.title, 'Voice note shared');
    expect(history.events.single.detail, 'Voice note');
  });

  test('H03 preserves board semantics for system and attachment evidence', () {
    final history = composeDriverContactHistory(
      messages: [
        DriverOperationsMessageModel(
          id: 'pickup-system',
          sender: 'system',
          body: 'Pickup verified\n6 packages confirmed in driver custody',
          sentAt: DateTime.utc(2026, 9, 7, 5, 4),
        ),
        DriverOperationsMessageModel(
          id: 'driver-text',
          sender: 'driver',
          body: 'I’m at Gate B now.',
          sentAt: DateTime.utc(2026, 9, 7, 7, 19),
        ),
        DriverOperationsMessageModel(
          id: 'driver-location',
          sender: 'driver',
          body: '',
          attachments: [
            DriverMessageAttachmentModel.location(
              label: 'Gate B',
              latitude: 13.7306,
              longitude: 100.5697,
              capturedAt: DateTime.utc(2026, 9, 7, 7, 21),
            ),
          ],
          sentAt: DateTime.utc(2026, 9, 7, 7, 21),
        ),
      ],
      contactAttempts: const [],
      threadUnavailable: false,
    );

    expect(history.events[0].title, 'Pickup verified');
    expect(history.events[0].tone, DriverContactHistoryEventTone.green);
    expect(history.events[1].quoteDetail, isTrue);
    expect(history.events[2].title, 'Location shared');
    expect(history.events[2].quoteDetail, isFalse);
    expect(history.events[2].copyable, isTrue);
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

  testWidgets('H03 populated ledger visually matches the supplied board', (
    tester,
  ) async {
    final controller = await _pumpCanonicalHistory(tester);

    expect(find.text('STOP 1 OF 4'), findsOneWidget);
    expect(find.text('K. Nattaporn'), findsOneWidget);
    expect(find.text('Pickup verified'), findsOneWidget);
    expect(find.text('POD saved'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/h03-contact-history-english-393x852.png'),
    );

    controller.dispose();
  });

  testWidgets('H03 saved-history state visually matches the supplied board', (
    tester,
  ) async {
    final controller = await _pumpCanonicalHistory(tester, saved: true);

    expect(find.text('UrbanFlowers · saved'), findsOneWidget);
    expect(find.text('Offline · showing saved history'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/h03-contact-history-offline-english-393x852.png',
      ),
    );

    controller.dispose();
  });
}

Future<HarnessAppController> _pumpCanonicalHistory(
  WidgetTester tester, {
  bool saved = false,
}) async {
  tester.view.physicalSize = const Size(
    DriverReferenceViewport.width,
    DriverReferenceViewport.height,
  );
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 28);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  SharedPreferences.setMockInitialValues({});
  final controller = await HarnessAppController.create();
  final round = _canonicalHistoryRound();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildRoundsDriverTheme(),
      home: ContactHistoryScreen(
        controller: controller,
        round: round,
        stop: round.stops.first,
        historyLoader: () async => DriverContactHistoryModel(
          events: _canonicalHistoryEvents(saved: saved),
          savedHistory: saved,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

DriverRoundModel _canonicalHistoryRound() => DriverRoundModel(
  id: 'H03-ROUND',
  reference: 'H03-ROUND-001',
  serviceDate: '2026-09-07',
  state: 'active',
  version: 1,
  tenantName: 'UrbanFlowers',
  pickup: const DriverPickupModel(
    id: 'H03-PICKUP',
    displayName: 'UrbanFlowers',
    rawAddress: 'Sukhumvit 39, Bangkok',
    contactName: 'Operations',
    contactPhone: '+66000000000',
  ),
  stops: [
    _historyStop(
      id: 'H03-STOP-1',
      sequence: 1,
      recipient: 'K. Nattaporn',
      address: 'The Emporio Place · Sukhumvit 24',
    ),
    _historyStop(id: 'H03-STOP-2', sequence: 2),
    _historyStop(id: 'H03-STOP-3', sequence: 3),
    _historyStop(id: 'H03-STOP-4', sequence: 4),
  ],
);

DriverRoundStopModel _historyStop({
  required String id,
  required int sequence,
  String recipient = 'Recipient',
  String address = 'Bangkok',
}) => DriverRoundStopModel(
  id: id,
  sequence: sequence,
  state: 'assigned',
  version: 1,
  destinationVersion: 1,
  manifestId: 'H03-MANIFEST-$sequence',
  manifestVersion: 1,
  deliveryReference: 'UF-H03-00$sequence',
  recipientName: recipient,
  recipientPhone: '+66999999999',
  rawAddress: address,
  latitude: 13.7306,
  longitude: 100.5697,
  windowStart: '2026-09-07T07:00:00Z',
  windowEnd: '2026-09-07T09:00:00Z',
  manifestItems: const [
    DriverManifestItemModel(
      lineNumber: 1,
      description: 'Flower bouquet',
      quantity: 1,
    ),
  ],
);

List<DriverContactHistoryEventModel> _canonicalHistoryEvents({
  required bool saved,
}) {
  final now = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(now.year, now.month, now.day, hour, minute);
  DriverContactHistoryEventModel event({
    required String id,
    required DriverContactHistoryEventKind kind,
    required String title,
    required String detail,
    required int hour,
    required int minute,
    String? outcome,
    DriverContactHistoryEventTone? tone,
    bool quoteDetail = false,
    String? detailHighlight,
  }) => DriverContactHistoryEventModel(
    id: id,
    kind: kind,
    title: title,
    detail: detail,
    occurredAt: at(hour, minute),
    outcome: outcome,
    savedLocally: saved && id == 'message-driver',
    tone: tone,
    quoteDetail: quoteDetail,
    detailHighlight: detailHighlight,
  );

  return [
    event(
      id: 'pickup-verified',
      kind: DriverContactHistoryEventKind.system,
      title: 'Pickup verified',
      detail: '6 packages confirmed in driver custody',
      hour: 12,
      minute: 4,
      tone: DriverContactHistoryEventTone.green,
    ),
    event(
      id: 'entrance-updated',
      kind: DriverContactHistoryEventKind.system,
      title: 'Entrance updated',
      detail: 'Gate A → Gate B',
      hour: 13,
      minute: 58,
      tone: DriverContactHistoryEventTone.orange,
    ),
    event(
      id: 'update-acknowledged',
      kind: DriverContactHistoryEventKind.system,
      title: 'Update acknowledged',
      detail: 'Driver confirmed Gate B',
      hour: 13,
      minute: 59,
      tone: DriverContactHistoryEventTone.green,
    ),
    event(
      id: 'message-driver',
      kind: DriverContactHistoryEventKind.driverMessage,
      title: 'Message to Operations',
      detail: 'I’m at Gate B now. Security is checking.',
      hour: 14,
      minute: 19,
      tone: DriverContactHistoryEventTone.ink,
      quoteDetail: true,
    ),
    event(
      id: 'message-operations',
      kind: DriverContactHistoryEventKind.operationsMessage,
      title: 'Operations message',
      detail: 'They’ve confirmed you can leave it at reception.',
      hour: 14,
      minute: 20,
      tone: DriverContactHistoryEventTone.ink,
      quoteDetail: true,
    ),
    event(
      id: 'location-shared',
      kind: DriverContactHistoryEventKind.driverMessage,
      title: 'Location shared',
      detail: 'Gate B · Current location',
      hour: 14,
      minute: 21,
      tone: DriverContactHistoryEventTone.ink,
    ),
    event(
      id: 'recipient-call',
      kind: DriverContactHistoryEventKind.recipientCall,
      title: 'Recipient call',
      detail: 'No answer',
      hour: 14,
      minute: 24,
      outcome: 'no_answer',
      tone: DriverContactHistoryEventTone.red,
    ),
    event(
      id: 'handoff-approved',
      kind: DriverContactHistoryEventKind.system,
      title: 'Handoff approved',
      detail: 'Leave with reception · UrbanFlowers approved',
      hour: 14,
      minute: 26,
      tone: DriverContactHistoryEventTone.green,
      detailHighlight: 'UrbanFlowers approved',
    ),
    event(
      id: 'pod-saved',
      kind: DriverContactHistoryEventKind.system,
      title: 'POD saved',
      detail: 'Proof photo · reception handoff',
      hour: 14,
      minute: 31,
      tone: DriverContactHistoryEventTone.green,
    ),
  ];
}
