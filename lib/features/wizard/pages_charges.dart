// lib/features/wizard/pages_charges.dart
//
// Pages 5–8: tip, delivery fee, discount, whole numbers, the Quick check
// (with an Edit link per section), the charges editor, and the result.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/services/providers.dart';
import '../../core/services/settings_provider.dart';
import '../../core/utils/countries.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/number_parser.dart';
import '../../core/utils/strings.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';
import '../../shared/widgets/voice_field.dart';
import '../result/result_card.dart';
import 'pages_items.dart' show fmtMoney;
import 'wizard_controller.dart';
import 'wizard_widgets.dart';

double? _num(String t) => double.tryParse(normalizeDigits(t.trim()).replaceAll(',', '.'));
String _plainNum(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

// ── Quick-pick page (Tip, Delivery fee, Discount) ─────────────────────────────
//
// Tiles with suggested values, an "Other" field, one big glowing "No …" button
// that moves on at once, and Back + Next (Next lights up once a value is set).

class _PickPage extends ConsumerStatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? header;                 // e.g. % / Fixed switch
  final List<double> values;
  final String Function(double) label;
  final String otherPlaceholder;
  final String? prefix, suffix;
  final double initial;                 // current value on the bill (0 = none)
  final double? max;                    // e.g. 100 for percentages
  final String noneLabel;
  final VoidCallback onNone;
  final ValueChanged<double> onNext;
  const _PickPage({super.key, required this.title, this.subtitle, this.header, required this.values,
      required this.label, required this.otherPlaceholder, this.prefix, this.suffix, required this.initial,
      this.max, required this.noneLabel, required this.onNone, required this.onNext});
  @override ConsumerState<_PickPage> createState() => _PickPageState();
}

class _PickPageState extends ConsumerState<_PickPage> {
  late int? _sel = () {
    final i = widget.values.indexOf(widget.initial);
    return i >= 0 ? i : null;
  }();
  late final _other = TextEditingController(
      text: widget.initial > 0 && !widget.values.contains(widget.initial) ? _plainNum(widget.initial) : '');

  @override
  void dispose() { _other.dispose(); super.dispose(); }

  double? get _otherValue {
    final v = _num(_other.text);
    if (v == null || v <= 0) return null;
    if (widget.max != null && v > widget.max!) return null;
    return v;
  }

  double? get _value => _other.text.trim().isNotEmpty ? _otherValue : (_sel == null ? null : widget.values[_sel!]);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final v = _value;
    final tooBig = widget.max != null && (_num(_other.text) ?? 0) > widget.max!;
    return WizardPage(
      title: widget.title,
      subtitle: widget.subtitle,
      primaryLabel: s.nextBtn,
      onPrimary: v == null ? null : () => widget.onNext(v),
      children: [
        if (widget.header != null) ...[widget.header!, const SizedBox(height: 14)],
        NumberGrid(
          columns: 3,
          labels: [for (final x in widget.values) widget.label(x)],
          selected: _other.text.trim().isEmpty ? _sel : null,
          onTap: (i) => setState(() { _sel = i; _other.clear(); FocusScope.of(context).unfocus(); }),
        ),
        const SizedBox(height: 12),
        VoiceField(controller: _other, placeholder: widget.otherPlaceholder, numeric: true,
            prefixText: widget.prefix, suffixText: widget.suffix,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) { final o = _otherValue; if (o != null) widget.onNext(o); }),
        if (tooBig)
          Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(s.typeValidPct, style: TextStyle(fontSize: 14, color: p.red))),
        const SizedBox(height: 56),
        GlowButton(label: '🙅 ${widget.noneLabel}', onTap: widget.onNone),
      ],
    );
  }
}

String _tileAmount(S s, double v, String cur) => '${s.n(v.round())} $cur';

// ── 5 · Tip ───────────────────────────────────────────────────────────────────

class TipPage extends ConsumerWidget {
  const TipPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final ctl = ref.read(wizardProvider.notifier);
    return _PickPage(
      title: s.tipQuestion,
      subtitle: s.tipHint,
      values: const [5, 10, 15, 20, 25],
      label: s.fmtPct,
      otherPlaceholder: s.otherPct,
      suffix: '%',
      max: 100,
      initial: ref.read(billDraftProvider).extras.tipPct,
      noneLabel: s.noTip,
      onNone: () => ctl.setTip(0),
      onNext: ctl.setTip,
    );
  }
}

