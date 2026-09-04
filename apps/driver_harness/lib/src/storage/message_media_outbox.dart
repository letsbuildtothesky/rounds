import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../driver/driver_operations_thread.dart';
import 'harness_database.dart';

class MessageMediaOutboxRecord {
  const MessageMediaOutboxRecord({
    required this.id,
    required this.roundId,
    required this.stopId,
    required this.body,
    required this.attachments,
    required this.idempotencyKey,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String roundId;
  final String stopId;
  final String body;
  final List<DriverMessageAttachmentModel> attachments;
  final String idempotencyKey;
  final String status;
  final DateTime createdAt;

  factory MessageMediaOutboxRecord.fromRow(Map<String, Object?> row) =>
      MessageMediaOutboxRecord(
        id: row['id']! as String,
        roundId: row['round_id']! as String,
        stopId: row['stop_id']! as String,
        body: row['body']! as String,
        attachments: (jsonDecode(row['attachments_json']! as String) as List)
            .map(
              (value) => DriverMessageAttachmentModel.fromJson(
                value as Map<String, dynamic>,
                local: true,
              ),
            )
            .toList(growable: false),
        idempotencyKey: row['idempotency_key']! as String,
        status: row['status']! as String,
        createdAt: DateTime.parse(row['created_at']! as String),
      );
}

class MessageMediaOutbox {
  MessageMediaOutbox(this._database);
  final Database _database;

  static Future<MessageMediaOutbox> open() async =>
      MessageMediaOutbox((await HarnessDatabase.open()).database);

  Future<MessageMediaOutboxRecord> save({
    required String roundId,
    required String stopId,
    required String body,
    required List<DriverMessageAttachmentModel> attachments,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.insert('message_media_outbox', {
      'id': id,
      'round_id': roundId,
      'stop_id': stopId,
      'body': body,
      'attachments_json': jsonEncode(
        attachments.map((value) => value.toLocalJson()).toList(),
      ),
      'idempotency_key': 'driver-rich-message:$stopId:$id',
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
    return (await byId(id))!;
  }

  Future<MessageMediaOutboxRecord?> byId(String id) async {
    final rows = await _database.query(
      'message_media_outbox',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : MessageMediaOutboxRecord.fromRow(rows.single);
  }

  Future<List<MessageMediaOutboxRecord>> pending({String? stopId}) async {
    final rows = await _database.query(
      'message_media_outbox',
      where: stopId == null
          ? "status in ('pending','uploading')"
          : "stop_id = ? and status in ('pending','uploading')",
      whereArgs: stopId == null ? null : [stopId],
      orderBy: 'created_at',
    );
    return rows.map(MessageMediaOutboxRecord.fromRow).toList(growable: false);
  }

  Future<MessageMediaOutboxRecord> updateAttachments(
    String id,
    List<DriverMessageAttachmentModel> attachments,
  ) async {
    await _update(id, {
      'attachments_json': jsonEncode(
        attachments.map((value) => value.toLocalJson()).toList(),
      ),
      'status': 'uploading',
      'last_error': null,
    });
    return (await byId(id))!;
  }

  Future<void> markPending(String id, Object error) => _update(id, {
    'status': 'pending',
    'last_error': error.toString(),
    'attempts': const _Increment(),
  });

  Future<void> remove(String id) => _database.delete(
    'message_media_outbox',
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> _update(String id, Map<String, Object?> values) async {
    final next = Map<String, Object?>.from(values)
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    if (next.remove('attempts') is _Increment) {
      await _database.rawUpdate(
        'update message_media_outbox set attempts = attempts + 1 where id = ?',
        [id],
      );
    }
    await _database.update(
      'message_media_outbox',
      next,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class _Increment {
  const _Increment();
}
