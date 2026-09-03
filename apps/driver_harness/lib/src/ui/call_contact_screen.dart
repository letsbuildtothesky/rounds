import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/driver_design_system.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';

enum CallContactTarget { recipient, operations }

typedef CallContactLauncher = Future<bool> Function(Uri uri);

class CallContactScreen extends StatefulWidget {
  const CallContactScreen({
    required this.controller,
    required this.round,
    required this.stop,
    required this.target,
    this.onMessageOperations,
    this.launcher = _launchExternal,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final CallContactTarget target;
  final Future<void> Function()? onMessageOperations;
  final CallContactLauncher launcher;

  @override
  State<CallContactScreen> createState() => _CallContactScreenState();
}

class _CallContactScreenState extends State<CallContactScreen> {
  late List<DriverContactAttemptModel> _attempts;
  bool _dialerOpened = false;
  bool _submitting = false;

  bool get _recipient => widget.target == CallContactTarget.recipient;
  String get _target => _recipient ? 'recipient' : 'operations';
  String get _phone =>
      (_recipient
              ? widget.stop.recipientPhone
              : widget.round.pickup.contactPhone)
          .trim();

  @override
  void initState() {
    super.initState();
    _attempts = widget.stop.contactAttempts
        .where((attempt) => attempt.target == _target)
        .toList(growable: true);
    _loadPending();
  }

  Future<void> _loadPending() async {
    final pending = await widget.controller.pendingContactAttempts(widget.stop);
    if (!mounted) return;
    setState(() {
      final ids = _attempts.map((attempt) => attempt.id).toSet();
      _attempts.addAll(
        pending.where(
          (attempt) => attempt.target == _target && !ids.contains(attempt.id),
        ),
      );
      _attempts.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    });
  }

  Future<void> _call() async {
    final opened =
        _phone.isNotEmpty &&
        await widget.launcher(Uri(scheme: 'tel', path: _phone));
    if (!mounted) return;
    if (opened) {
      setState(() => _dialerOpened = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The phone app could not be opened.')),
      );
    }
  }

  Future<void> _chooseOutcome() async {
    final outcome = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: RoundsColors.ink.withValues(alpha: .28),
      builder: (context) => _OutcomeSheet(recipient: _recipient),
    );
    if (outcome == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      final outcomeResult = await widget.controller.logContactAttempt(
        stop: widget.stop,
        target: _target,
        outcome: outcome,
      );
      if (!mounted || outcomeResult == null) return;
      final refreshed = widget.controller.driverSession?.currentRound?.stops
          .where((stop) => stop.id == widget.stop.id)
          .firstOrNull;
      final serverAttempts = refreshed?.contactAttempts
          .where((attempt) => attempt.target == _target)
          .toList();
      if (serverAttempts != null && serverAttempts.isNotEmpty) {
        setState(() => _attempts = serverAttempts);
      } else {
        setState(() {
          _attempts.add(
            DriverContactAttemptModel(
              id: 'local-${DateTime.now().microsecondsSinceEpoch}',
              target: _target,
              channel: 'native_phone',
              outcome: outcome,
              occurredAt: DateTime.now().toUtc(),
              savedLocally: outcomeResult.pendingSync,
            ),
          );
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcomeResult.committed
                  ? 'Call outcome recorded.'
                  : 'Call outcome saved locally and waiting to sync.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _attempts.isEmpty ? null : _attempts.last;
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        key: const Key('h02-back'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _recipient ? 'Call recipient' : 'Call Operations',
                            style: const TextStyle(
                              color: RoundsColors.ink,
                              fontSize: 17,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${widget.round.reference} · Stop ${widget.stop.sequence} of ${widget.round.stops.length}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RoundsColors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: RoundsColors.line),
            SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STOP ${widget.stop.sequence} OF ${widget.round.stops.length}',
                            style: const TextStyle(
                              color: RoundsColors.orange,
                              fontSize: 10.5,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${widget.stop.recipientName} · ${widget.stop.deliveryReference}',
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
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('View stop'),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: RoundsColors.line),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 38, 26, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Kicker(
                      label: _recipient ? 'Recipient' : 'Operations',
                      color: _recipient
                          ? RoundsColors.orange
                          : RoundsColors.green,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _recipient
                          ? widget.stop.recipientName
                          : widget.round.tenantName,
                      style: const TextStyle(
                        color: RoundsColors.ink,
                        fontSize: 42,
                        height: .98,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _recipient ? widget.stop.rawAddress : 'Operations phone',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoundsColors.muted,
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      decoration: const BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: RoundsColors.line),
                        ),
                      ),
                      child: Text(
                        _phone.isEmpty ? 'Phone number unavailable' : _phone,
                        style: const TextStyle(
                          color: RoundsColors.ink,
                          fontSize: 24,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.6,
                        ),
                      ),
                    ),
                    if (_recipient) ...[
                      const _PrivacyRow(
                        icon: Icons.phone_outlined,
                        title: 'Opens your phone app',
                        detail: 'Customer calls use the normal dialer.',
                      ),
                      const _PrivacyRow(
                        icon: Icons.info_outline,
                        title: 'Your number may be visible',
                        detail: 'Call masking is not active for this delivery.',
                      ),
                    ],
                    if (last != null) ...[
                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: const BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(color: RoundsColors.line),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              last.savedLocally
                                  ? 'Last call · saved'
                                  : 'Last call',
                              style: const TextStyle(
                                color: RoundsColors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _outcomeLabel(last.outcome),
                              style: TextStyle(
                                color: last.outcome == 'reached'
                                    ? RoundsColors.green
                                    : RoundsColors.orange,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: RoundsColors.line)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: FilledButton.icon(
                      key: const Key('h02-call'),
                      onPressed: _phone.isEmpty ? null : _call,
                      icon: const Icon(Icons.phone_outlined),
                      label: Text(
                        _recipient ? 'Call recipient' : 'Call Operations',
                      ),
                    ),
                  ),
                  if (_dialerOpened)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        key: const Key('h02-log-outcome'),
                        onPressed: _submitting ? null : _chooseOutcome,
                        child: Text(
                          _submitting ? 'Saving outcome…' : 'Log call outcome',
                        ),
                      ),
                    )
                  else if (!_recipient && widget.onMessageOperations != null)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: widget.onMessageOperations,
                        child: const Text('Message Operations'),
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
}

class _Kicker extends StatelessWidget {
  const _Kicker({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.3,
        ),
      ),
    ],
  );
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 58),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 30,
          child: Icon(icon, size: 20, color: RoundsColors.orange),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: 13.5,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  color: RoundsColors.muted,
                  fontSize: 11.8,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OutcomeSheet extends StatelessWidget {
  const _OutcomeSheet({required this.recipient});
  final bool recipient;

  @override
  Widget build(BuildContext context) {
    final options = <(String, String)>[
      ('reached', 'Reached'),
      ('no_answer', 'No answer'),
      (recipient ? 'busy' : 'call_failed', recipient ? 'Busy' : 'Call failed'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 16),
        decoration: BoxDecoration(
          color: RoundsColors.surface,
          border: Border.all(color: RoundsColors.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: RoundsColors.lineStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Call outcome',
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: 23,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -.9,
              ),
            ),
            const SizedBox(height: 12),
            for (final option in options)
              SizedBox(
                height: 58,
                child: InkWell(
                  key: Key('h02-outcome-${option.$1}'),
                  onTap: () => Navigator.of(context).pop(option.$1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.$2,
                          style: const TextStyle(
                            color: RoundsColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: RoundsColors.muted,
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

String _outcomeLabel(String value) => switch (value) {
  'reached' => 'Reached',
  'no_answer' => 'No answer',
  'busy' => 'Busy',
  'call_failed' => 'Call failed',
  _ => value,
};

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
