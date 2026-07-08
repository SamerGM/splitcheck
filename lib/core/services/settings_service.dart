// lib/core/services/settings_service.dart
// Saves theme and language choices across sessions.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _themeKey    = 'theme_mode';
  static const _languageKey = 'language';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Theme ──────────────────────────────────────────────────────────────────

  /// Returns saved theme, or null if user never chose (= use system default)
  ThemeMode loadTheme() {
    final saved = _prefs.getString(_themeKey);
    switch (saved) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      default:      return ThemeMode.system; // follows system
    }
  }

  Future<void> saveTheme(ThemeMode mode) async {
    switch (mode) {
      case ThemeMode.light:  await _prefs.setString(_themeKey, 'light'); break;
      case ThemeMode.dark:   await _prefs.setString(_themeKey, 'dark');  break;
      case ThemeMode.system: await _prefs.remove(_themeKey);             break;
    }
  }

  // ── Language ───────────────────────────────────────────────────────────────

  /// Returns saved language, default is English
  String loadLanguage() {
    return _prefs.getString(_languageKey) ?? 'en';
  }

  Future<void> saveLanguage(String lang) async {
    await _prefs.setString(_languageKey, lang);
  }
}
