import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';
import '../driver/driver_api.dart';
import '../driver/driver_session.dart';
import '../driver/driver_operations_thread.dart';

class HarnessAppController extends ChangeNotifier {
  HarnessAppController._(
    this._preferences,
    this._locale,
    this._hasSelectedLanguage,
    this._driverApi,
  );

  static const _localeKey = 'driver_locale';
  static const _selectedKey = 'driver_locale_selected';

  final SharedPreferences _preferences;
  HarnessLocale _locale;
  bool _hasSelectedLanguage;
  final DriverApi _driverApi;
  DriverSessionModel? _driverSession;
  bool _driverLoading = false;
  String? _driverError;

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

  static const _pilotDriverEmail = String.fromEnvironment('PILOT_DRIVER_EMAIL');
  static const _pilotDriverPassword = String.fromEnvironment(
    'PILOT_DRIVER_PASSWORD',
  );

  static Future<HarnessAppController> create() async {
    final preferences = await SharedPreferences.getInstance();
    return HarnessAppController._(
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
      ),
    );
  }

  Future<void> restoreDriverSession() async {
    if (!driverConfigured) return;
    _driverLoading = true;
    _driverError = null;
    notifyListeners();
    try {
      _driverSession = await _driverApi.restore();
    } catch (error) {
      _driverError = error.toString();
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

  Future<void> signOutDriver() async {
    await _driverApi.signOut();
    _driverSession = null;
    _driverError = null;
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

  Future<DriverCommandOutcome?> completePod({
    required DriverRoundStopModel stop,
    required String capturedPhotoPath,
    required String handoffType,
    String? receiverName,
    String? receiverRelationship,
    String? leftAtLocation,
    String? note,
  }) => _runDriverCommand(
    () => _driverApi.completePod(
      stop: stop,
      capturedPhotoPath: capturedPhotoPath,
      handoffType: handoffType,
      receiverName: receiverName,
      receiverRelationship: receiverRelationship,
      leftAtLocation: leftAtLocation,
      note: note,
    ),
  );

  Future<DriverCommandOutcome?> reportDeliveryDamage({
    required DriverRoundStopModel stop,
    required String capturedPhotoPath,
    String? note,
  }) => _runDriverCommand(
    () => _driverApi.reportDeliveryDamage(
      stop: stop,
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
      if (outcome.session != null) _driverSession = outcome.session;
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
}
