import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

/// A read-only preservation preflight, NOT an importer or permission to sync.
/// Never infer principal/assignment from the currently signed-in driver.
class LegacyUpgradeInventory {
  const LegacyUpgradeInventory._(this.rows);
  final List<LegacyPreservationRow> rows;
  bool get maySwitchClient =>
      false; // Encryption/conversion still unimplemented.

  static const requiredColumns = {
    'navigation_intents': ['logical_key', 'stop_id', 'destination_version'],
    'position_samples': ['sequence', 'captured_at', 'upload_state'],
    'harness_events': ['id', 'occurred_at', 'payload_json'],
    'driver_command_outbox': [
      'id',
      'idempotency_key',
      'payload_json',
      'endpoint',
      'occurred_from_device_at',
      'dependency_ids_json',
      'expected_version',
      'status',
    ],
    'pod_evidence_outbox': [
      'id',
      'local_path',
      'sha256',
      'byte_size',
      'upload_offset',
      'idempotency_key',
      'created_at',
      'status',
    ],
    'delivery_exception_evidence_outbox': [
      'id',
      'local_path',
      'sha256',
      'byte_size',
      'upload_offset',
      'idempotency_key',
      'created_at',
      'status',
    ],
    'message_media_outbox': [
      'id',
      'attachments_json',
      'idempotency_key',
      'created_at',
      'status',
    ],
  };

  /// Opens only an existing explicit path, without HarnessDatabase.open(),
  /// version callbacks, schema updates, or any filesystem/media cleanup.
  static Future<LegacyUpgradeInventory> inspect({
    required String databasePath,
    required DatabaseFactory factory,
  }) async {
    if (!await File(databasePath).exists()) {
      throw const LegacyInventoryException('LEGACY_DATABASE_MISSING');
    }
    Database? db;
    try {
      db = await factory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      return await db.transaction((tx) async {
        final version = (await tx.rawQuery(
          'PRAGMA user_version',
        )).single.values.single;
        if (version != 5) {
          throw const LegacyInventoryException('UNSUPPORTED_LEGACY_VERSION');
        }
        final tables = (await tx.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        )).map((row) => row['name']).toSet();
        // Never silently omit a table written by an unrecognised client.
        if (tables.difference({
              ...requiredColumns.keys,
              'android_metadata',
            }).isNotEmpty ||
            !tables.containsAll(requiredColumns.keys)) {
          throw const LegacyInventoryException('UNRECOGNISED_LEGACY_SCHEMA');
        }
        final result = <LegacyPreservationRow>[];
        for (final entry in requiredColumns.entries) {
          final columns = (await tx.rawQuery(
            'PRAGMA table_info(${entry.key})',
          )).map((row) => row['name']).toSet();
          if (!columns.containsAll(entry.value)) {
            throw const LegacyInventoryException('UNRECOGNISED_LEGACY_SCHEMA');
          }
          final key = entry.key == 'navigation_intents'
              ? 'logical_key'
              : entry.key == 'position_samples'
              ? 'sequence'
              : 'id';
          var offset = 0;
          while (true) {
            final batch = await tx.query(
              entry.key,
              orderBy: key,
              limit: 256,
              offset: offset,
            );
            for (final row in batch) {
              if (result.length >= 100000) {
                throw const LegacyInventoryException('LEGACY_INVENTORY_LIMIT');
              }
              result.add(
                LegacyPreservationRow(
                  table: entry.key,
                  sourceId: row[key].toString(),
                  // Hash the ENTIRE raw row: do not parse/re-encode payload_json
                  // or drop upload URLs, offsets, errors, old IDs or timestamps.
                  rowSha256: sha256
                      .convert(utf8.encode(jsonEncode(_stableRow(row))))
                      .toString(),
                  status: row['status'] is String
                      ? row['status'] as String
                      : null,
                  requiresOriginalFence:
                      entry.key == 'driver_command_outbox' ||
                      entry.key == 'pod_evidence_outbox' ||
                      entry.key == 'delivery_exception_evidence_outbox',
                ),
              );
            }
            if (batch.length < 256) break;
            offset += batch.length;
          }
        }
        return LegacyUpgradeInventory._(List.unmodifiable(result));
      }, exclusive: false);
    } on LegacyInventoryException {
      rethrow;
    } catch (_) {
      throw const LegacyInventoryException('LEGACY_INSPECTION_FAILED');
    } finally {
      await db?.close();
    }
  }

  static Map<String, Object?> _stableRow(Map<String, Object?> row) => {
    for (final key in row.keys.toList()..sort())
      key: row[key] is Uint8List
          ? {'sqlite_blob': base64Encode(row[key] as Uint8List)}
          : row[key],
  };
}

class LegacyPreservationRow {
  const LegacyPreservationRow({
    required this.table,
    required this.sourceId,
    required this.rowSha256,
    required this.status,
    required this.requiresOriginalFence,
  });
  final String table, sourceId, rowSha256;
  final String? status;
  final bool requiresOriginalFence;

  // Legacy v5 rows have no per-record principal or original assignment fence.
  // Even committed/empty queues do not prove file verification or deletion rights.
  List<String> get recoveryReasons => [
    'ORIGINAL_PRINCIPAL_UNPROVEN',
    if (requiresOriginalFence) 'ORIGINAL_ASSIGNMENT_UNPROVEN',
  ];
  bool get eligibleForAutomaticReplay => false;
}

class LegacyInventoryException implements Exception {
  const LegacyInventoryException(this.code);
  final String code;
  @override
  String toString() => 'LegacyInventoryException($code)';
}
