// lib/features/settings/settings_sheet.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/providers.dart';
import '../../core/services/settings_provider.dart';
import '../../core/utils/currency.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';
import '../flow/chat_screen.dart' show voiceLocaleFor;
import '../flow/flow_controller.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showAppleSheet(
    context: context,
    builder: (_) => const _SettingsBody(),
  );
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p        = Palette.of(context);
    final s        = ref.watch(stringsProvider);
    final lang     = ref.watch(languageProvider);
    final theme    = ref.watch(themeProvider);
    final currency = ref.watch(currencyProvider);
    final roundUp  = ref.watch(roundUpProvider);

    Widget label(String t) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8, top: 18),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(t.toUpperCase(), style: TextStyle(fontSize: 13, color: p.secondary)),
      ),
    );

    return SingleChildScrollView(
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

        label(s.roundUp),
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<double>(
            groupValue: roundUp,
            children: {
              0.0: _segText(s.roundOff),
              for (final v in const [0.5, 1.0, 5.0, 10.0])
                v: _segText(s.fmtNum(v, decimals: v == v.roundToDouble() ? 0 : 1)),
            },
            onValueChanged: (v) {
              if (v == null) return;
              HapticFeedback.selectionClick();
              ref.read(roundUpProvider.notifier).set(v);
            },
          ),
        ),

        label(s.currency),
        InsetGroup(inSheet: true, separatorInset: 16, children: [
          for (final code in kCurrencies.keys)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(currencyProvider.notifier).setCurrency(code);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(child: Text(
                    s.isAr ? kCurrencyNames[code]!.$2 : kCurrencyNames[code]!.$1,
                    style: TextStyle(fontSize: 17, letterSpacing: -0.4, color: p.label))),
                  Text(code, style: TextStyle(fontSize: 15, color: p.secondary)),
                  SizedBox(
                    width: 34,
                    child: code == currency
                        ? Icon(CupertinoIcons.checkmark_alt, color: p.accent, size: 22)
                        : null,
                  ),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }

  static Widget _segText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8), child: Text(text));

  static Widget _seg(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15), const SizedBox(width: 5), Text(text),
    ]),
  );
}
