// lib/features/flow/flow_controller.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/models.dart';
import '../../core/services/providers.dart';
import '../../core/services/parser_service.dart';
import '../../core/services/split_calculator.dart';
import '../../core/services/settings_provider.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/strings.dart';
import 'chat_message.dart';

final chatProvider = NotifierProvider<FlowController, List<ChatMessage>>(
  FlowController.new,
);

class FlowController extends Notifier<List<ChatMessage>> {
  static const _uuid = Uuid();

  // People
  int _expectedPeople = 0;
  List<Person> _previousPeople = const []; // kept while re-entering names so IDs survive

  // Item being built
  String _pendingName  = '';
  double _pendingPrice = 0;
  int    _totalItems   = 0;
  int    _currentIndex = 0;

  // Editing
  int    _editingIndex = -1;
  String _editSubStep  = ''; // '', 'name', 'price', 'who'
  bool   _returnToConfirm = false; // set when editing from the final summary

  // Discount
  String _discountMode = ''; // '', 'pct', 'fixed'

  @override
  List<ChatMessage> build() {
    Future.microtask(() async {
      try { await _start(); } catch (_) {}
    });
    return [];
  }

  BillDraftNotifier get _draft      => ref.read(billDraftProvider.notifier);
  BillDraft         get _draftState => ref.read(billDraftProvider);
  FlowStep          get _step       => ref.read(flowStepProvider);
  String            get _curr       => ref.read(currencyProvider);
  S                 get _s          => ref.read(stringsProvider);

  String _fmt(double amount) {
    final s = _s;
    final str = fmtAmount(amount, _curr, arabic: s.isAr);
    return s.isAr ? toArabicDigits(str) : str;
  }

  String _pct(double n) => _s.fmtPct(n);

  void _setStep(FlowStep s) => ref.read(flowStepProvider.notifier).value = s;

  void _addUser(String text) {
    state = [...state, ChatMessage(role: MessageRole.user, text: text)];
  }

  Future<void> _bot(String text, {List<QuickChip>? chips, int ms = 450}) async {
    ref.read(isTypingProvider.notifier).value = true;
    await Future.delayed(Duration(milliseconds: ms));
    ref.read(isTypingProvider.notifier).value = false;
    // A new question makes every older button stale — disable them so an old
    // tap can't jump the flow back to a previous step.
    if (chips != null && chips.isNotEmpty) {
      for (final m in state) {
        for (final c in m.chips ?? const <QuickChip>[]) { c.used = true; }
      }
    }
    state = [...state, ChatMessage(role: MessageRole.bot, text: text, chips: chips)];
  }

  /// Called by the UI when a quick-reply button is tapped.
  void chipTapped(ChatMessage msg, QuickChip chip) {
    if (chip.used) return;
    for (final c in msg.chips ?? const <QuickChip>[]) { c.used = true; }
    _addUser(chip.label);
    chip.onTap();
  }

  String _nameOf(String id) => _draftState.people
      .firstWhere((p) => p.id == id,
          orElse: () => const Person(id: '', name: '?', color: Color(0xFF000000)))
      .name;

  String _whoLabel(BillItem it) {
    final valid = it.personIds.where((id) => _draftState.people.any((p) => p.id == id)).toList();
    if (valid.isEmpty || valid.length == _draftState.people.length) return _s.everyoneLower;
    return valid.map(_nameOf).join(', ');
  }

  Future<void> handleInput(String text) async {
    if (text.trim().isEmpty) return;
    _addUser(text);

    switch (_step) {
      case FlowStep.peopleCount: await _handlePeopleCount(text); break;
      case FlowStep.people:      await _handlePeople(text);      break;
      case FlowStep.itemCount:   await _handleItemCount(text);   break;
      case FlowStep.itemName:    await _handleItemName(text);    break;
      case FlowStep.itemPrice:   await _handleItemPrice(text);   break;
      case FlowStep.itemWho:     await _handleItemWhoText(text); break;
      case FlowStep.itemEdit:    await _handleItemEditStep(text); break;
      case FlowStep.itemSummary:
      case FlowStep.editMenu:
        await _bot(_s.tapAButton, ms: 200);
        break;
      case FlowStep.vat:      await _handleVat(text);      break;
      case FlowStep.service:  await _handleService(text);  break;
      case FlowStep.tip:      await _handleTip(text);      break;
      case FlowStep.discount: await _handleDiscount(text); break;
      case FlowStep.confirm:  await _handleConfirm(text);  break;
      case FlowStep.result:   await _bot(_s.billDone, ms: 200); break;
    }
  }

