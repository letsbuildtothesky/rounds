import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:rounds_driver_harness/src/driver/driver_operations_thread.dart';
import 'package:rounds_driver_harness/src/storage/harness_database.dart';
import 'package:rounds_driver_harness/src/storage/message_media_outbox.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('rich message outbox retains local media and resumable state', () async {
    final directory = await Directory.systemTemp.createTemp(
      'rounds-rich-message-restart-',
    );
    final databasePath = path.join(directory.path, 'outbox.db');
    addTearDown(() async => directory.delete(recursive: true));
    final database = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) =>
            HarnessDatabase.createMessageMediaOutboxSchema(database),
      ),
    );
    final outbox = MessageMediaOutbox(database);
    final sha256 = List.filled(64, 'b').join();
    final saved = await outbox.save(
      roundId: 'round-1',
      stopId: 'stop-1',
      body: 'See the package',
      attachments: [
        DriverMessageAttachmentModel.media(
          kind: 'image',
          fileName: 'package.jpg',
          contentType: 'image/jpeg',
          byteSize: 4096,
          localPath: '/private/package.jpg',
          sha256: sha256,
        ),
      ],
    );

    final uploading = await outbox.updateAttachments(saved.id, [
      saved.attachments.single.copyWithUpload(
        mediaAssetId: 'asset-1',
        storageBucket: 'communication-media',
        storagePath: 'tenant/thread/asset-1',
        tusEndpoint: 'https://storage.test/upload/resumable',
        uploadUrl: 'https://storage.test/upload/one',
        uploadOffset: 2048,
      ),
    ]);
    await database.close();

    final reopenedDatabase = await databaseFactory.openDatabase(databasePath);
    addTearDown(reopenedDatabase.close);
    final recovered = (await MessageMediaOutbox(
      reopenedDatabase,
    ).pending(stopId: 'stop-1')).single;

    expect(uploading.id, saved.id);
    expect(recovered.status, 'uploading');
    expect(recovered.attachments.single.localPath, '/private/package.jpg');
    expect(recovered.attachments.single.mediaAssetId, 'asset-1');
    expect(recovered.attachments.single.uploadOffset, 2048);
  });
}