// ── 5b · Delivery fee (delivery orders) ───────────────────────────────────────

class DeliveryPage extends ConsumerWidget {
  const DeliveryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final ctl = ref.read(wizardProvider.notifier);
    final cur = currencySymbol(ref.watch(currencyProvider), arabic: s.isAr);
    return _PickPage(
      title: s.deliveryTitle,
      subtitle: s.deliveryEqualHint,
      values: const [5, 10, 15, 20, 25],
      label: (v) => _tileAmount(s, v, cur),
      otherPlaceholder: s.otherAmount,
      prefix: cur,
      initial: ref.read(billDraftProvider).extras.deliveryFee,
      noneLabel: s.noDeliveryFee,
      onNone: () => ctl.setDelivery(0),
      onNext: ctl.setDelivery,
    );
  }
}

// ── 6 · Discount ──────────────────────────────────────────────────────────────

class DiscountPage extends ConsumerStatefulWidget {
  const DiscountPage({super.key});
  @override ConsumerState<DiscountPage> createState() => _DiscountPageState();
}

class _DiscountPageState extends ConsumerState<DiscountPage> {
  late bool _fixed = ref.read(billDraftProvider).extras.discountFixed > 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final ctl = ref.read(wizardProvider.notifier);
    final ext = ref.read(billDraftProvider).extras;
    final cur = currencySymbol(ref.watch(currencyProvider), arabic: s.isAr);
    final header = SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<bool>(
        groupValue: _fixed,
        children: {
          false: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.percentage)),
          true: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.fixedDiscount)),
        },
        onValueChanged: (x) { if (x != null) { HapticFeedback.selectionClick(); setState(() => _fixed = x); } },
      ),
    );
    return _PickPage(
      key: ValueKey(_fixed),          // switching tabs clears the selection
      title: s.discountQuestion,
      header: header,
      values: _fixed ? const [10, 20, 25, 50, 100] : const [5, 10, 15, 20, 25],
      label: _fixed ? (v) => _tileAmount(s, v, cur) : s.fmtPct,
      otherPlaceholder: _fixed ? s.otherAmount : s.otherPct,
      prefix: _fixed ? cur : null,
      suffix: _fixed ? null : '%',
      max: _fixed ? null : 100,
      initial: _fixed ? ext.discountFixed : ext.discountPct,
      noneLabel: s.noDiscountBtn,
      onNone: () => ctl.setDiscount(),
      onNext: (v) => _fixed ? ctl.setDiscount(fixed: v) : ctl.setDiscount(pct: v),
    );
  }
}

// ── 7 · Whole numbers? ────────────────────────────────────────────────────────

class RoundUpPage extends ConsumerWidget {
  const RoundUpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final ctl = ref.read(wizardProvider.notifier);
    return WizardPage(
      title: s.wholeTitle,
      centered: true,
      children: [
        const Center(child: Text('🪙', style: TextStyle(fontSize: 64))),
        const SizedBox(height: 10),
        Text(s.wholeHint, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: p.secondary, height: 1.4)),
        const SizedBox(height: 26),
        AppleButton(label: s.yesRoundUp, onTap: () { HapticFeedback.lightImpact(); ctl.setRoundUp(true); }),
        SecondaryButton(s.skip, onTap: () => ctl.setRoundUp(false)),
      ],
    );
  }
}

// ── 8 · Quick check ───────────────────────────────────────────────────────────

class QuickCheckPage extends ConsumerWidget {
  const QuickCheckPage({super.key});

