// lib/features/flow/flow_controller.dart
//
// The brain of SplitCheck. Drives the entire guided conversation.
// No AI calls — pure pattern matching + ML Kit OCR.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/services/providers.dart';
import '../../core/services/parser_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/split_calculator.dart';
import '../../core/utils/currency.dart';
import 'chat_message.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final chatProvider = StateNotifierProvider<FlowController, List<ChatMessage>>(
  (ref) => FlowController(ref),
);

final isTypingProvider = StateProvider<bool>((ref) => false);

// ── Controller ────────────────────────────────────────────────────────────────

class FlowController extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  static const _uuid = Uuid();

  FlowController(this._ref) : super([]) {
    _start();
  }

  // helpers
  BillDraftNotifier get _draft => _ref.read(billDraftProvider.notifier);
  BillDraft get _draftState    => _ref.read(billDraftProvider);
  FlowStep get _step           => _ref.read(flowStepProvider);
  String get _curr             => _ref.read(currencyProvider);

  void _setStep(FlowStep s) => _ref.read(flowStepProvider.notifier).state = s;

  void _addUser(String text) {
    state = [...state, ChatMessage(role: MessageRole.user, text: text)];
  }

  Future<void> _bot(String text, {List<QuickChip>? chips, Widget? widget, int ms = 500}) async {
    _ref.read(isTypingProvider.notifier).state = true;
    await Future.delayed(Duration(milliseconds: ms));
    _ref.read(isTypingProvider.notifier).state = false;
    state = [...state, ChatMessage(role: MessageRole.bot, text: text, chips: chips, inlineWidget: widget)];
  }

  // ── PUBLIC: route user input ──────────────────────────────────────────────

  Future<void> handleInput(String text) async {
    if (text.trim().isEmpty) return;
    _addUser(text);
    switch (_step) {
      case FlowStep.people:  _handlePeople(text);  break;
      case FlowStep.items:   _handleItems(text);   break;
      case FlowStep.vat:     _handleVat(text);     break;
      case FlowStep.service: _handleService(text); break;
      case FlowStep.tip:     _handleTip(text);     break;
      case FlowStep.confirm: _handleConfirm(text); break;
      case FlowStep.result:
        _bot('Bill is done! Tap "New bill" below to start again.', ms: 200);
        break;
    }
  }

  // ── INIT ──────────────────────────────────────────────────────────────────

  Future<void> _start() async {
    _setStep(FlowStep.people);
    await _bot(
      '👋 Welcome to SplitCheck!\n\n'
      'Step 1 — Who\'s splitting the bill?\n\n'
      'Type or say all names at once.\n'
      'Example: Ahmed, Sara, Omar',
    );
  }

  // ═══════════════════ STEP 1 — PEOPLE ════════════════════════════════════

  Future<void> _handlePeople(String text) async {
    final names = parsePeopleNames(text);
    if (names.isEmpty) {
      await _bot('I couldn\'t find any names. Try: Ahmed, Sara, Omar', ms: 300);
      return;
    }

    _draft.setPeople(names.asMap().entries.map((e) => Person(
      id: _uuid.v4(),
      name: e.value,
      color: kPersonColors[e.key % kPersonColors.length],
    )).toList());

    final nameList = names.join(', ');
    await _bot(
      'Got it — $nameList\n\nIs this correct?',
      chips: [
        QuickChip(label: 'Yes ✓', onTap: () => _confirmPeople()),
        QuickChip(label: 'No, re-enter', onTap: () async {
          await _bot('Type all names again.', ms: 200);
        }),
      ],
    );
  }

  Future<void> _confirmPeople() async {
    await _bot('People confirmed ✓', ms: 250);
    _beginItems();
  }

  // ═══════════════════ STEP 2 — ITEMS ════════════════════════════════════

  Future<void> _beginItems() async {
    _setStep(FlowStep.items);
    final names = _draftState.people.map((p) => p.name).join(', ');
    await _bot(
      'People: $names\n\n'
      'Step 2 — Add items.\n\n'
      'Format: item name · price · who\n\n'
      'Examples:\n'
      '  Burger 35 Ahmed\n'
      '  Pizza 90 Ahmed Sara  ← split between them\n'
      '  Coffee 18            ← shared by everyone\n\n'
      'Add one or many at once.\n'
      'Tap 📷 to scan the receipt.\n'
      'Say "done" when finished.',
      chips: [
        QuickChip(label: 'Done ✓', onTap: () {
          if (_draftState.items.isEmpty) {
            _bot('Add at least one item first.', ms: 200);
            return;
          }
          _addUser('Done');
          _confirmItems();
        }),
      ],
    );
  }

  Future<void> _handleItems(String text) async {
    final low = text.toLowerCase().trim();
    if ((low == 'done' || low == 'next' || low == 'finish')) {
      if (_draftState.items.isEmpty) {
        await _bot('Add at least one item first.', ms: 200);
        return;
      }
      _confirmItems();
      return;
    }

    final parsed = parseItems(text, knownPeople: _draftState.people);
    if (parsed.isEmpty) {
      await _bot('Couldn\'t parse that.\nTry: Burger 35 Ahmed  or  Pizza 90 Ahmed Sara', ms: 300);
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
      _draft.addItem(BillItem(
        id: _uuid.v4(),
        name: p.name,
        price: p.price,
        personIds: personIds,
      ));
    }

    final summary = parsed.map((p) {
      final who = p.personNames.isEmpty ? 'shared' : p.personNames.join(' + ');
      return '  ${p.name}  ${fmtAmount(p.price, _curr)}  → $who';
    }).join('\n');

    final runTotal = _draftState.items.fold(0.0, (s, i) => s + i.price);

    await _bot(
      'Added:\n$summary\n\nRunning total: ${fmtAmount(runTotal, _curr)}',
      chips: [
        QuickChip(label: 'Add more', onTap: () async => _bot('What else?', ms: 200)),
        QuickChip(label: 'Done ✓', onTap: () { _addUser('Done'); _confirmItems(); }),
      ],
    );
  }

  Future<void> _confirmItems() async {
    final total = _draftState.items.fold(0.0, (s, i) => s + i.price);
    final list = _draftState.items.map((it) {
      final who = it.personIds.isEmpty
          ? 'shared'
          : it.personIds.map((pid) =>
              _draftState.people.firstWhere((p) => p.id == pid,
                orElse: () => const Person(id: '', name: '?', color: Color(0xFF000000))).name
            ).join(' + ');
      return '  ${it.name}  ${fmtAmount(it.price, _curr)}  → $who';
    }).join('\n');

    await _bot(
      'Items summary:\n\n$list\n\nSubtotal: ${fmtAmount(total, _curr)}\n\nAll correct?',
      chips: [
        QuickChip(label: 'Yes ✓', onTap: () { _addUser('Yes'); _askVat(); }),
        QuickChip(label: 'Remove last item', onTap: () {
          _draft.removeLastItem();
          _addUser('Remove last item');
          _confirmItems();
        }),
        QuickChip(label: 'Start items over', onTap: () {
          _draft.clearItems();
          _addUser('Start over');
          _bot('Items cleared. Add items again.', ms: 200);
        }),
      ],
    );
  }

  // ── OCR ───────────────────────────────────────────────────────────────────

  Future<void> handleOcrFile(File file) async {
    _addUser('📷 Scanning receipt…');
    _ref.read(isTypingProvider.notifier).state = true;

    try {
      final ocr = _ref.read(ocrServiceProvider);
      final result = await ocr.scanReceipt(file, knownPeople: _draftState.people);
      _ref.read(isTypingProvider.notifier).state = false;

      if (result.isArabic && result.items.isEmpty) {
        await _bot(
          'Arabic receipt detected.\n\n'
          'ML Kit reads English receipts. For Arabic receipts, please add items by typing or voice.',
          ms: 300,
          chips: [QuickChip(label: 'Add items manually', onTap: () async => _bot('What items?', ms: 200))],
        );
        return;
      }

      if (result.items.isEmpty) {
        await _bot('Couldn\'t read any items from this photo.\nTry a clearer, brighter photo.', ms: 300);
        return;
      }

      for (final item in result.items) {
        _draft.addItem(BillItem(id: _uuid.v4(), name: item.name, price: item.price, personIds: const []));
      }

      final total = _draftState.items.fold(0.0, (s, i) => s + i.price);
      final preview = result.items.take(5).map((i) => '  ${i.name}  ${fmtAmount(i.price, _curr)}').join('\n');
      final more = result.items.length > 5 ? '\n  +${result.items.length - 5} more items' : '';

      await _bot(
        'Scanned ✓ ${result.items.length} items:\n$preview$more\n\n'
        'Total: ${fmtAmount(total, _curr)}\n\n'
        'Now tell me who ordered what — same format as before.\n'
        'Or tap "Split equally" to skip assignment.',
        chips: [
          QuickChip(label: 'Add more items', onTap: () async => _bot('What else?', ms: 200)),
          QuickChip(label: 'Split equally →', onTap: () { _addUser('Split equally'); _askVat(); }),
        ],
      );
    } catch (e) {
      _ref.read(isTypingProvider.notifier).state = false;
      await _bot('Couldn\'t scan the receipt. Try a clearer photo or add items manually.', ms: 300);
    }
  }

  // ═══════════════════ STEP 3 — VAT ════════════════════════════════════════

  Future<void> _askVat() async {
    _setStep(FlowStep.vat);
    await _bot(
      'Step 3 — VAT / Tax\n\n'
      'What\'s the VAT percentage?\n'
      'Type a number like 5 for 5%\n'
      'Or say "none" to skip.',
      chips: [
        QuickChip(label: '5%',    onTap: () { _addUser('5');    _handleVat('5');    }),
        QuickChip(label: '15%',   onTap: () { _addUser('15');   _handleVat('15');   }),
        QuickChip(label: 'No VAT',onTap: () { _addUser('None'); _handleVat('0');    }),
      ],
    );
  }

  Future<void> _handleVat(String text) async {
    final n = parseNumber(text);
    if (n == null || n < 0) { await _bot('Please enter a number like 5, or say "none".', ms: 200); return; }
    _draft.setExtras(_draftState.extras.copyWith(vatPct: n));
    final msg = n == 0 ? 'No VAT — confirmed?' : 'VAT: ${n.toStringAsFixed(1)}% — correct?';
    await _bot(msg, chips: [
      QuickChip(label: 'Yes ✓', onTap: () { _addUser('Yes'); _askService(); }),
      QuickChip(label: 'Change', onTap: () async { _draft.setExtras(_draftState.extras.copyWith(vatPct: 0)); await _bot('What\'s the VAT?', ms: 200); }),
    ]);
  }

  // ═══════════════════ STEP 4 — SERVICE ════════════════════════════════════

  Future<void> _askService() async {
    _setStep(FlowStep.service);
    await _bot(
      'Step 4 — Service charge\n\n'
      'What\'s the service charge percentage?\n'
      'Type a number like 10, or say "none".',
      chips: [
        QuickChip(label: '10%',         onTap: () { _addUser('10');   _handleService('10'); }),
        QuickChip(label: '15%',         onTap: () { _addUser('15');   _handleService('15'); }),
        QuickChip(label: 'No service',  onTap: () { _addUser('None'); _handleService('0');  }),
      ],
    );
  }

  Future<void> _handleService(String text) async {
    final n = parseNumber(text);
    if (n == null || n < 0) { await _bot('Please enter a number like 10, or say "none".', ms: 200); return; }
    _draft.setExtras(_draftState.extras.copyWith(servicePct: n));
    final msg = n == 0 ? 'No service charge — confirmed?' : 'Service: ${n.toStringAsFixed(1)}% — correct?';
    await _bot(msg, chips: [
      QuickChip(label: 'Yes ✓', onTap: () { _addUser('Yes'); _askTip(); }),
      QuickChip(label: 'Change', onTap: () async { _draft.setExtras(_draftState.extras.copyWith(servicePct: 0)); await _bot('What\'s the service charge?', ms: 200); }),
    ]);
  }

  // ═══════════════════ STEP 5 — TIP ════════════════════════════════════════

  Future<void> _askTip() async {
    _setStep(FlowStep.tip);
    await _bot(
      'Step 5 — Tip (optional)\n\n'
      'Would you like to add a tip?\n'
      'Type a percentage, or say "none".',
      chips: [
        QuickChip(label: 'No tip', onTap: () { _addUser('None'); _handleTip('0');  }),
        QuickChip(label: '10%',    onTap: () { _addUser('10');   _handleTip('10'); }),
        QuickChip(label: '15%',    onTap: () { _addUser('15');   _handleTip('15'); }),
        QuickChip(label: '20%',    onTap: () { _addUser('20');   _handleTip('20'); }),
      ],
    );
  }

  Future<void> _handleTip(String text) async {
    final n = parseNumber(text);
    if (n == null || n < 0) { await _bot('Please enter a number like 10, or say "none".', ms: 200); return; }
    _draft.setExtras(_draftState.extras.copyWith(tipPct: n));
    final msg = n == 0 ? 'No tip — confirmed?' : 'Tip: ${n.toStringAsFixed(1)}% — correct?';
    await _bot(msg, chips: [
      QuickChip(label: 'Yes ✓', onTap: () { _addUser('Yes'); _showFinalConfirm(); }),
      QuickChip(label: 'Change', onTap: () async { _draft.setExtras(_draftState.extras.copyWith(tipPct: 0)); await _bot('What tip percentage?', ms: 200); }),
    ]);
  }

  // ═══════════════════ STEP 6 — FINAL CONFIRM ══════════════════════════════

  Future<void> _showFinalConfirm() async {
    _setStep(FlowStep.confirm);
    final sub = _draftState.items.fold(0.0, (s, i) => s + i.price);
    final ext = _draftState.extras;
    final vatAmt = ext.vatAmount(sub);
    final svcAmt = ext.serviceAmount(sub);
    final tipAmt = ext.tipAmount(sub);
    final total  = sub + vatAmt + svcAmt + tipAmt;

    final lines = [
      'People:   ${_draftState.people.map((p) => p.name).join(', ')}',
      'Items:    ${_draftState.items.length} items',
      'Subtotal: ${fmtAmount(sub, _curr)}',
      '',
      ext.vatPct > 0
          ? 'VAT ${ext.vatPct.toStringAsFixed(1)}%:      ${fmtAmount(vatAmt, _curr)}'
          : 'VAT:          None',
      ext.servicePct > 0
          ? 'Service ${ext.servicePct.toStringAsFixed(1)}%:  ${fmtAmount(svcAmt, _curr)}'
          : 'Service:      None',
      ext.tipPct > 0
          ? 'Tip ${ext.tipPct.toStringAsFixed(1)}%:       ${fmtAmount(tipAmt, _curr)}'
          : 'Tip:          None',
      '',
      'Grand total: ${fmtAmount(total, _curr)}',
    ].join('\n');

    await _bot(
      'Final confirmation:\n\n$lines\n\nAll good?',
      chips: [
        QuickChip(label: 'Yes — calculate! →', onTap: () { _addUser('Calculate'); _calcAndShow(); }),
        QuickChip(label: 'Change VAT',     onTap: () { _addUser('Change VAT');     _draft.setExtras(_draftState.extras.copyWith(vatPct: 0));     _askVat();     }),
        QuickChip(label: 'Change service', onTap: () { _addUser('Change service'); _draft.setExtras(_draftState.extras.copyWith(servicePct: 0)); _askService(); }),
        QuickChip(label: 'Change tip',     onTap: () { _addUser('Change tip');     _draft.setExtras(_draftState.extras.copyWith(tipPct: 0));     _askTip();     }),
      ],
    );
  }

  Future<void> _handleConfirm(String text) async {
    final low = text.toLowerCase();
    if (low.contains('yes') || low.contains('ok') || low.contains('calculate') || low.contains('go')) {
      _calcAndShow();
    } else {
      await _bot('Tap "Yes — calculate!" above, or choose what to change.', ms: 200);
    }
  }

  // ═══════════════════ STEP 7 — RESULT ═════════════════════════════════════

  void _calcAndShow() {
    _setStep(FlowStep.result);
    final bill   = _draftState.toBill(_curr);
    final result = SplitCalculator.calculate(bill);
    _ref.read(splitResultProvider.notifier).state = result;
    _ref.read(finalBillProvider.notifier).state   = bill;
    _bot(
      'Here\'s the final split${bill.merchant.isNotEmpty ? " for ${bill.merchant}" : ""}:',
      ms: 400,
    );
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  Future<void> reset() async {
    _draft.reset();
    _setStep(FlowStep.people);
    _ref.read(splitResultProvider.notifier).state = null;
    _ref.read(finalBillProvider.notifier).state   = null;
    state = [];
    await _start();
  }
}
