// lib/core/services/settings_service.dart
// Saves settings across sessions: theme, language, default currency,
// your name and friend groups.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _themeKey    = 'theme_mode';
  static const _languageKey = 'language';
  static const _currencyKey = 'currency';
  static const _countryKey  = 'country';
  static const _myNameKey   = 'my_name';
  static const _vatKey      = 'default_vat';
  static const _serviceKey  = 'default_service';
  static const _groupsKey   = 'friend_groups';

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

  // ── Default country / currency ─────────────────────────────────────────────
  // Saved only when the user says "make it my default".

  String? loadDefaultCurrency() => _prefs.getString(_currencyKey);
  String? loadDefaultCountry()  => _prefs.getString(_countryKey);

  double? loadDefaultVat()     => _prefs.getDouble(_vatKey);
  double? loadDefaultService() => _prefs.getDouble(_serviceKey);

  Future<void> saveDefault({required String country, required String currency,
      double? vat, double? service}) async {
    await _prefs.setString(_countryKey, country);
    await _prefs.setString(_currencyKey, currency);
    if (vat != null) await _prefs.setDouble(_vatKey, vat);
    if (service != null) await _prefs.setDouble(_serviceKey, service);
  }

  // ── My name (for "Include me") ─────────────────────────────────────────────

  String loadMyName() => _prefs.getString(_myNameKey) ?? '';
  Future<void> saveMyName(String name) async => _prefs.setString(_myNameKey, name.trim());

  // ── Friend groups ──────────────────────────────────────────────────────────

  List<FriendGroup> loadGroups() {
    final raw = _prefs.getString(_groupsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => FriendGroup.fromJson(e as Map<String, dynamic>))
          .where((g) => g.members.isNotEmpty)
          .toList();
    } catch (_) { return []; }
  }

  Future<void> saveGroups(List<FriendGroup> groups) async =>
      _prefs.setString(_groupsKey, jsonEncode(groups.map((g) => g.toJson()).toList()));
}

/// A saved group of friends, e.g. "Work friends": Ahmed, Sara, Omar.
class FriendGroup {
  final String name;
  final List<String> members;
  const FriendGroup(this.name, this.members);

  Map<String, dynamic> toJson() => {'name': name, 'members': members};
  factory FriendGroup.fromJson(Map<String, dynamic> j) =>
      FriendGroup(j['name'] as String, List<String>.from(j['members'] as List));

  /// Same people regardless of order / case.
  bool sameMembers(List<String> names) {
    String key(Iterable<String> l) => ([...l.map((n) => n.trim().toLowerCase())]..sort()).join('|');
    return key(members) == key(names);
  }
}
