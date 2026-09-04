import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ui/assigned_round_screen.dart';
import '../ui/driver_login_screen.dart';
import '../ui/driver_splash_screen.dart';
import '../ui/dropoff_handoff_screen.dart';
import '../ui/language_screen.dart';
import '../ui/live_delivery_change_screen.dart';
import '../ui/operations_chat_screen.dart';
import '../ui/pickup_confirmation_screen.dart';
import '../ui/start_shift_screen.dart';
import '../ui/team_home_screen.dart';
import '../ui/shift_end_screen.dart';
import '../connectivity/offline_reconnecting_screen.dart';
import '../driver/driver_session.dart';
import 'app_strings.dart';
import 'driver_design_system.dart';
import 'generated/driver_ui_metrics.g.dart';
import 'harness_app_controller.dart';

export 'harness_app_controller.dart';

enum DriverOperationalHome { waiting, assigned, activeRound }

DriverOperationalHome driverOperationalHome(DriverSessionModel session) {
  final round = session.currentRound;
  if (round == null) return DriverOperationalHome.waiting;
  if (round.state == 'approved' || round.state == 'loading') {
    return DriverOperationalHome.assigned;
  }
  return DriverOperationalHome.activeRound;
}

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
  String? _dismissedShiftSurfaceKey;

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
    if (!kReleaseMode && _previewScreen == 'handoff') {
      return DropoffHandoffScreen(
        controller: widget.controller,
        round: AssignedRoundScreen.demoRound,
        stop: AssignedRoundScreen.demoRound.stops.first,
        stopCount: AssignedRoundScreen.demoRound.stops.length,
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
    if (session != null && shift?.attendance != null) {
      final attendance = shift!.attendance!;
      final now = DateTime.now();
      final open = attendance.endedAt == null;
      final atOrAfterEnd = !now.isBefore(shift.effective.endAt);
      final endingSoon =
          now.isBefore(shift.effective.endAt) &&
          shift.effective.endAt.difference(now) <= const Duration(minutes: 15);
      final DriverShiftSurface? surface = open
          ? round == null && atOrAfterEnd
                ? DriverShiftSurface.endConfirmation
                : round != null && atOrAfterEnd
                ? DriverShiftSurface.overtime
                : round != null && endingSoon
                ? DriverShiftSurface.endingSoon
                : null
          : null;
      final surfaceKey = '${attendance.id}:${surface?.name}';
      if (surface != null && _dismissedShiftSurfaceKey != surfaceKey) {
        return ShiftEndScreen(
          controller: widget.controller,
          session: session,
          surface: surface,
          enableNativeNavigation: widget.enableNativeNavigation,
          onNotYet: surface == DriverShiftSurface.endConfirmation
              ? () => setState(() => _dismissedShiftSurfaceKey = surfaceKey)
              : null,
        );
      }
      if (open) {
        switch (driverOperationalHome(session)) {
          case DriverOperationalHome.waiting:
            return TeamHomeScreen(
              controller: widget.controller,
              session: session,
              enableNativeNavigation: widget.enableNativeNavigation,
            );
          case DriverOperationalHome.assigned:
            return TeamHomeScreen(
              controller: widget.controller,
              session: session,
              round: round,
              enableNativeNavigation: widget.enableNativeNavigation,
            );
          case DriverOperationalHome.activeRound:
            break;
        }
      }
    }
    return AssignedRoundScreen(
      controller: widget.controller,
      enableNativeNavigation: widget.enableNativeNavigation,
      session: session,
    );
  }
}
