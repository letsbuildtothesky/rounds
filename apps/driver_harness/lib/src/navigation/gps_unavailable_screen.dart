import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import 'gps_signal_monitor.dart';

class GpsUnavailableScreen extends StatelessWidget {
  const GpsUnavailableScreen({
    required this.interruption,
    required this.contextLabel,
    required this.onBack,
    required this.onContinue,
    required this.onRetry,
    required this.onReviewLocationAccess,
    super.key,
  });

  final GpsNavigationInterruption interruption;
  final String contextLabel;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final VoidCallback onReviewLocationAccess;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: MediaQuery.withNoTextScaling(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth <= DriverReferenceViewport.compactBreakpoint;
          final shortViewport =
              constraints.maxHeight <= DriverN03Metrics.shortBreakpointHeight;
          final mapHeight = shortViewport
              ? constraints.maxHeight * DriverN03Metrics.shortMapHeightFactor
              : compact
              ? constraints.maxHeight * DriverN03Metrics.compactMapHeightFactor
              : math.min(
                  DriverN03Metrics.mapMaxHeight,
                  constraints.maxHeight * DriverN03Metrics.mapHeightFactor,
                );
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: DriverN03Metrics.topBarHeight,
                child: _TopBar(contextLabel: contextLabel, onBack: onBack),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: DriverN03Metrics.topBarHeight + mapHeight,
                bottom: 0,
                child: _RecoveryPanel(
                  interruption: interruption,
                  compact: compact,
                  shortViewport: shortViewport,
                  onBack: onBack,
                  onContinue: onContinue,
                  onRetry: onRetry,
                  onReviewLocationAccess: onReviewLocationAccess,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.contextLabel, required this.onBack});