  // ═══════════════════ STEP 1 — PEOPLE ═════════════════════════════════════

  Future<void> _start() async {
    _setStep(FlowStep.peopleCount);
    final s = _s;
    await _bot('${s.welcome}\n\n${s.howManyPeople}', chips: [
      for (final n in [2, 3, 4, 5, 6])
        QuickChip(label: s.fmtNum(n.toDouble(), decimals: 0), onTap: () => _setPeopleCount(n)),
    ]);
  }

  Future<void> _handlePeopleCount(String text) async {
    final n = parseNumber(text)?.toInt();
    if (n == null || n <= 0 || n > 50) {
      await _bot(_s.pleaseEnterValidNumber, ms: 200);
      return;
    }
    await _setPeopleCount(n);
  }

  Future<void> _setPeopleCount(int n) async {
    _expectedPeople = n;
    _setStep(FlowStep.people);
    await _bot('${_s.peopleCountPrompt(n)}\n${_s.namesExample}', ms: 300);
  }

  Future<void> _handlePeople(String text) async {
    final s = _s;
    final low = text.toLowerCase().trim();

    if (_draftState.people.isNotEmpty) {
      if (const ['yes', 'y', 'ok', 'correct', 'نعم', 'اي', 'ايوه', 'أيوه', 'آه', 'اه', 'تمام', 'ماشي'].contains(low)) {
        await _confirmPeople();
        return;
      }
      if (const ['no', 'n', 're-enter', 'لا', 'لأ'].contains(low)) {
        _draft.setPeople([]);
        await _bot(s.typeNamesAgain, ms: 200);
        return;
      }
    }

    final names = parsePeopleNames(text);
    if (names.isEmpty) {
      await _bot(s.namesNotFound, ms: 300);
      return;
    }

    // Merge with names already entered; de-duplicate case-insensitively.
    final unique = <String>[];
    for (final n in [..._draftState.people.map((p) => p.name), ...names]) {
      if (!unique.any((u) => u.toLowerCase() == n.toLowerCase())) unique.add(n);
    }

    // Re-use the old ID (and colour) for a name that was already on the bill,
    // so item assignments survive "Edit people".
    final known = [..._previousPeople, ..._draftState.people];
    _draft.setPeople([
      for (var i = 0; i < unique.length; i++)
        known.firstWhere(
          (p) => p.name.toLowerCase() == unique[i].toLowerCase(),
          orElse: () => Person(
            id: _uuid.v4(),
            name: unique[i],
            color: kPersonColors[i % kPersonColors.length],
          ),
        ),
    ]);

    var msg = s.gotIt(unique.join(s.isAr ? '، ' : ', '));
    if (_expectedPeople > 0 && unique.length != _expectedPeople) {
      msg += '\n\n${s.countMismatch(_expectedPeople, unique.length)}';
    }
    await _bot('$msg\n\n${s.isCorrect}', chips: [
      QuickChip(label: s.yes, onTap: _confirmPeople),
      QuickChip(label: s.noReenter, onTap: () async {
        _draft.setPeople([]);
        await _bot(s.typeNamesAgain, ms: 200);
      }),
      QuickChip(label: s.addMoreNames, onTap: () => _bot(s.typeMoreNames, ms: 200)),
    ]);
  }

  Future<void> _confirmPeople() async {
    if (_draftState.people.isEmpty) {
      await _bot(_s.typeNamesAgain, ms: 200);
      return;
    }
    // Drop assignments that point at people who are no longer on the bill.
    final ids = _draftState.people.map((p) => p.id).toSet();
    _draft.setItems([
      for (final it in _draftState.items)
        BillItem(id: it.id, name: it.name, price: it.price,
            personIds: it.personIds.where(ids.contains).toList()),
    ]);
    _previousPeople = const [];
    _expectedPeople = 0;

    await _bot(_s.peopleConfirmed, ms: 250);
    if (_returnToConfirm) {
      await _showFinalConfirm();
    } else {
      await _askItemCount();
    }
  }

