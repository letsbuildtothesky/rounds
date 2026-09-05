import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';
import '../connectivity/driver_sync_state.dart';
import '../driver/driver_api.dart';
import '../driver/driver_entry.dart';
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
  static const _pendingWorkOwnerKey = 'driver_pending_work_owner_v1';
  static const _lastSyncedAtKey = 'driver_session_last_synced_at_v1';

  final SharedPreferences _preferences;
  HarnessLocale _locale;
  bool _hasSelectedLanguage;
  final DriverApi _driverApi;
  final DriverQueueInspector _queueInspector;
  final FlutterSecureStorage _sessionStorage;
  DriverSessionModel? _driverSession;
  String? _pendingWorkOwnerDriverId;
  bool _currentRouteAvailable = false;
  bool _driverLoading = false;
  String? _driverError;
  DriverEntryStage _driverEntryStage = DriverEntryStage.phone;
  String? _driverPhoneE164;
  DriverTeamInviteModel? _driverTeamInvite;
  String? _driverInviteCode;
  DriverSyncSnapshot _syncSnapshot = const DriverSyncSnapshot.online();
  bool _showConnectionSurface = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _sessionRefreshTimer;
  bool _silentRefreshRunning = false;
  bool _localeSyncRunning = false;
  bool _localeSyncRequested = false;

  HarnessLocale get locale => _locale;
  bool get hasSelectedLanguage => _hasSelectedLanguage;
  AppStrings get strings => AppStrings(_locale);
  bool get driverConfigured => _driverApi.isConfigured;
  DriverSessionModel? get driverSession => _driverSession;
  bool get driverLoading => _driverLoading;
  String? get driverError => _driverError;
  DriverEntryStage get driverEntryStage => _driverEntryStage;
  String? get driverPhoneE164 => _driverPhoneE164;
  DriverTeamInviteModel? get driverTeamInvite => _driverTeamInvite;
  DriverSyncSnapshot get syncSnapshot => _syncSnapshot;
  bool get showConnectionSurface => _showConnectionSurface;

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
      final expectedDriverId = await _expectedDriverIdBeforeSync();
      final restored = await _driverApi
          .restore(expectedDriverId: expectedDriverId)
          .timeout(const Duration(seconds: 15));
      if (restored == null) {
        _currentRouteAvailable = false;
        if (_driverSession != null) {
          _driverError = 'Sign in again before saved work can sync.';
          await _refreshSyncSnapshot(phase: DriverConnectionPhase.offline);
          _showConnectionSurface = true;
          return;
        }
        await _clearCachedSession();
      } else {
        await _acceptAuthenticatedSession(restored);
        await _saveSession(restored);
        _requestLocaleSync();
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

  Future<bool> requestDriverPhoneOtp(String nationalNumber) async {
    var digits = nationalNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length != 9) {
      _driverError = 'Enter a nine-digit Thai mobile number';
      notifyListeners();
      return false;
    }
    _driverLoading = true;
    _driverError = null;
    notifyListeners();
    try {
      final phoneE164 = '+66$digits';
      await _driverApi.requestPhoneOtp(phoneE164);
      _driverPhoneE164 = phoneE164;
      _driverEntryStage = DriverEntryStage.otp;
      return true;
    } catch (error) {
      _driverError = error.toString();
      return false;
    } finally {
      _driverLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyDriverPhoneOtp(String token) async {
    final phone = _driverPhoneE164;
    if (phone == null || token.replaceAll(RegExp(r'\D'), '').length != 6) {
      _driverError = 'Enter the six-digit code';
      notifyListeners();
      return false;
    }
    _driverLoading = true;
    _driverError = null;
    notifyListeners();
    try {
      final expectedDriverId = await _expectedDriverIdBeforeSync();
      final verified = await _driverApi.verifyPhoneOtp(
        phone,
        token,
        expectedDriverId: expectedDriverId,
      );
      if (verified.session != null) {
        await _completeDriverEntry(verified.session!);
      } else {
        _driverTeamInvite = verified.pendingInvite;
        _driverEntryStage = DriverEntryStage.path;
      }
      return true;
    } catch (error) {
      _driverError = error.toString();
      return false;
    } finally {
      _driverLoading = false;
      notifyListeners();
    }
  }

  Future<void> resendDriverPhoneOtp() async {
    final phone = _driverPhoneE164;
    if (phone == null) return;
    _driverLoading = true;
    _driverError = null;
    notifyListeners();
    try {
      await _driverApi.requestPhoneOtp(phone);
    } catch (error) {
      _driverError = error.toString();
    } finally {
      _driverLoading = false;
      notifyListeners();
    }
  }

  bool selectTeamDriverPath() {
    if (_driverTeamInvite == null) return false;
    _driverEntryStage = DriverEntryStage.teamInvite;
    _driverError = null;
    notifyListeners();
    return true;
  }

  Future<bool> resolveDriverTeamInvite(String code) async {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) return false;
    _driverLoading = true;
    _driverError = null;
    notifyListeners();
    try {
      _driverTeamInvite = await _driverApi.resolveTeamInvite(digits);
      _driverInviteCode = digits;
      _driverEntryStage = DriverEntryStage.teamInvite;
      return true;
    } catch (error) {
      _driverError = error.toString();
      return false;
    } finally {
      _driverLoading = false;
      notifyListeners();
    }
  }

  Future<bool> acceptDriverTeamInvite() async {
    final invite = _driverTeamInvite;
    if (invite == null) return false;
    _driverLoading = true;
    _driverError = null;
    notifyListeners();
    try {
      final expectedDriverId = await _expectedDriverIdBeforeSync();
      final session = await _driverApi.acceptTeamInvite(
        invite: invite,
        preferredLocale: _locale.storageValue,
        code: _driverInviteCode,
        expectedDriverId: expectedDriverId,
      );
      await _completeDriverEntry(session);
      return true;
    } catch (error) {
      _driverError = error.toString();
      return false;
    } finally {
      _driverLoading = false;
      notifyListeners();
    }
  }

  void driverEntryBack() {
    _driverError = null;
    switch (_driverEntryStage) {
      case DriverEntryStage.phone:
        return;
      case DriverEntryStage.otp:
        _driverEntryStage = DriverEntryStage.phone;
        break;
      case DriverEntryStage.path:
        _driverEntryStage = DriverEntryStage.otp;
        break;
      case DriverEntryStage.teamInvite:
        _driverEntryStage = DriverEntryStage.path;
        break;
    }
    notifyListeners();
  }

  Future<void> _completeDriverEntry(DriverSessionModel session) async {
    await _acceptAuthenticatedSession(session);
    await _saveSession(session);
    _requestLocaleSync();
    await _flushPendingTelemetry();
    await _refreshSyncSnapshot(
      phase: DriverConnectionPhase.online,
      syncedNow: true,
    );
    _driverEntryStage = DriverEntryStage.phone;
    _driverPhoneE164 = null;
    _driverTeamInvite = null;
    _driverInviteCode = null;
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
      final refreshed = await _driverApi
          .restore(
            expectedDriverId:
                _pendingWorkOwnerDriverId ?? _driverSession?.driverId,
          )
          .timeout(const Duration(seconds: 8));
      if (refreshed == null) return;
      final changed =
          jsonEncode(refreshed.toJson()) !=
          jsonEncode(_driverSession!.toJson());
      await _acceptAuthenticatedSession(refreshed);
      await _saveSession(refreshed);
      _requestLocaleSync();
      if (changed) notifyListeners();
    } catch (_) {
      // Connectivity monitoring owns the visible offline/reconnecting state.
    } finally {
      _silentRefreshRunning = false;
    }
  }

  Future<void> signOutDriver() async {
    final ownerDriverId = _pendingWorkOwnerDriverId ?? _driverSession?.driverId;
    var preserveOwner = ownerDriverId != null;
    try {
      await _refreshSyncSnapshot(phase: _syncSnapshot.phase);
      preserveOwner = _syncSnapshot.totalPending > 0;
    } catch (_) {
      // If local queue inspection fails, retaining the owner is safer than
      // allowing another Driver to attempt the queued work.
    }
    if (preserveOwner && ownerDriverId != null) {
      _pendingWorkOwnerDriverId = ownerDriverId;
      await _sessionStorage.write(
        key: _pendingWorkOwnerKey,
        value: ownerDriverId,
      );
    } else {
      _pendingWorkOwnerDriverId = null;
      await _sessionStorage.delete(key: _pendingWorkOwnerKey);
    }
    _driverSession = null;
    _currentRouteAvailable = false;
    _localeSyncRequested = false;
    await _driverApi.signOut();
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

  Future<String?> driverRealtimeAccessToken() =>
      _driverApi.realtimeAccessToken();

  Future<void> markOperationsThreadRead({
    required DriverRoundModel round,
    required DriverRoundStopModel stop,
    required String lastReadMessageId,
  }) => _driverApi.markOperationsThreadRead(
    round: round,
    stop: stop,
    lastReadMessageId: lastReadMessageId,
  );

  Future<List<DriverOperationsMessageModel>> pendingOperationsMessages({
    required DriverRoundModel round,
    required DriverRoundStopModel stop,
  }) => _driverApi.pendingOperationsMessages(round: round, stop: stop);

  Future<DriverCommandOutcome?> sendOperationsMessage({
    required DriverRoundModel round,
    required DriverRoundStopModel stop,
    required String body,
    List<DriverMessageAttachmentModel> attachments = const [],
  }) => _runDriverCommand(
    () => _driverApi.sendOperationsMessage(
      round: round,
      stop: stop,
      body: body,
      attachments: attachments,
    ),
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
    _requestLocaleSync();
  }

  Future<void> _acceptAuthenticatedSession(DriverSessionModel session) async {
    final previousNavigationScope = _navigationScope(
      _driverSession?.currentRound,
    );
    final nextNavigationScope = _navigationScope(session.currentRound);
    if (previousNavigationScope != nextNavigationScope) {
      _currentRouteAvailable = false;
    }
    if (_pendingWorkOwnerDriverId == null) {
      _pendingWorkOwnerDriverId = session.driverId;
      await _sessionStorage.write(
        key: _pendingWorkOwnerKey,
        value: session.driverId,
      );
    }
    _driverSession = session;
    if (!_hasSelectedLanguage) {
      _locale = HarnessLocaleValue.fromStorage(session.preferredLocale);
      _hasSelectedLanguage = true;
      await Future.wait([
        _preferences.setString(_localeKey, _locale.storageValue),
        _preferences.setBool(_selectedKey, true),
      ]);
      return;
    }
  }

  void reportCurrentRouteAvailability(bool available) {
    if (_currentRouteAvailable == available) return;
    _currentRouteAvailable = available;
    _syncSnapshot = _syncSnapshot.copyWith(
      assignedRoundAvailable: _driverSession?.currentRound != null,
      currentRouteAvailable: available,
    );
    notifyListeners();
  }

  String? _navigationScope(DriverRoundModel? round) {
    if (round == null) return null;
    final stops = round.stops
        .map(
          (stop) =>
              '${stop.id}:${stop.destinationVersion}:${stop.latitude}:${stop.longitude}',
        )
        .join('|');
    return '${round.id}:${round.pickup.latitude}:${round.pickup.longitude}:$stops';
  }

  void _requestLocaleSync() {
    if (_driverSession == null || !_hasSelectedLanguage) return;
    _localeSyncRequested = true;
    if (!_localeSyncRunning) unawaited(_syncPreferredLocale());
  }

  Future<void> _syncPreferredLocale() async {
    if (_localeSyncRunning) return;
    _localeSyncRunning = true;
    try {
      while (_localeSyncRequested) {
        _localeSyncRequested = false;
        final session = _driverSession;
        final desired = _locale;
        if (session == null ||
            session.preferredLocale == desired.storageValue) {
          continue;
        }
        final synced = await _driverApi.syncPreferredLocale(
          session: session,
          preferredLocale: desired.storageValue,
        );
        if (synced == null || !identical(_driverSession, session)) continue;
        _driverSession = synced;
        await _saveSession(synced);
        if (_locale != desired) _localeSyncRequested = true;
        notifyListeners();
      }
    } finally {
      _localeSyncRunning = false;
    }
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
    _currentRouteAvailable = false;
    final stored = await Future.wait([
      _sessionStorage.read(key: _sessionCacheKey),
      _sessionStorage.read(key: _pendingWorkOwnerKey),
    ]);
    final raw = stored[0];
    _pendingWorkOwnerDriverId = stored[1];
    if (raw != null) {
      try {
        _driverSession = DriverSessionModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (_pendingWorkOwnerDriverId == null) {
          _pendingWorkOwnerDriverId = _driverSession!.driverId;
          await _sessionStorage.write(
            key: _pendingWorkOwnerKey,
            value: _driverSession!.driverId,
          );
        }
      } catch (_) {
        await _sessionStorage.delete(key: _sessionCacheKey);
      }
    }
    final lastSynced = DateTime.tryParse(
      _preferences.getString(_lastSyncedAtKey) ?? '',
    );
    _syncSnapshot = DriverSyncSnapshot(
      phase: DriverConnectionPhase.online,
      assignedRoundAvailable: _driverSession?.currentRound != null,
      currentRouteAvailable: false,
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

  Future<String?> _expectedDriverIdBeforeSync() async {
    final expectedDriverId =
        _pendingWorkOwnerDriverId ?? _driverSession?.driverId;
    if (expectedDriverId != null) return expectedDriverId;

    final inspected = await _queueInspector.inspect(
      phase: DriverConnectionPhase.offline,
      assignedRoundAvailable: false,
      currentRouteAvailable: false,
      lastSyncedAt: DateTime.tryParse(
        _preferences.getString(_lastSyncedAtKey) ?? '',
      ),
    );
    if (inspected.totalPending > 0) {
      throw const DriverWorkOwnerUnknownException();
    }
    return null;
  }

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
      assignedRoundAvailable: _driverSession?.currentRound != null,
      currentRouteAvailable: _currentRouteAvailable,
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
