// lib/core/services/ocr_service.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
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
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> scanReceipt(File imageFile, {List<Person> knownPeople = const []}) async {
    // Preprocess image for better OCR
    final processedFile = await _preprocessImage(imageFile);
    
    final inputImage = InputImage.fromFile(processedFile);
    final recognized = await _recognizer.processImage(inputImage);
    final rawText = recognized.text;

    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(rawText);
    final items = _parseReceiptText(rawText, knownPeople: knownPeople);

    // Clean up temp file
    if (processedFile.path != imageFile.path) {
      try { await processedFile.delete(); } catch (_) {}
    }

    return OcrResult(rawText: rawText, items: items, isArabic: isArabic);
  }

  Future<File> _preprocessImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return imageFile;

      // 1. Auto-rotate based on EXIF
      image = img.bakeOrientation(image);

      // 2. Convert to grayscale
      image = img.grayscale(image);

      // 3. Increase contrast
      image = img.adjustColor(image, contrast: 1.5, brightness: 1.1);

      // 4. Sharpen
      image = img.convolution(image, filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ], div: 1);

      // 5. Resize if too small (min 1000px wide for good OCR)
      if (image.width < 1000) {
        final scale = 1000 / image.width;
        image = img.copyResize(image,
          width: 1000,
          height: (image.height * scale).round());
      }

      // Save processed image
      final tempPath = '${imageFile.parent.path}/processed_receipt.jpg';
      final processedFile = File(tempPath);
      await processedFile.writeAsBytes(img.encodeJpg(image, quality: 95));
      return processedFile;
    } catch (e) {
      return imageFile; // fallback to original
    }
  }

  List<ParsedItem> _parseReceiptText(String text, {required List<Person> knownPeople}) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final items = <ParsedItem>[];

    final skipKeywords = RegExp(
      r'\b(total|subtotal|sub.?total|tax|vat|service|tip|gratuity|discount|change|cash|card|receipt|thank|welcome|visit|amount|balance|due|paid|tender|change)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (skipKeywords.hasMatch(line)) continue;
      if (line.length < 3) continue;

      // Multiple price pattern attempts
      ParsedItem? item = _tryParseLine(line);
      if (item != null) items.add(item);
    }

    // Remove duplicates
    final seen = <String>{};
    return items.where((item) => seen.add(item.name.toLowerCase())).toList();
  }

  ParsedItem? _tryParseLine(String line) {
    // Pattern 1: "Burger         35.00"
    final p1 = RegExp(r'^(.+?)\s{2,}(\d+[\.,]\d{1,2})\s*$');
    // Pattern 2: "Burger 35.00"
    final p2 = RegExp(r'^(.+?)\s+(\d+[\.,]\d{1,2})\s*$');
    // Pattern 3: "Burger 35" (no decimal)
    final p3 = RegExp(r'^(.+?)\s+(\d{1,4})\s*$');
    // Pattern 4: Price then name "35.00 Burger"
    final p4 = RegExp(r'^(\d+[\.,]\d{1,2})\s+(.+)$');
    // Pattern 5: "Burger .......... 35.00"
    final p5 = RegExp(r'^(.+?)\s*[.\-_]{3,}\s*(\d+[\.,]\d{1,2})\s*$');

    for (final pattern in [p5, p1, p2]) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        final name = _cleanName(match.group(1)!);
        final price = _parsePrice(match.group(2)!);
        if (name.isNotEmpty && price != null && price > 0 && price < 10000) {
          return ParsedItem(name: name, price: price, personNames: const []);
        }
      }
    }

    // Try p4 (price then name)
    final m4 = p4.firstMatch(line);
    if (m4 != null) {
      final price = _parsePrice(m4.group(1)!);
      final name = _cleanName(m4.group(2)!);
      if (name.isNotEmpty && price != null && price > 0 && price < 10000) {
        return ParsedItem(name: name, price: price, personNames: const []);
      }
    }

    // Try p3 only if line has reasonable structure
    if (line.split(' ').length >= 2) {
      final m3 = p3.firstMatch(line);
      if (m3 != null) {
        final name = _cleanName(m3.group(1)!);
        final price = _parsePrice(m3.group(2)!);
        if (name.isNotEmpty && price != null && price >= 1 && price < 10000) {
          return ParsedItem(name: name, price: price, personNames: const []);
        }
      }
    }

    return null;
  }

  String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'^\d+\s*[xX]\s*'), '') // remove qty prefix
        .replaceAll(RegExp(r'[*|#@]'), '')           // remove special chars
        .trim();
  }

  double? _parsePrice(String priceStr) {
    return double.tryParse(priceStr.replaceAll(',', '.'));
  }

  void dispose() => _recognizer.close();
}
