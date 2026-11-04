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
  /// False when shown from History (there is no chat to restart).
  final bool showNewBill;
  const ResultCard({super.key, required this.result, required this.bill, this.showNewBill = true});
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

  List<String> _assigned(BillItem it) {
    final valid = it.personIds.where((id) => bill.people.any((p) => p.id == id)).toList();
    return valid.isEmpty ? bill.people.map((p) => p.id).toList() : valid;
  }

  List<BillItem> _itemsOf(Person person) =>
      bill.items.where((it) => _assigned(it).contains(person.id)).toList();

  /// This person's part of an item, respecting portions (e.g. 2 of 3 slices).
  double _shareOf(BillItem it, Person person) {
    final ids = _assigned(it);
    final total = ids.fold<int>(0, (a, id) => a + it.portionsOf(id).clamp(1, 1000));
    return it.price * it.portionsOf(person.id).clamp(1, 1000) / total;
  }

  String _itemLine(S s, BillItem it, Person person) {
    final ids = _assigned(it);
    final unequal = ids.any((id) => it.portionsOf(id) > 1);
    if (unequal) {
      // e.g. "Pizza ×3 · 2/3" — this person had 2 of 3 portions.
      final total = ids.fold<int>(0, (a, id) => a + it.portionsOf(id).clamp(1, 1000));
      return '${it.label} · ${it.portionsOf(person.id)}/$total';
    }
    return ids.length > 1 ? '${it.label} · ${s.sharedTag} ÷${ids.length}' : it.label;
  }

  List<String> _personLines(S s, PersonResult pr) => [
    for (final it in _itemsOf(pr.person)) '• ${_itemLine(s, it, pr.person)}: ${_fmt(s, _shareOf(it, pr.person))}',
    if (pr.discountShare > 0) '• ${s.discountLabel}: −${_fmt(s, pr.discountShare)}',
    if (pr.vatShare > 0)      '• ${s.vatLabel}: ${_fmt(s, pr.vatShare)}',
    if (pr.serviceShare > 0)  '• ${s.serviceLabel}: ${_fmt(s, pr.serviceShare)}',
    if (pr.tipShare > 0)      '• ${s.tipLabel}: ${_fmt(s, pr.tipShare)}',
    if (pr.deliveryShare > 0) '• ${s.deliveryLabel}: ${_fmt(s, pr.deliveryShare)}',
  ];

  String _shareText(S s) {
    final buf = StringBuffer()
      ..writeln('🧾 ${bill.merchant.isNotEmpty ? bill.merchant : s.billWord}')
      ..writeln();
    for (final pr in result.personResults) {
      buf.writeln('${pr.person.name}: ${_fmt(s, pr.total)}');
      for (final l in _personLines(s, pr)) { buf.writeln('   $l'); }
    }
    buf
      ..writeln()
      ..writeln('${s.grandTotal}: ${_fmt(s, result.grandTotal)}');
    if (result.roundingExtra > 0) buf.writeln('(${s.roundingLabel} +${_fmt(s, result.roundingExtra)})');
    buf.writeln(s.shareFooter);
    return buf.toString();
  }

  /// A personal message for one person — "Hi Sara 👋 your share is …".
  String _personText(S s, PersonResult pr) => [
    s.personMessage(pr.person.name, _fmt(s, pr.total), bill.merchant),
    '',
    ..._personLines(s, pr),
    '',
    s.shareFooter,
  ].join('\n');

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

  Future<void> _sendTo(S s, PersonResult pr) async {
    HapticFeedback.lightImpact();
    await SharePlus.instance.share(ShareParams(text: _personText(s, pr), subject: s.billWord));
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
              Text(s.grandTotal, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.secondary)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(_fmt(s, result.grandTotal), style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1.2, color: p.label)),
              ),
              if (result.roundingExtra > 0)
                Text('${s.roundingLabel} +${_fmt(s, result.roundingExtra)}',
                    style: TextStyle(fontSize: 13, color: p.secondary)),
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
          if (widget.showNewBill) ...[
            const SizedBox(width: 10),
            Expanded(child: _Action(icon: CupertinoIcons.plus, label: s.newBill,
                onTap: () { HapticFeedback.mediumImpact(); ref.read(chatProvider.notifier).reset(); })),
          ],
        ]),

        const SizedBox(height: 22),

        // ── Per-person breakdown ────────────────────────────────────────────
        InsetGroup(
          header: s.breakdown,
          children: [
            for (final pr in result.personResults)
              _PersonRow(
                pr: pr,
                lines: _personLines(s, pr),
                fmt: (v) => _fmt(s, v),
                sendLabel: s.sendToPerson,
                onSend: () => _sendTo(s, pr),
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
  final PersonResult pr;
  final List<String> lines;
  final String Function(double) fmt;
  final String sendLabel;
  final VoidCallback onSend;
  const _PersonRow({required this.pr, required this.lines, required this.fmt,
      required this.sendLabel, required this.onSend});
  @override State<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<_PersonRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p  = Palette.of(context);
    final pr = widget.pr;

    Widget line(String text) {
      // "• Label: value" → label on the left, value on the right.
      final i = text.lastIndexOf(': ');
      final label = i > 0 ? text.substring(2, i) : text;
      final value = i > 0 ? text.substring(i + 2) : '';
      final isDiscount = value.startsWith('−');
      final color = isDiscount ? p.green : p.secondary;
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: color))),
          Text(value, style: TextStyle(fontSize: 15, color: color,
              fontFeatures: const [ui.FontFeature.tabularFigures()])),
        ]),
      );
    }

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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final l in widget.lines) line(l),
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
                      Text('${widget.sendLabel} · ${pr.person.name}', style: TextStyle(
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
