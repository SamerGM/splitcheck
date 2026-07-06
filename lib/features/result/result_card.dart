// lib/features/result/result_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/utils/currency.dart';
import '../../shared/theme/app_theme.dart';
import '../flow/flow_controller.dart';

class ResultCard extends ConsumerWidget {
  final SplitResult result;
  final Bill bill;

  const ResultCard({super.key, required this.result, required this.bill});

  String _buildShareText() {
    final buf = StringBuffer();
    buf.writeln('🧾 ${bill.merchant}');
    buf.writeln('─' * 24);
    for (final pr in result.personResults) {
      buf.writeln('${pr.person.name}: ${fmtAmount(pr.total, bill.currency)}');
    }
    buf.writeln('─' * 24);
    buf.writeln('Total: ${fmtAmount(result.grandTotal, bill.currency)}');
    if (bill.extras.vatPct > 0)     buf.writeln('VAT ${bill.extras.vatPct}%: ${fmtAmount(result.vatAmount, bill.currency)}');
    if (bill.extras.servicePct > 0) buf.writeln('Service ${bill.extras.servicePct}%: ${fmtAmount(result.serviceAmount, bill.currency)}');
    if (bill.extras.tipPct > 0)     buf.writeln('Tip ${bill.extras.tipPct}%: ${fmtAmount(result.tipAmount, bill.currency)}');
    buf.writeln();
    buf.writeln('Split via SplitCheck');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1D30),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grand total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              border: Border.all(color: AppTheme.accent.withOpacity(0.22)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                Text(fmtAmount(result.grandTotal, bill.currency),
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppTheme.accent)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Per person
          const Text('Per person', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textHint, letterSpacing: .7)),
          const SizedBox(height: 8),

          ...result.personResults.map((pr) => _PersonBlock(pr: pr, bill: bill)),

          // Actions
          const SizedBox(height: 8),
          Row(children: [
            _Btn(label: 'Copy', icon: Icons.copy_rounded, primary: true, onTap: () {
              Clipboard.setData(ClipboardData(text: _buildShareText()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 2)));
            }),
            const SizedBox(width: 7),
            _Btn(label: 'Share', icon: Icons.share_rounded, onTap: () {
              Share.share(_buildShareText(), subject: 'Bill Split — ${bill.merchant}');
            }),
            const SizedBox(width: 7),
            _Btn(label: 'New bill', icon: Icons.refresh_rounded, onTap: () {
              ref.read(chatProvider.notifier).reset();
            }),
          ]),
        ],
      ),
    );
  }
}

// ── Per-person block showing item lines + extras ──────────────────────────────

class _PersonBlock extends StatelessWidget {
  final PersonResult pr;
  final Bill bill;
  const _PersonBlock({required this.pr, required this.bill});

  @override
  Widget build(BuildContext context) {
    final pct = (pr.itemsSubtotal / (bill.subtotal == 0 ? 1 : bill.subtotal) * 100).toStringAsFixed(1);
    final myItems = bill.items.where((it) =>
      (it.personIds.isEmpty ? bill.people.map((p) => p.id).contains(pr.person.id) : it.personIds.contains(pr.person.id))
    ).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Header
          Row(children: [
            CircleAvatar(radius: 13, backgroundColor: pr.person.color.withOpacity(0.15),
              child: Text(pr.person.name.characters.first.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pr.person.color))),
            const SizedBox(width: 8),
            Text(pr.person.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(fmtAmount(pr.total, bill.currency),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.accent)),
          ]),

          // Item lines
          ...myItems.map((it) {
            final assigned = it.personIds.isEmpty ? bill.people.map((p) => p.id).toList() : it.personIds;
            final share = it.price / assigned.length;
            final shared = assigned.length > 1;
            return _Line(label: it.name + (shared ? ' (shared)' : ''), value: fmtAmount(share, bill.currency));
          }),

          // Extras
          if (pr.vatShare > 0)
            _Line(label: 'VAT ${bill.extras.vatPct.toStringAsFixed(1)}% × $pct%', value: fmtAmount(pr.vatShare, bill.currency), muted: true),
          if (pr.serviceShare > 0)
            _Line(label: 'Service ${bill.extras.servicePct.toStringAsFixed(1)}% × $pct%', value: fmtAmount(pr.serviceShare, bill.currency), muted: true),
          if (pr.tipShare > 0)
            _Line(label: 'Tip ${bill.extras.tipPct.toStringAsFixed(1)}% × $pct%', value: fmtAmount(pr.tipShare, bill.currency), muted: true),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label, value;
  final bool muted;
  const _Line({required this.label, required this.value, this.muted = false});
  @override
  Widget build(BuildContext context) {
    final c = muted ? AppTheme.textHint : AppTheme.textMuted;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(label, style: TextStyle(fontSize: 11, color: c))),
        Text(value, style: TextStyle(fontSize: 11, color: c)),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap; final bool primary;
  const _Btn({required this.label, required this.icon, required this.onTap, this.primary = false});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: primary ? AppTheme.accentDark : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(9),
          border: primary ? null : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: primary ? Colors.white : AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary ? Colors.white : AppTheme.textMuted)),
        ]),
      ),
    ));
  }
}
