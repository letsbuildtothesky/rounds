import 'package:flutter/material.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import 'components/operations_contact_flow.dart';
import 'components/rounds_action_drawer.dart';
import 'location_problem_screen.dart';
import 'operations_chat_screen.dart';

typedef RecipientUnavailableLauncher = Future<bool> Function(Uri uri);

class RecipientUnavailableScreen extends StatefulWidget {
  const RecipientUnavailableScreen({
    required this.controller,
    required this.round,
    required this.stop,
    required this.launcher,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final RecipientUnavailableLauncher launcher;

  @override
  State<RecipientUnavailableScreen> createState() =>
      _RecipientUnavailableScreenState();
}

class _RecipientUnavailableScreenState
    extends State<RecipientUnavailableScreen> {
  late List<DriverContactAttemptModel> _attempts;
  bool _submitting = false;

  List<DriverContactAttemptModel> get _recipientAttempts => _attempts
      .where((attempt) => attempt.target == 'recipient')
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _attempts = widget.stop.contactAttempts.toList(growable: true);
    _loadPending();
  }

  Future<void> _loadPending() async {
    final pending = await widget.controller.pendingContactAttempts(widget.stop);
    if (!mounted) return;
    setState(() => _replaceAttempts([..._attempts, ...pending]));
  }

  void _replaceAttempts(List<DriverContactAttemptModel> attempts) {
    final byId = <String, DriverContactAttemptModel>{
      for (final attempt in attempts) attempt.id: attempt,
    };
    _attempts = byId.values.toList(growable: true)
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  }

  Future<void> _primaryAction() async {
    if (_recipientAttempts.length >= 2) {
      await _contactOperations();
      return;
    }
    await _callRecipient();
  }

  Future<void> _callRecipient() async {
    final phone = widget.stop.recipientPhone.trim();
    final opened =
        phone.isNotEmpty &&
        await widget.launcher(Uri(scheme: 'tel', path: phone));
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The phone app could not be opened.')),
      );
      return;
    }
    final outcome = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: RoundsColors.ink.withValues(alpha: .28),
      builder: (context) => const _RecipientOutcomeSheet(),
    );
    if (outcome != null && mounted) await _recordOutcome(outcome);
  }

  Future<void> _recordOutcome(String outcome) async {
    setState(() => _submitting = true);
    try {
      final command = await widget.controller.logContactAttempt(
        stop: widget.stop,
        target: 'recipient',
        outcome: outcome,
      );
      if (!mounted) return;
      if (command == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.controller.driverError ?? 'Call outcome was not saved.',
            ),
          ),
        );
        return;
      }

      final refreshed = widget.controller.driverSession?.currentRound?.stops
          .where((stop) => stop.id == widget.stop.id)
          .firstOrNull;
      if (refreshed != null) {
        final pending = await widget.controller.pendingContactAttempts(
          refreshed,
        );
        if (!mounted) return;
        setState(
          () => _replaceAttempts([...refreshed.contactAttempts, ...pending]),
        );
      } else {
        setState(
          () => _replaceAttempts([
            ..._attempts,
            DriverContactAttemptModel(
              id: 'local-${DateTime.now().microsecondsSinceEpoch}',
              target: 'recipient',
              channel: 'native_phone',
              outcome: outcome,
              occurredAt: DateTime.now().toUtc(),
              savedLocally: command.pendingSync,
            ),
          ]),
        );
      }

      if (outcome == 'reached') {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              command.committed
                  ? 'Call attempt recorded.'
                  : 'Call attempt saved on this phone and waiting to sync.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _contactOperations() => openOperationsContactFlow(
    context,
    round: widget.round,
    stop: widget.stop,
    controller: widget.controller,
    launcher: widget.launcher,
    onMessage: _openOperationsChat,
  );

  Future<void> _openOperationsChat() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => OperationsChatScreen(
        controller: widget.controller,
        round: widget.round,
        stop: widget.stop,
      ),
    ),
  );

  Future<void> _openMore() async {
    final action = await showRoundsActionDrawer(
      context,
      title: 'Stop actions',
      actions: const [
        RoundsDrawerAction(
          value: 'message',
          label: 'Message Operations',
          icon: Icons.chat_bubble_outline,
        ),
        RoundsDrawerAction(
          value: 'address',
          label: 'Address / entrance problem',
          icon: Icons.location_on_outlined,
        ),
        RoundsDrawerAction(
          value: 'another',
          label: 'Report another issue',
          icon: Icons.report_problem_outlined,
          destructive: true,
        ),
      ],
      showCancel: false,
    );
    if (!mounted || action == null) return;
    if (action == 'message') await _openOperationsChat();
    if (action == 'address' && mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => LocationProblemScreen(
            controller: widget.controller,
            round: widget.round,
            stop: widget.stop,
            problemContext: LocationProblemContext.delivery,
            launcher: widget.launcher,
          ),
        ),
      );
    }
    if (action == 'another' && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final attempts = _recipientAttempts;
    final item = widget.stop.manifestItems.firstOrNull;
    final primaryLabel = attempts.length >= 2
        ? 'Contact Operations'
        : attempts.isEmpty
        ? 'Call recipient'
        : 'Call recipient again';
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              key: const Key('recipient-unavailable-topbar'),
              height: DriverG01Metrics.topBarHeight,
              padding: const EdgeInsets.symmetric(
                horizontal: DriverG01Metrics.topBarPaddingHorizontal,
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: RoundsColors.line)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: DriverG01Metrics.topButtonSize,
                    height: DriverG01Metrics.topButtonSize,
                    child: IconButton(
                      key: const Key('recipient-unavailable-back'),
                      onPressed: () => Navigator.of(context).pop(false),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back,
                        size: DriverG01Metrics.topIconSize,
                      ),
                    ),
                  ),
                  const SizedBox(width: DriverG01Metrics.topColumnGap),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STOP ${widget.stop.sequence} OF ${widget.round.stops.length}',
                          style: const TextStyle(
                            color: RoundsColors.muted,
                            fontSize: DriverG01Metrics.topEyebrowSize,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: DriverG01Metrics.topEyebrowTracking,
                          ),
                        ),
                        const SizedBox(height: DriverG01Metrics.topTitleGap),
                        Text(
                          widget.stop.recipientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: RoundsColors.ink,
                            fontSize: DriverG01Metrics.topTitleSize,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.42,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: DriverG01Metrics.topButtonSize,
                    height: DriverG01Metrics.topButtonSize,
                    child: IconButton(
                      key: const Key('recipient-unavailable-more'),
                      onPressed: _openMore,
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_horiz,
                        size: DriverG01Metrics.topIconSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DriverG01Metrics.contentPaddingHorizontal,
                  DriverG01Metrics.contentPaddingTop,
                  DriverG01Metrics.contentPaddingHorizontal,
                  DriverG01Metrics.contentPaddingBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _IssueKicker(),
                    const SizedBox(height: DriverG01Metrics.heroGap),
                    const Text(
                      'Recipient unavailable',
                      key: Key('recipient-unavailable-title'),
                      style: TextStyle(
                        color: RoundsColors.ink,
                        fontSize: DriverG01Metrics.heroSize,
                        height: DriverG01Metrics.heroHeight,
                        fontWeight: FontWeight.w900,
                        letterSpacing: DriverG01Metrics.heroTracking,
                      ),
                    ),
                    const SizedBox(height: DriverG01Metrics.locationGap),
                    Text(
                      widget.stop.rawAddress,
                      style: const TextStyle(
                        color: RoundsColors.muted,
                        fontSize: DriverG01Metrics.locationSize,
                        height: DriverG01Metrics.locationHeight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(
                        top: DriverG01Metrics.recipientMarginTop,
                      ),
                      padding: const EdgeInsets.only(
                        top: DriverG01Metrics.recipientPaddingTop,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: RoundsColors.line),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CURRENT STOP',
                                  style: TextStyle(
                                    color: RoundsColors.orange,
                                    fontSize:
                                        DriverG01Metrics.recipientEyebrowSize,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: DriverG01Metrics
                                        .recipientEyebrowTracking,
                                  ),
                                ),
                                const SizedBox(
                                  height:
                                      DriverG01Metrics.recipientEyebrowBottom,
                                ),
                                Text(
                                  widget.stop.recipientName,
                                  style: const TextStyle(
                                    color: RoundsColors.ink,
                                    fontSize:
                                        DriverG01Metrics.recipientNameSize,
                                    height:
                                        DriverG01Metrics.recipientNameHeight,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing:
                                        DriverG01Metrics.recipientNameTracking,
                                  ),
                                ),
                                if (widget.stop.accessNote?.trim().isNotEmpty ==
                                    true) ...[
                                  const SizedBox(
                                    height: DriverG01Metrics.recipientNoteGap,
                                  ),
                                  Text(
                                    widget.stop.accessNote!,
                                    style: const TextStyle(
                                      color: RoundsColors.muted,
                                      fontSize:
                                          DriverG01Metrics.recipientNoteSize,
                                      height:
                                          DriverG01Metrics.recipientNoteHeight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (item != null) ...[
                            const SizedBox(
                              width: DriverG01Metrics.recipientColumnGap,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                top: DriverG01Metrics.itemPaddingTop,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: DriverG01Metrics.itemDotSize,
                                    height: DriverG01Metrics.itemDotSize,
                                    decoration: const BoxDecoration(
                                      color: RoundsColors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: DriverG01Metrics.itemDotGap,
                                  ),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 120,
                                    ),
                                    child: Text(
                                      '${item.quantity}× ${item.description}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: RoundsColors.inkSecondary,
                                        fontSize: DriverG01Metrics.itemSize,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: DriverG01Metrics.sectionGap),
                    const Text(
                      'CONTACT ATTEMPTS',
                      style: TextStyle(
                        color: RoundsColors.muted,
                        fontSize: DriverG01Metrics.ledgerTitleSize,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: DriverG01Metrics.ledgerTitleTracking,
                      ),
                    ),
                    const SizedBox(height: DriverG01Metrics.ledgerTitleBottom),
                    _AttemptLedger(attempts: attempts),
                  ],
                ),
              ),
            ),
            Container(
              key: const Key('recipient-unavailable-footer'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                DriverG01Metrics.footerPaddingHorizontal,
                DriverG01Metrics.footerPaddingTop,
                DriverG01Metrics.footerPaddingHorizontal,
                DriverG01Metrics.footerPaddingBottom,
              ),
              decoration: const BoxDecoration(
                color: RoundsColors.surface,
                border: Border(top: BorderSide(color: RoundsColors.line)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: DriverG01Metrics.primaryHeight,
                    child: FilledButton(
                      key: const Key('recipient-unavailable-primary'),
                      onPressed: _submitting ? null : _primaryAction,
                      child: Text(
                        _submitting ? 'Saving attempt…' : primaryLabel,
                      ),
                    ),
                  ),
                  if (attempts.length < 2) ...[
                    const SizedBox(height: DriverG01Metrics.secondaryGap),
                    SizedBox(
                      width: double.infinity,
                      height: DriverG01Metrics.secondaryHeight,
                      child: TextButton(
                        key: const Key('recipient-unavailable-operations'),
                        onPressed: _submitting ? null : _contactOperations,
                        child: const Text('Contact Operations'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueKicker extends StatelessWidget {
  const _IssueKicker();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: DriverG01Metrics.issueDotSize,
        height: DriverG01Metrics.issueDotSize,
        decoration: const BoxDecoration(
          color: RoundsColors.red,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: DriverG01Metrics.issueGap),
      const Text(
        'DELIVERY PROBLEM',
        style: TextStyle(
          color: RoundsColors.red,
          fontSize: DriverG01Metrics.issueSize,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG01Metrics.issueTracking,
        ),
      ),
    ],
  );
}

class _AttemptLedger extends StatelessWidget {
  const _AttemptLedger({required this.attempts});

  final List<DriverContactAttemptModel> attempts;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('recipient-unavailable-ledger'),
    decoration: const BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: RoundsColors.line),
      ),
    ),
    child: attempts.isEmpty
        ? const SizedBox(
            height: DriverG01Metrics.ledgerEmptyHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No attempts yet',
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        : Column(
            children: [
              for (var index = 0; index < attempts.length; index++)
                Container(
                  key: Key('recipient-attempt-$index'),
                  constraints: const BoxConstraints(
                    minHeight: DriverG01Metrics.ledgerRowHeight,
                  ),
                  decoration: BoxDecoration(
                    border: index == 0
                        ? null
                        : const Border(
                            top: BorderSide(color: RoundsColors.line),
                          ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: DriverG01Metrics.ledgerTimeColumnWidth,
                        child: Text(
                          _formatTime(attempts[index].occurredAt),
                          style: const TextStyle(
                            color: RoundsColors.muted,
                            fontSize: DriverG01Metrics.ledgerTimeSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Recipient call',
                          style: TextStyle(
                            color: RoundsColors.ink,
                            fontSize: DriverG01Metrics.ledgerRowTitleSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        _outcomeLabel(attempts[index]),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: attempts[index].outcome == 'reached'
                              ? RoundsColors.green
                              : RoundsColors.red,
                          fontSize: DriverG01Metrics.ledgerOutcomeSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

class _RecipientOutcomeSheet extends StatelessWidget {
  const _RecipientOutcomeSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: RoundsColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DriverG01Metrics.sheetRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DriverG01Metrics.sheetPaddingHorizontal,
          DriverG01Metrics.sheetPaddingTop,
          DriverG01Metrics.sheetPaddingHorizontal,
          DriverG01Metrics.sheetPaddingBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: DriverG01Metrics.sheetHandleWidth,
                height: DriverG01Metrics.sheetHandleHeight,
                decoration: BoxDecoration(
                  color: RoundsColors.lineStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: DriverG01Metrics.sheetHandleBottom),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Call outcome',
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverG01Metrics.sheetTitleSize,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.77,
                ),
              ),
            ),
            const SizedBox(height: DriverG01Metrics.sheetTitleBottom),
            const _OutcomeRow(
              value: 'reached',
              label: 'Reached recipient',
              detail: 'Return to handoff',
            ),
            const _OutcomeRow(
              value: 'no_answer',
              label: 'No answer',
              detail: 'Record attempt',
            ),
            const _OutcomeRow(
              value: 'busy',
              label: 'Busy / declined',
              detail: 'Record attempt',
            ),
          ],
        ),
      ),
    ),
  );
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({
    required this.value,
    required this.label,
    required this.detail,
  });

  final String value;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('recipient-outcome-$value'),
    onTap: () => Navigator.of(context).pop(value),
    child: Container(
      height: DriverG01Metrics.sheetRowHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: DriverG01Metrics.sheetRowPaddingHorizontal,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: RoundsColors.ink,
                fontSize: DriverG01Metrics.sheetRowSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            detail,
            style: const TextStyle(
              color: RoundsColors.muted,
              fontSize: DriverG01Metrics.sheetDetailSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _outcomeLabel(DriverContactAttemptModel attempt) {
  final label = switch (attempt.outcome) {
    'reached' => 'Reached',
    'no_answer' => 'No answer',
    'busy' => 'Busy / declined',
    'call_failed' => 'Call failed',
    _ => attempt.outcome,
  };
  return attempt.savedLocally ? '$label · saved' : label;
}
