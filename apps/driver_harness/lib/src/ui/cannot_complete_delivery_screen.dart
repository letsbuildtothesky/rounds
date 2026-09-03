import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import 'operations_chat_screen.dart';

typedef CannotCompleteLauncher = Future<bool> Function(Uri uri);

enum _CannotCompleteState { choose, action, waiting }

enum _CannotCompleteReason { access, refused, closed, other }

extension on _CannotCompleteReason {
  String get title => switch (this) {
    _CannotCompleteReason.access => 'No access',
    _CannotCompleteReason.refused => 'Delivery refused',
    _CannotCompleteReason.closed => 'Location closed',
    _CannotCompleteReason.other => 'Other',
  };

  String get detail => switch (this) {
    _CannotCompleteReason.access => 'Security, gate or building access',
    _CannotCompleteReason.refused => 'Recipient or location will not accept it',
    _CannotCompleteReason.closed => 'Office, store or venue is closed',
    _CannotCompleteReason.other => 'Another reason prevents delivery',
  };

  IconData get icon => switch (this) {
    _CannotCompleteReason.access => Icons.door_front_door_outlined,
    _CannotCompleteReason.refused => Icons.block_outlined,
    _CannotCompleteReason.closed => Icons.storefront_outlined,
    _CannotCompleteReason.other => Icons.more_horiz,
  };

  bool get callFirst =>
      this == _CannotCompleteReason.access ||
      this == _CannotCompleteReason.closed;

  String get code => switch (this) {
    _CannotCompleteReason.access => 'no_access',
    _CannotCompleteReason.refused => 'delivery_refused',
    _CannotCompleteReason.closed => 'location_closed',
    _CannotCompleteReason.other => 'other',
  };
}

class CannotCompleteDeliveryScreen extends StatefulWidget {
  const CannotCompleteDeliveryScreen({
    required this.controller,
    required this.round,
    required this.stop,
    this.initialNote = '',
    this.launcher = _launchExternal,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final String initialNote;
  final CannotCompleteLauncher launcher;

  @override
  State<CannotCompleteDeliveryScreen> createState() =>
      _CannotCompleteDeliveryScreenState();
}

class _CannotCompleteDeliveryScreenState
    extends State<CannotCompleteDeliveryScreen> {
  _CannotCompleteState _state = _CannotCompleteState.choose;
  _CannotCompleteReason? _reason;
  String _note = '';
  bool _submitting = false;
  bool _messagePendingSync = false;
  late List<DriverContactAttemptModel> _attempts;

  @override
  void initState() {
    super.initState();
    _note = widget.initialNote.trim();
    _attempts = widget.stop.contactAttempts
        .where((attempt) => attempt.target == 'recipient')
        .toList(growable: true);
    _loadPendingAttempts();
  }

  Future<void> _loadPendingAttempts() async {
    final pending = await widget.controller.pendingContactAttempts(widget.stop);
    if (!mounted) return;
    final byId = <String, DriverContactAttemptModel>{
      for (final attempt in [..._attempts, ...pending]) attempt.id: attempt,
    };
    setState(() {
      _attempts = byId.values.toList(growable: true)
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    });
  }

  Future<void> _chooseReason(_CannotCompleteReason reason) async {
    var note = _note;
    if (reason == _CannotCompleteReason.other) {
      final entered = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: RoundsColors.ink.withValues(alpha: .28),
        builder: (_) => _OtherReasonSheet(initialValue: note),
      );
      if (!mounted || entered == null) return;
      note = entered;
    }
    setState(() {
      _reason = reason;
      _note = note;
      _state = _CannotCompleteState.action;
    });
  }

  Future<void> _primaryAction() async {
    final reason = _reason;
    if (reason == null || _submitting) return;
    if (reason.callFirst && _attempts.isEmpty) {
      await _callRecipient();
      return;
    }
    await _sendToOperations();
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
      builder: (_) => const _CannotCompleteCallOutcomeSheet(),
    );
    if (outcome != null && mounted) await _recordCallOutcome(outcome);
  }

