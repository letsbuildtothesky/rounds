import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/driver/driver_operations_thread.dart';
import 'package:rounds_driver_harness/src/ui/operations_chat_screen.dart';

void main() {
  test('Driver thread parses its durable unread boundary', () {
    final thread = DriverOperationsThreadModel.fromJson({
      'id': '10000000-0000-4000-8000-000000000010',
      'roundId': '10000000-0000-4000-8000-000000000020',
      'stopId': '10000000-0000-4000-8000-000000000030',
      'version': 2,
      'unreadCount': 1,
      'firstUnreadMessageId': '10000000-0000-4000-8000-000000000040',
      'hasUnreadVoice': true,
      'messages': <Object?>[],
    });
    expect(thread.unreadCount, 1);
    expect(thread.firstUnreadMessageId, '10000000-0000-4000-8000-000000000040');
    expect(thread.hasUnreadVoice, isTrue);
  });

  testWidgets('H01 unread divider preserves the canonical board copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: const Scaffold(body: DriverChatUnreadDivider(count: 1)),
      ),
    );
    expect(find.byKey(const Key('h01-unread-divider')), findsOneWidget);
    expect(find.text('1 UNREAD'), findsOneWidget);
  });

  testWidgets('H01 media uses the canonical photo and voice geometry', (
    tester,
  ) async {
    const photo = DriverMessageAttachmentModel.media(
      kind: 'image',
      fileName: 'delivery.jpg',
      contentType: 'image/jpeg',
      byteSize: 1024,
      localPath: '/missing/test-photo.jpg',
      sha256: 'photo-sha',
    );
    const voice = DriverMessageAttachmentModel.media(
      kind: 'voice',
      fileName: 'voice.m4a',
      contentType: 'audio/mp4',
      byteSize: 2048,
      durationMilliseconds: 30500,
      sha256: 'voice-sha',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DriverChatMediaAttachmentCard(attachment: photo, mine: false),
                  DriverChatMediaAttachmentCard(attachment: voice, mine: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('h01-photo-preview'))).height,
      118,
    );
    expect(
      tester.getSize(find.byKey(const Key('h01-voice-play'))),
      const Size(34, 34),
    );
    expect(find.byKey(const Key('h01-voice-wave')), findsOneWidget);
    expect(find.text('0:31'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
  });
}
