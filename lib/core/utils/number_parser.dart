// lib/core/utils/number_parser.dart
// Converts written numbers (English + Arabic) to digits

const _enOnes = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
  'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
  'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
  'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
  'eighteen': 18, 'nineteen': 19,
};

const _enTens = {
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
  'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
};

const _arOnes = {
  'صفر': 0, 'واحد': 1, 'اثنان': 2, 'اثنين': 2, 'ثلاثة': 3,
  'أربعة': 4, 'اربعة': 4, 'خمسة': 5, 'ستة': 6, 'سبعة': 7,
  'ثمانية': 8, 'تسعة': 9, 'عشرة': 10,
  'أحد عشر': 11, 'احد عشر': 11, 'اثنا عشر': 12, 'اثني عشر': 12,
  'ثلاثة عشر': 13, 'أربعة عشر': 14, 'خمسة عشر': 15,
  'ستة عشر': 16, 'سبعة عشر': 17, 'ثمانية عشر': 18, 'تسعة عشر': 19,
  // Spoken / Egyptian & Gulf forms
  'اتنين': 2, 'تلاتة': 3, 'تلاته': 3, 'ثلاث': 3, 'اربع': 4, 'خمس': 5, 'ست': 6, 'سبع': 7,
  'تمانية': 8, 'تمانيه': 8, 'ثمان': 8, 'تسع': 9, 'عشره': 10, 'عشر': 10,
  'خمسه': 5, 'سته': 6, 'سبعه': 7, 'تسعه': 9, 'اربعه': 4, 'ثلاثه': 3,
  'حداشر': 11, 'اتناشر': 12, 'تلتاشر': 13, 'اربعتاشر': 14, 'خمستاشر': 15,
  'ستاشر': 16, 'سبعتاشر': 17, 'تمنتاشر': 18, 'تسعتاشر': 19,
};

const _arTens = {
  'عشرون': 20, 'عشرين': 20, 'ثلاثون': 30, 'ثلاثين': 30,
  'أربعون': 40, 'اربعين': 40, 'خمسون': 50, 'خمسين': 50,
  'ستون': 60, 'ستين': 60, 'سبعون': 70, 'سبعين': 70,
  'ثمانون': 80, 'ثمانين': 80, 'تسعون': 90, 'تسعين': 90,
  'تلاتين': 30, 'تمانين': 80,
};

const _arHundreds = {
  'مئة': 100, 'مية': 100, 'مائة': 100,
  'مئتان': 200, 'مئتين': 200, 'ميتين': 200,
  'ثلاثمئة': 300, 'ثلاثمية': 300, 'أربعمئة': 400, 'اربعمية': 400,
  'خمسمئة': 500, 'خمسمية': 500, 'ستمئة': 600, 'ستمية': 600,
  'سبعمئة': 700, 'سبعمية': 700, 'ثمانمئة': 800, 'ثمانمية': 800,
  'تسعمئة': 900, 'تسعمية': 900,
};

/// Tries to parse a string as a number.
/// Accepts digits ("35"), written English ("thirty five"),
/// or written Arabic ("خمسة وثلاثون").
/// Returns null if cannot parse.
/// Converts Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) to Western digits (0123456789)
String normalizeDigits(String input) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  var result = input;
  for (int i = 0; i < 10; i++) {
    result = result.replaceAll(arabicDigits[i], i.toString());
  }
  return result;
}

double? parseNumberFromText(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // Try direct numeric parse first
  final direct = double.tryParse(trimmed.replaceAll(',', '.'));
  if (direct != null) return direct;

  // Try English words
  final enResult = _parseEnglishNumber(trimmed.toLowerCase());
  if (enResult != null) return enResult.toDouble();

  // Try Arabic words
  final arResult = _parseArabicNumber(trimmed);
  if (arResult != null) return arResult.toDouble();

  // Try extracting first number from mixed text
  final numMatch = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(trimmed);
  if (numMatch != null) {
    return double.tryParse(numMatch.group(0)!.replaceAll(',', '.'));
  }

  return null;
}

int? _parseEnglishNumber(String input) {
  input = input.replaceAll(RegExp(r'\band\b'), '').trim();
  final words = input.split(RegExp(r'[\s-]+'));
  
  int result = 0;
  int current = 0;

  for (final word in words) {
    if (word.isEmpty) continue;
    if (_enOnes.containsKey(word)) {
      current += _enOnes[word]!;
    } else if (_enTens.containsKey(word)) {
      current += _enTens[word]!;
    } else if (word == 'hundred') {
      current = current == 0 ? 100 : current * 100;
    } else if (word == 'thousand') {
      current = current == 0 ? 1000 : current * 1000;
      result += current;
      current = 0;
    } else {
      return null; // unknown word
    }
  }
  
  result += current;
  return result == 0 ? null : result;
}

