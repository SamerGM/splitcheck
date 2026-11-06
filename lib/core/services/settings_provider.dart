// lib/core/services/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/strings.dart';
import 'settings_service.dart';
export 'settings_service.dart' show FriendGroup;
import '../utils/currency.dart';

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

// ── Currency ──────────────────────────────────────────────────────────────────
// The currency of the bill being split. Starts from the saved default (if the
// user made one), otherwise USD. Choosing a country in the chat changes it for
// this bill; "make it my default" also saves it.

class CurrencyNotifier extends Notifier<String> {
  @override
  String build() => 'USD';

  bool _hasDefault = false;
  /// True once the user saved a default — the chat then stops asking.
  bool get hasDefault => _hasDefault;

  Future<void> init() async {
    final svc = ref.read(settingsServiceProvider);
    final saved = svc.loadDefaultCurrency();
    _hasDefault = saved != null && kCurrencies.containsKey(saved);
    state = _hasDefault ? saved! : 'USD';
    ref.read(countryProvider.notifier).set(svc.loadDefaultCountry());
  }

  /// Use for the current bill only.
  void use(String code, {String? country}) {
    state = code;
    if (country != null) ref.read(countryProvider.notifier).set(country);
  }

  /// Use and remember as the default (Settings / "make it my default").
  Future<void> setDefault(String code, {required String country}) async {
    use(code, country: country);
    _hasDefault = true;
    await ref.read(settingsServiceProvider).saveDefault(country: country, currency: code);
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, String>(
  CurrencyNotifier.new,
);

class _CountryNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

/// Country chosen with the currency (for showing its flag), or null.
final countryProvider = NotifierProvider<_CountryNotifier, String?>(_CountryNotifier.new);

// ── My name ───────────────────────────────────────────────────────────────────

class MyNameNotifier extends Notifier<String> {
  @override
  String build() => '';
  Future<void> init() async { state = ref.read(settingsServiceProvider).loadMyName(); }
  Future<void> set(String v) async {
    state = v.trim();
    await ref.read(settingsServiceProvider).saveMyName(v);
  }
}

final myNameProvider = NotifierProvider<MyNameNotifier, String>(MyNameNotifier.new);

// ── Friend groups ─────────────────────────────────────────────────────────────

class GroupsNotifier extends Notifier<List<FriendGroup>> {
  @override
  List<FriendGroup> build() => const [];

  Future<void> init() async {
    final svc = ref.read(settingsServiceProvider);
    await svc.init();
    state = svc.loadGroups();
  }

  Future<void> add(String name, List<String> members) async {
    final list = [...state]
      ..removeWhere((g) => g.name.toLowerCase() == name.trim().toLowerCase())
      ..insert(0, FriendGroup(name.trim(), members));
    state = list;
    await ref.read(settingsServiceProvider).saveGroups(list);
  }

  Future<void> remove(String name) async {
    final list = state.where((g) => g.name != name).toList();
    state = list;
    await ref.read(settingsServiceProvider).saveGroups(list);
  }

  bool exists(List<String> names) => state.any((g) => g.sameMembers(names));
}

final groupsProvider = NotifierProvider<GroupsNotifier, List<FriendGroup>>(GroupsNotifier.new);

// ── Strings ───────────────────────────────────────────────────────────────────

final stringsProvider = Provider<S>((ref) {
  final lang = ref.watch(languageProvider);
  return S(lang == 'ar');
});
