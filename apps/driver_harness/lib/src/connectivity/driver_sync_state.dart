import '../storage/harness_database.dart';
import 'package:sqflite/sqflite.dart';

enum DriverConnectionPhase { online, offline, reconnecting }

class DriverSyncSnapshot {
  const DriverSyncSnapshot({
    required this.phase,
    required this.assignedRoundAvailable,
    required this.currentRouteAvailable,
    required this.pendingProofCount,
    required this.pendingMessageCount,
    required this.pendingStatusCount,
    required this.pendingTelemetryCount,
    this.lastSyncedAt,
  });

  const DriverSyncSnapshot.online()
    : phase = DriverConnectionPhase.online,
      assignedRoundAvailable = false,
      currentRouteAvailable = false,
      pendingProofCount = 0,
      pendingMessageCount = 0,
      pendingStatusCount = 0,
      pendingTelemetryCount = 0,
      lastSyncedAt = null;

  final DriverConnectionPhase phase;
  final bool assignedRoundAvailable;
  final bool currentRouteAvailable;
  final int pendingProofCount;
  final int pendingMessageCount;
  final int pendingStatusCount;
  final int pendingTelemetryCount;
  final DateTime? lastSyncedAt;

  int get pendingProofAndStatusCount =>
      pendingProofCount + pendingStatusCount + pendingTelemetryCount;
  int get totalPending => pendingProofAndStatusCount + pendingMessageCount;
  bool get fullySynced => totalPending == 0;

  DriverSyncSnapshot copyWith({
    DriverConnectionPhase? phase,
    bool? assignedRoundAvailable,
    bool? currentRouteAvailable,
    DateTime? lastSyncedAt,
  }) => DriverSyncSnapshot(
    phase: phase ?? this.phase,
    assignedRoundAvailable:
        assignedRoundAvailable ?? this.assignedRoundAvailable,
    currentRouteAvailable: currentRouteAvailable ?? this.currentRouteAvailable,
    pendingProofCount: pendingProofCount,
    pendingMessageCount: pendingMessageCount,
    pendingStatusCount: pendingStatusCount,
    pendingTelemetryCount: pendingTelemetryCount,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
}

abstract interface class DriverQueueInspector {
  Future<DriverSyncSnapshot> inspect({
    required DriverConnectionPhase phase,
    required bool assignedRoundAvailable,
    required bool currentRouteAvailable,
    DateTime? lastSyncedAt,
  });
}

class SqliteDriverQueueInspector implements DriverQueueInspector {
  const SqliteDriverQueueInspector({this.databaseFactory});

  final Future<Database> Function()? databaseFactory;

  @override
  Future<DriverSyncSnapshot> inspect({
    required DriverConnectionPhase phase,
    required bool assignedRoundAvailable,
    required bool currentRouteAvailable,
    DateTime? lastSyncedAt,
  }) async {
    final db = await (databaseFactory ?? _openDatabase)();
    final commandRows = await db.rawQuery('''
      select command_type, count(*) as item_count
      from driver_command_outbox
      where status in ('pending', 'sending', 'blocked_dependency')
      group by command_type
    ''');
    var pendingMessages = 0;
    var pendingStatuses = 0;
    for (final row in commandRows) {
      final count = (row['item_count'] as num?)?.toInt() ?? 0;
      if (row['command_type'] == 'thread.send_message') {
        pendingMessages += count;
      } else {
        pendingStatuses += count;
      }
    }
    final queueRows = await Future.wait([
      db.rawQuery('''
        select count(*) as item_count from pod_evidence_outbox
        where status in ('local_saved','prepared','uploading','uploaded','pending_command')
      '''),
      db.rawQuery('''
        select count(*) as item_count from delivery_exception_evidence_outbox
        where status in ('local_saved','prepared','uploading','uploaded','pending_command')
      '''),
      db.rawQuery('''
        select count(*) as item_count from position_samples
        where upload_state = 'pending'
      '''),
      db.rawQuery('''
        select count(*) as item_count from message_media_outbox
        where status in ('pending', 'uploading')
      '''),
    ]);
    int count(List<Map<String, Object?>> rows) =>
        (rows.single['item_count'] as num?)?.toInt() ?? 0;

    return DriverSyncSnapshot(
      phase: phase,
      assignedRoundAvailable: assignedRoundAvailable,
      currentRouteAvailable: currentRouteAvailable,
      pendingProofCount: count(queueRows[0]) + count(queueRows[1]),
      pendingMessageCount: pendingMessages + count(queueRows[3]),
      pendingStatusCount: pendingStatuses,
      pendingTelemetryCount: count(queueRows[2]),
      lastSyncedAt: lastSyncedAt,
    );
  }

  static Future<Database> _openDatabase() async =>
      (await HarnessDatabase.open()).database;
}
