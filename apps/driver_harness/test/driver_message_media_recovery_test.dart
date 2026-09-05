import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;
import 'package:rounds_driver_harness/src/driver/driver_api.dart';
import 'package:rounds_driver_harness/src/driver/driver_operations_thread.dart';
import 'package:rounds_driver_harness/src/storage/delivery_exception_evidence_outbox.dart';
import 'package:rounds_driver_harness/src/storage/driver_command_outbox.dart';
import 'package:rounds_driver_harness/src/storage/harness_database.dart';
import 'package:rounds_driver_harness/src/storage/message_media_outbox.dart';
import 'package:rounds_driver_harness/src/storage/pod_evidence_outbox.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('process restart resumes a partial rich-message upload once', () async {
    FlutterSecureStorage.setMockInitialValues({
      'rounds_driver_access_token': 'access-token',
    });
    final directory = await Directory.systemTemp.createTemp(
      'rounds-rich-message-api-restart-',
    );
    addTearDown(() async => directory.delete(recursive: true));
    final localFile = File(path.join(directory.path, 'manifest.txt'));
    const bytes = <int>[82, 111, 117, 110, 100, 115];
    await localFile.writeAsBytes(bytes);
    final databasePath = path.join(directory.path, 'rounds.db');
    final originalDatabase = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) async {
          await HarnessDatabase.createCommandOutboxSchema(database);
          await HarnessDatabase.createPodEvidenceSchema(database);
          await HarnessDatabase.createDeliveryExceptionEvidenceSchema(database);
          await HarnessDatabase.createMessageMediaOutboxSchema(database);
        },
      ),
    );
    final originalOutbox = MessageMediaOutbox(originalDatabase);
    final saved = await originalOutbox.save(
      roundId: 'round-1',
      stopId: 'stop-1',
      body: 'Restart recovery proof',
      attachments: [
        DriverMessageAttachmentModel.media(
          kind: 'file',
          fileName: 'manifest.txt',
          contentType: 'text/plain',
          byteSize: bytes.length,
          localPath: localFile.path,
          sha256: sha256.convert(bytes).toString(),
        ),
      ],
    );
    await originalOutbox.updateAttachments(saved.id, [
      saved.attachments.single.copyWithUpload(
        mediaAssetId: 'asset-1',
        storageBucket: 'communication-media',
        storagePath: 'tenant/thread/asset-1',
        tusEndpoint: 'https://storage.example.test/resumable',
        uploadUrl: 'https://storage.example.test/uploads/asset-1',
        uploadOffset: 2,
      ),
    ]);
    await originalDatabase.close();

    final recoveredDatabase = await databaseFactory.openDatabase(databasePath);
    addTearDown(recoveredDatabase.close);
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url}');
      if (request.method == 'GET' && request.url.path == '/v1/driver/session') {
        return http.Response(jsonEncode(_sessionJson), HttpStatus.ok);
      }
      if (request.method == 'HEAD' && request.url.path == '/uploads/asset-1') {
        return http.Response(
          '',
          HttpStatus.noContent,
          headers: {'upload-offset': '2'},
        );
      }
      if (request.method == 'PATCH' && request.url.path == '/uploads/asset-1') {
        expect(request.bodyBytes, bytes.sublist(2));
        expect(request.headers['upload-offset'], '2');
        return http.Response(
          '',
          HttpStatus.noContent,
          headers: {'upload-offset': bytes.length.toString()},
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/v1/driver/message-media/asset-1/verify') {
        return http.Response('{}', HttpStatus.ok);
      }
      if (request.method == 'POST' &&
          request.url.path ==
              '/v1/driver/rounds/round-1/stops/stop-1/messages') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final attachment =
            (payload['attachments'] as List).single as Map<String, dynamic>;
        expect(payload['body'], 'Restart recovery proof');
        expect(attachment['mediaAssetId'], 'asset-1');
        expect(attachment.containsKey('localPath'), isFalse);
        expect(request.headers['idempotency-key'], saved.idempotencyKey);
        return http.Response('{}', HttpStatus.created);
      }
      fail('Unexpected request ${request.method} ${request.url}');
    });
    final api = DriverApi(
      supabaseUrl: 'https://example.supabase.co',
      publishableKey: 'public-key',
      roundsApiUrl: 'https://api.example.test',
      client: client,
      outboxFactory: () async => DriverCommandOutbox(recoveredDatabase),
      podOutboxFactory: () async => PodEvidenceOutbox(recoveredDatabase),
      exceptionOutboxFactory: () async =>
          DeliveryExceptionEvidenceOutbox(recoveredDatabase),
      messageMediaOutboxFactory: () async =>
          MessageMediaOutbox(recoveredDatabase),
    );

    final restored = await api.restore(expectedDriverId: 'driver-1');

    expect(restored?.driverId, 'driver-1');
    expect(await MessageMediaOutbox(recoveredDatabase).pending(), isEmpty);
    final commands = await recoveredDatabase.query(
      'driver_command_outbox',
      where: 'command_type = ?',
      whereArgs: ['thread.send_message'],
    );
    expect(commands, hasLength(1));
    expect(commands.single['status'], 'committed');
    expect(
      requests.where((request) => request.contains('/stops/stop-1/messages')),
      hasLength(1),
    );
  });
}

const _sessionJson = <String, Object?>{
  'user': {'id': 'auth-user', 'displayName': 'Johannes'},
  'driver': {'id': 'driver-1', 'version': 1, 'preferredLocale': 'en'},
  'team': {'displayName': 'UrbanFlowers'},
};
