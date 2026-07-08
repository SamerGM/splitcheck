import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_service.dart';
import 'ocr_service.dart';
import 'history_service.dart';
import 'split_calculator.dart';
import '../models/models.dart';
import '../utils/currency.dart';

final voiceServiceProvider   = Provider<VoiceService>((ref) => VoiceService());
final ocrServiceProvider     = Provider<OcrService>((ref) => OcrService());
final historyServiceProvider = Provider<HistoryService>((ref) => HistoryService());

final currencyProvider      = NotifierProvider<_StrNotifier, String>(() => _StrNotifier('AED'));
final voiceLocaleProvider   = NotifierProvider<_LocaleNotifier, VoiceLocale>(() => _LocaleNotifier());
final flowStepProvider      = NotifierProvider<_StepNotifier, FlowStep>(() => _StepNotifier());
final isTypingProvider      = NotifierProvider<_BoolNotifier, bool>(() => _BoolNotifier());
final splitResultProvider   = NotifierProvider<_ResultNotifier, SplitResult?>(() => _ResultNotifier());
final finalBillProvider     = NotifierProvider<_BillNotifier, Bill?>(() => _BillNotifier());

class _StrNotifier extends Notifier<String> {
  final String _init;
  _StrNotifier(this._init);
  @override String build() => _init;
  set value(String v) => state = v;
}

class _LocaleNotifier extends Notifier<VoiceLocale> {
  @override VoiceLocale build() => VoiceLocale.english;
  set value(VoiceLocale v) => state = v;
}

class _StepNotifier extends Notifier<FlowStep> {
  @override FlowStep build() => FlowStep.people;
  set value(FlowStep v) => state = v;
}

class _BoolNotifier extends Notifier<bool> {
  @override bool build() => false;
  set value(bool v) => state = v;
}

class _ResultNotifier extends Notifier<SplitResult?> {
  @override SplitResult? build() => null;
  set value(SplitResult? v) => state = v;
}

class _BillNotifier extends Notifier<Bill?> {
  @override Bill? build() => null;
  set value(Bill? v) => state = v;
}

class BillDraftNotifier extends Notifier<BillDraft> {
  @override BillDraft build() => BillDraft.empty();
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

enum FlowStep { people, items, vat, service, tip, confirm, result }
