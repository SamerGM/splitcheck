// lib/core/services/split_calculator.dart
import '../models/models.dart';

/// Pure calculation — no Flutter, no async, no dependencies.
/// Proportional allocation: whoever ordered more pays more of the
/// discount, VAT, service and tip.
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
      final perPerson = item.price / assigned.length;
      for (final pid in assigned) {
        personSubs[pid] = personSubs[pid]! + perPerson;
      }
    }

    // ── Step 2: bill-level amounts ──
    final discAmt = extras.discountAmount(sub);
    final vatAmt  = extras.vatAmount(sub);
    final svcAmt  = extras.serviceAmount(sub);
    final tipAmt  = extras.tipAmount(sub);

    // ── Step 3: proportional allocation ──
    final totalSub = personSubs.values.fold(0.0, (a, b) => a + b);

    final results = people.map((p) {
      final pSub  = personSubs[p.id] ?? 0.0;
      final ratio = totalSub > 0 ? pSub / totalSub : 1.0 / people.length;
      final disc  = discAmt * ratio;
      final vat   = vatAmt * ratio;
      final svc   = svcAmt * ratio;
      final tip   = tipAmt * ratio;
      return PersonResult(
        person:        p,
        itemsSubtotal: pSub,
        discountShare: disc,
        vatShare:      vat,
        serviceShare:  svc,
        tipShare:      tip,
        total:         pSub - disc + vat + svc + tip,
      );
    }).toList();

    return SplitResult(
      subtotal:       sub,
      discountAmount: discAmt,
      vatAmount:      vatAmt,
      serviceAmount:  svcAmt,
      tipAmount:      tipAmt,
      grandTotal:     bill.grandTotal,
      personResults:  results,
    );
  }
}