  Future<void> _recordCallOutcome(String outcome) async {
    setState(() => _submitting = true);
    try {
      final result = await widget.controller.logContactAttempt(
        stop: widget.stop,
        target: 'recipient',
        outcome: outcome == 'no_answer' ? 'no_answer' : 'reached',
      );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.controller.driverError ?? 'Call outcome was not saved.',
            ),
          ),
        );
        return;
      }
      if (outcome == 'resolved') {
        Navigator.of(context).pop(false);
        return;
      }
      setState(() {
        _attempts.add(
          DriverContactAttemptModel(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            target: 'recipient',
            channel: 'native_phone',
            outcome: outcome == 'no_answer' ? 'no_answer' : 'reached',
            occurredAt: DateTime.now().toUtc(),
            savedLocally: result.pendingSync,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.committed
                ? 'Call outcome recorded.'
                : 'Call outcome saved on this phone and waiting to sync.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendToOperations() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _submitting = true);
    final contactSummary = _attempts.isEmpty
        ? 'No recipient call recorded.'
        : _attempts
              .map(
                (attempt) =>
                    'Recipient call: ${_contactOutcome(attempt.outcome)}',
              )
              .join('\n');
    final message =
        'CANNOT COMPLETE DELIVERY\n'
        'Round: ${widget.round.reference}\n'
        'Stop ${widget.stop.sequence}: ${widget.stop.deliveryReference}\n'
        'Recipient: ${widget.stop.recipientName}\n'
        'Reason: ${reason.title} (${reason.code})\n'
        '${_note.isEmpty ? '' : 'Note: $_note\n'}'
        'Custody: package remains with driver\n'
        '$contactSummary';
    try {
      final result = await widget.controller.sendOperationsMessage(
        round: widget.round,
        stop: widget.stop,
        body: message,
      );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.controller.driverError ??
                  'The Operations message was not saved.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _messagePendingSync = result.pendingSync;
        _state = _CannotCompleteState.waiting;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.committed
                ? 'Sent to Operations.'
                : 'Saved on this phone and waiting to sync.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openOperationsChat() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => OperationsChatScreen(
        controller: widget.controller,
        round: widget.round,
        stop: widget.stop,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final reason = _reason;
    final item = widget.stop.manifestItems.firstOrNull;
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              round: widget.round,
              stop: widget.stop,
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('cannot-complete-content'),
                padding: const EdgeInsets.fromLTRB(
                  DriverG04Metrics.contentPaddingHorizontal,
                  DriverG04Metrics.contentPaddingTop,
                  DriverG04Metrics.contentPaddingHorizontal,
                  DriverG04Metrics.contentPaddingBottom,
                ),
                child: _state == _CannotCompleteState.choose
                    ? _ChooseState(
                        stop: widget.stop,
                        item: item,
                        onChoose: _chooseReason,
                      )
                    : _ActionState(
                        stop: widget.stop,
                        item: item,
                        reason: reason!,
                        note: _note,
                        attempts: _attempts,
                        waiting: _state == _CannotCompleteState.waiting,
                        pendingSync: _messagePendingSync,
                      ),
              ),
            ),
            _Footer(
              state: _state,
              reason: reason,
              hasAttempts: _attempts.isNotEmpty,
              submitting: _submitting,
              onPrimary: _primaryAction,
              onMessage: _openOperationsChat,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.round,
    required this.stop,
    required this.onBack,
  });

  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('cannot-complete-topbar'),
    height: DriverG04Metrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverG04Metrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: DriverG04Metrics.topButtonSize,
          height: DriverG04Metrics.topButtonSize,
          child: IconButton(
            key: const Key('cannot-complete-back'),
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back,
              size: DriverG04Metrics.topIconSize,
            ),
          ),
        ),
        const SizedBox(width: DriverG04Metrics.topColumnGap),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STOP ${stop.sequence} OF ${round.stops.length}',
                style: const TextStyle(
                  color: RoundsColors.orange,
                  fontSize: DriverG04Metrics.topEyebrowSize,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: DriverG04Metrics.topEyebrowTracking,
                ),
              ),
              const SizedBox(height: DriverG04Metrics.topTitleGap),
              Text(
                stop.recipientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverG04Metrics.topTitleSize,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: DriverG04Metrics.topButtonSize),
      ],
    ),
  );
}

