import 'driver_operations_thread.dart';
import 'driver_session.dart';

enum DriverContactHistoryEventKind {
  driverMessage,
  operationsMessage,
  system,
  recipientCall,
  operationsCall,
}

enum DriverContactHistoryEventTone { ink, orange, green, red }

class DriverContactHistoryEventModel {
  const DriverContactHistoryEventModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.occurredAt,
    this.outcome,
    this.savedLocally = false,
    this.tone,
    this.quoteDetail = false,
    this.detailHighlight,
  });

  final String id;
  final DriverContactHistoryEventKind kind;
  final String title;
  final String detail;
  final DateTime occurredAt;
  final String? outcome;
  final bool savedLocally;
  final DriverContactHistoryEventTone? tone;
  final bool quoteDetail;
  final String? detailHighlight;

  bool get copyable =>
      kind == DriverContactHistoryEventKind.driverMessage ||
      kind == DriverContactHistoryEventKind.operationsMessage;
}

class DriverContactHistoryModel {
  const DriverContactHistoryModel({
    required this.events,
    required this.savedHistory,
  });

  final List<DriverContactHistoryEventModel> events;
  final bool savedHistory;
}

DriverContactHistoryModel composeDriverContactHistory({
  required List<DriverOperationsMessageModel> messages,
  required List<DriverContactAttemptModel> contactAttempts,
  required bool threadUnavailable,
}) {
  final attemptsBySemanticKey = <String>{
    for (final attempt in contactAttempts)
      '${attempt.target}:${attempt.outcome}',
  };
  final events =
      <DriverContactHistoryEventModel>[
        for (final message in messages)
          if (!_duplicatesTypedCall(message, attemptsBySemanticKey))
            _messageEvent(message),
        for (final attempt in contactAttempts) _callEvent(attempt),
      ]..sort((left, right) {
        final time = left.occurredAt.compareTo(right.occurredAt);
        return time == 0 ? left.id.compareTo(right.id) : time;
      });
  return DriverContactHistoryModel(
    events: List.unmodifiable(events),
    savedHistory:
        threadUnavailable || events.any((event) => event.savedLocally),
  );
}

bool _duplicatesTypedCall(
  DriverOperationsMessageModel message,
  Set<String> attempts,
) {
  if (message.sender != 'system') return false;
  final parsed = _parseSystemCall(message.body);
  return parsed != null && attempts.contains('${parsed.$1}:${parsed.$2}');
}

DriverContactHistoryEventModel _messageEvent(
  DriverOperationsMessageModel message,
) {
  final attachmentReferences = message.attachments
      .map((attachment) => attachment.copyReference)
      .toList(growable: false);
  final humanDetail = [
    if (message.body.trim().isNotEmpty) message.body.trim(),
    ...attachmentReferences,
  ].join('\n');
  final attachmentOnly =
      message.body.trim().isEmpty && message.attachments.isNotEmpty;
  final attachmentTitle = message.attachments.length == 1
      ? switch (message.attachments.single.kind) {
          'location' => 'Location shared',
          'image' => 'Photo shared',
          'file' => 'File shared',
          'voice' => 'Voice note shared',
          _ => 'Attachment shared',
        }
      : 'Attachments shared';
  if (message.sender == 'driver') {
    return DriverContactHistoryEventModel(
      id: 'message:${message.id}',
      kind: DriverContactHistoryEventKind.driverMessage,
      title: attachmentOnly ? attachmentTitle : 'Message to Operations',
      detail: humanDetail,
      occurredAt: message.sentAt,
      savedLocally: message.savedLocally,
      tone: DriverContactHistoryEventTone.ink,
      quoteDetail: !attachmentOnly,
    );
  }
  if (message.sender == 'operations') {
    return DriverContactHistoryEventModel(
      id: 'message:${message.id}',
      kind: DriverContactHistoryEventKind.operationsMessage,
      title: attachmentOnly
          ? 'Operations $attachmentTitle'
          : 'Operations message',
      detail: humanDetail,
      occurredAt: message.sentAt,
      savedLocally: message.savedLocally,
      tone: DriverContactHistoryEventTone.ink,
      quoteDetail: !attachmentOnly,
    );
  }
  final parsedCall = _parseSystemCall(message.body);
  if (parsedCall != null) {
    final target = parsedCall.$1;
    final outcome = parsedCall.$2;
    return DriverContactHistoryEventModel(
      id: 'system-call:${message.id}',
      kind: target == 'recipient'
          ? DriverContactHistoryEventKind.recipientCall
          : DriverContactHistoryEventKind.operationsCall,
      title: target == 'recipient' ? 'Recipient call' : 'Operations call',
      detail: _outcomeLabel(outcome),
      outcome: outcome,
      occurredAt: message.sentAt,
      savedLocally: message.savedLocally,
      tone: outcome == 'reached'
          ? DriverContactHistoryEventTone.green
          : DriverContactHistoryEventTone.red,
    );
  }
  final (title, detail) = _splitSystemBody(message.body);
  return DriverContactHistoryEventModel(
    id: 'system:${message.id}',
    kind: DriverContactHistoryEventKind.system,
    title: title,
    detail: detail,
    occurredAt: message.sentAt,
    savedLocally: message.savedLocally,
    tone: _systemTone(title),
    detailHighlight: title == 'Handoff approved'
        ? _detailAfterLastSeparator(detail)
        : null,
  );
}