  Future<void> _placeName(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final ctrl = TextEditingController(text: ref.read(billDraftProvider).merchant);
    final name = await showAppleSheet<String>(
      context: context,
      title: s.askPlaceName,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        VoiceField(controller: ctrl, placeholder: s.placeLabel, autofocus: true),
        const SizedBox(height: 16),
        AppleButton(label: s.saveBtn, onTap: () => Navigator.pop(ctx, ctrl.text)),
      ]),
    );
    ctrl.dispose();
    if (name != null) ref.read(wizardProvider.notifier).setPlaceName(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final w = ref.watch(wizardProvider);
    final d = ref.watch(billDraftProvider);
    final ctl = ref.read(wizardProvider.notifier);
    final ext = d.extras;
    final sub = d.items.fold(0.0, (a, i) => a + i.price);
    final country = w.country ?? countryForCurrency(ref.watch(currencyProvider));

    Widget line(String a, String b, {Color? color, bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(a, style: TextStyle(fontSize: bold ? 20 : 16, fontWeight: bold ? FontWeight.w700 : null,
            color: color ?? p.label))),
        Text(b, style: TextStyle(fontSize: bold ? 20 : 16, fontWeight: bold ? FontWeight.w700 : null,
            color: color ?? p.label, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );

    return WizardPage(
      title: s.quickCheckTitle,
      subtitle: [
        w.delivery ? '🛵 ${s.deliveryOrder}' : '🍽️ ${s.dineIn}',
        if (country != null) '${country.flag} ${country.name(s.isAr)}',
        ref.watch(currencyProvider),
        if (d.merchant.isNotEmpty) '🏷 ${d.merchant}',
      ].join(' · '),
      primaryLabel: s.calculate,
      onPrimary: d.items.isEmpty || d.people.isEmpty ? null : ctl.splitIt,
      children: [
        SectionLabel(s.peopleSection(d.people.length), action: s.editSmall, onAction: ctl.editPeople),
        WCard(child: Text(d.people.map((x) => x.name).join(s.isAr ? '، ' : ', '),
            style: TextStyle(fontSize: 16, color: p.label))),
        SectionLabel(s.itemsSection(d.items.length), action: s.editSmall, onAction: ctl.editItems),
        WCard(child: Column(children: [
          for (final it in d.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text.rich(TextSpan(children: [
                  TextSpan(text: s.itemLabel(it.name, it.quantity), style: TextStyle(fontSize: 16, color: p.label)),
                  if (_whoOf(it, d.people, s) != null)
                    TextSpan(text: ' · ${_whoOf(it, d.people, s)}', style: TextStyle(fontSize: 13, color: p.secondary)),
                ]))),
                const SizedBox(width: 10),
                Text(fmtMoney(ref, it.price), style: TextStyle(fontSize: 16, color: p.label,
                    fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          Divider(color: p.separator, height: 14),
          line(s.itemsTotalLabel, fmtMoney(ref, sub), color: p.label),
        ])),
        SectionLabel(s.chargesSection, action: s.editSmall, onAction: ctl.editCharges),
        WCard(child: Column(children: [
          line(s.subtotalLabel, fmtMoney(ref, sub)),
          if (ext.hasDiscount)
            line('${s.discountLabel}${ext.discountPct > 0 ? ' ${s.fmtPct(ext.discountPct)}' : ''}',
                '−${fmtMoney(ref, ext.discountAmount(sub))}', color: p.green),
          if (w.pricesIncluded && ext.vatPct == 0 && ext.servicePct == 0)
            line(s.vatAndService, s.includedInPrices),
          if (ext.vatPct > 0) line('${s.vatLabel} ${s.fmtPct(ext.vatPct)}', fmtMoney(ref, ext.vatAmount(sub))),
          if (ext.servicePct > 0) line('${s.serviceLabel} ${s.fmtPct(ext.servicePct)}', fmtMoney(ref, ext.serviceAmount(sub))),
          line(s.tipLabel, ext.tipPct > 0 ? '${s.fmtPct(ext.tipPct)} · ${fmtMoney(ref, ext.tipAmount(sub))}' : s.noneOpt),
          if (w.delivery || ext.deliveryFee > 0)
            line(s.deliveryLabel, ext.deliveryFee > 0 ? fmtMoney(ref, ext.deliveryFee) : s.noneOpt),
          line(s.wholeNumbers, ext.roundUpTo > 0 ? s.onLabel : s.offLabel),
          Divider(color: p.separator, height: 18),
          line(s.grandTotal, fmtMoney(ref, ext.grandTotal(sub)), bold: true),
        ])),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _placeName(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(d.merchant.isEmpty ? s.addPlaceName : '🏷 ${d.merchant} · ${s.editSmall}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.accent)),
          ),
        ),
      ],
    );
  }
}

/// "Kary" / "Mary, Ssmer" for items not shared by everyone; null = everyone.
String? _whoOf(BillItem it, List<Person> people, S s) {
  final ids = it.personIds.where((id) => people.any((x) => x.id == id)).toList();
  if (ids.isEmpty || ids.length == people.length) return null;
  return [for (final x in people) if (ids.contains(x.id)) x.name].join(s.isAr ? '، ' : ', ');
}

// ── 8b · Edit charges (from the Quick check) ──────────────────────────────────

class ChargesEditPage extends ConsumerStatefulWidget {
  const ChargesEditPage({super.key});
  @override ConsumerState<ChargesEditPage> createState() => _ChargesEditPageState();
}

class _ChargesEditPageState extends ConsumerState<ChargesEditPage> {
  late final BillExtras _e = ref.read(billDraftProvider).extras;
  late final _vat = TextEditingController(text: _plainNum(_e.vatPct));
  late final _svc = TextEditingController(text: _plainNum(_e.servicePct));
  late final _tip = TextEditingController(text: _plainNum(_e.tipPct));
  late final _del = TextEditingController(text: _plainNum(_e.deliveryFee));
  late bool _fixed = _e.discountFixed > 0;
  late final _disc = TextEditingController(text: _plainNum(_fixed ? _e.discountFixed : _e.discountPct));
  late bool _whole = _e.roundUpTo > 0;
  late bool _included = ref.read(wizardProvider).pricesIncluded;

  @override
  void dispose() {
    for (final c in [_vat, _svc, _tip, _del, _disc]) { c.dispose(); }
    super.dispose();
  }

  void _save() {
    double pct(TextEditingController c) => (_num(c.text) ?? 0).clamp(0, 100).toDouble();
    final d = (_num(_disc.text) ?? 0).clamp(0, double.infinity).toDouble();
    ref.read(wizardProvider.notifier).setPricesIncludedFlag(_included);
    ref.read(wizardProvider.notifier).saveCharges(_e.copyWith(
      vatPct: _included ? 0 : pct(_vat), servicePct: _included ? 0 : pct(_svc), tipPct: pct(_tip),
      deliveryFee: (_num(_del.text) ?? 0).clamp(0, double.infinity).toDouble(),
      discountPct: _fixed ? 0 : d.clamp(0, 100).toDouble(), discountFixed: _fixed ? d : 0,
      roundUpTo: _whole ? 1 : 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final w = ref.watch(wizardProvider);
    final cur = currencySymbol(ref.watch(currencyProvider), arabic: s.isAr);

    Widget pctRow(String label, TextEditingController c) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 16, color: p.label))),
        Expanded(child: VoiceField(controller: c, placeholder: '0', numeric: true, suffixText: '%')),
      ]),
    );

    return WizardPage(
      title: s.editCharges,
      primaryLabel: s.saveBtn,
      onPrimary: _save,
      children: [
        WCard(child: Row(children: [
          Expanded(child: Text(s.pricesIncludeToggle, style: TextStyle(fontSize: 16, color: p.label))),
          CupertinoSwitch(value: _included, activeTrackColor: p.green,
              onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _included = v); }),
        ])),
        const SizedBox(height: 12),
        if (!_included) ...[
          pctRow(s.vatLabel, _vat),
          pctRow(s.serviceCharge, _svc),
        ],
        pctRow(s.tipLabel, _tip),
        if (w.delivery)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(width: 120, child: Text(s.deliveryLabel, style: TextStyle(fontSize: 16, color: p.label))),
              Expanded(child: VoiceField(controller: _del, placeholder: '0', numeric: true, prefixText: cur)),
            ]),
          ),
        SectionLabel(s.discountLabel),
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<bool>(
            groupValue: _fixed,
            children: {
              false: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.percentage)),
              true: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.fixedDiscount)),
            },
            onValueChanged: (x) { if (x != null) setState(() => _fixed = x); },
          ),
        ),
        const SizedBox(height: 10),
        VoiceField(controller: _disc, placeholder: '0', numeric: true,
            prefixText: _fixed ? cur : null, suffixText: _fixed ? null : '%'),
        const SizedBox(height: 14),
        WCard(child: Row(children: [
          Expanded(child: Text('🪙 ${s.wholeNumbers}', style: TextStyle(fontSize: 16, color: p.label))),
          CupertinoSwitch(value: _whole, activeTrackColor: p.green,
              onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _whole = v); }),
        ])),
      ],
    );
  }
}

// ── Result ────────────────────────────────────────────────────────────────────

class ResultPage extends ConsumerWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final result = ref.watch(splitResultProvider);
    final bill = ref.watch(finalBillProvider);
    if (result == null || bill == null) return const SizedBox.shrink();
    return WizardPage(
      title: s.finalSplit,
      primaryLabel: '＋ ${s.newBill}',
      onPrimary: () => ref.read(wizardProvider.notifier).startOver(),
      children: [ResultCard(result: result, bill: bill, showNewBill: false)],
    );
  }
}
