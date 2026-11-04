// lib/core/services/ocr_service.dart
// Uses Google Cloud Vision API for high-accuracy OCR
// Falls back to on-device ML Kit (Latin script only) if the API is unavailable.
// Arabic receipts need Cloud Vision (languageHints: en, ar).
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'parser_service.dart';
import 'receipt_parser.dart';

class OcrResult {
  final String rawText;
  final List<ParsedItem> items;
  final bool isArabic;
  final String merchant;
  const OcrResult({
    required this.rawText,
    required this.items,
    required this.isArabic,
    this.merchant = '',
  });
}

class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  static const String _apiKey = String.fromEnvironment('GOOGLE_VISION_API_KEY');

  Future<OcrResult> scanReceipt(File imageFile) async {
    // Preprocess image
    final processedFile = await _preprocessImage(imageFile);

    // Try Cloud Vision API first
    String rawText = '';
    if (_apiKey.isNotEmpty) {
      try {
        rawText = await _cloudVisionOcr(processedFile);
      } catch (_) {
        rawText = ''; // fall through to on-device ML Kit
      }
    }
    if (rawText.trim().isEmpty) {
      rawText = await _mlKitOcr(processedFile);
    }

    // Clean up temp file
    if (processedFile.path != imageFile.path) {
      try { await processedFile.delete(); } catch (_) {}
    }

    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(rawText);
    final parsed = ReceiptParser.parse(rawText);

    return OcrResult(rawText: rawText, items: parsed.items, isArabic: isArabic, merchant: parsed.merchant);
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
          // One feature only — each feature is billed separately.
          'features': [
            {'type': 'DOCUMENT_TEXT_DETECTION'},
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

  void dispose() => _recognizer.close();
}
