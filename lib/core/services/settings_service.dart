// lib/core/services/settings_service.dart
// Saves theme and language choices across sessions.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _themeKey    = 'theme_mode';
  static const _languageKey = 'language';
  static const _currencyKey = 'currency';
  static const _roundKey    = 'round_up_to';
  static const _groupsKey   = 'recent_groups';

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

  // ── Currency ───────────────────────────────────────────────────────────────

  String loadCurrency() => _prefs.getString(_currencyKey) ?? 'USD';

  Future<void> saveCurrency(String code) async {
    await _prefs.setString(_currencyKey, code);
  }

  // ── Round each share up (0 = off) ──────────────────────────────────────────

  double loadRoundUpTo() => _prefs.getDouble(_roundKey) ?? 0;
  Future<void> saveRoundUpTo(double v) async => _prefs.setDouble(_roundKey, v);

  // ── Recent groups of people (most recent first) ────────────────────────────

  List<List<String>> loadRecentGroups() => (_prefs.getStringList(_groupsKey) ?? const [])
      .map((g) => g.split('\u001f').where((n) => n.isNotEmpty).toList())
      .where((g) => g.isNotEmpty)
      .toList();

  Future<void> saveRecentGroup(List<String> names) async {
    String key(List<String> g) => ([...g.map((n) => n.toLowerCase())]..sort()).join('|');
    final groups = loadRecentGroups()..removeWhere((g) => key(g) == key(names));
    groups.insert(0, names);
    await _prefs.setStringList(
        _groupsKey, groups.take(3).map((g) => g.join('\u001f')).toList());
  }
}
