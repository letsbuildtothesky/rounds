import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../storage/driver_command_outbox.dart';
import '../storage/delivery_exception_evidence_outbox.dart';
import '../storage/pod_evidence_outbox.dart';
import 'driver_session.dart';
import 'driver_operations_thread.dart';

class DriverApiException implements Exception {
  const DriverApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum DriverCommandDisposition { committed, pendingSync }

class DriverCommandOutcome {
  const DriverCommandOutcome(this.disposition, {this.session});

  final DriverCommandDisposition disposition;
  final DriverSessionModel? session;

  bool get committed => disposition == DriverCommandDisposition.committed;
  bool get pendingSync => disposition == DriverCommandDisposition.pendingSync;
}

class DriverApi {
  DriverApi({
    required this.supabaseUrl,
    required this.publishableKey,
    required this.roundsApiUrl,
    FlutterSecureStorage? storage,
    http.Client? client,
    Future<DriverCommandOutbox> Function()? outboxFactory,
    Future<PodEvidenceOutbox> Function()? podOutboxFactory,
    Future<DeliveryExceptionEvidenceOutbox> Function()? exceptionOutboxFactory,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client(),
       _outboxFactory = outboxFactory ?? DriverCommandOutbox.open,
       _podOutboxFactory = podOutboxFactory ?? PodEvidenceOutbox.open,
       _exceptionOutboxFactory =
           exceptionOutboxFactory ?? DeliveryExceptionEvidenceOutbox.open;

  static const _accessTokenKey = 'rounds_driver_access_token';
  static const _refreshTokenKey = 'rounds_driver_refresh_token';

  final String supabaseUrl;
  final String publishableKey;
  final String roundsApiUrl;
  final FlutterSecureStorage _storage;
  final http.Client _client;
  final Future<DriverCommandOutbox> Function() _outboxFactory;
  final Future<PodEvidenceOutbox> Function() _podOutboxFactory;
  final Future<DeliveryExceptionEvidenceOutbox> Function()
  _exceptionOutboxFactory;
  DriverCommandOutbox? _outbox;
  PodEvidenceOutbox? _podOutbox;
  DeliveryExceptionEvidenceOutbox? _exceptionOutbox;

  bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      publishableKey.isNotEmpty &&
      roundsApiUrl.isNotEmpty;

  Future<DriverSessionModel?> restore() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null) return null;
    try {
      var session = await _driverSession(accessToken);
      final exceptionFlush = await _flushPendingExceptionEvidence(accessToken);
      final podFlush = await _flushPendingPodEvidence(
        exceptionFlush.accessToken,
      );
      final flush = await _flushPending(podFlush.accessToken);
      if (flush.committedAny) session = await _driverSession(flush.accessToken);
      return session;
    } on _Unauthorized {
      final refreshed = await _refresh();
      if (refreshed == null) {
        await signOut();
        return null;
      }
      var session = await _driverSession(refreshed);
      final exceptionFlush = await _flushPendingExceptionEvidence(refreshed);
      final podFlush = await _flushPendingPodEvidence(
        exceptionFlush.accessToken,
      );
      final flush = await _flushPending(podFlush.accessToken);
      if (flush.committedAny) session = await _driverSession(flush.accessToken);
      return session;
    }
  }

