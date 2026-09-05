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
}