  // ═══════════════════ STEP 2 — ITEMS ══════════════════════════════════════

  Future<void> _askItemCount({bool more = false}) async {
    _setStep(FlowStep.itemCount);
    await _bot(more ? _s.howManyMoreItems : '${_s.howManyItems}\n\n${_s.scanTip}', ms: 300);
  }

  Future<void> _handleItemCount(String text) async {
    final n = parseNumber(text.trim())?.toInt();
    if (n == null || n <= 0 || n > 100) {
      await _bot(_s.pleaseEnterValidNumber, ms: 200);
      return;
    }
    _currentIndex = _draftState.items.length;
    _totalItems   = _currentIndex + n;
    await _askItemName();
  }

  Future<void> _askItemName() async {
    _setStep(FlowStep.itemName);
    await _bot(_s.itemNamePrompt(_currentIndex + 1, _totalItems), ms: 300);
  }

  bool _nameTaken(String name, {int exceptIndex = -1}) {
    final items = _draftState.items;
    for (var i = 0; i < items.length; i++) {
      if (i != exceptIndex && items[i].name.toLowerCase() == name.toLowerCase()) return true;
    }
    return false;
  }

  Future<void> _handleItemName(String text) async {
    final name = text.trim();
    if (_nameTaken(name)) {
      await _bot(_s.itemExists(name), ms: 300);
      return;
    }
    _pendingName = name;
    _setStep(FlowStep.itemPrice);
    await _bot(_s.itemPricePrompt(name), ms: 300);
  }

  Future<void> _handleItemPrice(String text) async {
    final price = parseNumber(text.trim());
    if (price == null || price <= 0) {
      await _bot(_s.pleaseEnterValidNumber, ms: 200);
      return;
    }
    _pendingPrice = price;
    _editSubStep = '';
    _setStep(FlowStep.itemWho);
    await _bot(_s.itemWhoPrompt(_pendingName, _fmt(price)), ms: 300);
  }

  /// Typed answer to "who had it?" (the picker sheet calls [confirmSelectedPeople]).
  Future<void> _handleItemWhoText(String text) async {
    final s = _s;
    final people = _draftState.people;
    final low = text.toLowerCase().trim();

    const everyone = ['everyone', 'all', 'shared', 'everybody', 'الكل', 'الجميع', 'كل', 'مُقسمة', 'مقسمة'];
    if (everyone.contains(low)) {
      await confirmSelectedPeople(people.map((p) => p.id).toList());
      return;
    }

    Person? match(String token) {
      final t = token.toLowerCase();
      for (final p in people) { if (p.name.toLowerCase() == t) return p; }
      final starts = people.where((p) => p.name.toLowerCase().startsWith(t)).toList();
      return starts.length == 1 ? starts.first : null; // only an unambiguous prefix
    }

    // Split on explicit separators first, so two-word names keep working.
    final tokens = text
        .split(RegExp(r',|،|\band\b|\s+و\s*|&|\+', caseSensitive: false))
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty);

    final matched = <String>[];
    final unmatched = <String>[];
    for (final token in tokens) {
      final whole = match(token);
      if (whole != null) {
        if (!matched.contains(whole.id)) matched.add(whole.id);
        continue;
      }
      // "Ahmed Sara" without commas → try word by word.
      for (final word in token.split(RegExp(r'\s+'))) {
        final p = match(word);
        if (p == null) {
          unmatched.add(word);
        } else if (!matched.contains(p.id)) {
          matched.add(p.id);
        }
      }
    }

