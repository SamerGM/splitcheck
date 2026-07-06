// lib/core/services/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_service.dart';
import 'ocr_service.dart';
import 'history_service.dart';
import 'split_calculator.dart';
import '../models/models.dart';
import '../utils/currency.dart';

// ── Singletons ───────────────────────────────────────────────────────────────

final voiceServiceProvider  = Provider<VoiceService>((ref) => VoiceService());
final ocrServiceProvider    = Provider<OcrService>((ref) => OcrService());
final historyServiceProvider = Provider<HistoryService>((ref) => HistoryService());

// ── App-wide settings ─────────────────────────────────────────────────────────

final currencyProvider = StateProvider<String>((ref) => 'AED');
final voiceLocaleProvider = StateProvider<VoiceLocale>((ref) => VoiceLocale.english);

// ── Bill draft (in-progress flow) ─────────────────────────────────────────────

class BillDraftNotifier extends Notifier<BillDraft> {
  @override
  BillDraft build() => BillDraft.empty();

  void setMerchant(String v) => state = state.copyWith(merchant: v);
  void setPeople(List<Person> v) => state = state.copyWith(people: v);
  void addItem(BillItem item) => state = state.copyWith(items: [...state.items, item]);
  void removeLastItem() {
    if (state.items.isEmpty) return;
    final updated = List<BillItem>.from(state.items)..removeLast();
    state = state.copyWith(items: updated);
  }
  void clearItems() => state = state.copyWith(items: []);
  void setExtras(BillExtras v) => state = state.copyWith(extras: v);
  void reset() => state = BillDraft.empty();
}

final billDraftProvider = NotifierProvider<BillDraftNotifier, BillDraft>(
  BillDraftNotifier.new,
);

// ── History ───────────────────────────────────────────────────────────────────

class HistoryNotifier extends AsyncNotifier<List<Bill>> {
  @override
  Future<List<Bill>> build() async {
    final svc = ref.read(historyServiceProvider);
    await svc.init();
    return svc.loadAll();
  }

  Future<void> save(Bill bill) async {
    await ref.read(historyServiceProvider).save(bill);
    state = AsyncData(ref.read(historyServiceProvider).loadAll());
  }

  Future<void> delete(String id) async {
    await ref.read(historyServiceProvider).delete(id);
    state = AsyncData(ref.read(historyServiceProvider).loadAll());
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<Bill>>(
  HistoryNotifier.new,
);

// ── Flow step ─────────────────────────────────────────────────────────────────

enum FlowStep { people, items, vat, service, tip, confirm, result }

final flowStepProvider = StateProvider<FlowStep>((ref) => FlowStep.people);

// ── Split result (set when calculation is done) ────────────────────────────────

final splitResultProvider = StateProvider<SplitResult?>((ref) => null);
final finalBillProvider   = StateProvider<Bill?>((ref) => null);
