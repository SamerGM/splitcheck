// lib/features/wizard/pages_setup.dart
//
// Pages 1–3: dine-in or delivery, country & currency, VAT & service,
// how many people, and their names.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/person.dart';
import '../../core/services/contacts_service.dart';
import '../../core/services/settings_provider.dart';
import '../../core/utils/countries.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/number_parser.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';
import '../../shared/widgets/voice_field.dart';
import 'wizard_controller.dart';
import 'wizard_widgets.dart';

String _fmtPct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
double? _num(String t) => double.tryParse(normalizeDigits(t.trim()).replaceAll(',', '.'));

// ── 1 · Dine-in or delivery ───────────────────────────────────────────────────

class OrderTypePage extends ConsumerStatefulWidget {
  const OrderTypePage({super.key});
  @override ConsumerState<OrderTypePage> createState() => _OrderTypePageState();
}

class _OrderTypePageState extends ConsumerState<OrderTypePage> {
  late bool _delivery = ref.read(wizardProvider).delivery;
  bool _picked = false;

  void _choose(bool delivery) {
    setState(() { _delivery = delivery; _picked = true; });
    advanceSoon(() => ref.read(wizardProvider.notifier).chooseOrderType(delivery: delivery));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return WizardPage(
      eyebrow: s.newBill,
      title: s.whereEat,
      children: [
        OptionCard(emoji: '🍽️', title: s.dineIn, hint: s.dineInHint,
            selected: _picked && !_delivery, onTap: () => _choose(false)),
        OptionCard(emoji: '🛵', title: s.deliveryOrder, hint: s.deliveryOrderHint,
            selected: _picked && _delivery, onTap: () => _choose(true)),
      ],
    );
  }
}

// ── 1b · Are the menu prices final? ──────────────────────────────────────────

class PricesIncludedPage extends ConsumerStatefulWidget {
  const PricesIncludedPage({super.key});
  @override ConsumerState<PricesIncludedPage> createState() => _PricesIncludedPageState();
}

class _PricesIncludedPageState extends ConsumerState<PricesIncludedPage> {
  late bool _included = ref.read(wizardProvider).pricesIncluded;
  bool _picked = false;

  void _choose(bool included) {
    setState(() { _included = included; _picked = true; });
    advanceSoon(() => ref.read(wizardProvider.notifier).setPricesIncluded(included));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return WizardPage(
      title: s.pricesFinalQ,
      subtitle: s.pricesFinalHint,
      children: [
        OptionCard(emoji: '✅', title: s.yesIncluded, hint: s.yesIncludedHint,
            selected: _picked && _included, onTap: () => _choose(true)),
        OptionCard(emoji: '➕', title: s.noAddOnTop, hint: s.noAddOnTopHint,
            selected: _picked && !_included, onTap: () => _choose(false)),
      ],
    );
  }
}

// ── 2a · Country & currency ───────────────────────────────────────────────────

class CountryPage extends ConsumerStatefulWidget {
  const CountryPage({super.key});
  @override ConsumerState<CountryPage> createState() => _CountryPageState();
}

