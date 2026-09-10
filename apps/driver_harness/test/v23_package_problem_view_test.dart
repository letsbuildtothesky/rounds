import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/ui/components/package_problem_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final sdk = Platform.environment['ROUNDS_TEST_FLUTTER_SDK'];
    if (sdk != null) {
      final font = FontLoader('Roboto');
      font.addFont(
        File(
          '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        ).readAsBytes().then((v) => ByteData.sublistView(v)),
      );
      await font.load();
    }
  });
  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    double scale = 1,
    String? reason,
    bool choices = true,
    bool busy = false,
    VoidCallback? onSubmit,
    ValueChanged<String>? onChoose,
    VoidCallback? onBack,
    VoidCallback? onMessage,
    String recipient = 'K. Nattaporn',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: RepaintBoundary(
            key: const Key('g03-capture'),
            child: PackageProblemView(
              stopLabel: 'Stop 1 of 4',
              recipient: recipient,
              address: 'The Emporio Place · Sukhumvit 24',
              packageLabel: 'Midnight Orchid + glass vase',
              packageMeta: '#8421 · 1 package',
              handling: 'Fragile',
              problemLabel: 'Delivery problem',
              details: controller,
              reason: reason,
              showChoices: choices,
              busy: busy,
              onChoose: onChoose ?? (_) {},
              onDetail: (_) {},
              onBack: onBack ?? () {},
              onMore: () {},
              onPhoto: () {},
              onSubmit: onSubmit ?? () {},
              onCallRecipient: () {},
              onMessageOperations: onMessage ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'G03 approved choices and contacts dispatch callbacks; measured outer geometry',
    (tester) async {
      String? chosen;
      var back = 0, message = 0;
      await show(
        tester,
        onChoose: (r) => chosen = r,
        onBack: () => back++,
        onMessage: () => message++,
      );
      expect(tester.getSize(find.byKey(const Key('g03-topbar'))).height, 64);
      expect(tester.getRect(find.byKey(const Key('g03-heading'))).top, 64);
      expect(tester.getRect(find.byKey(const Key('g03-footer'))).bottom, 852);
      for (final choice in PackageProblemEnglish.choices.entries) {
        await tester.tap(find.text(choice.value.$1));
        expect(chosen, choice.key);
      }
      await tester.tap(find.byTooltip('Back'));
      expect(back, 1);
      await tester.tap(find.text('Message Ops'));
      expect(message, 1);
      expect(find.text('Request instructions'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('g03-capture')),
        matchesGoldenFile('goldens/v23/g03-choices.png'),
      );
    },
  );
  testWidgets('damaged needs real photo before submit; no fake approval', (
    tester,
  ) async {
    var submitted = 0;
    await show(
      tester,
      choices: false,
      reason: 'damaged',
      onSubmit: () => submitted++,
    );
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Photograph the damage'), findsOneWidget);
    await tester.tap(find.text('Request instructions'));
    expect(submitted, 0);
    expect(find.text('Waiting for decision'), findsNothing);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('g03-capture')),
      matchesGoldenFile('goldens/v23/g03-damaged.png'),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing has no photo gate and can explicitly submit', (
    tester,
  ) async {
    var submitted = 0;
    await show(
      tester,
      choices: false,
      reason: 'missing',
      onSubmit: () => submitted++,
    );
    expect(
      find.text('No photo required for a missing package.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('g03-take-photo')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('g03-details')),
      'Missing from pickup',
    );
    await tester.tap(find.text('Request instructions'));
    expect(submitted, 1);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('g03-capture')),
      matchesGoldenFile('goldens/v23/g03-missing.png'),
    );
  });
  for (final reason in ['damaged', 'missing', 'wrong']) {
    testWidgets(
      '$reason 320px/large text/short viewport scrolls with pinned contacts',
      (tester) async {
        await show(
          tester,
          size: const Size(320, 640),
          scale: 1.6,
          choices: false,
          reason: reason,
          recipient: 'A long recipient name for wrapping',
        );
        await tester.ensureVisible(find.byKey(const Key('g03-details')));
        await tester.pumpAndSettle();
        expect(find.text('Message Ops'), findsOneWidget);
        expect(tester.getRect(find.byKey(const Key('g03-footer'))).bottom, 640);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'busy prevents double submission, back and contacts remain available',
    (tester) async {
      var back = 0, submitted = 0;
      await show(
        tester,
        choices: false,
        reason: 'missing',
        busy: true,
        onBack: () => back++,
        onSubmit: () => submitted++,
      );
      await tester.tap(find.text('Saving report…'));
      expect(submitted, 0);
      await tester.tap(find.byTooltip('Back'));
      expect(back, 1);
    },
  );
}
