// lib/core/services/voice_service.dart
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

enum VoiceLocale { english, arabic }

class VoiceService {
  final _speech = stt.SpeechToText();
  bool _initialized = false;

  String localeId(VoiceLocale locale) =>
      locale == VoiceLocale.arabic ? 'ar-SA' : 'en-US';

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (e) { _initialized = false; },
    );
    return _initialized;
  }

  bool get isListening => _speech.isListening;

  Future<void> listen({
    required VoiceLocale locale,
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    final ready = await initialize();
    if (!ready) { onDone(); return; }

    // For Arabic, try multiple locales for better recognition
    String selectedLocale = localeId(locale);
    if (locale == VoiceLocale.arabic) {
      final available = await _speech.locales();
      final ids = available.map((l) => l.localeId).toList();
      for (final candidate in ['ar-SA', 'ar-EG', 'ar-AE', 'ar']) {
        if (ids.any((id) => id.startsWith(candidate.split('-')[0]))) {
          selectedLocale = candidate;
          break;
        }
      }
    }

    await _speech.listen(
      localeId: selectedLocale,
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 5),
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
        if (result.finalResult) onDone();
      },
    );
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
}
