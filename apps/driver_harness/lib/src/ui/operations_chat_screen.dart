import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/driver_design_system.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_operations_thread.dart';
import '../driver/driver_session.dart';

class OperationsChatScreen extends StatefulWidget {
  const OperationsChatScreen({
    required this.controller,
    required this.round,
    required this.stop,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;

  @override
  State<OperationsChatScreen> createState() => _OperationsChatScreenState();
}

class _OperationsChatScreenState extends State<OperationsChatScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  List<DriverOperationsMessageModel> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final pending = await widget.controller.pendingOperationsMessages(
      round: widget.round,
      stop: widget.stop,
    );
    DriverOperationsThreadModel? thread;
    String? error;
    try {
      thread = await widget.controller.getOperationsThread(
        round: widget.round,
        stop: widget.stop,
      );
    } catch (caught) {
      error = caught.toString();
    }
    if (!mounted) return;
    final combined = <DriverOperationsMessageModel>[
      ...?thread?.messages,
      ...pending,
    ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    setState(() {
      _messages = combined;
      _loadError = error;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    _composer.clear();
    setState(() => _sending = true);
    final outcome = await widget.controller.sendOperationsMessage(
      round: widget.round,
      stop: widget.stop,
      body: body,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    await _load();
    if (!mounted) return;
    if (outcome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.driverError ?? 'Message could not be saved',
          ),
        ),
      );
    } else if (outcome.pendingSync) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message saved on this phone. It will send when connected.',
          ),
        ),
      );
    }
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _callOperations() async {
    final phone = widget.round.pickup.contactPhone.trim();
    final opened =
        phone.isNotEmpty && await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The phone app could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _messages.any((message) => message.savedLocally);
    final offline = _loadError != null || pending;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      body: SafeArea(
        child: Column(
          children: [
            _ChatTopBar(onCall: _callOperations),
            _StopContext(round: widget.round, stop: widget.stop),
            if (offline)
              Container(
                key: const Key('operations-offline-banner'),
                width: double.infinity,
                color: const Color(0xFFFFE8D8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                child: const Text(
                  'Offline · messages will send when connected',
                  style: TextStyle(
                    color: RoundsColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
                        children: [
                          if (_messages.isEmpty)
                            const _EmptyThread()
                          else
                            for (final message in _messages)
                              _MessageBubble(message: message),
                        ],
                      ),
                    ),
            ),
            _Composer(controller: _composer, sending: _sending, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({required this.onCall});
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Row(
      children: [
        IconButton(
          key: const Key('operations-chat-back'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 27),
        ),
        const Expanded(
          child: Text(
            'Operations',
            style: TextStyle(
              color: RoundsColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          key: const Key('operations-chat-call'),
          onPressed: onCall,
          icon: const Icon(Icons.call_outlined, size: 25),
        ),
        const SizedBox(width: 6),
      ],
    ),
  );
}

class _StopContext extends StatelessWidget {
  const _StopContext({required this.round, required this.stop});
  final DriverRoundModel round;
  final DriverRoundStopModel stop;

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border.symmetric(
        horizontal: BorderSide(color: RoundsColors.line),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${round.reference} · Stop ${stop.sequence} of ${round.stops.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RoundsType.roadKicker,
              ),
              const SizedBox(height: 5),
              Text(
                '${stop.recipientName} · ${stop.deliveryReference}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Text(
          'Current stop',
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 74),
    child: Column(
      children: const [
        Icon(Icons.support_agent, size: 42, color: RoundsColors.muted),
        SizedBox(height: 14),
        Text(
          'Operations thread',
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Messages about this stop stay here for the team.',
          textAlign: TextAlign.center,
          style: TextStyle(color: RoundsColors.muted, fontSize: 14),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final DriverOperationsMessageModel message;

  @override
  Widget build(BuildContext context) {
    final mine = message.sender == 'driver';
    final time = TimeOfDay.fromDateTime(
      message.sentAt.toLocal(),
    ).format(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .78,
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: mine ? RoundsColors.ink : Colors.white,
                  border: mine ? null : Border.all(color: RoundsColors.line),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                ),
                child: Text(
                  message.body,
                  style: TextStyle(
                    color: mine ? Colors.white : RoundsColors.ink,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                message.savedLocally ? 'Saved locally · $time' : 'Sent · $time',
                style: const TextStyle(
                  color: RoundsColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: const Key('operations-chat-composer'),
            controller: controller,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: 'Message Operations',
              filled: true,
              fillColor: const Color(0xFFF0F3F5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox.square(
          dimension: 46,
          child: IconButton.filled(
            key: const Key('operations-chat-send'),
            onPressed: sending ? null : onSend,
            style: IconButton.styleFrom(backgroundColor: RoundsColors.ink),
            icon: sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_upward, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
