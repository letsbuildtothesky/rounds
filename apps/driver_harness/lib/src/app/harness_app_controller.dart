import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';
import '../connectivity/driver_sync_state.dart';
import '../driver/driver_api.dart';
import '../driver/driver_session.dart';
import '../driver/driver_operations_thread.dart';
import '../telemetry/telemetry_uploader.dart';

class HarnessAppController extends ChangeNotifier {
  HarnessAppController._(
    this._preferences,
    this._locale,
    this._hasSelectedLanguage,
    this._driverApi,
    this._queueInspector,
    this._sessionStorage,
  );

  static const _localeKey = 'driver_locale';
  static const _selectedKey = 'driver_locale_selected';
  static const _sessionCacheKey = 'driver_session_cache_v1';
  static const _lastSyncedAtKey = 'driver_session_last_synced_at_v1';

  final SharedPreferences _preferences;
  HarnessLocale _locale;
  bool _hasSelectedLanguage;
  final DriverApi _driverApi;
  final DriverQueueInspector _queueInspector;
  final FlutterSecureStorage _sessionStorage;
  DriverSessionModel? _driverSession;
  bool _driverLoading = false;
  String? _driverError;
  DriverSyncSnapshot _syncSnapshot = const DriverSyncSnapshot.online();
  bool _showConnectionSurface = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _sessionRefreshTimer;
  bool _silentRefreshRunning = false;

  HarnessLocale get locale => _locale;
  bool get hasSelectedLanguage => _hasSelectedLanguage;
  AppStrings get strings => AppStrings(_locale);
  bool get driverConfigured => _driverApi.isConfigured;
  bool get oneTapPilotSignInConfigured =>
      !kReleaseMode &&
      _pilotDriverEmail.isNotEmpty &&
      _pilotDriverPassword.isNotEmpty;
  DriverSessionModel? get driverSession => _driverSession;
  bool get driverLoading => _driverLoading;
  String? get driverError => _driverError;
  DriverSyncSnapshot get syncSnapshot => _syncSnapshot;
  bool get showConnectionSurface => _showConnectionSurface;

  static const _pilotDriverEmail = String.fromEnvironment('PILOT_DRIVER_EMAIL');
  static const _pilotDriverPassword = String.fromEnvironment(
    'PILOT_DRIVER_PASSWORD',
  );

