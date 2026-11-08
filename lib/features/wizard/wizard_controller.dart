// lib/features/wizard/wizard_controller.dart
//
// Drives the full-screen pages: which page is showing, the Back history, and
// every answer. The bill itself lives in billDraftProvider so the calculator,
// history and result card keep working unchanged.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/services/providers.dart';
import '../../core/services/settings_provider.dart';
import '../../core/services/split_calculator.dart';
import '../../core/utils/countries.dart';
import '../../core/utils/strings.dart';

enum WStep {
  orderType, pricesIncluded, country, rates, peopleCount, names, itemsMethod, itemCount,
  itemEntry, itemsReview, tip, delivery, discount, roundUp, quickCheck,
  chargesEdit, result,
}

/// One entry in the Back history. [index] is the item number for [WStep.itemEntry];
/// [single] means "editing one item from the review page" (save returns there).
class WNav {
  final WStep step;
  final int index;
  final bool single;
  const WNav(this.step, {this.index = 0, this.single = false});
}

class WizardState {
  final List<WNav> stack;
  final bool delivery;
  /// Menu prices already include VAT & service → nothing is added on top.
  final bool pricesIncluded;
  final Country? country;   // chosen for this bill (null = skipped / USD)
  final int itemTotal;      // planned number of items
  final bool returnToCheck; // editing from the Quick check
  final bool busy;          // scanning a receipt
  final String? message;    // short notice shown on the page (e.g. scan failed)

  const WizardState({
    this.stack = const [WNav(WStep.orderType)],
    this.delivery = false,
    this.pricesIncluded = false,
    this.country,
    this.itemTotal = 0,
    this.returnToCheck = false,
    this.busy = false,
    this.message,
  });

  WNav get nav => stack.last;
  WStep get step => nav.step;
  bool get canGoBack => stack.length > 1 && step != WStep.result;

  WizardState copyWith({
    List<WNav>? stack, bool? delivery, bool? pricesIncluded, Country? country, bool clearCountry = false,
    int? itemTotal, bool? returnToCheck, bool? busy, String? message, bool clearMessage = false,
  }) => WizardState(
    stack: stack ?? this.stack,
    delivery: delivery ?? this.delivery,
    pricesIncluded: pricesIncluded ?? this.pricesIncluded,
    country: clearCountry ? null : (country ?? this.country),
    itemTotal: itemTotal ?? this.itemTotal,
    returnToCheck: returnToCheck ?? this.returnToCheck,
    busy: busy ?? this.busy,
    message: clearMessage ? null : (message ?? this.message),
  );
}

final wizardProvider = NotifierProvider<WizardController, WizardState>(WizardController.new);

class WizardController extends Notifier<WizardState> {
  static const _uuid = Uuid();

  @override
  WizardState build() => const WizardState();

  BillDraftNotifier get _draft => ref.read(billDraftProvider.notifier);
  BillDraft get draft => ref.read(billDraftProvider);
  S get _s => ref.read(stringsProvider);

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _go(WNav nav) => state = state.copyWith(stack: [...state.stack, nav], clearMessage: true);

  void back() {
    if (!state.canGoBack) return;
    final stack = [...state.stack]..removeLast();
    // Leaving the Quick check edit flow by going back also ends "return to check".
    final rtc = state.returnToCheck && stack.any((n) => n.step == WStep.quickCheck) &&
        stack.last.step != WStep.quickCheck;
    state = state.copyWith(stack: stack, returnToCheck: rtc, clearMessage: true);
  }

  /// After an edit started from the Quick check: jump straight back to it.
  bool _backToCheck() {
    if (!state.returnToCheck) return false;
    final i = state.stack.lastIndexWhere((n) => n.step == WStep.quickCheck);
    if (i < 0) return false;
    state = state.copyWith(stack: state.stack.sublist(0, i + 1), returnToCheck: false, clearMessage: true);
    return true;
  }

  void startOver() {
    _draft.reset();
    ref.read(splitResultProvider.notifier).value = null;
    ref.read(finalBillProvider.notifier).value = null;
    state = const WizardState();
  }