List<MapEntry<String, int>> _byLength(Map<String, int> m) =>
    m.entries.toList()..sort((a, b) => b.key.length.compareTo(a.key.length));

int? _parseArabicNumber(String input) {
  int result = 0;
  
  // Check hundreds first
  for (final entry in _arHundreds.entries) {
    if (input.contains(entry.key)) {
      result += entry.value;
      input = input.replaceFirst(entry.key, '').trim();
    }
  }

  // "واحد" starts with و, so take it out before removing the "و" connectors.
  var one = 0;
  if (RegExp(r'(^|\s)واحد(\s|$)').hasMatch(input)) { one = 1; input = input.replaceFirst('واحد', ' '); }
  // Remove connectors ("خمسة وعشرين" → "خمسة عشرين")
  input = input.replaceAll(RegExp(r'(^|\s)و\s*'), ' ').trim();

  // Check tens
  for (final entry in _byLength(_arTens)) {
    if (input.contains(entry.key)) {
      result += entry.value;
      input = input.replaceFirst(entry.key, '').trim();
    }
  }

  // Check ones
  for (final entry in _byLength(_arOnes)) {
    if (input.contains(entry.key)) {
      result += entry.value;
      input = input.replaceFirst(entry.key, '').trim();
      break;
    }
  }
  result += one;

  return result == 0 ? null : result;
}

/// Words people add around a spoken amount ("ten dirhams", "15 percent").
final _fillers = RegExp(
    r'\b(aed|egp|sar|usd|qar|kwd|bhd|omr|jod|dirhams?|dhs?|pounds?|riyals?|rials?|dollars?|bucks|dinars?|euros?|lira|percent|per cent|only|about|around|is|it|the|a|an)\b'
    r'|درهم|دراهم|جنيه|جنيهات|ريال|دولار|دينار|بالمية|بالمئة|في المية|في المئة|بالمائة|تقريبا|بس|%');

/// Turns what the microphone heard into a number: "ten" → 10, "Ten." → 10,
/// "twenty five" → 25, "ten dirhams" → 10, "twelve point five" → 12.5,
/// "١٥" → 15, "عشرة" → 10, "خمسة وعشرين" → 25. Returns null if there's no number.
double? parseSpokenNumber(String input) {
  var t = normalizeDigits(input.toLowerCase().trim())
      .replaceAll('٫', '.')
      .replaceAll(RegExp(r'(?<=\d),(?=\d{3}\b)'), '')   // 1,000 → 1000
      .replaceAll(RegExp(r'(?<=\d),(?=\d)'), '.')        // 12,5 → 12.5
      .replaceAll(_fillers, ' ')
      .replaceAll(RegExp(r'[!?،,;:"]|\.(?!\d)'), ' ')    // punctuation, but keep 12.5
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (t.isEmpty) return null;

  final direct = double.tryParse(t);
  if (direct != null) return direct;

  // "twelve point five" / "اتناشر فاصلة خمسة"
  final pt = RegExp(r'\s(point|dot|فاصلة|فاصله)\s').firstMatch(' $t ');
  if (pt != null) {
    final whole = parseSpokenNumber(t.substring(0, pt.start).trim());
    final fracWords = t.substring(pt.end - 1).trim();
    final frac = RegExp(r'^\d+$').hasMatch(fracWords)
        ? fracWords
        : fracWords.split(' ').map((w) => _enOnes[w] ?? _arOnes[w]).whereType<int>().join();
    if (whole != null && frac.isNotEmpty) return double.tryParse('${whole.toStringAsFixed(0)}.$frac');
  }

  // Digits mixed with words: "10 and a half" → 10, "about 15" → 15
  final m = RegExp(r'\d+(?:\.\d+)?').firstMatch(t);
  if (m != null) return double.tryParse(m.group(0)!);

  // English words; unknown words are ignored as long as one number word is there.
  final en = t.split(RegExp(r'[\s-]+')).where((w) =>
      _enOnes.containsKey(w) || _enTens.containsKey(w) || w == 'hundred' || w == 'thousand').join(' ');
  if (en.isNotEmpty) {
    final v = _parseEnglishNumber(en);
    if (v != null) return v.toDouble();
  }

  final ar = _parseArabicNumber(t);
  return ar?.toDouble();
}
