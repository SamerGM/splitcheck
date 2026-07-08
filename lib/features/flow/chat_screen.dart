import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gap/gap.dart';

import '../../core/services/providers.dart';
import '../../core/services/settings_provider.dart';
import '../../core/services/voice_service.dart';
import '../../shared/theme/app_theme.dart';
import 'chat_message.dart';
import 'flow_controller.dart';
import '../result/result_card.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _focus  = FocusNode();
  bool _isRec   = false;
  String _live  = '';

  @override
  void dispose() {
    _ctrl.dispose(); _scroll.dispose(); _focus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final v = _ctrl.text.trim(); if (v.isEmpty) return;
    _ctrl.clear();
    await ref.read(chatProvider.notifier).handleInput(v);
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xf == null) return;
    await ref.read(chatProvider.notifier).handleOcrFile(File(xf.path));
    _scrollToBottom();
  }

  Future<void> _toggleVoice() async {
    final voice  = ref.read(voiceServiceProvider);
    final locale = ref.read(voiceLocaleProvider);
    if (_isRec) {
      await voice.stop();
      setState(() => _isRec = false);
      if (_ctrl.text.trim().isNotEmpty) await _send();
    } else {
      setState(() { _isRec = true; _live = ''; });
      await voice.listen(
        locale: locale,
        onResult: (text, isFinal) {
          setState(() => _live = text);
          if (isFinal) _ctrl.text = text;
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isRec = false);
          if (_ctrl.text.trim().isNotEmpty) _send();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages  = ref.watch(chatProvider);
    final isTyping  = ref.watch(isTypingProvider);
    final step      = ref.watch(flowStepProvider);
    final result    = ref.watch(splitResultProvider);
    final bill      = ref.watch(finalBillProvider);
    final currency  = ref.watch(currencyProvider);
    final locale    = ref.watch(voiceLocaleProvider);
    final themeMode = ref.watch(themeProvider);
    final language  = ref.watch(languageProvider);
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    ref.listen(chatProvider,    (_, __) => _scrollToBottom());
    ref.listen(isTypingProvider,(_, __) => _scrollToBottom());

    final showScan = step == FlowStep.items;

    return Scaffold(
      body: SafeArea(child: Column(children: [
        _TopBar(
          step: step,
          currency: currency,
          locale: locale,
          isDark: isDark,
          language: language,
          themeMode: themeMode,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            itemCount: messages.length + (isTyping ? 1 : 0) + (result != null ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (result != null && bill != null && i == messages.length + (isTyping ? 1 : 0)) {
                return ResultCard(result: result, bill: bill).animate().fadeIn().slideY(begin: .1);
              }
              if (isTyping && i == messages.length) {
                return const _TypingBubble().animate().fadeIn();
              }
              return _Bubble(msg: messages[i])
                  .animate().fadeIn(duration: 220.ms).slideY(begin: .07, duration: 220.ms);
            },
          ),
        ),
        _InputBar(
          ctrl: _ctrl, isRec: _isRec, liveText: _live,
          showScan: showScan,
          onSend: _send, onVoice: _toggleVoice, onScan: _pickImage,
        ),
      ])),
    );
  }
}

// ── TOP BAR ───────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final FlowStep step;
  final String currency;
  final VoiceLocale locale;
  final bool isDark;
  final String language;
  final ThemeMode themeMode;

  const _TopBar({
    required this.step, required this.currency, required this.locale,
    required this.isDark, required this.language, required this.themeMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final accentColor  = isDark ? AppTheme.darkAccent  : AppTheme.lightAccent;

    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        // Logo
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.receipt_long, color: accentColor, size: 17),
        ),
        const Gap(8),
        Text('SplitCheck', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: accentColor)),
        const Spacer(),

        // Progress dots
        Row(children: FlowStep.values.map((s) {
          final si = FlowStep.values.indexOf(s);
          final ci = FlowStep.values.indexOf(step);
          return AnimatedContainer(
            duration: 350.ms,
            width: si == ci ? 22 : (si < ci ? 14 : 6),
            height: 6, margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: si < ci
                  ? (isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess)
                  : si == ci
                      ? accentColor
                      : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }).toList()),
        const Gap(8),

        // Language toggle EN / AR
        GestureDetector(
          onTap: () {
            ref.read(languageProvider.notifier).toggle();
            final newLang = language == 'en' ? 'ar' : 'en';
            ref.read(voiceLocaleProvider.notifier).value =
                newLang == 'ar' ? VoiceLocale.arabic : VoiceLocale.english;
            ref.read(chatProvider.notifier).reset();
          },
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: language == 'en' ? accentColor : Colors.transparent,
                ),
                child: Text('EN', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: language == 'en' ? Colors.white : (isDark ? Colors.white54 : Colors.black45),
                )),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: language == 'ar' ? accentColor : Colors.transparent,
                ),
                child: Text('AR', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: language == 'ar' ? Colors.white : (isDark ? Colors.white54 : Colors.black45),
                )),
              ),
            ]),
          ),
        ),
        const Gap(6),

        // Theme toggle ☀️ / 🌙
        GestureDetector(
          onTap: () => ref.read(themeProvider.notifier).toggle(context),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: !isDark ? accentColor : Colors.transparent,
                ),
                child: Icon(Icons.wb_sunny, size: 14, color: Colors.white),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isDark ? accentColor : Colors.transparent,
                ),
                child: Icon(Icons.nightlight_round, size: 14, color: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

}

