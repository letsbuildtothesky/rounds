import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_handoff_selection.dart';
import '../driver/driver_session.dart';
import 'call_contact_screen.dart';
import 'operations_chat_screen.dart';
import 'proof_of_delivery_screen.dart';
import 'recipient_unavailable_screen.dart';

typedef HandoffPodBuilder = Widget Function(DriverHandoffSelection selection);

class DropoffHandoffScreen extends StatelessWidget {
  const DropoffHandoffScreen({
    required this.controller,
    required this.round,
    required this.stop,
    required this.stopCount,
    this.podBuilder,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final int stopCount;
  final HandoffPodBuilder? podBuilder;

  bool get _thai => controller.strings.isThai;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < DriverReferenceViewport.compactBreakpoint;
    final short = size.height <= DriverF01F02Metrics.shortBreakpointHeight;
    final horizontal = compact
        ? DriverF01F02Metrics.compactContentPaddingHorizontal
        : DriverF01F02Metrics.contentPaddingHorizontal;
    final top = short
        ? (_thai
              ? DriverF01F02Metrics.thaiShortContentPaddingTop
              : DriverF01F02Metrics.englishShortContentPaddingTop)
        : compact
        ? (_thai
              ? DriverF01F02Metrics.thaiCompactContentPaddingTop
              : DriverF01F02Metrics.englishCompactContentPaddingTop)
        : (_thai
              ? DriverF01F02Metrics.thaiContentPaddingTop
              : DriverF01F02Metrics.englishContentPaddingTop);
    final heroSize = compact
        ? (_thai
              ? DriverF01F02Metrics.thaiCompactHeroSize
              : DriverF01F02Metrics.englishCompactHeroSize)
        : (_thai
              ? DriverF01F02Metrics.thaiHeroSize
              : DriverF01F02Metrics.englishHeroSize);

    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              thai: _thai,
              sequence: stop.sequence,
              stopCount: stopCount,
              recipientName: stop.recipientName,
              compact: compact,
            ),
            Expanded(
              child: ListView(
                key: const Key('handoff-content'),
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  top,
                  horizontal,
                  _thai
                      ? DriverF01F02Metrics.thaiContentPaddingBottom
                      : DriverF01F02Metrics.englishContentPaddingBottom,
                ),
                children: [
                  Container(
                    padding: EdgeInsets.only(
                      bottom: short
                          ? DriverF01F02Metrics.shortHeroPaddingBottom
                          : _thai
                          ? DriverF01F02Metrics.thaiHeroPaddingBottom
                          : DriverF01F02Metrics.englishHeroPaddingBottom,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: RoundsColors.line),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _thai ? 'ใครรับของ?' : 'Who received it?',
                          key: const Key('handoff-title'),
                          style: TextStyle(
                            color: RoundsColors.ink,
                            fontSize: heroSize,
                            height: _thai ? 1.18 : .98,
                            fontWeight: _thai
                                ? FontWeight.w800
                                : FontWeight.w900,
                            letterSpacing: _thai ? 0 : -1.75,
                          ),
                        ),
                        SizedBox(
                          height: _thai
                              ? DriverF01F02Metrics.thaiPlaceGap
                              : DriverF01F02Metrics.englishPlaceGap,
                        ),
                        _AddressLine(address: stop.rawAddress),
                      ],
                    ),
                  ),
                  _PackageLine(stop: stop, thai: _thai, compact: compact),
                  SizedBox(
                    height: short
                        ? DriverF01F02Metrics.shortSectionMarginTop
                        : compact
                        ? DriverF01F02Metrics.compactSectionMarginTop
                        : (_thai
                              ? DriverF01F02Metrics.thaiSectionMarginTop
                              : DriverF01F02Metrics.englishSectionMarginTop),
                  ),
                  Text(
                    _thai ? 'ส่งมอบให้' : 'HANDOFF',
                    style: TextStyle(
                      color: RoundsColors.muted,
                      fontSize: _thai ? 11.8 : 11,
                      height: _thai ? 1.4 : 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: _thai ? 0 : .88,
                    ),
                  ),
                  SizedBox(
                    height: _thai
                        ? DriverF01F02Metrics.thaiSectionMarginBottom
                        : DriverF01F02Metrics.englishSectionMarginBottom,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: RoundsColors.line)),
                    ),
                    child: Column(
                      children: [
                        _Choice(
                          key: const Key('handoff-recipient'),
                          title: _thai ? 'ผู้รับ' : 'Recipient',
                          subtitle: stop.recipientName,
                          thai: _thai,
                          compact: compact,
                          short: short,
                          onTap: () => _openPod(
                            context,
                            const DriverHandoffSelection.recipient(),
                          ),
                        ),
                        _Choice(
                          key: const Key('handoff-someone-else'),
                          title: _thai ? 'คนอื่นรับแทน' : 'Someone else',
                          subtitle: _thai
                              ? 'รีเซปชัน · รปภ. · ครอบครัว · พนักงาน'
                              : 'Reception · Security · Family · Staff',
                          thai: _thai,
                          compact: compact,
                          short: short,
                          onTap: () => _openPod(
                            context,
                            const DriverHandoffSelection.someoneElse(),
                          ),
                        ),
                        _Choice(
                          key: const Key('handoff-left-at-location'),
                          title: _thai ? 'วางไว้ที่จุดส่ง' : 'Left at location',
                          subtitle: _thai
                              ? 'เฉพาะเมื่อมีคำสั่ง'
                              : 'Only when instructed',
                          thai: _thai,
                          compact: compact,
                          short: short,
                          warning: true,
                          onTap: () => _chooseLeftLocation(context),
                        ),
                      ],
                    ),
                  ),
                  _ContactBlock(
                    thai: _thai,
                    compact: compact,
                    short: short,
                    onCall: () => _callRecipient(context),
                    onMessage: () => _messageOperations(context),
                    onUnavailable: () => _recipientUnavailable(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPod(
    BuildContext context,
    DriverHandoffSelection selection,
  ) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            podBuilder?.call(selection) ??
            ProofOfDeliveryScreen(
              controller: controller,
              stop: stop,
              handoff: selection,
            ),
      ),
    );
    if (completed == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _chooseLeftLocation(BuildContext context) async {
    final location = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: RoundsColors.ink.withValues(alpha: .28),
      builder: (_) => _LeftLocationSheet(thai: _thai),
    );
    if (location != null && context.mounted) {
      await _openPod(context, DriverHandoffSelection.leftAt(location));
    }
  }

  Future<void> _callRecipient(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CallContactScreen(
            controller: controller,
            round: round,
            stop: stop,
            target: CallContactTarget.recipient,
          ),
        ),
      );

  Future<void> _messageOperations(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => OperationsChatScreen(
            controller: controller,
            round: round,
            stop: stop,
          ),
        ),
      );

  Future<void> _recipientUnavailable(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RecipientUnavailableScreen(
            controller: controller,
            round: round,
            stop: stop,
            launcher: (uri) =>
                launchUrl(uri, mode: LaunchMode.externalApplication),
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.thai,
    required this.sequence,
    required this.stopCount,
    required this.recipientName,
    required this.compact,
  });

  final bool thai;
  final int sequence;
  final int stopCount;
  final String recipientName;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('handoff-top-bar'),
    height: thai
        ? (compact
              ? DriverF01F02Metrics.thaiCompactTopBarHeight
              : DriverF01F02Metrics.thaiTopBarHeight)
        : DriverF01F02Metrics.englishTopBarHeight,
    padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 42,
          child: OutlinedButton(
            key: const Key('handoff-back'),
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: RoundsColors.ink,
              side: const BorderSide(color: RoundsColors.lineStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RoundsRadii.small),
              ),
            ),
            child: const Icon(Icons.arrow_back, size: 21),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                thai ? 'ถึงจุด $sequence' : 'AT STOP $sequence',
                style: TextStyle(
                  color: RoundsColors.orange,
                  fontSize: thai ? 11.8 : 11,
                  height: thai ? 1.4 : 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: thai ? 0 : .88,
                ),
              ),
              SizedBox(height: thai ? 2 : 4),
              Text(
                recipientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: thai ? 48 : 42,
          child: Text(
            thai ? '$sequence จาก $stopCount' : '$sequence of $stopCount',
            maxLines: 1,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: RoundsColors.muted,
              fontSize: 12.5,
              height: thai ? 1.4 : 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.address});
  final String address;

  @override
  Widget build(BuildContext context) {
    final parts = address.split(',');
    final place = parts.first.trim();
    final remainder = parts.skip(1).map((part) => part.trim()).join(', ');
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: place,
            style: const TextStyle(
              color: RoundsColors.inkSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (remainder.isNotEmpty) TextSpan(text: ' · $remainder'),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: RoundsColors.muted,
        fontSize: 13.5,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PackageLine extends StatelessWidget {
  const _PackageLine({
    required this.stop,
    required this.thai,
    required this.compact,
  });
  final DriverRoundStopModel stop;
  final bool thai;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final count = stop.manifestItems.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
    final description = stop.manifestItems
        .map((item) => item.description)
        .where((value) => value.trim().isNotEmpty)
        .join(' + ');
    final handling = stop.manifestItems
        .map((item) => item.handlingNote?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    return Container(
      key: const Key('handoff-package-line'),
      constraints: BoxConstraints(
        minHeight: compact
            ? DriverF01F02Metrics.compactPackageMinHeight
            : thai
            ? DriverF01F02Metrics.thaiPackageMinHeight
            : DriverF01F02Metrics.englishPackageMinHeight,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: RoundsColors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description.isEmpty ? stop.deliveryReference : description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: compact ? 12.8 : 13.5,
                    height: thai ? 1.4 : 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  thai
                      ? '$count แพ็กเกจ'
                      : '$count ${count == 1 ? 'package' : 'packages'}',
                  style: TextStyle(
                    color: RoundsColors.muted,
                    fontSize: compact ? 11 : 11.8,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (handling != null) ...[
            const SizedBox(width: 10),
            Text(
              handling,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: RoundsColors.orange,
                fontSize: compact ? 11 : 11.8,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.subtitle,
    required this.thai,
    required this.compact,
    required this.short,
    required this.onTap,
    this.warning = false,
    super.key,
  });
  final String title;
  final String subtitle;
  final bool thai;
  final bool compact;
  final bool short;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: BoxConstraints(
        minHeight: short
            ? DriverF01F02Metrics.shortChoiceMinHeight
            : compact
            ? (thai
                  ? DriverF01F02Metrics.thaiCompactChoiceMinHeight
                  : DriverF01F02Metrics.englishCompactChoiceMinHeight)
            : (thai
                  ? DriverF01F02Metrics.thaiChoiceMinHeight
                  : DriverF01F02Metrics.englishChoiceMinHeight),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 2,
        vertical: short
            ? 8
            : compact
            ? 10
            : thai
            ? 12
            : 14,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: compact ? (thai ? 17 : 17.5) : 19,
                    height: thai ? 1.35 : 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: thai ? 0 : -.45,
                  ),
                ),
                SizedBox(height: thai ? 4 : 7),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: warning
                        ? const Color(0xFF8E6A48)
                        : RoundsColors.muted,
                    fontSize: compact ? (thai ? 11.5 : 11.8) : 12.5,
                    height: thai ? 1.45 : 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              Icons.chevron_right,
              size: 22,
              color: Color(0xFF8B96A4),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContactBlock extends StatelessWidget {
  const _ContactBlock({
    required this.thai,
    required this.compact,
    required this.short,
    required this.onCall,
    required this.onMessage,
    required this.onUnavailable,
  });
  final bool thai;
  final bool compact;
  final bool short;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) {
    final top = short
        ? DriverF01F02Metrics.shortContactMarginTop
        : compact
        ? DriverF01F02Metrics.compactContactMarginTop
        : thai
        ? DriverF01F02Metrics.thaiContactMarginTop
        : DriverF01F02Metrics.englishContactMarginTop;
    final paddingTop = short
        ? DriverF01F02Metrics.shortContactPaddingTop
        : compact
        ? DriverF01F02Metrics.compactContactPaddingTop
        : thai
        ? DriverF01F02Metrics.thaiContactPaddingTop
        : DriverF01F02Metrics.englishContactPaddingTop;
    final height = compact ? 50.0 : 54.0;
    return Container(
      key: const Key('handoff-contact-block'),
      margin: EdgeInsets.only(top: top),
      padding: EdgeInsets.only(top: paddingTop),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            thai ? 'ติดต่อ' : 'NEED CONTACT',
            style: TextStyle(
              color: RoundsColors.muted,
              fontSize: thai ? 11.8 : 11,
              height: thai ? 1.4 : 1,
              fontWeight: FontWeight.w800,
              letterSpacing: thai ? 0 : .88,
            ),
          ),
          SizedBox(height: thai ? 8 : 10),
          Row(
            children: [
              Expanded(
                child: _ContactButton(
                  key: const Key('handoff-call-recipient'),
                  height: height,
                  compact: compact,
                  icon: Icons.phone_outlined,
                  label: thai ? 'โทรหาผู้รับ' : 'Call recipient',
                  onPressed: onCall,
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
              Expanded(
                child: _ContactButton(
                  key: const Key('handoff-message-ops'),
                  height: height,
                  compact: compact,
                  icon: Icons.chat_bubble_outline,
                  label: thai ? 'แชตฝ่ายจัดงาน' : 'Message Ops',
                  onPressed: onMessage,
                ),
              ),
            ],
          ),
          SizedBox(height: thai ? 6 : 8),
          SizedBox(
            height: short
                ? 40
                : compact
                ? 43
                : thai
                ? 46
                : 48,
            child: TextButton(
              key: const Key('handoff-recipient-unavailable'),
              onPressed: onUnavailable,
              style: TextButton.styleFrom(
                foregroundColor: RoundsColors.red,
                textStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: compact
                      ? 12
                      : thai
                      ? 12.8
                      : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(
                thai ? 'ติดต่อผู้รับไม่ได้' : 'Recipient unavailable',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.height,
    required this.compact,
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });
  final double height;
  final bool compact;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: RoundsColors.inkSecondary,
        side: const BorderSide(color: RoundsColors.lineStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RoundsRadii.small),
        ),
        textStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: compact ? 11.7 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: compact ? 16 : 18),
          SizedBox(width: compact ? 5 : 7),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
  );
}

class _LeftLocationSheet extends StatelessWidget {
  const _LeftLocationSheet({required this.thai});
  final bool thai;

  @override
  Widget build(BuildContext context) {
    final actions = <(String, String)>[
      ('reception', thai ? 'รีเซปชัน' : 'Reception'),
      ('lobby', thai ? 'ล็อบบี้ / ทางเข้า' : 'Lobby / entrance'),
      ('door', thai ? 'หน้าประตู' : 'At the door'),
      ('safe', thai ? 'จุดอื่นที่อนุมัติ' : 'Other approved place'),
    ];
    return Material(
      key: const Key('left-location-drawer'),
      color: RoundsColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RoundsRadii.large),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: RoundsColors.lineStrong,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  thai ? 'วางไว้ที่จุดส่ง' : 'Left at location',
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: 22,
                    height: thai ? 1.35 : 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: thai ? 0 : -.85,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: RoundsColors.line)),
                  ),
                  child: Column(
                    children: [
                      for (final action in actions)
                        InkWell(
                          key: Key('left-location-${action.$1}'),
                          onTap: () => Navigator.of(context).pop(action.$2),
                          child: Container(
                            constraints: BoxConstraints(
                              minHeight: thai ? 60 : 58,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: RoundsColors.line),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    action.$2,
                                    style: const TextStyle(
                                      color: RoundsColors.ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Text(
                                  '›',
                                  style: TextStyle(
                                    color: RoundsColors.muted,
                                    fontSize: 19,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: TextButton(
                    key: const Key('left-location-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: RoundsColors.muted,
                      textStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(thai ? 'ยกเลิก' : 'Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
