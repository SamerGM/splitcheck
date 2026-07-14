// lib/core/services/parser_service.dart

import '../models/person.dart';
import '../utils/number_parser.dart';
import '../utils/currency.dart';

// ── People parser ─────────────────────────────────────────────────────────────

/// Supported separators between names:
/// , ، and و & + - / \ space newline
List<String> parsePeopleNames(String input) {
  // First try splitting by explicit separators
  final bySeparator = input
      .split(RegExp(r',|،|\band\b|\bو\b|\n|&|\+|-|/|\\', caseSensitive: false))
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty && n.length < 40)
      .toList();
  
  // If only one token found and it contains spaces, split by space
  if (bySeparator.length == 1 && bySeparator[0].contains(' ')) {
    return bySeparator[0]
        .split(RegExp(r'\s+'))
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty && n.length < 40)
        .toList();
  }
  
  return bySeparator;
}

// ── Item parser ───────────────────────────────────────────────────────────────

class ParsedItem {
  final String name;
  final double price;
  final List<String> personNames;

  const ParsedItem({
    required this.name,
    required this.price,
    required this.personNames,
  });
}

const _sharedKeywords = {
  'shared', 'share', 'everyone', 'all', 'everybody',
  'الكل', 'الجميع', 'كل', 'مُقسمة',
};

/// Separators between person names in item assignment:
/// space , ، and و & + - / \ 
final _nameSeparator = RegExp(
  r'\s*,\s*|\s*،\s*|\s+and\s+|\s+و\s+|\s*&\s*|\s*\+\s*|\s*-\s*|\s*/\s*|\s*\\\s*|\s+',
  caseSensitive: false,
);

List<ParsedItem> parseItems(String input, {required List<Person> knownPeople}) {
  final lines = _splitIntoItemLines(input);
  return lines
      .map((line) => _parseSingleItem(line.trim(), knownPeople: knownPeople))
      .whereType<ParsedItem>()
      .toList();
}

List<String> _splitIntoItemLines(String input) {
  final byNewline = input.split(RegExp(r'\n|،'));
  final result = <String>[];
  for (final segment in byNewline) {
    final parts = segment.split(',');
    if (parts.length == 1) { result.add(segment.trim()); continue; }
    String current = parts[0];
    for (int i = 1; i < parts.length; i++) {
      final part = parts[i].trim();
      final hasEarlyNumber = RegExp(r'^\s*\w+\s+\d').hasMatch(part);
      final startsWithNumber = RegExp(r'^\s*\d').hasMatch(part);
      if (hasEarlyNumber || startsWithNumber) {
        result.add(current.trim());
        current = part;
      } else {
        current += ', ' + part;
      }
    }
    result.add(current.trim());
  }
  return result.where((l) => l.isNotEmpty).toList();
}

ParsedItem? _parseSingleItem(String line, {required List<Person> knownPeople}) {
  if (line.isEmpty) return null;
  final numberPattern = RegExp(r'(\d+(?:\.\d{1,2})?)');
  final match = numberPattern.firstMatch(line);
  if (match == null) return null;
  final price = double.tryParse(match.group(1)!);
  if (price == null || price <= 0) return null;
  String itemName = line.substring(0, match.start).trim();
  if (itemName.isEmpty) itemName = 'Item';
  final remainder = line.substring(match.end).trim();
  if (remainder.isEmpty) {
    return ParsedItem(name: itemName, price: price, personNames: const []);
  }
  final remLower = remainder.toLowerCase().trim();
  if (_sharedKeywords.contains(remLower)) {
    return ParsedItem(name: itemName, price: price, personNames: const []);
  }
  final rawNames = remainder
      .split(_nameSeparator)
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .toList();
  if (rawNames.every((n) => _sharedKeywords.contains(n.toLowerCase()))) {
    return ParsedItem(name: itemName, price: price, personNames: const []);
  }
  final matchedNames = <String>[];
  for (final raw in rawNames) {
    if (_sharedKeywords.contains(raw.toLowerCase())) continue;
    final person = _matchPerson(raw, knownPeople);
    if (person != null && !matchedNames.contains(person.name)) {
      matchedNames.add(person.name);
    }
  }
  if (matchedNames.isEmpty && rawNames.isNotEmpty) {
    final filtered = rawNames
        .where((n) => !_sharedKeywords.contains(n.toLowerCase()))
        .toList();
    return ParsedItem(name: itemName, price: price, personNames: filtered);
  }
  return ParsedItem(name: itemName, price: price, personNames: matchedNames);
}

Person? _matchPerson(String raw, List<Person> people) {
  final r = raw.toLowerCase();
  for (final p in people) {
    if (p.name.toLowerCase() == r) return p;
  }
  for (final p in people) {
    if (p.name.toLowerCase().contains(r) || r.contains(p.name.toLowerCase())) {
      return p;
    }
  }
  return null;
}

// ── Extras parser ─────────────────────────────────────────────────────────────

class ParsedExtras {
  final double? vatPct;
  final double? servicePct;
  final double? tipPct;
  const ParsedExtras({this.vatPct, this.servicePct, this.tipPct});
}

ParsedExtras parseExtras(String input) {
  final text = input.toLowerCase();
  double? extract(List<String> keywords) {
    for (final kw in keywords) {
      final pattern = RegExp(kw + r'[^0-9]*(\d+(?:\.\d{1,2})?)');
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

double? parseNumber(String input) {
  final lower = input.toLowerCase().trim();
  if (lower == 'none' || lower == 'no' || lower == 'skip' ||
      lower == 'لا' || lower == 'بدون' || lower == '0') {
    return 0.0;
  }
  return double.tryParse(lower.replaceAll('%', '').trim());
}
