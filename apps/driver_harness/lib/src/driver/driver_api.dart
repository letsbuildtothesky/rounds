import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../storage/driver_command_outbox.dart';
import 'driver_session.dart';

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
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client(),
       _outboxFactory = outboxFactory ?? DriverCommandOutbox.open;

  static const _accessTokenKey = 'rounds_driver_access_token';
  static const _refreshTokenKey = 'rounds_driver_refresh_token';

  final String supabaseUrl;
  final String publishableKey;
  final String roundsApiUrl;
  final FlutterSecureStorage _storage;
  final http.Client _client;
  final Future<DriverCommandOutbox> Function() _outboxFactory;
  DriverCommandOutbox? _outbox;

  bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      publishableKey.isNotEmpty &&
      roundsApiUrl.isNotEmpty;

  Future<DriverSessionModel?> restore() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null) return null;
    try {
      var session = await _driverSession(accessToken);
      final flush = await _flushPending(accessToken);
      if (flush.committedAny) session = await _driverSession(flush.accessToken);
      return session;
    } on _Unauthorized {
      final refreshed = await _refresh();
      if (refreshed == null) {
        await signOut();
        return null;
      }
      var session = await _driverSession(refreshed);
      final flush = await _flushPending(refreshed);
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
      final flush = await _flushPending(accessToken);
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

  Future<DriverCommandOutbox> _commandOutbox() async =>
      _outbox ??= await _outboxFactory();

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
