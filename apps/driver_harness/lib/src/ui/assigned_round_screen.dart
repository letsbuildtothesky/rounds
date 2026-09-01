import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../app/harness_app_controller.dart';
import 'navigation_harness_screen.dart';

class AssignedRoundScreen extends StatelessWidget {
  const AssignedRoundScreen({
    required this.controller,
    required this.enableNativeNavigation,
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;

  @override
  Widget build(BuildContext context) {
    final strings = controller.strings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rounds · Phase 0'),
        actions: [
          IconButton(
            tooltip: strings.chooseLanguage,
            onPressed: () => controller.selectLocale(
              controller.locale == HarnessLocale.thai
                  ? HarnessLocale.english
                  : HarnessLocale.thai,
            ),
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.assignedRound,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${strings.currentStop} · STOP-001'),
                      const SizedBox(height: 8),
                      Text(
                        strings.recipient,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(strings.demoAddress),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('start-navigation'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NavigationHarnessScreen(
                      controller: controller,
                      enableNativeNavigation: enableNativeNavigation,
                    ),
                  ),
                ),
                icon: const Icon(Icons.navigation_rounded),
                label: Text(strings.startNavigation),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
