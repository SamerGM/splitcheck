// lib/features/flow/chat_message.dart
import 'package:flutter/widgets.dart';

enum MessageRole { bot, user }

class QuickChip {
  final String label;
  final VoidCallback onTap;
  bool used;
  QuickChip({required this.label, required this.onTap}) : used = false;
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String text;
  final DateTime time;
  final List<QuickChip>? chips;
  final Widget? inlineWidget;

  ChatMessage({
    required this.role,
    required this.text,
    this.chips,
    this.inlineWidget,
  })  : id = DateTime.now().microsecondsSinceEpoch.toString(),
        time = DateTime.now();
}
