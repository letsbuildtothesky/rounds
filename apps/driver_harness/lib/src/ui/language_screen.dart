import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../app/harness_app_controller.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({required this.controller, super.key});

  final HarnessAppController controller;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late HarnessLocale _selection = widget.controller.locale;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(_selection);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.route_rounded,
                size: 56,
                color: Color(0xFF17453B),
              ),
              const SizedBox(height: 24),
              Text(
                strings.chooseLanguage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 32),
              _LanguageChoice(
                label: strings.thai,
                selected: _selection == HarnessLocale.thai,
                onTap: () => setState(() => _selection = HarnessLocale.thai),
              ),
              const SizedBox(height: 12),
              _LanguageChoice(
                label: strings.english,
                selected: _selection == HarnessLocale.english,
                onTap: () => setState(() => _selection = HarnessLocale.english),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('continue-language'),
                onPressed: () => widget.controller.selectLocale(_selection),
                child: Text(strings.continueAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFDDECE5) : Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleLarge),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: const Color(0xFF17453B),
            ),
          ],
        ),
      ),
    ),
  );
}
