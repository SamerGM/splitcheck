// lib/core/services/ocr_service.dart
//
// Uses Google ML Kit Text Recognition — free, on-device, English.
// No API key. No internet required.

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'parser_service.dart';
import '../models/person.dart';

class OcrResult {
  final String rawText;
  final List<ParsedItem> items;
  final bool isArabic;

  const OcrResult({
    required this.rawText,
    required this.items,
    required this.isArabic,
  });
}

class OcrService {
  // Latin recognizer covers English + most receipt formats
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Scans an image file and extracts receipt items.
  Future<OcrResult> scanReceipt(File imageFile, {List<Person> knownPeople = const []}) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(inputImage);
    final rawText = recognized.text;

    // Detect if Arabic characters are present
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(rawText);

    // Parse items from the extracted text
    final items = _parseReceiptText(rawText, knownPeople: knownPeople);

    return OcrResult(rawText: rawText, items: items, isArabic: isArabic);
  }

  /// Parses raw receipt text into item lines.
  /// Handles formats like:
  ///   "Burger         35.00"
  ///   "Coffee ......... 18"
  ///   "1x Pizza        90.00"
  List<ParsedItem> _parseReceiptText(String text, {required List<Person> knownPeople}) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final items = <ParsedItem>[];

    // Keywords that indicate a total/summary line — skip these
    final skipKeywords = RegExp(
      r'\b(total|subtotal|sub total|tax|vat|service|tip|gratuity|discount|change|cash|card|receipt|thank|welcome|visit)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (skipKeywords.hasMatch(line)) continue;

      // Look for a price at the end of the line: "Burger 35.00" or "Burger    35"
      final pricePattern = RegExp(r'^(.+?)\s+(\d+\.\d{1,2}|\d+)\s*$');
      final match = pricePattern.firstMatch(line);
      if (match == null) continue;

      String name = match.group(1)!.trim();
      final priceStr = match.group(2)!;
      final price = double.tryParse(priceStr);
      if (price == null || price <= 0 || price > 10000) continue;

      // Remove quantity prefix like "2x" or "1 x"
      name = name.replaceAll(RegExp(r'^\d+\s*[xX]\s*'), '').trim();
      if (name.isEmpty) continue;

      items.add(ParsedItem(name: name, price: price, personNames: const []));
    }

    return items;
  }

  void dispose() => _recognizer.close();
}
