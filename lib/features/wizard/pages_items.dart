// lib/features/wizard/pages_items.dart
//
// Page 4: scan or type the items, how many, one card per item, and the review list.
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/models.dart';
import '../../core/services/providers.dart';
import '../../core/services/settings_provider.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/number_parser.dart';
import '../../core/utils/strings.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/voice_field.dart';
import 'wizard_controller.dart';
import 'wizard_widgets.dart';

String fmtMoney(WidgetRef ref, double v) {
  final s = ref.read(stringsProvider);
  final str = fmtAmount(v, ref.read(currencyProvider), arabic: s.isAr);
  return s.isAr ? toArabicDigits(str) : str;
}

// ── 4a · Scan or type ─────────────────────────────────────────────────────────

class ItemsMethodPage extends ConsumerStatefulWidget {
  const ItemsMethodPage({super.key});
  @override ConsumerState<ItemsMethodPage> createState() => _ItemsMethodPageState();
}

class _ItemsMethodPageState extends ConsumerState<ItemsMethodPage> {
  bool _scan = false;
  bool _picked = false;

  Future<void> _doScan() async {
    final s = ref.read(stringsProvider);
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(s.scanReceiptTitle),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, ImageSource.camera), child: Text(s.takePhoto)),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, ImageSource.gallery), child: Text(s.chooseGallery)),
        ],
        cancelButton: CupertinoActionSheetAction(isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
      ),
    );
    if (source == null) return;
    final xf = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (xf == null) return;
    await ref.read(wizardProvider.notifier).scanReceipt(File(xf.path));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final w = ref.watch(wizardProvider);
    return WizardPage(
      title: s.addTheItems,
      subtitle: s.howAddItems,
      children: [
        OptionCard(emoji: '📷', title: s.scanReceiptOpt, hint: s.scanReceiptHint,
            selected: _picked && _scan, onTap: () {
              if (w.busy) return;
              setState(() { _scan = true; _picked = true; });
              advanceSoon(_doScan);
            }),
        OptionCard(emoji: '✍️', title: s.enterManually, hint: s.enterManuallyHint,
            selected: _picked && !_scan, onTap: () {
              if (w.busy) return;
              setState(() { _scan = false; _picked = true; });
              advanceSoon(() => ref.read(wizardProvider.notifier).chooseManual());
            }),
        if (w.busy)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const CupertinoActivityIndicator(), const SizedBox(width: 10),
              Text(s.scanning, style: TextStyle(fontSize: 15, color: p.secondary)),
            ]),
          ),
        if (w.message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(w.message!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: p.red)),
          ),
      ],
    );
  }
}

// ── 4b · How many items? ──────────────────────────────────────────────────────

class ItemCountPage extends ConsumerStatefulWidget {
  const ItemCountPage({super.key});
  @override ConsumerState<ItemCountPage> createState() => _ItemCountPageState();
}

class _ItemCountPageState extends ConsumerState<ItemCountPage> {
  int? _sel;
  final _other = TextEditingController();

  @override
  void dispose() { _other.dispose(); super.dispose(); }

  int? get _otherCount {
    final o = double.tryParse(normalizeDigits(_other.text.trim()))?.toInt();
    return (o != null && o > 0) ? o.clamp(1, 100) : null;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return WizardPage(
      title: s.howManyItemsTitle,
      subtitle: s.itemsCountHint,
      children: [
        NumberGrid(
          labels: [for (var n = 1; n <= 10; n++) s.n(n)],
          selected: _other.text.trim().isEmpty ? _sel : null,
          onTap: (i) {
            setState(() { _sel = i; _other.clear(); });
            advanceSoon(() => ref.read(wizardProvider.notifier).setItemCount(i + 1));
          },
        ),
        const SizedBox(height: 12),
        VoiceField(
          controller: _other, placeholder: s.otherNumber, numeric: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) { if (_otherCount != null) ref.read(wizardProvider.notifier).setItemCount(_otherCount!); },
          trailing: _otherCount == null ? null
              : GoButton(onTap: () => ref.read(wizardProvider.notifier).setItemCount(_otherCount!)),
        ),
      ],
    );
  }
}

// ── 4c · One item ─────────────────────────────────────────────────────────────

class ItemEntryPage extends ConsumerStatefulWidget {
  final int index;
  const ItemEntryPage({super.key, required this.index});
  @override ConsumerState<ItemEntryPage> createState() => _ItemEntryPageState();
}

