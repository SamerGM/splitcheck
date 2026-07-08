import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/strings.dart';
import '../../core/services/settings_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../flow/flow_controller.dart';

class ResultCard extends ConsumerWidget {
  final SplitResult result;
  final Bill bill;

  const ResultCard({super.key, required this.result, required this.bill});

  String _buildShareText(S s) {
    final buf = StringBuffer();
    buf.writeln(s.shareHeader(bill.merchant));
    buf.writeln('─' * 24);
    for (final pr in result.personResults) {
      buf.writeln('${pr.person.name}: ${fmtAmount(pr.total, bill.currency)}');
    }
    buf.writeln('─' * 24);
    buf.writeln('${s.grandTotal}: ${fmtAmount(result.grandTotal, bill.currency)}');
    if (bill.extras.vatPct > 0)
      buf.writeln('VAT ${bill.extras.vatPct}%: ${fmtAmount(result.vatAmount, bill.currency)}');
    if (bill.extras.servicePct > 0)
      buf.writeln('Service ${bill.extras.servicePct}%: ${fmtAmount(result.serviceAmount, bill.currency)}');
    if (bill.extras.tipPct > 0)
      buf.writeln('Tip ${bill.extras.tipPct}%: ${fmtAmount(result.tipAmount, bill.currency)}');
    buf.writeln();
    buf.writeln(s.shareFooter);
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final s          = ref.watch(stringsProvider);
    final accent     = isDark ? AppTheme.darkAccent     : AppTheme.lightAccent;
    final accentDark = isDark ? AppTheme.darkAccentDark : AppTheme.lightAccentDark;
    final textHint   = isDark ? AppTheme.darkTextHint   : AppTheme.lightTextHint;
    final textMuted  = isDark ? AppTheme.darkTextMuted  : AppTheme.lightTextMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1D30) : const Color(0xFFEEF4FB),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grand total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.grandTotal, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                Text(fmtAmount(result.grandTotal, bill.currency),
                  style: TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w800, color: accent)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Text(s.perPerson, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: textHint, letterSpacing: .7)),
          const SizedBox(height: 8),

          ...result.personResults.map((pr) =>
            _PersonBlock(pr: pr, bill: bill, isDark: isDark, s: s)),

          const SizedBox(height: 8),
          Row(children: [
            _Btn(
              label: s.copy, icon: Icons.copy_rounded,
              primary: true, accentDark: accentDark, textMuted: textMuted,
              onTap: () {
                Clipboard.setData(ClipboardData(text: _buildShareText(s)));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.copied),
                    duration: const Duration(seconds: 2)));
              },
            ),
            const SizedBox(width: 7),
            _Btn(
              label: s.share, icon: Icons.share_rounded,
              accentDark: accentDark, textMuted: textMuted,
              onTap: () => Share.share(
                _buildShareText(s),
                subject: 'Bill Split — ${bill.merchant}'),
            ),
            const SizedBox(width: 7),
            _Btn(
              label: s.newBill, icon: Icons.refresh_rounded,
              accentDark: accentDark, textMuted: textMuted,
              onTap: () => ref.read(chatProvider.notifier).reset(),
            ),
          ]),
        ],
      ),
    );
  }
}

class _PersonBlock extends StatelessWidget {
  final PersonResult pr;
  final Bill bill;
  final bool isDark;
  final S s;

  const _PersonBlock({
    required this.pr, required this.bill,
    required this.isDark, required this.s});

  @override
  Widget build(BuildContext context) {
    final accent    = isDark ? AppTheme.darkAccent    : AppTheme.lightAccent;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final textHint  = isDark ? AppTheme.darkTextHint  : AppTheme.lightTextHint;
    final cardBg    = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.03);

    final pct = (pr.itemsSubtotal /
        (bill.subtotal == 0 ? 1 : bill.subtotal) * 100)
        .toStringAsFixed(1);

    final myItems = bill.items.where((it) =>
      it.personIds.isEmpty
          ? bill.people.map((p) => p.id).contains(pr.person.id)
          : it.personIds.contains(pr.person.id)
    ).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: pr.person.color.withValues(alpha: 0.15),
            child: Text(pr.person.name.characters.first.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: pr.person.color)),
          ),
          const SizedBox(width: 8),
          Text(pr.person.name, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
          const Spacer(),
          Text(fmtAmount(pr.total, bill.currency),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
              color: accent)),
        ]),
        ...myItems.map((it) {
          final assigned = it.personIds.isEmpty
              ? bill.people.map((p) => p.id).toList()
              : it.personIds;
          final share  = it.price / assigned.length;
          final isShared = assigned.length > 1;
          return _Line(
            label: it.name + (isShared ? ' (${s.shared})' : ''),
            value: fmtAmount(share, bill.currency),
            color: textMuted,
          );
        }),
        if (pr.vatShare > 0)
          _Line(
            label: 'VAT ${bill.extras.vatPct.toStringAsFixed(0)}% × $pct%',
            value: fmtAmount(pr.vatShare, bill.currency),
            color: textHint),
        if (pr.serviceShare > 0)
          _Line(
            label: 'Service ${bill.extras.servicePct.toStringAsFixed(0)}% × $pct%',
            value: fmtAmount(pr.serviceShare, bill.currency),
            color: textHint),
        if (pr.tipShare > 0)
          _Line(
            label: 'Tip ${bill.extras.tipPct.toStringAsFixed(0)}% × $pct%',
            value: fmtAmount(pr.tipShare, bill.currency),
            color: textHint),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Line({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(label, style: TextStyle(fontSize: 11, color: color))),
        Text(value, style: TextStyle(fontSize: 11, color: color)),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label; final IconData icon;
  final VoidCallback onTap; final bool primary;
  final Color accentDark, textMuted;
  const _Btn({required this.label, required this.icon, required this.onTap,
    required this.accentDark, required this.textMuted, this.primary = false});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: primary ? accentDark : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(9),
          border: primary ? null : Border.all(color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: primary ? Colors.white : textMuted),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: primary ? Colors.white : textMuted)),
        ]),
      ),
    ));
  }
}