class _CountryPageState extends ConsumerState<CountryPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final chosen = ref.watch(wizardProvider).country?.code;
    final q = _q.trim().toLowerCase();
    final list = kCountries.where((c) =>
        q.isEmpty || c.en.toLowerCase().contains(q) || c.ar.contains(q) ||
        c.currency.toLowerCase().contains(q) ||
        (kCurrencyNames[c.currency]?.$1.toLowerCase().contains(q) ?? false) ||
        (kCurrencyNames[c.currency]?.$2.contains(q) ?? false)).toList();

    return WizardPage(
      title: s.countryCurrency,
      subtitle: s.countryHint,
      primaryLabel: s.skipUseUsd,
      onPrimary: () => ref.read(wizardProvider.notifier).skipCountry(),
      children: [
        CupertinoSearchTextField(
          placeholder: s.searchCountry,
          style: TextStyle(color: p.label),
          backgroundColor: p.fill,
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 12),
        InsetGroup(separatorInset: 58, children: [
          for (final c in list)
            Semantics(button: true, label: '${c.name(s.isAr)} ${c.currency}', excludeSemantics: true,
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { HapticFeedback.selectionClick(); ref.read(wizardProvider.notifier).pickCountry(c); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  SizedBox(width: 32, child: Text(c.flag, style: const TextStyle(fontSize: 26))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name(s.isAr), style: TextStyle(fontSize: 17, letterSpacing: -.4, color: p.label)),
                    Text('${s.isAr ? kCurrencyNames[c.currency]!.$2 : kCurrencyNames[c.currency]!.$1} · ${c.currency}',
                        style: TextStyle(fontSize: 13, color: p.secondary)),
                  ])),
                  if (c.code == chosen) Icon(CupertinoIcons.checkmark_alt, color: p.accent, size: 22)
                  else Icon(CupertinoIcons.chevron_forward, color: p.tertiary, size: 16),
                ]),
              ),
            )),
        ]),
      ],
    );
  }
}

// ── 2b · Confirm VAT & service ────────────────────────────────────────────────

class RatesPage extends ConsumerStatefulWidget {
  const RatesPage({super.key});
  @override ConsumerState<RatesPage> createState() => _RatesPageState();
}

class _RatesPageState extends ConsumerState<RatesPage> {
  late final TextEditingController _vat, _svc;

  @override
  void initState() {
    super.initState();
    final (v, sv) = ref.read(wizardProvider.notifier).suggestedRates();
    _vat = TextEditingController(text: _fmtPct(v));
    _svc = TextEditingController(text: _fmtPct(sv));
  }

  @override
  void dispose() { _vat.dispose(); _svc.dispose(); super.dispose(); }

  Future<void> _confirm(bool makeDefault) => ref.read(wizardProvider.notifier).confirmRates(
      vat: (_num(_vat.text) ?? 0).clamp(0, 100).toDouble(),
      service: (_num(_svc.text) ?? 0).clamp(0, 100).toDouble(),
      makeDefault: makeDefault);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final c = ref.watch(wizardProvider).country;
    if (c == null) return const SizedBox.shrink();

    Widget box(String label, TextEditingController ctrl) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 0, 6),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsetsDirectional.only(start: 12),
              child: Text(label, style: TextStyle(fontSize: 13, color: p.secondary))),
          VoiceField(controller: ctrl, placeholder: '0', numeric: true, suffixText: '%', large: true, fill: p.surface),
        ]),
      ),
    );

    return WizardPage(
      title: '${c.name(s.isAr)} · ${c.currency}',
      subtitle: s.usualRates(c.name(s.isAr)),
      centered: true,
      children: [
        Center(child: Text(c.flag, style: const TextStyle(fontSize: 64))),
        const SizedBox(height: 18),
        Row(children: [box(s.vatLabel, _vat), const SizedBox(width: 12), box(s.serviceCharge, _svc)]),
        const SizedBox(height: 20),
        AppleButton(label: s.makeMyDefault, onTap: () { HapticFeedback.lightImpact(); _confirm(true); }),
        SecondaryButton(s.thisBillOnly, onTap: () => _confirm(false)),
        const SizedBox(height: 12),
        Text(s.defaultNote, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: p.secondary)),
      ],
    );
  }
}

// ── 3a · How many people? ─────────────────────────────────────────────────────

class PeopleCountPage extends ConsumerStatefulWidget {
  const PeopleCountPage({super.key});
  @override ConsumerState<PeopleCountPage> createState() => _PeopleCountPageState();
}

class _PeopleCountPageState extends ConsumerState<PeopleCountPage> {
  static const _counts = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
  late int? _sel = () {
    final n = ref.read(wizardProvider.notifier).draft.people.length;
    final i = _counts.indexOf(n);
    return i >= 0 ? i : null;
  }();
  final _other = TextEditingController();

  @override
  void dispose() { _other.dispose(); super.dispose(); }

