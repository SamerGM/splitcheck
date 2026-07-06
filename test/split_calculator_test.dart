// test/split_calculator_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitcheck/core/models/models.dart';
import 'package:splitcheck/core/services/split_calculator.dart';
import 'package:splitcheck/core/services/parser_service.dart';

Person p(String id, String name) =>
    Person(id: id, name: name, color: Colors.blue);

BillItem item(String id, String name, double price, List<String> pids) =>
    BillItem(id: id, name: name, price: price, personIds: pids);

Bill bill(List<Person> people, List<BillItem> items, {double vat = 0, double svc = 0, double tip = 0}) =>
    Bill(
      id: 'test', merchant: 'Test', date: DateTime.now(), currency: 'AED',
      people: people, items: items,
      extras: BillExtras(vatPct: vat, servicePct: svc, tipPct: tip),
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
