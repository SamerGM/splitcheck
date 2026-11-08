// lib/core/services/split_calculator.dart
import 'dart:math' as math;

import '../models/models.dart';
import '../utils/currency.dart';

/// Pure calculation — no Flutter, no async, no dependencies.
/// Proportional allocation: whoever ordered more pays more of the discount,
/// VAT and service. The delivery fee and the tip are split equally between
/// everyone ("÷3 persons").
///
/// Person totals are rounded to the currency's smallest unit (cents, fils)
/// so they always add up exactly to the grand total, or rounded *up* to
/// [BillExtras.roundUpTo] when that option is on.
class SplitCalculator {
  static SplitResult calculate(Bill bill) {
    final people = bill.people;
    final extras = bill.extras;
    final sub    = bill.subtotal;
    final allIds = people.map((p) => p.id).toList();

    // ── Step 1: per-person item subtotals ──
    final Map<String, double> personSubs = {for (final p in people) p.id: 0.0};

    for (final item in bill.items) {
      // Only keep IDs that still belong to someone on the bill; if none are
      // left (e.g. a person was removed) the item falls back to "everyone",
      // so no money silently disappears from the split.
      final valid = item.personIds.where(personSubs.containsKey).toList();
      final assigned = valid.isEmpty ? allIds : valid;
      if (assigned.isEmpty) continue;
      // Portions: "Ahmed had 2 slices, Sara 1" → 2/3 and 1/3.
      final weights = {for (final id in assigned) id: math.max(1, item.portionsOf(id))};
      final totalWeight = weights.values.fold(0, (a, b) => a + b);
      for (final pid in assigned) {
        personSubs[pid] = personSubs[pid]! + item.price * weights[pid]! / totalWeight;
      }
    }

    // ── Step 2: bill-level amounts ──
    final discAmt  = extras.discountAmount(sub);
    final vatAmt   = extras.vatAmount(sub);
    final svcAmt   = extras.serviceAmount(sub);
    final tipAmt   = extras.tipAmount(sub);
    final delivery = people.isEmpty ? 0.0 : extras.deliveryFee / people.length;
    final tipEach  = people.isEmpty ? 0.0 : tipAmt / people.length;

    // ── Step 3: proportional allocation ──
    final totalSub = personSubs.values.fold(0.0, (a, b) => a + b);
    final exact = <double>[];
    final shares = <(double, double, double, double, double)>[];
    for (final p in people) {
      final pSub  = personSubs[p.id] ?? 0.0;
      final ratio = totalSub > 0 ? pSub / totalSub : 1.0 / people.length;
      final s = (discAmt * ratio, vatAmt * ratio, svcAmt * ratio, tipEach, delivery);
      shares.add(s);
      exact.add(pSub - s.$1 + s.$2 + s.$3 + s.$4 + s.$5);
    }

    // ── Step 4: rounding ──
    final exactGrand = bill.grandTotal;
    final decimals   = currencyDecimals(bill.currency);
    final rounded    = extras.roundUpTo > 0
        ? _roundUp(exact, extras.roundUpTo, decimals)
        : _roundToUnit(exact, exactGrand, decimals);
    final grand = rounded.fold(0.0, (a, b) => a + b);

    final results = [
      for (var i = 0; i < people.length; i++)
        PersonResult(
          person:        people[i],
          itemsSubtotal: personSubs[people[i].id] ?? 0.0,
          discountShare: shares[i].$1,
          vatShare:      shares[i].$2,
          serviceShare:  shares[i].$3,
          tipShare:      shares[i].$4,
          deliveryShare: shares[i].$5,
          total:         rounded[i],
        ),
    ];

    return SplitResult(
      subtotal:       sub,
      discountAmount: discAmt,
      vatAmount:      vatAmt,
      serviceAmount:  svcAmt,
      tipAmount:      tipAmt,
      deliveryFee:    extras.deliveryFee,
      roundingExtra:  extras.roundUpTo > 0 ? _fix(grand - exactGrand, decimals) : 0,
      grandTotal:     extras.roundUpTo > 0 ? _fix(grand, decimals) : _fix(exactGrand, decimals),
      personResults:  results,
    );
  }

  static double _fix(double v, int decimals) =>
      double.parse(v.toStringAsFixed(decimals));

  /// Largest-remainder rounding: each share rounded to the smallest currency
  /// unit, and the leftover cents go to whoever had the biggest fractions,
  /// so the shares add up exactly to the (rounded) grand total.
  static List<double> _roundToUnit(List<double> exact, double grand, int decimals) {
    if (exact.isEmpty) return const [];
    final f = math.pow(10, decimals).toDouble();
    final units = [for (final e in exact) (e * f + 1e-7).floor()];
    var leftover = (grand * f).round() - units.fold(0, (a, b) => a + b);
    final order = List.generate(exact.length, (i) => i)
      ..sort((a, b) => (exact[b] * f - units[b]).compareTo(exact[a] * f - units[a]));
    for (var k = 0; leftover > 0 && k < order.length * 2; k++, leftover--) {
      units[order[k % order.length]]++;
    }
    return [for (final u in units) u / f];
  }

  /// Rounds each share up to the next multiple of [step] (e.g. 1 or 5).
  static List<double> _roundUp(List<double> exact, double step, int decimals) => [
    for (final e in exact) _fix((e / step - 1e-9).ceil() * step, decimals),
  ];
}
