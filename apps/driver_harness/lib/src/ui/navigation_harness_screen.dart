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
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;
  final DriverRoundStopModel stop;

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

  @override
  void initState() {
    super.initState();
    _arrived = widget.stop.state == 'arrived';
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.controller.strings;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Material(
              color: const Color(0xFF17453B),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      color: Colors.white,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${strings.currentStop} · ${widget.stop.deliveryReference}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            widget.stop.recipientName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _FreshnessBadge(
                      freshness: const FreshnessPolicy().classify(
                        _lastOperationalSample,
                        DateTime.now(),
                      ),
                      controller: widget.controller,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
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
                    )
                  : _NavigationPreview(label: strings.navigationReady),
            ),
            if (_navigationStatus != null)
              Material(
                color: const Color(0xFFE8EFEA),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_navigationStatus!)),
                    ],
                  ),
                ),
              ),
            Material(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.support_agent),
                            label: Text(strings.contactOperations),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.warning_amber_rounded),
                            label: Text(strings.reportException),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_nearArrival ||
                        !widget.enableNativeNavigation ||
                        _arrived ||
                        _arrivalPendingSync)
                      FilledButton(
                        key: const Key('arrival-action'),
                        onPressed: _arrivalPendingSync || _submittingArrival
                            ? null
                            : _arrived
                            ? _openPod
                            : _confirmArrival,
                        child: Text(
                          _arrived
                              ? strings.podPlaceholder
                              : _submittingArrival
                              ? 'Confirming with server…'
                              : _arrivalPendingSync
                              ? 'Pending sync — not arrived'
                              : strings.arrived,
                        ),
                      ),
                    if (_arrivalPendingSync)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          children: [
                            Text(
                              strings.pendingSync,
                              style: const TextStyle(
                                color: Color(0xFF9B5A00),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'Arrival is not committed yet',
                              style: TextStyle(color: Color(0xFF9B5A00)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
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
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        _label,
        style: const TextStyle(
          color: Color(0xFF17453B),
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}
