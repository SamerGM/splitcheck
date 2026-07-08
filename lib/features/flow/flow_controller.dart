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
import '../../core/utils/strings.dart';
import '../../core/utils/currency.dart';
import 'chat_message.dart';

final chatProvider = NotifierProvider<FlowController, List<ChatMessage>>(
  FlowController.new,
);

class FlowController extends Notifier<List<ChatMessage>> {
  static const _uuid = Uuid();
  bool _editMode = false;

  @override
  List<ChatMessage> build() {
    Future.microtask(() async {
      try {
        await _start();
      } catch (e) {
        // ignore startup errors
      }
    });
    return [];
  }

  BillDraftNotifier get _draft => ref.read(billDraftProvider.notifier);
  BillDraft get _draftState    => ref.read(billDraftProvider);
  FlowStep get _step           => ref.read(flowStepProvider);
  String get _curr             => ref.read(currencyProvider);
  S get _s                     => ref.read(stringsProvider);

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
    if (_editMode) { _handleEditCommand(text); return; }
    switch (_step) {
      case FlowStep.people:  _handlePeople(text);  break;
      case FlowStep.items:   _handleItems(text);   break;
      case FlowStep.vat:     _handleVat(text, requireConfirm: true); break;
      case FlowStep.service: _handleService(text, requireConfirm: true); break;
      case FlowStep.tip:     _handleTip(text, requireConfirm: true); break;
      case FlowStep.confirm: _handleConfirm(text); break;
      case FlowStep.result:
        _bot(_s.billDone, ms: 200);
        break;
    }
  }

  Future<void> _start() async {
    _setStep(FlowStep.people);
    final s = _s;
    await _bot(
      '${s.welcome}\n\n'
      '${s.step1Question}\n\n'
      '${s.typeOrSayNames}\n'
      '${s.namesExample}',
    );
  }

  // ═══════════════════ STEP 1 — PEOPLE ═════════════════════════════════════

  Future<void> _handlePeople(String text) async {
    final s = _s;
    final names = parsePeopleNames(text);
    if (names.isEmpty) {
      await _bot(s.namesNotFound, ms: 300);
      return;
    }
    _draft.setPeople(names.asMap().entries.map((e) => Person(
      id: _uuid.v4(),
      name: e.value,
      color: kPersonColors[e.key % kPersonColors.length],
    )).toList());
    await _bot('${s.gotIt(names.join(', '))}\n\n${s.isCorrect}', chips: [
      QuickChip(label: s.yes, onTap: () => _confirmPeople()),
      QuickChip(label: s.noReenter, onTap: () async {
        await _bot(s.typeNamesAgain, ms: 200);
      }),
      QuickChip(label: s.addMoreNames, onTap: () async {
        await _bot(s.typeNamesAgain, ms: 200);
      }),
    ]);
  }

  Future<void> _confirmPeople() async {
    await _bot(_s.peopleConfirmed, ms: 250);
    _beginItems();
  }

  // ═══════════════════ STEP 2 — ITEMS ══════════════════════════════════════

  Future<void> _beginItems() async {
    _setStep(FlowStep.items);
    final s = _s;
    final names = _draftState.people.map((p) => p.name).join(', ');
    await _bot(
      '${s.people(names)}\n\n'
      '${s.step2Title}\n\n'
      '${s.itemFormat}\n\n'
      'Examples:\n'
      '  ${s.itemExample1}\n'
      '  ${s.itemExample2}\n'
      '  ${s.itemExample3}\n\n'
      '${s.scanTip}\n'
      '${s.sayDoneWhenFinished}',
      chips: [
        QuickChip(label: s.done, onTap: () {
          if (_draftState.items.isEmpty) {
            _bot(s.addItemFirst, ms: 200);
            return;
          }
          _addUser(s.done);
          _showEditScreen();
        }),
      ],
    );
  }

  Future<void> _handleItems(String text) async {
    final s = _s;
    final low = text.toLowerCase().trim();
    if (low == 'done' || low == 'next' || low == 'finish' || low == 'تم') {
      if (_draftState.items.isEmpty) {
        await _bot(s.addItemFirst, ms: 200);
        return;
      }
      _showEditScreen();
      return;
    }
    final parsed = parseItems(text, knownPeople: _draftState.people);
    if (parsed.isEmpty) {
      await _bot(s.cantParseItem, ms: 300);
      return;
    }
    for (final p in parsed) {
      final personIds = <String>[];
      for (final name in p.personNames) {
        final match = _draftState.people.firstWhere(
          (person) => person.name.toLowerCase() == name.toLowerCase() ||
                      person.name.toLowerCase().contains(name.toLowerCase()),
          orElse: () => const Person(id: '', name: '', color: Color(0xFF000000)),
        );
        if (match.id.isNotEmpty && !personIds.contains(match.id)) {
          personIds.add(match.id);
        }
      }
      _draft.addItem(BillItem(id: _uuid.v4(), name: p.name, price: p.price, personIds: personIds));
    }
    final summary = parsed.map((p) {
      final who = p.personNames.isEmpty ? s.shared : p.personNames.join(' + ');
      return '  ${p.name}  ${fmtAmount(p.price, _curr)}  → $who';
    }).join('\n');
    final runTotal = _draftState.items.fold(0.0, (sum, i) => sum + i.price);
    await _bot(
      'Added:\n$summary\n\n${s.runningTotal(fmtAmount(runTotal, _curr))}',
      chips: [
        QuickChip(label: s.addMore, onTap: () async => _bot(s.whatElse, ms: 200)),
        QuickChip(label: s.done, onTap: () { _addUser(s.done); _showEditScreen(); }),
      ],
    );
  }

  // ═══════════════════ EDIT SCREEN ═════════════════════════════════════════

  Future<void> _showEditScreen() async {
    _editMode = true;
    final s = _s;
    final total = _draftState.items.fold(0.0, (sum, i) => sum + i.price);
    await _bot(
      '${s.hereAreItems}\n\n${_itemListText()}'
      '${s.subtotal(fmtAmount(total, _curr))}\n\n'
      '${s.wantToEdit}\n\n'
      '  ${s.editExample1}\n'
      '  ${s.editExample2}\n'
      '  ${s.editExample3}\n\n'
      'Or tap "${s.allGood}" to continue.',
      chips: [
        QuickChip(label: s.allGood, onTap: () {
          _editMode = false;
          _addUser(s.allGood);
          _askVat();
        }),
      ],
    );
  }

  String _itemListText() => _itemListTextFrom(_draftState.items);

  String _itemListTextFrom(List<BillItem> items) {
    final s = _s;
    if (items.isEmpty) return '  (no items)\n';
    return items.asMap().entries.map((e) {
      final it = e.value;
      final who = it.personIds.isEmpty
          ? s.shared
          : it.personIds.map((pid) =>
              _draftState.people.firstWhere((p) => p.id == pid,
                orElse: () => const Person(id: '', name: '?', color: Color(0xFF000000))).name
            ).join(' + ');
      return '  ${e.key + 1}. ${it.name}  ${fmtAmount(it.price, _curr)}  → $who';
    }).join('\n') + '\n';
  }

  Future<void> _handleEditCommand(String text) async {
    final s = _s;
    final low = text.toLowerCase().trim();
    if (low == 'all good' || low == 'done' || low == 'ok' || low == 'next' ||
        low == 'continue' || low == 'كل شيء صحيح' || low == 'تم') {
      _editMode = false;
      _askVat();
      return;
    }
    final cmd = parseEditCommand(text);
    if (cmd == null) {
      await _bot(
        s.editCantUnderstand,
        chips: [
          QuickChip(label: s.allGood, onTap: () {
            _editMode = false;
            _addUser(s.allGood);
            _askVat();
          }),
        ],
        ms: 300,
      );
      return;
    }
    final keyword = cmd.itemKeyword.toLowerCase();
    final items = List<BillItem>.from(_draftState.items);
    final idx = items.indexWhere((it) => it.name.toLowerCase().contains(keyword));
    if (idx == -1) {
      await _bot(s.itemNotFound(cmd.itemKeyword), ms: 300);
      return;
    }
    final item = items[idx];
    if (cmd.action == EditAction.remove) {
      items.removeAt(idx);
      ref.read(billDraftProvider.notifier).state = _draftState.copyWith(items: items);
      final total = items.fold(0.0, (sum, i) => sum + i.price);
      await _bot(
        '${s.itemRemoved(item.name)}\n\n${_itemListTextFrom(items)}'
        '${s.subtotal(fmtAmount(total, _curr))}\n\n${s.anythingElse}',
        chips: [QuickChip(label: s.allGood, onTap: () { _editMode = false; _addUser(s.allGood); _askVat(); })],
        ms: 300,
      );
      return;
    }
    double newPrice = item.price;
    List<String> newPersonIds = List.from(item.personIds);
    if (cmd.newPrice != null) newPrice = cmd.newPrice!;
    if (cmd.newPersons.isNotEmpty) {
      newPersonIds = [];
      for (final name in cmd.newPersons) {
        final match = _draftState.people.firstWhere(
          (p) => p.name.toLowerCase() == name.toLowerCase() ||
                 p.name.toLowerCase().contains(name.toLowerCase()),
          orElse: () => const Person(id: '', name: '', color: Color(0xFF000000)),
        );
        if (match.id.isNotEmpty) newPersonIds.add(match.id);
      }
    }
    items[idx] = BillItem(id: item.id, name: item.name, price: newPrice, personIds: newPersonIds);
    ref.read(billDraftProvider.notifier).state = _draftState.copyWith(items: items);
    final who = newPersonIds.isEmpty
        ? s.shared
        : newPersonIds.map((pid) =>
            _draftState.people.firstWhere((p) => p.id == pid,
              orElse: () => const Person(id: '', name: '?', color: Color(0xFF000000))).name
          ).join(' + ');
    final total = items.fold(0.0, (sum, i) => sum + i.price);
    await _bot(
      '${s.itemUpdated(item.name)}\n'
      '  Price: ${fmtAmount(newPrice, _curr)}\n'
      '  Who: $who\n\n'
      '${_itemListTextFrom(items)}'
      '${s.subtotal(fmtAmount(total, _curr))}\n\n${s.anythingElse}',
      chips: [QuickChip(label: s.allGood, onTap: () { _editMode = false; _addUser(s.allGood); _askVat(); })],
      ms: 300,
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
        await _bot(
          s.arabicReceiptDetected,
          ms: 300,
          chips: [QuickChip(label: s.addItemsManually, onTap: () async => _bot(s.whatElse, ms: 200))],
        );
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
          QuickChip(label: s.splitEqually, onTap: () { _addUser(s.splitEqually); _showEditScreen(); }),
        ],
      );
    } catch (e) {
      ref.read(isTypingProvider.notifier).value = false;
      await _bot(s.cantScanReceipt, ms: 300);
    }
  }

  // ═══════════════════ STEP 3 — VAT ════════════════════════════════════════

  Future<void> _askVat() async {
    _setStep(FlowStep.vat);
    final s = _s;
    await _bot(
      '${s.step3Title}\n\n${s.quickOptionOrCustom}',
      chips: [
        QuickChip(label: '0%',  onTap: () { _addUser('0%');  _applyVat(0);  }),
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
    _askService();
  }

  Future<void> _handleVat(String text, {bool requireConfirm = true}) async {
    final s = _s;
    final n = parseNumber(text);
    if (n == null || n < 0) {
      await _bot(s.typeValidNumber, ms: 200);
      return;
    }
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

  // ═══════════════════ STEP 4 — SERVICE ════════════════════════════════════

  Future<void> _askService() async {
    _setStep(FlowStep.service);
    final s = _s;
    await _bot(
      '${s.step4Title}\n\n${s.quickOptionOrCustom}',
      chips: [
        QuickChip(label: '0%',  onTap: () { _addUser('0%');  _applyService(0);  }),
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
    _askTip();
  }

  Future<void> _handleService(String text, {bool requireConfirm = true}) async {
    final s = _s;
    final n = parseNumber(text);
    if (n == null || n < 0) {
      await _bot(s.typeValidNumber, ms: 200);
      return;
    }
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

  // ═══════════════════ STEP 5 — TIP ════════════════════════════════════════

  Future<void> _askTip() async {
    _setStep(FlowStep.tip);
    final s = _s;
    await _bot(
      '${s.step5Title}\n\n${s.quickOptionOrCustom}',
      chips: [
        QuickChip(label: '0%',  onTap: () { _addUser('0%');  _applyTip(0);  }),
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
    _showFinalConfirm();
  }

  Future<void> _handleTip(String text, {bool requireConfirm = true}) async {
    final s = _s;
    final n = parseNumber(text);
    if (n == null || n < 0) {
      await _bot(s.typeValidNumber, ms: 200);
      return;
    }
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

  // ═══════════════════ STEP 6 — FINAL CONFIRM ══════════════════════════════

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
      ext.vatPct > 0     ? s.vatLine(ext.vatPct, fmtAmount(vatAmt, _curr))     : s.vatNone,
      ext.servicePct > 0 ? s.serviceLine(ext.servicePct, fmtAmount(svcAmt, _curr)) : s.serviceNone,
      ext.tipPct > 0     ? s.tipLine(ext.tipPct, fmtAmount(tipAmt, _curr))     : s.tipNone,
      '',
      s.grandTotalLine(fmtAmount(total, _curr)),
    ].join('\n');
    await _bot(
      '${s.finalConfirmTitle}\n\n$lines\n\n${s.allGoodQuestion}',
      chips: [
        QuickChip(label: s.calculate, onTap: () { _addUser(s.calculate); _calcAndShow(); }),
        QuickChip(label: s.changeVat,     onTap: () { _addUser(s.changeVat);     _draft.setExtras(_draftState.extras.copyWith(vatPct: 0));     _askVat();     }),
        QuickChip(label: s.changeService, onTap: () { _addUser(s.changeService); _draft.setExtras(_draftState.extras.copyWith(servicePct: 0)); _askService(); }),
        QuickChip(label: s.changeTip,     onTap: () { _addUser(s.changeTip);     _draft.setExtras(_draftState.extras.copyWith(tipPct: 0));     _askTip();     }),
      ],
    );
  }

  Future<void> _handleConfirm(String text) async {
    final low = text.toLowerCase();
    if (low.contains('yes') || low.contains('ok') || low.contains('calculate') ||
        low.contains('go') || low.contains('نعم') || low.contains('احسب')) {
      _calcAndShow();
    } else {
      await _bot(_s.tapCalculate, ms: 200);
    }
  }

  // ═══════════════════ STEP 7 — RESULT ═════════════════════════════════════

  void _calcAndShow() {
    _setStep(FlowStep.result);
    final bill   = _draftState.toBill(_curr);
    final result = SplitCalculator.calculate(bill);
    ref.read(splitResultProvider.notifier).value = result;
    ref.read(finalBillProvider.notifier).value   = bill;
    _bot(_s.finalSplit(bill.merchant), ms: 400);
  }

  Future<void> reset() async {
    _editMode = false;
    _draft.reset();
    _setStep(FlowStep.people);
    ref.read(splitResultProvider.notifier).value = null;
    ref.read(finalBillProvider.notifier).value   = null;
    state = [];
    await _start();
  }
}