  static Future<HarnessAppController> create() async {
    final preferences = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    final controller = HarnessAppController._(
      preferences,
      HarnessLocaleValue.fromStorage(preferences.getString(_localeKey)),
      preferences.getBool(_selectedKey) ?? false,
      DriverApi(
        supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
        publishableKey: const String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
        ),
        roundsApiUrl: const String.fromEnvironment(
          'ROUNDS_API_URL',
          defaultValue: 'http://10.0.2.2:8080',
        ),
        storage: secureStorage,
      ),
      const SqliteDriverQueueInspector(),
      secureStorage,
    );
    if (controller.driverConfigured) {
      await controller._restoreCachedSession();
      await controller._startConnectivityMonitoring();
      controller._startSessionRefresh();
    }
    return controller;
  }

  Future<void> restoreDriverSession() async {
    if (!driverConfigured) return;
    _driverLoading = true;
    _driverError = null;
    notifyListeners();
    try {
      final restored = await _driverApi.restore().timeout(
        const Duration(seconds: 15),
      );
      _driverSession = restored;
      if (restored == null) {
        await _clearCachedSession();
      } else {
        await _saveSession(restored);
        await _flushPendingTelemetry();
      }
      await _refreshSyncSnapshot(
        phase: DriverConnectionPhase.online,
        syncedNow: restored != null,
      );
      if (restored != null &&
          _syncSnapshot.phase == DriverConnectionPhase.reconnecting) {
        _showConnectionSurface = true;
      }
    } catch (error) {
      _driverError = error.toString();
      await _refreshSyncSnapshot(phase: DriverConnectionPhase.offline);
      if (_driverSession != null) _showConnectionSurface = true;
    } finally {
      _driverLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInDriver(String email, String password) async {
    _driverLoading = true;
    _driverError = null;
    notifyListeners();
    try {
      _driverSession = await _driverApi.signIn(email, password);
      await _saveSession(_driverSession!);
      await _flushPendingTelemetry();
      await _refreshSyncSnapshot(
        phase: DriverConnectionPhase.online,
        syncedNow: true,
      );
      if (_syncSnapshot.phase == DriverConnectionPhase.reconnecting) {
        _showConnectionSurface = true;
      }
    } catch (error) {
      _driverError = error.toString();
    } finally {
      _driverLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInPilotDriver() {
    if (!oneTapPilotSignInConfigured) {
      throw StateError('One-tap pilot sign-in is not configured');
    }
    return signInDriver(_pilotDriverEmail, _pilotDriverPassword);
  }

  Future<void> refreshDriverSession() async {
    await restoreDriverSession();
  }

  Future<DriverCommandOutcome?> startShift() {
    final session = _driverSession;
    if (session == null) return Future.value(null);
    return _runDriverCommand(() => _driverApi.startShift(session));
  }

  Future<DriverCommandOutcome?> endShift() {
    final session = _driverSession;
    if (session == null) return Future.value(null);
    return _runDriverCommand(() => _driverApi.endShift(session));
  }

  void _startSessionRefresh() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refreshDriverSessionQuietly()),
    );
  }

  Future<void> _refreshDriverSessionQuietly() async {
    if (_driverSession == null || _driverLoading || _silentRefreshRunning) {
      return;
    }
    _silentRefreshRunning = true;
    try {
      final refreshed = await _driverApi.restore().timeout(
        const Duration(seconds: 8),
      );
      if (refreshed == null) return;
      final changed =
          jsonEncode(refreshed.toJson()) !=
          jsonEncode(_driverSession!.toJson());
      _driverSession = refreshed;
      await _saveSession(refreshed);
      if (changed) notifyListeners();
    } catch (_) {
      // Connectivity monitoring owns the visible offline/reconnecting state.
    } finally {
      _silentRefreshRunning = false;
    }
  }

  Future<void> signOutDriver() async {
    await _driverApi.signOut();
    _driverSession = null;
    _driverError = null;
    _showConnectionSurface = false;
    _syncSnapshot = const DriverSyncSnapshot.online();
    await _clearCachedSession();
    notifyListeners();
  }

  Future<DriverCommandOutcome?> confirmPickup(DriverRoundModel round) =>
      _runDriverCommand(() => _driverApi.confirmPickup(round));

  Future<DriverCommandOutcome?> reportPickupProblem({
    required DriverRoundStopModel stop,
    required String category,
    String? note,
  }) => _runDriverCommand(
    () => _driverApi.reportPickupProblem(
      stop: stop,
      category: category,
      note: note,
    ),
  );

  Future<DriverCommandOutcome?> reportLocationProblem({
    required DriverRoundStopModel stop,
    required String stage,
    required String category,
    required String detail,
    Map<String, Object?>? position,
  }) => _runDriverCommand(
    () => _driverApi.reportLocationProblem(
      stop: stop,
      stage: stage,
      category: category,
      detail: detail,
      position: position,
    ),
  );

  Future<DriverCommandOutcome?> reportDriverEmergency({
    required DriverRoundStopModel stop,
    required String safetyStatus,
    Map<String, Object?>? position,
  }) => _runDriverCommand(
    () => _driverApi.reportDriverEmergency(
      stop: stop,
      safetyStatus: safetyStatus,
      position: position,
    ),
  );

  Future<DriverCommandOutcome?> confirmArrival(
    DriverRoundStopModel stop, {
    String? overrideReason,
  }) => _runDriverCommand(
    () => _driverApi.confirmArrival(stop, overrideReason: overrideReason),
  );

  Future<DriverOperationsThreadModel> getOperationsThread({
    required DriverRoundModel round,
    required DriverRoundStopModel stop,
  }) => _driverApi.getOperationsThread(round: round, stop: stop);

  Future<List<DriverOperationsMessageModel>> pendingOperationsMessages({
    required DriverRoundModel round,
    required DriverRoundStopModel stop,
  }) => _driverApi.pendingOperationsMessages(round: round, stop: stop);

  Future<DriverCommandOutcome?> sendOperationsMessage({
    required DriverRoundModel round,
    required DriverRoundStopModel stop,
    required String body,
  }) => _runDriverCommand(
    () =>
        _driverApi.sendOperationsMessage(round: round, stop: stop, body: body),
  );

  Future<DriverCommandOutcome?> acknowledgeLiveDeliveryChange(
    DriverLiveDeliveryChangeModel change,
  ) =>
      _runDriverCommand(() => _driverApi.acknowledgeLiveDeliveryChange(change));

  Future<List<DriverContactAttemptModel>> pendingContactAttempts(
    DriverRoundStopModel stop,
  ) => _driverApi.pendingContactAttempts(stop);

  Future<DriverCommandOutcome?> logContactAttempt({
    required DriverRoundStopModel stop,
    required String target,
    required String outcome,
  }) => _runDriverCommand(
    () => _driverApi.logContactAttempt(
      stop: stop,
      target: target,
      outcome: outcome,
    ),
  );

  Future<DriverCommandOutcome?> completePod({
    required DriverRoundStopModel stop,
    required String capturedPhotoPath,
    required List<int> confirmedLineNumbers,
    required String handoffType,
    String? receiverName,
    String? receiverRelationship,
    String? leftAtLocation,
    String? note,
  }) => _runDriverCommand(
    () => _driverApi.completePod(
      stop: stop,
      capturedPhotoPath: capturedPhotoPath,
      confirmedLineNumbers: confirmedLineNumbers,
      handoffType: handoffType,
      receiverName: receiverName,
      receiverRelationship: receiverRelationship,
      leftAtLocation: leftAtLocation,
      note: note,
    ),
  );

  Future<DriverCommandOutcome?> reportDeliveryProblem({
    required DriverRoundStopModel stop,
    required String category,
    String? capturedPhotoPath,
    String? note,
  }) => _runDriverCommand(
    () => _driverApi.reportDeliveryProblem(
      stop: stop,
      category: category,
      capturedPhotoPath: capturedPhotoPath,
      note: note,
    ),
  );

  Future<DriverCommandOutcome?> _runDriverCommand(
    Future<DriverCommandOutcome> Function() command,
  ) async {
    _driverLoading = true;
    _driverError = null;
    notifyListeners();
    try {
      final outcome = await command();
      if (outcome.session != null) {
        _driverSession = outcome.session;
        await _saveSession(outcome.session!);
      }
      if (driverConfigured) {
        if (outcome.pendingSync) {
          await _refreshSyncSnapshot(phase: DriverConnectionPhase.offline);
          _showConnectionSurface = true;
        } else {
          await _refreshSyncSnapshot(
            phase: DriverConnectionPhase.online,
            syncedNow: true,
          );
        }
      }
      return outcome;
    } catch (error) {
      _driverError = error.toString();
      return null;
    } finally {
      _driverLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectLocale(HarnessLocale locale) async {
    _locale = locale;
    _hasSelectedLanguage = true;
    await Future.wait([
      _preferences.setString(_localeKey, locale.storageValue),
      _preferences.setBool(_selectedKey, true),
    ]);
    notifyListeners();
  }

  void showConnectionStatus() {
    _showConnectionSurface = true;
    notifyListeners();
  }

  void returnToRound() {
    _showConnectionSurface = false;
    notifyListeners();
  }

  Future<void> retryConnection() async {
    if (!driverConfigured || _driverLoading) return;
    _showConnectionSurface = true;
    await _refreshSyncSnapshot(phase: DriverConnectionPhase.reconnecting);
    notifyListeners();
    await restoreDriverSession();
  }

  Future<void> _restoreCachedSession() async {
    final raw = await _sessionStorage.read(key: _sessionCacheKey);
    if (raw != null) {
      try {
        _driverSession = DriverSessionModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        await _sessionStorage.delete(key: _sessionCacheKey);
      }
    }
    final lastSynced = DateTime.tryParse(
      _preferences.getString(_lastSyncedAtKey) ?? '',
    );
    _syncSnapshot = DriverSyncSnapshot(
      phase: DriverConnectionPhase.online,
      currentRouteAvailable: _driverSession?.currentRound != null,
      pendingProofCount: 0,
      pendingMessageCount: 0,
      pendingStatusCount: 0,
      pendingTelemetryCount: 0,
      lastSyncedAt: lastSynced,
    );
  }

  Future<void> _saveSession(DriverSessionModel session) async {
    final now = DateTime.now().toUtc();
    await Future.wait([
      _sessionStorage.write(
        key: _sessionCacheKey,
        value: jsonEncode(session.toJson()),
      ),
      _preferences.setString(_lastSyncedAtKey, now.toIso8601String()),
    ]);
  }

  Future<void> _clearCachedSession() => Future.wait([
    _sessionStorage.delete(key: _sessionCacheKey),
    _preferences.remove(_lastSyncedAtKey),
  ]);

  Future<void> _startConnectivityMonitoring() async {
    final connectivity = Connectivity();
    try {
      final initial = await connectivity.checkConnectivity();
      if (initial.contains(ConnectivityResult.none)) {
        await _refreshSyncSnapshot(phase: DriverConnectionPhase.offline);
        _showConnectionSurface = _driverSession != null;
      } else {
        await _refreshSyncSnapshot(phase: DriverConnectionPhase.online);
      }
      _connectivitySubscription = connectivity.onConnectivityChanged.listen((
        results,
      ) {
        if (results.contains(ConnectivityResult.none)) {
          unawaited(_markOffline());
        } else if (_syncSnapshot.phase == DriverConnectionPhase.offline) {
          unawaited(retryConnection());
        }
      });
    } catch (_) {
      // API reachability remains authoritative if the platform bridge is
      // unavailable, including in widget tests.
    }
  }

  Future<void> _markOffline() async {
    await _refreshSyncSnapshot(phase: DriverConnectionPhase.offline);
    if (_driverSession != null) _showConnectionSurface = true;
    notifyListeners();
  }

  Future<void> _refreshSyncSnapshot({
    required DriverConnectionPhase phase,
    bool syncedNow = false,
  }) async {
    final saved = DateTime.tryParse(
      _preferences.getString(_lastSyncedAtKey) ?? '',
    );
    final inspected = await _queueInspector.inspect(
      phase: phase,
      currentRouteAvailable: _driverSession?.currentRound != null,
      lastSyncedAt: syncedNow ? DateTime.now().toUtc() : saved,
    );
    _syncSnapshot =
        phase == DriverConnectionPhase.online && !inspected.fullySynced
        ? inspected.copyWith(phase: DriverConnectionPhase.reconnecting)
        : inspected;
  }

  Future<void> _flushPendingTelemetry() => TelemetryUploader(
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  ).flushOnce();

  @override
  void dispose() {
    _sessionRefreshTimer?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }
}
