import 'driver_operations_thread.dart';
import 'driver_session.dart';

enum DriverContactHistoryEventKind {
  driverMessage,
  operationsMessage,
  system,
  recipientCall,
  operationsCall,
}

class DriverContactHistoryEventModel {
  const DriverContactHistoryEventModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.occurredAt,
    this.outcome,
    this.savedLocally = false,
  });

  final String id;
  final DriverContactHistoryEventKind kind;
  final String title;
  final String detail;
  final DateTime occurredAt;
  final String? outcome;
  final bool savedLocally;

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
  final locationOnly =
      message.body.trim().isEmpty && message.attachments.isNotEmpty;
  if (message.sender == 'driver') {
    return DriverContactHistoryEventModel(
      id: 'message:${message.id}',
      kind: DriverContactHistoryEventKind.driverMessage,
      title: locationOnly ? 'Location shared' : 'Message to Operations',
      detail: humanDetail,
      occurredAt: message.sentAt,
      savedLocally: message.savedLocally,
    );
  }
  if (message.sender == 'operations') {
    return DriverContactHistoryEventModel(
      id: 'message:${message.id}',
      kind: DriverContactHistoryEventKind.operationsMessage,
      title: locationOnly ? 'Operations location' : 'Operations message',
      detail: humanDetail,
      occurredAt: message.sentAt,
      savedLocally: message.savedLocally,
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
    );
  }
  final separator = message.body.indexOf(' · ');
  final title = separator < 0
      ? 'Rounds update'
      : message.body.substring(0, separator);
  final detail = separator < 0
      ? message.body
      : message.body.substring(separator + 3);
  return DriverContactHistoryEventModel(
    id: 'system:${message.id}',
    kind: DriverContactHistoryEventKind.system,
    title: title,
    detail: detail,
    occurredAt: message.sentAt,
    savedLocally: message.savedLocally,
  );
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
    );

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
