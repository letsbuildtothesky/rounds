import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'device_wire.dart';
import 'execution_query.dart';
import 'encrypted_work_store.dart';
import 'command_wire.dart';

part 'installation_store.dart';
part 'command_transport.dart';
part 'photo_upload_transport.dart';

/// Transport capability, not a job assignment, proof, or offline authority.
class RegisteredDriverDevice {
  RegisteredDriverDevice._(
    Map<String, dynamic> wire,
    this.storageNamespace,
    this.requireCurrentSession,
    this.onStorageLock,
    this._issuer,
  ) : principalId = (wire['principal_id'] as String).toLowerCase(),
      deviceId = (wire['device_id'] as String).toLowerCase(),
      epoch = wire['session_epoch'] as int,
      _capability = wire['device_session'] as String,
      expiresAt = DateTime.parse(wire['expires_at'] as String).toUtc();

  final String principalId;
  final String deviceId;
  final int epoch;
  final DateTime expiresAt;
  final String _capability;
  final Object _issuer;

  /// Opaque environment + verified subject binding, not caller input.
  final String storageNamespace;
  final void Function() requireCurrentSession;

  /// Returns an unsubscribe callback. Lock closes stores but never deletes data.
  final void Function() Function(void Function()) onStorageLock;

  /// Never put these headers in command bytes, SQLite, analytics or logs.
  Map<String, String> get transportHeaders => {
    'X-Rounds-Device-Session': _capability,
  };
  @override
  String toString() => 'RegisteredDriverDevice(redacted)';
}

