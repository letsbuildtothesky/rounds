import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rounds_driver_harness/src/driver/driver_chat_attachment_opener.dart';
import 'package:rounds_driver_harness/src/driver/driver_operations_thread.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'rounds-message-media-test-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'downloads signed bytes to a safe private cache path before opening',
    () async {
      const bytes = <int>[82, 111, 117, 110, 100, 115];
      String? launchedPath;
      String? launchedContentType;
      final opener = DriverChatAttachmentOpener(
        client: MockClient((request) async {
          expect(request.url.host, 'storage.example.test');
          return http.Response.bytes(bytes, HttpStatus.ok);
        }),
        temporaryDirectory: () async => temporaryDirectory,
        launchLocalFile: (filePath, {contentType}) async {
          launchedPath = filePath;
          launchedContentType = contentType;
          return true;
        },
      );
      const attachment = DriverMessageAttachmentModel.media(
        kind: 'file',
        fileName: '../../unsafe/acceptance.md',
        contentType: 'text/markdown',
        byteSize: 6,
        mediaAssetId: '00000000-0000-4000-8000-000000000001',
        downloadUrl: 'https://storage.example.test/signed?token=secret',
      );

      expect(await opener.open(attachment), isTrue);
      expect(launchedPath, isNotNull);
      expect(launchedPath, startsWith(temporaryDirectory.path));
      expect(launchedPath, isNot(contains('..')));
      expect(launchedPath, isNot(contains('token=secret')));
      expect(await File(launchedPath!).readAsBytes(), bytes);
      expect(launchedContentType, 'text/plain');
      opener.close();
    },
  );

  test(
    'rejects a response whose byte length differs from trusted metadata',
    () async {
      var launched = false;
      final opener = DriverChatAttachmentOpener(
        client: MockClient(
          (_) async => http.Response.bytes(<int>[1, 2, 3], HttpStatus.ok),
        ),
        temporaryDirectory: () async => temporaryDirectory,
        launchLocalFile: (_, {contentType}) async {
          launched = true;
          return true;
        },
      );
      const attachment = DriverMessageAttachmentModel.media(
        kind: 'file',
        fileName: 'manifest.pdf',
        contentType: 'application/pdf',
        byteSize: 4,
        mediaAssetId: 'asset-id',
        downloadUrl: 'https://storage.example.test/signed',
      );

      expect(await opener.open(attachment), isFalse);
      expect(launched, isFalse);
      expect(
        Directory(
          '${temporaryDirectory.path}/rounds_message_media',
        ).existsSync(),
        isFalse,
      );
      opener.close();
    },
  );

  test('never downloads an insecure attachment URL', () async {
    var requested = false;
    final opener = DriverChatAttachmentOpener(
      client: MockClient((_) async {
        requested = true;
        return http.Response('', HttpStatus.ok);
      }),
      temporaryDirectory: () async => temporaryDirectory,
      launchLocalFile: (_, {contentType}) async => true,
    );
    const attachment = DriverMessageAttachmentModel.media(
      kind: 'file',
      fileName: 'manifest.pdf',
      contentType: 'application/pdf',
      byteSize: 4,
      mediaAssetId: 'asset-id',
      downloadUrl: 'http://storage.example.test/signed',
    );

    expect(await opener.open(attachment), isFalse);
    expect(requested, isFalse);
    opener.close();
  });
}
