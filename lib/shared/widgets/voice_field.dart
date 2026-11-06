// lib/shared/widgets/voice_field.dart
//
// Text field with a 🎤 button: tap to speak, the words appear in the field.
// Number fields turn spoken numbers ("forty five" / "خمسة وأربعين") into digits.
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/parser_service.dart';
import '../../core/services/providers.dart';
import '../theme/app_theme.dart';

class VoiceField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool numeric;
  final String? prefixText;          // e.g. "EGP"
  final String? suffixText;          // e.g. "%"
  final Widget? trailing;            // extra button (e.g. contacts)
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool large;                  // big number style (VAT box, prices)
  final Color? fill;

  const VoiceField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.numeric = false,
    this.prefixText,
    this.suffixText,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.large = false,
    this.fill,
  });

  @override ConsumerState<VoiceField> createState() => _VoiceFieldState();
}

class _VoiceFieldState extends ConsumerState<VoiceField> {
  bool _listening = false;

  Future<void> _toggleMic() async {
    final voice = ref.read(voiceServiceProvider);
    HapticFeedback.mediumImpact();
    if (_listening) {
      await voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await voice.listen(
      locale: ref.read(voiceLocaleProvider),
      onResult: (text, isFinal) {
        if (!mounted) return;
        var t = text;
        if (widget.numeric && isFinal) {
          final n = parseNumber(text);
          if (n != null) t = n == n.roundToDouble() ? n.toStringAsFixed(0) : '$n';
        }
        widget.controller.text = t;
        widget.controller.selection = TextSelection.collapsed(offset: t.length);
        widget.onChanged?.call(t);
      },
      onDone: () { if (mounted) setState(() => _listening = false); },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final size = widget.large ? 28.0 : 17.0;
    return Container(
      decoration: BoxDecoration(
        color: widget.fill ?? (p.isDark ? p.elevated : p.surface),
        borderRadius: BorderRadius.circular(12),
        border: _listening ? Border.all(color: p.red, width: 1.5) : null,
      ),
      child: Row(children: [
        if (widget.prefixText != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 14),
            child: Text(widget.prefixText!, style: TextStyle(fontSize: widget.large ? 18 : 17, color: p.secondary)),
          ),
        Expanded(
          child: CupertinoTextField(
            controller: widget.controller,
            placeholder: _listening ? '…' : widget.placeholder,
            placeholderStyle: TextStyle(fontSize: size, color: p.tertiary, fontWeight: widget.large ? FontWeight.w700 : null),
            style: TextStyle(fontSize: size, color: p.label, fontWeight: widget.large ? FontWeight.w700 : null),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.large ? 10 : 13),
            decoration: null,
            autofocus: widget.autofocus,
            keyboardType: widget.numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            textCapitalization: widget.numeric ? TextCapitalization.none : TextCapitalization.sentences,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
          ),
        ),
        if (widget.suffixText != null)
          Text(widget.suffixText!, style: TextStyle(fontSize: widget.large ? 18 : 17, color: p.secondary)),
        if (widget.trailing != null) widget.trailing!,
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(36, 36),
          onPressed: _toggleMic,
          child: Icon(_listening ? CupertinoIcons.stop_circle_fill : CupertinoIcons.mic_fill,
              color: _listening ? p.red : p.accent, size: 22),
        ),
      ]),
    );
  }
}