  Future<DriverSessionModel> signIn(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
      headers: {'apikey': publishableKey, 'content-type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    if (response.statusCode != 200) {
      throw DriverApiException(_message(response, 'Sign in failed'));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String;
    final refreshToken = body['refresh_token'] as String;
    await _writeTokens(accessToken, refreshToken);
    try {
      var session = await _driverSession(accessToken);
      final exceptionFlush = await _flushPendingExceptionEvidence(accessToken);
      final podFlush = await _flushPendingPodEvidence(
        exceptionFlush.accessToken,
      );
      final flush = await _flushPending(podFlush.accessToken);
      if (flush.committedAny) session = await _driverSession(flush.accessToken);
      return session;
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  Future<void> signOut() => Future.wait([
    _storage.delete(key: _accessTokenKey),
    _storage.delete(key: _refreshTokenKey),
  ]);

  Future<DriverOperationsThreadModel> getOperationsThread({
    required DriverRoundModel round,
    required DriverRoundStopModel stop,
  }) async {
    final response = await _authorizedGet(
      '/v1/driver/rounds/${round.id}/stops/${stop.id}/thread',
    );
    if (response.statusCode != 200) {
      throw DriverApiException(
        _message(response, 'Operations messages could not be loaded'),
      );
    }
    return DriverOperationsThreadModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<DriverOperationsMessageModel>> pendingOperationsMessages({
    required DriverRoundModel round,
    required DriverRoundStopModel stop,
  }) async {
    final endpoint = '/v1/driver/rounds/${round.id}/stops/${stop.id}/messages';
    final records = await (await _commandOutbox()).pendingByType(
      'thread.send_message',
    );
    return records
        .where((record) => record.endpoint == endpoint)
        .map((record) {
          final payload =
              jsonDecode(record.payloadJson) as Map<String, dynamic>;
          return DriverOperationsMessageModel(
            id: record.id,
            sender: 'driver',
            body: payload['body'] as String,
            sentAt: DateTime.parse(record.occurredFromDeviceAt),
            savedLocally: true,
          );
        })
        .toList(growable: false);
  }

  Future<DriverCommandOutcome> sendOperationsMessage({
    required DriverRoundModel round,
    required DriverRoundStopModel stop,
    required String body,
  }) {
    final trimmed = body.trim();
    final nonce = DateTime.now().toUtc().microsecondsSinceEpoch;
    final fingerprint = sha256.convert(utf8.encode('$nonce:$trimmed'));
    return _queueAndSend(
      commandType: 'thread.send_message',
      aggregateId: stop.id,
      expectedVersion: 1,
      idempotencyKey: 'driver-message:${stop.id}:$fingerprint',
      endpoint: '/v1/driver/rounds/${round.id}/stops/${stop.id}/messages',
      payload: {'body': trimmed},
    );
  }

  Future<DriverCommandOutcome> acknowledgeLiveDeliveryChange(
    DriverLiveDeliveryChangeModel change,
  ) => _queueAndSend(
    commandType: 'driver.acknowledge_live_change',
    aggregateId: change.id,
    expectedVersion: 1,
    idempotencyKey: 'driver-live-change:${change.id}:v${change.changeVersion}',
    endpoint: '/v1/driver/live-delivery-changes/${change.id}/acknowledge',
    payload: {'expectedChangeVersion': 1},
  );

  Future<List<DriverContactAttemptModel>> pendingContactAttempts(
    DriverRoundStopModel stop,
  ) async {
    final records = await (await _commandOutbox()).pendingByType(
      'stop.log_contact_attempt',
    );
    return records
        .where((record) => record.aggregateId == stop.id)
        .map((record) {
          final payload =
              jsonDecode(record.payloadJson) as Map<String, dynamic>;
          return DriverContactAttemptModel(
            id: record.id,
            target: payload['target'] as String,
            channel: payload['channel'] as String,
            outcome: payload['outcome'] as String,
            occurredAt: DateTime.parse(record.occurredFromDeviceAt),
            savedLocally: true,
          );
        })
        .toList(growable: false);
  }

  Future<DriverCommandOutcome> logContactAttempt({
    required DriverRoundStopModel stop,
    required String target,
    required String outcome,
  }) {
    final nonce = DateTime.now().toUtc().microsecondsSinceEpoch;
    return _queueAndSend(
      commandType: 'stop.log_contact_attempt',
      aggregateId: stop.id,
      expectedVersion: stop.version,
      idempotencyKey: 'contact:${stop.id}:$target:$nonce',
      endpoint: '/v1/driver/stops/${stop.id}/contact-attempts',
      payload: {
        'target': target,
        'channel': 'native_phone',
        'outcome': outcome,
      },
    );
  }

  Future<DriverCommandOutcome> confirmPickup(DriverRoundModel round) =>
      _queueAndSend(
        commandType: 'round.confirm_pickup',
        aggregateId: round.id,
        expectedVersion: round.version,
        idempotencyKey: 'driver-pickup:${round.id}:v${round.version}',
        endpoint: '/v1/driver/rounds/${round.id}/pickup',
        payload: {
          'stops': round.stops
              .map(
                (stop) => {
                  'stopId': stop.id,
                  'manifestId': stop.manifestId,
                  'manifestVersion': stop.manifestVersion,
                  'confirmedLineNumbers': stop.manifestItems
                      .map((item) => item.lineNumber)
                      .toList(growable: false),
                },
              )
              .toList(growable: false),
        },
      );

  Future<DriverCommandOutcome> reportPickupProblem({
    required DriverRoundStopModel stop,
    required String category,
    String? note,
  }) => _queueAndSend(
    commandType: 'stop.report_pickup_problem',
    aggregateId: stop.id,
    expectedVersion: stop.version,
    idempotencyKey: 'pickup-problem:${stop.id}:v${stop.version}:$category',
    endpoint: '/v1/driver/stops/${stop.id}/pickup-problem',
    payload: {
      'manifestId': stop.manifestId,
      'manifestVersion': stop.manifestVersion,
      'category': category,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    },
  );

  Future<DriverCommandOutcome> reportLocationProblem({
    required DriverRoundStopModel stop,
    required String stage,
    required String category,
    required String detail,
    Map<String, Object?>? position,
  }) {
    final payload = <String, Object?>{
      'manifestId': stop.manifestId,
      'manifestVersion': stop.manifestVersion,
      'stage': stage,
      'category': category,
      'detail': detail.trim(),
      'position': ?position,
    };
    final fingerprint = sha256.convert(utf8.encode(jsonEncode(payload)));
    return _queueAndSend(
      commandType: 'stop.report_location_problem',
      aggregateId: stop.id,
      expectedVersion: stop.version,
      idempotencyKey:
          'location-problem:${stop.id}:v${stop.version}:$fingerprint',
      endpoint: '/v1/driver/stops/${stop.id}/location-problem',
      payload: payload,
    );
  }

  Future<DriverCommandOutcome> confirmArrival(
    DriverRoundStopModel stop, {
    Map<String, Object?>? position,
    String? overrideReason,
  }) => _queueAndSend(
    commandType: 'stop.confirm_arrival',
    aggregateId: stop.id,
    expectedVersion: stop.version,
    idempotencyKey: 'stop-arrival:${stop.id}:v${stop.version}',
    endpoint: '/v1/driver/stops/${stop.id}/arrival',
    payload: {
      'position': ?position,
      if (overrideReason != null && overrideReason.trim().isNotEmpty)
        'overrideReason': overrideReason.trim(),
    },
  );

  Future<DriverCommandOutcome> completePod({
    required DriverRoundStopModel stop,
    required String capturedPhotoPath,
    required String handoffType,
    String? receiverName,
    String? receiverRelationship,
    String? leftAtLocation,
    String? note,
  }) async {
    final source = File(capturedPhotoPath);
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty || bytes.length > 6291456) {
      throw const DriverApiException(
        'Delivery photo must be smaller than 6 MB',
      );
    }
    final digest = sha256.convert(bytes).toString();
    final support = await getApplicationSupportDirectory();
    final evidenceDirectory = Directory(
      path.join(support.path, 'pod_evidence'),
    );
    await evidenceDirectory.create(recursive: true);
    final extension = path.extension(capturedPhotoPath).toLowerCase() == '.png'
        ? '.png'
        : '.jpg';
    final durablePath = path.join(
      evidenceDirectory.path,
      '${stop.id}-$digest$extension',
    );
    if (!await File(durablePath).exists()) await source.copy(durablePath);
    final record = await (await _podEvidenceOutbox()).saveLocal(
      stopId: stop.id,
      expectedStopVersion: stop.version,
      manifestId: stop.manifestId,
      manifestVersion: stop.manifestVersion,
      confirmedLineNumbers: stop.manifestItems
          .map((item) => item.lineNumber)
          .toList(growable: false),
      localPath: durablePath,
      sha256: digest,
      byteSize: bytes.length,
      contentType: extension == '.png' ? 'image/png' : 'image/jpeg',
      handoffType: handoffType,
      receiverName: receiverName,
      receiverRelationship: receiverRelationship,
      leftAtLocation: leftAtLocation,
      note: note,
    );
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) {
      return const DriverCommandOutcome(DriverCommandDisposition.pendingSync);
    }
    return _syncPodEvidence(record, token);
  }

  Future<DriverCommandOutcome> reportDeliveryDamage({
    required DriverRoundStopModel stop,
    required String capturedPhotoPath,
    String? note,
  }) async {
    final source = File(capturedPhotoPath);
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty || bytes.length > 6291456) {
      throw const DriverApiException('Damage photo must be smaller than 6 MB');
    }
    final digest = sha256.convert(bytes).toString();
    final support = await getApplicationSupportDirectory();
    final evidenceDirectory = Directory(
      path.join(support.path, 'delivery_exception_evidence'),
    );
    await evidenceDirectory.create(recursive: true);
    final extension = path.extension(capturedPhotoPath).toLowerCase() == '.png'
        ? '.png'
        : '.jpg';
    final durablePath = path.join(
      evidenceDirectory.path,
      '${stop.id}-$digest$extension',
    );
    if (!await File(durablePath).exists()) await source.copy(durablePath);
    final record = await (await _deliveryExceptionOutbox()).saveLocal(
      stopId: stop.id,
      expectedStopVersion: stop.version,
      manifestId: stop.manifestId,
      manifestVersion: stop.manifestVersion,
      category: 'damaged_item',
      localPath: durablePath,
      sha256: digest,
      byteSize: bytes.length,
      contentType: extension == '.png' ? 'image/png' : 'image/jpeg',
      note: note,
    );
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) {
      return const DriverCommandOutcome(DriverCommandDisposition.pendingSync);
    }
    return _syncExceptionEvidence(record, token);
  }