class _ChooseState extends StatelessWidget {
  const _ChooseState({
    required this.stop,
    required this.item,
    required this.onChoose,
  });

  final DriverRoundStopModel stop;
  final DriverManifestItemModel? item;
  final ValueChanged<_CannotCompleteReason> onChoose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Kicker('DELIVERY PROBLEM'),
      const SizedBox(height: DriverG04Metrics.heroGap),
      const Text(
        'Can’t complete delivery',
        style: TextStyle(
          color: RoundsColors.ink,
          fontSize: DriverG04Metrics.heroSize,
          height: DriverG04Metrics.heroHeight,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG04Metrics.heroTracking,
        ),
      ),
      const SizedBox(height: DriverG04Metrics.locationGap),
      Text(
        stop.rawAddress,
        style: const TextStyle(
          color: RoundsColors.muted,
          fontSize: DriverG04Metrics.locationSize,
          height: DriverG04Metrics.locationHeight,
          fontWeight: FontWeight.w700,
        ),
      ),
      _PackageBlock(item: item, label: 'PACKAGE WITH YOU'),
      const SizedBox(height: DriverG04Metrics.custodyGap),
      const Row(
        children: [
          Icon(Icons.check, size: 17, color: RoundsColors.green),
          SizedBox(width: 8),
          Text(
            'Pickup custody remains active',
            style: TextStyle(
              color: RoundsColors.green,
              fontSize: DriverG04Metrics.custodySize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      const SizedBox(height: DriverG04Metrics.sectionGap),
      const Text(
        'WHAT HAPPENED?',
        style: TextStyle(
          color: RoundsColors.muted,
          fontSize: DriverG04Metrics.choiceTitleSize,
          fontWeight: FontWeight.w800,
          letterSpacing: DriverG04Metrics.choiceTitleTracking,
        ),
      ),
      const SizedBox(height: DriverG04Metrics.choiceTitleBottom),
      for (final reason in _CannotCompleteReason.values)
        _ReasonRow(reason: reason, onTap: () => onChoose(reason)),
    ],
  );
}

class _ActionState extends StatelessWidget {
  const _ActionState({
    required this.stop,
    required this.item,
    required this.reason,
    required this.note,
    required this.attempts,
    required this.waiting,
    required this.pendingSync,
  });

  final DriverRoundStopModel stop;
  final DriverManifestItemModel? item;
  final _CannotCompleteReason reason;
  final String note;
  final List<DriverContactAttemptModel> attempts;
  final bool waiting;
  final bool pendingSync;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Kicker(
        waiting
            ? pendingSync
                  ? 'SAVED ON THIS PHONE'
                  : 'SENT TO OPERATIONS'
            : 'DELIVERY PROBLEM',
      ),
      const SizedBox(height: DriverG04Metrics.heroGap),
      Text(
        waiting ? 'Waiting for decision' : reason.title,
        style: const TextStyle(
          color: RoundsColors.ink,
          fontSize: DriverG04Metrics.heroSize,
          height: DriverG04Metrics.heroHeight,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG04Metrics.heroTracking,
        ),
      ),
      const SizedBox(height: DriverG04Metrics.locationGap),
      Text(
        '${stop.recipientName} · Stop ${stop.sequence}',
        style: const TextStyle(
          color: RoundsColors.muted,
          fontSize: DriverG04Metrics.locationSize,
          height: DriverG04Metrics.locationHeight,
          fontWeight: FontWeight.w700,
        ),
      ),
      _PackageBlock(
        item: item,
        label: waiting ? 'PACKAGE IN CUSTODY' : 'PACKAGE WITH YOU',
        detail: reason.title,
      ),
      const SizedBox(height: DriverG04Metrics.custodyGap),
      Row(
        children: [
          const Icon(Icons.check, size: 17, color: RoundsColors.green),
          const SizedBox(width: 8),
          Text(
            waiting
                ? 'Keep the delivery with you'
                : 'Keep the package with you',
            style: const TextStyle(
              color: RoundsColors.green,
              fontSize: DriverG04Metrics.custodySize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _TruthRow(label: 'Reason', value: reason.title),
      if (note.isNotEmpty) _TruthRow(label: 'Note', value: note),
      if (attempts.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text(
          'CONTACT',
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 7),
        for (var index = 0; index < attempts.length; index++)
          _ContactRow(attempt: attempts[index], index: index),
      ],
      if (waiting) ...[
        const SizedBox(height: 28),
        const Divider(height: 1),
        const SizedBox(height: 20),
        const Text(
          'OPERATIONS REVIEW',
          style: TextStyle(
            color: RoundsColors.orange,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'No next step has been approved yet',
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: 24,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pendingSync
              ? 'The structured reason is waiting to sync. Keep custody; Operations has not received it yet.'
              : 'The structured reason and contact evidence are in the real Operations thread. Keep custody and open the conversation for a decision.',
          style: const TextStyle(
            color: RoundsColors.muted,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ],
  );
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: DriverG04Metrics.issueDotSize,
        height: DriverG04Metrics.issueDotSize,
        decoration: const BoxDecoration(
          color: RoundsColors.red,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: DriverG04Metrics.issueGap),
      Text(
        label,
        style: const TextStyle(
          color: RoundsColors.red,
          fontSize: DriverG04Metrics.issueSize,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG04Metrics.issueTracking,
        ),
      ),
    ],
  );
}

class _PackageBlock extends StatelessWidget {
  const _PackageBlock({required this.item, required this.label, this.detail});
  final DriverManifestItemModel? item;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: DriverG04Metrics.packageMarginTop),
    padding: const EdgeInsets.only(top: DriverG04Metrics.packagePaddingTop),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverG04Metrics.packageEyebrowSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: DriverG04Metrics.packageEyebrowTracking,
                ),
              ),
              const SizedBox(height: DriverG04Metrics.packageNameGap),
              Text(
                item?.description ?? 'Physical package',
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverG04Metrics.packageNameSize,
                  height: DriverG04Metrics.packageNameHeight,
                  fontWeight: FontWeight.w800,
                  letterSpacing: DriverG04Metrics.packageNameTracking,
                ),
              ),
              if ((detail ?? item?.handlingNote)?.isNotEmpty ?? false) ...[
                const SizedBox(height: DriverG04Metrics.packageNoteGap),
                Text(
                  detail ?? item!.handlingNote!,
                  style: const TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverG04Metrics.packageNoteSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: DriverG04Metrics.packageColumnGap),
        Padding(
          padding: const EdgeInsets.only(
            top: DriverG04Metrics.quantityPaddingTop,
          ),
          child: Text(
            '×${item?.quantity ?? 1}',
            style: const TextStyle(
              color: RoundsColors.ink,
              fontSize: DriverG04Metrics.quantitySize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.reason, required this.onTap});
  final _CannotCompleteReason reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('cannot-complete-${reason.code}'),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(
        minHeight: DriverG04Metrics.choiceRowHeight,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: DriverG04Metrics.choiceIconColumnWidth,
            child: Icon(
              reason.icon,
              size: DriverG04Metrics.choiceIconSize,
              color: RoundsColors.inkSecondary,
            ),
          ),
          const SizedBox(width: DriverG04Metrics.choiceColumnGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason.title,
                  style: const TextStyle(
                    color: RoundsColors.ink,
                    fontSize: DriverG04Metrics.choiceNameSize,
                    height: DriverG04Metrics.choiceNameHeight,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DriverG04Metrics.choiceDetailGap),
                Text(
                  reason.detail,
                  style: const TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverG04Metrics.choiceDetailSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: RoundsColors.muted),
        ],
      ),
    ),
  );
}

class _TruthRow extends StatelessWidget {
  const _TruthRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 63),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: RoundsColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: RoundsColors.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.attempt, required this.index});
  final DriverContactAttemptModel attempt;
  final int index;

  @override
  Widget build(BuildContext context) {
    final local = attempt.occurredAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Container(
      key: Key('cannot-complete-attempt-$index'),
      constraints: const BoxConstraints(minHeight: 58),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              time,
              style: const TextStyle(
                color: RoundsColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Recipient call',
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            _contactOutcome(attempt.outcome),
            style: const TextStyle(
              color: RoundsColors.red,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.state,
    required this.reason,
    required this.hasAttempts,
    required this.submitting,
    required this.onPrimary,
    required this.onMessage,
  });

  final _CannotCompleteState state;
  final _CannotCompleteReason? reason;
  final bool hasAttempts;
  final bool submitting;
  final VoidCallback onPrimary;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final callFirst = reason?.callFirst == true && !hasAttempts;
    final label = state == _CannotCompleteState.waiting
        ? 'Open Operations conversation'
        : callFirst
        ? 'Call recipient'
        : 'Send to Operations';
    return Container(
      key: const Key('cannot-complete-footer'),
      padding: const EdgeInsets.fromLTRB(
        DriverG04Metrics.footerPaddingHorizontal,
        DriverG04Metrics.footerPaddingTop,
        DriverG04Metrics.footerPaddingHorizontal,
        DriverG04Metrics.footerPaddingBottom,
      ),
      decoration: const BoxDecoration(
        color: RoundsColors.surface,
        border: Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: state == _CannotCompleteState.choose
          ? SizedBox(
              height: DriverG04Metrics.secondaryHeight,
              child: TextButton(
                key: const Key('cannot-complete-message'),
                onPressed: onMessage,
                child: const Text('Message Operations'),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: DriverG04Metrics.primaryHeight,
                  child: FilledButton(
                    key: const Key('cannot-complete-primary'),
                    onPressed: submitting
                        ? null
                        : state == _CannotCompleteState.waiting
                        ? onMessage
                        : onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: RoundsColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DriverG04Metrics.primaryRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      submitting ? 'Saving…' : label,
                      style: const TextStyle(
                        fontSize: DriverG04Metrics.primarySize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (state == _CannotCompleteState.action) ...[
                  const SizedBox(height: DriverG04Metrics.secondaryGap),
                  SizedBox(
                    height: DriverG04Metrics.secondaryHeight,
                    child: TextButton(
                      onPressed: submitting ? null : onMessage,
                      child: const Text('Contact Operations'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _CannotCompleteCallOutcomeSheet extends StatelessWidget {
  const _CannotCompleteCallOutcomeSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: RoundsColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: RoundsColors.lineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Call outcome',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _OutcomeButton(
              value: 'resolved',
              label: 'Issue resolved',
              icon: Icons.check,
            ),
            _OutcomeButton(
              value: 'blocked',
              label: 'Reached · still blocked',
              icon: Icons.add,
            ),
            _OutcomeButton(
              value: 'no_answer',
              label: 'No answer',
              icon: Icons.phone_missed_outlined,
            ),
          ],
        ),
      ),
    ),
  );
}

class _OutcomeButton extends StatelessWidget {
  const _OutcomeButton({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: SizedBox(
      height: 62,
      child: TextButton.icon(
        key: Key('cannot-complete-outcome-$value'),
        onPressed: () => Navigator.of(context).pop(value),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: RoundsColors.ink,
        ),
        icon: Icon(icon, color: RoundsColors.inkSecondary),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    ),
  );
}

class _OtherReasonSheet extends StatefulWidget {
  const _OtherReasonSheet({required this.initialValue});
  final String initialValue;

  @override
  State<_OtherReasonSheet> createState() => _OtherReasonSheetState();
}

class _OtherReasonSheetState extends State<_OtherReasonSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: RoundsColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Other reason',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            const Text(
              'Only add what Operations needs to decide the next step.',
              style: TextStyle(color: RoundsColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('cannot-complete-other-note'),
              controller: _controller,
              maxLength: 120,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Short note'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('cannot-complete-use-other'),
              onPressed: () =>
                  Navigator.of(context).pop(_controller.text.trim()),
              child: const Text('Use this reason'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _contactOutcome(String outcome) => switch (outcome) {
  'no_answer' => 'No answer',
  'busy' => 'Busy',
  'wrong_number' => 'Wrong number',
  'reached' => 'Reached · still blocked',
  _ => 'Failed',
};

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
