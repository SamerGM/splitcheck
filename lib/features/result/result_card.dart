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
import '../../core/services/settings_provider.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/strings.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';
import '../flow/flow_controller.dart';

class ResultCard extends ConsumerStatefulWidget {
  final SplitResult result;
  final Bill bill;
  const ResultCard({super.key, required this.result, required this.bill});
  @override ConsumerState<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends ConsumerState<ResultCard> {
  final _shareKey = GlobalKey();

  SplitResult get result => widget.result;
  Bill get bill => widget.bill;

  String _fmt(S s, double v) {
    final str = fmtAmount(v, bill.currency, arabic: s.isAr);
    return s.isAr ? toArabicDigits(str) : str;
  }

  List<BillItem> _itemsOf(Person person) => bill.items.where((it) {
    final valid = it.personIds.where((id) => bill.people.any((p) => p.id == id)).toList();
    return valid.isEmpty || valid.contains(person.id);
  }).toList();

  int _splitCount(BillItem it) {
    final valid = it.personIds.where((id) => bill.people.any((p) => p.id == id)).length;
    return valid == 0 ? bill.people.length : valid;
  }

  String _shareText(S s) {
    final buf = StringBuffer()
      ..writeln('🧾 ${s.billWord}')
      ..writeln();
    for (final pr in result.personResults) {
      buf.writeln('${pr.person.name}: ${_fmt(s, pr.total)}');
      for (final it in _itemsOf(pr.person)) {
        buf.writeln('   • ${it.name} ${_fmt(s, it.price / _splitCount(it))}');
      }
      if (pr.discountShare > 0) buf.writeln('   • ${s.discountLabel} −${_fmt(s, pr.discountShare)}');
      if (pr.vatShare > 0)      buf.writeln('   • ${s.vatLabel} ${_fmt(s, pr.vatShare)}');
      if (pr.serviceShare > 0)  buf.writeln('   • ${s.serviceLabel} ${_fmt(s, pr.serviceShare)}');
      if (pr.tipShare > 0)      buf.writeln('   • ${s.tipLabel} ${_fmt(s, pr.tipShare)}');
      if (pr.deliveryShare > 0) buf.writeln('   • ${s.deliveryLabel} ${_fmt(s, pr.deliveryShare)}');
    }
    buf
      ..writeln()
      ..writeln('${s.grandTotal}: ${_fmt(s, result.grandTotal)}')
      ..writeln(s.shareFooter);
    return buf.toString();
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
                Text(s.appName, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: p.label)),
                const Spacer(),
                Text(_dateLabel(s), style: TextStyle(fontSize: 13, color: p.secondary)),
              ]),
              const SizedBox(height: 18),
              Text(s.grandTotal, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.secondary)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(_fmt(s, result.grandTotal), style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1.2, color: p.label)),
              ),
              const SizedBox(height: 16),
              for (final pr in result.personResults)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Avatar(person: pr.person, size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Text(pr.person.name, style: TextStyle(
                      fontSize: 17, letterSpacing: -0.4, color: p.label))),
                    Text(_fmt(s, pr.total), style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: p.label,
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
          const SizedBox(width: 10),
          Expanded(child: _Action(icon: CupertinoIcons.plus, label: s.newBill,
              onTap: () { HapticFeedback.mediumImpact(); ref.read(chatProvider.notifier).reset(); })),
        ]),

        const SizedBox(height: 22),

        // ── Per-person breakdown ────────────────────────────────────────────
        InsetGroup(
          header: s.breakdown,
          children: [
            for (final pr in result.personResults)
              _PersonRow(pr: pr, items: _itemsOf(pr.person), splitCount: _splitCount, fmt: (v) => _fmt(s, v), s: s),
          ],
        ),
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
  final PersonResult pr;
  final List<BillItem> items;
  final int Function(BillItem) splitCount;
  final String Function(double) fmt;
  final S s;
  const _PersonRow({required this.pr, required this.items, required this.splitCount, required this.fmt, required this.s});
  @override State<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<_PersonRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p  = Palette.of(context);
    final pr = widget.pr;
    final s  = widget.s;

    Widget line(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: color ?? p.secondary))),
        Text(value, style: TextStyle(fontSize: 15, color: color ?? p.secondary,
            fontFeatures: const [ui.FontFeature.tabularFigures()])),
      ]),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () { HapticFeedback.selectionClick(); setState(() => _open = !_open); },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Column(children: [
          Row(children: [
            Avatar(person: pr.person, size: 34),
            const SizedBox(width: 12),
            Expanded(child: Text(pr.person.name, style: TextStyle(fontSize: 17, letterSpacing: -0.4, color: p.label))),
            Text(widget.fmt(pr.total), style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: p.label)),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: _open ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(CupertinoIcons.chevron_right, size: 16, color: p.tertiary),
            ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open ? const SizedBox(width: double.infinity) : Padding(
              padding: const EdgeInsetsDirectional.only(start: 46, top: 4),
              child: Column(children: [
                for (final it in widget.items)
                  line(widget.splitCount(it) > 1 ? '${it.name} · ${s.sharedTag} ÷${widget.splitCount(it)}' : it.name,
                      widget.fmt(it.price / widget.splitCount(it))),
                if (pr.discountShare > 0) line(s.discountLabel, '−${widget.fmt(pr.discountShare)}', color: p.green),
                if (pr.vatShare > 0)      line(s.vatLabel, widget.fmt(pr.vatShare)),
                if (pr.serviceShare > 0)  line(s.serviceLabel, widget.fmt(pr.serviceShare)),
                if (pr.tipShare > 0)      line(s.tipLabel, widget.fmt(pr.tipShare)),
                if (pr.deliveryShare > 0) line(s.deliveryLabel, widget.fmt(pr.deliveryShare)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