  // ── 1 · Dine-in or delivery ─────────────────────────────────────────────────

  void chooseOrderType({required bool delivery}) {
    state = state.copyWith(delivery: delivery);
    _go(const WNav(WStep.pricesIncluded));
  }

  // ── 1b · Are the menu prices final? ─────────────────────────────────────────

  void setPricesIncluded(bool included) {
    state = state.copyWith(pricesIncluded: included);
    final cur = ref.read(currencyProvider.notifier);
    if (cur.hasDefault) {
      // Saved default → skip the country pages and use its rates.
      final c = countryByCode(ref.read(countryProvider));
      state = state.copyWith(country: c);
      if (included) { _setRates(0, 0); } else { _setRates(cur.defaultVat, state.delivery ? 0 : cur.defaultService); }
      _go(const WNav(WStep.peopleCount));
    } else {
      _go(const WNav(WStep.country));
    }
  }

  /// From the charges editor: switch "prices include VAT & service" on or off.
  void setPricesIncludedFlag(bool included) => state = state.copyWith(pricesIncluded: included);

  // ── 2 · Country & rates ─────────────────────────────────────────────────────

  void pickCountry(Country c) {
    state = state.copyWith(country: c);
    ref.read(currencyProvider.notifier).use(c.currency, country: c.code);
    if (state.pricesIncluded) {
      _setRates(0, 0);           // final prices → no VAT/service page
      _go(const WNav(WStep.peopleCount));
    } else {
      _go(const WNav(WStep.rates));
    }
  }

  void skipCountry() {
    state = state.copyWith(clearCountry: true);
    ref.read(currencyProvider.notifier).use('USD');
    _setRates(0, 0);
    if (!_backToCheck()) _go(const WNav(WStep.peopleCount));
  }

  /// Usual rates for the chosen country (service is 0 for delivery orders).
  (double, double) suggestedRates() {
    final c = state.country;
    return (c?.vat ?? 0, state.delivery ? 0 : (c?.service ?? 0));
  }

  Future<void> confirmRates({required double vat, required double service, required bool makeDefault}) async {
    _setRates(vat, service);
    final c = state.country;
    if (makeDefault && c != null) {
      await ref.read(currencyProvider.notifier).setDefault(c.currency, country: c.code, vat: vat, service: service);
    }
    if (!_backToCheck()) _go(const WNav(WStep.peopleCount));
  }

  void _setRates(double vat, double service) =>
      _draft.setExtras(draft.extras.copyWith(vatPct: vat, servicePct: service));

  // ── 3 · People ──────────────────────────────────────────────────────────────

  /// Names to show on the names page for [count] people: keeps names already
  /// typed, puts "me" first when your name is set.
  List<String> namesFor(int count) {
    final me = ref.read(myNameProvider);
    final current = draft.people.map((p) => p.name).toList();
    final names = <String>[...current];
    if (names.isEmpty && me.isNotEmpty) names.add(me);
    while (names.length < count) { names.add(''); }
    return names.take(count).toList();
  }

  List<String> _pendingNames = const [];
  /// Names the names page should start with.
  List<String> get pendingNames => _pendingNames;

  void setPeopleCount(int n) {
    _pendingNames = namesFor(n);
    _go(const WNav(WStep.names));
  }

  void useGroup(FriendGroup g) {
    _pendingNames = [...g.members];
    _go(const WNav(WStep.names));
  }

  /// Opening the names page to edit people (from the Quick check).
  void editPeople() {
    _pendingNames = draft.people.map((p) => p.name).toList();
    state = state.copyWith(returnToCheck: true);
    _go(const WNav(WStep.names));
  }

