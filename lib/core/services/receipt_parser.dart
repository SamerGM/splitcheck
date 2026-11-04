// lib/core/services/receipt_parser.dart
//
// Turns raw OCR text from a receipt into items. Pure Dart, so it is unit-tested.
// Handles English and Arabic receipts, Arabic-Indic digits, "2 x Cola" quantities,
// and price-first lines (common in right-to-left OCR output).
import '../utils/number_parser.dart';
import 'parser_service.dart';

class ParsedReceipt {
  final List<ParsedItem> items;
  final String merchant; // best guess at the place name (may be empty)
  const ParsedReceipt(this.items, this.merchant);
}

class ReceiptParser {
  static final _skip = RegExp(
    // English
    r'\b(total|subtotal|sub.?total|tax|vat|trn|service|tip|gratuity|discount|change|cash|card|visa|'
    r'mastercard|receipt|invoice|bill|table|order|check|guest|cover|server|cashier|date|time|tel|'
    r'phone|thank|welcome|visit|amount|balance|due|paid|tender|qty|www|http)\b'
    // Arabic
    r'|الإجمالي|الاجمالي|إجمالي|اجمالي|المجموع|مجموع|الضريبة|ضريبة|القيمة المضافة|الخدمة|خدمة|'
    r'الخصم|خصم|نقدا|نقدًا|نقدي|الباقي|المتبقي|المدفوع|مدفوع|فاتورة|طاولة|ترابيزة|شكرا|شكراً|'
    r'التاريخ|تاريخ|الوقت|هاتف|تليفون|الكاشير|كاشير|رقم|بطاقة|فيزا',
    caseSensitive: false,
  );

  static final _letters = RegExp(r'[A-Za-z؀-ۿ]');
  static const _price = r'(\d{1,5}(?:[.,]\d{1,3})?)';

  static ParsedReceipt parse(String raw) {
    final lines = raw
        .split('\n')
        .map((l) => normalizeDigits(l).replaceAll('٫', '.').replaceAll('٬', ',').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final items = <ParsedItem>[];
    for (final line in lines) {
      if (line.length < 3 || _skip.hasMatch(line)) continue;
      final item = _parseLine(line);
      if (item != null) items.add(item);
    }

    final seen = <String>{};
    final unique = items.where((i) => seen.add(i.name.toLowerCase())).toList();
    return ParsedReceipt(unique, _guessMerchant(lines));
  }

  static ParsedItem? _parseLine(String line) {
    // Prices need decimals ("12.50") unless clearly separated, so "Table 12" isn't an item.
    final patterns = <RegExp>[
      RegExp('^(.+?)\\s*[.\\-_]{3,}\\s*$_price\\s*\$'),   // Name ...... 12.50
      RegExp('^(.+?)\\s+(\\d{1,5}[.,]\\d{1,3})\\s*\$'),   // Name 12.50
      RegExp('^(\\d{1,5}[.,]\\d{1,3})\\s+(.+)\$'),        // 12.50 Name (RTL)
      RegExp('^(.+?)\\s{2,}(\\d{1,5})\\s*\$'),            // Name      45   (wide gap)
    ];
    for (var i = 0; i < patterns.length; i++) {
      final m = patterns[i].firstMatch(line);
      if (m == null) continue;
      var name  = i == 2 ? m.group(2)! : m.group(1)!;
      final pStr = i == 2 ? m.group(1)! : m.group(2)!;
      final price = double.tryParse(pStr.replaceAll(',', '.'));
      if (price == null || price <= 0 || price >= 100000) continue;

      // Quantity: "2 x Cola", "2x Cola", "Cola x2", "٢ × كولا"
      var qty = 1;
      final lead = RegExp(r'^(\d{1,2})\s*[xX×*]\s*').firstMatch(name);
      final trail = RegExp(r'\s*[xX×*]\s*(\d{1,2})$').firstMatch(name);
      if (lead != null) { qty = int.parse(lead.group(1)!); name = name.substring(lead.end); }
      else if (trail != null) { qty = int.parse(trail.group(1)!); name = name.substring(0, trail.start); }
      else {
        // "2 Cola" (leading count followed by a space and letters)
        final n = RegExp(r'^(\d{1,2})\s+(?=\D)').firstMatch(name);
        if (n != null) { qty = int.parse(n.group(1)!); name = name.substring(n.end); }
      }
      name = name.replaceAll(RegExp(r'[*|#@:]'), '').trim();
      if (!_letters.hasMatch(name) || qty < 1) continue;
      return ParsedItem(name: name, price: price, personNames: const [], quantity: qty);
    }
    return null;
  }

  /// The place name is usually one of the first lines: letters, no prices.
  static String _guessMerchant(List<String> lines) {
    for (final l in lines.take(4)) {
      if (_skip.hasMatch(l)) continue;
      if (RegExp(r'\d').hasMatch(l)) continue;
      if (!_letters.hasMatch(l) || l.length < 3 || l.length > 40) continue;
      return l;
    }
    return '';
  }
}
