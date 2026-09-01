import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

class HarnessAppController extends ChangeNotifier {
  HarnessAppController._(
    this._preferences,
    this._locale,
    this._hasSelectedLanguage,
  );

  static const _localeKey = 'driver_locale';
  static const _selectedKey = 'driver_locale_selected';

  final SharedPreferences _preferences;
  HarnessLocale _locale;
  bool _hasSelectedLanguage;

  HarnessLocale get locale => _locale;
  bool get hasSelectedLanguage => _hasSelectedLanguage;
  AppStrings get strings => AppStrings(_locale);

  static Future<HarnessAppController> create() async {
    final preferences = await SharedPreferences.getInstance();
    return HarnessAppController._(
      preferences,
      HarnessLocaleValue.fromStorage(preferences.getString(_localeKey)),
      preferences.getBool(_selectedKey) ?? false,
    );
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
