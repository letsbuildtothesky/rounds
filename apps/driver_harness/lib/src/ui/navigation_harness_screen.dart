import 'package:flutter/material.dart';

import '../app/harness_app_controller.dart';
import '../navigation/google_navigation_surface.dart';
import '../telemetry/freshness.dart';

class NavigationHarnessScreen extends StatefulWidget {
  const NavigationHarnessScreen({
    required this.controller,
    required this.enableNativeNavigation,
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;

  @override
  State<NavigationHarnessScreen> createState() =>
      _NavigationHarnessScreenState();
}

class _NavigationHarnessScreenState extends State<NavigationHarnessScreen> {
  bool _arrived = false;
  DateTime? _lastOperationalSample;
  String? _navigationStatus;

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
                            '${strings.currentStop} · STOP-001',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            strings.recipient,
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
                        setState(() => _arrived = true);
                      },
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
                    FilledButton(
                      key: const Key('arrival-action'),
                      onPressed: () => setState(() => _arrived = true),
                      child: Text(
                        _arrived ? strings.podPlaceholder : strings.arrived,
                      ),
                    ),
                    if (_arrived)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          strings.pendingSync,
                          style: const TextStyle(color: Color(0xFF9B5A00)),
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
