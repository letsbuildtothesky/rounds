import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ui/assigned_round_screen.dart';
import '../ui/driver_login_screen.dart';
import '../ui/language_screen.dart';
import 'app_strings.dart';
import 'harness_app_controller.dart';

export 'harness_app_controller.dart';

class RoundsHarnessApp extends StatelessWidget {
  const RoundsHarnessApp({
    required this.controller,
    this.enableNativeNavigation = true,
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: controller.locale.locale,
        supportedLocales: const [Locale('th', 'TH'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF17453B),
            primary: const Color(0xFF17453B),
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F2EC),
          useMaterial3: true,
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        home: !controller.hasSelectedLanguage
            ? LanguageScreen(controller: controller)
            : controller.driverConfigured && controller.driverLoading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : controller.driverConfigured && controller.driverSession == null
            ? DriverLoginScreen(controller: controller)
            : AssignedRoundScreen(
                controller: controller,
                enableNativeNavigation: enableNativeNavigation,
                session: controller.driverSession,
              ),
      ),
    );
  }
}
