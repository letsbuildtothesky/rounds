import 'package:flutter/material.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import 'driver_sync_state.dart';

class OfflineReconnectingScreen extends StatelessWidget {
  const OfflineReconnectingScreen({
    required this.snapshot,
    required this.onReturnToRound,
    required this.onRetry,
    super.key,
  });

  final DriverSyncSnapshot snapshot;
  final VoidCallback onReturnToRound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RoundsColors.surface,
      child: SafeArea(
        child: MediaQuery.withNoTextScaling(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth <
                  DriverReferenceViewport.compactBreakpoint;
              final short =
                  constraints.maxHeight <=
                  DriverN02Metrics.shortBreakpointHeight;
              return Column(
                children: [
                  _ConnectionTopBar(snapshot: snapshot, compact: compact),
                  Expanded(
                    child: _ConnectionBody(
                      snapshot: snapshot,
                      compact: compact,
                      short: short,
                      onReturnToRound: onReturnToRound,
                      onRetry: onRetry,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConnectionTopBar extends StatelessWidget {
  const _ConnectionTopBar({required this.snapshot, required this.compact});

  final DriverSyncSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.phase == DriverConnectionPhase.online
        ? RoundsColors.green
        : RoundsColors.orange;
    final label = switch (snapshot.phase) {
      DriverConnectionPhase.online => 'Online',
      DriverConnectionPhase.offline => 'Offline',
      DriverConnectionPhase.reconnecting => 'Reconnecting',
    };
    return Container(
      key: const Key('n02-topbar'),
      height: DriverN02Metrics.topBarHeight,
      padding: EdgeInsets.symmetric(
        horizontal: compact
            ? DriverN02Metrics.compactTopBarPaddingHorizontal
            : DriverN02Metrics.topBarPaddingHorizontal,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rounds',
                style: _style(
                  size: DriverN02Metrics.brandSize,
                  weight: 900,
                  height: 1,
                  tracking: -1,
                ),
              ),
              Container(
                width: DriverN02Metrics.brandDotSize,
                height: DriverN02Metrics.brandDotSize,
                margin: const EdgeInsets.only(left: 3, bottom: 2),
                decoration: const BoxDecoration(
                  color: RoundsColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                key: const Key('n02-status-dot'),
                width: DriverN02Metrics.statusDotSize,
                height: DriverN02Metrics.statusDotSize,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: DriverN02Metrics.statusGap),
              Text(
                label,
                key: const Key('n02-status-label'),
                style: _style(
                  color: color,
                  size: DriverN02Metrics.statusSize,
                  weight: 840,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionBody extends StatelessWidget {
  const _ConnectionBody({
    required this.snapshot,
    required this.compact,
    required this.short,
    required this.onReturnToRound,
    required this.onRetry,
  });

  final DriverSyncSnapshot snapshot;
  final bool compact;
  final bool short;
  final VoidCallback onReturnToRound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final phase = snapshot.phase;
    final online = phase == DriverConnectionPhase.online;
    final reconnecting = phase == DriverConnectionPhase.reconnecting;
    final accent = online ? RoundsColors.green : RoundsColors.orange;
    final title = online
        ? 'Back online'
        : reconnecting
        ? 'Reconnecting'
        : 'You’re offline';
    final lead = online
        ? 'Saved work is synced. Your Round is current again.'
        : reconnecting
        ? 'Connection is back. Saved work is syncing now.'
        : snapshot.currentRouteAvailable
        ? 'Your current Round stays available. New work is saved on this phone until Rounds reconnects.'
        : 'New work is saved on this phone until Rounds reconnects.';

    final horizontal = compact
        ? DriverN02Metrics.compactMainPaddingHorizontal
        : DriverN02Metrics.mainPaddingHorizontal;
    final top = short
        ? DriverN02Metrics.shortMainPaddingTop
        : compact
        ? DriverN02Metrics.compactMainPaddingTop
        : DriverN02Metrics.mainPaddingTop;
    final iconSize = short
        ? DriverN02Metrics.shortIconSize
        : compact
        ? DriverN02Metrics.compactIconSize
        : DriverN02Metrics.iconSize;
    final iconGlyph = short
        ? DriverN02Metrics.shortIconGlyphSize
        : compact
        ? DriverN02Metrics.compactIconGlyphSize
        : DriverN02Metrics.iconGlyphSize;

    return LayoutBuilder(
      builder: (context, bodyConstraints) => SingleChildScrollView(
        key: const Key('n02-scroll'),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bodyConstraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              key: const Key('n02-main'),
              padding: EdgeInsets.fromLTRB(
                horizontal,
                top,
                horizontal,
                compact
                    ? DriverN02Metrics.compactMainPaddingBottom
                    : DriverN02Metrics.mainPaddingBottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONNECTION',
                    style: _style(
                      color: accent,
                      size: DriverN02Metrics.kickerSize,
                      weight: 900,
                      tracking: 1.14,
                    ),
                  ),
                  const SizedBox(height: DriverN02Metrics.kickerBottom),
                  Container(
                    key: const Key('n02-state-icon'),
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: RoundsColors.line),
                      borderRadius: BorderRadius.circular(
                        DriverN02Metrics.iconRadius,
                      ),
                    ),
                    child: Icon(
                      online
                          ? Icons.check
                          : reconnecting
                          ? Icons.sync
                          : Icons.wifi_off,
                      color: accent,
                      size: iconGlyph,
                    ),
                  ),
                  SizedBox(
                    height: short
                        ? DriverN02Metrics.shortIconBottom
                        : compact
                        ? DriverN02Metrics.compactIconBottom
                        : DriverN02Metrics.iconBottom,
                  ),
                  Text(
                    title,
                    key: const Key('n02-title'),
                    style: _style(
                      size: short
                          ? DriverN02Metrics.shortTitleSize
                          : compact
                          ? DriverN02Metrics.compactTitleSize
                          : DriverN02Metrics.titleSize,
                      height: DriverN02Metrics.titleHeight,
                      weight: 880,
                      tracking: -2.604,
                    ),
                  ),
                  SizedBox(
                    height: short
                        ? DriverN02Metrics.shortLeadTop
                        : compact
                        ? DriverN02Metrics.compactLeadTop
                        : DriverN02Metrics.leadTop,
                  ),
                  Text(
                    lead,
                    key: const Key('n02-lead'),
                    style: _style(
                      color: RoundsColors.inkSecondary,
                      size: short
                          ? DriverN02Metrics.shortLeadSize
                          : compact
                          ? DriverN02Metrics.compactLeadSize
                          : DriverN02Metrics.leadSize,
                      height: DriverN02Metrics.leadHeight,
                      weight: 650,
                    ),
                  ),
                  SizedBox(
                    height: short
                        ? DriverN02Metrics.shortTruthTop
                        : compact
                        ? DriverN02Metrics.compactTruthTop
                        : DriverN02Metrics.truthTop,
                  ),
                  _TruthLedger(
                    snapshot: snapshot,
                    compact: compact,
                    short: short,
                  ),
                  SizedBox(
                    height: short
                        ? DriverN02Metrics.shortSyncNoteTop
                        : compact
                        ? DriverN02Metrics.compactSyncNoteTop
                        : DriverN02Metrics.syncNoteTop,
                  ),
                  Text(
                    _syncNote(snapshot),
                    key: const Key('n02-sync-note'),
                    style: _style(
                      color: RoundsColors.muted,
                      size: compact
                          ? DriverN02Metrics.compactSyncNoteSize
                          : DriverN02Metrics.syncNoteSize,
                      height: DriverN02Metrics.syncNoteHeight,
                      weight: 700,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: short
                        ? DriverN02Metrics.shortPrimaryHeight
                        : compact
                        ? DriverN02Metrics.compactPrimaryHeight
                        : DriverN02Metrics.primaryHeight,
                    child: FilledButton(
                      key: const Key('n02-return'),
                      onPressed: onReturnToRound,
                      style: FilledButton.styleFrom(
                        backgroundColor: RoundsColors.ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DriverN02Metrics.primaryRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        'Return to Round',
                        style: _style(
                          color: Colors.white,
                          size: DriverN02Metrics.primarySize,
                          weight: 860,
                          tracking: -.34,
                        ),
                      ),
                    ),
                  ),
                  if (!online) ...[
                    const SizedBox(height: DriverN02Metrics.secondaryTop),
                    SizedBox(
                      width: double.infinity,
                      height: short
                          ? DriverN02Metrics.shortSecondaryHeight
                          : compact
                          ? DriverN02Metrics.compactSecondaryHeight
                          : DriverN02Metrics.secondaryHeight,
                      child: TextButton(
                        key: const Key('n02-retry'),
                        onPressed: reconnecting ? null : onRetry,
                        child: Text(
                          reconnecting
                              ? 'Checking connection…'
                              : 'Retry connection',
                          style: _style(
                            color: RoundsColors.muted,
                            size: DriverN02Metrics.secondarySize,
                            weight: 790,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TruthLedger extends StatelessWidget {
  const _TruthLedger({
    required this.snapshot,
    required this.compact,
    required this.short,
  });

  final DriverSyncSnapshot snapshot;
  final bool compact;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final syncing = snapshot.phase == DriverConnectionPhase.reconnecting;
    final online = snapshot.phase == DriverConnectionPhase.online;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: RoundsColors.line),
        ),
      ),
      child: Column(
        children: [
          _TruthRow(
            key: const Key('n02-route-row'),
            icon: Icons.route_outlined,
            title: 'Current route',
            subtitle: snapshot.currentRouteAvailable
                ? 'Last synced route stays available'
                : 'No route is cached on this phone',
            state: snapshot.currentRouteAvailable ? 'Available' : 'Unavailable',
            good: snapshot.currentRouteAvailable,
            compact: compact,
            short: short,
          ),
          _TruthRow(
            key: const Key('n02-proof-row'),
            icon: Icons.image_outlined,
            title: 'Proof & status',
            subtitle: _pendingCopy(
              snapshot.pendingProofAndStatusCount,
              syncing: syncing,
              kind: 'proof or status item',
            ),
            state: _pendingState(
              snapshot.pendingProofAndStatusCount,
              syncing: syncing,
              online: online,
            ),
            good: online && snapshot.pendingProofAndStatusCount == 0,
            local: snapshot.pendingProofAndStatusCount > 0,
            compact: compact,
            short: short,
          ),
          _TruthRow(
            key: const Key('n02-message-row'),
            icon: Icons.chat_bubble_outline,
            title: 'Messages',
            subtitle: _pendingCopy(
              snapshot.pendingMessageCount,
              syncing: syncing,
              kind: 'message',
            ),
            state: _pendingState(
              snapshot.pendingMessageCount,
              syncing: syncing,
              online: online,
            ),
            good: online && snapshot.pendingMessageCount == 0,
            local: snapshot.pendingMessageCount > 0,
            compact: compact,
            short: short,
          ),
        ],
      ),
    );
  }
}

class _TruthRow extends StatelessWidget {
  const _TruthRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.good,
    required this.compact,
    required this.short,
    this.local = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String state;
  final bool good;
  final bool local;
  final bool compact;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final rowHeight = short
        ? DriverN02Metrics.shortTruthRowMinHeight
        : compact
        ? DriverN02Metrics.compactTruthRowMinHeight
        : DriverN02Metrics.truthRowMinHeight;
    return Container(
      constraints: BoxConstraints(minHeight: rowHeight),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: compact
                ? DriverN02Metrics.compactTruthIconSize
                : DriverN02Metrics.truthIconSize,
            child: Icon(
              icon,
              size: DriverN02Metrics.truthIconGlyphSize,
              color: RoundsColors.green,
            ),
          ),
          SizedBox(
            width: compact
                ? DriverN02Metrics.compactTruthGap
                : DriverN02Metrics.truthGap,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _style(
                    color: RoundsColors.inkSecondary,
                    size: compact
                        ? DriverN02Metrics.compactTruthTitleSize
                        : DriverN02Metrics.truthTitleSize,
                    height: 1.2,
                    weight: 830,
                  ),
                ),
                SizedBox(height: short ? 2 : DriverN02Metrics.truthSubtitleTop),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _style(
                    color: RoundsColors.muted,
                    size: compact
                        ? DriverN02Metrics.compactTruthSubtitleSize
                        : DriverN02Metrics.truthSubtitleSize,
                    height: DriverN02Metrics.truthSubtitleHeight,
                    weight: 680,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state,
            style: _style(
              color: good
                  ? RoundsColors.green
                  : local
                  ? RoundsColors.orange
                  : RoundsColors.muted,
              size: compact
                  ? DriverN02Metrics.compactTruthStateSize
                  : DriverN02Metrics.truthStateSize,
              weight: 820,
            ),
          ),
        ],
      ),
    );
  }
}

String _pendingCopy(int count, {required bool syncing, required String kind}) {
  if (count == 0) return 'Nothing waiting on this phone';
  final noun = count == 1 ? kind : '${kind}s';
  return syncing
      ? 'Syncing $count $noun to Rounds'
      : '$count $noun saved on this phone';
}

String _pendingState(int count, {required bool syncing, required bool online}) {
  if (count == 0) return online ? 'Synced' : 'Clear';
  return syncing ? 'Syncing' : 'Local';
}

String _syncNote(DriverSyncSnapshot snapshot) {
  if (snapshot.phase == DriverConnectionPhase.online && snapshot.fullySynced) {
    return 'All locally saved work is now on Rounds.';
  }
  if (snapshot.phase == DriverConnectionPhase.reconnecting) {
    return 'Keep working. Rounds will confirm when everything is synced.';
  }
  final value = snapshot.lastSyncedAt?.toLocal();
  if (value == null) return 'Rounds will reconnect automatically.';
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return 'Last synced $hour:$minute · Rounds will reconnect automatically.';
}

TextStyle _style({
  Color color = RoundsColors.ink,
  required double size,
  required double weight,
  double? height,
  double? tracking,
}) => TextStyle(
  color: color,
  fontSize: size,
  fontWeight: FontWeight.lerp(FontWeight.w100, FontWeight.w900, weight / 900),
  height: height,
  letterSpacing: tracking,
);
