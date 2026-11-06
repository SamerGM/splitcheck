// lib/core/services/voice_service.dart
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

enum VoiceLocale { english, arabic }

class VoiceService {
  final _speech = stt.SpeechToText();
  bool _initialized = false;

  String localeId(VoiceLocale locale) =>
      locale == VoiceLocale.arabic ? 'ar_EG' : 'en_US';

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

    // For Arabic, prefer Egyptian, then other Arabic locales the device has.
    String selectedLocale = localeId(locale);
    if (locale == VoiceLocale.arabic) {
      final ids = (await _speech.locales())
          .map((l) => l.localeId.replaceAll('_', '-').toLowerCase())
          .toList();
      const preferred = ['ar-eg', 'ar-sa', 'ar-ae', 'ar'];
      final hit = preferred.firstWhere(
        (c) => ids.contains(c),
        orElse: () => ids.firstWhere((id) => id.startsWith('ar'), orElse: () => 'ar-eg'),
      );
      final parts = hit.split('-'); // 'ar-eg' → 'ar_EG' (engine format)
      selectedLocale = parts.length == 2 ? '${parts[0]}_${parts[1].toUpperCase()}' : parts[0];
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

/// Voice input language for an app language code ('en' / 'ar').
VoiceLocale voiceLocaleFor(String lang) => lang == 'ar' ? VoiceLocale.arabic : VoiceLocale.english;
