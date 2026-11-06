// lib/features/settings/settings_sheet.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/providers.dart';
import '../../core/services/settings_provider.dart';
import '../../core/utils/countries.dart';
import '../../core/utils/currency.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';
import '../flow/chat_screen.dart' show voiceLocaleFor;
import '../flow/flow_controller.dart';
import 'country_picker.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showAppleSheet(
    context: context,
    builder: (_) => const _SettingsBody(),
  );
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody();
  @override ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late final _name = TextEditingController(text: ref.read(myNameProvider));

  @override
  void dispose() {
    final v = _name.text.trim();
    if (v != ref.read(myNameProvider)) ref.read(myNameProvider.notifier).set(v);
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p        = Palette.of(context);
    final s        = ref.watch(stringsProvider);
    final lang     = ref.watch(languageProvider);
    final theme    = ref.watch(themeProvider);
    final currency = ref.watch(currencyProvider);
    final country  = countryByCode(ref.watch(countryProvider)) ?? countryForCurrency(currency);
    final groups   = ref.watch(groupsProvider);

    Widget label(String t) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8, top: 18),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(t.toUpperCase(), style: TextStyle(fontSize: 13, color: p.secondary)),
      ),
    );

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s.settings, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: p.label)),

          label(s.language),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: lang,
              children: const {
                'en': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('English')),
                'ar': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('العربية')),
              },
              onValueChanged: (v) {
                if (v == null || v == lang) return;
                HapticFeedback.selectionClick();
                ref.read(languageProvider.notifier).setLanguage(v);
                ref.read(voiceLocaleProvider.notifier).value = voiceLocaleFor(v);
                ref.read(chatProvider.notifier).reset(); // restart the chat in the new language
              },
            ),
          ),

          label(s.appearance),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<ThemeMode>(
              groupValue: theme,
              children: {
                ThemeMode.system: _seg(CupertinoIcons.circle_lefthalf_fill, s.auto),
                ThemeMode.light:  _seg(CupertinoIcons.sun_max_fill, s.light),
                ThemeMode.dark:   _seg(CupertinoIcons.moon_fill, s.dark),
              },
              onValueChanged: (v) {
                if (v == null) return;
                HapticFeedback.selectionClick();
                ref.read(themeProvider.notifier).setTheme(v);
              },
            ),
          ),

          // ── Default country & currency (dropdown) ────────────────────────
          label(s.countryCurrency),
          InsetGroup(inSheet: true, separatorInset: 16, children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final c = await showCountryPicker(context, selectedCode: country?.code);
                if (c != null) {
                  HapticFeedback.selectionClick();
                  await ref.read(currencyProvider.notifier).setDefault(c.currency, country: c.code);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Text(country?.flag ?? '🌍', style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(country?.name(s.isAr) ?? s.countryCurrency,
                        style: TextStyle(fontSize: 17, letterSpacing: -0.4, color: p.label)),
                    Text('${s.isAr ? kCurrencyNames[currency]?.$2 ?? currency : kCurrencyNames[currency]?.$1 ?? currency} · $currency',
                        style: TextStyle(fontSize: 13, color: p.secondary)),
                  ])),
                  Icon(CupertinoIcons.chevron_up_chevron_down, size: 18, color: p.tertiary),
                ]),
              ),
            ),
          ]),

          // ── Your name ("Include me") ─────────────────────────────────────
          label(s.yourName),
          CupertinoTextField(
            controller: _name,
            placeholder: s.yourName,
            placeholderStyle: TextStyle(fontSize: 17, color: p.tertiary),
            style: TextStyle(fontSize: 17, color: p.label),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.isDark ? p.elevated : p.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (v) => ref.read(myNameProvider.notifier).set(v),
          ),

          // ── Friend groups ────────────────────────────────────────────────
          label(s.friendGroups),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(s.noGroupsYet, style: TextStyle(fontSize: 15, color: p.secondary)),
            )
          else
            InsetGroup(inSheet: true, separatorInset: 16, children: [
              for (final g in groups)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.name, style: TextStyle(fontSize: 17, letterSpacing: -0.4, color: p.label)),
                      Text(g.members.join(s.isAr ? '، ' : ', '),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.secondary)),
                    ])),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref.read(groupsProvider.notifier).remove(g.name);
                      },
                      child: Icon(CupertinoIcons.trash, color: p.red, size: 20),
                    ),
                  ]),
                ),
            ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  static Widget _seg(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15), const SizedBox(width: 5), Text(text),
    ]),
  );
}