class _ItemEntryPageState extends ConsumerState<ItemEntryPage> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  late Set<String> _who;

  @override
  void initState() {
    super.initState();
    final ctl = ref.read(wizardProvider.notifier);
    final people = ctl.draft.people.map((p) => p.id).toList();
    final it = ctl.itemAt(widget.index);
    if (it != null) {
      _name.text = it.name;
      _price.text = it.price == it.price.roundToDouble() ? it.price.toStringAsFixed(0) : '${it.price}';
      _who = it.personIds.isEmpty ? {...people} : {...it.personIds.where(people.contains)};
      if (_who.isEmpty) _who = {...people};
    } else {
      _who = {...people}; // everyone by default
    }
  }

  @override
  void dispose() { _name.dispose(); _price.dispose(); super.dispose(); }

  double? get _priceValue {
    final v = double.tryParse(normalizeDigits(_price.text.trim()).replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  bool get _valid => _name.text.trim().isNotEmpty && _priceValue != null && _who.isNotEmpty;

  /// "🍕 Pizza" → "Pizza"
  static String _plain(String label) {
    final i = label.indexOf(' ');
    return i < 0 ? label : label.substring(i + 1);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final w = ref.watch(wizardProvider);
    final ctl = ref.read(wizardProvider.notifier);
    final people = ref.watch(billDraftProvider).people;
    final items = ref.watch(billDraftProvider).items;
    final used = {
      for (var i = 0; i < items.length; i++) if (i != widget.index) items[i].name.toLowerCase(),
    };
    final suggestions = [for (final l in s.itemSuggestions) if (!used.contains(_plain(l).toLowerCase())) l];
    final everyone = _who.length == people.length;
    final single = w.nav.single;
    final price = _priceValue;

    String hint() {
      if (price == null || _who.isEmpty) return s.fillItem;
      if (everyone && people.length > 1) return s.splitBetween(s.everyoneLower.toLowerCase(), fmtMoney(ref, price / people.length));
      if (_who.length == 1) return '→ ${people.firstWhere((x) => _who.contains(x.id)).name}';
      final names = [for (final x in people) if (_who.contains(x.id)) x.name].join(s.isAr ? '، ' : ', ');
      return s.splitBetween(names, fmtMoney(ref, price / _who.length));
    }

    return WizardPage(
      eyebrow: s.itemXofY(widget.index + 1, w.itemTotal < widget.index + 1 ? widget.index + 1 : w.itemTotal),
      title: s.whatOrdered,
      primaryLabel: single ? s.saveBtn : (widget.index + 1 >= w.itemTotal ? s.continueBtn : s.nextItem),
      onPrimary: !_valid ? null : () => ctl.saveItem(widget.index,
          name: _name.text, price: _priceValue!, whoIds: [for (final x in people) if (_who.contains(x.id)) x.id]),
      children: [
        SectionLabel(s.editName),
        VoiceField(controller: _name, placeholder: s.whatOrdered, onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in suggestions)
            Pill(label: l, soft: true, on: _name.text.trim() == _plain(l),
                onTap: () => setState(() => _name.text = _plain(l))),
        ]),
        SectionLabel(s.priceLabel),
        VoiceField(controller: _price, placeholder: '0', numeric: true,
            prefixText: currencySymbol(ref.watch(currencyProvider), arabic: s.isAr), onChanged: (_) => setState(() {})),
        SectionLabel(s.whoShared),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill(label: '👥 ${s.everyone}', on: everyone, onTap: () => setState(() {
            _who = everyone ? <String>{} : {for (final x in people) x.id};
          })),
          for (final x in people)
            Pill(label: _who.contains(x.id) && !everyone ? '✓ ${x.name}' : x.name,
                on: _who.contains(x.id) && !everyone,
                onTap: () => setState(() {
                  if (everyone) { _who = {x.id}; }            // from "everyone" → just this person
                  else if (_who.contains(x.id)) { _who.remove(x.id); }
                  else { _who.add(x.id); }
                })),
        ]),
        const SizedBox(height: 10),
        Text(hint(), style: TextStyle(fontSize: 14, color: p.secondary)),
      ],
    );
  }
}

// ── 4d · Review items ─────────────────────────────────────────────────────────

class ItemsReviewPage extends ConsumerWidget {
  const ItemsReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final draft = ref.watch(billDraftProvider);
    final ctl = ref.read(wizardProvider.notifier);
    final total = draft.items.fold(0.0, (a, i) => a + i.price);

    String who(BillItem it) {
      final ids = it.personIds.where((id) => draft.people.any((x) => x.id == id)).toList();
      final n = ids.isEmpty ? draft.people.length : ids.length;
      final names = ids.isEmpty ? s.everyone
          : [for (final x in draft.people) if (ids.contains(x.id)) x.name].join(s.isAr ? '، ' : ', ');
      return n > 1 ? '$names · ${fmtMoney(ref, it.price / n)} ${s.isAr ? 'لكل واحد' : 'each'}' : names;
    }

    return WizardPage(
      title: s.yourItems,
      subtitle: s.itemsTotal(draft.items.length, fmtMoney(ref, total)),
      primaryLabel: s.looksGoodNext,
      onPrimary: draft.items.isEmpty ? null : ctl.itemsDone,
      children: [
        for (var i = 0; i < draft.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(draft.items[i].name,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.label))),
                Text(fmtMoney(ref, draft.items[i].price),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.label)),
              ]),
              const SizedBox(height: 3),
              Text('→ ${who(draft.items[i])}', style: TextStyle(fontSize: 14, color: p.secondary)),
              const SizedBox(height: 8),
              Row(children: [
                GestureDetector(onTap: () { HapticFeedback.selectionClick(); ctl.editItem(i); },
                    child: Text(s.editSmall, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.accent))),
                const SizedBox(width: 20),
                GestureDetector(onTap: () { HapticFeedback.mediumImpact(); ctl.deleteItem(i); },
                    child: Text(s.deleteSmall, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.red))),
              ]),
            ])),
          ),
        SecondaryButton(s.addItemBtn, onTap: ctl.addItem),
      ],
    );
  }
}
