// lib/features/flow/flow_controller.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/models.dart';
import '../../core/services/providers.dart';
import '../../core/services/parser_service.dart';
import '../../core/services/edit_parser.dart';
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

  // Item being built
  String _pendingItemName  = '';
  String _pendingItemPrice = '';
  int    _totalItems       = 0;
  int    _currentItemIndex = 0;

  // Edit state
  int    _editingItemIndex = -1;
  String _editSubStep      = ''; // 'name', 'price', 'who'
  bool   _editingFromMenu  = false; // when true, go back to confirm after edit

  @override
  List<ChatMessage> build() {
    Future.microtask(() async {
      try { await _start(); } catch (e) {}
    });
    return [];
  }

  BillDraftNotifier get _draft      => ref.read(billDraftProvider.notifier);
  BillDraft         get _draftState => ref.read(billDraftProvider);
  FlowStep          get _step       => ref.read(flowStepProvider);
  String            get _curr       => ref.read(currencyProvider);
  S                 get _s          => ref.read(stringsProvider);

  void _setStep(FlowStep s) => ref.read(flowStepProvider.notifier).value = s;

  void _addUser(String text) {
    state = [...state, ChatMessage(role: MessageRole.user, text: text)];
  }

  Future<void> _bot(String text, {List<QuickChip>? chips, Widget? widget, int ms = 500}) async {
    ref.read(isTypingProvider.notifier).value = true;
    await Future.delayed(Duration(milliseconds: ms));
    ref.read(isTypingProvider.notifier).value = false;
    state = [...state, ChatMessage(role: MessageRole.bot, text: text, chips: chips, inlineWidget: widget)];
  }

  Future<void> handleInput(String text) async {
    if (text.trim().isEmpty) return;
    _addUser(text);

    switch (_step) {
      case FlowStep.people:     _handlePeople(text);    break;
      case FlowStep.itemCount:  _handleItemCount(text); break;
      case FlowStep.itemName:   _handleItemName(text);  break;
      case FlowStep.itemPrice:  _handleItemPrice(text); break;
      case FlowStep.itemWho:    _handleItemWhoText(text); break;
      case FlowStep.itemSummary: break; // handled by chips
      case FlowStep.itemEdit:   _handleItemEditStep(text); break;
      case FlowStep.editMenu:   break; // handled by chips
      case FlowStep.vat:        _handleVat(text, requireConfirm: true); break;
      case FlowStep.service:    _handleService(text, requireConfirm: true); break;
      case FlowStep.tip:        _handleTip(text, requireConfirm: true); break;
      case FlowStep.confirm:    _handleConfirm(text); break;
      case FlowStep.result:
        _bot(_s.billDone, ms: 200);
        break;
    }
  }

  // ═══════════════════ STEP 1 — PEOPLE ═════════════════════════════════════

  Future<void> _start() async {
    _setStep(FlowStep.people);
    final s = _s;
    await _bot(
      '${s.welcome}\n\n${s.step1Question}\n\n${s.typeOrSayNames}\n${s.namesExample}',
    );
  }

  Future<void> _handlePeople(String text) async {
    final s = _s;
    final low = text.toLowerCase().trim();

    if (_draftState.people.isNotEmpty) {
      if (low == 'yes' || low == 'y' || low == 'نعم' || low == 'ok' || low == 'correct') {
        _confirmPeople();
        return;
      }
      if (low == 'no' || low == 'n' || low == 'لا' || low == 're-enter' || low == 'edit') {
        await _bot(s.typeNamesAgain, ms: 200);
        _draft.setPeople([]);
        return;
      }
    }

    final names = parsePeopleNames(text);
    if (names.isEmpty) {
      await _bot(s.namesNotFound, ms: 300);
      return;
    }

    // Add to existing people if any
    final existing = _draftState.people;
    final allNames = [...existing.map((p) => p.name), ...names];
    final uniqueNames = allNames.toSet().toList();

    _draft.setPeople(uniqueNames.asMap().entries.map((e) => Person(
      id: _uuid.v4(),
      name: e.value,
      color: kPersonColors[e.key % kPersonColors.length],
    )).toList());

    await _bot('${s.gotIt(uniqueNames.join(', '))}\n\n${s.isCorrect}', chips: [
      QuickChip(label: s.yes, onTap: () => _confirmPeople()),
      QuickChip(label: s.noReenter, onTap: () async {
        _draft.setPeople([]);
        await _bot(s.typeNamesAgain, ms: 200);
      }),
      QuickChip(label: s.addMoreNames, onTap: () async {
        await _bot(s.typeNamesAgain, ms: 200);
      }),
    ]);
  }

  Future<void> _confirmPeople() async {
    await _bot(_s.peopleConfirmed, ms: 250);
    _askItemCount();
  }

  // ═══════════════════ STEP 2 — ITEM COUNT ══════════════════════════════════

  Future<void> _askItemCount() async {
    _setStep(FlowStep.itemCount);
    await _bot(_s.howManyItems, ms: 300);
  }

  Future<void> _handleItemCount(String text) async {
    final s = _s;
    final n = int.tryParse(text.trim());
    if (n == null || n <= 0) {
      await _bot(s.pleaseEnterValidNumber, ms: 200);
      return;
    }
    _totalItems = _currentItemIndex + n;
    _askItemName();
  }

  // ═══════════════════ STEP 3 — ITEMS ONE BY ONE ═══════════════════════════

  Future<void> _askItemName() async {
    _setStep(FlowStep.itemName);
    await _bot(_s.itemNamePrompt(_currentItemIndex + 1, _totalItems), ms: 300);
  }

  Future<void> _handleItemName(String text) async {
    final name = text.trim();
    // Check for duplicate item name
    final existing = _draftState.items.map((i) => i.name.toLowerCase()).toList();
    if (existing.contains(name.toLowerCase())) {
      await _bot('"$name" already exists. Please enter a different item name.', ms: 300);
      return;
    }
    _pendingItemName = name;
    _setStep(FlowStep.itemPrice);
    await _bot(_s.itemPricePrompt(_pendingItemName), ms: 300);
  }

  Future<void> _handleItemPrice(String text) async {
    final s = _s;
    final price = double.tryParse(text.trim().replaceAll(',', '.'));
    if (price == null || price <= 0) {
      await _bot(s.pleaseEnterValidNumber, ms: 200);
      return;
    }
    _pendingItemPrice = fmtAmount(price, _curr);
    _setStep(FlowStep.itemWho);

    await _bot(
      _s.itemWhoPrompt(_pendingItemName, _pendingItemPrice),
      ms: 300,
    );
  }

  Future<void> _handleItemWhoText(String text) async {
    final s = _s;
    final low = text.toLowerCase().trim();

    // Check for "everyone" keywords
    final sharedKeywords = ['everyone', 'all', 'shared', 'الكل', 'الجميع', 'كل', 'مُقسمة'];
    if (sharedKeywords.contains(low)) {
      await confirmSelectedPeople(_draftState.people.map((p) => p.id).toList());
      return;
    }

    // Try to match names
    final names = text.split(RegExp(r',|،|\band\b|\bو\b|&|\+|\s+', caseSensitive: false))
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    final matchedIds = <String>[];
    final unmatched = <String>[];

    for (final name in names) {
      final match = _draftState.people.firstWhere(
        (p) => p.name.toLowerCase() == name.toLowerCase() ||
               p.name.toLowerCase().contains(name.toLowerCase()),
        orElse: () => const Person(id: '', name: '', color: Color(0xFF000000)),
      );
      if (match.id.isNotEmpty) {
        if (!matchedIds.contains(match.id)) matchedIds.add(match.id);
      } else {
        unmatched.add(name);
      }
    }

    if (unmatched.isNotEmpty) {
      final validNames = _draftState.people.map((p) => p.name).join(', ');
      await _bot(
        '❌ "${unmatched.join(', ')}" not found in the list.\n\nValid names: $validNames\n\nPlease try again or select from the popup.',
        ms: 300,
      );
      return;
    }

    if (matchedIds.isEmpty) {
      await _bot('Please select at least one person or type a valid name.', ms: 300);
      return;
    }

    await confirmSelectedPeople(matchedIds);
  }

  // Name selection is handled via widget in chat_screen
  // But we also need chip-based selection here
  final List<String> _selectedPersonIds = [];

  void _selectPersonForItem(String personId) {
    if (_selectedPersonIds.contains(personId)) {
      _selectedPersonIds.remove(personId);
    } else {
      _selectedPersonIds.add(personId);
    }
  }

  Future<void> _selectEveryoneForItem() async {
    final personIds = _draftState.people.map((p) => p.id).toList();
    _confirmWhoOrdered(personIds);
  }

  Future<void> confirmSelectedPeople(List<String> personIds) async {
    if (personIds.isEmpty) {
      await _bot(_s.selectAtLeastOne, ms: 200);
      return;
    }
    _confirmWhoOrdered(personIds);
  }

  Future<void> _confirmWhoOrdered(List<String> personIds) async {
    final price = double.tryParse(
      _pendingItemPrice.replaceAll('\$', '').trim()
    ) ?? 0.0;

    _draft.addItem(BillItem(
      id: _uuid.v4(),
      name: _pendingItemName,
      price: price,
      personIds: personIds,
    ));

    final who = personIds.isEmpty
        ? _s.shared
        : personIds.map((id) =>
            _draftState.people.firstWhere((p) => p.id == id,
              orElse: () => const Person(id: '', name: '?', color: Color(0xFF000000))).name
          ).join(', ');

    await _bot(
      _s.itemConfirmed(_pendingItemName, _pendingItemPrice, who),
      ms: 200,
    );

    _currentItemIndex++;
    _pendingItemName  = '';
    _pendingItemPrice = '';

    if (_currentItemIndex < _totalItems) {
      _askItemName();
    } else {
      _showItemSummary();
    }
  }

  // ═══════════════════ ITEM SUMMARY ════════════════════════════════════════

  Future<void> _showItemSummary() async {
    _setStep(FlowStep.itemSummary);
    final s = _s;
    final subtotal = _draftState.items.fold(0.0, (sum, i) => sum + i.price);

    final itemList = _draftState.items.asMap().entries.map((e) {
      final it = e.value;
      final who = it.personIds.isEmpty
          ? s.shared
          : it.personIds.map((id) =>
              _draftState.people.firstWhere((p) => p.id == id,
                orElse: () => const Person(id: '', name: '?', color: Color(0xFF000000))).name
            ).join(', ');
      return '${e.key + 1}. ${it.name}  ${fmtAmount(it.price, _curr)}  → $who';
    }).join('\n');

    await _bot(
      '${s.allItemsAdded(fmtAmount(subtotal, _curr))}\n\n$itemList',
      chips: [
        QuickChip(label: s.looksGood, onTap: () {
          _addUser(s.looksGood);
          _askVat();
        }),
        QuickChip(label: s.addMoreItemsBtn, onTap: () async {
          await _bot(s.howManyMoreItems, ms: 200);
          _setStep(FlowStep.itemCount);
        }),
        QuickChip(label: s.editExistingItem, onTap: () => _showItemEditList()),
      ],
      ms: 300,
    );
  }

  // ═══════════════════ ITEM EDIT ════════════════════════════════════════════

  Future<void> _showItemEditList() async {
    _setStep(FlowStep.itemEdit);
    final items = _draftState.items;
    await _bot(
      _s.whichItemToEdit,
      chips: items.asMap().entries.map((e) =>
        QuickChip(
          label: '${e.key + 1}. ${e.value.name} ${fmtAmount(e.value.price, _curr)}',
          onTap: () => _showItemEditOptions(e.key),
        )
      ).toList(),
      ms: 200,
    );
  }

  Future<void> _showItemEditOptions(int index) async {
    _editingItemIndex = index;
    final item = _draftState.items[index];
    final s = _s;
    await _bot(
      '${s.whatToChangeInItem}: ${item.name} ${fmtAmount(item.price, _curr)}',
      chips: [
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
          _setStep(FlowStep.itemWho);
          await _bot(
            _s.itemWhoPrompt(item.name, fmtAmount(item.price, _curr)),
            ms: 200,
          );
        }),
        QuickChip(label: s.deleteItem, onTap: () async {
          final items = List<BillItem>.from(_draftState.items);
          final name = items[_editingItemIndex].name;
          items.removeAt(_editingItemIndex);
          ref.read(billDraftProvider.notifier).state = _draftState.copyWith(items: items);
          await _bot(_s.itemRemoved(name), ms: 200);
          _showItemSummary();
        }),
      ],
      ms: 200,
    );
  }

  Future<void> _handleItemEditStep(String text) async {
    final items = List<BillItem>.from(_draftState.items);
    final item = items[_editingItemIndex];

    if (_editSubStep == 'name') {
      items[_editingItemIndex] = BillItem(
        id: item.id, name: text.trim(),
        price: item.price, personIds: item.personIds,
      );
      ref.read(billDraftProvider.notifier).state = _draftState.copyWith(items: items);
      await _bot(_s.itemUpdated(text.trim()), ms: 200);
      _showItemSummary();
    } else if (_editSubStep == 'price') {
      final price = double.tryParse(text.trim().replaceAll(',', '.'));
      if (price == null || price <= 0) {
        await _bot(_s.pleaseEnterValidNumber, ms: 200);
        return;
      }
      items[_editingItemIndex] = BillItem(
        id: item.id, name: item.name,
        price: price, personIds: item.personIds,
      );
      ref.read(billDraftProvider.notifier).state = _draftState.copyWith(items: items);
      await _bot(_s.itemUpdated(item.name), ms: 200);
      _showItemSummary();
    }
  }

  Future<void> _updateItemWho(List<String> personIds) async {
    final items = List<BillItem>.from(_draftState.items);
    final item = items[_editingItemIndex];
    items[_editingItemIndex] = BillItem(
      id: item.id, name: item.name,
      price: item.price, personIds: personIds,
    );
    ref.read(billDraftProvider.notifier).state = _draftState.copyWith(items: items);
    await _bot(_s.itemUpdated(item.name), ms: 200);
    _showItemSummary();
  }

  // ═══════════════════ EDIT MENU (from final confirm) ═══════════════════════

  Future<void> _showEditMenu() async {
    _setStep(FlowStep.editMenu);
    final s = _s;
    await _bot(
      s.whatToEdit,
      chips: [
        QuickChip(label: s.editPeople, onTap: () async {
          _draft.setPeople([]);
          await _start();
        }),
        QuickChip(label: s.editNumberOfItems, onTap: () {
          _draft.clearItems();
          _askItemCount();
        }),
        QuickChip(label: s.editItems, onTap: () => _showItemEditList()),
        QuickChip(label: s.editVat, onTap: () {
          _editingFromMenu = true;
          _draft.setExtras(_draftState.extras.copyWith(vatPct: 0));
          _askVat();
        }),
        QuickChip(label: s.editService, onTap: () {
          _editingFromMenu = true;
          _draft.setExtras(_draftState.extras.copyWith(servicePct: 0));
          _askService();
        }),
        QuickChip(label: s.editTip, onTap: () {
          _editingFromMenu = true;
          _draft.setExtras(_draftState.extras.copyWith(tipPct: 0));
          _askTip();
        }),
      ],
      ms: 200,
    );
  }

  // ═══════════════════ OCR ═════════════════════════════════════════════════

  Future<void> handleOcrFile(File file) async {
    final s = _s;
    _addUser(s.scanning);
    ref.read(isTypingProvider.notifier).value = true;
    try {
      final ocr = ref.read(ocrServiceProvider);
      final result = await ocr.scanReceipt(file, knownPeople: _draftState.people);
      ref.read(isTypingProvider.notifier).value = false;
      if (result.isArabic && result.items.isEmpty) {
        await _bot(s.arabicReceiptDetected, ms: 300,
          chips: [QuickChip(label: s.addItemsManually, onTap: () async => _bot(s.whatElse, ms: 200))]);
        return;
      }
      if (result.items.isEmpty) {
        await _bot(s.cantReadReceipt, ms: 300);
        return;
      }
      for (final item in result.items) {
        _draft.addItem(BillItem(id: _uuid.v4(), name: item.name, price: item.price, personIds: const []));
      }
      final total = _draftState.items.fold(0.0, (sum, i) => sum + i.price);
      final preview = result.items.take(5).map((i) => '  ${i.name}  ${fmtAmount(i.price, _curr)}').join('\n');
      final more = result.items.length > 5 ? '\n  +${result.items.length - 5} more' : '';
      await _bot(
        '${s.scannedItems(result.items.length)}\n$preview$more\n\nTotal: ${fmtAmount(total, _curr)}\n\n${s.whoOrderedWhat}',
        chips: [
          QuickChip(label: s.addMoreItems, onTap: () async => _bot(s.whatElse, ms: 200)),
          QuickChip(label: s.splitEqually, onTap: () { _addUser(s.splitEqually); _showItemSummary(); }),
        ],
      );
    } catch (e) {
      ref.read(isTypingProvider.notifier).value = false;
      await _bot(_s.cantScanReceipt, ms: 300);
    }
  }

  // ═══════════════════ STEP VAT ════════════════════════════════════════════

  Future<void> _askVat() async {
    _setStep(FlowStep.vat);
    final s = _s;
    await _bot(
      '${s.step3Title}\n\n${s.quickOptionOrCustom}',
      chips: [
        QuickChip(label: s.noVatChip, onTap: () { _addUser(s.noVatChip); _applyVat(0); }),
        QuickChip(label: '5%',  onTap: () { _addUser('5%');  _applyVat(5);  }),
        QuickChip(label: '10%', onTap: () { _addUser('10%'); _applyVat(10); }),
        QuickChip(label: '14%', onTap: () { _addUser('14%'); _applyVat(14); }),
        QuickChip(label: '15%', onTap: () { _addUser('15%'); _applyVat(15); }),
        QuickChip(label: '20%', onTap: () { _addUser('20%'); _applyVat(20); }),
        QuickChip(label: s.custom, onTap: () async {
          await _bot(s.typeVat, ms: 200);
        }),
      ],
    );
  }

  Future<void> _applyVat(double n) async {
    final s = _s;
    _draft.setExtras(_draftState.extras.copyWith(vatPct: n));
    await _bot(n == 0 ? s.noVat : s.vatApplied(n), ms: 250);
    if (_editingFromMenu) { _editingFromMenu = false; _showFinalConfirm(); return; }
    _askService();
  }

  Future<void> _handleVat(String text, {bool requireConfirm = true}) async {
    final s = _s;
    final n = parseNumber(text);
    if (n == null || n < 0) { await _bot(s.typeValidNumber, ms: 200); return; }
    _draft.setExtras(_draftState.extras.copyWith(vatPct: n));
    if (!requireConfirm) { _askService(); return; }
    await _bot(s.vatConfirm(n), chips: [
      QuickChip(label: s.yes, onTap: () { _addUser(s.yes); _askService(); }),
      QuickChip(label: s.change, onTap: () async {
        _draft.setExtras(_draftState.extras.copyWith(vatPct: 0));
        await _bot(s.typeVat, ms: 200);
      }),
    ]);
  }

  // ═══════════════════ STEP SERVICE ════════════════════════════════════════

  Future<void> _askService() async {
    _setStep(FlowStep.service);
    final s = _s;
    await _bot(
      '${s.step4Title}\n\n${s.quickOptionOrCustom}',
      chips: [
        QuickChip(label: s.noServiceChip, onTap: () { _addUser(s.noServiceChip); _applyService(0); }),
        QuickChip(label: '5%',  onTap: () { _addUser('5%');  _applyService(5);  }),
        QuickChip(label: '10%', onTap: () { _addUser('10%'); _applyService(10); }),
        QuickChip(label: '12%', onTap: () { _addUser('12%'); _applyService(12); }),
        QuickChip(label: '15%', onTap: () { _addUser('15%'); _applyService(15); }),
        QuickChip(label: '20%', onTap: () { _addUser('20%'); _applyService(20); }),
        QuickChip(label: s.custom, onTap: () async {
          await _bot(s.typeService, ms: 200);
        }),
      ],
    );
  }

  Future<void> _applyService(double n) async {
    final s = _s;
    _draft.setExtras(_draftState.extras.copyWith(servicePct: n));
    await _bot(n == 0 ? s.noService : s.serviceApplied(n), ms: 250);
    if (_editingFromMenu) { _editingFromMenu = false; _showFinalConfirm(); return; }
    _askTip();
  }

  Future<void> _handleService(String text, {bool requireConfirm = true}) async {
    final s = _s;
    final n = parseNumber(text);
    if (n == null || n < 0) { await _bot(s.typeValidNumber, ms: 200); return; }
    _draft.setExtras(_draftState.extras.copyWith(servicePct: n));
    if (!requireConfirm) { _askTip(); return; }
    await _bot(s.serviceConfirm(n), chips: [
      QuickChip(label: s.yes, onTap: () { _addUser(s.yes); _askTip(); }),
      QuickChip(label: s.change, onTap: () async {
        _draft.setExtras(_draftState.extras.copyWith(servicePct: 0));
        await _bot(s.typeService, ms: 200);
      }),
    ]);
  }

  // ═══════════════════ STEP TIP ════════════════════════════════════════════

  Future<void> _askTip() async {
    _setStep(FlowStep.tip);
    final s = _s;
    await _bot(
      '${s.step5Title}\n\n${s.quickOptionOrCustom}',
      chips: [
        QuickChip(label: s.noTipChip, onTap: () { _addUser(s.noTipChip); _applyTip(0); }),
        QuickChip(label: '5%',  onTap: () { _addUser('5%');  _applyTip(5);  }),
        QuickChip(label: '10%', onTap: () { _addUser('10%'); _applyTip(10); }),
        QuickChip(label: '15%', onTap: () { _addUser('15%'); _applyTip(15); }),
        QuickChip(label: '20%', onTap: () { _addUser('20%'); _applyTip(20); }),
        QuickChip(label: s.custom, onTap: () async {
          await _bot(s.typeTip, ms: 200);
        }),
      ],
    );
  }

  Future<void> _applyTip(double n) async {
    final s = _s;
    _draft.setExtras(_draftState.extras.copyWith(tipPct: n));
    await _bot(n == 0 ? s.noTip : s.tipApplied(n), ms: 250);
    _editingFromMenu = false;
    _showFinalConfirm();
  }

  Future<void> _handleTip(String text, {bool requireConfirm = true}) async {
    final s = _s;
    final n = parseNumber(text);
    if (n == null || n < 0) { await _bot(s.typeValidNumber, ms: 200); return; }
    _draft.setExtras(_draftState.extras.copyWith(tipPct: n));
    if (!requireConfirm) { _showFinalConfirm(); return; }
    await _bot(s.tipConfirm(n), chips: [
      QuickChip(label: s.yes, onTap: () { _addUser(s.yes); _showFinalConfirm(); }),
      QuickChip(label: s.change, onTap: () async {
        _draft.setExtras(_draftState.extras.copyWith(tipPct: 0));
        await _bot(s.typeTip, ms: 200);
      }),
    ]);
  }

  // ═══════════════════ FINAL CONFIRM ═══════════════════════════════════════

  Future<void> _showFinalConfirm() async {
    _setStep(FlowStep.confirm);
    final s = _s;
    final sub = _draftState.items.fold(0.0, (sum, i) => sum + i.price);
    final ext = _draftState.extras;
    final vatAmt = ext.vatAmount(sub);
    final svcAmt = ext.serviceAmount(sub);
    final tipAmt = ext.tipAmount(sub);
    final total  = sub + vatAmt + svcAmt + tipAmt;
    final lines = [
      '${s.peopleLabel}   ${_draftState.people.map((p) => p.name).join(', ')}',
      '${s.itemsCount(_draftState.items.length)}',
      '${s.subtotal(fmtAmount(sub, _curr))}',
      '',
      ext.vatPct > 0     ? s.vatLine(ext.vatPct, fmtAmount(vatAmt, _curr))         : s.vatNone,
      ext.servicePct > 0 ? s.serviceLine(ext.servicePct, fmtAmount(svcAmt, _curr)) : s.serviceNone,
      ext.tipPct > 0     ? s.tipLine(ext.tipPct, fmtAmount(tipAmt, _curr))         : s.tipNone,
      '',
      s.grandTotalLine(fmtAmount(total, _curr)),
    ].join('\n');
    await _bot(
      '${s.finalConfirmTitle}\n\n$lines\n\n${s.allGoodQuestion}',
      chips: [
        QuickChip(label: s.everythingLooksGood, onTap: () { _addUser(s.everythingLooksGood); _calcAndShow(); }),
        QuickChip(label: s.editBtn, onTap: () => _showEditMenu()),
      ],
    );
  }

  Future<void> _handleConfirm(String text) async {
    final low = text.toLowerCase();
    if (low.contains('yes') || low.contains('ok') || low.contains('calculate') ||
        low.contains('go') || low.contains('نعم') || low.contains('احسب') ||
        low.contains('looks good') || low.contains('everything')) {
      _calcAndShow();
    } else {
      await _bot(_s.tapCalculate, ms: 200);
    }
  }

  // ═══════════════════ RESULT ═══════════════════════════════════════════════

  void _calcAndShow() {
    _setStep(FlowStep.result);
    final bill   = _draftState.toBill(_curr);
    final result = SplitCalculator.calculate(bill);
    ref.read(splitResultProvider.notifier).value = result;
    ref.read(finalBillProvider.notifier).value   = bill;
    _bot(_s.finalSplit(bill.merchant), ms: 400);
  }

  Future<void> reset() async {
    _pendingItemName  = '';
    _pendingItemPrice = '';
    _totalItems       = 0;
    _currentItemIndex = 0;
    _editingItemIndex = -1;
    _editSubStep      = '';
    _selectedPersonIds.clear();
    _draft.reset();
    _setStep(FlowStep.people);
    ref.read(splitResultProvider.notifier).value = null;
    ref.read(finalBillProvider.notifier).value   = null;
    state = [];
    await _start();
  }
}