  /// Empty names become "Person 1", "Person 2"…
  void confirmNames(List<String> raw) {
    final names = <String>[];
    for (var i = 0; i < raw.length; i++) {
      var n = raw[i].trim();
      if (n.isEmpty) n = _s.personN(i + 1);
      // Two people can't share a name — "Ahmed" twice becomes "Ahmed 2".
      var unique = n; var k = 2;
      while (names.any((x) => x.toLowerCase() == unique.toLowerCase())) { unique = '$n $k'; k++; }
      names.add(unique);
    }
    // Keep IDs (and colours) of people already on the bill, so item choices survive edits.
    final known = draft.people;
    final people = [
      for (var i = 0; i < names.length; i++)
        known.firstWhere((p) => p.name.toLowerCase() == names[i].toLowerCase(),
            orElse: () => Person(id: _uuid.v4(), name: names[i], color: kPersonColors[i % kPersonColors.length])),
    ];
    _draft.setPeople(people);
    final ids = people.map((p) => p.id).toSet();
    _draft.setItems([
      for (final it in draft.items) it.copyWith(personIds: it.personIds.where(ids.contains).toList()),
    ]);
    if (!_backToCheck()) _go(const WNav(WStep.itemsMethod));
  }

  Future<void> saveGroup(String name, List<String> raw) async {
    final members = [
      for (var i = 0; i < raw.length; i++) raw[i].trim().isEmpty ? _s.personN(i + 1) : raw[i].trim(),
    ];
    await ref.read(groupsProvider.notifier).add(name, members);
  }

  // ── 4 · Items ───────────────────────────────────────────────────────────────

  void chooseManual() => _go(const WNav(WStep.itemCount));

  void setItemCount(int n) {
    final start = draft.items.length;
    state = state.copyWith(itemTotal: start + n);
    _go(WNav(WStep.itemEntry, index: start));
  }

