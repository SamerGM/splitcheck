// lib/core/services/voice_service.dart
// Voice input temporarily disabled pending speech_to_text v2 embedding fix.
enum VoiceLocale { english, arabic }
class VoiceService {
  bool get isListening => false;
  String localeId(VoiceLocale locale) =>
      locale == VoiceLocale.arabic ? 'ar-SA' : 'en-US';
  Future<bool> initialize() async => false;
  Future<void> listen({
    required VoiceLocale locale,
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async { onDone(); }
  Future<void> stop() async {}
  Future<void> cancel() async {}
}
