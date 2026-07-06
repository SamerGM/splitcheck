// lib/core/services/parser_service.dart
//
// Smart pattern matching for all user inputs.
// No API calls. No AI. Runs entirely on-device.

import '../models/person.dart';

// ── People parser ─────────────────────────────────────────────────────────────

/// Parses a comma/and-separated list of names.
/// Handles: "Ahmed, Sara, Omar" | "Ahmed and Sara" | "أحمد وسارة"
List<String> parsePeopleNames(String input) {
  return input
      .split(RegExp(r',|،|\band\b|\bو\b|\n', caseSensitive: false))
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty && n.length < 40)
      .toList();
}

// ── Item parser ───────────────────────────────────────────────────────────────

class ParsedItem {
  final String name;
  final double price;
  final List<String> personNames; // empty = shared by all

  const ParsedItem({required this.name, required this.price, required this.personNames});
}

/// Parses one or more items from a single user message.
///
/// Supported formats (all on one line or separated by commas/newlines):
///   Burger 35 Ahmed
///   Pizza 90 Ahmed Sara
///   Coffee 18
///   Coffee 18 shared
///   برجر 35 أحمد
///
/// Multi-item: "Burger 35 Ahmed, Coffee 18 Sara, Fries 20"
List<ParsedItem> parseItems(String input, {required List<Person> knownPeople}) {
  // Split by comma or newline to allow multiple items at once
  final lines = input
      .split(RegExp(r',|،|\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final results = <ParsedItem>[];

  for (final line in lines) {
    final item = _parseSingleItem(line, knownPeople: knownPeople);
    if (item != null) results.add(item);
  }

  return results;
}

ParsedItem? _parseSingleItem(String line, {required List<Person> knownPeople}) {
  // Extract all numbers from the line (price candidate)
  final numberPattern = RegExp(r'\d+(\.\d{1,2})?');
  final numberMatches = numberPattern.allMatches(line).toList();

  if (numberMatches.isEmpty) return null;

  // The price is the first standalone number (not part of a word)
  double? price;
  int priceEnd = 0;
  for (final m in numberMatches) {
    final candidate = double.tryParse(m.group(0)!);
    if (candidate != null && candidate > 0) {
      price = candidate;
      priceEnd = m.end;
      break;
    }
  }
  if (price == null) return null;

  // Item name = everything before the price number
  final priceStart = line.indexOf(numberMatches.first.group(0)!);
  String itemName = line.substring(0, priceStart).trim();
  if (itemName.isEmpty) itemName = 'Item';

  // Remaining text after the price = potential person names
  final remainder = line.substring(priceEnd).trim().toLowerCase();

  // "shared" keyword means everyone
  if (remainder.isEmpty || remainder == 'shared' || remainder == 'everyone' || remainder == 'all') {
    return ParsedItem(name: itemName, price: price, personNames: const []);
  }

  // Match known people names in the remainder (case-insensitive, partial match ok)
  final matched = <String>[];
  for (final person in knownPeople) {
    final pName = person.name.toLowerCase();
    if (remainder.contains(pName) || pName.contains(remainder.split(' ').first)) {
      if (!matched.contains(person.name)) matched.add(person.name);
    }
  }

  return ParsedItem(name: itemName, price: price, personNames: matched);
}

// ── Extras parser ─────────────────────────────────────────────────────────────

class ParsedExtras {
  final double? vatPct;
  final double? servicePct;
  final double? tipPct;

  const ParsedExtras({this.vatPct, this.servicePct, this.tipPct});
}

/// Parses "Tax 5%, service 10%, tip 15%" style input.
/// Also handles: "vat 5", "service charge 10", "gratuity 15"
ParsedExtras parseExtras(String input) {
  final text = input.toLowerCase();

  double? extract(List<String> keywords) {
    for (final kw in keywords) {
      // Match keyword followed by optional text then a number
      final pattern = RegExp(kw + r'[^0-9]*(\d+(\.\d{1,2})?)');
      final m = pattern.firstMatch(text);
      if (m != null) {
        final val = double.tryParse(m.group(1)!);
        if (val != null && val >= 0 && val <= 100) return val;
      }
    }
    return null;
  }

  return ParsedExtras(
    vatPct:     extract(['vat', 'tax', 'ضريبة', 'ضريبه']),
    servicePct: extract(['service charge', 'service', 'خدمة', 'خدمه']),
    tipPct:     extract(['tip', 'gratuity', 'إكرامية', 'إكراميه', 'بقشيش']),
  );
}

// ── Number parser ─────────────────────────────────────────────────────────────

/// Parses a plain number from user input.
/// "5" → 5.0 | "5%" → 5.0 | "none" → 0.0 | "no" → 0.0
double? parseNumber(String input) {
  final lower = input.toLowerCase().trim();
  if (lower == 'none' || lower == 'no' || lower == 'skip' ||
      lower == 'لا' || lower == 'بدون' || lower == '0') {
    return 0.0;
  }
  final cleaned = lower.replaceAll('%', '').trim();
  return double.tryParse(cleaned);
}
