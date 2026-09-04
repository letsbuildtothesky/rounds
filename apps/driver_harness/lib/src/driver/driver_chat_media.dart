import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'driver_operations_thread.dart';

class DriverChatMediaGateway {
  DriverChatMediaGateway({ImagePicker? imagePicker, AudioRecorder? recorder})
    : _imagePicker = imagePicker ?? ImagePicker(),
      _recorder = recorder ?? AudioRecorder();

  final ImagePicker _imagePicker;
  final AudioRecorder _recorder;
  DateTime? _recordingStartedAt;
  String? _recordingPath;

  Future<DriverMessageAttachmentModel?> captureCamera() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1920,
    );
    return picked == null
        ? null
        : retain(kind: 'image', sourcePath: picked.path, fileName: picked.name);
  }

  Future<DriverMessageAttachmentModel?> pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 2048,
    );
    return picked == null
        ? null
        : retain(kind: 'image', sourcePath: picked.path, fileName: picked.name);
  }

  Future<DriverMessageAttachmentModel?> pickFile() async {
    final result = await FilePicker.pickFiles();
    final selected = result.singleOrNull;
    if (selected?.path == null) return null;
    return retain(
      kind: 'file',
      sourcePath: selected!.path!,
      fileName: selected.name,
    );
  }

  Future<void> startVoice() async {
    if (!await _recorder.hasPermission()) {
      throw const FileSystemException('Microphone permission is required');
    }
    final temporary = await getTemporaryDirectory();
    final target = path.join(
      temporary.path,
      'rounds-voice-${const Uuid().v4()}.m4a',
    );
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 96000,
        sampleRate: 44100,
      ),
      path: target,
    );
    _recordingPath = target;
    _recordingStartedAt = DateTime.now();
  }

  Future<DriverMessageAttachmentModel?> stopVoice() async {
    final stoppedPath = await _recorder.stop() ?? _recordingPath;
    final startedAt = _recordingStartedAt;
    _recordingPath = null;
    _recordingStartedAt = null;
    if (stoppedPath == null || startedAt == null) return null;
    final duration = DateTime.now()
        .difference(startedAt)
        .inMilliseconds
        .clamp(250, 600000);
    return retain(
      kind: 'voice',
      sourcePath: stoppedPath,
      fileName: 'Voice note.m4a',
      durationMilliseconds: duration,
    );
  }

  Future<void> cancelVoice() async {
    final stoppedPath = await _recorder.stop() ?? _recordingPath;
    _recordingPath = null;
    _recordingStartedAt = null;
    if (stoppedPath != null) {
      try {
        await File(stoppedPath).delete();
      } on FileSystemException {
        // The OS may already have removed the temporary recording.
      }
    }
  }

  Future<DriverMessageAttachmentModel> retain({
    required String kind,
    required String sourcePath,
    required String fileName,
    int? durationMilliseconds,
  }) async {
    final source = File(sourcePath);
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty || bytes.length > 15728640) {
      throw const FileSystemException('Attachment must be smaller than 15 MB');
    }
    final digest = sha256.convert(bytes).toString();
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'message_media'));
    await directory.create(recursive: true);
    final safeExtension = path.extension(fileName).toLowerCase();
    final retainedPath = path.join(directory.path, '$digest$safeExtension');
    if (!await File(retainedPath).exists()) await source.copy(retainedPath);
    return DriverMessageAttachmentModel.media(
      kind: kind,
      fileName: fileName,
      contentType: _contentType(fileName, kind),
      byteSize: bytes.length,
      localPath: retainedPath,
      sha256: digest,
      durationMilliseconds: durationMilliseconds,
    );
  }

  Future<void> dispose() => _recorder.dispose();
}

String _contentType(String fileName, String kind) {
  if (kind == 'voice') return 'audio/mp4';
  return switch (path.extension(fileName).toLowerCase()) {
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.png' => 'image/png',
    '.webp' => 'image/webp',
    '.pdf' => 'application/pdf',
    '.txt' => 'text/plain',
    '.csv' => 'text/csv',
    '.doc' => 'application/msword',
    '.docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.xls' => 'application/vnd.ms-excel',
    '.xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => 'application/octet-stream',
  };
}
