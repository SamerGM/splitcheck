// lib/core/models/bill.dart
import 'person.dart';
import 'bill_item.dart';
import 'bill_extras.dart';

class Bill {
  final String id;
  final String merchant;
  final DateTime date;
  final String currency;
  final List<Person> people;
  final List<BillItem> items;
  final BillExtras extras;

  const Bill({
    required this.id,
    required this.merchant,
    required this.date,
    required this.currency,
    required this.people,
    required this.items,
    required this.extras,
  });

  double get subtotal => items.fold(0, (s, i) => s + i.price);
  double get grandTotal => subtotal + extras.totalExtras(subtotal);

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant': merchant,
    'date': date.toIso8601String(),
    'currency': currency,
    'people': people.map((p) => p.toJson()).toList(),
    'items': items.map((i) => i.toJson()).toList(),
    'extras': extras.toJson(),
  };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
    id: j['id'] as String,
    merchant: j['merchant'] as String,
    date: DateTime.parse(j['date'] as String),
    currency: j['currency'] as String,
    people: (j['people'] as List).map((e) => Person.fromJson(e as Map<String, dynamic>)).toList(),
    items:  (j['items']  as List).map((e) => BillItem.fromJson(e as Map<String, dynamic>)).toList(),
    extras: BillExtras.fromJson(j['extras'] as Map<String, dynamic>),
  );
}
