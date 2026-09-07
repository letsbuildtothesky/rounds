import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/driver/driver_chat_media.dart';
import 'package:rounds_driver_harness/src/driver/driver_operations_thread.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/storage/operations_message_draft_store.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/operations_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('H01 restores its draft and uses canonical fixed geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final draftStore = OperationsMessageDraftStore(preferences: preferences);
    final round = AssignedRoundScreen.demoRound;
    final stop = round.stops.first;
    await draftStore.save(stop.id, 'Waiting at reception.');
    final controller = await HarnessAppController.create();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: OperationsChatScreen(
          controller: controller,
          round: round,
          stop: stop,
          draftStore: draftStore,
          threadLoader: () async => null,
          pendingMessagesLoader: () async => const [],
          refreshInterval: null,
          realtimeEnabled: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.getSize(find.byKey(const Key('h01-topbar'))).height, 64);
    expect(tester.getSize(find.byKey(const Key('h01-context'))).height, 58);
    expect(find.text('Waiting at reception.'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('View stop'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('H01 stages and persists a real structured location', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final draftStore = OperationsMessageDraftStore(preferences: preferences);
    final round = AssignedRoundScreen.demoRound;
    final controller = await HarnessAppController.create();
    await draftStore.saveLocation(
      round.stops.first.id,
      DriverMessageAttachmentModel.location(
        label: 'Current location',
        latitude: 13.7306,
        longitude: 100.5697,
        accuracyMeters: 8,
        capturedAt: DateTime.utc(2026, 9, 4, 3),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: OperationsChatScreen(
          controller: controller,
          round: round,
          stop: round.stops.first,
          draftStore: draftStore,
          threadLoader: () async => null,
          pendingMessagesLoader: () async => const [],
          refreshInterval: null,
          realtimeEnabled: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('h01-staged-location')), findsOneWidget);
    final restored = draftStore.restoreLocation(round.stops.first.id);
    expect(restored?.latitude, 13.7306);
    expect(restored?.longitude, 100.5697);

    controller.dispose();
  });

  testWidgets('H01 exposes the canonical attachment drawer and voice action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = await HarnessAppController.create();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: OperationsChatScreen(
          controller: controller,
          round: AssignedRoundScreen.demoRound,
          stop: AssignedRoundScreen.demoRound.stops.first,
          draftStore: OperationsMessageDraftStore(preferences: preferences),
          threadLoader: () async => null,
          pendingMessagesLoader: () async => const [],
          refreshInterval: null,
          realtimeEnabled: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('operations-chat-mic')), findsOneWidget);
    await tester.tap(find.byKey(const Key('h01-add-attachment')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('h01-add-camera')), findsOneWidget);
    expect(find.byKey(const Key('h01-add-photo')), findsOneWidget);
    expect(find.byKey(const Key('h01-add-file')), findsOneWidget);
    expect(find.byKey(const Key('h01-add-location')), findsOneWidget);

    controller.dispose();
  });

  testWidgets('H01 online thread visually matches the supplied English board', (
    tester,
  ) async {
    final controller = await _pumpCanonicalChat(tester);

    expect(find.text('STOP 1 OF 4'), findsOneWidget);
    expect(find.text('K. Nattaporn · The Emporio Place'), findsOneWidget);
    expect(find.text('Pickup verified'), findsOneWidget);
    expect(find.text('1 UNREAD'), findsOneWidget);
    expect(find.text('Current location'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/h01-operations-chat-english-393x852.png'),
    );

    controller.dispose();
  });

  testWidgets('H01 attachment drawer visually matches the supplied board', (
    tester,
  ) async {
    final controller = await _pumpCanonicalChat(tester);
    await tester.tap(find.byKey(const Key('h01-add-attachment')));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('h01-sheet-handle'))),
      const Size(42, 4),
    );
    expect(find.text('Add to message'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/h01-operations-chat-attachment-drawer-english-393x852.png',
      ),
    );

    controller.dispose();
  });

  testWidgets('H01 voice recording and preview match the supplied board', (
    tester,
  ) async {
    final mediaGateway = _RecordingMediaGateway();
    final controller = await _pumpCanonicalChat(
      tester,
      mediaGateway: mediaGateway,
    );
    await tester.tap(find.byKey(const Key('operations-chat-mic')));
    await tester.pumpAndSettle();

    expect(find.text('Recording'), findsOneWidget);
    expect(find.byKey(const Key('h01-voice-waveform')), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/h01-operations-chat-voice-recording-english-393x852.png',
      ),
    );

    await tester.tap(find.byKey(const Key('h01-stop-voice')));
    await tester.pumpAndSettle();
    expect(find.text('Preview before send'), findsOneWidget);
    expect(find.text('Add voice to message'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/h01-operations-chat-voice-preview-english-393x852.png',
      ),
    );

    controller.dispose();
  });
}