    if (unmatched.isNotEmpty) {
      await _bot(s.namesNotOnBill(unmatched.join(', '), people.map((p) => p.name).join(', ')), ms: 300);
      return;
    }
    await confirmSelectedPeople(matched);
  }

  /// Who should already be ticked when the picker opens (when editing an item).
  List<String> get preselectedIds {
    if (_editSubStep != 'who' || _editingIndex < 0 || _editingIndex >= _draftState.items.length) {
      return const [];
    }
    final ids = _draftState.items[_editingIndex].personIds;
    return ids.isEmpty ? _draftState.people.map((p) => p.id).toList() : ids;
  }

  Future<void> confirmSelectedPeople(List<String> personIds) async {
    if (personIds.isEmpty) {
      await _bot(_s.selectAtLeastOne, ms: 200);
      return;
    }
    if (_editSubStep == 'who' && _editingIndex >= 0) {
      await _updateItemWho(personIds);
    } else {
      await _addPendingItem(personIds);
    }
  }

  Future<void> _addPendingItem(List<String> personIds) async {
    // Everyone selected → store as shared (empty list) so it stays correct if people change.
    final ids = personIds.length == _draftState.people.length ? <String>[] : personIds;
    final item = BillItem(id: _uuid.v4(), name: _pendingName, price: _pendingPrice, personIds: ids);
    _draft.addItem(item);

    await _bot(_s.itemConfirmed(item.name, _fmt(item.price), _whoLabel(item)), ms: 200);

    _currentIndex++;
    _pendingName = '';
    _pendingPrice = 0;

    if (_currentIndex < _totalItems) {
      await _askItemName();
    } else {
      await _showItemSummary();
    }
  }

  // ═══════════════════ ITEM SUMMARY & EDITING ══════════════════════════════

  Future<void> _showItemSummary() async {
    final s = _s;
    final items = _draftState.items;
    if (items.isEmpty) {
      await _bot(s.noItemsYet, ms: 200);
      await _askItemCount();
      return;
    }
    _setStep(FlowStep.itemSummary);
    _editSubStep = '';
    _editingIndex = -1;
    final subtotal = items.fold(0.0, (sum, i) => sum + i.price);
    final list = items.asMap().entries
        .map((e) => '${e.key + 1}. ${e.value.name} · ${_fmt(e.value.price)} → ${_whoLabel(e.value)}')
        .join('\n');

    await _bot('${s.allItemsAdded(_fmt(subtotal))}\n\n$list', chips: [
      QuickChip(label: s.looksGood, onTap: () async {
        if (_returnToConfirm) { await _showFinalConfirm(); } else { await _askVat(); }
      }),
      QuickChip(label: s.addMoreItemsBtn, onTap: () => _askItemCount(more: true)),
      QuickChip(label: s.editExistingItem, onTap: _showItemEditList),
    ], ms: 300);
  }

  Future<void> _showItemEditList() async {
    _setStep(FlowStep.itemEdit);
    _editSubStep = '';
    final items = _draftState.items;
    await _bot(_s.whichItemToEdit, chips: [
      for (var i = 0; i < items.length; i++)
        QuickChip(label: '${items[i].name} · ${_fmt(items[i].price)}', onTap: () => _showItemEditOptions(i)),
      QuickChip(label: _s.back, onTap: _showItemSummary),
    ], ms: 200);
  }

  Future<void> _showItemEditOptions(int index) async {
    _editingIndex = index;
    final item = _draftState.items[index];
    final s = _s;
    await _bot(s.whatToChangeInItem(item.name), chips: [
      QuickChip(label: s.editName, onTap: () async {
        _editSubStep = 'name';
        _setStep(FlowStep.itemEdit);
        await _bot(s.enterNewName, ms: 200);
      }),
      QuickChip(label: s.editPrice, onTap: () async {
        _editSubStep = 'price';
        _setStep(FlowStep.itemEdit);
        await _bot(s.enterNewPrice, ms: 200);
      }),
      QuickChip(label: s.editWhoOrdered, onTap: () async {
        _editSubStep = 'who';
        await _bot(s.itemWhoPrompt(item.name, _fmt(item.price)), ms: 200);
        _setStep(FlowStep.itemWho);
      }),
      QuickChip(label: s.deleteItem, onTap: () async {
        final items = List<BillItem>.from(_draftState.items)..removeAt(index);
        _draft.setItems(items);
        await _bot(s.itemRemoved(item.name), ms: 200);
        await _showItemSummary();
      }),
    ], ms: 200);
  }

  void _replaceItem(BillItem Function(BillItem old) change) {
    final items = List<BillItem>.from(_draftState.items);
    items[_editingIndex] = change(items[_editingIndex]);
    _draft.setItems(items);
  }

  Future<void> _handleItemEditStep(String text) async {
    if (_editingIndex < 0 || _editingIndex >= _draftState.items.length || _editSubStep.isEmpty) {
      await _bot(_s.tapAButton, ms: 200);
      return;
    }
    final item = _draftState.items[_editingIndex];

    if (_editSubStep == 'name') {
      final name = text.trim();
      if (_nameTaken(name, exceptIndex: _editingIndex)) {
        await _bot(_s.itemExists(name), ms: 300);
        return;
      }
      _replaceItem((o) => BillItem(id: o.id, name: name, price: o.price, personIds: o.personIds));
      await _bot(_s.itemUpdated(name), ms: 200);
      await _showItemSummary();
    } else if (_editSubStep == 'price') {
      final price = parseNumber(text.trim());
      if (price == null || price <= 0) {
        await _bot(_s.pleaseEnterValidNumber, ms: 200);
        return;
      }
      _replaceItem((o) => BillItem(id: o.id, name: o.name, price: price, personIds: o.personIds));
      await _bot(_s.itemUpdated(item.name), ms: 200);
      await _showItemSummary();
    }
  }

  Future<void> _updateItemWho(List<String> personIds) async {
    final ids = personIds.length == _draftState.people.length ? <String>[] : personIds;
    final name = _draftState.items[_editingIndex].name;
    _replaceItem((o) => BillItem(id: o.id, name: o.name, price: o.price, personIds: ids));
    await _bot(_s.itemUpdated(name), ms: 200);
    await _showItemSummary();
  }

  // ═══════════════════ OCR ═════════════════════════════════════════════════

  Future<void> handleOcrFile(File file) async {
    final s = _s;
    _addUser(s.scanning);
    ref.read(isTypingProvider.notifier).value = true;
    try {
      final result = await ref.read(ocrServiceProvider).scanReceipt(file);
      ref.read(isTypingProvider.notifier).value = false;
      if (result.items.isEmpty) {
        await _bot(result.isArabic ? s.arabicReceiptDetected : s.cantReadReceipt, ms: 300);
        if (_step != FlowStep.itemCount) await _askItemCount();
        return;
      }
      for (final item in result.items) {
        final name = _nameTaken(item.name) ? '${item.name} (2)' : item.name;
        _draft.addItem(BillItem(id: _uuid.v4(), name: name, price: item.price));
      }
      _currentIndex = _draftState.items.length;
      _totalItems   = _currentIndex;
      await _bot(s.scannedItems(result.items.length), ms: 300);
      await _showItemSummary();
    } catch (_) {
      ref.read(isTypingProvider.notifier).value = false;
      await _bot(s.cantScanReceipt, ms: 300);
    }
  }

  // ═══════════════════ VAT / SERVICE / TIP ═════════════════════════════════

  List<QuickChip> _pctChips(List<double> options, String noneLabel, Future<void> Function(double) apply, String customPrompt) => [
    QuickChip(label: noneLabel, onTap: () => apply(0)),
    for (final n in options) QuickChip(label: _pct(n), onTap: () => apply(n)),
    QuickChip(label: _s.custom, onTap: () => _bot(customPrompt, ms: 200)),
  ];

  Future<double?> _readPct(String text) async {
    final n = parseNumber(text);
    if (n == null || n < 0 || n > 100) {
      await _bot(_s.typeValidPct, ms: 200);
      return null;
    }
    return n;
  }

  Future<void> _askVat() async {
    _setStep(FlowStep.vat);
    final s = _s;
    await _bot(s.vatQuestion, chips: _pctChips([5, 10, 14, 15], s.noVatChip, _applyVat, s.typeVat));
  }

  Future<void> _handleVat(String text) async {
    final n = await _readPct(text);
    if (n != null) await _applyVat(n);
  }

  Future<void> _applyVat(double n) async {
    _draft.setExtras(_draftState.extras.copyWith(vatPct: n));
    await _bot(n == 0 ? _s.noVat : _s.vatApplied(_pct(n)), ms: 250);
    if (_returnToConfirm) { await _showFinalConfirm(); } else { await _askService(); }
  }

  Future<void> _askService() async {
    _setStep(FlowStep.service);
    final s = _s;
    await _bot(s.serviceQuestion, chips: _pctChips([5, 10, 12, 15], s.noServiceChip, _applyService, s.typeService));
  }

  Future<void> _handleService(String text) async {
    final n = await _readPct(text);
    if (n != null) await _applyService(n);
  }

  Future<void> _applyService(double n) async {
    _draft.setExtras(_draftState.extras.copyWith(servicePct: n));
    await _bot(n == 0 ? _s.noService : _s.serviceApplied(_pct(n)), ms: 250);
    if (_returnToConfirm) { await _showFinalConfirm(); } else { await _askTip(); }
  }

  Future<void> _askTip() async {
    _setStep(FlowStep.tip);
    final s = _s;
    await _bot(s.tipQuestion, chips: _pctChips([5, 10, 15, 20], s.noTipChip, _applyTip, s.typeTip));
  }

  Future<void> _handleTip(String text) async {
    final n = await _readPct(text);
    if (n != null) await _applyTip(n);
  }

  Future<void> _applyTip(double n) async {
    _draft.setExtras(_draftState.extras.copyWith(tipPct: n));
    await _bot(n == 0 ? _s.noTip : _s.tipApplied(_pct(n)), ms: 250);
    if (_returnToConfirm) { await _showFinalConfirm(); } else { await _askDiscount(); }
  }

  // ═══════════════════ DISCOUNT ════════════════════════════════════════════

  Future<void> _askDiscount() async {
    _setStep(FlowStep.discount);
    _discountMode = '';
    final s = _s;
    await _bot(s.discountQuestion, chips: [
      QuickChip(label: s.noDiscount, onTap: () => _applyDiscount(pct: 0, fixed: 0)),
      QuickChip(label: s.percentDiscount, onTap: () async {
        _discountMode = 'pct';
        await _bot(s.enterDiscountPct, ms: 200);
      }),
      QuickChip(label: s.fixedDiscount, onTap: () async {
        _discountMode = 'fixed';
        await _bot(s.enterDiscountFixed, ms: 200);
      }),
    ], ms: 300);
  }

  Future<void> _handleDiscount(String text) async {
    final s = _s;
    final low = text.toLowerCase().trim();
    if (const ['no', 'none', 'nope', 'لا', 'لأ', 'بدون', 'مفيش', 'من غير'].contains(low)) {
      await _applyDiscount(pct: 0, fixed: 0);
      return;
    }

    final n = parseNumber(text);
    if (n == null || n < 0) {
      await _bot(s.pleaseEnterValidNumber, ms: 200);
      return;
    }

    var mode = _discountMode;
    if (mode.isEmpty && text.contains('%')) mode = 'pct';
    if (mode.isEmpty) {
      // Ambiguous ("20") — let the user say which they meant.
      await _bot(s.discountWhichKind, chips: [
        if (n <= 100) QuickChip(label: s.discountPctOption(_pct(n)), onTap: () => _applyDiscount(pct: n, fixed: 0)),
        QuickChip(label: s.discountFixedOption(_fmt(n)), onTap: () => _applyDiscount(pct: 0, fixed: n)),
      ], ms: 200);
      return;
    }

    if (mode == 'pct') {
      if (n > 100) { await _bot(s.typeValidPct, ms: 200); return; }
      await _applyDiscount(pct: n, fixed: 0);
    } else {
      await _applyDiscount(pct: 0, fixed: n);
    }
  }

  Future<void> _applyDiscount({required double pct, required double fixed}) async {
    final s = _s;
    _draft.setExtras(_draftState.extras.copyWith(discountPct: pct, discountFixed: fixed));
    _discountMode = '';
    final sub = _draftState.items.fold(0.0, (a, i) => a + i.price);
    if (pct > 0) {
      await _bot(s.discountPctApplied(_pct(pct)), ms: 250);
    } else if (fixed > 0) {
      final applied = _draftState.extras.discountAmount(sub);
      await _bot(fixed > sub ? s.discountCapped(_fmt(applied)) : s.discountFixedApplied(_fmt(fixed)), ms: 250);
    } else {
      await _bot(s.noDiscountApplied, ms: 250);
    }
    await _showFinalConfirm();
  }

  // ═══════════════════ FINAL CONFIRM ═══════════════════════════════════════

  Future<void> _showFinalConfirm() async {
    _returnToConfirm = false;
    _setStep(FlowStep.confirm);
    final s = _s;
    final sub  = _draftState.items.fold(0.0, (sum, i) => sum + i.price);
    final ext  = _draftState.extras;
    final lines = [
      '👥 ${_draftState.people.map((p) => p.name).join(', ')}',
      '🧾 ${s.itemsCount(_draftState.items.length)}',
      '',
      '${s.subtotalLabel}: ${_fmt(sub)}',
      if (ext.hasDiscount) '${s.discountLabel}: −${_fmt(ext.discountAmount(sub))}',
      if (ext.vatPct > 0)     '${s.vatLabel} ${_pct(ext.vatPct)}: ${_fmt(ext.vatAmount(sub))}',
      if (ext.servicePct > 0) '${s.serviceLabel} ${_pct(ext.servicePct)}: ${_fmt(ext.serviceAmount(sub))}',
      if (ext.tipPct > 0)     '${s.tipLabel} ${_pct(ext.tipPct)}: ${_fmt(ext.tipAmount(sub))}',
      '',
      '${s.grandTotal}: ${_fmt(ext.grandTotal(sub))}',
    ].join('\n');
    await _bot('${s.finalConfirmTitle}\n\n$lines', chips: [
      QuickChip(label: s.calculate, onTap: () async => _calcAndShow()),
      QuickChip(label: s.editBtn, onTap: _showEditMenu),
    ]);
  }

  Future<void> _handleConfirm(String text) async {
    final low = text.toLowerCase().trim();
    final no  = RegExp(r'\b(no|edit|change|wait)\b').hasMatch(low) || low.contains('لا') || low.contains('لأ') || low.contains('تعديل') || low.contains('عدّل') || low.contains('عدل');
    final yes = RegExp(r'\b(yes|ok|okay|go|calculate|split|good|yep|sure)\b').hasMatch(low) ||
        low.contains('نعم') || low.contains('احسب') || low.contains('تمام') || low.contains('أيوه') || low.contains('ايوه') || low.contains('قسّمها') || low.contains('ماشي');
    if (no) {
      await _showEditMenu();
    } else if (yes) {
      _calcAndShow();
    } else {
      await _bot(_s.tapCalculate, ms: 200);
    }
  }

  Future<void> _showEditMenu() async {
    _setStep(FlowStep.editMenu);
    _returnToConfirm = true;
    final s = _s;
    await _bot(s.whatToEdit, chips: [
      QuickChip(label: s.editPeople, onTap: () async {
        _previousPeople = _draftState.people;
        _expectedPeople = 0;
        _draft.setPeople([]);
        _setStep(FlowStep.people);
        await _bot(s.reenterPeople(_previousPeople.map((p) => p.name).join(', ')), ms: 200);
      }),
      QuickChip(label: s.editItems, onTap: _showItemEditList),
      QuickChip(label: s.editNumberOfItems, onTap: () async {
        _draft.clearItems();
        await _askItemCount(); // after the new items, "Looks good" returns here

      }),
      QuickChip(label: s.vatLabel, onTap: _askVat),
      QuickChip(label: s.serviceLabel, onTap: _askService),
      QuickChip(label: s.tipLabel, onTap: _askTip),
      QuickChip(label: s.discountLabel, onTap: _askDiscount),
      QuickChip(label: s.back, onTap: _showFinalConfirm),
    ], ms: 200);
  }

  // ═══════════════════ RESULT ══════════════════════════════════════════════

  void _calcAndShow() {
    _setStep(FlowStep.result);
    final bill   = _draftState.toBill(_curr);
    final result = SplitCalculator.calculate(bill);
    ref.read(splitResultProvider.notifier).value = result;
    ref.read(finalBillProvider.notifier).value   = bill;
    _bot(_s.finalSplit, ms: 400);
    _saveToHistory(bill);
  }

  Future<void> _saveToHistory(Bill bill) async {
    try {
      final svc = ref.read(historyServiceProvider);
      await svc.init();
      await svc.save(bill);
    } catch (_) {/* history is best-effort */}
  }

  Future<void> reset() async {
    _expectedPeople = 0;
    _previousPeople = const [];
    _pendingName    = '';
    _pendingPrice   = 0;
    _totalItems     = 0;
    _currentIndex   = 0;
    _editingIndex   = -1;
    _editSubStep    = '';
    _returnToConfirm = false;
    _discountMode   = '';
    _draft.reset();
    ref.read(isTypingProvider.notifier).value = false;
    ref.read(splitResultProvider.notifier).value = null;
    ref.read(finalBillProvider.notifier).value   = null;
    state = [];
    await _start();
  }
}
