import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'driver_operations_thread.dart';

typedef DriverChatTemporaryDirectory = Future<Directory> Function();
typedef DriverChatLocalFileLauncher =
    Future<bool> Function(String filePath, {String? contentType});

class DriverChatAttachmentOpener {
  DriverChatAttachmentOpener({
    http.Client? client,
    DriverChatTemporaryDirectory? temporaryDirectory,
    DriverChatLocalFileLauncher? launchLocalFile,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _launchLocalFile = launchLocalFile ?? _openWithPlatform;

  static const int maximumBytes = 15 * 1024 * 1024;

  final http.Client _client;
  final bool _ownsClient;
  final DriverChatTemporaryDirectory _temporaryDirectory;
  final DriverChatLocalFileLauncher _launchLocalFile;

  Future<bool> open(
    DriverMessageAttachmentModel attachment, {
    String? downloadUrl,
  }) async {
    final localPath = attachment.localPath;
    if (localPath != null) {
      final localFile = File(localPath);
      if (!await localFile.exists()) return false;
      return _launchLocalFile(
        localFile.path,
        contentType: _platformContentType(attachment),
      );
    }

    final rawUrl = downloadUrl ?? attachment.downloadUrl;
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) return false;

    final bytes = response.bodyBytes;
    final expectedBytes = attachment.byteSize;
    if (bytes.length > maximumBytes ||
        (expectedBytes != null &&
            expectedBytes > 0 &&
            expectedBytes != bytes.length)) {
      return false;
    }

    final temporaryRoot = await _temporaryDirectory();
    final cacheDirectory = Directory(
      path.join(temporaryRoot.path, 'rounds_message_media'),
    );
    await cacheDirectory.create(recursive: true);
    final cachedFile = File(
      path.join(cacheDirectory.path, _safeFileName(attachment)),
    );
    await cachedFile.writeAsBytes(bytes, flush: true);

    return _launchLocalFile(
      cachedFile.path,
      contentType: _platformContentType(attachment),
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  static Future<bool> _openWithPlatform(
    String filePath, {
    String? contentType,
  }) async {
    final result = await OpenFilex.open(filePath, type: contentType);
    return result.type == ResultType.done;
  }

  static String _safeFileName(DriverMessageAttachmentModel attachment) {
    final rawName = path.basename(attachment.fileName ?? 'attachment');
    final safeName = rawName
        .replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_')
        .replaceAll(RegExp(r'^\.+'), '');
    final usableName = safeName.isEmpty ? 'attachment' : safeName;
    final rawPrefix =
        attachment.mediaAssetId ?? attachment.sha256 ?? 'message-media';
    final safePrefix = rawPrefix.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final prefix = safePrefix.length > 36
        ? safePrefix.substring(0, 36)
        : safePrefix;
    return '${prefix.isEmpty ? 'message-media' : prefix}-$usableName';
  }

  static String? _platformContentType(DriverMessageAttachmentModel attachment) {
    final extension = path.extension(attachment.fileName ?? '').toLowerCase();
    if (const {
      '.md',
      '.markdown',
      '.log',
      '.yaml',
      '.yml',
    }.contains(extension)) {
      return 'text/plain';
    }
    final contentType = attachment.contentType?.split(';').first.trim();
    if (contentType == null ||
        contentType.isEmpty ||
        contentType == 'application/octet-stream') {
      return null;
    }
    return contentType;
  }
}