  /// Scan → items come in pre-filled; you confirm each card and pick who shared it.
  Future<void> scanReceipt(File file) async {
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final result = await ref.read(ocrServiceProvider).scanReceipt(file);
      if (result.items.isEmpty) {
        state = state.copyWith(busy: false,
            message: result.isArabic ? _s.arabicReceiptDetected : _s.cantReadReceipt);
        return;
      }
      final start = draft.items.length;
      for (final it in result.items) {
        _draft.addItem(BillItem(id: _uuid.v4(), name: it.name, price: it.price, quantity: it.quantity));
      }
      if (draft.merchant.isEmpty && result.merchant.isNotEmpty) _draft.setMerchant(result.merchant);
      _keepReceiptPhoto(file);
      state = state.copyWith(busy: false, itemTotal: draft.items.length);
      _go(WNav(WStep.itemEntry, index: start));
    } catch (_) {
      state = state.copyWith(busy: false, message: _s.cantScanReceipt);
    }
  }

  Future<void> _keepReceiptPhoto(File file) async {
    try {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/receipts');
      await dir.create(recursive: true);
      final copy = await file.copy('${dir.path}/${_uuid.v4()}.jpg');
      _draft.setReceiptPath(copy.path);
    } catch (_) {/* the photo is optional */}
  }

  /// Item already at [index] (when editing or after a scan), if any.
  BillItem? itemAt(int index) => index < draft.items.length ? draft.items[index] : null;

  /// Saves the item card. [whoIds] empty = everyone.
  void saveItem(int index, {required String name, required double price, required List<String> whoIds}) {
    final everyone = whoIds.length == draft.people.length;
    final ids = everyone ? <String>[] : whoIds;
    final items = [...draft.items];
    final old = itemAt(index);
    final item = (old ?? BillItem(id: _uuid.v4(), name: name, price: price))
        .copyWith(name: name.trim(), price: price, personIds: ids, portions: const {});
    if (index < items.length) { items[index] = item; } else { items.add(item); }
    _draft.setItems(numberRepeats(items, arabic: ref.read(stringsProvider).isAr));

    final nav = state.nav;
    if (nav.single) { back(); return; } // edited one item from the review page
    if (index + 1 < state.itemTotal) {
      _go(WNav(WStep.itemEntry, index: index + 1));
    } else {
      _go(const WNav(WStep.itemsReview));
    }
  }

  void editItem(int index) => _go(WNav(WStep.itemEntry, index: index, single: true));

  void deleteItem(int index) {
    final items = [...draft.items]..removeAt(index);
    _draft.setItems(items);
    state = state.copyWith(itemTotal: items.length);
  }

  void addItem() {
    state = state.copyWith(itemTotal: draft.items.length + 1);
    _go(WNav(WStep.itemEntry, index: draft.items.length, single: true));
  }

  void editItems() {
    state = state.copyWith(returnToCheck: true);
    _go(const WNav(WStep.itemsReview));
  }

  void itemsDone() {
    if (!_backToCheck()) _go(const WNav(WStep.tip));
  }

  // ── 5 · Charges ─────────────────────────────────────────────────────────────

  void setTip(double pct) {
    _draft.setExtras(draft.extras.copyWith(tipPct: pct));
    _go(WNav(state.delivery ? WStep.delivery : WStep.discount));
  }

  void setDelivery(double fee) {
    _draft.setExtras(draft.extras.copyWith(deliveryFee: fee));
    _go(const WNav(WStep.discount));
  }

  void setDiscount({double pct = 0, double fixed = 0}) {
    _draft.setExtras(draft.extras.copyWith(discountPct: pct, discountFixed: fixed));
    _go(const WNav(WStep.roundUp));
  }

  void setRoundUp(bool on) {
    _draft.setExtras(draft.extras.copyWith(roundUpTo: on ? 1 : 0));
    _go(const WNav(WStep.quickCheck));
  }

  void editCharges() => _go(const WNav(WStep.chargesEdit));

  void saveCharges(BillExtras extras) {
    _draft.setExtras(extras);
    back();
  }

  void setPlaceName(String name) => _draft.setMerchant(name.trim());

  // ── 6 · Result ──────────────────────────────────────────────────────────────

  Future<void> splitIt() async {
    final bill = draft.toBill(ref.read(currencyProvider));
    ref.read(splitResultProvider.notifier).value = SplitCalculator.calculate(bill);
    ref.read(finalBillProvider.notifier).value = bill;
    _go(const WNav(WStep.result));
    try {
      final svc = ref.read(historyServiceProvider);
      await svc.init();
      await svc.save(bill);
      ref.invalidate(historyProvider);
    } catch (_) {/* history is best-effort */}
  }

  /// "Step x of 8" for the top bar (0 = no label).
  static int stepNumber(WStep s) => switch (s) {
    WStep.orderType || WStep.pricesIncluded => 1,
    WStep.country || WStep.rates => 2,
    WStep.peopleCount || WStep.names => 3,
    WStep.itemsMethod || WStep.itemCount || WStep.itemEntry || WStep.itemsReview => 4,
    WStep.tip || WStep.delivery => 5,
    WStep.discount => 6,
    WStep.roundUp => 7,
    WStep.quickCheck || WStep.chargesEdit => 8,
    WStep.result => 0,
  };
  static const totalSteps = 8;
}

/// For the UI: a stable colour for the n-th person avatar.
/// "Pizza 2" → "Pizza" (also with Arabic digits: "بيتزا ٢").
String baseItemName(String name) =>
    name.trim().replaceFirst(RegExp(r'\s+[0-9٠-٩]+$'), '');

/// Two or more items with the same name get numbered in order:
/// Pizza, Pizza → Pizza 1, Pizza 2.
List<BillItem> numberRepeats(List<BillItem> items, {bool arabic = false}) {
  final groups = <String, List<int>>{};
  for (var i = 0; i < items.length; i++) {
    groups.putIfAbsent(baseItemName(items[i].name).toLowerCase(), () => []).add(i);
  }
  final out = [...items];
  for (final idx in groups.values) {
    if (idx.length < 2) continue;
    final base = baseItemName(items[idx.first].name);
    for (var k = 0; k < idx.length; k++) {
      final n = arabic ? toArabicDigits('${k + 1}') : '${k + 1}';
      out[idx[k]] = out[idx[k]].copyWith(name: '$base $n');
    }
  }
  return out;
}

Color personColor(int i) => kPersonColors[i % kPersonColors.length];
