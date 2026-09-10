part of 'device_registration_client.dart';

/// Only key/value credential operations; intentionally no delete/deleteAll.
abstract interface class DeviceSecretBackend {
  factory DeviceSecretBackend.native() => _NativeDeviceSecrets();
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class _NativeDeviceSecrets implements DeviceSecretBackend {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'rounds_v23_installations',
      resetOnError: false,
      migrateWithBackup: true,
    ),
    iOptions: IOSOptions(
      accountName: 'rounds.v23.installations',
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) async {
    await storage.write(key: key, value: value);
    if (Platform.isAndroid) {
      // Plugin10.3.1 normal writes use SharedPreferences.apply(). Read-back
      // sees memory, not disk. The native barrier commits ONLY our namespace,
      // wrapped key and config before enrollment may send the secret.
      final committed = await const MethodChannel(
        'app.rounds/v23_installation_durability',
      ).invokeMethod<bool>('flushV1');
      if (committed != true) {
        throw const DeviceEnrollmentException('SECURE_STORAGE_UNAVAILABLE');
      }
    }
  }
}

class DeviceInstallationStore {
  DeviceInstallationStore({required this._backend, required this.platform}) {
    if (!{'android', 'ios'}.contains(platform)) {
      throw const DeviceEnrollmentException('UNSUPPORTED_PLATFORM');
    }
  }

  factory DeviceInstallationStore.native() => DeviceInstallationStore(
    backend: _NativeDeviceSecrets(),
    platform: Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : 'unsupported',
  );

  final DeviceSecretBackend _backend;
  final String platform;

  // One lifecycle writer in the foreground isolate. Background isolates must
  // broker through it; cross-isolate coordination is a client activation gate.
  static Future<void> _tail = Future<void>.value();
  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _key(String subject) =>
      'installation.v1.${sha256.convert(utf8.encode(subject))}';

  Future<_InstallationRecord?> _load(
    String subject, {
    required bool create,
  }) async {
    try {
      final raw = await _backend.read(_key(subject));
      if (raw != null) {
        final record = _InstallationRecord.decode(raw);
        if (record.platform != platform) {
          throw const DeviceEnrollmentException('IDENTITY_MISMATCH');
        }
        return record;
      }
      if (!create) return null;
      final random =
          Random.secure(); // No fallback to timestamps/UUID/weak PRNG.
      final record = _InstallationRecord(
        secret: List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
        platform: platform,
        state: 'active',
      );
      // Persist and read back BEFORE any server registration. Failure never
      // results in sending a new transient secret or clearing existing storage.
      await _save(subject, record);
      return record;
    } on DeviceEnrollmentException {
      rethrow;
    } catch (_) {
      throw const DeviceEnrollmentException('SECURE_STORAGE_UNAVAILABLE');
    }
  }

  Future<void> _save(String subject, _InstallationRecord record) async {
    try {
      final encoded = record.encode();
      await _backend.write(_key(subject), encoded);
      if (await _backend.read(_key(subject)) != encoded) {
        throw const DeviceEnrollmentException('SECURE_STORAGE_UNAVAILABLE');
      }
    } on DeviceEnrollmentException {
      rethrow;
    } catch (_) {
      throw const DeviceEnrollmentException('SECURE_STORAGE_UNAVAILABLE');
    }
  }
}

class _InstallationRecord {
  const _InstallationRecord({
    required this.secret,
    required this.platform,
    required this.state,
    this.principal,
    this.device,
    this.epoch,
  });
  final String secret, platform, state;
  final String? principal, device;
  final int? epoch;

  _InstallationRecord withState(String value) => _InstallationRecord(
    secret: secret,
    platform: platform,
    state: value,
    principal: principal,
    device: device,
    epoch: epoch,
  );
  String encode() => jsonEncode({
    'version': 1,
    'secret': secret,
    'platform': platform,
    'state': state,
    'principal': principal,
    'device': device,
    'epoch': epoch,
  });

  static _InstallationRecord decode(String raw) {
    try {
      if (raw.length > 2048) throw const FormatException();
      final value = jsonDecode(raw) as Map<String, dynamic>;
      const keys = {
        'version',
        'secret',
        'platform',
        'state',
        'principal',
        'device',
        'epoch',
      };
      if (value.length != keys.length ||
          !keys.every(value.containsKey) ||
          value['version'] != 1 ||
          !{
            'active',
            'blocked',
            'revoke_pending',
            'revoked',
          }.contains(value['state'])) {
        throw const FormatException();
      }
      deviceWire('DriverDeviceSessionRequest', {
        'installation_secret': value['secret'],
        'platform': value['platform'],
      });
      final bound = value['principal'] != null;
      if (bound
          ? (!isDeviceUuid(value['principal']) ||
                !isDeviceUuid(value['device']) ||
                value['epoch'] is! int ||
                value['epoch'] < 1 ||
                value['epoch'] > 9007199254740991)
          : (value['device'] != null || value['epoch'] != null)) {
        throw const FormatException();
      }
      return _InstallationRecord(
        secret: value['secret'] as String,
        platform: value['platform'] as String,
        state: value['state'] as String,
        principal: value['principal'] as String?,
        device: value['device'] as String?,
        epoch: value['epoch'] as int?,
      );
    } catch (_) {
      throw const DeviceEnrollmentException('SECURE_STORAGE_CORRUPT');
    }
  }
}
