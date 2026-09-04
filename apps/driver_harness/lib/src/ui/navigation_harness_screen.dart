import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import '../navigation/gps_signal_monitor.dart';
import '../navigation/gps_unavailable_screen.dart';
import '../navigation/google_navigation_surface.dart';
import '../permissions/driver_permissions_screen.dart';
import 'components/navigation_road_controls.dart';
import 'components/navigation_stop_dock.dart';
import 'components/delivery_issue_flow.dart';
import 'components/operations_contact_flow.dart';
import 'components/rounds_action_drawer.dart';
import 'dropoff_handoff_screen.dart';
import 'post_delivery_screen.dart';
import 'operations_chat_screen.dart';

class NavigationHarnessScreen extends StatefulWidget {
  const NavigationHarnessScreen({
    required this.controller,
    required this.enableNativeNavigation,
    required this.round,
    required this.stop,
    required this.stopCount,
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final int stopCount;

  @override
  State<NavigationHarnessScreen> createState() =>
      _NavigationHarnessScreenState();
}

class _NavigationHarnessScreenState extends State<NavigationHarnessScreen> {
  late bool _arrived;
  final GoogleNavigationSurfaceController _navigationController =
      GoogleNavigationSurfaceController();
  bool _nearArrival = false;
  bool _arrivalPendingSync = false;
  bool _submittingArrival = false;
  String? _navigationStatus;
  int? _remainingSeconds;
  int? _remainingMeters;
  GpsNavigationInterruption? _gpsInterruption;

  @override
  void initState() {
    super.initState();
    _arrived = widget.stop.state == 'arrived';
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.controller.strings;
    final showArrivalAction =
        _nearArrival ||
        !widget.enableNativeNavigation ||
        _arrived ||
        _arrivalPendingSync;
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final outerMargin = compact
        ? DriverE02Metrics.compactOuterMargin
        : DriverE02Metrics.outerMargin;
    final controlSize = compact
        ? DriverE02Metrics.compactRoadControlSize
        : DriverE02Metrics.roadControlSize;
    final rowHeight = compact
        ? DriverE02Metrics.compactDockRowHeight
        : DriverE02Metrics.dockRowHeight;
    final dockHeight =
        rowHeight +
        (showArrivalAction
            ? DriverE02Metrics.arrivalHeight +
                  DriverE02Metrics.arrivalMarginBottom
            : 0) +
        (_arrivalPendingSync ? DriverE02Metrics.pendingStatusHeight : 0);
    final controlsBottom =
        outerMargin + dockHeight + DriverE02Metrics.vendorSafeBottomGap;
    final mapBottomInset =
        controlsBottom + controlSize + DriverE02Metrics.vendorSafeBottomGap;

    return Scaffold(
      backgroundColor: RoundsColors.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.enableNativeNavigation
                  ? GoogleNavigationSurface(
                      controller: _navigationController,
                      strings: strings,
                      onOperationalSample: (_) {},
                      onStatus: (status) {
                        if (!mounted) return;
                        setState(() => _navigationStatus = status);
                      },
                      onRemainingChanged: (remainingSeconds, remainingMeters) {
                        if (!mounted) return;
                        setState(() {
                          _remainingSeconds = remainingSeconds;
                          _remainingMeters = remainingMeters;
                        });
                      },
                      onArrival: () {
                        if (!mounted) return;
                        setState(() => _nearArrival = true);
                      },
                      onGpsInterruptionChanged: (interruption) {
                        if (!mounted) return;
                        setState(() => _gpsInterruption = interruption);
                      },
                      stopId: widget.stop.id,
                      destinationVersion: widget.stop.destinationVersion,
                      destinationTitle:
                          '${widget.stop.deliveryReference} · ${widget.stop.recipientName}',
                      latitude: widget.stop.latitude,
                      longitude: widget.stop.longitude,
                      bottomOverlayInset: mapBottomInset,
                    )
                  : _NavigationPreview(label: strings.navigationReady),
            ),
            if (_gpsInterruption == null)
              Positioned(
                left: outerMargin,
                right: outerMargin,
                bottom: controlsBottom,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NavigationRoadControlButton(
                      key: const Key('navigation-back'),
                      tooltip: 'Back',
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    NavigationRoadMenuButton(onPressed: _openNavigationActions),
                  ],
                ),
              ),
            if (_gpsInterruption == null)
              Positioned(
                left: outerMargin,
                right: outerMargin,
                bottom: outerMargin,
                child: NavigationStopDock(
                  sequence: widget.stop.sequence,
                  stopCount: widget.stopCount,
                  recipientName: widget.stop.recipientName,
                  address: widget.stop.rawAddress,
                  etaLabel: _etaLabel,
                  distanceLabel: _distanceLabel,
                  showArrivalAction: showArrivalAction,
                  arrivalLabel: _arrivalLabel,
                  onArrival: _arrivalPendingSync || _submittingArrival
                      ? null
                      : _arrived
                      ? _openPod
                      : _confirmArrival,
                  pendingSyncLabel: _arrivalPendingSync
                      ? widget.controller.strings.pendingSync
                      : null,
                  pendingSyncDetail: _arrivalPendingSync
                      ? 'Arrival is not committed yet'
                      : null,
                ),
              ),
            if (_gpsInterruption case final interruption?)
              Positioned.fill(
                child: GpsUnavailableScreen(
                  interruption: interruption,
                  contextLabel:
                      '${widget.round.tenantName} · Stop ${widget.stop.sequence}',
                  onBack: () => Navigator.of(context).pop(),
                  onContinue: () => setState(() => _gpsInterruption = null),
                  onRetry: () => unawaited(_retryGps()),
                  onReviewLocationAccess: _reviewLocationAccess,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewLocationAccess() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const DriverPermissionsScreen()),
    );
    if (mounted) await _retryGps();
  }

  Future<void> _retryGps() async {
    await _navigationController.retryGps();
  }

  String get _etaLabel {
    final seconds = _remainingSeconds;
    if (seconds == null) return '—';
    return '${(seconds / 60).ceil().clamp(1, 999)} min';
  }

  String get _distanceLabel {
    final meters = _remainingMeters;
    if (meters == null) {
      return _navigationStatus?.contains('active') ?? false
          ? 'Routing'
          : 'Locating';
    }
    if (meters < 1000) return '$meters m';
    final kilometers = meters / 1000;
    return '${kilometers.toStringAsFixed(kilometers >= 10 ? 0 : 1)} km';
  }

  String get _arrivalLabel => _arrived
      ? widget.controller.strings.podPlaceholder
      : _submittingArrival
      ? 'Confirming with server…'
      : _arrivalPendingSync
      ? 'Pending sync — not arrived'
      : 'I’m at Stop ${widget.stop.sequence}';

  Future<void> _openNavigationActions() async {
    final action = await showRoundsActionDrawer(
      context,
      title: 'Navigation actions',
      actions: [
        RoundsDrawerAction(
          value: 'contact',
          label: widget.controller.strings.contactOperations,
          icon: Icons.support_agent,
        ),
        RoundsDrawerAction(
          value: 'exception',
          label: widget.controller.strings.reportException,
          icon: Icons.warning_amber_rounded,
          destructive: true,
        ),
        if (kDebugMode && !_arrived)
          const RoundsDrawerAction(
            value: 'test_arrival_override',
            label: 'Test arrival override',
            icon: Icons.science_outlined,
          ),
      ],
    );
    if (action != null && mounted) await _onMenuSelected(action);
  }

  Future<void> _onMenuSelected(String action) async {
    if (action == 'test_arrival_override') {
      await _confirmTestArrivalOverride();
    } else if (action == 'contact') {
      await openOperationsContactFlow(
        context,
        round: widget.round,
        stop: widget.stop,
        controller: widget.controller,
        onMessage: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => OperationsChatScreen(
              controller: widget.controller,
              round: widget.round,
              stop: widget.stop,
            ),
          ),
        ),
      );
    } else {
      final currentStop = widget.controller.driverSession?.currentRound?.stops
          .where((stop) => stop.id == widget.stop.id)
          .firstOrNull;
      final reported = await openDeliveryIssueFlow(
        context,
        round: widget.round,
        stop: currentStop ?? widget.stop,
        damageEvidenceAvailable: _arrived,
        controller: widget.controller,
      );
      if (reported && mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmArrival({String? overrideReason}) async {
    setState(() => _submittingArrival = true);
    final currentStop = widget.controller.driverSession?.currentRound?.stops
        .where((stop) => stop.id == widget.stop.id)
        .firstOrNull;
    final outcome = await widget.controller.confirmArrival(
      currentStop ?? widget.stop,
      overrideReason: overrideReason,
    );
    if (!mounted) return;
    setState(() {
      _submittingArrival = false;
      _arrived = outcome?.committed ?? false;
      _arrivalPendingSync = outcome?.pendingSync ?? false;
    });
    if (outcome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.driverError ?? 'Arrival could not be confirmed',
          ),
        ),
      );
    } else if (outcome.pendingSync) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Arrival saved on this phone. Pending sync — server state is unchanged.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmTestArrivalOverride() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: RoundsColors.ink.withValues(alpha: .38),
      builder: (_) => const _ArrivalOverrideSheet(),
    );
    if (reason == null || !mounted) return;
    await _confirmArrival(overrideReason: reason);
  }

  Future<void> _openPod() async {
    final currentStop = widget.controller.driverSession?.currentRound?.stops
        .where((stop) => stop.id == widget.stop.id)
        .firstOrNull;
    if (currentStop == null) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DropoffHandoffScreen(
          controller: widget.controller,
          round: widget.round,
          stop: currentStop,
          stopCount: widget.stopCount,
        ),
      ),
    );
    if (completed != true || !mounted) return;
    final refreshedRound = widget.controller.driverSession?.currentRound;
    final nextStop = nextOperationalStop(refreshedRound);
    if (refreshedRound != null && nextStop != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => StopCompleteNextStopScreen(
            round: refreshedRound,
            completedStop: widget.stop,
            nextStop: nextStop,
            enableNativeMap: widget.enableNativeNavigation,
            onNavigate: (nextContext) {
              Navigator.of(nextContext).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => NavigationHarnessScreen(
                    controller: widget.controller,
                    enableNativeNavigation: widget.enableNativeNavigation,
                    round: refreshedRound,
                    stop: nextStop,
                    stopCount: refreshedRound.stops.length,
                  ),
                ),
              );
            },
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RoundCompleteScreen(
          round: widget.round,
          onContinue: (completeContext) => Navigator.of(completeContext).pop(),
        ),
      ),
    );
  }
}

class _ArrivalOverrideSheet extends StatefulWidget {
  const _ArrivalOverrideSheet();

  @override
  State<_ArrivalOverrideSheet> createState() => _ArrivalOverrideSheetState();
}

class _ArrivalOverrideSheetState extends State<_ArrivalOverrideSheet> {
  final _reason = TextEditingController(text: 'Field test override');

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      key: const Key('test-arrival-override-drawer'),
      color: RoundsColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RoundsRadii.large),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Test arrival override',
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Debug builds only. This commits a real, audited arrival without changing the delivery pin.',
              style: TextStyle(
                color: RoundsColors.muted,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('test-arrival-override-reason'),
              controller: _reason,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Audit reason',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 58,
              child: FilledButton(
                key: const Key('confirm-test-arrival-override'),
                onPressed: _reason.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_reason.text.trim()),
                child: const Text('Confirm test arrival'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationPreview extends StatelessWidget {
  const _NavigationPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFD7DDD7),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.two_wheeler, size: 64, color: Color(0xFF17453B)),
          const SizedBox(height: 16),
          Text(label, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}
