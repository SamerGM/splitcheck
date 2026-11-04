import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitcheck/core/models/models.dart';
import 'package:splitcheck/core/services/parser_service.dart';
import 'package:splitcheck/core/services/receipt_parser.dart';
import 'package:splitcheck/core/services/split_calculator.dart';

Person p(String id) => Person(id: id, name: id, color: Colors.blue);

Bill bill(List<Person> people, List<BillItem> items, {BillExtras extras = const BillExtras(), String cur = 'USD'}) =>
    Bill(id: 't', merchant: '', date: DateTime(2026), currency: cur, people: people, items: items, extras: extras);

void main() {
  group('Portions (unequal shares)', () {
    test('Ahmed 2 slices, Sara 1 → 2/3 and 1/3', () {
      final r = SplitCalculator.calculate(bill([p('a'), p('b')], [
        const BillItem(id: '1', name: 'Pizza', price: 30, personIds: ['a', 'b'], portions: {'a': 2}),
      ]));
      expect(r.personResults[0].total, 20);
      expect(r.personResults[1].total, 10);
    });

    test('Portions survive JSON round-trip (history)', () {
      const it = BillItem(id: '1', name: 'Cola', price: 10, quantity: 2, personIds: ['a'], portions: {'a': 3});
      final back = BillItem.fromJson(it.toJson());
      expect(back.quantity, 2);
      expect(back.portions, {'a': 3});
      expect(back.label, 'Cola ×2');
    });
  });

  group('Rounding', () {
    test('Shares add up exactly to the cent (10 split 3 ways)', () {
      final r = SplitCalculator.calculate(bill([p('a'), p('b'), p('c')], [
        const BillItem(id: '1', name: 'X', price: 10),
      ]));
      final totals = r.personResults.map((x) => x.total).toList()..sort();
      expect(totals, [3.33, 3.33, 3.34]);
      expect(r.grandTotal, 10.0);
    });

    test('3-decimal currencies (KWD) round to the fils', () {
      final r = SplitCalculator.calculate(bill([p('a'), p('b'), p('c')], [
        const BillItem(id: '1', name: 'X', price: 1),
      ], cur: 'KWD'));
      expect(r.personResults.fold(0.0, (a, x) => a + x.total), closeTo(1.0, 1e-9));
      expect(r.personResults.map((x) => x.total).toSet(), {0.333, 0.334});
    });

    test('Round each share up to 5', () {
      final r = SplitCalculator.calculate(bill([p('a'), p('b')], [
        const BillItem(id: '1', name: 'X', price: 33, personIds: ['a']),
        const BillItem(id: '2', name: 'Y', price: 11, personIds: ['b']),
      ], extras: const BillExtras(roundUpTo: 5)));
      expect(r.personResults[0].total, 35);
      expect(r.personResults[1].total, 15);
      expect(r.grandTotal, 50);
      expect(r.roundingExtra, 6);
    });
  });

  group('Quantity in price', () {
    test('parses 2x15, 2 × 15, ٢×١٥ and plain prices', () {
      expect(parseQuantityPrice('2x15'), (2, 15.0));
      expect(parseQuantityPrice('2 × 15'), (2, 15.0));
      expect(parseQuantityPrice('٢×١٥'), (2, 15.0));
      expect(parseQuantityPrice('3*2.5'), (3, 2.5));
      expect(parseQuantityPrice('40'), (1, 40.0));
      expect(parseQuantityPrice('abc'), isNull);
    });
  });

  group('Receipt parser', () {
    test('English receipt: items, quantity, merchant; skips totals and "Table 12"', () {
      final r = ReceiptParser.parse('''
Cafe Luna
Table 12
2 x Latte      9.00
Croissant ..... 3.50
Water 1.25
Subtotal 13.75
VAT 5% 0.69
TOTAL 14.44
''');
      expect(r.merchant, 'Cafe Luna');
      expect(r.items.map((i) => i.name).toList(), ['Latte', 'Croissant', 'Water']);
      expect(r.items.first.quantity, 2);
      expect(r.items.first.price, 9.0);
    });

    test('Arabic receipt with Arabic digits and price-first lines', () {
      final r = ReceiptParser.parse('''
مطعم الشام
شاورما دجاج ٤٥٫٠٠
٢ × بيبسي ١٢٫٥٠
٣٠٫٠٠ فتوش
الإجمالي ٨٧٫٥٠
ضريبة ١٤٪
''');
      expect(r.merchant, 'مطعم الشام');
      expect(r.items.length, 3);
      expect(r.items[0].name, 'شاورما دجاج');
      expect(r.items[0].price, 45.0);
      expect(r.items[1].name, 'بيبسي');
      expect(r.items[1].quantity, 2);
      expect(r.items[2].name, 'فتوش');
      expect(r.items[2].price, 30.0);
    });
  });
}