  Future<DriverCommandOutcome> _queueAndSend({
    required String commandType,
    required String aggregateId,
    required int expectedVersion,
    required String idempotencyKey,
    required String endpoint,
    required Map<String, Object?> payload,
  }) async {
    if (!isConfigured) {
      return const DriverCommandOutcome(DriverCommandDisposition.pendingSync);
    }
    final outbox = await _commandOutbox();
    final command = await outbox.enqueue(
      commandType: commandType,
      aggregateId: aggregateId,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
      endpoint: endpoint,
      payload: payload,
    );
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null) {
      await outbox.markPending(command.id, 'Authentication required');
      throw const DriverApiException('Sign in again to sync this action');
    }
    final send = await _sendStored(command, accessToken, allowRefresh: true);
    if (!send.committed) {
      return const DriverCommandOutcome(DriverCommandDisposition.pendingSync);
    }
    try {
      return DriverCommandOutcome(
        DriverCommandDisposition.committed,
        session: await _driverSession(send.accessToken),
      );
    } catch (_) {
      return const DriverCommandOutcome(DriverCommandDisposition.committed);
    }
  }

  Future<_StoredSendResult> _sendStored(
    DriverCommandRecord command,
    String accessToken, {
    required bool allowRefresh,
  }) async {
    final outbox = await _commandOutbox();
    await outbox.markSending(command);
    http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$roundsApiUrl${command.endpoint}'),
        headers: {
          'authorization': 'Bearer $accessToken',
          'content-type': 'application/json',
          'idempotency-key': command.idempotencyKey,
          'x-trace-id': command.id,
        },
        body: command.payloadJson,
      );
    } catch (error) {
      await outbox.markPending(command.id, error.toString());
      return _StoredSendResult.pending(accessToken);
    }
    if (response.statusCode == 401 && allowRefresh) {
      final refreshed = await _refresh();
      if (refreshed != null) {
        return _sendStored(command, refreshed, allowRefresh: false);
      }
    }
    if (response.statusCode == 200 || response.statusCode == 201) {
      await outbox.markCommitted(command.id);
      return _StoredSendResult.committed(accessToken);
    }
    final message = _message(response, 'Driver action could not be committed');
    if (response.statusCode == 401 || response.statusCode >= 500) {
      await outbox.markPending(command.id, message);
      if (response.statusCode == 401) {
        throw const DriverApiException(
          'Session expired. Sign in again; your action is still saved.',
        );
      }
      return _StoredSendResult.pending(accessToken);
    }
    if (response.statusCode == 409) {
      await outbox.markConflict(command.id, message);
    } else {
      await outbox.markFailedTerminal(command.id, message);
    }
    throw DriverApiException(message);
  }

  Future<_FlushResult> _flushPending(String accessToken) async {
    var token = accessToken;
    var committedAny = false;
    final outbox = await _commandOutbox();
    for (final command in await outbox.readyToSend()) {
      try {
        final result = await _sendStored(command, token, allowRefresh: true);
        token = result.accessToken;
        if (!result.committed) break;
        committedAny = true;
      } on DriverApiException {
        continue;
      }
    }
    return _FlushResult(token, committedAny);
  }

  Future<_FlushResult> _flushPendingPodEvidence(String accessToken) async {
    var committedAny = false;
    final outbox = await _podEvidenceOutbox();
    for (final record in await outbox.pending()) {
      try {
        final outcome = await _syncPodEvidence(record, accessToken);
        if (outcome.pendingSync) break;
        committedAny = true;
      } on DriverApiException {
        continue;
      }
    }
    return _FlushResult(accessToken, committedAny);
  }

  Future<_FlushResult> _flushPendingExceptionEvidence(
    String accessToken,
  ) async {
    var committedAny = false;
    final outbox = await _deliveryExceptionOutbox();
    for (final record in await outbox.pending()) {
      try {
        final outcome = await _syncExceptionEvidence(record, accessToken);
        if (outcome.pendingSync) break;
        committedAny = true;
      } on DriverApiException {
        continue;
      }
    }
    return _FlushResult(accessToken, committedAny);
  }

  Future<DriverCommandOutcome> _syncExceptionEvidence(
    DeliveryExceptionEvidenceRecord original,
    String accessToken,
  ) async {
    final outbox = await _deliveryExceptionOutbox();
    var record = original;
    try {
      if (record.mediaAssetId == null || record.tusEndpoint == null) {
        final response = await _client.post(
          Uri.parse(
            '$roundsApiUrl/v1/driver/stops/${record.stopId}/exception-media',
          ),
          headers: {
            'authorization': 'Bearer $accessToken',
            'content-type': 'application/json',
            'x-trace-id': record.id,
          },
          body: jsonEncode({
            'sha256': record.sha256,
            'byteSize': record.byteSize,
            'contentType': record.contentType,
          }),
        );
        if (response.statusCode != 200 && response.statusCode != 201) {
          if (response.statusCode >= 500) {
            throw DriverApiException(
              _message(
                response,
                'Damage photo preparation is temporarily unavailable',
              ),
            );
          }
          final message = _message(
            response,
            'Damage photo could not be prepared',
          );
          await outbox.markFailed(record.id, message);
          throw DriverApiException(message);
        }
        record = await outbox.markPrepared(
          record.id,
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      if (record.status != 'uploaded' && record.status != 'pending_command') {
        record = await _uploadExceptionTus(record, accessToken);
      }
      await outbox.markPendingCommand(record.id);
      final outcome = await _queueAndSend(
        commandType: 'stop.report_delivery_problem',
        aggregateId: record.stopId,
        expectedVersion: record.expectedStopVersion,
        idempotencyKey: record.idempotencyKey,
        endpoint: '/v1/driver/stops/${record.stopId}/delivery-problem',
        payload: {
          'manifestId': record.manifestId,
          'manifestVersion': record.manifestVersion,
          'category': record.category,
          'mediaAssetId': record.mediaAssetId,
          if (record.note != null && record.note!.trim().isNotEmpty)
            'note': record.note!.trim(),
        },
      );
      if (outcome.committed) await outbox.markCompleted(record.id);
      return outcome;
    } on DriverApiException catch (error) {
      final latest = await outbox.byId(record.id);
      if (latest?.status == 'failed_terminal') rethrow;
      await outbox.markPending(record.id, error);
      return const DriverCommandOutcome(DriverCommandDisposition.pendingSync);
    } catch (error) {
      await outbox.markPending(record.id, error);
      return const DriverCommandOutcome(DriverCommandDisposition.pendingSync);
    }
  }

  Future<DeliveryExceptionEvidenceRecord> _uploadExceptionTus(
    DeliveryExceptionEvidenceRecord original,
    String accessToken,
  ) async {
    final outbox = await _deliveryExceptionOutbox();
    var record = original;
    var uploadUrl = record.uploadUrl;
    if (uploadUrl == null) {
      final metadata =
          {
                'bucketName': record.storageBucket!,
                'objectName': record.storagePath!,
                'contentType': record.contentType,
                'cacheControl': '3600',
              }.entries
              .map(
                (entry) =>
                    '${entry.key} ${base64Encode(utf8.encode(entry.value))}',
              )
              .join(',');
      final request = http.Request('POST', Uri.parse(record.tusEndpoint!));
      request.headers.addAll({
        'tus-resumable': '1.0.0',
        'upload-length': record.byteSize.toString(),
        'upload-metadata': metadata,
        'authorization': 'Bearer $accessToken',
      });
      final response = await http.Response.fromStream(
        await _client.send(request),
      );
      if (response.statusCode != 201) {
        throw DriverApiException(
          'Damage photo upload could not start (HTTP ${response.statusCode})',
        );
      }
      final location = response.headers['location'];
      if (location == null) {
        throw const DriverApiException(
          'Damage photo upload did not return a resume URL',
        );
      }
      uploadUrl = Uri.parse(record.tusEndpoint!).resolve(location).toString();
      await outbox.markUploadUrl(record.id, uploadUrl);
      record = (await outbox.byId(record.id))!;
    } else {
      final head = http.Request('HEAD', Uri.parse(uploadUrl));
      head.headers.addAll({
        'tus-resumable': '1.0.0',
        'authorization': 'Bearer $accessToken',
      });
      final response = await http.Response.fromStream(await _client.send(head));
      if (response.statusCode == 200 || response.statusCode == 204) {
        final offset =
            int.tryParse(response.headers['upload-offset'] ?? '') ??
            record.uploadOffset;
        await outbox.markOffset(record.id, offset);
        record = (await outbox.byId(record.id))!;
      } else if (response.statusCode == 404 || response.statusCode == 410) {
        record = await outbox.resetUploadSession(record.id);
        return _uploadExceptionTus(record, accessToken);
      } else {
        throw DriverApiException(
          'Damage photo upload could not resume (HTTP ${response.statusCode})',
        );
      }
    }
    if (record.uploadOffset < record.byteSize) {
      final bytes = await File(record.localPath).readAsBytes();
      final request = http.Request('PATCH', Uri.parse(uploadUrl));
      request.headers.addAll({
        'tus-resumable': '1.0.0',
        'upload-offset': record.uploadOffset.toString(),
        'content-type': 'application/offset+octet-stream',
        'authorization': 'Bearer $accessToken',
      });
      request.bodyBytes = bytes.sublist(record.uploadOffset);
      final response = await http.Response.fromStream(
        await _client.send(request),
      );
      if (response.statusCode != 204) {
        throw DriverApiException(
          'Damage photo upload paused (HTTP ${response.statusCode})',
        );
      }
      final offset =
          int.tryParse(response.headers['upload-offset'] ?? '') ??
          record.byteSize;
      await outbox.markOffset(record.id, offset);
      if (offset < record.byteSize) {
        throw const DriverApiException('Damage photo upload is incomplete');
      }
    }
    await outbox.markUploaded(record.id);
    return (await outbox.byId(record.id))!;
  }

  Future<DriverCommandOutcome> _syncPodEvidence(
    PodEvidenceRecord original,
    String accessToken,
  ) async {
    final outbox = await _podEvidenceOutbox();
    var record = original;
    try {
      if (record.mediaAssetId == null || record.tusEndpoint == null) {
        final response = await _client.post(
          Uri.parse('$roundsApiUrl/v1/driver/stops/${record.stopId}/pod-media'),
          headers: {
            'authorization': 'Bearer $accessToken',
            'content-type': 'application/json',
            'x-trace-id': record.id,
          },
          body: jsonEncode({
            'sha256': record.sha256,
            'byteSize': record.byteSize,
            'contentType': record.contentType,
          }),
        );
        if (response.statusCode != 200 && response.statusCode != 201) {
          if (response.statusCode >= 500) {
            throw DriverApiException(
              _message(
                response,
                'Photo preparation is temporarily unavailable',
              ),
            );
          }
          final message = _message(response, 'Photo could not be prepared');
          await outbox.markFailed(record.id, message);
          throw DriverApiException(message);
        }
        record = await outbox.markPrepared(
          record.id,
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      if (record.status != 'uploaded' && record.status != 'pending_command') {
        record = await _uploadTus(record, accessToken);
      }
      await outbox.markPendingCommand(record.id);
      final outcome = await _queueAndSend(
        commandType: 'stop.complete_pod',
        aggregateId: record.stopId,
        expectedVersion: record.expectedStopVersion,
        idempotencyKey: record.idempotencyKey,
        endpoint: '/v1/driver/stops/${record.stopId}/pod',
        payload: {
          'manifestId': record.manifestId,
          'manifestVersion': record.manifestVersion,
          'confirmedLineNumbers': record.confirmedLineNumbers,
          'mediaAssetId': record.mediaAssetId,
          'handoffType': record.handoffType,
          if (record.receiverName != null) 'receiverName': record.receiverName,
          if (record.receiverRelationship != null)
            'receiverRelationship': record.receiverRelationship,
          if (record.leftAtLocation != null)
            'leftAtLocation': record.leftAtLocation,
          if (record.note != null && record.note!.trim().isNotEmpty)
            'note': record.note!.trim(),
        },
      );
      if (outcome.committed) await outbox.markCompleted(record.id);
      return outcome;
    } on DriverApiException catch (error) {
      final latest = await outbox.byId(record.id);
      if (latest?.status == 'failed_terminal') rethrow;
      await outbox.markPending(record.id, error);
      return const DriverCommandOutcome(DriverCommandDisposition.pendingSync);
    } catch (error) {
      await outbox.markPending(record.id, error);
      return const DriverCommandOutcome(DriverCommandDisposition.pendingSync);
    }
  }

  Future<PodEvidenceRecord> _uploadTus(
    PodEvidenceRecord original,
    String accessToken,
  ) async {
    final outbox = await _podEvidenceOutbox();
    var record = original;
    var uploadUrl = record.uploadUrl;
    if (uploadUrl == null) {
      final metadata =
          {
                'bucketName': record.storageBucket!,
                'objectName': record.storagePath!,
                'contentType': record.contentType,
                'cacheControl': '3600',
              }.entries
              .map(
                (entry) =>
                    '${entry.key} ${base64Encode(utf8.encode(entry.value))}',
              )
              .join(',');
      final request = http.Request('POST', Uri.parse(record.tusEndpoint!));
      request.headers.addAll({
        'tus-resumable': '1.0.0',
        'upload-length': record.byteSize.toString(),
        'upload-metadata': metadata,
        'authorization': 'Bearer $accessToken',
      });
      final response = await http.Response.fromStream(
        await _client.send(request),
      );
      if (response.statusCode != 201) {
        throw DriverApiException(
          'Photo upload could not start (HTTP ${response.statusCode})',
        );
      }
      final location = response.headers['location'];
      if (location == null) {
        throw const DriverApiException(
          'Photo upload did not return a resume URL',
        );
      }
      uploadUrl = Uri.parse(record.tusEndpoint!).resolve(location).toString();
      await outbox.markUploadUrl(record.id, uploadUrl);
      record = (await outbox.byId(record.id))!;
    } else {
      final head = http.Request('HEAD', Uri.parse(uploadUrl));
      head.headers.addAll({
        'tus-resumable': '1.0.0',
        'authorization': 'Bearer $accessToken',
      });
      final response = await http.Response.fromStream(await _client.send(head));
      if (response.statusCode == 200 || response.statusCode == 204) {
        final offset =
            int.tryParse(response.headers['upload-offset'] ?? '') ??
            record.uploadOffset;
        await outbox.markOffset(record.id, offset);
        record = (await outbox.byId(record.id))!;
      } else if (response.statusCode == 404 || response.statusCode == 410) {
        record = await outbox.resetUploadSession(record.id);
        return _uploadTus(record, accessToken);
      } else {
        throw DriverApiException(
          'Photo upload could not resume (HTTP ${response.statusCode})',
        );
      }
    }
    if (record.uploadOffset < record.byteSize) {
      final bytes = await File(record.localPath).readAsBytes();
      final request = http.Request('PATCH', Uri.parse(uploadUrl));
      request.headers.addAll({
        'tus-resumable': '1.0.0',
        'upload-offset': record.uploadOffset.toString(),
        'content-type': 'application/offset+octet-stream',
        'authorization': 'Bearer $accessToken',
      });
      request.bodyBytes = bytes.sublist(record.uploadOffset);
      final response = await http.Response.fromStream(
        await _client.send(request),
      );
      if (response.statusCode != 204) {
        throw DriverApiException(
          'Photo upload paused (HTTP ${response.statusCode})',
        );
      }
      final offset =
          int.tryParse(response.headers['upload-offset'] ?? '') ??
          record.byteSize;
      await outbox.markOffset(record.id, offset);
      if (offset < record.byteSize) {
        throw const DriverApiException('Photo upload is incomplete');
      }
    }
    await outbox.markUploaded(record.id);
    return (await outbox.byId(record.id))!;
  }

  Future<DriverCommandOutbox> _commandOutbox() async =>
      _outbox ??= await _outboxFactory();

  Future<PodEvidenceOutbox> _podEvidenceOutbox() async =>
      _podOutbox ??= await _podOutboxFactory();

  Future<DeliveryExceptionEvidenceOutbox> _deliveryExceptionOutbox() async =>
      _exceptionOutbox ??= await _exceptionOutboxFactory();

  Future<DriverSessionModel> _driverSession(String accessToken) async {
    final response = await _client.get(
      Uri.parse('$roundsApiUrl/v1/driver/session'),
      headers: {
        'authorization': 'Bearer $accessToken',
        'x-trace-id': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );
    if (response.statusCode == 401) throw const _Unauthorized();
    if (response.statusCode != 200) {
      throw DriverApiException(
        _message(response, 'Assigned work could not be loaded'),
      );
    }
    return DriverSessionModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<http.Response> _authorizedGet(String endpoint) async {
    var accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null) {
      throw const DriverApiException('Sign in again to load Operations');
    }
    var response = await _client.get(
      Uri.parse('$roundsApiUrl$endpoint'),
      headers: {
        'authorization': 'Bearer $accessToken',
        'x-trace-id': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );
    if (response.statusCode == 401) {
      accessToken = await _refresh();
      if (accessToken == null) throw const _Unauthorized();
      response = await _client.get(
        Uri.parse('$roundsApiUrl$endpoint'),
        headers: {
          'authorization': 'Bearer $accessToken',
          'x-trace-id': DateTime.now().microsecondsSinceEpoch.toString(),
        },
      );
    }
    return response;
  }

  Future<String?> _refresh() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) return null;
    final response = await _client.post(
      Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token'),
      headers: {'apikey': publishableKey, 'content-type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String;
    await _writeTokens(
      accessToken,
      body['refresh_token'] as String? ?? refreshToken,
    );
    return accessToken;
  }

  Future<void> _writeTokens(String accessToken, String refreshToken) =>
      Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      ]);

  String _message(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final nested = body['error'];
      if (nested is Map<String, dynamic> && nested['message'] is String) {
        return nested['message'] as String;
      }
      if (body['msg'] is String) return body['msg'] as String;
      if (body['error_description'] is String) {
        return body['error_description'] as String;
      }
    } catch (_) {}
    return fallback;
  }
}

class _Unauthorized implements Exception {
  const _Unauthorized();
}

class _StoredSendResult {
  const _StoredSendResult(this.accessToken, this.committed);
  const _StoredSendResult.pending(String token) : this(token, false);
  const _StoredSendResult.committed(String token) : this(token, true);

  final String accessToken;
  final bool committed;
}

class _FlushResult {
  const _FlushResult(this.accessToken, this.committedAny);
  final String accessToken;
  final bool committedAny;
}