  final String contextLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('n03-topbar'),
    color: RoundsColors.surface,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverN03Metrics.topBarPaddingHorizontal,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: DriverN03Metrics.backSize,
            child: IconButton(
              key: const Key('n03-back'),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              iconSize: DriverN03Metrics.backIconSize,
              color: RoundsColors.ink,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          const SizedBox(width: DriverN03Metrics.topBarGap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Navigation paused',
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: DriverN03Metrics.topTitleSize,
                    height: DriverN03Metrics.topTitleHeight,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: DriverN03Metrics.topSubtitleGap),
                Text(
                  contextLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverN03Metrics.topSubtitleSize,
                    height: DriverN03Metrics.topSubtitleHeight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecoveryPanel extends StatelessWidget {
  const _RecoveryPanel({
    required this.interruption,
    required this.compact,
    required this.shortViewport,
    required this.onBack,
    required this.onContinue,
    required this.onRetry,
    required this.onReviewLocationAccess,
  });

  final GpsNavigationInterruption interruption;
  final bool compact;
  final bool shortViewport;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final VoidCallback onReviewLocationAccess;

  bool get _accessOff =>
      interruption.kind == GpsInterruptionKind.locationAccessOff;

  bool get _cached => interruption.cachedRouteAvailable;

  @override
  Widget build(BuildContext context) {
    final title = _accessOff
        ? 'Turn location back on'
        : _cached
        ? 'Cached route ready'
        : 'Waiting for GPS';
    final lead = _accessOff
        ? 'Live navigation is paused.'
        : _cached
        ? 'Live position and ETA are paused.'
        : 'Live position is unavailable. No cached route is ready yet.';
    final primaryLabel = _accessOff
        ? 'Location settings'
        : _cached
        ? 'Continue with cached route'
        : 'Retry GPS';
    final secondaryLabel = _accessOff && _cached
        ? 'View cached route'
        : _cached
        ? 'Retry GPS'
        : 'Back';
    final primaryAction = _accessOff
        ? onReviewLocationAccess
        : _cached
        ? onContinue
        : onRetry;
    final secondaryAction = (_accessOff && _cached)
        ? onContinue
        : _cached
        ? onRetry
        : onBack;

    return ColoredBox(
      key: const Key('n03-panel'),
      color: RoundsColors.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact
              ? DriverN03Metrics.compactPanelPaddingHorizontal
              : DriverN03Metrics.panelPaddingHorizontal,
          shortViewport
              ? DriverN03Metrics.shortPanelPaddingTop
              : compact
              ? DriverN03Metrics.compactPanelPaddingTop
              : DriverN03Metrics.panelPaddingTop,
          compact
              ? DriverN03Metrics.compactPanelPaddingHorizontal
              : DriverN03Metrics.panelPaddingHorizontal,
          compact
              ? DriverN03Metrics.compactPanelPaddingBottom
              : DriverN03Metrics.panelPaddingBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _accessOff ? 'LOCATION ACCESS OFF' : 'GPS SIGNAL LOST',
              style: const TextStyle(
                color: RoundsColors.orange,
                fontSize: DriverN03Metrics.kickerSize,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.09,
              ),
            ),
            const SizedBox(height: DriverN03Metrics.kickerBottom),
            Text(
              title,
              key: const Key('n03-title'),
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: shortViewport
                    ? DriverN03Metrics.shortTitleSize
                    : compact
                    ? DriverN03Metrics.compactTitleSize
                    : DriverN03Metrics.titleSize,
                height: DriverN03Metrics.titleHeight,
                fontWeight: FontWeight.w900,
                letterSpacing: -2.14,
              ),
            ),
            SizedBox(
              height: shortViewport
                  ? DriverN03Metrics.shortLeadTop
                  : compact
                  ? DriverN03Metrics.compactLeadTop
                  : DriverN03Metrics.leadTop,
            ),
            Text(
              lead,
              style: TextStyle(
                color: RoundsColors.inkSecondary,
                fontSize: shortViewport
                    ? DriverN03Metrics.shortLeadSize
                    : compact
                    ? DriverN03Metrics.compactLeadSize
                    : DriverN03Metrics.leadSize,
                height: DriverN03Metrics.leadHeight,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              height: shortViewport
                  ? DriverN03Metrics.shortTruthTop
                  : compact
                  ? DriverN03Metrics.compactTruthTop
                  : DriverN03Metrics.truthTop,
            ),
            _TruthTable(
              cached: _cached,
              accessOff: _accessOff,
              compact: compact,
              shortViewport: shortViewport,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: shortViewport
                  ? DriverN03Metrics.shortPrimaryHeight
                  : compact
                  ? DriverN03Metrics.compactPrimaryHeight
                  : DriverN03Metrics.primaryHeight,
              child: FilledButton(
                key: const Key('n03-primary'),
                onPressed: primaryAction,
                style: FilledButton.styleFrom(
                  backgroundColor: RoundsColors.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DriverN03Metrics.primaryRadius,
                    ),
                  ),
                ),
                child: Text(
                  primaryLabel,
                  style: TextStyle(
                    fontSize: compact
                        ? DriverN03Metrics.compactPrimarySize
                        : DriverN03Metrics.primarySize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.34,
                  ),
                ),
              ),
            ),
            const SizedBox(height: DriverN03Metrics.secondaryTop),
            SizedBox(
              width: double.infinity,
              height: shortViewport
                  ? DriverN03Metrics.shortSecondaryHeight
                  : compact
                  ? DriverN03Metrics.compactSecondaryHeight
                  : DriverN03Metrics.secondaryHeight,
              child: TextButton(
                key: const Key('n03-secondary'),
                onPressed: secondaryAction,
                child: Text(
                  secondaryLabel,
                  style: const TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverN03Metrics.secondarySize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TruthTable extends StatelessWidget {
  const _TruthTable({
    required this.cached,
    required this.accessOff,
    required this.compact,
    required this.shortViewport,
  });

  final bool cached;
  final bool accessOff;
  final bool compact;
  final bool shortViewport;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('n03-truth'),
    decoration: const BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: RoundsColors.line),
      ),
    ),
    child: Column(
      children: [
        _TruthRow(
          label: 'Cached route',
          value: cached ? 'Available' : 'Unavailable',
          valueColor: cached ? RoundsColors.green : RoundsColors.muted,
          height: _rowHeight,
          textSize: _textSize,
        ),
        const Divider(height: 1, color: RoundsColors.line),
        _TruthRow(
          label: 'Live position',
          value: accessOff ? 'Off' : 'Paused',
          valueColor: RoundsColors.orange,
          height: _rowHeight,
          textSize: _textSize,
        ),
      ],
    ),
  );

  double get _rowHeight => shortViewport
      ? DriverN03Metrics.shortTruthRowMinHeight
      : compact
      ? DriverN03Metrics.compactTruthRowMinHeight
      : DriverN03Metrics.truthRowMinHeight;

  double get _textSize =>
      compact ? DriverN03Metrics.compactTruthSize : DriverN03Metrics.truthSize;
}

class _TruthRow extends StatelessWidget {
  const _TruthRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.height,
    required this.textSize,
  });

  final String label;
  final String value;
  final Color valueColor;
  final double height;
  final double textSize;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: textSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: DriverN03Metrics.truthGap),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: textSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
