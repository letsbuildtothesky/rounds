import 'package:flutter/material.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../driver/driver_session.dart';
import 'post_delivery_screen.dart';

class MyRoundsScreen extends StatelessWidget {
  const MyRoundsScreen({
    required this.session,
    required this.onReturnToRound,
    super.key,
  });

  final DriverSessionModel session;
  final VoidCallback onReturnToRound;

  @override
  Widget build(BuildContext context) {
    final current = session.currentRound;
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: MediaQuery.withNoTextScaling(
          child: Column(
            children: [
              const _MyRoundsTopBar(),
              Expanded(
                child: ListView(
                  key: const Key('j01-body'),
                  padding: EdgeInsets.zero,
                  children: [
                    const _MyRoundsHeader(),
                    if (current != null)
                      _ActiveRoundCard(
                        round: current,
                        onReturn: onReturnToRound,
                      ),
                    _CompletedRounds(rounds: session.completedRounds),
                  ],
                ),
              ),
              _MyRoundsBottomNav(onHome: onReturnToRound),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyRoundsTopBar extends StatelessWidget {
  const _MyRoundsTopBar();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('j01-topbar'),
    height: DriverJ01Metrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverJ01Metrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Rounds',
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: DriverJ01Metrics.brandSize,
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
        const SizedBox(
          width: DriverJ01Metrics.topButtonSize,
          height: DriverJ01Metrics.topButtonSize,
          child: Icon(
            Icons.notifications_none,
            color: RoundsColors.lineStrong,
            size: DriverJ01Metrics.topIconSize,
          ),
        ),
      ],
    ),
  );
}

class _MyRoundsHeader extends StatelessWidget {
  const _MyRoundsHeader();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('j01-header'),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      DriverJ01Metrics.headerPaddingHorizontal,
      DriverJ01Metrics.headerPaddingTop,
      DriverJ01Metrics.headerPaddingHorizontal,
      DriverJ01Metrics.headerPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORK',
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: DriverJ01Metrics.eyebrowSize,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.04,
          ),
        ),
        SizedBox(height: DriverJ01Metrics.eyebrowBottom),
        Text(
          'My Rounds',
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: DriverJ01Metrics.titleSize,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.87,
          ),
        ),
      ],
    ),
  );
}

class _ActiveRoundCard extends StatelessWidget {
  const _ActiveRoundCard({required this.round, required this.onReturn});

