import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_contact_history.dart';
import '../driver/driver_operations_thread.dart';
import '../driver/driver_session.dart';
import 'operations_chat_screen.dart';

typedef DriverContactHistoryLoader =
    Future<DriverContactHistoryModel> Function();

class ContactHistoryScreen extends StatefulWidget {
  const ContactHistoryScreen({
    required this.controller,
    required this.round,
    required this.stop,
    this.historyLoader,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final DriverContactHistoryLoader? historyLoader;

  @override
  State<ContactHistoryScreen> createState() => _ContactHistoryScreenState();
}

class _ContactHistoryScreenState extends State<ContactHistoryScreen> {
  final _scrollController = ScrollController();
  DriverContactHistoryModel? _history;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final history = await (widget.historyLoader?.call() ?? _readHistory());
    if (!mounted) return;
    setState(() {
      _history = history;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  Future<DriverContactHistoryModel> _readHistory() async {
    final currentStop = widget.controller.driverSession?.currentRound?.stops
        .where((stop) => stop.id == widget.stop.id)
        .firstOrNull;
    final stop = currentStop ?? widget.stop;
    var threadUnavailable = false;
    var serverMessages = const <DriverOperationsMessageModel>[];
    try {
      final thread = await widget.controller.getOperationsThread(
        round: widget.round,
        stop: stop,
      );
      serverMessages = thread.messages;
    } catch (_) {
      threadUnavailable = true;
    }
    final pendingMessages = await widget.controller.pendingOperationsMessages(
      round: widget.round,
      stop: stop,
    );
    final pendingAttempts = await widget.controller.pendingContactAttempts(
      stop,
    );
    final messages = _uniqueMessages([...serverMessages, ...pendingMessages]);
    final attempts = _uniqueAttempts([
      ...stop.contactAttempts,
      ...pendingAttempts,
    ]);
    return composeDriverContactHistory(
      messages: messages,
      contactAttempts: attempts,
      threadUnavailable: threadUnavailable,
    );
  }

  List<DriverOperationsMessageModel> _uniqueMessages(
    List<DriverOperationsMessageModel> values,
  ) => <String, DriverOperationsMessageModel>{
    for (final value in values) value.id: value,
  }.values.toList(growable: false);

  List<DriverContactAttemptModel> _uniqueAttempts(
    List<DriverContactAttemptModel> values,
  ) => <String, DriverContactAttemptModel>{
    for (final value in values) value.id: value,
  }.values.toList(growable: false);

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Future<void> _messageOperations() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OperationsChatScreen(
          controller: widget.controller,
          round: widget.round,
          stop: widget.stop,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _copy(DriverContactHistoryEventModel event) async {
    if (!event.copyable) return;
    await Clipboard.setData(ClipboardData(text: event.detail));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    final saved = history?.savedHistory ?? false;
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _HistoryTopBar(
              tenantName: widget.round.tenantName,
              saved: saved,
              onBack: () => Navigator.of(context).pop(),
            ),
            _StopContext(
              round: widget.round,
              stop: widget.stop,
              onViewStop: () => Navigator.of(context).pop(),
            ),
            if (saved)
              Container(
                key: const Key('contact-history-offline'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: DriverH03Metrics.connectionPaddingVertical,
                  horizontal: DriverH03Metrics.connectionPaddingHorizontal,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF2EB),
                  border: Border(bottom: BorderSide(color: Color(0xFFFFD9C8))),
                ),
                child: const Text(
                  'Offline · showing saved history',
                  style: TextStyle(
                    color: Color(0xFF8F461E),
                    fontSize: DriverH03Metrics.connectionSize,
                    height: DriverH03Metrics.connectionHeight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        key: const Key('contact-history-ledger'),
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          DriverH03Metrics.ledgerPaddingHorizontal,
                          DriverH03Metrics.ledgerPaddingTop,
                          DriverH03Metrics.ledgerPaddingHorizontal,
                          DriverH03Metrics.ledgerPaddingBottom,
                        ),
                        children: [
                          if (history == null || history.events.isEmpty)
                            const _EmptyHistory()
                          else
                            for (final group in _groupEvents(history.events))
                              _DaySection(
                                label: group.label,
                                events: group.events,
                                onCopy: _copy,
                              ),
                        ],
                      ),
                    ),
            ),
            Container(
              key: const Key('contact-history-footer'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                DriverH03Metrics.footerPaddingHorizontal,
                DriverH03Metrics.footerPaddingTop,
                DriverH03Metrics.footerPaddingHorizontal,
                DriverH03Metrics.footerPaddingBottom,
              ),
              decoration: const BoxDecoration(
                color: RoundsColors.surface,
                border: Border(top: BorderSide(color: RoundsColors.line)),
              ),
              child: SizedBox(
                height: DriverH03Metrics.primaryHeight,
                child: FilledButton(
                  key: const Key('contact-history-message-operations'),
                  onPressed: _messageOperations,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DriverH03Metrics.primaryRadius,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Message Operations',
                    style: TextStyle(
                      fontSize: DriverH03Metrics.primarySize,
                      fontWeight: FontWeight.w800,
                    ),
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

class _HistoryTopBar extends StatelessWidget {
  const _HistoryTopBar({
    required this.tenantName,
    required this.saved,
    required this.onBack,
  });

  final String tenantName;
  final bool saved;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('contact-history-topbar'),
    height: DriverH03Metrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverH03Metrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: DriverH03Metrics.topButtonSize,
          height: DriverH03Metrics.topButtonSize,
          child: IconButton(
            key: const Key('contact-history-back'),
            onPressed: onBack,
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.arrow_back,
              size: DriverH03Metrics.topIconSize,
            ),
          ),
        ),
        const SizedBox(width: DriverH03Metrics.topColumnGap),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contact history',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverH03Metrics.topTitleSize,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.42,
                ),
              ),
              const SizedBox(height: DriverH03Metrics.topStatusGap),
              Row(
                children: [
                  Container(
                    width: DriverH03Metrics.topStatusDotSize,
                    height: DriverH03Metrics.topStatusDotSize,
                    decoration: BoxDecoration(
                      color: saved ? RoundsColors.orange : RoundsColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: DriverH03Metrics.topStatusDotGap),
                  Flexible(
                    child: Text(
                      '$tenantName · ${saved ? 'saved' : 'synced'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: saved ? RoundsColors.orange : RoundsColors.green,
                        fontSize: DriverH03Metrics.topStatusSize,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(
          width: DriverH03Metrics.topButtonSize,
          height: DriverH03Metrics.topButtonSize,
        ),
      ],
    ),
  );
}

class _StopContext extends StatelessWidget {
  const _StopContext({
    required this.round,
    required this.stop,
    required this.onViewStop,
  });

  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final VoidCallback onViewStop;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('contact-history-context'),
    height: DriverH03Metrics.contextHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverH03Metrics.contextPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STOP ${stop.sequence} OF ${round.stops.length}',
                style: const TextStyle(
                  color: RoundsColors.orange,
                  fontSize: DriverH03Metrics.contextKickerSize,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: DriverH03Metrics.contextKickerTracking,
                ),
              ),
              const SizedBox(height: DriverH03Metrics.contextNameGap),
              Text(
                stop.recipientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverH03Metrics.contextNameSize,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.32,
                ),
              ),
              const SizedBox(height: DriverH03Metrics.contextMetaGap),
              Text(
                stop.rawAddress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverH03Metrics.contextMetaSize,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: DriverH03Metrics.contextColumnGap),
        SizedBox(
          height: DriverH03Metrics.contextActionHeight,
          child: TextButton(
            key: const Key('contact-history-view-stop'),
            onPressed: onViewStop,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
            child: const Text(
              'View stop',
              style: TextStyle(
                color: RoundsColors.inkSecondary,
                fontSize: DriverH03Metrics.contextActionSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.label,
    required this.events,
    required this.onCopy,
  });

  final String label;
  final List<DriverContactHistoryEventModel> events;
  final ValueChanged<DriverContactHistoryEventModel> onCopy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF8D97A5),
            fontSize: DriverH03Metrics.daySize,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: DriverH03Metrics.dayTracking,
          ),
        ),
        const SizedBox(height: DriverH03Metrics.dayBottom),
        IntrinsicHeight(
          child: Stack(
            children: [
              Positioned(
                left: DriverH03Metrics.timelineLeft,
                top: 17,
                bottom: 17,
                child: Container(width: 1, color: RoundsColors.line),
              ),
              Column(
                children: [
                  for (final event in events)
                    _HistoryEvent(event: event, onCopy: () => onCopy(event)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HistoryEvent extends StatelessWidget {
  const _HistoryEvent({required this.event, required this.onCopy});

  final DriverContactHistoryEventModel event;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event);
    final human = event.copyable;
    return GestureDetector(
      key: Key('contact-history-event-${event.id}'),
      onLongPress: human ? onCopy : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: DriverH03Metrics.eventMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: DriverH03Metrics.eventBottom),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: DriverH03Metrics.timeColumnWidth,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: DriverH03Metrics.timePaddingTop,
                  ),
                  child: Text(
                    _formatTime(event.occurredAt),
                    style: const TextStyle(
                      color: RoundsColors.muted,
                      fontSize: DriverH03Metrics.timeSize,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DriverH03Metrics.eventColumnGap),
              SizedBox(
                width: DriverH03Metrics.dotColumnWidth,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: DriverH03Metrics.dotPaddingTop,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: DriverH03Metrics.dotSize,
                      height: DriverH03Metrics.dotSize,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: RoundsColors.surface,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DriverH03Metrics.eventColumnGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: RoundsColors.inkSecondary,
                        fontSize: DriverH03Metrics.eventTitleSize,
                        height: DriverH03Metrics.eventTitleHeight,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: DriverH03Metrics.detailGap),
                    Text(
                      '${human ? '“${event.detail}”' : event.detail}'
                      '${event.savedLocally ? ' · saved on this phone' : ''}',
                      style: TextStyle(
                        color: event.outcome == null
                            ? (human ? RoundsColors.ink : RoundsColors.muted)
                            : color,
                        fontSize: human
                            ? DriverH03Metrics.humanSize
                            : DriverH03Metrics.detailSize,
                        height: human
                            ? DriverH03Metrics.humanHeight
                            : DriverH03Metrics.detailHeight,
                        fontWeight: event.outcome == null
                            ? FontWeight.w600
                            : FontWeight.w800,
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
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(Icons.history, color: RoundsColors.lineStrong, size: 34),
        SizedBox(height: 12),
        Text(
          'No contact history yet',
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Calls and messages for this stop will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _EventDay {
  const _EventDay({required this.label, required this.events});
  final String label;
  final List<DriverContactHistoryEventModel> events;
}

List<_EventDay> _groupEvents(List<DriverContactHistoryEventModel> events) {
  final groups = <String, List<DriverContactHistoryEventModel>>{};
  for (final event in events) {
    final local = event.occurredAt.toLocal();
    final key =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    groups.putIfAbsent(key, () => []).add(event);
  }
  final today = DateTime.now();
  return groups.entries
      .map((entry) {
        final first = entry.value.first.occurredAt.toLocal();
        final isToday =
            first.year == today.year &&
            first.month == today.month &&
            first.day == today.day;
        return _EventDay(
          label: isToday
              ? 'Today'
              : '${first.day.toString().padLeft(2, '0')}/${first.month.toString().padLeft(2, '0')}/${first.year}',
          events: entry.value,
        );
      })
      .toList(growable: false);
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

Color _eventColor(DriverContactHistoryEventModel event) => switch (event.kind) {
  DriverContactHistoryEventKind.driverMessage ||
  DriverContactHistoryEventKind.operationsMessage => RoundsColors.ink,
  DriverContactHistoryEventKind.system => RoundsColors.orange,
  DriverContactHistoryEventKind.recipientCall ||
  DriverContactHistoryEventKind.operationsCall =>
    event.outcome == 'reached' ? RoundsColors.green : RoundsColors.red,
};
