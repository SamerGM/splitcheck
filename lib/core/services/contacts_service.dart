// lib/core/services/contacts_service.dart
import 'package:flutter/services.dart';

/// Opens the phone's contact picker and returns the chosen name (or null).
/// Android only; elsewhere it returns null.
class ContactsService {
  static const _channel = MethodChannel('splitcheck/contacts');

  static Future<String?> pickName() async {
    try {
      final name = await _channel.invokeMethod<String>('pickName');
      final t = name?.trim();
      return (t == null || t.isEmpty) ? null : t;
    } on MissingPluginException {
      return null; // not available on this platform (web/tests)
    } on PlatformException {
      return null;
    }
  }
}
