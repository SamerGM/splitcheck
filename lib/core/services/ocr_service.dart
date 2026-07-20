// lib/core/services/ocr_service.dart
// Uses Google Cloud Vision API for high-accuracy OCR
// Falls back to ML Kit if API fails
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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
  static const String _apiKey = String.fromEnvironment('GOOGLE_VISION_API_KEY');

  Future<OcrResult> scanReceipt(File imageFile, {List<Person> knownPeople = const []}) async {
    // Preprocess image
    final processedFile = await _preprocessImage(imageFile);

    // Try Cloud Vision API first
    String rawText = '';
    try {
      rawText = await _cloudVisionOcr(processedFile);
    } catch (e) {
      // Fallback to ML Kit
      rawText = await _mlKitOcr(processedFile);
    }

    if (rawText.isEmpty) {
      rawText = await _mlKitOcr(processedFile);
    }

    // Clean up temp file
    if (processedFile.path != imageFile.path) {
      try { await processedFile.delete(); } catch (_) {}
    }

    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(rawText);
    final items = _parseReceiptText(rawText, knownPeople: knownPeople);

    return OcrResult(rawText: rawText, items: items, isArabic: isArabic);
  }

  Future<String> _cloudVisionOcr(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requests': [{
          'image': {'content': base64Image},
          'features': [
            {'type': 'TEXT_DETECTION', 'maxResults': 1},
            {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1},
          ],
          'imageContext': {
            'languageHints': ['en', 'ar'],
          },
        }],
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) throw Exception('Vision API error: ${response.statusCode}');

    final json = jsonDecode(response.body);
    final responses = json['responses'] as List;
    if (responses.isEmpty) return '';

    final fullText = responses[0]['fullTextAnnotation']?['text'] as String? ?? '';
    if (fullText.isNotEmpty) return fullText;

    // Fallback to textAnnotations
    final annotations = responses[0]['textAnnotations'] as List?;
    if (annotations != null && annotations.isNotEmpty) {
      return annotations[0]['description'] as String? ?? '';
    }

    return '';
  }

  Future<String> _mlKitOcr(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(inputImage);
    return recognized.text;
  }

  Future<File> _preprocessImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return imageFile;

      image = img.bakeOrientation(image);
      image = img.grayscale(image);
      image = img.adjustColor(image, contrast: 1.5, brightness: 1.1);
      image = img.convolution(image, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0], div: 1);

      if (image.width < 1000) {
        final scale = 1000 / image.width;
        image = img.copyResize(image,
          width: 1000,
          height: (image.height * scale).round());
      }

      final tempPath = '${imageFile.parent.path}/processed_receipt.jpg';
      final processedFile = File(tempPath);
      await processedFile.writeAsBytes(img.encodeJpg(image, quality: 95));
      return processedFile;
    } catch (e) {
      return imageFile;
    }
  }

  List<ParsedItem> _parseReceiptText(String text, {required List<Person> knownPeople}) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final items = <ParsedItem>[];

    final skipKeywords = RegExp(
      r'\b(total|subtotal|sub.?total|tax|vat|service|tip|gratuity|discount|change|cash|card|receipt|thank|welcome|visit|amount|balance|due|paid|tender)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (skipKeywords.hasMatch(line)) continue;
      if (line.length < 3) continue;
      final item = _tryParseLine(line);
      if (item != null) items.add(item);
    }

    final seen = <String>{};
    return items.where((item) => seen.add(item.name.toLowerCase())).toList();
  }

  ParsedItem? _tryParseLine(String line) {
    final patterns = [
      RegExp(r'^(.+?)\s*[.\-_]{3,}\s*(\d+[\.,]\d{1,2})\s*$'),
      RegExp(r'^(.+?)\s{2,}(\d+[\.,]\d{1,2})\s*$'),
      RegExp(r'^(.+?)\s+(\d+[\.,]\d{1,2})\s*$'),
      RegExp(r'^(\d+[\.,]\d{1,2})\s+(.+)$'),
      RegExp(r'^(.+?)\s+(\d{1,4})\s*$'),
    ];

    for (int i = 0; i < patterns.length; i++) {
      final match = patterns[i].firstMatch(line);
      if (match != null) {
        String name, priceStr;
        if (i == 3) {
          priceStr = match.group(1)!;
          name = match.group(2)!;
        } else {
          name = match.group(1)!;
          priceStr = match.group(2)!;
        }
        name = name.replaceAll(RegExp(r'^\d+\s*[xX]\s*'), '').replaceAll(RegExp(r'[*|#@]'), '').trim();
        final price = double.tryParse(priceStr.replaceAll(',', '.'));
        if (name.isNotEmpty && price != null && price > 0 && price < 10000) {
          return ParsedItem(name: name, price: price, personNames: const []);
        }
      }
    }
    return null;
  }

  void dispose() => _recognizer.close();
}
