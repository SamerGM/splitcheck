// lib/features/result/result_card.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/services/bill_breakdown.dart';
import '../../core/services/share_text.dart';
import '../../core/services/settings_provider.dart';
import '../../core/utils/strings.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';

class ResultCard extends ConsumerStatefulWidget {
  final SplitResult result;
  final Bill bill;
  /// Shown as a third action button when set.
  final VoidCallback? onNewBill;
  final bool showNewBill;
  const ResultCard({super.key, required this.result, required this.bill, this.showNewBill = false, this.onNewBill});
  @override ConsumerState<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends ConsumerState<ResultCard> {
  final _shareKey = GlobalKey();

  SplitResult get result => widget.result;
  Bill get bill => widget.bill;

  late BillBreakdown _bd = BillBreakdown.of(bill, result);

  @override
  void didUpdateWidget(covariant ResultCard old) {
    super.didUpdateWidget(old);
    if (old.bill != bill || old.result != result) _bd = BillBreakdown.of(bill, result);
  }

  ShareFormatter _f(S s) => ShareFormatter(_bd, s);
  String _shareText(S s) => _f(s).full();
  String _personText(S s, PersonBreakdown pb) => _f(s).forPerson(pb);

  /// Rows for the in-app breakdown of one person: (label, value, grey hint).
  List<(String, String, String?)> _rows(S s, PersonBreakdown pb) {
    final f = _f(s);
    final n = s.n(_bd.count);
    return [
      for (final l in pb.items)
        (f.itemLabel(l, pb), f.money(l.total),
         (_bd.hasVat || _bd.hasService || l.discount >= 0.005)
            ? [f.num(l.base),
               if (l.discount >= 0.005) '− ${f.num(l.discount)} ${s.discountLabel}',
               if (_bd.hasVat) '+ ${f.num(l.vat)} ${s.vatLabel}',
               if (_bd.hasService) '+ ${f.num(l.service)} ${s.serviceLabel}'].join(' ')
            : null),
      if (_bd.deliveryFee > 0) ('${s.deliveryFeeLabel} ÷$n', f.money(pb.delivery), null),
      if (_bd.tipAmount > 0) ('${s.tipLabel} ÷$n', f.money(pb.tip), null),
      if (pb.roundUp > 0) (s.roundUpRow, '+${f.money(pb.roundUp)}', null),
    ];
  }

  Future<void> _share(S s) async {
    HapticFeedback.lightImpact();
    try {
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('no boundary');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('no bytes');
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/splitcheck_result.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)], text: _shareText(s), subject: s.billWord));
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: _shareText(s), subject: s.billWord));
    }
  }

  Future<void> _sendTo(S s, PersonBreakdown pb) async {
    HapticFeedback.lightImpact();
    await SharePlus.instance.share(ShareParams(text: _personText(s, pb), subject: s.billWord));
  }

  Future<void> _copy(S s) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: _shareText(s)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 20),
          const SizedBox(width: 8), Text(s.copied),
        ]),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final p = Palette.of(context);
    final hasPhoto = bill.receiptPath != null && File(bill.receiptPath!).existsSync();
    final f = _f(s);

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Summary card (this is what gets shared as an image) ─────────────
        RepaintBoundary(
          key: _shareKey,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: p.isDark ? null : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const AppGlyph(size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(bill.merchant.isNotEmpty ? bill.merchant : s.appName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: p.label)),
                ),
                Text(_dateLabel(s), style: TextStyle(fontSize: 13, color: p.secondary)),
              ]),
              const SizedBox(height: 18),
              _SummaryHeader(f: f),
              const SizedBox(height: 14),
              _TotalsBox(f: f),
              const SizedBox(height: 10),
              for (final pb in _bd.people)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Avatar(person: pb.person, size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(pb.person.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 17, letterSpacing: -0.4, color: p.label)),
                      if (f.cardWorking(pb).isNotEmpty)
                        Text(f.cardWorking(pb), style: TextStyle(fontSize: 12.5, color: p.secondary, height: 1.3)),
                    ])),
                    const SizedBox(width: 8),
                    Text(f.amount(pb.rounded), style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: p.label,
                      fontFeatures: const [ui.FontFeature.tabularFigures()])),
                  ]),
                ),
              const SizedBox(height: 10),
              Center(child: Text(s.shareFooter, style: TextStyle(fontSize: 12, color: p.tertiary))),
            ]),
          ),
        ),

        const SizedBox(height: 16),

        // ── Actions ─────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _Action(icon: CupertinoIcons.square_arrow_up, label: s.share, onTap: () => _share(s))),
          const SizedBox(width: 10),
          Expanded(child: _Action(icon: CupertinoIcons.doc_on_doc, label: s.copy, onTap: () => _copy(s))),
          if (widget.showNewBill && widget.onNewBill != null) ...[
            const SizedBox(width: 10),
            Expanded(child: _Action(icon: CupertinoIcons.plus, label: s.newBill,
                onTap: () { HapticFeedback.mediumImpact(); widget.onNewBill?.call(); })),
          ],
        ]),

        const SizedBox(height: 22),

        // ── Per-person breakdown ────────────────────────────────────────────
        InsetGroup(
          header: s.breakdown,
          children: [
            for (final pb in _bd.people)
              _PersonRow(
                person: pb.person,
                amount: f.amount(pb.rounded),
                rows: _rows(s, pb),
                sendLabel: s.sendToPerson,
                onSend: () => _sendTo(s, pb),
              ),
          ],
        ),

        if (hasPhoto) ...[
          const SizedBox(height: 22),
          ReceiptThumb(path: bill.receiptPath!, title: s.receiptPhoto),
        ],
      ]),
    );
  }

  String _dateLabel(S s) {
    final d = bill.date;
    final str = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return s.isAr ? toArabicDigits(str) : str;
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(icon, color: p.accent, size: 22),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.accent)),
        ]),
      ),
    );
  }
}

