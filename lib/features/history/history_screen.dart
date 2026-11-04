// lib/features/history/history_screen.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/services/providers.dart';
import '../../core/services/settings_provider.dart';
import '../../core/services/split_calculator.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/strings.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';
import '../result/result_card.dart';

/// List of past bills, newest first, grouped by day. Swipe to delete.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final p = Palette.of(context);
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: p.bg,
      body: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(s.history, style: TextStyle(color: p.label)),
          backgroundColor: p.barBg,
          border: Border(bottom: BorderSide(color: p.separator, width: 0.33)),
          previousPageTitle: s.back,
        ),
        ...history.when(
          loading: () => [const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))],
          error: (_, __) => [_empty(s, p)],
          data: (bills) => bills.isEmpty ? [_empty(s, p)] : _sections(context, ref, s, p, bills),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
    );
  }

  Widget _empty(S s, Palette p) => SliverFillRemaining(
    hasScrollBody: false,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(CupertinoIcons.clock, size: 56, color: p.tertiary),
      const SizedBox(height: 12),
      Text(s.historyEmpty, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: p.label)),
      const SizedBox(height: 4),
      Text(s.historyEmptyHint, style: TextStyle(fontSize: 15, color: p.secondary)),
    ])),
  );

  List<Widget> _sections(BuildContext context, WidgetRef ref, S s, Palette p, List<Bill> bills) {
    final groups = <String, List<Bill>>{};
    for (final b in bills) { groups.putIfAbsent(_dayLabel(s, b.date), () => []).add(b); }
    return [
      for (final e in groups.entries)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: InsetGroup(
              header: e.key,
              children: [for (final b in e.value) _BillRow(bill: b)],
            ),
          ),
        ),
    ];
  }

  static String _dayLabel(S s, DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return s.today;
    if (day == today.subtract(const Duration(days: 1))) return s.yesterday;
    final str = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return s.isAr ? toArabicDigits(str) : str;
  }
}

class _BillRow extends ConsumerWidget {
  final Bill bill;
  const _BillRow({required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final p = Palette.of(context);
    final total = SplitCalculator.calculate(bill).grandTotal;
    String fmt(double v) {
      final str = fmtAmount(v, bill.currency, arabic: s.isAr);
      return s.isAr ? toArabicDigits(str) : str;
    }
    final names = bill.people.map((e) => e.name).join(s.isAr ? '، ' : ', ');
    final time = '${bill.date.hour.toString().padLeft(2, '0')}:${bill.date.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: ValueKey(bill.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: p.red,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 24),
        child: const Icon(CupertinoIcons.trash_fill, color: Colors.white),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        if (bill.receiptPath != null) {
          try { File(bill.receiptPath!).deleteSync(); } catch (_) {}
        }
        ref.read(historyProvider.notifier).delete(bill.id);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => BillDetailScreen(bill: bill),
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
              child: Icon(bill.receiptPath != null ? CupertinoIcons.doc_text_viewfinder : CupertinoIcons.doc_text,
                  size: 19, color: p.accent),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bill.merchant.isNotEmpty ? bill.merchant : s.untitledBill,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, letterSpacing: -0.4, color: p.label)),
              const SizedBox(height: 2),
              Text('${s.isAr ? toArabicDigits(time) : time} · $names',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: p.secondary)),
            ])),
            const SizedBox(width: 8),
            Text(fmt(total), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.label)),
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_forward, size: 16, color: p.tertiary),
          ]),
        ),
      ),
    );
  }
}

/// A saved bill, shown with the same result card (share / copy / send again).
class BillDetailScreen extends ConsumerWidget {
  final Bill bill;
  const BillDetailScreen({super.key, required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        CupertinoNavigationBar(
          middle: Text(bill.merchant.isNotEmpty ? bill.merchant : s.untitledBill, style: TextStyle(color: p.label)),
          previousPageTitle: s.history,
          backgroundColor: p.barBg,
          border: Border(bottom: BorderSide(color: p.separator, width: 0.33)),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 32 + MediaQuery.of(context).padding.bottom),
            children: [
              ResultCard(result: SplitCalculator.calculate(bill), bill: bill, showNewBill: false),
            ],
          ),
        ),
      ]),
    );
  }
}
