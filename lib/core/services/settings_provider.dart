// lib/core/services/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/strings.dart';
import 'settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());

// ── Theme ─────────────────────────────────────────────────────────────────────

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> init() async {
    final svc = ref.read(settingsServiceProvider);
    await svc.init();
    state = svc.loadTheme();
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsServiceProvider).saveTheme(mode);
  }

  void toggle(BuildContext context) {
    final current = state == ThemeMode.system
        ? (MediaQuery.of(context).platformBrightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light)
        : state;
    setTheme(current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

// ── Language ──────────────────────────────────────────────────────────────────

class LanguageNotifier extends Notifier<String> {
  @override
  String build() => 'en';

  Future<void> init() async {
    final svc = ref.read(settingsServiceProvider);
    state = svc.loadLanguage();
  }

  Future<void> setLanguage(String lang) async {
    state = lang;
    await ref.read(settingsServiceProvider).saveLanguage(lang);
  }

  void toggle() {
    setLanguage(state == 'en' ? 'ar' : 'en');
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, String>(
  LanguageNotifier.new,
);

// ── Strings ───────────────────────────────────────────────────────────────────

final stringsProvider = Provider<S>((ref) {
  final lang = ref.watch(languageProvider);
  return S(lang == 'ar');
});
