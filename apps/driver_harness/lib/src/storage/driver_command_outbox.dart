import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'harness_database.dart';

enum DriverCommandStatus {
  pending,
  sending,
  blockedDependency,
  conflict,
  committed,
  failedTerminal,
}

extension on DriverCommandStatus {
  String get storageValue => switch (this) {
    DriverCommandStatus.pending => 'pending',
    DriverCommandStatus.sending => 'sending',
    DriverCommandStatus.blockedDependency => 'blocked_dependency',
    DriverCommandStatus.conflict => 'conflict',
    DriverCommandStatus.committed => 'committed',
    DriverCommandStatus.failedTerminal => 'failed_terminal',
  };
}

class DriverCommandRecord {
  const DriverCommandRecord({
    required this.id,
    required this.commandType,
    required this.aggregateId,
    required this.expectedVersion,
    required this.idempotencyKey,
    required this.endpoint,
    required this.payloadJson,
    required this.occurredFromDeviceAt,
    required this.attempts,
    required this.status,
  });

  final String id;
  final String commandType;
  final String aggregateId;
  final int expectedVersion;
  final String idempotencyKey;
  final String endpoint;
  final String payloadJson;
  final String occurredFromDeviceAt;
  final int attempts;
  final String status;

  factory DriverCommandRecord.fromRow(Map<String, Object?> row) =>
      DriverCommandRecord(
        id: row['id']! as String,
        commandType: row['command_type']! as String,
        aggregateId: row['aggregate_id']! as String,
        expectedVersion: row['expected_version']! as int,
        idempotencyKey: row['idempotency_key']! as String,
        endpoint: row['endpoint']! as String,
        payloadJson: row['payload_json']! as String,
        occurredFromDeviceAt: row['occurred_from_device_at']! as String,
        attempts: row['attempts']! as int,
        status: row['status']! as String,
      );
}

class DriverCommandOutbox {
  DriverCommandOutbox(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final Database _database;
  final Uuid _uuid;

  static Future<DriverCommandOutbox> open() async {
    final database = await HarnessDatabase.open();
    return DriverCommandOutbox(database.database);
  }

  Future<DriverCommandRecord> enqueue({
    required String commandType,
    required String aggregateId,
    required int expectedVersion,
    required String idempotencyKey,
    required String endpoint,
    required Map<String, Object?> payload,
    List<String> dependencyIds = const [],
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.insert('driver_command_outbox', {
      'id': _uuid.v4(),
      'command_type': commandType,
      'aggregate_id': aggregateId,
      'expected_version': expectedVersion,
      'idempotency_key': idempotencyKey,
      'endpoint': endpoint,
      'payload_json': jsonEncode(payload),
      'dependency_ids_json': jsonEncode(dependencyIds),
      'created_at': now,
      'occurred_from_device_at': now,
      'attempts': 0,
      'status': DriverCommandStatus.pending.storageValue,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await _database.query(
      'driver_command_outbox',
      where: 'idempotency_key = ?',
      whereArgs: [idempotencyKey],
      limit: 1,
    );
    return DriverCommandRecord.fromRow(rows.single);
  }

  Future<List<DriverCommandRecord>> readyToSend() async {
    final rows = await _database.query(
      'driver_command_outbox',
      where: 'status in (?, ?)',
      whereArgs: [
        DriverCommandStatus.pending.storageValue,
        DriverCommandStatus.sending.storageValue,
      ],
      orderBy: 'created_at asc',
    );
    return rows.map(DriverCommandRecord.fromRow).toList(growable: false);
  }

  Future<List<DriverCommandRecord>> pendingByType(String commandType) async {
    final rows = await _database.query(
      'driver_command_outbox',
      where: 'command_type = ? and status in (?, ?)',
      whereArgs: [
        commandType,
        DriverCommandStatus.pending.storageValue,
        DriverCommandStatus.sending.storageValue,
      ],
      orderBy: 'created_at asc',
    );
    return rows.map(DriverCommandRecord.fromRow).toList(growable: false);
  }

  Future<void> markSending(DriverCommandRecord command) => _database.update(
    'driver_command_outbox',
    {
      'status': DriverCommandStatus.sending.storageValue,
      'attempts': command.attempts + 1,
      'last_error': null,
    },
    where: 'id = ?',
    whereArgs: [command.id],
  );

  Future<void> markPending(String id, String error) => _database.update(
    'driver_command_outbox',
    {
      'status': DriverCommandStatus.pending.storageValue,
      'last_error': error,
      'next_retry_at': DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 15))
          .toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> markCommitted(String id) =>
      _mark(id, DriverCommandStatus.committed, error: null);

  Future<void> markConflict(String id, String error) =>
      _mark(id, DriverCommandStatus.conflict, error: error);

  Future<void> markFailedTerminal(String id, String error) =>
      _mark(id, DriverCommandStatus.failedTerminal, error: error);

  Future<void> _mark(
    String id,
    DriverCommandStatus status, {
    required String? error,
  }) => _database.update(
    'driver_command_outbox',
    {'status': status.storageValue, 'last_error': error},
    where: 'id = ?',
    whereArgs: [id],
  );
}
