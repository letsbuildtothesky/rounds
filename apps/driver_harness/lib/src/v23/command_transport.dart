part of 'device_registration_client.dart';

/// Only this registered HTTPS transport can construct a receipt candidate.
/// Store still checks command identity, semantic binding and original lease.
class DriverCommandReply {
  DriverCommandReply._(
    this._json,
    this.httpStatus,
    this.retryAfterSeconds,
    this.upload,
  );
  final String _json;
  final int httpStatus;
  final int retryAfterSeconds;
  final DriverPhotoUpload? upload;
  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  @override
  String toString() => 'DriverCommandReply(redacted)';
}

extension NativeExecutionTransport on DriverDeviceRegistrationClient {
  /// One bounded exchange only. The encrypted queue owns retries and status
  /// reconciliation; no automatic redirect, background retry or token storage.
  Future<DriverCommandReply> exchangeExecutionCommand({
    required RegisteredDriverDevice device,
    required String bearer,
    required String commandType,
    required String frozenRequest,
    required bool statusOnly,
  }) async {
    if (!nativeExecutionCommands.contains(commandType) ||
        !identical(device._issuer, _issuer)) {
      throw const DeviceEnrollmentException('NOT_AUTHORIZED');
    }
    device.requireCurrentSession();
    if (!device.expiresAt.isAfter(_now().toUtc()) ||
        bearer.isEmpty ||
        bearer.contains(RegExp(r'[\r\n]'))) {
      lock();
      throw const DeviceEnrollmentException('UNAUTHENTICATED');
    }
    final wire = jsonDecode(frozenRequest) as Map<String, dynamic>;
    validateCommandWire('${commandType}Request', wire);
    if (canonicalNativeCommand(wire) != frozenRequest) {
      throw const DeviceEnrollmentException('INVALID_COMMAND_WIRE');
    }
    final uri = statusOnly
        ? _apiOrigin
              .resolve('/v1/queries/CommandStatus')
              .replace(
                queryParameters: {
                  'entity_id': wire['command_id'] as String,
                  'tenant_id': wire['context']['tenant_id'] as String,
                  'city_id': wire['context']['city_id'] as String,
                },
              )
        : _apiOrigin.resolve('/v1/commands/$commandType');
    final abort = Completer<void>();
    try {
      return await (() async {
        final request =
            http.AbortableRequest(
                statusOnly ? 'GET' : 'POST',
                uri,
                abortTrigger: abort.future,
              )
              ..followRedirects = false
              ..headers.addAll({
                'Authorization': 'Bearer $bearer',
                'Accept': 'application/json',
                ...device.transportHeaders,
              });
        if (!statusOnly) {
          request.headers['Content-Type'] = 'application/json';
          request.bodyBytes = utf8.encode(frozenRequest);
        }
        final response = await _client.send(request);
        if ((response.contentLength ?? 0) > 1048576) {
          await response.stream.listen(null).cancel();
          throw const DeviceEnrollmentException('INVALID_RESPONSE');
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 1048576) {
            throw const DeviceEnrollmentException('INVALID_RESPONSE');
          }
          bytes.addAll(chunk);
        }
        device.requireCurrentSession();
        if (response.statusCode == 401 || response.statusCode == 403) {
          lock();
          throw DeviceEnrollmentException(
            response.statusCode == 401 ? 'UNAUTHENTICATED' : 'NOT_AUTHORIZED',
          );
        }
        if (!device.expiresAt.isAfter(_now().toUtc())) {
          lock();
          throw const DeviceEnrollmentException('UNAUTHENTICATED');
        }
        if (!(response.headers['content-type'] ?? '').toLowerCase().startsWith(
          'application/json',
        )) {
          throw const DeviceEnrollmentException('INVALID_RESPONSE');
        }
        var value = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        if (response.statusCode != 200) {
          validateCommandWire('Error', value);
        } else {
          if (statusOnly) {
            if (value.length != 3 ||
                !isDeviceInstant(value['as_of']) ||
                value['next_cursor'] != null ||
                value['data'] is! Map ||
                (value['data'] as Map).length != 1 ||
                value['data']['result'] is! Map<String, dynamic>) {
              throw const DeviceEnrollmentException('INVALID_RESPONSE');
            }
            value = value['data']['result'] as Map<String, dynamic>;
          }
          validateCommandWire(
            value['state'] == 'rejected'
                ? 'RejectedCommandStatus'
                : {'queued', 'in_progress'}.contains(value['state'])
                ? 'PendingCommandStatus'
                : '${commandType}Result',
            value,
          );
          if (value['command_id'] != wire['command_id'] ||
              value['command_type'] != commandType) {
            throw const DeviceEnrollmentException('INVALID_RESPONSE');
          }
        }
        DriverPhotoUpload? upload;
        if (response.statusCode == 200 &&
            commandType == 'ReserveAsset' &&
            value['state'] == 'committed') {
          upload = DriverPhotoUpload._(
            this,
            device,
            Map<String, dynamic>.from(value['data'] as Map),
          );
          value = {
            ...value,
            'data': {'asset_id': value['data']['asset_id']},
          };
        }
        return DriverCommandReply._(
          canonicalNativeCommand(value),
          response.statusCode,
          RegExp(r'^\d{1,9}$').hasMatch(response.headers['retry-after'] ?? '')
              ? int.parse(response.headers['retry-after']!)
              : response.statusCode == 429
              ? 60
              : 30,
          upload,
        );
      })().timeout(timeout);
    } on DeviceEnrollmentException {
      rethrow;
    } catch (_) {
      throw const DeviceEnrollmentException('UNKNOWN_RESULT');
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }
}