Future<HarnessAppController> _pumpCanonicalChat(
  WidgetTester tester, {
  DriverChatMediaGateway? mediaGateway,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = await HarnessAppController.create();
  final round = _canonicalRound();
  final thread = _canonicalThread(round);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildRoundsDriverTheme(),
      home: OperationsChatScreen(
        controller: controller,
        round: round,
        stop: round.stops.first,
        draftStore: OperationsMessageDraftStore(preferences: preferences),
        mediaGateway: mediaGateway,
        threadLoader: () async => thread,
        pendingMessagesLoader: () async => const [],
        readMarker: (_) async {},
        refreshInterval: null,
        realtimeEnabled: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

DriverRoundModel _canonicalRound() => DriverRoundModel(
  id: 'H01-ROUND',
  reference: 'H01-ROUND-001',
  serviceDate: '2026-09-04',
  state: 'active',
  version: 1,
  tenantName: 'UrbanFlowers',
  pickup: const DriverPickupModel(
    id: 'H01-PICKUP',
    displayName: 'UrbanFlowers',
    rawAddress: 'Sukhumvit 39, Bangkok',
    contactName: 'Operations',
    contactPhone: '+66000000000',
  ),
  stops: [
    _canonicalStop(
      id: 'H01-STOP-1',
      sequence: 1,
      recipient: 'K. Nattaporn',
      address: 'The Emporio Place',
    ),
    _canonicalStop(
      id: 'H01-STOP-2',
      sequence: 2,
      recipient: 'Stop 2',
      address: 'Bangkok',
    ),
    _canonicalStop(
      id: 'H01-STOP-3',
      sequence: 3,
      recipient: 'Stop 3',
      address: 'Bangkok',
    ),
    _canonicalStop(
      id: 'H01-STOP-4',
      sequence: 4,
      recipient: 'Stop 4',
      address: 'Bangkok',
    ),
  ],
);

DriverRoundStopModel _canonicalStop({
  required String id,
  required int sequence,
  required String recipient,
  required String address,
}) => DriverRoundStopModel(
  id: id,
  sequence: sequence,
  state: 'assigned',
  version: 1,
  destinationVersion: 1,
  manifestId: 'H01-MANIFEST-$sequence',
  manifestVersion: 1,
  deliveryReference: 'UF-H01-00$sequence',
  recipientName: recipient,
  recipientPhone: '+66999999999',
  rawAddress: address,
  latitude: 13.7306,
  longitude: 100.5697,
  windowStart: '2026-09-04T07:00:00Z',
  windowEnd: '2026-09-04T09:00:00Z',
  manifestItems: const [
    DriverManifestItemModel(
      lineNumber: 1,
      description: 'Flower bouquet',
      quantity: 1,
    ),
  ],
);

DriverOperationsThreadModel _canonicalThread(DriverRoundModel round) {
  final now = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(now.year, now.month, now.day, hour, minute);
  const unreadId = 'h01-message-6';
  return DriverOperationsThreadModel(
    id: 'H01-THREAD',
    roundId: round.id,
    stopId: round.stops.first.id,
    version: 1,
    unreadCount: 1,
    firstUnreadMessageId: unreadId,
    hasUnreadVoice: false,
    messages: [
      DriverOperationsMessageModel(
        id: 'h01-message-1',
        sender: 'system',
        body: 'Pickup verified\n6 packages confirmed in driver custody',
        sentAt: at(12, 4),
      ),
      DriverOperationsMessageModel(
        id: 'h01-message-2',
        sender: 'system',
        body: 'Entrance updated\nGate A → Gate B · acknowledged',
        sentAt: at(13, 58),
      ),
      DriverOperationsMessageModel(
        id: 'h01-message-3',
        sender: 'driver',
        body: 'I’m at Gate B now. Security is checking.',
        sentAt: at(14, 19),
      ),
      DriverOperationsMessageModel(
        id: 'h01-message-4',
        sender: 'operations',
        body: 'Great. They’ve confirmed you can leave it at reception.',
        sentAt: at(14, 20),
      ),
      DriverOperationsMessageModel(
        id: 'h01-message-5',
        sender: 'driver',
        body: 'I’m here now.',
        sentAt: at(14, 21),
        attachments: [
          DriverMessageAttachmentModel.location(
            label: 'Gate B',
            latitude: 13.7306,
            longitude: 100.5697,
            capturedAt: at(14, 21),
          ),
        ],
      ),
      DriverOperationsMessageModel(
        id: unreadId,
        sender: 'operations',
        body: 'Please take the proof photo before you complete the stop.',
        sentAt: at(14, 22),
      ),
    ],
  );
}

class _RecordingMediaGateway implements DriverChatMediaGateway {
  @override
  Future<void> startVoice() async {}

  @override
  Future<DriverMessageAttachmentModel?> stopVoice() async =>
      const DriverMessageAttachmentModel.media(
        kind: 'voice',
        fileName: 'Voice note.m4a',
        contentType: 'audio/mp4',
        byteSize: 1024,
        localPath: '/missing/voice-note.m4a',
        sha256: 'h01-voice',
        durationMilliseconds: 31000,
      );

  @override
  Future<void> cancelVoice() async {}

  @override
  Future<DriverMessageAttachmentModel?> captureCamera() async => null;

  @override
  Future<DriverMessageAttachmentModel?> pickPhoto() async => null;

  @override
  Future<DriverMessageAttachmentModel?> pickFile() async => null;

  @override
  Future<DriverMessageAttachmentModel> retain({
    required String kind,
    required String sourcePath,
    required String fileName,
    int? durationMilliseconds,
  }) => throw UnimplementedError();

  @override
  Future<void> dispose() async {}
}
