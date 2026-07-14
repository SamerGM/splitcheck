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
};

const _arTens = {
  'عشرون': 20, 'عشرين': 20, 'ثلاثون': 30, 'ثلاثين': 30,
  'أربعون': 40, 'اربعين': 40, 'خمسون': 50, 'خمسين': 50,
  'ستون': 60, 'ستين': 60, 'سبعون': 70, 'سبعين': 70,
  'ثمانون': 80, 'ثمانين': 80, 'تسعون': 90, 'تسعين': 90,
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

int? _parseArabicNumber(String input) {
  int result = 0;
  
  // Check hundreds first
  for (final entry in _arHundreds.entries) {
    if (input.contains(entry.key)) {
      result += entry.value;
      input = input.replaceFirst(entry.key, '').trim();
    }
  }

  // Remove connectors
  input = input.replaceAll(RegExp(r'و\s*'), '').trim();

  // Check tens
  for (final entry in _arTens.entries) {
    if (input.contains(entry.key)) {
      result += entry.value;
      input = input.replaceFirst(entry.key, '').trim();
    }
  }

  // Check ones
  for (final entry in _arOnes.entries) {
    if (input.contains(entry.key)) {
      result += entry.value;
      input = input.replaceFirst(entry.key, '').trim();
      break;
    }
  }

  return result == 0 ? null : result;
}
