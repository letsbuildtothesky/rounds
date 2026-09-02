import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'harness_database.dart';

class DeliveryExceptionEvidenceRecord {
  const DeliveryExceptionEvidenceRecord({
    required this.id,
    required this.stopId,
    required this.expectedStopVersion,
    required this.manifestId,
    required this.manifestVersion,
    required this.category,
    required this.localPath,
    required this.sha256,
    required this.byteSize,
    required this.contentType,
    required this.idempotencyKey,
    required this.status,
    required this.uploadOffset,
    this.note,
    this.mediaAssetId,
    this.storageBucket,
    this.storagePath,
    this.tusEndpoint,
    this.uploadUrl,
  });

  final String id;
  final String stopId;
  final int expectedStopVersion;
  final String manifestId;
  final int manifestVersion;
  final String category;
  final String? note;
  final String localPath;
  final String sha256;
  final int byteSize;
  final String contentType;
  final String? mediaAssetId;
  final String? storageBucket;
  final String? storagePath;
  final String? tusEndpoint;
  final String? uploadUrl;
  final int uploadOffset;
  final String idempotencyKey;
  final String status;

  factory DeliveryExceptionEvidenceRecord.fromRow(Map<String, Object?> row) =>
      DeliveryExceptionEvidenceRecord(
        id: row['id']! as String,
        stopId: row['stop_id']! as String,
        expectedStopVersion: row['expected_stop_version']! as int,
        manifestId: row['manifest_id']! as String,
        manifestVersion: row['manifest_version']! as int,
        category: row['category']! as String,
        note: row['note'] as String?,
        localPath: row['local_path']! as String,
        sha256: row['sha256']! as String,
        byteSize: row['byte_size']! as int,
        contentType: row['content_type']! as String,
        mediaAssetId: row['media_asset_id'] as String?,
        storageBucket: row['storage_bucket'] as String?,
        storagePath: row['storage_path'] as String?,
        tusEndpoint: row['tus_endpoint'] as String?,
        uploadUrl: row['upload_url'] as String?,
        uploadOffset: row['upload_offset']! as int,
        idempotencyKey: row['idempotency_key']! as String,
        status: row['status']! as String,
      );
}

class DeliveryExceptionEvidenceOutbox {
  DeliveryExceptionEvidenceOutbox(this._database);
  final Database _database;

  static Future<DeliveryExceptionEvidenceOutbox> open() async =>
      DeliveryExceptionEvidenceOutbox((await HarnessDatabase.open()).database);

  Future<DeliveryExceptionEvidenceRecord> saveLocal({
    required String stopId,
    required int expectedStopVersion,
    required String manifestId,
    required int manifestVersion,
    required String category,
    required String localPath,
    required String sha256,
    required int byteSize,
    required String contentType,
    String? note,
  }) async {
    final existing = await forStop(stopId);
    if (existing != null &&
        existing.sha256 == sha256 &&
        existing.category == category &&
        existing.status != 'failed_terminal') {
      await _update(existing.id, {'note': note});
      return (await byId(existing.id))!;
    }
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.insert('delivery_exception_evidence_outbox', {
      'id': id,
      'stop_id': stopId,
      'expected_stop_version': expectedStopVersion,
      'manifest_id': manifestId,
      'manifest_version': manifestVersion,
      'category': category,
      'note': note,
      'local_path': localPath,
      'sha256': sha256,
      'byte_size': byteSize,
      'content_type': contentType,
      'idempotency_key': 'delivery-problem:$stopId:$category:$sha256',
      'status': 'local_saved',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return (await byId(id))!;
  }

  Future<DeliveryExceptionEvidenceRecord?> forStop(String stopId) async {
    final rows = await _database.query(
      'delivery_exception_evidence_outbox',
      where: 'stop_id = ?',
      whereArgs: [stopId],
      orderBy: 'created_at desc',
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : DeliveryExceptionEvidenceRecord.fromRow(rows.first);
  }

  Future<DeliveryExceptionEvidenceRecord?> byId(String id) async {
    final rows = await _database.query(
      'delivery_exception_evidence_outbox',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : DeliveryExceptionEvidenceRecord.fromRow(rows.first);
  }

  Future<List<DeliveryExceptionEvidenceRecord>>
  pending() async => (await _database.query(
    'delivery_exception_evidence_outbox',
    where:
        "status in ('local_saved','prepared','uploading','uploaded','pending_command')",
    orderBy: 'created_at',
  )).map(DeliveryExceptionEvidenceRecord.fromRow).toList(growable: false);

  Future<DeliveryExceptionEvidenceRecord> markPrepared(
    String id,
    Map<String, dynamic> prepared,
  ) async {
    await _update(id, {
      'media_asset_id': prepared['mediaAssetId'],
      'storage_bucket': prepared['bucket'],
      'storage_path': prepared['path'],
      'tus_endpoint': prepared['tusEndpoint'],
      'status': prepared['assetState'] == 'staged' ? 'prepared' : 'uploaded',
      'last_error': null,
    });
    return (await byId(id))!;
  }

  Future<void> markUploadUrl(String id, String uploadUrl) =>
      _update(id, {'upload_url': uploadUrl, 'status': 'uploading'});
  Future<void> markOffset(String id, int offset) =>
      _update(id, {'upload_offset': offset, 'status': 'uploading'});
  Future<DeliveryExceptionEvidenceRecord> resetUploadSession(String id) async {
    await _update(id, {
      'upload_url': null,
      'upload_offset': 0,
      'status': 'prepared',
    });
    return (await byId(id))!;
  }

  Future<void> markUploaded(String id) => _update(id, {'status': 'uploaded'});
  Future<void> markPendingCommand(String id) =>
      _update(id, {'status': 'pending_command'});
  Future<void> markCompleted(String id) =>
      _update(id, {'status': 'completed', 'last_error': null});
  Future<void> markPending(String id, Object error) async {
    await _database.rawUpdate(
      'update delivery_exception_evidence_outbox set attempts = attempts + 1 where id = ?',
      [id],
    );
    await _update(id, {'last_error': error.toString()});
  }

  Future<void> markFailed(String id, String error) =>
      _update(id, {'status': 'failed_terminal', 'last_error': error});

  Future<void> _update(String id, Map<String, Object?> values) =>
      _database.update(
        'delivery_exception_evidence_outbox',
        Map<String, Object?>.from(values)
          ..['updated_at'] = DateTime.now().toUtc().toIso8601String(),
        where: 'id = ?',
        whereArgs: [id],
      );
}
