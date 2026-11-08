// lib/core/services/bill_breakdown.dart
//
// Per-person working used by the share text, the share card and the in-app
// breakdown, so all three always show the same numbers:
//   items (+ VAT / service, − discount) + delivery share + tip share
//   = exact total → rounded up (when "whole numbers" is on).
import '../models/models.dart';
import 'split_calculator.dart';

class ItemLine {
  final BillItem item;
  final int splitBetween;   // people sharing it (1 = only this person)
  final double base;        // this person's part of the price
  final double discount;    // their part of the discount (positive)
  final double vat;
  final double service;
  final int myPortions, totalPortions;   // e.g. 2 of 3 slices
  double get total => base - discount + vat + service;
  bool get unequal => splitBetween > 1 && myPortions * splitBetween != totalPortions;
  const ItemLine(this.item, this.splitBetween, this.base, this.discount, this.vat, this.service,
      [this.myPortions = 1, this.totalPortions = 1]);
}

class PersonBreakdown {
  final PersonResult result;
  final List<ItemLine> items;
  final double delivery;    // equal share
  final double tip;         // equal share
  final bool wholeNumbers;  // round-up is on
  const PersonBreakdown(this.result, this.items, this.delivery, this.tip, this.wholeNumbers);

  Person get person => result.person;
  double get exact => items.fold(0.0, (a, l) => a + l.total) + delivery + tip;
  double get rounded => result.total;
  double get roundUp => !wholeNumbers || (rounded - exact) < 0.005 ? 0 : rounded - exact;
}

class BillBreakdown {
  final Bill bill;
  final SplitResult result;
  final List<PersonBreakdown> people;
  const BillBreakdown._(this.bill, this.result, this.people);

  bool get wholeNumbers => bill.extras.roundUpTo > 0;
  int get count => bill.people.length;

  /// Items + VAT + service − discount (before delivery, tip and round-up).
  double get totalAfterVat => people.fold(0.0, (a, p) => a + p.items.fold(0.0, (b, l) => b + l.total));
  double get deliveryFee => bill.extras.deliveryFee;
  double get tipAmount => result.tipAmount;
  /// Whatever the round-up added on top, so the rows always add up to the grand total.
  double get roundUp {
    if (!wholeNumbers) return 0;
    final v = grandTotal - totalAfterVat - deliveryFee - tipAmount;
    return v < 0.005 ? 0 : v;
  }
  bool get hasVat => bill.extras.vatPct > 0;
  bool get hasService => bill.extras.servicePct > 0;
  double get grandTotal => result.grandTotal;

  factory BillBreakdown.of(Bill bill, [SplitResult? result]) {
    final r = result ?? SplitCalculator.calculate(bill);
    final ext = bill.extras;
    final sub = bill.subtotal;
    final discRatio = sub > 0 ? ext.discountAmount(sub) / sub : 0.0;
    final n = bill.people.length;
    final ids = bill.people.map((p) => p.id).toSet();

    final list = <PersonBreakdown>[];
    for (final pr in r.personResults) {
      final lines = <ItemLine>[];
      for (final it in bill.items) {
        final valid = it.personIds.where(ids.contains).toList();
        final assigned = valid.isEmpty ? bill.people.map((p) => p.id).toList() : valid;
        if (!assigned.contains(pr.person.id)) continue;
        final weights = {for (final id in assigned) id: it.portionsOf(id).clamp(1, 1000)};
        final total = weights.values.fold<int>(0, (a, b) => a + b);
        final base = it.price * weights[pr.person.id]! / total;
        final afterDisc = base * (1 - discRatio);
        lines.add(ItemLine(it, assigned.length, base, base * discRatio,
            afterDisc * ext.vatPct / 100, afterDisc * ext.servicePct / 100,
            weights[pr.person.id]!, total));
      }
      list.add(PersonBreakdown(pr, lines, n == 0 ? 0 : ext.deliveryFee / n, n == 0 ? 0 : r.tipAmount / n, ext.roundUpTo > 0));
    }
    return BillBreakdown._(bill, r, list);
  }
}
