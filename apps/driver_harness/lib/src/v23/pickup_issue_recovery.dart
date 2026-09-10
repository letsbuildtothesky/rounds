import 'execution_query.dart';

enum PickupIssueReadPhase {
  notRequested,
  loading,
  waiting,
  instructions,
  failed,
}

/// Presentation facts for the existing G03 host, not execution authority.
/// A last-known instruction stays visibly stale during a refresh/failure.
/// No stored query changes an observation, receipt, readiness or departure.
class PickupIssueRecovery {
  const PickupIssueRecovery({
    this.phase = PickupIssueReadPhase.notRequested,
    this.snapshot,
    this.errorCode,
  });

  final PickupIssueReadPhase phase;
  final DriverPickupIssueSnapshot? snapshot;
  final String? errorCode;

  bool get isLastKnown =>
      snapshot != null &&
      phase != PickupIssueReadPhase.waiting &&
      phase != PickupIssueReadPhase.instructions;

  int? get issueVersion => snapshot?.toJson()['data']['issue_version'] as int?;
  String? get issueState => snapshot?.toJson()['data']['state'] as String?;
  String? get departureGate =>
      snapshot?.toJson()['data']['departure_gate'] as String?;
  String? get asOf => snapshot?.toJson()['as_of'] as String?;
  Map<String, dynamic>? get _decision {
    final decisions = snapshot?.toJson()['data']['decisions'] as List?;
    return decisions == null || decisions.isEmpty
        ? null
        : decisions.single as Map<String, dynamic>;
  }

  String? get action => _decision?['action'] as String?;
  String? get instructions => _decision?['instructions'] as String?;
  String? get decisionId => _decision?['id'] as String?;

  @override
  String toString() => 'PickupIssueRecovery(${phase.name}, redacted)';
}
