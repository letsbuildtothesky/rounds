import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'harness_database.dart';

class PodEvidenceRecord {
  const PodEvidenceRecord({
    required this.id,
    required this.stopId,
    required this.expectedStopVersion,
    required this.manifestId,
    required this.manifestVersion,
    required this.confirmedLineNumbers,
    required this.localPath,
    required this.sha256,
    required this.byteSize,
    required this.contentType,
    required this.handoffType,
    required this.idempotencyKey,
    required this.status,
    required this.uploadOffset,
    this.receiverName,
    this.receiverRelationship,
    this.leftAtLocation,
    this.note,
    this.mediaAssetId,
    this.storageBucket,
    this.storagePath,
    this.tusEndpoint,
    this.uploadSignature,
    this.uploadUrl,
  });

  final String id;
  final String stopId;
  final int expectedStopVersion;
  final String manifestId;
  final int manifestVersion;
  final List<int> confirmedLineNumbers;
  final String localPath;
  final String sha256;
  final int byteSize;
  final String contentType;
  final String handoffType;
  final String? receiverName;
  final String? receiverRelationship;
  final String? leftAtLocation;
  final String? note;
  final String? mediaAssetId;
  final String? storageBucket;
  final String? storagePath;
  final String? tusEndpoint;
  final String? uploadSignature;
  final String? uploadUrl;
  final int uploadOffset;
  final String idempotencyKey;
  final String status;

  factory PodEvidenceRecord.fromRow(Map<String, Object?> row) =>
      PodEvidenceRecord(
        id: row['id']! as String,
        stopId: row['stop_id']! as String,
        expectedStopVersion: row['expected_stop_version']! as int,
        manifestId: row['manifest_id']! as String,
        manifestVersion: row['manifest_version']! as int,
        confirmedLineNumbers:
            (jsonDecode(row['confirmed_line_numbers_json']! as String)
                    as List<dynamic>)
                .cast<int>(),
        localPath: row['local_path']! as String,
        sha256: row['sha256']! as String,
        byteSize: row['byte_size']! as int,
        contentType: row['content_type']! as String,
        handoffType: row['handoff_type']! as String,
        receiverName: row['receiver_name'] as String?,
        receiverRelationship: row['receiver_relationship'] as String?,
        leftAtLocation: row['left_at_location'] as String?,
        note: row['note'] as String?,
        mediaAssetId: row['media_asset_id'] as String?,
        storageBucket: row['storage_bucket'] as String?,
        storagePath: row['storage_path'] as String?,
        tusEndpoint: row['tus_endpoint'] as String?,
        uploadSignature: row['upload_signature'] as String?,
        uploadUrl: row['upload_url'] as String?,
        uploadOffset: row['upload_offset']! as int,
        idempotencyKey: row['idempotency_key']! as String,
        status: row['status']! as String,
      );
}

class PodEvidenceOutbox {
  PodEvidenceOutbox(this._database);
  final Database _database;

  static Future<PodEvidenceOutbox> open() async =>
      PodEvidenceOutbox((await HarnessDatabase.open()).database);

  Future<PodEvidenceRecord> saveLocal({
    required String stopId,
    required int expectedStopVersion,
    required String manifestId,
    required int manifestVersion,
    required List<int> confirmedLineNumbers,
    required String localPath,
    required String sha256,
    required int byteSize,
    required String contentType,
    required String handoffType,
    String? receiverName,
    String? receiverRelationship,
    String? leftAtLocation,
    String? note,
  }) async {
    final existing = await forStop(stopId);
    if (existing != null &&
        existing.sha256 == sha256 &&
        existing.status != 'failed_terminal') {
      return existing;
    }
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.insert('pod_evidence_outbox', {
      'id': id,
      'stop_id': stopId,
      'expected_stop_version': expectedStopVersion,
      'manifest_id': manifestId,
      'manifest_version': manifestVersion,
      'confirmed_line_numbers_json': jsonEncode(confirmedLineNumbers),
      'local_path': localPath,
      'sha256': sha256,
      'byte_size': byteSize,
      'content_type': contentType,
      'handoff_type': handoffType,
      'receiver_name': receiverName,
      'receiver_relationship': receiverRelationship,
      'left_at_location': leftAtLocation,
      'note': note,
      'idempotency_key': 'stop-pod:$stopId:$sha256',
      'status': 'local_saved',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return (await byId(id))!;
  }

  Future<PodEvidenceRecord?> forStop(String stopId) async {
    final rows = await _database.query(
      'pod_evidence_outbox',
      where: 'stop_id = ?',
      whereArgs: [stopId],
      orderBy: 'created_at desc',
      limit: 1,
    );
    return rows.isEmpty ? null : PodEvidenceRecord.fromRow(rows.first);
  }

  Future<PodEvidenceRecord?> byId(String id) async {
    final rows = await _database.query(
      'pod_evidence_outbox',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PodEvidenceRecord.fromRow(rows.first);
  }

  Future<List<PodEvidenceRecord>> pending() async => (await _database.query(
    'pod_evidence_outbox',
    where:
        "status in ('local_saved','prepared','uploading','uploaded','pending_command')",
    orderBy: 'created_at',
  )).map(PodEvidenceRecord.fromRow).toList(growable: false);

  Future<PodEvidenceRecord> markPrepared(
    String id,
    Map<String, dynamic> prepared,
  ) async {
    await _update(id, {
      'media_asset_id': prepared['mediaAssetId'],
      'storage_bucket': prepared['bucket'],
      'storage_path': prepared['path'],
      'tus_endpoint': prepared['tusEndpoint'],
      'upload_signature': null,
      'status': prepared['assetState'] == 'staged' ? 'prepared' : 'uploaded',
      'last_error': null,
    });
    return (await byId(id))!;
  }

  Future<void> markUploadUrl(String id, String uploadUrl) =>
      _update(id, {'upload_url': uploadUrl, 'status': 'uploading'});
  Future<void> markOffset(String id, int offset) =>
      _update(id, {'upload_offset': offset, 'status': 'uploading'});
  Future<PodEvidenceRecord> resetUploadSession(String id) async {
    await _update(id, {
      'upload_url': null,
      'upload_offset': 0,
      'status': 'prepared',
    });
    return (await byId(id))!;
  }

  Future<void> markUploaded(String id) => _update(id, {'status': 'uploaded'});
  Future<void> markPending(String id, Object error) => _update(id, {
    'last_error': error.toString(),
    'attempts': const _Increment(),
  });
  Future<void> markPendingCommand(String id) =>
      _update(id, {'status': 'pending_command'});
  Future<void> markCompleted(String id) =>
      _update(id, {'status': 'completed', 'last_error': null});
  Future<void> markFailed(String id, String error) =>
      _update(id, {'status': 'failed_terminal', 'last_error': error});

  Future<void> _update(String id, Map<String, Object?> values) async {
    final next = Map<String, Object?>.from(values)
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    if (next['attempts'] is _Increment) {
      next.remove('attempts');
      await _database.rawUpdate(
        'update pod_evidence_outbox set attempts = attempts + 1 where id = ?',
        [id],
      );
    }
    await _database.update(
      'pod_evidence_outbox',
      next,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class _Increment {
  const _Increment();
}
