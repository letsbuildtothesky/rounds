import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_chat_location.dart';
import '../driver/driver_chat_media.dart';
import '../driver/driver_message_links.dart';
import '../driver/driver_operations_thread.dart';
import '../driver/driver_session.dart';
import '../storage/operations_message_draft_store.dart';

class OperationsChatScreen extends StatefulWidget {
  const OperationsChatScreen({
    required this.controller,
    required this.round,
    required this.stop,
    this.draftStore,
    this.locationGateway = const GeolocatorDriverChatLocationGateway(),
    this.mediaGateway,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final OperationsMessageDraftStore? draftStore;
  final DriverChatLocationGateway locationGateway;
  final DriverChatMediaGateway? mediaGateway;

  @override
  State<OperationsChatScreen> createState() => _OperationsChatScreenState();
}

class _OperationsChatScreenState extends State<OperationsChatScreen>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  List<DriverOperationsMessageModel> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _capturingLocation = false;
  bool _capturingMedia = false;
  DriverMessageAttachmentModel? _stagedLocation;
  List<DriverMessageAttachmentModel> _stagedMedia = const [];
  String? _loadError;
  OperationsMessageDraftStore? _draftStore;
  Timer? _draftTimer;
  Timer? _messageRefreshTimer;
  bool _refreshingMessages = false;
  late final DriverChatMediaGateway _mediaGateway =
      widget.mediaGateway ?? DriverChatMediaGateway();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _composer.addListener(_composerChanged);
    unawaited(_restoreDraft());
    unawaited(_load());
    _messageRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_load()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _messageRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final draftStore = _draftStore;
    if (draftStore != null) {
      unawaited(draftStore.save(widget.stop.id, _composer.text));
    }
    _composer.removeListener(_composerChanged);
    _composer.dispose();
    _scrollController.dispose();
    if (widget.mediaGateway == null) unawaited(_mediaGateway.dispose());
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final store =
        widget.draftStore ?? await OperationsMessageDraftStore.create();
    if (!mounted) return;
    _draftStore = store;
    final draft = store.restore(widget.stop.id);
    if (draft != null && _composer.text.isEmpty) {
      _composer.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
    final location = store.restoreLocation(widget.stop.id);
    final media = store.restoreMedia(widget.stop.id);
    if (location != null || media.isNotEmpty) {
      setState(() {
        _stagedLocation = location;
        _stagedMedia = media;
      });
    }
  }

  void _composerChanged() {
    if (mounted) setState(() {});
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 250), () {
      final store = _draftStore;
      if (store != null) unawaited(store.save(widget.stop.id, _composer.text));
    });
  }

  Future<void> _load() async {
    if (_refreshingMessages) return;
    _refreshingMessages = true;
    var pending = const <DriverOperationsMessageModel>[];
    DriverOperationsThreadModel? thread;
    String? error;
    try {
      try {
        pending = await widget.controller.pendingOperationsMessages(
          round: widget.round,
          stop: widget.stop,
        );
        thread = await widget.controller.getOperationsThread(
          round: widget.round,
          stop: widget.stop,
        );
      } catch (caught) {
        error = caught.toString();
      }
      if (!mounted) return;
      final combined = _mergeMessages([
        ...(thread?.messages ?? _messages),
        ...pending,
      ]);
      final previousSignature = _messageSignature(_messages);
      final nextSignature = _messageSignature(combined);
      final messagesChanged = previousSignature != nextSignature;
      setState(() {
        _messages = combined;
        _loadError = error;
        _loading = false;
      });
      if (messagesChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
      }
    } finally {
      _refreshingMessages = false;
    }
  }

  String _messageSignature(
    List<DriverOperationsMessageModel> messages,
  ) => messages
      .map(
        (message) =>
            '${message.id}:${message.savedLocally}:${message.attachments.length}',
      )
      .join('|');

  List<DriverOperationsMessageModel> _mergeMessages(
    List<DriverOperationsMessageModel> messages,
  ) {
    final unique = <String, DriverOperationsMessageModel>{};
    for (final message in messages) {
      unique[message.id] = message;
    }
    return unique.values.toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    final location = _stagedLocation;
    final media = _stagedMedia;
    if ((body.isEmpty && location == null && media.isEmpty) || _sending) return;
    setState(() => _sending = true);
    final outcome = await widget.controller.sendOperationsMessage(
      round: widget.round,
      stop: widget.stop,
      body: body,
      attachments: [?location, ...media],
    );
    if (!mounted) return;
    if (outcome == null) {
      setState(() => _sending = false);
      await _draftStore?.save(widget.stop.id, body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.driverError ?? 'Message could not be saved',
          ),
        ),
      );
      return;
    }
    _composer.clear();
    await _draftStore?.clear(widget.stop.id);
    await _draftStore?.clearLocation(widget.stop.id);
    await _draftStore?.clearMedia(widget.stop.id);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _stagedLocation = null;
      _stagedMedia = const [];
    });
    await _load();
    if (!mounted) return;
    if (outcome.pendingSync) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message saved on this phone. It will send when connected.',
          ),
        ),
      );
    }
  }

  Future<void> _showAttachmentSheet() async {
    if (_sending || _capturingLocation || _capturingMedia) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add to message',
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _AttachmentChoice(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                keyValue: 'h01-add-camera',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_pickMedia(_mediaGateway.captureCamera));
                },
              ),
              _AttachmentChoice(
                icon: Icons.photo_outlined,
                label: 'Photo',
                keyValue: 'h01-add-photo',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_pickMedia(_mediaGateway.pickPhoto));
                },
              ),
              _AttachmentChoice(
                icon: Icons.insert_drive_file_outlined,
                label: 'File',
                keyValue: 'h01-add-file',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_pickMedia(_mediaGateway.pickFile));
                },
              ),
              ListTile(
                key: const Key('h01-add-location'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: RoundsColors.ink,
                ),
                title: const Text(
                  'Location',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_captureLocation());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMedia(
    Future<DriverMessageAttachmentModel?> Function() picker,
  ) async {
    if (_capturingMedia || _stagedMedia.length >= 7) return;
    setState(() => _capturingMedia = true);
    try {
      final attachment = await picker();
      if (attachment == null || !mounted) return;
      final next = [..._stagedMedia, attachment];
      await _draftStore?.saveMedia(widget.stop.id, next);
      if (mounted) setState(() => _stagedMedia = next);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _capturingMedia = false);
    }
  }

  Future<void> _recordVoice() async {
    if (_sending || _capturingMedia) return;
    final attachment = await showModalBottomSheet<DriverMessageAttachmentModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _VoiceNoteSheet(gateway: _mediaGateway),
    );
    if (attachment == null || !mounted) return;
    final next = [..._stagedMedia, attachment];
    await _draftStore?.saveMedia(widget.stop.id, next);
    if (mounted) setState(() => _stagedMedia = next);
  }

  Future<void> _removeStagedMedia(int index) async {
    final next = [..._stagedMedia]..removeAt(index);
    await _draftStore?.saveMedia(widget.stop.id, next);
    if (mounted) setState(() => _stagedMedia = next);
  }

  Future<void> _captureLocation() async {
    if (_capturingLocation) return;
    setState(() => _capturingLocation = true);
    try {
      final location = await widget.locationGateway.captureCurrentLocation();
      await _draftStore?.saveLocation(widget.stop.id, location);
      if (!mounted) return;
      setState(() => _stagedLocation = location);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location added')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _capturingLocation = false);
    }
  }

  Future<void> _removeStagedLocation() async {
    await _draftStore?.clearLocation(widget.stop.id);
    if (mounted) setState(() => _stagedLocation = null);
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
    final compact = MediaQuery.sizeOf(context).width <= 340;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: MediaQuery.withNoTextScaling(
          child: Column(
            children: [
              _ChatTopBar(
                round: widget.round,
                offline: offline,
                compact: compact,
                onCall: _callOperations,
              ),
              _StopContext(
                round: widget.round,
                stop: widget.stop,
                compact: compact,
                onViewStop: () => Navigator.of(context).pop(),
              ),
              if (offline)
                Container(
                  key: const Key('operations-offline-banner'),
                  width: double.infinity,
                  color: const Color(0xFFFFE8D8),
                  constraints: const BoxConstraints(
                    minHeight: DriverH01Metrics.connectionMinHeight,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DriverH01Metrics.connectionPaddingHorizontal,
                    vertical: DriverH01Metrics.connectionPaddingVertical,
                  ),
                  child: const Text(
                    'Offline · messages will send when connected',
                    style: TextStyle(
                      color: RoundsColors.warning,
                      fontSize: DriverH01Metrics.connectionSize,
                      height: DriverH01Metrics.connectionHeight,
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
                          key: const Key('h01-messages'),
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            compact
                                ? DriverH01Metrics
                                      .compactMessagesPaddingHorizontal
                                : DriverH01Metrics.messagesPaddingHorizontal,
                            DriverH01Metrics.messagesPaddingTop,
                            compact
                                ? DriverH01Metrics
                                      .compactMessagesPaddingHorizontal
                                : DriverH01Metrics.messagesPaddingHorizontal,
                            DriverH01Metrics.messagesPaddingBottom,
                          ),
                          children: [
                            if (_messages.isEmpty)
                              const _EmptyThread()
                            else ...[
                              _DayLabel(date: _messages.first.sentAt),
                              for (final message in _messages)
                                _MessageBubble(
                                  message: message,
                                  compact: compact,
                                ),
                            ],
                          ],
                        ),
                      ),
              ),
              _Composer(
                controller: _composer,
                sending: _sending,
                capturingLocation: _capturingLocation,
                stagedLocation: _stagedLocation,
                stagedMedia: _stagedMedia,
                canSend:
                    _composer.text.trim().isNotEmpty ||
                    _stagedLocation != null ||
                    _stagedMedia.isNotEmpty,
                compact: compact,
                onAdd: _showAttachmentSheet,
                onRemoveLocation: _removeStagedLocation,
                onRemoveMedia: _removeStagedMedia,
                onRecordVoice: _recordVoice,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final isToday =
        localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day;
    return Padding(
      key: const Key('h01-day'),
      padding: const EdgeInsets.only(bottom: DriverH01Metrics.dayBottom),
      child: Text(
        isToday
            ? 'TODAY'
            : MaterialLocalizations.of(
                context,
              ).formatMediumDate(localDate).toUpperCase(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF8D97A5),
          fontSize: DriverH01Metrics.daySize,
          fontWeight: FontWeight.w800,
          letterSpacing: DriverH01Metrics.dayTracking,
        ),
      ),
    );
  }
}

class _SystemEvent extends StatelessWidget {
  const _SystemEvent({required this.message});

  final DriverOperationsMessageModel message;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(
      message.sentAt.toLocal(),
    ).format(context);
    return Container(
      margin: const EdgeInsets.only(top: DriverH01Metrics.rowTop),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: RoundsColors.line),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              time,
              style: const TextStyle(
                color: RoundsColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 3, right: 9),
            decoration: const BoxDecoration(
              color: RoundsColors.green,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              message.body,
              style: const TextStyle(
                color: RoundsColors.inkSecondary,
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({
    required this.round,
    required this.offline,
    required this.compact,
    required this.onCall,
  });

  final DriverRoundModel round;
  final bool offline;
  final bool compact;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('h01-topbar'),
    height: DriverH01Metrics.topBarHeight,
    padding: EdgeInsets.symmetric(
      horizontal: compact
          ? DriverH01Metrics.compactTopBarPaddingHorizontal
          : DriverH01Metrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        SizedBox.square(
          dimension: DriverH01Metrics.topButtonSize,
          child: IconButton(
            key: const Key('operations-chat-back'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              size: DriverH01Metrics.topIconSize,
            ),
          ),
        ),
        const SizedBox(width: DriverH01Metrics.topColumnGap),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operations',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverH01Metrics.topTitleSize,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.43,
                ),
              ),
              const SizedBox(height: DriverH01Metrics.topStatusGap),
              Row(
                children: [
                  Container(
                    width: DriverH01Metrics.topStatusDotSize,
                    height: DriverH01Metrics.topStatusDotSize,
                    decoration: BoxDecoration(
                      color: offline
                          ? RoundsColors.warning
                          : RoundsColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: DriverH01Metrics.topStatusDotGap),
                  Expanded(
                    child: Text(
                      '${round.tenantName} · ${offline ? 'Connection paused' : 'Online'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: offline
                            ? RoundsColors.warning
                            : RoundsColors.green,
                        fontSize: DriverH01Metrics.topStatusSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox.square(
          dimension: DriverH01Metrics.topButtonSize,
          child: IconButton(
            key: const Key('operations-chat-call'),
            onPressed: onCall,
            icon: const Icon(
              Icons.call_outlined,
              size: DriverH01Metrics.topIconSize,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StopContext extends StatelessWidget {
  const _StopContext({
    required this.round,
    required this.stop,
    required this.compact,
    required this.onViewStop,
  });
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final bool compact;
  final VoidCallback onViewStop;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('h01-context'),
    height: DriverH01Metrics.contextHeight,
    padding: EdgeInsets.symmetric(
      horizontal: compact
          ? DriverH01Metrics.compactContextPaddingHorizontal
          : DriverH01Metrics.contextPaddingHorizontal,
    ),
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
                'STOP ${stop.sequence} OF ${round.stops.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoundsColors.orange,
                  fontSize: DriverH01Metrics.contextKickerSize,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: DriverH01Metrics.contextKickerTracking,
                ),
              ),
              const SizedBox(height: DriverH01Metrics.contextNameGap),
              Text(
                '${stop.recipientName} · ${stop.rawAddress}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverH01Metrics.contextNameSize,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.23,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: DriverH01Metrics.contextColumnGap),
        SizedBox(
          height: DriverH01Metrics.contextActionHeight,
          child: TextButton(
            key: const Key('h01-view-stop'),
            onPressed: onViewStop,
            style: TextButton.styleFrom(
              foregroundColor: RoundsColors.inkSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
            child: const Text(
              'View stop',
              style: TextStyle(
                fontSize: DriverH01Metrics.contextActionSize,
                fontWeight: FontWeight.w900,
              ),
            ),
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

class _AttachmentChoice extends StatelessWidget {
  const _AttachmentChoice({
    required this.icon,
    required this.label,
    required this.keyValue,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String keyValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    key: Key(keyValue),
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: RoundsColors.ink),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.compact});
  final DriverOperationsMessageModel message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (message.sender == 'system') {
      return _SystemEvent(message: message);
    }
    final mine = message.sender == 'driver';
    final time = TimeOfDay.fromDateTime(
      message.sentAt.toLocal(),
    ).format(context);
    final copyText = [
      if (message.body.trim().isNotEmpty) message.body.trim(),
      ...message.attachments.map((attachment) => attachment.copyReference),
    ].join(' · ');
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: DriverH01Metrics.rowTop),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.sizeOf(context).width *
                (compact
                    ? DriverH01Metrics.compactMaxBubbleFraction
                    : DriverH01Metrics.maxBubbleFraction),
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: mine ? 0 : 2,
                  right: mine ? 2 : 0,
                  bottom: DriverH01Metrics.senderBottom,
                ),
                child: Text(
                  mine ? 'You' : 'Operations',
                  style: const TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverH01Metrics.senderSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DriverH01Metrics.bubblePaddingHorizontal,
                  vertical: DriverH01Metrics.bubblePaddingVertical,
                ),
                decoration: BoxDecoration(
                  color: mine ? RoundsColors.ink : const Color(0xFFF3F5F7),
                  border: mine
                      ? null
                      : Border.all(color: const Color(0xFFEDF0F2)),
                  borderRadius: BorderRadius.circular(
                    DriverH01Metrics.bubbleRadius,
                  ),
                ),
                child: GestureDetector(
                  key: Key('h01-message-${message.id}'),
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () async {
                    await Clipboard.setData(ClipboardData(text: copyText));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied')),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: mine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (message.body.trim().isNotEmpty)
                        _MessageBody(
                          body: message.body,
                          style: TextStyle(
                            color: mine ? Colors.white : RoundsColors.ink,
                            fontSize: DriverH01Metrics.bubbleSize,
                            height: DriverH01Metrics.bubbleHeight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      for (final attachment in message.attachments)
                        if (attachment.kind == 'location')
                          _LocationAttachmentCard(
                            attachment: attachment,
                            mine: mine,
                          )
                        else
                          _MediaAttachmentCard(
                            attachment: attachment,
                            mine: mine,
                          ),
                      const SizedBox(height: DriverH01Metrics.metaTop),
                      Text(
                        mine
                            ? '$time · ${message.savedLocally ? 'Saved locally' : 'Sent'}'
                            : time,
                        style: TextStyle(
                          color: mine
                              ? Colors.white.withValues(alpha: .62)
                              : RoundsColors.muted,
                          fontSize: DriverH01Metrics.metaSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _LocationAttachmentCard extends StatelessWidget {
  const _LocationAttachmentCard({required this.attachment, required this.mine});

  final DriverMessageAttachmentModel attachment;
  final bool mine;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('h01-location-${attachment.latitude}-${attachment.longitude}'),
    margin: const EdgeInsets.only(top: 9),
    decoration: BoxDecoration(
      color: mine ? Colors.white.withValues(alpha: .08) : Colors.white,
      border: Border.all(
        color: mine
            ? Colors.white.withValues(alpha: .18)
            : const Color(0xFFDCE3E8),
      ),
      borderRadius: BorderRadius.circular(7),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: mine
                    ? Colors.white.withValues(alpha: .12)
                    : const Color(0xFFF3F5F7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.location_on_outlined,
                size: 19,
                color: mine ? Colors.white : RoundsColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: mine ? Colors.white : RoundsColors.ink,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${attachment.latitude.toStringAsFixed(4)}, '
                    '${attachment.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: mine
                          ? Colors.white.withValues(alpha: .65)
                          : RoundsColors.muted,
                      fontSize: 11.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: mine
                  ? Colors.white.withValues(alpha: .55)
                  : RoundsColors.muted,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _open(BuildContext context) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${attachment.latitude},${attachment.longitude}',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The location could not be opened.')),
      );
    }
  }
}

class _MediaAttachmentCard extends StatefulWidget {
  const _MediaAttachmentCard({required this.attachment, required this.mine});
  final DriverMessageAttachmentModel attachment;
  final bool mine;

  @override
  State<_MediaAttachmentCard> createState() => _MediaAttachmentCardState();
}

class _MediaAttachmentCardState extends State<_MediaAttachmentCard> {
  AudioPlayer? _player;

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final mine = widget.mine;
    final isVoice = attachment.kind == 'voice';
    return Container(
      key: Key('h01-media-${attachment.mediaAssetId ?? attachment.sha256}'),
      margin: const EdgeInsets.only(top: 9),
      decoration: BoxDecoration(
        color: mine ? Colors.white.withValues(alpha: .08) : Colors.white,
        border: Border.all(
          color: mine
              ? Colors.white.withValues(alpha: .18)
              : const Color(0xFFDCE3E8),
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: isVoice ? _playVoice : _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: mine
                      ? Colors.white.withValues(alpha: .12)
                      : const Color(0xFFF3F5F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isVoice
                      ? Icons.play_arrow
                      : attachment.kind == 'image'
                      ? Icons.photo_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 19,
                  color: mine ? Colors.white : RoundsColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVoice ? 'Voice note' : attachment.fileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mine ? Colors.white : RoundsColors.ink,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isVoice
                          ? _durationLabel(attachment.durationMilliseconds ?? 0)
                          : _sizeLabel(attachment.byteSize ?? 0),
                      style: TextStyle(
                        color: mine
                            ? Colors.white.withValues(alpha: .65)
                            : RoundsColors.muted,
                        fontSize: 11.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: mine
                    ? Colors.white.withValues(alpha: .55)
                    : RoundsColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playVoice() async {
    final source = widget.attachment.localPath;
    final remote = widget.attachment.downloadUrl;
    if (source == null && remote == null) return;
    final player = _player ??= AudioPlayer();
    if (source != null) {
      await player.setFilePath(source);
    } else {
      await player.setUrl(remote!);
    }
    await player.play();
  }

  Future<void> _open() async {
    final remote = widget.attachment.downloadUrl;
    final local = widget.attachment.localPath;
    final uri = remote != null
        ? Uri.parse(remote)
        : local != null
        ? Uri.file(local)
        : null;
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The attachment could not be opened.')),
      );
    }
  }
}

String _sizeLabel(int bytes) => bytes >= 1048576
    ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).ceil()} KB';

String _durationLabel(int milliseconds) {
  final seconds = (milliseconds / 1000).ceil();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _MessageBody extends StatefulWidget {
  const _MessageBody({required this.body, required this.style});

  final String body;
  final TextStyle style;

  @override
  State<_MessageBody> createState() => _MessageBodyState();
}

class _MessageBodyState extends State<_MessageBody> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    final spans = parseDriverMessageText(widget.body)
        .map((segment) {
          if (segment.uri == null) return TextSpan(text: segment.text);
          final recognizer = TapGestureRecognizer()
            ..onTap = () => _openLink(segment.uri!);
          _recognizers.add(recognizer);
          return TextSpan(
            text: segment.text,
            style: const TextStyle(
              decoration: TextDecoration.underline,
              decorationThickness: 1,
            ),
            recognizer: recognizer,
          );
        })
        .toList(growable: false);
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }

  Future<void> _openLink(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The link could not be opened.')),
      );
    }
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.capturingLocation,
    required this.stagedLocation,
    required this.stagedMedia,
    required this.canSend,
    required this.compact,
    required this.onAdd,
    required this.onRemoveLocation,
    required this.onRemoveMedia,
    required this.onRecordVoice,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final bool capturingLocation;
  final DriverMessageAttachmentModel? stagedLocation;
  final List<DriverMessageAttachmentModel> stagedMedia;
  final bool canSend;
  final bool compact;
  final VoidCallback onAdd;
  final VoidCallback onRemoveLocation;
  final ValueChanged<int> onRemoveMedia;
  final VoidCallback onRecordVoice;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('h01-composer'),
    padding: EdgeInsets.fromLTRB(
      compact
          ? DriverH01Metrics.compactComposerPaddingHorizontal
          : DriverH01Metrics.composerPaddingHorizontal,
      DriverH01Metrics.composerPaddingTop,
      compact
          ? DriverH01Metrics.compactComposerPaddingHorizontal
          : DriverH01Metrics.composerPaddingHorizontal,
      DriverH01Metrics.composerPaddingBottom,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stagedLocation != null || stagedMedia.isNotEmpty)
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (stagedLocation != null)
                  _StagedAttachment(
                    attachment: stagedLocation!,
                    onRemove: onRemoveLocation,
                  ),
                for (var index = 0; index < stagedMedia.length; index++)
                  _StagedAttachment(
                    attachment: stagedMedia[index],
                    onRemove: () => onRemoveMedia(index),
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox.square(
              dimension: compact
                  ? DriverH01Metrics.compactComposerControlSize
                  : DriverH01Metrics.composerControlSize,
              child: IconButton.outlined(
                key: const Key('h01-add-attachment'),
                onPressed: sending || capturingLocation ? null : onAdd,
                style: IconButton.styleFrom(
                  foregroundColor: RoundsColors.ink,
                  side: const BorderSide(color: RoundsColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DriverH01Metrics.composerRadius,
                    ),
                  ),
                ),
                icon: capturingLocation
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
              ),
            ),
            SizedBox(
              width: compact
                  ? DriverH01Metrics.compactComposerColumnGap
                  : DriverH01Metrics.composerColumnGap,
            ),
            Expanded(
              child: TextField(
                key: const Key('operations-chat-composer'),
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverH01Metrics.composerInputSize,
                  height: DriverH01Metrics.composerInputHeight,
                ),
                decoration: const InputDecoration(
                  hintText: 'Message Operations',
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: DriverH01Metrics.composerInputPaddingHorizontal,
                    vertical: DriverH01Metrics.composerInputPaddingVertical,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: RoundsColors.lineStrong),
                    borderRadius: BorderRadius.all(
                      Radius.circular(DriverH01Metrics.composerRadius),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: RoundsColors.lineStrong),
                    borderRadius: BorderRadius.all(
                      Radius.circular(DriverH01Metrics.composerRadius),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF9CAAB8)),
                    borderRadius: BorderRadius.all(
                      Radius.circular(DriverH01Metrics.composerRadius),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: compact
                  ? DriverH01Metrics.compactComposerColumnGap
                  : DriverH01Metrics.composerColumnGap,
            ),
            SizedBox.square(
              dimension: compact
                  ? DriverH01Metrics.compactComposerControlSize
                  : DriverH01Metrics.composerControlSize,
              child: IconButton.filled(
                key: Key(
                  canSend ? 'operations-chat-send' : 'operations-chat-mic',
                ),
                onPressed: sending
                    ? null
                    : canSend
                    ? onSend
                    : onRecordVoice,
                style: IconButton.styleFrom(
                  backgroundColor: RoundsColors.ink,
                  disabledBackgroundColor: RoundsColors.line,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DriverH01Metrics.composerRadius,
                    ),
                  ),
                ),
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        canSend ? Icons.arrow_upward : Icons.mic_outlined,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StagedAttachment extends StatelessWidget {
  const _StagedAttachment({required this.attachment, required this.onRemove});

  final DriverMessageAttachmentModel attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: Key(
          attachment.kind == 'location'
              ? 'h01-staged-location'
              : 'h01-staged-${attachment.kind}',
        ),
        width: 168,
        height: 56,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: RoundsColors.line),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2EB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                attachment.kind == 'location'
                    ? Icons.location_on_outlined
                    : attachment.kind == 'voice'
                    ? Icons.mic_outlined
                    : attachment.kind == 'image'
                    ? Icons.photo_outlined
                    : Icons.insert_drive_file_outlined,
                size: 17,
                color: RoundsColors.warning,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.kind == 'location'
                        ? 'Location'
                        : attachment.kind == 'voice'
                        ? 'Voice note'
                        : attachment.kind == 'image'
                        ? 'Photo'
                        : 'File',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attachment.kind == 'location'
                        ? attachment.label
                        : attachment.fileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RoundsColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key(
                attachment.kind == 'location'
                    ? 'h01-remove-location'
                    : 'h01-remove-${attachment.kind}',
              ),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VoiceNoteSheet extends StatefulWidget {
  const _VoiceNoteSheet({required this.gateway});
  final DriverChatMediaGateway gateway;

  @override
  State<_VoiceNoteSheet> createState() => _VoiceNoteSheetState();
}

class _VoiceNoteSheetState extends State<_VoiceNoteSheet> {
  final _player = AudioPlayer();
  Timer? _timer;
  int _seconds = 0;
  bool _starting = true;
  bool _recording = false;
  DriverMessageAttachmentModel? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await widget.gateway.startVoice();
      if (!mounted) return;
      setState(() {
        _starting = false;
        _recording = true;
        _seconds = 0;
        _preview = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final preview = await widget.gateway.stopVoice();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _preview = preview;
    });
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    if (_recording) await widget.gateway.cancelVoice();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _play() async {
    final path = _preview?.localPath;
    if (path == null) return;
    await _player.setFilePath(path);
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preview == null ? 'VOICE NOTE' : 'VOICE READY',
              style: TextStyle(
                color: preview == null
                    ? RoundsColors.warning
                    : RoundsColors.green,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              preview == null ? 'Recording' : 'Preview before send',
              style: const TextStyle(
                color: RoundsColors.ink,
                fontSize: 30,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 14),
            if (_starting)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: RoundsColors.red))
            else if (preview == null)
              Text(
                _durationLabel(_seconds * 1000),
                key: const Key('h01-voice-timer'),
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              )
            else
              ListTile(
                key: const Key('h01-voice-preview'),
                contentPadding: EdgeInsets.zero,
                leading: IconButton.filled(
                  onPressed: _play,
                  icon: const Icon(Icons.play_arrow),
                ),
                title: const Text(
                  'Voice note',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  _durationLabel(preview.durationMilliseconds ?? 0),
                ),
              ),
            const SizedBox(height: 16),
            if (_recording)
              FilledButton(
                key: const Key('h01-stop-voice'),
                onPressed: _stop,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  backgroundColor: RoundsColors.ink,
                ),
                child: const Text('Stop recording'),
              )
            else if (preview != null) ...[
              FilledButton(
                key: const Key('h01-stage-voice'),
                onPressed: () => Navigator.of(context).pop(preview),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  backgroundColor: RoundsColors.ink,
                ),
                child: const Text('Add voice to message'),
              ),
              TextButton(onPressed: _start, child: const Text('Record again')),
            ],
            TextButton(
              onPressed: _cancel,
              child: const Text(
                'Cancel',
                style: TextStyle(color: RoundsColors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
