part of 'device_registration_client.dart';

/// Ephemeral capability constructed only from a registered API response.
/// Never serialize this object or put URLs/tokens in a queue/log.
class DriverPhotoUpload {
  DriverPhotoUpload._(this._issuer, this._device, this._wire);
  final DriverDeviceRegistrationClient _issuer;
  final RegisteredDriverDevice _device;
  final Map<String, dynamic> _wire;
  @override
  String toString() => 'DriverPhotoUpload(redacted)';
}

extension NativePhotoUpload on DriverDeviceRegistrationClient {
  /// This finite adapter supports raw signed PUT, with no separate token.
  /// Other protocols require a configured adapter, never guessed headers.
  Future<void> uploadPhoto({
    required RegisteredDriverDevice device,
    required DriverPhotoUpload capability,
    required String assetId,
    required String mimeType,
    required String sha256,
    required List<int> bytes,
  }) async {
    device.requireCurrentSession();
    if (!identical(capability._issuer, this) ||
        !identical(capability._device, device) ||
        !identical(device._issuer, _issuer)) {
      throw const DeviceEnrollmentException('NOT_AUTHORIZED');
    }
    final cap = capability._wire;
    final uri = Uri.tryParse(cap['upload_url'] as String);
    final expires = DateTime.tryParse(cap['expires_at'] as String);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.host.isEmpty ||
        !_uploadOrigins.contains(
          Uri(
            scheme: uri.scheme,
            host: uri.host,
            port: uri.hasPort ? uri.port : null,
          ),
        ) ||
        cap['asset_id'] != assetId ||
        cap['upload_method'] != 'PUT' ||
        cap['upload_token'] != null ||
        expires == null ||
        !expires.isAfter(_now().toUtc()) ||
        expires.isAfter(_now().toUtc().add(const Duration(minutes: 5))) ||
        !{'image/jpeg', 'image/png'}.contains(mimeType) ||
        bytes.isEmpty ||
        bytes.length > 20 * 1024 * 1024 ||
        sha256 != _photoDigest(bytes)) {
      throw const DeviceEnrollmentException('UPLOAD_NOT_CONFIGURED_OR_INVALID');
    }
    if (!device.expiresAt.isAfter(_now().toUtc())) {
      lock();
      throw const DeviceEnrollmentException('UNAUTHENTICATED');
    }
    final abort = Completer<void>();
    final unsubscribe = device.onStorageLock(() {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      await (() async {
        final request =
            http.AbortableRequest('PUT', uri, abortTrigger: abort.future)
              ..followRedirects = false
              ..headers['Content-Type'] = mimeType
              ..bodyBytes = bytes;
        // No application bearer, device session, cookies or arbitrary headers.
        final response = await _client.send(request);
        await response.stream.listen(null).cancel();
        device.requireCurrentSession();
        if (!device.expiresAt.isAfter(_now().toUtc())) {
          lock();
          throw const DeviceEnrollmentException('UNAUTHENTICATED');
        }
        if (![200, 201, 204].contains(response.statusCode)) {
          throw const DeviceEnrollmentException('UPLOAD_RESULT_UNKNOWN');
        }
      })().timeout(timeout);
    } on DeviceEnrollmentException {
      rethrow;
    } catch (_) {
      throw const DeviceEnrollmentException('UPLOAD_RESULT_UNKNOWN');
    } finally {
      unsubscribe();
      if (!abort.isCompleted) abort.complete();
    }
  }
}

String _photoDigest(List<int> bytes) => sha256.convert(bytes).toString();
