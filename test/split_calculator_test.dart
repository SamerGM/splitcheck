// test/split_calculator_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitcheck/core/models/models.dart';
import 'package:splitcheck/core/services/split_calculator.dart';
import 'package:splitcheck/core/services/parser_service.dart';
import 'package:splitcheck/core/utils/currency.dart';

Person p(String id, String name) =>
    Person(id: id, name: name, color: Colors.blue);

BillItem item(String id, String name, double price, List<String> pids) =>
    BillItem(id: id, name: name, price: price, personIds: pids);

Bill bill(List<Person> people, List<BillItem> items,
        {double vat = 0, double svc = 0, double tip = 0, double discPct = 0, double discFixed = 0}) =>
    Bill(
      id: 'test', merchant: 'Test', date: DateTime.now(), currency: 'AED',
      people: people, items: items,
      extras: BillExtras(vatPct: vat, servicePct: svc, tipPct: tip,
          discountPct: discPct, discountFixed: discFixed),
    );

void main() {
  group('SplitCalculator', () {

    test('Equal split — no extras', () {
      final b = bill([p('a','Ahmed'), p('b','Sara')], [item('i1','Burger',100,[])]);
      final r = SplitCalculator.calculate(b);
      expect(r.grandTotal, 100);
      expect(r.personResults[0].total, closeTo(50, 0.01));
      expect(r.personResults[1].total, closeTo(50, 0.01));
    });

    test('Item assigned to one person', () {
      final b = bill(
        [p('a','Ahmed'), p('b','Sara')],
        [item('i1','Steak',80,['a']), item('i2','Salad',20,['b'])],
      );
      final r = SplitCalculator.calculate(b);
      final ahmed = r.personResults.firstWhere((x) => x.person.id == 'a');
      final sara  = r.personResults.firstWhere((x) => x.person.id == 'b');
      expect(ahmed.total, closeTo(80, 0.01));
      expect(sara.total,  closeTo(20, 0.01));
    });

    test('Pizza split between two of three', () {
      final b = bill(
        [p('a','Ahmed'), p('b','Sara'), p('c','Omar')],
        [item('i1','Pizza',90,['a','b']), item('i2','Water',30,['c'])],
      );
      final r = SplitCalculator.calculate(b);
      expect(r.personResults.firstWhere((x) => x.person.id=='a').total, closeTo(45, 0.01));
      expect(r.personResults.firstWhere((x) => x.person.id=='b').total, closeTo(45, 0.01));
      expect(r.personResults.firstWhere((x) => x.person.id=='c').total, closeTo(30, 0.01));
    });

    test('Proportional VAT allocation', () {
      final b = bill(
        [p('a','Ahmed'), p('b','Sara')],
        [item('i1','Steak',200,['a']), item('i2','Salad',100,['b'])],
        vat: 10,
      );
      final r = SplitCalculator.calculate(b);
      // Ahmed = 200/300 = 66.7% → pays 66.7% of 30 = 20 → total 220
      // Sara  = 100/300 = 33.3% → pays 33.3% of 30 = 10 → total 110
      expect(r.personResults.firstWhere((x) => x.person.id=='a').total, closeTo(220, 0.01));
      expect(r.personResults.firstWhere((x) => x.person.id=='b').total, closeTo(110, 0.01));
      expect(r.grandTotal, closeTo(330, 0.01));
    });

    test('Grand total with VAT + service + tip', () {
      final b = bill([p('a','Ahmed')], [item('i1','Meal',100,[])], vat: 5, svc: 10, tip: 15);
      final r = SplitCalculator.calculate(b);
      expect(r.grandTotal, closeTo(130, 0.01));
    });
  });

  group('Discounts', () {
    test('Percentage discount reduces the grand total', () {
      final b = bill([p('a','Ahmed'), p('b','Sara')], [item('i1','Meal',100,[])], discPct: 10);
      final r = SplitCalculator.calculate(b);
      expect(r.discountAmount, closeTo(10, 0.001));
      expect(r.grandTotal, closeTo(90, 0.001));
      expect(r.personResults[0].total, closeTo(45, 0.001));
    });

    test('Fixed discount + VAT on discounted subtotal, allocated proportionally', () {
      final b = bill(
        [p('a','Ahmed'), p('b','Sara')],
        [item('i1','Steak',300,['a']), item('i2','Salad',100,['b'])],
        discFixed: 40, vat: 5,
      );
      final r = SplitCalculator.calculate(b);
      // 400 - 40 = 360, VAT 5% = 18 → 378
      expect(r.grandTotal, closeTo(378, 0.001));
      final a = r.personResults.firstWhere((x) => x.person.id == 'a');
      final s = r.personResults.firstWhere((x) => x.person.id == 'b');
      expect(a.total, closeTo(283.5, 0.001)); // 75% of 378
      expect(s.total, closeTo(94.5, 0.001));  // 25% of 378
      expect(a.total + s.total, closeTo(r.grandTotal, 0.001));
    });

    test('Fixed discount larger than the bill is capped', () {
      final b = bill([p('a','Ahmed')], [item('i1','Tea',20,[])], discFixed: 50);
      expect(SplitCalculator.calculate(b).grandTotal, closeTo(0, 0.001));
    });
  });

  group('Robustness', () {
    test('Item assigned to a removed person falls back to everyone', () {
      final b = bill([p('a','Ahmed'), p('b','Sara')], [item('i1','Pizza',60,['ghost'])]);
      final r = SplitCalculator.calculate(b);
      expect(r.personResults[0].total, closeTo(30, 0.001));
      expect(r.personResults[1].total, closeTo(30, 0.001));
    });

    test('Person totals always add up to the grand total', () {
      final b = bill(
        [p('a','A'), p('b','B'), p('c','C')],
        [item('1','X',33.3,['a']), item('2','Y',71.9,['b','c']), item('3','Z',15,[])],
        vat: 5, svc: 10, tip: 7, discPct: 12.5,
      );
      final r = SplitCalculator.calculate(b);
      final sum = r.personResults.fold(0.0, (a, x) => a + x.total);
      expect(sum, closeTo(r.grandTotal, 0.0001));
    });
  });

  group('Currency', () {
    test('Uses the selected currency instead of a hard-coded \$', () {
      expect(fmtAmount(12.5, 'AED'), 'AED 12.50');
      expect(fmtAmount(12.5, 'USD'), '\$12.50');
      expect(fmtAmount(1.5, 'KWD'), 'KWD 1.500');
      expect(fmtAmount(12.5, 'SAR', arabic: true), '12.50 ر.س');
    });
  });

  group('ParserService', () {

    test('Parse comma-separated names', () {
      expect(parsePeopleNames('Ahmed, Sara, Omar'), ['Ahmed', 'Sara', 'Omar']);
    });

    test('Parse "and" separated names', () {
      expect(parsePeopleNames('Ahmed and Sara'), ['Ahmed', 'Sara']);
    });

    test('Parse single item', () {
      final people = [p('a', 'Ahmed'), p('b', 'Sara')];
      final items = parseItems('Burger 35 Ahmed', knownPeople: people);
      expect(items.length, 1);
      expect(items[0].name, 'Burger');
      expect(items[0].price, 35);
      expect(items[0].personNames, ['Ahmed']);
    });

    test('Parse shared item (no person)', () {
      final items = parseItems('Coffee 18', knownPeople: []);
      expect(items.length, 1);
      expect(items[0].personNames, isEmpty);
    });

    test('Parse number from text', () {
      expect(parseNumber('5'), 5.0);
      expect(parseNumber('5%'), 5.0);
      expect(parseNumber('none'), 0.0);
      expect(parseNumber('no'), 0.0);
    });
  });
}
