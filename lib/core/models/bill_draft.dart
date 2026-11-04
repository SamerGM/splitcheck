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
  final String? receiptPath;

  const BillDraft({
    this.merchant = '',
    this.people = const [],
    this.items = const [],
    required this.extras,
    this.receiptPath,
  });

  factory BillDraft.empty() => BillDraft(extras: BillExtras.empty());

  BillDraft copyWith({
    String? merchant,
    List<Person>? people,
    List<BillItem>? items,
    BillExtras? extras,
    String? receiptPath,
  }) => BillDraft(
    merchant: merchant ?? this.merchant,
    people:   people   ?? this.people,
    items:    items    ?? this.items,
    extras:   extras   ?? this.extras,
    receiptPath: receiptPath ?? this.receiptPath,
  );

  Bill toBill(String currency) => Bill(
    id: const Uuid().v4(),
    merchant: merchant.isNotEmpty ? merchant : '',
    date: DateTime.now(),
    currency: currency,
    people: people,
    items: items,
    extras: extras,
    receiptPath: receiptPath,
  );
}

// ── Split result ──────────────────────────────────────────────────────────────

class PersonResult {
  final Person person;
  final double itemsSubtotal;  // their share of item costs only
  final double discountShare;  // their share of the discount (positive number)
  final double vatShare;
  final double serviceShare;
  final double tipShare;
  final double deliveryShare; // equal share of the delivery fee
  final double total;

  const PersonResult({
    required this.person,
    required this.itemsSubtotal,
    this.discountShare = 0,
    required this.vatShare,
    required this.serviceShare,
    required this.tipShare,
    this.deliveryShare = 0,
    required this.total,
  });
}

class SplitResult {
  final double subtotal;
  final double discountAmount;
  final double vatAmount;
  final double serviceAmount;
  final double tipAmount;
  final double deliveryFee;
  /// Extra added by "round each share up" (0 when off).
  final double roundingExtra;
  final double grandTotal;
  final List<PersonResult> personResults;

  const SplitResult({
    required this.subtotal,
    this.discountAmount = 0,
    required this.vatAmount,
    required this.serviceAmount,
    required this.tipAmount,
    this.deliveryFee = 0,
    this.roundingExtra = 0,
    required this.grandTotal,
    required this.personResults,
  });
}