  final DriverRoundModel round;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final next = nextOperationalStop(round);
    final completed = round.stops
        .where((stop) => stop.state == 'completed' || stop.state == 'cancelled')
        .length;
    final remaining = round.stops.length - completed;
    return Container(
      key: const Key('j01-active-round'),
      padding: const EdgeInsets.fromLTRB(
        DriverJ01Metrics.activePaddingHorizontal -
            DriverJ01Metrics.activeBorderLeft,
        DriverJ01Metrics.activePaddingTop,
        DriverJ01Metrics.activePaddingHorizontal,
        DriverJ01Metrics.activePaddingBottom,
      ),
      decoration: const BoxDecoration(
        color: RoundsColors.surface,
        border: Border(
          left: BorderSide(
            color: RoundsColors.orange,
            width: DriverJ01Metrics.activeBorderLeft,
          ),
          bottom: BorderSide(color: RoundsColors.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVE ROUND',
            style: TextStyle(
              color: RoundsColors.orange,
              fontSize: DriverJ01Metrics.activeKickerSize,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.04,
            ),
          ),
          const SizedBox(height: DriverJ01Metrics.activeKickerBottom),
          Text(
            '${round.tenantName} · ${round.stops.length} ${round.stops.length == 1 ? 'stop' : 'stops'}',
            style: const TextStyle(
              color: RoundsColors.inkSecondary,
              fontSize: DriverJ01Metrics.activeMerchantSize,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DriverJ01Metrics.activeMerchantBottom),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next == null
                          ? 'Round complete'
                          : 'Stop ${next.sequence} of ${round.stops.length}',
                      style: const TextStyle(
                        color: RoundsColors.ink,
                        fontSize: DriverJ01Metrics.activeTitleSize,
                        height: .98,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2.04,
                      ),
                    ),
                    const SizedBox(height: DriverJ01Metrics.activeNextTop),
                    Text(
                      next == null
                          ? 'Awaiting server refresh'
                          : next.recipientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoundsColors.inkSecondary,
                        fontSize: DriverJ01Metrics.activeNextSize,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _duration(round.plannedDurationSeconds) ??
                        round.state.toUpperCase(),
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontSize: round.plannedDurationSeconds == null
                          ? 18
                          : DriverJ01Metrics.activeSideSize,
                      height: .95,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.76,
                    ),
                  ),
                  const SizedBox(height: DriverJ01Metrics.activeSideLabelTop),
                  Text(
                    round.plannedDurationSeconds == null
                        ? 'server state'
                        : 'planned route',
                    style: const TextStyle(
                      color: RoundsColors.muted,
                      fontSize: DriverJ01Metrics.activeSideLabelSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DriverJ01Metrics.activeMetaTop),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                '$remaining ${remaining == 1 ? 'stop' : 'stops'} left',
                style: const TextStyle(
                  color: RoundsColors.inkSecondary,
                  fontSize: DriverJ01Metrics.activeMetaSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (round.plannedDistanceMeters != null)
                Text(
                  '${_distance(round.plannedDistanceMeters!)} planned',
                  style: const TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverJ01Metrics.activeMetaSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: DriverJ01Metrics.activeButtonTop),
          SizedBox(
            key: const Key('j01-return-round'),
            width: double.infinity,
            height: DriverJ01Metrics.activeButtonHeight,
            child: FilledButton.icon(
              onPressed: onReturn,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DriverJ01Metrics.activeButtonRadius,
                  ),
                ),
              ),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 20),
              label: const Text(
                'Return to Round',
                style: TextStyle(
                  fontSize: DriverJ01Metrics.activeButtonSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedRounds extends StatelessWidget {
  const _CompletedRounds({required this.rounds});

  final List<DriverCompletedRoundModel> rounds;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('j01-completed'),
    padding: const EdgeInsets.fromLTRB(
      DriverJ01Metrics.completedPaddingHorizontal,
      DriverJ01Metrics.completedPaddingTop,
      DriverJ01Metrics.completedPaddingHorizontal,
      DriverJ01Metrics.completedPaddingBottom,
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Completed',
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: DriverJ01Metrics.completedSectionSize,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${rounds.length} ${rounds.length == 1 ? 'Round' : 'Rounds'}',
              style: const TextStyle(
                color: RoundsColors.muted,
                fontSize: DriverJ01Metrics.completedSectionCountSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: DriverJ01Metrics.completedSectionBottom),
        const Divider(height: 1),
        if (rounds.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 34),
            child: Text(
              'No completed Rounds yet.',
              style: TextStyle(
                color: RoundsColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          for (final round in rounds)
            _CompletedRoundRow(
              round: round,
              onTap: () => _showRoundEvidence(context, round),
            ),
      ],
    ),
  );
}

class _CompletedRoundRow extends StatelessWidget {
  const _CompletedRoundRow({required this.round, required this.onTap});

  final DriverCompletedRoundModel round;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('j01-completed-${round.id}'),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: DriverJ01Metrics.completedRowMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: DriverJ01Metrics.completedRowPaddingVertical,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          round.tenantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: RoundsColors.ink,
                            fontSize: DriverJ01Metrics.completedRowTitleSize,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.43,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Text(
                        'TEAM',
                        style: TextStyle(
                          color: RoundsColors.muted,
                          fontSize: DriverJ01Metrics.completedKindSize,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .89,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DriverJ01Metrics.completedSubTop),
                  Text(
                    '${round.stopCount} ${round.stopCount == 1 ? 'stop' : 'stops'}${round.plannedDistanceMeters == null ? '' : ' · ${_distance(round.plannedDistanceMeters!)} planned'}',
                    style: const TextStyle(
                      color: RoundsColors.muted,
                      fontSize: DriverJ01Metrics.completedSubSize,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: DriverJ01Metrics.completedProofTop),
                  Row(
                    children: [
                      Container(
                        width: DriverJ01Metrics.completedProofDotSize,
                        height: DriverJ01Metrics.completedProofDotSize,
                        decoration: const BoxDecoration(
                          color: RoundsColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        round.evidenceLabel,
                        style: const TextStyle(
                          color: RoundsColors.green,
                          fontSize: DriverJ01Metrics.completedProofSize,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _duration(round.plannedDurationSeconds) ?? 'Done',
                    style: const TextStyle(
                      color: RoundsColors.ink,
                      fontSize: DriverJ01Metrics.completedSideSize,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: DriverJ01Metrics.completedSideMetaTop),
                  Text(
                    _clock(round.completedAt),
                    style: const TextStyle(
                      color: RoundsColors.muted,
                      fontSize: DriverJ01Metrics.completedSideMetaSize,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MyRoundsBottomNav extends StatelessWidget {
  const _MyRoundsBottomNav({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('j01-bottom-nav'),
    height: DriverJ01Metrics.bottomNavHeight,
    padding: const EdgeInsets.fromLTRB(
      DriverJ01Metrics.bottomNavPaddingHorizontal,
      DriverJ01Metrics.bottomNavPaddingTop,
      DriverJ01Metrics.bottomNavPaddingHorizontal,
      DriverJ01Metrics.bottomNavPaddingBottom,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _NavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            onTap: onHome,
          ),
        ),
        const Expanded(
          child: _NavItem(
            icon: Icons.location_on_outlined,
            label: 'Jobs',
            active: true,
          ),
        ),
        const Expanded(
          child: _NavItem(icon: Icons.schedule, label: 'Hours'),
        ),
        const Expanded(
          child: _NavItem(icon: Icons.person_outline, label: 'Profile'),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: DriverJ01Metrics.bottomNavIconSize,
          color: active ? RoundsColors.orange : RoundsColors.muted,
        ),
        const SizedBox(height: DriverJ01Metrics.bottomNavGap),
        Text(
          label,
          style: TextStyle(
            color: active ? RoundsColors.orange : RoundsColors.muted,
            fontSize: DriverJ01Metrics.bottomNavLabelSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Future<void> _showRoundEvidence(
  BuildContext context,
  DriverCompletedRoundModel round,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  builder: (context) => _RoundEvidenceSheet(round: round),
);

class _RoundEvidenceSheet extends StatelessWidget {
  const _RoundEvidenceSheet({required this.round});

  final DriverCompletedRoundModel round;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('j01-evidence-sheet'),
    padding: const EdgeInsets.fromLTRB(
      DriverJ01Metrics.sheetPaddingHorizontal,
      DriverJ01Metrics.sheetPaddingTop,
      DriverJ01Metrics.sheetPaddingHorizontal,
      DriverJ01Metrics.sheetPaddingBottom,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(DriverJ01Metrics.sheetRadius),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: DriverJ01Metrics.sheetGrabWidth,
              height: DriverJ01Metrics.sheetGrabHeight,
              margin: const EdgeInsets.only(
                bottom: DriverJ01Metrics.sheetGrabBottom,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFD7DDE2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const Text(
            'COMPLETED',
            style: TextStyle(
              color: RoundsColors.green,
              fontSize: DriverJ01Metrics.sheetKickerSize,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.04,
            ),
          ),
          const SizedBox(height: DriverJ01Metrics.sheetKickerBottom),
          Text(
            round.tenantName,
            style: const TextStyle(
              color: RoundsColors.ink,
              fontSize: DriverJ01Metrics.sheetTitleSize,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.26,
            ),
          ),
          const SizedBox(height: DriverJ01Metrics.sheetSubTop),
          Text(
            '${round.reference} · ${_date(round.serviceDate)} · ${_clock(round.completedAt)}',
            style: const TextStyle(
              color: RoundsColors.muted,
              fontSize: DriverJ01Metrics.sheetSubSize,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DriverJ01Metrics.sheetEvidenceTop),
          const Divider(height: 1),
          _EvidenceRow(
            label: 'Stops',
            value: '${round.stopCount} of ${round.stopCount}',
          ),
          if (round.plannedDistanceMeters != null)
            _EvidenceRow(
              label: 'Planned distance',
              value: _distance(round.plannedDistanceMeters!),
            ),
          if (round.plannedDurationSeconds != null)
            _EvidenceRow(
              label: 'Planned duration',
              value: _duration(round.plannedDurationSeconds)!,
            ),
          _EvidenceRow(
            label: 'Evidence',
            value: round.evidenceLabel,
            good: true,
          ),
          const SizedBox(height: DriverJ01Metrics.sheetButtonTop),
          SizedBox(
            width: double.infinity,
            height: DriverJ01Metrics.sheetButtonHeight,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DriverJ01Metrics.sheetButtonRadius,
                  ),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: DriverJ01Metrics.sheetButtonSize,
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

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.label,
    required this.value,
    this.good = false,
  });

  final String label;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: DriverJ01Metrics.sheetRowHeight,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: RoundsColors.muted,
            fontSize: DriverJ01Metrics.sheetRowLabelSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: good ? RoundsColors.green : RoundsColors.ink,
              fontSize: DriverJ01Metrics.sheetRowValueSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

String? _duration(int? seconds) {
  if (seconds == null) return null;
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

String _distance(int meters) => '${(meters / 1000).toStringAsFixed(1)} km';

String _clock(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _date(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}