  int? get _otherCount {
    final o = _num(_other.text)?.toInt();
    return (o != null && o > 0) ? o.clamp(1, 50) : null;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final groups = ref.watch(groupsProvider);
    return WizardPage(
      title: s.howManyPeopleTitle,
      subtitle: s.includingYou,
      children: [
        NumberGrid(
          labels: [for (final n in _counts) s.n(n)],
          selected: _other.text.trim().isEmpty ? _sel : null,
          onTap: (i) {
            setState(() { _sel = i; _other.clear(); });
            advanceSoon(() => ref.read(wizardProvider.notifier).setPeopleCount(_counts[i]));
          },
        ),
        const SizedBox(height: 12),
        VoiceField(
          controller: _other, placeholder: s.otherNumber, numeric: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) { if (_otherCount != null) ref.read(wizardProvider.notifier).setPeopleCount(_otherCount!); },
          trailing: _otherCount == null ? null
              : GoButton(onTap: () => ref.read(wizardProvider.notifier).setPeopleCount(_otherCount!)),
        ),
        if (groups.isNotEmpty) ...[
          SectionLabel(s.orPickGroup),
          InsetGroup(separatorInset: 16, children: [
            for (final g in groups)
              Semantics(button: true, label: g.name, excludeSemantics: true,
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () { HapticFeedback.selectionClick(); ref.read(wizardProvider.notifier).useGroup(g); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.name, style: TextStyle(fontSize: 17, color: p.label)),
                      Text(g.members.join(s.isAr ? '، ' : ', '), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.secondary)),
                    ])),
                    Icon(CupertinoIcons.chevron_forward, color: p.tertiary, size: 16),
                  ]),
                ),
              )),
          ]),
        ],
      ],
    );
  }
}

// ── 3b · Who's splitting? ─────────────────────────────────────────────────────

class NamesPage extends ConsumerStatefulWidget {
  const NamesPage({super.key});
  @override ConsumerState<NamesPage> createState() => _NamesPageState();
}

class _NamesPageState extends ConsumerState<NamesPage> {
  final List<TextEditingController> _rows = [];
  late final TextEditingController _me;
  bool _includeMe = true;

