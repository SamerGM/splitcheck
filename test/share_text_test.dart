// test/share_text_test.dart — the agreed share format, on the 7118 AED example.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitcheck/core/models/models.dart';
import 'package:splitcheck/core/services/bill_breakdown.dart';
import 'package:splitcheck/core/services/share_text.dart';
import 'package:splitcheck/core/utils/strings.dart';

Person p(String id, String name) => Person(id: id, name: name, color: Colors.blue);

Bill example({double vat = 5, double delivery = 15, double tipAed = 20, double roundUp = 1, String currency = 'AED'}) {
  const sub = 6744.0;
  return Bill(
    id: 't', merchant: '', date: DateTime(2026, 11, 8), currency: currency,
    people: [p('s', 'Samer'), p('a', 'Sara'), p('o', 'Omar')],
    items: [
      BillItem(id: '1', name: 'Beef plate', price: 100, personIds: ['s']),
      BillItem(id: '2', name: 'Pizza', price: 150, personIds: []),
      BillItem(id: '3', name: 'Feast', price: 3247, personIds: ['a']),
      BillItem(id: '4', name: 'Feast', price: 3247, personIds: ['o']),
    ],
    extras: BillExtras(vatPct: vat, tipPct: tipAed / sub * 100, deliveryFee: delivery, roundUpTo: roundUp),
  );
}

void main() {
  test('Breakdown adds up: 170 + 3474 + 3474 = 7118 = 7081.20 + 15 + 20 + 1.80', () {
    final b = BillBreakdown.of(example());
    expect(b.people.map((e) => e.rounded).toList(), [170, 3474, 3474]);
    expect(b.grandTotal, 7118);
    expect(b.totalAfterVat, closeTo(7081.20, 0.001));
    expect(b.roundUp, closeTo(1.80, 0.001));
    expect(b.people[0].exact, closeTo(169.17, 0.005));
    expect(b.people[0].delivery, 5);
    expect(b.people[0].tip, closeTo(6.67, 0.005));
  });

  test('English text matches the agreed format', () {
    final t = ShareFormatter(BillBreakdown.of(example()), const S(false)).full();
    expect(t, startsWith('🧾 Bill split\n\n*Samer*: 170 AED\n'));
    expect(t, contains('  • Beef plate: 100.00 AED + 5.00 AED "VAT" = 105.00 AED\n'));
    expect(t, contains('  • Pizza · Shared ÷3: 50.00 AED + 2.50 AED "VAT" = 52.50 AED\n'));
    expect(t, contains('  • Delivery fee 15 AED ÷3 "Persons": 5.00 AED\n'));
    expect(t, contains('  • Tip 20 AED ÷3 "Persons": 6.67 AED\n'));
    expect(t, contains('  Total: 169.17 AED (105.00 + 52.50 + 5.00 + 6.67) + 0.83 AED "round-up" = 170 AED\n\n*Sara*'));
    expect(t, contains('Total after VAT: 7081.20 AED\n*Grand total after all additions + round-up: 7118 AED*\n\nSplit with SplitCheck'));
  });

  test('Omits delivery, tip, round-up and VAT when they are not on the bill', () {
    final t = ShareFormatter(BillBreakdown.of(example(vat: 0, delivery: 0, tipAed: 0, roundUp: 0)), const S(false)).full();
    expect(t, isNot(contains('Delivery')));
    expect(t, isNot(contains('Tip')));
    expect(t, isNot(contains('round-up')));
    expect(t, isNot(contains('"VAT"')));
    expect(t, contains('  • Beef plate: 100.00 AED\n'));
    expect(t, contains('*Samer*: 150.00 AED'));
    expect(t, contains('*Grand total: 6744.00 AED*'));
  });

  test('Arabic text uses Arabic digits and the Arabic currency symbol', () {
    final t = ShareFormatter(BillBreakdown.of(example()), const S(true)).full();
    expect(t, startsWith('🧾 تقسيم الفاتورة\n\n*Samer*: ١٧٠ د.إ\n'));
    expect(t, contains('*الإجمالي النهائي بعد كل الإضافات + التقريب: ٧١١٨ د.إ*'));
  });

  test('Card working line', () {
    final f = ShareFormatter(BillBreakdown.of(example()), const S(false));
    expect(f.cardWorking(f.b.people[0]), '169.17 + 0.83 round-up · incl. delivery 5.00 + tip 6.67');
  });
}
