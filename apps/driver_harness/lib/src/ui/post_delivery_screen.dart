import 'package:flutter/material.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../driver/driver_session.dart';
import 'components/round_overview_map.dart';
import 'components/rounds_action_drawer.dart';

DriverRoundStopModel? nextOperationalStop(DriverRoundModel? round) {
  if (round == null) return null;
  for (final stop in round.stops) {
    if (stop.state != 'completed' && stop.state != 'cancelled') return stop;
  }
  return null;
}

class StopCompleteNextStopScreen extends StatelessWidget {
  const StopCompleteNextStopScreen({
    required this.round,
    required this.completedStop,
    required this.nextStop,
    required this.enableNativeMap,
    required this.onNavigate,
    super.key,
  });

  final DriverRoundModel round;
  final DriverRoundStopModel completedStop;
  final DriverRoundStopModel nextStop;
  final bool enableNativeMap;
  final void Function(BuildContext context) onNavigate;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final barHeight = compact
        ? DriverF08Metrics.compactCompleteBarHeight
        : DriverF08Metrics.completeBarHeight;
    final dockHeight = compact
        ? DriverF08Metrics.compactDockHeight
        : DriverF08Metrics.dockHeight;
    final delivered = round.stops
        .where((stop) => stop.state == 'completed')
        .length;
    final remaining = round.stops
        .where(
          (stop) =>
              stop.sequence > nextStop.sequence &&
              stop.state != 'completed' &&
              stop.state != 'cancelled',
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: RoundsColors.canvas,
      body: SafeArea(
        child: MediaQuery.withNoTextScaling(
          child: Stack(
            children: [
              Positioned(
                key: const Key('f08-map'),
                left: 0,
                right: 0,
                top: barHeight,
                bottom: dockHeight,
                child: RoundOverviewMap(
                  round: round,
                  enableNativeMap: enableNativeMap,
                  currentStopSequence: nextStop.sequence,
                  completedStopSequences: round.stops
                      .where((stop) => stop.state == 'completed')
                      .map((stop) => stop.sequence)
                      .toSet(),
                  semanticsLabel: 'Remaining Round route map',
                ),
              ),
              Positioned(
                key: const Key('f08-complete-bar'),
                left: 0,
                right: 0,
                top: 0,
                height: barHeight,
                child: _CompletedStopBar(
                  stop: completedStop,
                  delivered: delivered,
                  total: round.stops.length,
                ),
              ),
              Positioned(
                key: const Key('f08-map-summary'),
                left: 12,
                top: barHeight + 14,
                child: _NextMapSummary(
                  nextStop: nextStop,
                  total: round.stops.length,
                ),
              ),
              Positioned(
                key: const Key('f08-next-dock'),
                left: 0,
                right: 0,
                bottom: 0,
                height: dockHeight,
                child: _NextStopDock(
                  nextStop: nextStop,
                  total: round.stops.length,
                  remaining: remaining,
                  onNavigate: () => onNavigate(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedStopBar extends StatelessWidget {
  const _CompletedStopBar({
    required this.stop,
    required this.delivered,
    required this.total,
  });

  final DriverRoundStopModel stop;
  final int delivered;
  final int total;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverF08Metrics.completeBarPaddingHorizontal,
      ),
      child: Row(
        children: [
          Container(
            width: DriverF08Metrics.completeIconSize,
            height: DriverF08Metrics.completeIconSize,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF8F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 21, color: RoundsColors.green),
          ),
          const SizedBox(width: DriverF08Metrics.completeColumnGap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stop ${stop.sequence} complete',
                  key: const Key('f08-complete-title'),
                  style: const TextStyle(
                    color: RoundsColors.ink,
                    fontSize: DriverF08Metrics.completeTitleSize,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: DriverF08Metrics.completeDetailGap),
                Text(
                  stop.recipientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverF08Metrics.completeDetailSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$delivered of $total',
                style: const TextStyle(
                  color: RoundsColors.green,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'delivered',
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _NextMapSummary extends StatelessWidget {
  const _NextMapSummary({required this.nextStop, required this.total});

  final DriverRoundStopModel nextStop;
  final int total;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .96),
    elevation: 4,
    shadowColor: const Color(0x1F172238),
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: RoundsColors.line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stop ${nextStop.sequence} of $total',
            style: const TextStyle(
              color: RoundsColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Next · ready',
            style: TextStyle(
              color: RoundsColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NextStopDock extends StatelessWidget {
  const _NextStopDock({
    required this.nextStop,
    required this.total,
    required this.remaining,
    required this.onNavigate,
  });

  final DriverRoundStopModel nextStop;
  final int total;
  final List<DriverRoundStopModel> remaining;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: RoundsColors.line)),
      boxShadow: [
        BoxShadow(
          color: Color(0x12172238),
          blurRadius: 30,
          offset: Offset(0, -12),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        DriverF08Metrics.dockPaddingHorizontal,
        DriverF08Metrics.dockPaddingTop,
        DriverF08Metrics.dockPaddingHorizontal,
        DriverF08Metrics.dockPaddingBottom,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT STOP · ${nextStop.sequence} OF $total',
                      key: const Key('f08-next-kicker'),
                      style: const TextStyle(
                        color: RoundsColors.orange,
                        fontSize: DriverF08Metrics.kickerSize,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .88,
                      ),
                    ),
                    const SizedBox(height: DriverF08Metrics.nameGap),
                    Text(
                      nextStop.recipientName,
                      key: const Key('f08-next-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoundsColors.ink,
                        fontSize: DriverF08Metrics.nameSize,
                        height: .98,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.35,
                      ),
                    ),
                    const SizedBox(height: DriverF08Metrics.placeGap),
                    Text(
                      nextStop.rawAddress,
                      key: const Key('f08-next-place'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoundsColors.muted,
                        fontSize: DriverF08Metrics.placeSize,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Padding(
                padding: EdgeInsets.only(top: 13),
                child: Text(
                  'Ready',
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: RoundsColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nextStop.manifestItems.isEmpty
                      ? nextStop.deliveryReference
                      : nextStop.manifestItems
                            .map(
                              (item) =>
                                  '${item.quantity > 1 ? '${item.quantity}× ' : ''}${item.description}',
                            )
                            .join(' · '),
                  key: const Key('f08-task'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoundsColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            key: const Key('f08-navigate-next'),
            width: double.infinity,
            height: DriverF08Metrics.primaryHeight,
            child: FilledButton(
              onPressed: onNavigate,
              style: FilledButton.styleFrom(
                backgroundColor: RoundsColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DriverF08Metrics.primaryRadius,
                  ),
                ),
              ),
              child: Text(
                'Navigate to Stop ${nextStop.sequence}',
                style: const TextStyle(
                  fontSize: DriverF08Metrics.primarySize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (remaining.isNotEmpty) ...[
            const SizedBox(height: DriverF08Metrics.remainingMarginTop),
            SizedBox(
              height: DriverF08Metrics.remainingHeight,
              child: TextButton(
                key: const Key('f08-remaining-stops'),
                onPressed: () => _showRemaining(context),
                child: Text(
                  '${remaining.length} ${remaining.length == 1 ? 'stop' : 'stops'} after this',
                  style: const TextStyle(
                    color: RoundsColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _showRemaining(BuildContext context) async {
    await showRoundsActionDrawer(
      context,
      title: 'Remaining stops',
      actions: [
        for (final stop in remaining)
          RoundsDrawerAction(
            value: stop.id,
            label:
                '${stop.sequence}. ${stop.recipientName} · ${stop.rawAddress}',
            icon: Icons.location_on_outlined,
          ),
      ],
    );
  }
}

class RoundCompleteScreen extends StatelessWidget {
  const RoundCompleteScreen({
    required this.round,
    required this.onContinue,
    super.key,
  });

  final DriverRoundModel round;
  final void Function(BuildContext context) onContinue;

  @override
  Widget build(BuildContext context) {
    final delivered = round.stops
        .where((stop) => stop.state == 'completed')
        .length;
    final closed = round.stops
        .where((stop) => stop.state == 'cancelled')
        .length;
    final resolved = delivered + closed;
    final hasClosedStops = closed > 0;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: MediaQuery.withNoTextScaling(
          child: Column(
            children: [
              Container(
                key: const Key('i01-topbar'),
                height: DriverI01Metrics.topBarHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: DriverI01Metrics.topBarPaddingHorizontal,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: RoundsColors.line)),
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Rounds',
                      style: TextStyle(
                        color: RoundsColors.ink,
                        fontSize: DriverI01Metrics.brandSize,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(left: 3, bottom: 2),
                      decoration: const BoxDecoration(
                        color: RoundsColors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                key: const Key('i01-hero'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  DriverI01Metrics.heroPaddingHorizontal,
                  DriverI01Metrics.heroPaddingTop,
                  DriverI01Metrics.heroPaddingHorizontal,
                  DriverI01Metrics.heroPaddingBottom,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: RoundsColors.line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check, size: 22, color: RoundsColors.green),
                        SizedBox(width: DriverI01Metrics.heroStateGap),
                        Text(
                          'ROUND COMPLETE',
                          style: TextStyle(
                            color: RoundsColors.green,
                            fontSize: DriverI01Metrics.heroStateSize,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.08,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DriverI01Metrics.heroStateBottom),
                    Text(
                      hasClosedStops
                          ? '$resolved of ${round.stops.length} resolved'
                          : '$delivered of ${round.stops.length} delivered',
                      key: const Key('i01-title'),
                      style: const TextStyle(
                        color: RoundsColors.ink,
                        fontSize: DriverI01Metrics.heroTitleSize,
                        height: DriverI01Metrics.heroTitleHeight,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2.5,
                      ),
                    ),
                    const SizedBox(height: DriverI01Metrics.heroSubtitleTop),
                    Text(
                      hasClosedStops
                          ? '$delivered delivered · $closed formally closed'
                          : 'All deliveries committed',
                      style: const TextStyle(
                        color: RoundsColors.inkSecondary,
                        fontSize: DriverI01Metrics.heroSubtitleSize,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.45,
                      ),
                    ),
                    const SizedBox(height: DriverI01Metrics.heroMetaTop),
                    Text(
                      '${round.tenantName} · ${round.reference}',
                      style: const TextStyle(
                        color: RoundsColors.muted,
                        fontSize: DriverI01Metrics.heroMetaSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  key: const Key('i01-continuation'),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    DriverI01Metrics.continuationPaddingHorizontal,
                    DriverI01Metrics.continuationPaddingTop,
                    DriverI01Metrics.continuationPaddingHorizontal,
                    20,
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TEAM SHIFT',
                        style: TextStyle(
                          color: RoundsColors.muted,
                          fontSize: DriverI01Metrics.continuationSectionSize,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.03,
                        ),
                      ),
                      SizedBox(
                        height: DriverI01Metrics.continuationSectionBottom,
                      ),
                      Text(
                        'Shift continues',
                        style: TextStyle(
                          color: RoundsColors.green,
                          fontSize: DriverI01Metrics.continuationStateSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(
                        height: DriverI01Metrics.continuationStateBottom,
                      ),
                      Text(
                        'Ready for next assignment',
                        style: TextStyle(
                          color: RoundsColors.ink,
                          fontSize: DriverI01Metrics.continuationMessageSize,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                key: const Key('i01-footer'),
                padding: const EdgeInsets.fromLTRB(
                  DriverI01Metrics.footerPaddingHorizontal,
                  DriverI01Metrics.footerPaddingTop,
                  DriverI01Metrics.footerPaddingHorizontal,
                  DriverI01Metrics.footerPaddingBottom,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: RoundsColors.line)),
                ),
                child: SizedBox(
                  key: const Key('i01-continue'),
                  width: double.infinity,
                  height: DriverI01Metrics.primaryHeight,
                  child: FilledButton(
                    onPressed: () => onContinue(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: RoundsColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DriverI01Metrics.primaryRadius,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Continue shift',
                      style: TextStyle(
                        fontSize: DriverI01Metrics.primarySize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
