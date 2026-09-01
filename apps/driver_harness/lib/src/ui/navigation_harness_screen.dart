import 'package:flutter/material.dart';

import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import '../navigation/google_navigation_surface.dart';
import '../telemetry/freshness.dart';
import 'proof_of_delivery_screen.dart';

class NavigationHarnessScreen extends StatefulWidget {
  const NavigationHarnessScreen({
    required this.controller,
    required this.enableNativeNavigation,
    required this.stop,
    required this.stopCount,
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;
  final DriverRoundStopModel stop;
  final int stopCount;

  @override
  State<NavigationHarnessScreen> createState() =>
      _NavigationHarnessScreenState();
}

class _NavigationHarnessScreenState extends State<NavigationHarnessScreen> {
  late bool _arrived;
  bool _nearArrival = false;
  bool _arrivalPendingSync = false;
  bool _submittingArrival = false;
  DateTime? _lastOperationalSample;
  String? _navigationStatus;
  int? _remainingSeconds;
  int? _remainingMeters;

  @override
  void initState() {
    super.initState();
    _arrived = widget.stop.state == 'arrived';
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.controller.strings;
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F4),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.enableNativeNavigation
                  ? GoogleNavigationSurface(
                      strings: strings,
                      onOperationalSample: (capturedAt) {
                        if (!mounted) return;
                        setState(() => _lastOperationalSample = capturedAt);
                      },
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
                      stopId: widget.stop.id,
                      destinationVersion: widget.stop.destinationVersion,
                      destinationTitle:
                          '${widget.stop.deliveryReference} · ${widget.stop.recipientName}',
                      latitude: widget.stop.latitude,
                      longitude: widget.stop.longitude,
                      bottomOverlayInset: 194,
                    )
                  : _NavigationPreview(label: strings.navigationReady),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _CurrentStopDock(
                controller: widget.controller,
                stop: widget.stop,
                stopCount: widget.stopCount,
                freshness: const FreshnessPolicy().classify(
                  _lastOperationalSample,
                  DateTime.now(),
                ),
                remainingSeconds: _remainingSeconds,
                remainingMeters: _remainingMeters,
                navigationStatus: _navigationStatus,
                showArrivalAction:
                    _nearArrival ||
                    !widget.enableNativeNavigation ||
                    _arrived ||
                    _arrivalPendingSync,
                arrived: _arrived,
                arrivalPendingSync: _arrivalPendingSync,
                submittingArrival: _submittingArrival,
                onBack: () => Navigator.of(context).pop(),
                onArrival: _arrivalPendingSync || _submittingArrival
                    ? null
                    : _arrived
                    ? _openPod
                    : _confirmArrival,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmArrival() async {
    setState(() => _submittingArrival = true);
    final outcome = await widget.controller.confirmArrival(widget.stop);
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

  Future<void> _openPod() async {
    final currentStop = widget.controller.driverSession?.currentRound?.stops
        .where((stop) => stop.id == widget.stop.id)
        .firstOrNull;
    if (currentStop == null) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProofOfDeliveryScreen(
          controller: widget.controller,
          stop: currentStop,
        ),
      ),
    );
    if (completed == true && mounted) Navigator.of(context).pop();
  }
}

class _CurrentStopDock extends StatelessWidget {
  const _CurrentStopDock({
    required this.controller,
    required this.stop,
    required this.stopCount,
    required this.freshness,
    required this.remainingSeconds,
    required this.remainingMeters,
    required this.navigationStatus,
    required this.showArrivalAction,
    required this.arrived,
    required this.arrivalPendingSync,
    required this.submittingArrival,
    required this.onBack,
    required this.onArrival,
  });

  final HarnessAppController controller;
  final DriverRoundStopModel stop;
  final int stopCount;
  final PositionFreshness freshness;
  final int? remainingSeconds;
  final int? remainingMeters;
  final String? navigationStatus;
  final bool showArrivalAction;
  final bool arrived;
  final bool arrivalPendingSync;
  final bool submittingArrival;
  final VoidCallback onBack;
  final VoidCallback? onArrival;

  String get _etaLabel {
    final seconds = remainingSeconds;
    if (seconds == null) return '—';
    return '${(seconds / 60).ceil().clamp(1, 999)} min';
  }

  String get _distanceLabel {
    final meters = remainingMeters;
    if (meters == null) {
      return navigationStatus?.contains('active') ?? false
          ? 'Routing'
          : 'Locating';
    }
    if (meters < 1000) return '$meters m';
    final kilometers = meters / 1000;
    return '${kilometers.toStringAsFixed(kilometers >= 10 ? 0 : 1)} km';
  }

  @override
  Widget build(BuildContext context) => Material(
    elevation: 10,
    color: Colors.white,
    shadowColor: const Color(0x33172238),
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFCBD4DC)),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _DockIconButton(
                key: const Key('navigation-back'),
                tooltip: 'Back',
                icon: Icons.arrow_back,
                onPressed: onBack,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'STOP ${stop.sequence} OF $stopCount · ${stop.deliveryReference}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFF6420),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .55,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _FreshnessBadge(
                          freshness: freshness,
                          controller: controller,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stop.recipientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172238),
                        fontSize: 19,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stop.rawAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF748094),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _etaLabel,
                    style: const TextStyle(
                      color: Color(0xFF172238),
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _distanceLabel,
                    style: const TextStyle(
                      color: Color(0xFF748094),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                key: const Key('navigation-more'),
                tooltip: 'More actions',
                icon: const Icon(Icons.more_horiz, color: Color(0xFF172238)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (action) {
                  final message = action == 'contact'
                      ? controller.strings.contactOperations
                      : controller.strings.reportException;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'contact',
                    child: Row(
                      children: [
                        const Icon(Icons.support_agent, size: 20),
                        const SizedBox(width: 10),
                        Text(controller.strings.contactOperations),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'exception',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: Color(0xFFBF4A4A),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          controller.strings.reportException,
                          style: const TextStyle(color: Color(0xFFBF4A4A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (showArrivalAction) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                key: const Key('arrival-action'),
                onPressed: onArrival,
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF168B50),
                  disabledBackgroundColor: const Color(0xFFD9DFE5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: Text(
                  arrived
                      ? controller.strings.podPlaceholder
                      : submittingArrival
                      ? 'Confirming with server…'
                      : arrivalPendingSync
                      ? 'Pending sync — not arrived'
                      : 'I’m at Stop ${stop.sequence}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
          if (arrivalPendingSync) ...[
            const SizedBox(height: 6),
            Text(
              controller.strings.pendingSync,
              style: const TextStyle(
                color: Color(0xFF9B5A00),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'Arrival is not committed yet',
              style: TextStyle(
                color: Color(0xFF9B5A00),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 42,
    height: 42,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: const Color(0xFF172238),
        side: const BorderSide(color: Color(0xFFCBD4DC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Icon(icon, size: 20, semanticLabel: tooltip),
    ),
  );
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

class _FreshnessBadge extends StatelessWidget {
  const _FreshnessBadge({required this.freshness, required this.controller});

  final PositionFreshness freshness;
  final HarnessAppController controller;

  String get _label => switch (freshness) {
    PositionFreshness.live => controller.strings.live,
    PositionFreshness.aging => controller.strings.aging,
    PositionFreshness.stale => controller.strings.stale,
    PositionFreshness.unknown => controller.strings.unknown,
  };

  Color get _background => switch (freshness) {
    PositionFreshness.live => const Color(0xFFBDE9D4),
    PositionFreshness.aging => const Color(0xFFFFE2A8),
    PositionFreshness.stale => const Color(0xFFF5C7A9),
    PositionFreshness.unknown => const Color(0xFFD9DDDC),
  };

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _background,
      borderRadius: BorderRadius.all(Radius.circular(99)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Text(
        _label,
        style: const TextStyle(
          color: Color(0xFF17453B),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}