class _PersonRow extends StatefulWidget {
  final Person person;
  final String amount;
  final List<(String, String, String?)> rows;
  final String sendLabel;
  final VoidCallback onSend;
  const _PersonRow({required this.person, required this.amount, required this.rows,
      required this.sendLabel, required this.onSend});
  @override State<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<_PersonRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p  = Palette.of(context);

    Widget line((String, String, String?) r) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(r.$1, style: TextStyle(fontSize: 15, color: p.secondary))),
          const SizedBox(width: 8),
          Text(r.$2, style: TextStyle(fontSize: 15, color: p.secondary,
              fontFeatures: const [ui.FontFeature.tabularFigures()])),
        ]),
        if (r.$3 != null)
          Text(r.$3!, style: TextStyle(fontSize: 12.5, color: p.tertiary)),
      ]),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () { HapticFeedback.selectionClick(); setState(() => _open = !_open); },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Column(children: [
          Row(children: [
            Avatar(person: widget.person, size: 34),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.person.name, style: TextStyle(fontSize: 17, letterSpacing: -0.4, color: p.label))),
            Text(widget.amount, style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: p.label)),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: _open ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(CupertinoIcons.chevron_forward, size: 16, color: p.tertiary),
            ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open ? const SizedBox(width: double.infinity) : Padding(
              padding: const EdgeInsetsDirectional.only(start: 46, top: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final r in widget.rows) line(r),
                const SizedBox(height: 10),
                PressableScale(
                  onTap: widget.onSend,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: p.isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(CupertinoIcons.paperplane_fill, size: 15, color: p.accent),
                      const SizedBox(width: 6),
                      Text('${widget.sendLabel} · ${widget.person.name}', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: p.accent)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// "Grand total after all additions + round-up" and the big whole number.
class _SummaryHeader extends StatelessWidget {
  final ShareFormatter f;
  const _SummaryHeader({required this.f});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final b = f.b;
    final full = f.amount(b.grandTotal);
    final i = full.lastIndexOf(' ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(f.grandLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.secondary)),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text.rich(TextSpan(children: [
          TextSpan(text: full.substring(0, i), style: TextStyle(
              fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: -1.3, color: p.label)),
          TextSpan(text: ' ${full.substring(i + 1)}', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, color: p.secondary)),
        ])),
      ),
    ]);
  }
}

/// Total after VAT → + delivery → + tip → + round-up → Grand total (only rows that exist).
class _TotalsBox extends StatelessWidget {
  final ShareFormatter f;
  const _TotalsBox({required this.f});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final b = f.b;
    final s = f.s;
    Widget row(String l, String v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(l, style: TextStyle(fontSize: bold ? 15 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: bold ? p.label : p.secondary))),
        Text(v, style: TextStyle(fontSize: bold ? 15 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: p.label, fontFeatures: const [ui.FontFeature.tabularFigures()])),
      ]),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        row(f.totalAfterVatLabel, f.money(b.totalAfterVat)),
        if (b.deliveryFee > 0) row('+ ${s.deliveryFeeLabel}', f.num(b.deliveryFee)),
        if (b.tipAmount > 0) row('+ ${s.tipLabel}', f.num(b.tipAmount)),
        if (b.roundUp > 0) row('+ ${s.roundUpRow}', f.num(b.roundUp)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 1, thickness: .5, color: p.separator),
        ),
        row(s.grandTotalWord, f.amount(b.grandTotal), bold: true),
      ]),
    );
  }
}

/// Small preview of the scanned receipt; tap to view full screen.
class ReceiptThumb extends StatelessWidget {
  final String path;
  final String title;
  const ReceiptThumb({super.key, required this.path, required this.title});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return InsetGroup(header: title, children: [
      GestureDetector(
        onTap: () => Navigator.of(context).push(CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
            body: Center(child: InteractiveViewer(maxScale: 5, child: Image.file(File(path)))),
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: p.fill,
              height: 180,
              width: double.infinity,
              child: Image.file(File(path), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(CupertinoIcons.photo, color: p.tertiary)),
            ),
          ),
        ),
      ),
    ]);
  }
}
