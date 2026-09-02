import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/storage/delivery_exception_evidence_outbox.dart';
import 'package:rounds_driver_harness/src/storage/harness_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('damage evidence survives restart with exact resumable state', () async {
    final directory = await Directory.systemTemp.createTemp(
      'rounds-damage-outbox-',
    );
    final databasePath = '${directory.path}/damage.db';
    try {
      var database = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, _) =>
              HarnessDatabase.createDeliveryExceptionEvidenceSchema(database),
        ),
      );
      var outbox = DeliveryExceptionEvidenceOutbox(database);
      final saved = await outbox.saveLocal(
        stopId: 'stop-1',
        expectedStopVersion: 5,
        manifestId: 'manifest-1',
        manifestVersion: 2,
        category: 'damaged_item',
        note: 'Glass is cracked',
        localPath: '/private/damage.jpg',
        sha256: List.filled(64, 'a').join(),
        byteSize: 2048,
        contentType: 'image/jpeg',
      );
      await outbox.markPrepared(saved.id, {
        'mediaAssetId': 'asset-1',
        'bucket': 'pod-evidence',
        'path': 'tenant/exceptions/damage.jpg',
        'tusEndpoint': 'https://storage/upload/resumable',
        'assetState': 'staged',
      });
      await outbox.markUploadUrl(
        saved.id,
        'https://storage/upload/resumable/upload-1',
      );
      await outbox.markOffset(saved.id, 1024);
      await database.close();

      database = await databaseFactoryFfi.openDatabase(databasePath);
      outbox = DeliveryExceptionEvidenceOutbox(database);
      final restored = (await outbox.pending()).single;
      expect(restored.localPath, '/private/damage.jpg');
      expect(restored.category, 'damaged_item');
      expect(restored.note, 'Glass is cracked');
      expect(restored.mediaAssetId, 'asset-1');
      expect(restored.uploadOffset, 1024);
      final reset = await outbox.resetUploadSession(restored.id);
      expect(reset.status, 'prepared');
      expect(reset.uploadUrl, isNull);
      expect(reset.uploadOffset, 0);
      await database.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
