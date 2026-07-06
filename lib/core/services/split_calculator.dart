// lib/core/services/split_calculator.dart
import '../models/models.dart';

/// Pure calculation — no Flutter, no async, no dependencies.
/// Proportional allocation: whoever spent more on items pays more extras.
class SplitCalculator {
  static SplitResult calculate(Bill bill) {
    final people  = bill.people;
    final items   = bill.items;
    final extras  = bill.extras;
    final sub     = bill.subtotal;

    // ── Step 1: per-person item subtotals ──
    final Map<String, double> personSubs = {for (final p in people) p.id: 0.0};

    for (final item in items) {
      final assigned = item.personIds.isEmpty
          ? people.map((p) => p.id).toList()
          : item.personIds;
      final perPerson = item.price / assigned.length;
      for (final pid in assigned) {
        if (personSubs.containsKey(pid)) {
          personSubs[pid] = personSubs[pid]! + perPerson;
        }
      }
    }

    // ── Step 2: extras amounts ──
    final vatAmt  = extras.vatAmount(sub);
    final svcAmt  = extras.serviceAmount(sub);
    final tipAmt  = extras.tipAmount(sub);

    // ── Step 3: proportional allocation ──
    final totalSub = personSubs.values.fold(0.0, (a, b) => a + b);

    final List<PersonResult> results = people.map((p) {
      final pSub  = personSubs[p.id] ?? 0.0;
      final ratio = totalSub > 0 ? pSub / totalSub : 1.0 / people.length;
      return PersonResult(
        person:         p,
        itemsSubtotal:  pSub,
        vatShare:       vatAmt * ratio,
        serviceShare:   svcAmt * ratio,
        tipShare:       tipAmt * ratio,
        total:          pSub + (vatAmt + svcAmt + tipAmt) * ratio,
      );
    }).toList();

    return SplitResult(
      subtotal:      sub,
      vatAmount:     vatAmt,
      serviceAmount: svcAmt,
      tipAmount:     tipAmt,
      grandTotal:    bill.grandTotal,
      personResults: results,
    );
  }
}