  @override
  void initState() {
    super.initState();
    final myName = ref.read(myNameProvider);
    _me = TextEditingController(text: myName);
    final names = [...ref.read(wizardProvider.notifier).pendingNames];
    if (myName.isNotEmpty) {
      // You're in the list (count page adds you first, or editing / a group with you in it).
      final i = names.indexWhere((n) => n.trim().toLowerCase() == myName.toLowerCase());
      _includeMe = i >= 0;
      if (i >= 0) names.removeAt(i);
    } else if (names.length > 1 && names.every((n) => n.trim().isEmpty)) {
      // No saved name yet: "How many people (including you)" → one of the blanks is you.
      names.removeLast();
    }
    // Generated "Person 1/2…" names come back as empty fields (they're placeholders).
    for (final n in names) {
      final isDefault = RegExp(r'^(Person|شخص) [0-9٠-٩]+$').hasMatch(n.trim());
      _rows.add(TextEditingController(text: isDefault ? '' : n));
    }
    if (_rows.isEmpty) _rows.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _rows) { c.dispose(); }
    _me.dispose();
    super.dispose();
  }

  int get _offset => _includeMe ? 1 : 0;

  /// The total stays as chosen on "How many people": leaving yourself out adds
  /// a field; including yourself again removes an empty one.
  void _setIncludeMe(bool v) {
    HapticFeedback.selectionClick();
    setState(() {
      _includeMe = v;
      if (!v) {
        _rows.add(TextEditingController());
      } else {
        final i = _rows.lastIndexWhere((c) => c.text.trim().isEmpty);
        if (i >= 0 && _rows.length > 1) _rows.removeAt(i).dispose();
      }
    });
  }

  /// Everyone on the bill, you first (empty name → "Me"); empty rows → Person 1, 2…
  List<String> get _names {
    final s = ref.read(stringsProvider);
    return [
      if (_includeMe) _me.text.trim().isEmpty ? s.meDefault : _me.text.trim(),
      for (var i = 0; i < _rows.length; i++)
        _rows[i].text.trim().isEmpty ? s.personN(i + 1) : _rows[i].text.trim(),
    ];
  }

  void _rememberMyName() {
    final v = _me.text.trim();
    if (v.isNotEmpty && v != ref.read(myNameProvider)) ref.read(myNameProvider.notifier).set(v);
  }

  Future<void> _pickContact(TextEditingController c) async {
    final name = await ContactsService.pickName();
    if (name != null && mounted) setState(() => c.text = name);
  }

  Future<void> _saveGroup() async {
    final s = ref.read(stringsProvider);
    final ctrl = TextEditingController();
    final name = await showAppleSheet<String>(
      context: context,
      title: s.nameThisGroup,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Column(mainAxisSize: MainAxisSize.min, children: [
        VoiceField(controller: ctrl, placeholder: s.groupNameHint, autofocus: true, onChanged: (_) => setSt(() {})),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in s.groupSuggestions)
            Pill(label: g, soft: true, on: ctrl.text == g, onTap: () => setSt(() => ctrl.text = g)),
        ]),
        const SizedBox(height: 18),
        AppleButton(label: s.saveGroupBtn.replaceAll('💾 ', ''),
            onTap: ctrl.text.trim().isEmpty ? null : () => Navigator.pop(ctx, ctrl.text.trim())),
        SecondaryButton(s.cancel, onTap: () => Navigator.pop(ctx)),
      ])),
    );
    ctrl.dispose();
    if (name == null || !mounted) return;
    await ref.read(wizardProvider.notifier).saveGroup(name, _names);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.groupSaved(name))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    return WizardPage(
      title: s.whoSplitting,
      subtitle: s.namesHint,
      primaryLabel: s.continueBtn,
      onPrimary: () { _rememberMyName(); ref.read(wizardProvider.notifier).confirmNames(_names); },
      children: [
        // ── Include me (your name is remembered for next time) ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.includeMe, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.label)),
                Text(s.includeMeHint, style: TextStyle(fontSize: 13, color: p.secondary)),
              ])),
              CupertinoSwitch(
                value: _includeMe,
                activeTrackColor: p.green,
                onChanged: _setIncludeMe,
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Avatar(
                person: Person(id: 'me', name: _me.text.trim().isEmpty ? s.meDefault : _me.text.trim(),
                    color: _includeMe ? personColor(0) : p.tertiary),
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(child: VoiceField(
                controller: _me, placeholder: s.yourName, fill: p.fill,
                onChanged: (_) => setState(() {}),
              )),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _rows.length; i++) ...[
          Row(children: [
            Avatar(
              person: Person(
                id: '$i',
                name: _rows[i].text.trim().isEmpty ? s.n(i + 1) : _rows[i].text.trim(),
                color: personColor(i + _offset),
              ),
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VoiceField(
                controller: _rows[i],
                placeholder: s.personN(i + 1),
                onChanged: (_) => setState(() {}),
                trailing: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(32, 36),
                        onPressed: () => _pickContact(_rows[i]),
                        child: Icon(CupertinoIcons.person_crop_rectangle, color: p.accent, size: 22),
                      ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsetsDirectional.only(start: 8),
              minimumSize: const Size(32, 36),
              onPressed: _rows.length + _offset <= 1 ? null : () {
                HapticFeedback.selectionClick();
                setState(() => _rows.removeAt(i).dispose());
              },
              child: Icon(CupertinoIcons.minus_circle, color: _rows.length + _offset <= 1 ? p.tertiary : p.red, size: 24),
            ),
          ]),
          const SizedBox(height: 10),
        ],
        PressableScale(
          onTap: () { HapticFeedback.selectionClick(); setState(() => _rows.add(TextEditingController())); },
          child: Container(
            height: 50,
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(CupertinoIcons.plus_circle_fill, color: p.accent, size: 22),
              const SizedBox(width: 8),
              Text(s.addPerson, style: TextStyle(fontSize: 17, color: p.accent, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        SecondaryButton(s.saveAsGroupBtn, onTap: _saveGroup),
      ],
    );
  }
}
