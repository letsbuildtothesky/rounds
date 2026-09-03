import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ui/assigned_round_screen.dart';
import '../ui/driver_login_screen.dart';
import '../ui/driver_splash_screen.dart';
import '../ui/language_screen.dart';
import '../ui/live_delivery_change_screen.dart';
import '../ui/operations_chat_screen.dart';
import '../ui/pickup_confirmation_screen.dart';
import '../ui/start_shift_screen.dart';
import '../connectivity/offline_reconnecting_screen.dart';
import '../driver/driver_session.dart';
import 'app_strings.dart';
import 'driver_design_system.dart';
import 'generated/driver_ui_metrics.g.dart';
import 'harness_app_controller.dart';

export 'harness_app_controller.dart';

class RoundsHarnessApp extends StatefulWidget {
  const RoundsHarnessApp({
    required this.controller,
    this.enableNativeNavigation = true,
    this.splashDuration = const Duration(
      milliseconds: DriverA01Metrics.proceedAfterMs,
    ),
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;
  final Duration splashDuration;

  @override
  State<RoundsHarnessApp> createState() => _RoundsHarnessAppState();
}

class _RoundsHarnessAppState extends State<RoundsHarnessApp> {
  late bool _splashComplete = widget.splashDuration == Duration.zero;

  static const _previewScreen = String.fromEnvironment('ROUNDS_PREVIEW_SCREEN');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: widget.controller.locale.locale,
        supportedLocales: const [Locale('th', 'TH'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildRoundsDriverTheme(),
        builder: (context, child) => Stack(
          children: [
            ExcludeSemantics(
              excluding: widget.controller.showConnectionSurface,
              child: child ?? const SizedBox.shrink(),
            ),
            if (widget.controller.showConnectionSurface)
              Positioned.fill(
                child: OfflineReconnectingScreen(
                  snapshot: widget.controller.syncSnapshot,
                  onReturnToRound: widget.controller.returnToRound,
                  onRetry: widget.controller.retryConnection,
                ),
              ),
          ],
        ),
        home: _home(),
      ),
    );
  }

  Widget _home() {
    if (!kReleaseMode && _previewScreen == 'pickup') {
      return PickupConfirmationScreen(
        controller: widget.controller,
        round: AssignedRoundScreen.demoRound,
      );
    }
    if (!_splashComplete) {
      return DriverSplashScreen(
        proceedAfter: widget.splashDuration,
        onComplete: () => setState(() => _splashComplete = true),
      );
    }
    if (!widget.controller.hasSelectedLanguage) {
      return LanguageScreen(controller: widget.controller);
    }
    if (widget.controller.driverConfigured &&
        widget.controller.driverLoading &&
        widget.controller.driverSession == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.controller.driverConfigured &&
        widget.controller.driverSession == null) {
      return DriverLoginScreen(controller: widget.controller);
    }
    final session = widget.controller.driverSession;
    final round = session?.currentRound;
    final change = session?.pendingLiveChange;
    if (round != null && change != null) {
      DriverRoundStopModel? stop;
      for (final candidate in round.stops) {
        if (candidate.id == change.stopId) {
          stop = candidate;
          break;
        }
      }
      if (stop != null) {
        final changedStop = stop;
        return LiveDeliveryChangeScreen(
          round: round,
          stop: changedStop,
          change: change,
          enableNativeMap: widget.enableNativeNavigation,
          onAcknowledge: () =>
              widget.controller.acknowledgeLiveDeliveryChange(change),
          contactScreenBuilder: (_) => OperationsChatScreen(
            controller: widget.controller,
            round: round,
            stop: changedStop,
          ),
        );
      }
    }
    final shift = session?.shift;
    if (session != null &&
        shift != null &&
        shift.attendance == null &&
        (round == null || round.state == 'approved')) {
      return StartShiftScreen(controller: widget.controller, session: session);
    }
    return AssignedRoundScreen(
      controller: widget.controller,
      enableNativeNavigation: widget.enableNativeNavigation,
      session: session,
    );
  }
}
