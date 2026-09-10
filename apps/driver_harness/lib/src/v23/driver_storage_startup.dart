import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as legacy;

import '../storage/legacy_startup_gate.dart';
import 'device_registration_client.dart';
import 'driver_storage_auth.dart';
import 'driver_storage_lifecycle.dart';
import 'legacy_recovery_archive.dart';

/// Existing-Driver5 diagnostic cohort only, not a client/data cutover. The
/// archive is a point-in-time copy; legacy writes after startup stay legacy.
class DriverStorageStartup {
  DriverStorageStartup({
    required DriverStorageLifecycle lifecycle,
    required this._gate,
    required this._closeTransport,
  }) : auth = DriverStorageAuth(lifecycle);

  final DriverStorageAuth auth;
  final LegacyStartupGate _gate;
  final void Function() _closeTransport;
  Future<void>? _disposing;

  Future<void> start() => _gate.prepare(auth.lifecycle.start);

  /// Called by main BEFORE the controller, runApp, cache restoration, queue
  /// inspection, timers, telemetry or camera/draft writers can be constructed.
  /// Default path does not resolve directories, keys, archive or HTTP at all.
  static Future<DriverStorageStartup?> startNative() async {
    if (!const bool.fromEnvironment('ROUNDS_V23_STORAGE_CHECKPOINT')) {
      return null;
    }
    validateCohort(debug: kDebugMode, android: Platform.isAndroid);
    final client = http.Client();
    DriverStorageStartup? startup;
    try {
      final secrets = DeviceSecretBackend.native();
      final registration = DriverDeviceRegistrationClient(
        authOrigin: Uri.parse(const String.fromEnvironment('SUPABASE_URL')),
        // Explicit separate v2.3 origin. Never fall back to the legacy emulator
        // HTTP URL, a production URL, or a bundled account/credential.
        apiOrigin: Uri.parse(
          const String.fromEnvironment('ROUNDS_V23_API_ORIGIN'),
        ),
        publishableKey: const String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
        ),
        store: DeviceInstallationStore(backend: secrets, platform: 'android'),
        client: client,
      );
      startup = DriverStorageStartup(
        gate: LegacyStartupGate.process,
        closeTransport: client.close,
        lifecycle: DriverStorageLifecycle(
          registration: registration,
          secrets: secrets,
          prepareLegacy: (root) async {
            final databasePath = p.join(
              await legacy.getDatabasesPath(),
              'rounds_phase_zero.db',
            );
            final receipt = await LegacyRecoveryArchive.preserve(
              databasePath: databasePath,
              factory: legacy.databaseFactory,
              supportDirectory: await getApplicationSupportDirectory(),
              archiveParent: root,
              readDraftPreferences: readLegacyDraftPreferences,
              secrets: secrets,
            );
            if (receipt.sourceIssues != 0) {
              throw const StorageLifecycleException(
                'LEGACY_SOURCE_REQUIRES_RECOVERY',
              );
            }
          },
        ),
      );
      await startup.start();
      startup.auth.lifecycle.observe(WidgetsBinding.instance);
      return startup;
    } catch (_) {
      if (startup != null) {
        await startup.dispose();
      } else {
        client.close();
      }
      // No fallback controller/UI/legacy worker on preparation/config failure.
      throw const StorageLifecycleException('STARTUP_REQUIRES_RECOVERY');
    }
  }

  static void validateCohort({required bool debug, required bool android}) {
    if (!debug || !android) {
      throw const StorageLifecycleException('STORAGE_COHORT_NOT_SUPPORTED');
    }
  }

  Future<void> dispose() =>
      _disposing ??= auth.dispose().whenComplete(_closeTransport);
}
