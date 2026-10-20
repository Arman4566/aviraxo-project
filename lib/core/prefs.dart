import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-level preferences that must apply before any screen is built: language, theme and the selected firm.
class AppPrefs {
  AppPrefs._();
  static final AppPrefs I = AppPrefs._();

  /// 'en' or 'hi'. Listen to this to rebuild the UI when the language changes.
  final ValueNotifier<String> language = ValueNotifier<String>('en');
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Id of the firm the user is working in (sent as X-Business-Id). Null = the oldest firm.
  String? businessId;

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    I.language.value = sp.getString('pref_language') ?? 'en';
    I.themeMode.value = switch (sp.getString('pref_theme')) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    I.businessId = sp.getString('pref_business_id');
  }

  Future<void> setLanguage(String code) async {
    language.value = code;
    (await SharedPreferences.getInstance()).setString('pref_language', code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    (await SharedPreferences.getInstance()).setString('pref_theme', mode.name);
  }

  Future<void> setBusinessId(String? id) async {
    businessId = id;
    final sp = await SharedPreferences.getInstance();
    if (id == null) {
      await sp.remove('pref_business_id');
    } else {
      await sp.setString('pref_business_id', id);
    }
  }
}