// ── BUBBLE ────────────────────────────────────────────────────────────────────

class _Bubble extends StatefulWidget {
  final ChatMessage msg;
  const _Bubble({required this.msg});
  @override State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  @override
  Widget build(BuildContext context) {
    final isBot  = widget.msg.role == MessageRole.bot;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final botBg  = isDark ? AppTheme.darkCard  : AppTheme.lightCard;
    final botBorder = isDark
        ? AppTheme.darkAccent.withValues(alpha: 0.13)
        : AppTheme.lightAccent.withValues(alpha: 0.2);
    final userBg = isDark ? AppTheme.darkAccentDark : AppTheme.lightAccentDark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.86),
            child: Column(
              crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isBot ? botBg : userBg,
                    border: isBot ? Border.all(color: botBorder) : null,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isBot ? 5 : 18),
                      bottomRight: Radius.circular(isBot ? 18 : 5),
                    ),
                  ),
                  child: Text(widget.msg.text,
                    style: TextStyle(fontSize: 13, height: 1.65,
                      color: isBot ? textColor : Colors.white)),
                ),
                if (widget.msg.inlineWidget != null)
                  Padding(padding: const EdgeInsets.only(top: 6),
                    child: widget.msg.inlineWidget!),
                if (widget.msg.chips?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 6, runSpacing: 6,
                      children: widget.msg.chips!.map((chip) {
                        return GestureDetector(
                          onTap: chip.used ? null : () {
                            setState(() => chip.used = true);
                            chip.onTap();
                          },
                          child: AnimatedOpacity(
                            opacity: chip.used ? 0.35 : 1,
                            duration: 200.ms,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 7),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(chip.label, style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: accentColor)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 3, right: 3),
                  child: Text(
                    '${widget.msg.time.hour.toString().padLeft(2,'0')}:'
                    '${widget.msg.time.minute.toString().padLeft(2,'0')}',
                    style: TextStyle(fontSize: 10,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.2)),
                    textAlign: isBot ? TextAlign.left : TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── TYPING ────────────────────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with TickerProviderStateMixin {
  late final List<AnimationController> _cs;

  @override
  void initState() {
    super.initState();
    _cs = List.generate(3, (i) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true));
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 140), () {
        if (mounted) _cs[i].forward();
      });
    }
  }

  @override
  void dispose() { for (final c in _cs) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: accent.withValues(alpha: 0.15)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18), topRight: Radius.circular(18),
            bottomLeft: Radius.circular(5), bottomRight: Radius.circular(18)),
        ),
        child: Row(children: List.generate(3, (i) => AnimatedBuilder(
          animation: _cs[i],
          builder: (_, __) => Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.5 + _cs[i].value * 0.5),
              shape: BoxShape.circle,
            ),
            transform: Matrix4.translationValues(0, -_cs[i].value * 5, 0),
          ),
        ))),
      ),
    ]));
  }
}

// ── INPUT BAR ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isRec, showScan;
  final String liveText;
  final VoidCallback onSend, onVoice, onScan;

  const _InputBar({
    required this.ctrl, required this.isRec, required this.liveText,
    required this.showScan, required this.onSend,
    required this.onVoice, required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final cardColor    = isDark ? AppTheme.darkCard    : AppTheme.lightCard;
    final accentColor  = isDark ? AppTheme.darkAccent  : AppTheme.lightAccent;
    final accentDark   = isDark ? AppTheme.darkAccentDark : AppTheme.lightAccentDark;
    final hintColor    = isDark ? AppTheme.darkTextHint    : AppTheme.lightTextHint;
    final borderColor  = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);

    final textColor    = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor   = isDark ? AppTheme.darkTextMuted   : AppTheme.lightTextMuted;
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (isRec && liveText.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Text(liveText,
              style: TextStyle(fontSize: 12, color: mutedColor)),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (showScan) ...[
            _IBtn(
              onTap: onScan, icon: Icons.camera_alt_outlined,
              color: accentColor,
              bg: accentColor.withValues(alpha: 0.1),
              border: accentColor.withValues(alpha: 0.22),
            ),
            const Gap(7),
          ],
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: 4, minLines: 1,
              onSubmitted: (_) => onSend(),
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: isRec ? 'Listening…' : 'Type your answer…',
                hintStyle: TextStyle(fontSize: 13, color: hintColor),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: accentColor, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const Gap(7),
          _IBtn(
            onTap: onVoice,
            icon: isRec ? Icons.stop : Icons.mic,
            color: isRec ? Colors.white : mutedColor,
            bg: isRec
                ? const Color(0xFFB91C1C)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.06)),
            border: isRec
                ? const Color(0xFFB91C1C)
                : borderColor,
          ),
          const Gap(7),
          _IBtn(
            onTap: onSend, icon: Icons.send_rounded,
            color: Colors.white, bg: accentDark, border: accentDark,
          ),
        ]),
      ]),
    );
  }
}

class _IBtn extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color color, bg, border;

  const _IBtn({
    required this.onTap, required this.icon,
    required this.color, required this.bg, required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: bg, shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }
}