/// main constructs this only in the default-off storage debug checkpoint.
/// Configured Auth/mobile migration and the business sender remain gated.
class DriverDeviceRegistrationClient {
  DriverDeviceRegistrationClient({
    required Uri authOrigin,
    required Uri apiOrigin,
    required String publishableKey,
    required this._store,
    required this._client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 10),
    Set<Uri> uploadOrigins = const {},
  }) : _authOrigin = _secureOrigin(authOrigin),
       _apiOrigin = _secureOrigin(apiOrigin),
       _uploadOrigins = Set.unmodifiable(
         uploadOrigins.map((u) {
           final v = _secureOrigin(u);
           return Uri(
             scheme: v.scheme,
             host: v.host,
             port: v.hasPort ? v.port : null,
           );
         }),
       ),
       _publishableKey = publishableKey,
       _now = now ?? DateTime.now {
    if (publishableKey.isEmpty ||
        publishableKey.contains(RegExp(r'[\r\n]')) ||
        timeout <= Duration.zero) {
      throw const DeviceEnrollmentException('INVALID_CONFIGURATION');
    }
  }

  final Uri _authOrigin;
  final Uri _apiOrigin;
  final Set<Uri> _uploadOrigins;
  final String _publishableKey;
  final DeviceInstallationStore _store;
  final http.Client _client;
  final DateTime Function() _now;
  final Duration timeout;
  int _sessionGeneration = 0;
  bool _closed = false;
  String? _activeStorageScope;
  int _storageGeneration = 0;
  final _storageClosers = <void Function()>{};
  final Object _issuer = Object();

  /// Call on sign-out/account switch BEFORE awaiting token removal. Does not
  /// erase the stable installation identity or another principal's evidence.
  void lock() {
    _sessionGeneration++;
    _closeStorage();
    _activeStorageScope = null;
  }

  void _closeStorage() {
    _storageGeneration++;
    _activeStorageScope = null;
    for (final close in _storageClosers.toList()) {
      try {
        close();
      } catch (_) {
        /* Invalidate every handle even if native close fails. */
      }
    }
    _storageClosers.clear();
  }

  /// Owner manages the injected HTTP client; no network/storage cleanup here.
  void dispose() {
    lock();
    _closed = true;
  }

  Future<RegisteredDriverDevice> ensureSession(String bearer) {
    final generation = _sessionGeneration;
    return _store._serialized(() async {
      final subject = _storageScope(await _verifiedSubject(bearer, generation));
      if (_activeStorageScope != subject) {
        _closeStorage();
      }
      var record = await _store._load(subject, create: true);
      _checkActive(generation);
      if (record!.state != 'active') {
        throw const DeviceEnrollmentException('DEVICE_REQUIRES_RECOVERY');
      }
      final request = deviceWire('DriverDeviceSessionRequest', {
        'installation_secret': record.secret,
        'platform': record.platform,
      });
      Map<String, dynamic> response;
      try {
        response = await _request(
          _apiOrigin.resolve('/v1/auth/driver-device/session'),
          bearer,
          body: request,
          limit: 4096,
        );
      } on DeviceEnrollmentException catch (error) {
        // Denial never triggers automatic key rotation/re-enrollment.
        if (error.code == 'NOT_AUTHORIZED') {
          _closeStorage();
          record = record.withState('blocked');
          await _store._save(subject, record);
        }
        rethrow;
      }
      _checkActive(generation);
      final storageGeneration = _storageGeneration;
      final result = RegisteredDriverDevice._(
        deviceWire('DriverDeviceSessionResult', response),
        sha256.convert(utf8.encode(subject)).toString(),
        () {
          _checkActive(generation);
          if (_activeStorageScope != subject ||
              storageGeneration != _storageGeneration) {
            throw const DeviceEnrollmentException('SESSION_CHANGED');
          }
        },
        (close) {
          _storageClosers.add(close);
          return () => _storageClosers.remove(close);
        },
        _issuer,
      );
      final remaining = result.expiresAt.difference(_now().toUtc());
      if (remaining <= Duration.zero ||
          remaining > const Duration(minutes: 15)) {
        throw const DeviceEnrollmentException('INVALID_RESPONSE');
      }
      if ((record.principal != null &&
              record.principal != result.principalId) ||
          (record.device != null && record.device != result.deviceId) ||
          (record.epoch != null && record.epoch! > result.epoch)) {
        _closeStorage();
        await _store._save(subject, record.withState('blocked'));
        throw const DeviceEnrollmentException('IDENTITY_MISMATCH');
      }
      await _store._save(
        subject,
        _InstallationRecord(
          secret: record.secret,
          platform: record.platform,
          principal: result.principalId,
          device: result.deviceId,
          epoch: result.epoch,
          state: 'active',
        ),
      );
      _checkActive(generation);
      _activeStorageScope = subject;
      return result;
    });
  }

  /// Same explicit HTTPS origin and registered device; no legacy cache fallback.
  Future<DriverExecutionSnapshot> fetchExecution({
    required String bearer,
    required RegisteredDriverDevice device,
    required String tenantId,
    required String cityId,
    required String roundId,
  }) async {
    for (final id in [tenantId, cityId, roundId]) {
      if (!isDeviceUuid(id) || id != id.toLowerCase()) {
        throw const DeviceEnrollmentException('VALIDATION_FAILED');
      }
    }
    device.requireCurrentSession();
    if (!device.expiresAt.isAfter(_now().toUtc())) {
      throw const DeviceEnrollmentException('UNAUTHENTICATED');
    }
    final response = await _request(
      _apiOrigin
          .resolve('/v1/queries/DriverRound')
          .replace(
            queryParameters: {
              'entity_id': roundId,
              'tenant_id': tenantId,
              'city_id': cityId,
              'view': 'execution',
            },
          ),
      bearer,
      limit: 65536,
      deviceHeaders: device.transportHeaders,
    );
    device.requireCurrentSession();
    final result = DriverExecutionSnapshot.parse(response);
    final c = result.context.toJson();
    if (c['principal_id'] != device.principalId ||
        c['round_id'] != roundId ||
        c['tenant_id'] != tenantId ||
        c['city_id'] != cityId ||
        !device.expiresAt.isAfter(_now().toUtc())) {
      throw const DeviceEnrollmentException('INVALID_RESPONSE');
    }
    return result;
  }

  /// Display view is opt-in: old execution readers keep their exact wire shape.
  Future<DriverPickupSnapshot> fetchPickup({
    required String bearer,
    required RegisteredDriverDevice device,
    required String tenantId,
    required String cityId,
    required String roundId,
  }) async {
    for (final id in [tenantId, cityId, roundId]) {
      if (!isDeviceUuid(id) || id != id.toLowerCase()) {
        throw const DeviceEnrollmentException('VALIDATION_FAILED');
      }
    }
    device.requireCurrentSession();
    if (!device.expiresAt.isAfter(_now().toUtc())) {
      throw const DeviceEnrollmentException('UNAUTHENTICATED');
    }
    final response = await _request(
      _apiOrigin
          .resolve('/v1/queries/DriverRound')
          .replace(
            queryParameters: {
              'entity_id': roundId,
              'tenant_id': tenantId,
              'city_id': cityId,
              'view': 'pickup',
            },
          ),
      bearer,
      limit: 65536,
      deviceHeaders: device.transportHeaders,
    );
    device.requireCurrentSession();
    final result = DriverPickupSnapshot.parse(response);
    final c = result.execution.context.toJson();
    if (c['principal_id'] != device.principalId ||
        c['round_id'] != roundId ||
        c['tenant_id'] != tenantId ||
        c['city_id'] != cityId ||
        !device.expiresAt.isAfter(_now().toUtc())) {
      throw const DeviceEnrollmentException('INVALID_RESPONSE');
    }
    return result;
  }

  Future<DriverPickupIssueSnapshot> fetchPickupIssue({
    required String bearer,
    required RegisteredDriverDevice device,
    required ReportedPickupIssue report,
  }) async {
    device.requireCurrentSession();
    final original = report.toJson();
    if (original['principal_id'] != device.principalId ||
        !device.expiresAt.isAfter(_now().toUtc())) {
      throw const DeviceEnrollmentException('UNAUTHENTICATED');
    }
    final response = await _request(
      _apiOrigin
          .resolve('/v1/queries/DriverRound')
          .replace(
            queryParameters: {
              'entity_id': original['round_id'] as String,
              'tenant_id': original['tenant_id'] as String,
              'city_id': original['city_id'] as String,
              'view': 'pickup_issue',
              'issue_id': original['issue_id'] as String,
            },
          ),
      bearer,
      limit: 65536,
      deviceHeaders: device.transportHeaders,
    );
    device.requireCurrentSession();
    if (!device.expiresAt.isAfter(_now().toUtc())) {
      throw const DeviceEnrollmentException('UNAUTHENTICATED');
    }
    final snapshot = DriverPickupIssueSnapshot.parse(response);
    snapshot.requireOriginalReport(report);
    return snapshot;
  }

  /// Explicit self-revocation only. Unknown response keeps a durable local
  /// revoke_pending latch. A later explicit retry uses the unchanged secret.
  Future<void> revoke(String bearer) {
    final generation = _sessionGeneration;
    return _store._serialized(() async {
      final subject = _storageScope(await _verifiedSubject(bearer, generation));
      final record = await _store._load(subject, create: false);
      _checkActive(generation);
      if (record == null) throw const DeviceEnrollmentException('NOT_ENROLLED');
      _closeStorage();
      _activeStorageScope = null;
      // Even a completed local revoke is verified at the server on explicit
      // retry, so an interrupted response can never create a second identity.
      await _store._save(subject, record.withState('revoke_pending'));
      _checkActive(generation);
      final result = deviceWire(
        'DriverDeviceRevokeResult',
        await _request(
          _apiOrigin.resolve('/v1/auth/driver-device/revoke'),
          bearer,
          body: deviceWire('DriverDeviceRevokeRequest', {
            'installation_secret': record.secret,
          }),
          limit: 4096,
        ),
      );
      if (record.device != null &&
          record.device != (result['device_id'] as String).toLowerCase()) {
        throw const DeviceEnrollmentException('IDENTITY_MISMATCH');
      }
      await _store._save(subject, record.withState('revoked'));
      _checkActive(generation);
    });
  }

  Future<String> _verifiedSubject(String bearer, int generation) async {
    _checkActive(generation);
    if (bearer.isEmpty ||
        bearer.length > 8192 ||
        bearer.contains(RegExp(r'\s'))) {
      throw const DeviceEnrollmentException('UNAUTHENTICATED');
    }
    // Do not decode a JWT or trust a caller-selected principal/cache owner.
    // Server independently verifies this same bearer during enrollment.
    final user = await _request(
      _authOrigin.resolve('/auth/v1/user'),
      bearer,
      limit: 65536,
      provider: true,
    );
    _checkActive(generation);
    if (!isDeviceUuid(user['id'])) {
      throw const DeviceEnrollmentException('INVALID_RESPONSE');
    }
    return (user['id'] as String).toLowerCase();
  }

  Future<Map<String, dynamic>> _request(
    Uri uri,
    String bearer, {
    Map<String, dynamic>? body,
    required int limit,
    bool provider = false,
    Map<String, String> deviceHeaders = const {},
  }) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(
            body == null ? 'GET' : 'POST',
            uri,
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..headers.addAll({
            'authorization': 'Bearer $bearer',
            'accept': 'application/json',
            if (provider) 'apikey': _publishableKey,
            if (body != null) 'content-type': 'application/json',
            ...deviceHeaders,
          });
    if (body != null) request.body = jsonEncode(body);
    try {
      return await (() async {
        final response = await _client.send(request);
        final bytes = <int>[];
        if ((response.contentLength ?? 0) > limit) {
          await response.stream.listen(null).cancel();
          throw const DeviceEnrollmentException('INVALID_RESPONSE');
        }
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > limit) {
            throw const DeviceEnrollmentException('INVALID_RESPONSE');
          }
          bytes.addAll(chunk);
        }
        if (response.statusCode != 200) {
          // Deliberately do not reflect arbitrary provider messages to UI/logs.
          String? code;
          if (!provider) {
            try {
              code = (jsonDecode(utf8.decode(bytes)) as Map)['code'] as String?;
            } catch (_) {
              /* Unknown bodies remain a safe transport failure. */
            }
          }
          const allowed = {
            'NOT_AUTHORIZED',
            'FEATURE_NOT_ENABLED',
            'UPGRADE_REQUIRED',
            'UNKNOWN_RESULT',
            'RATE_LIMITED',
            'UNAUTHENTICATED',
            'VALIDATION_FAILED',
            'PROVIDER_UNAVAILABLE',
            'POLICY_NOT_CONFIGURED',
            'MANIFEST_MISMATCH',
          };
          throw DeviceEnrollmentException(
            response.statusCode == 401
                ? 'UNAUTHENTICATED'
                : response.statusCode == 429
                ? 'RATE_LIMITED'
                : allowed.contains(code)
                ? code!
                : 'PROVIDER_UNAVAILABLE',
          );
        }
        if (!(response.headers['content-type'] ?? '').toLowerCase().startsWith(
          'application/json',
        )) {
          throw const DeviceEnrollmentException('INVALID_RESPONSE');
        }
        final parsed = jsonDecode(utf8.decode(bytes));
        if (parsed is! Map<String, dynamic>) {
          throw const DeviceEnrollmentException('INVALID_RESPONSE');
        }
        return parsed;
      })().timeout(timeout);
    } on DeviceEnrollmentException {
      rethrow;
    } on FormatException {
      throw const DeviceEnrollmentException('INVALID_RESPONSE');
    } catch (_) {
      // A timed-out POST may have committed. Retry the SAME durable identity;
      // this request continuation never writes storage or returns credentials.
      throw DeviceEnrollmentException(
        body == null ? 'PROVIDER_UNAVAILABLE' : 'UNKNOWN_RESULT',
      );
    } finally {
      // Native IOClient honours this even while headers/body are outstanding.
      // Injected test clients must support abort for transport resource tests.
      if (!abort.isCompleted) abort.complete();
    }
  }

  void _checkActive(int generation) {
    if (_closed || generation != _sessionGeneration) {
      throw const DeviceEnrollmentException('SESSION_CHANGED');
    }
  }

  String _storageScope(String subject) =>
      '${_authOrigin.origin}\n${_apiOrigin.origin}\n$subject';

  static Uri _secureOrigin(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path != '' && uri.path != '/')) {
      throw const DeviceEnrollmentException('INVALID_CONFIGURATION');
    }
    return uri;
  }
}
