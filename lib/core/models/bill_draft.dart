// lib/core/models/bill_draft.dart
import 'package:uuid/uuid.dart';
import 'person.dart';
import 'bill_item.dart';
import 'bill_extras.dart';
import 'bill.dart';

/// Mutable working state built step by step during the guided flow.
class BillDraft {
  final String merchant;
  final List<Person> people;
  final List<BillItem> items;
  final BillExtras extras;

  const BillDraft({
    this.merchant = '',
    this.people = const [],
    this.items = const [],
    required this.extras,
  });

  factory BillDraft.empty() => BillDraft(extras: BillExtras.empty());

  BillDraft copyWith({
    String? merchant,
    List<Person>? people,
    List<BillItem>? items,
    BillExtras? extras,
  }) => BillDraft(
    merchant: merchant ?? this.merchant,
    people:   people   ?? this.people,
    items:    items    ?? this.items,
    extras:   extras   ?? this.extras,
  );

  Bill toBill(String currency) => Bill(
    id: const Uuid().v4(),
    merchant: merchant.isNotEmpty ? merchant : 'Bill',
    date: DateTime.now(),
    currency: currency,
    people: people,
    items: items,
    extras: extras,
  );
}

// ── Split result ──────────────────────────────────────────────────────────────

class PersonResult {
  final Person person;
  final double itemsSubtotal;  // their share of item costs only
  final double vatShare;
  final double serviceShare;
  final double tipShare;
  final double total;

  const PersonResult({
    required this.person,
    required this.itemsSubtotal,
    required this.vatShare,
    required this.serviceShare,
    required this.tipShare,
    required this.total,
  });
}

class SplitResult {
  final double subtotal;
  final double vatAmount;
  final double serviceAmount;
  final double tipAmount;
  final double grandTotal;
  final List<PersonResult> personResults;

  const SplitResult({
    required this.subtotal,
    required this.vatAmount,
    required this.serviceAmount,
    required this.tipAmount,
    required this.grandTotal,
    required this.personResults,
  });
}
