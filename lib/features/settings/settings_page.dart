// lib/features/settings/settings_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/providers.dart';
import '../../core/services/settings_provider.dart';
import '../../core/services/voice_service.dart';
import '../../core/utils/countries.dart';
import '../../core/utils/number_parser.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';
import '../../shared/widgets/voice_field.dart';
import '../wizard/wizard_controller.dart';
import '../groups/group_widgets.dart';
import 'country_picker.dart';

/// Full-screen Settings: language, appearance, default country (+ its VAT and
/// service), your name and saved groups.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final _name = TextEditingController(text: ref.read(myNameProvider));
  late final _vat = TextEditingController(text: _fmt(ref.read(currencyProvider.notifier).defaultVat));
  late final _svc = TextEditingController(text: _fmt(ref.read(currencyProvider.notifier).defaultService));

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
  static double _num(String t) => double.tryParse(normalizeDigits(t.trim()).replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    _saveName();
    _name.dispose(); _vat.dispose(); _svc.dispose();
    super.dispose();
  }

  void _saveName() {
    final v = _name.text.trim();
    if (v != ref.read(myNameProvider)) ref.read(myNameProvider.notifier).set(v);
  }

  Future<void> _saveRates() async {
    final cur = ref.read(currencyProvider.notifier);
    final code = ref.read(countryProvider);
    if (!cur.hasDefault || code == null) return;
    await cur.setDefault(ref.read(currencyProvider), country: code,
        vat: _num(_vat.text).clamp(0, 100).toDouble(), service: _num(_svc.text).clamp(0, 100).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final p        = Palette.of(context);
    final s        = ref.watch(stringsProvider);
    final lang     = ref.watch(languageProvider);
    final theme    = ref.watch(themeProvider);
    final cur      = ref.watch(currencyProvider);
    final curN     = ref.read(currencyProvider.notifier);
    final country  = curN.hasDefault ? countryByCode(ref.watch(countryProvider)) : null;
    final groups   = ref.watch(groupsProvider);

    Widget label(String t) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8, top: 22),
      child: Text(t.toUpperCase(), style: TextStyle(fontSize: 13, color: p.secondary)),
    );

    Widget seg(IconData? icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 5)], Text(text),
      ]),
    );

    return Scaffold(
      backgroundColor: p.bg,
      body: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(s.settings, style: TextStyle(color: p.label)),
          backgroundColor: p.barBg,
          border: Border(bottom: BorderSide(color: p.separator, width: .33)),
          previousPageTitle: s.back,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: Text(s.done, style: TextStyle(fontWeight: FontWeight.w600, color: p.accent)),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 40 + MediaQuery.of(context).padding.bottom),
          sliver: SliverList.list(children: [
            label(s.language),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: lang,
              children: {'en': seg(null, 'English'), 'ar': seg(null, 'العربية')},
              onValueChanged: (v) {
                if (v == null || v == lang) return;
                HapticFeedback.selectionClick();
                ref.read(languageProvider.notifier).setLanguage(v);
                ref.read(voiceLocaleProvider.notifier).value = voiceLocaleFor(v);
                ref.read(wizardProvider.notifier).startOver(); // restart in the new language
              },
            ),

            label(s.appearance),
            CupertinoSlidingSegmentedControl<ThemeMode>(
              groupValue: theme,
              children: {
                ThemeMode.system: seg(CupertinoIcons.circle_lefthalf_fill, s.auto),
                ThemeMode.light:  seg(CupertinoIcons.sun_max_fill, s.light),
                ThemeMode.dark:   seg(CupertinoIcons.moon_fill, s.dark),
              },
              onValueChanged: (v) {
                if (v == null) return;
                HapticFeedback.selectionClick();
                ref.read(themeProvider.notifier).setTheme(v);
              },
            ),

            label(s.defaultCountry),
            InsetGroup(separatorInset: 16, children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final c = await showCountryPicker(context, selectedCode: country?.code);
                  if (c == null) return;
                  HapticFeedback.selectionClick();
                  await ref.read(currencyProvider.notifier).setDefault(c.currency, country: c.code);
                  _vat.text = _fmt(c.vat);
                  _svc.text = _fmt(c.service);
                  if (mounted) setState(() {});
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Text(country?.flag ?? '🌍', style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(country?.name(s.isAr) ?? s.noDefaultCountry,
                          style: TextStyle(fontSize: 17, letterSpacing: -.4, color: p.label)),
                      if (country != null)
                        Text('$cur · ${s.vatLabel} ${s.fmtPct(curN.defaultVat)} · ${s.serviceLabel} ${s.fmtPct(curN.defaultService)}',
                            style: TextStyle(fontSize: 13, color: p.secondary)),
                    ])),
                    Icon(CupertinoIcons.chevron_up_chevron_down, size: 18, color: p.tertiary),
                  ]),
                ),
              ),
            ]),
            if (country != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: VoiceField(controller: _vat, placeholder: s.vatLabel, numeric: true,
                    prefixText: s.vatLabel, suffixText: '%', onChanged: (_) => _saveRates())),
                const SizedBox(width: 10),
                Expanded(child: VoiceField(controller: _svc, placeholder: s.serviceLabel, numeric: true,
                    prefixText: s.serviceLabel, suffixText: '%', onChanged: (_) => _saveRates())),
              ]),
            ],

            label(s.yourName),
            VoiceField(controller: _name, placeholder: s.yourName, onSubmitted: (_) => _saveName()),

            label(s.friendGroups),
            InsetGroup(separatorInset: 16, children: [
              for (final g in groups)
                Dismissible(
                  key: ValueKey('group-${g.name}'),
                  direction: Directionality.of(context) == TextDirection.rtl
                      ? DismissDirection.startToEnd : DismissDirection.endToStart,
                  confirmDismiss: (_) => deleteGroupFlow(context, ref, g),
                  background: Container(
                    color: p.red,
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsetsDirectional.only(end: 20),
                    child: Text(s.delete, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  child: Semantics(button: true, label: g.name, excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () { HapticFeedback.selectionClick(); openGroupEditor(context, g); },
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 12, 8),
                        child: Row(children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(36, 36),
                            onPressed: () => deleteGroupFlow(context, ref, g),
                            child: Icon(CupertinoIcons.minus_circle_fill, color: p.red, size: 22),
                          ),
                          const SizedBox(width: 2),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.name, style: TextStyle(fontSize: 17, letterSpacing: -.4, color: p.label)),
                            Text(g.members.join(s.isAr ? '، ' : ', '), maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: p.secondary)),
                          ])),
                          Text(s.n(g.members.length), style: TextStyle(fontSize: 15, color: p.secondary)),
                          const SizedBox(width: 6),
                          Icon(CupertinoIcons.chevron_forward, color: p.tertiary, size: 16),
                        ]),
                      ),
                    ),
                  ),
                ),
              Semantics(button: true, label: s.newGroup, excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () { HapticFeedback.selectionClick(); openGroupEditor(context); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                    child: Row(children: [
                      Icon(CupertinoIcons.plus_circle_fill, color: p.green, size: 22),
                      const SizedBox(width: 10),
                      Text(s.newGroup, style: TextStyle(fontSize: 17, color: p.accent)),
                    ]),
                  ),
                )),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(s.savedGroupsFooter, style: TextStyle(fontSize: 13, color: p.secondary)),
            ),
          ]),
        ),
      ]),
    );
  }
}