(String, String) _splitSystemBody(String body) {
  final normalized = body.trim();
  final newline = normalized.indexOf('\n');
  if (newline >= 0) {
    return (
      normalized.substring(0, newline).trim(),
      normalized.substring(newline + 1).trim(),
    );
  }
  final separator = normalized.indexOf(' · ');
  if (separator >= 0) {
    return (
      normalized.substring(0, separator).trim(),
      normalized.substring(separator + 3).trim(),
    );
  }
  return ('Rounds update', normalized);
}

DriverContactHistoryEventModel _callEvent(DriverContactAttemptModel attempt) =>
    DriverContactHistoryEventModel(
      id: 'call:${attempt.id}',
      kind: attempt.target == 'recipient'
          ? DriverContactHistoryEventKind.recipientCall
          : DriverContactHistoryEventKind.operationsCall,
      title: attempt.target == 'recipient'
          ? 'Recipient call'
          : 'Operations call',
      detail: _outcomeLabel(attempt.outcome),
      outcome: attempt.outcome,
      occurredAt: attempt.occurredAt,
      savedLocally: attempt.savedLocally,
      tone: attempt.outcome == 'reached'
          ? DriverContactHistoryEventTone.green
          : DriverContactHistoryEventTone.red,
    );

DriverContactHistoryEventTone _systemTone(String title) {
  return switch (title.toLowerCase()) {
    'pickup verified' ||
    'update acknowledged' ||
    'handoff approved' ||
    'pod saved' => DriverContactHistoryEventTone.green,
    _ => DriverContactHistoryEventTone.orange,
  };
}

String? _detailAfterLastSeparator(String detail) {
  final separator = detail.lastIndexOf(' · ');
  if (separator < 0 || separator + 3 >= detail.length) return null;
  return detail.substring(separator + 3);
}

(String, String)? _parseSystemCall(String body) {
  final match = RegExp(
    r'^(Recipient|Operations) call · (Reached|No answer|Busy|Call failed)$',
    caseSensitive: false,
  ).firstMatch(body.trim());
  if (match == null) return null;
  final target = match.group(1)!.toLowerCase();
  final outcome = switch (match.group(2)!.toLowerCase()) {
    'reached' => 'reached',
    'no answer' => 'no_answer',
    'busy' => 'busy',
    'call failed' => 'call_failed',
    _ => '',
  };
  return (target, outcome);
}

String _outcomeLabel(String value) => switch (value) {
  'reached' => 'Reached',
  'no_answer' => 'No answer',
  'busy' => 'Busy / declined',
  'call_failed' => 'Call failed',
  _ => value,
};
