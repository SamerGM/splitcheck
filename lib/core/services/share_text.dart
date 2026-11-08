// lib/core/services/share_text.dart
//
// The text that goes out when a split is shared (WhatsApp etc.), plus the
// short lines used on the share card. Pure Dart so it can be unit-tested.
//
//   🧾 Bill split
//
//   *Samer*: 170 AED
//     • Beef plate: 100.00 AED + 5.00 AED "VAT" = 105.00 AED
//     • Pizza · Shared ÷3: 50.00 AED + 2.50 AED "VAT" = 52.50 AED
//     • Delivery fee 15 AED ÷3 "Persons": 5.00 AED
//     • Tip 20 AED ÷3 "Persons": 6.67 AED
//     Total: 169.17 AED (105.00 + 52.50 + 5.00 + 6.67) + 0.83 AED "round-up" = 170 AED
//   …
//   Total after VAT: 7081.20 AED
//   *Grand total after all additions + round-up: 7118 AED*
//
//   Split with SplitCheck
import '../utils/currency.dart';
import '../utils/strings.dart';
import 'bill_breakdown.dart';

class ShareFormatter {
  final BillBreakdown b;
  final S s;
  ShareFormatter(this.b, this.s);

  String get _cur => s.isAr
      ? currencySymbol(b.bill.currency, arabic: true)
      : b.bill.currency;
  int get _dec => currencyDecimals(b.bill.currency);
  String _d(String v) => s.isAr ? toArabicDigits(v) : v;

  /// 12.50
  String num(double v) => _d(v.toStringAsFixed(_dec));
  /// 12.50 AED
  String money(double v) => '${num(v)} $_cur';
  /// 170 AED
  String whole(double v) => '${_d(v.round().toString())} $_cur';
  /// 15 AED, or 15.50 AED when it has decimals.
  String compact(double v) => (v - v.roundToDouble()).abs() < 0.005 ? whole(v) : money(v);
  /// A person's or the bill's final amount: whole numbers when round-up is on.
  String amount(double v) => b.wholeNumbers ? whole(v) : money(v);

  String _q(String word) => '"$word"';

  String itemLabel(ItemLine l, PersonBreakdown pb) {
    final it = l.item;
    final label = s.itemLabel(it.name, it.quantity);
    if (l.unequal) return '$label · ${s.n(l.myPortions)}/${s.n(l.totalPortions)}';
    return l.splitBetween > 1 ? '$label · ${s.sharedTag} ÷${s.n(l.splitBetween)}' : label;
  }

  String itemLine(ItemLine l, PersonBreakdown pb) {
    final parts = StringBuffer(money(l.base));
    var extra = false;
    if (l.discount >= 0.005) { parts.write(' − ${money(l.discount)} ${_q(s.discountLabel)}'); extra = true; }
    if (b.hasVat)            { parts.write(' + ${money(l.vat)} ${_q(s.vatLabel)}'); extra = true; }
    if (b.hasService)        { parts.write(' + ${money(l.service)} ${_q(s.serviceLabel)}'); extra = true; }
    if (extra) parts.write(' = ${money(l.total)}');
    return '  • ${itemLabel(l, pb)}: $parts';
  }

  String get _n => s.n(b.count);

  List<String> personLines(PersonBreakdown pb) => [
    for (final l in pb.items) itemLine(l, pb),
    if (b.deliveryFee > 0)
      '  • ${s.deliveryFeeLabel} ${compact(b.deliveryFee)} ÷$_n ${_q(s.personsWord)}: ${money(pb.delivery)}',
    if (b.tipAmount > 0)
      '  • ${s.tipLabel} ${compact(b.tipAmount)} ÷$_n ${_q(s.personsWord)}: ${money(pb.tip)}',
    totalLine(pb),
  ];

  String totalLine(PersonBreakdown pb) {
    final parts = [
      for (final l in pb.items) num(l.total),
      if (b.deliveryFee > 0) num(pb.delivery),
      if (b.tipAmount > 0) num(pb.tip),
    ];
    final buf = StringBuffer('  ${s.totalWord}: ${money(pb.exact)}');
    if (parts.length > 1) buf.write(' (${parts.join(' + ')})');
    if (pb.roundUp > 0) buf.write(' + ${money(pb.roundUp)} ${_q(s.roundUpWord)} = ${whole(pb.rounded)}');
    return buf.toString();
  }

  String get totalAfterVatLabel => b.hasVat ? s.totalAfterVat : s.itemsTotalLabel;
  String get grandLabel => b.wholeNumbers ? s.grandTotalAll : s.grandTotalWord;

  /// Full message for the whole group.
  String full() {
    final place = b.bill.merchant.trim();
    final buf = StringBuffer('🧾 ${s.billWord}${place.isEmpty ? '' : ' · $place'}\n\n');
    for (final pb in b.people) {
      buf.writeln('*${pb.person.name}*: ${amount(pb.rounded)}');
      for (final l in personLines(pb)) { buf.writeln(l); }
      buf.writeln();
    }
    buf
      ..writeln('$totalAfterVatLabel: ${money(b.totalAfterVat)}')
      ..writeln('*$grandLabel: ${amount(b.grandTotal)}*')
      ..writeln()
      ..write(s.shareFooter);
    return buf.toString();
  }

  /// Message for one person ("Send" next to their name).
  String forPerson(PersonBreakdown pb) => [
    s.personMessage(pb.person.name, amount(pb.rounded), b.bill.merchant.trim()),
    '',
    ...personLines(pb),
    '',
    s.shareFooter,
  ].join('\n');

  /// Grey line under a name on the card:
  /// "169.17 + 0.83 round-up · incl. delivery 5.00 + tip 6.67".
  String cardWorking(PersonBreakdown pb) {
    final left = pb.roundUp > 0 ? '${num(pb.exact)} + ${num(pb.roundUp)} ${s.roundUpWord}' : '';
    final incl = [
      if (b.deliveryFee > 0) '${s.deliveryWord} ${num(pb.delivery)}',
      if (b.tipAmount > 0) '${s.tipWord} ${num(pb.tip)}',
    ];
    final right = incl.isEmpty ? '' : '${s.inclWord} ${incl.join(' + ')}';
    return [left, right].where((e) => e.isNotEmpty).join(' · ');
  }
}
