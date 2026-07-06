// lib/features/flow/chat_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gap/gap.dart';

import '../../core/services/providers.dart';
import '../../core/services/voice_service.dart';
import '../../core/utils/currency.dart';
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
    final messages = ref.watch(chatProvider);
    final isTyping = ref.watch(isTypingProvider);
    final step     = ref.watch(flowStepProvider);
    final result   = ref.watch(splitResultProvider);
    final bill     = ref.watch(finalBillProvider);
    final currency = ref.watch(currencyProvider);
    final locale   = ref.watch(voiceLocaleProvider);

    ref.listen(chatProvider,    (_, __) => _scrollToBottom());
    ref.listen(isTypingProvider,(_, __) => _scrollToBottom());

    final showScan = step == FlowStep.items;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        _TopBar(step: step, currency: currency, locale: locale),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            itemCount: messages.length + (isTyping ? 1 : 0) + (result != null ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (result != null && bill != null && i == messages.length + (isTyping ? 1 : 0)) {
                return ResultCard(result: result, bill: bill)
                    .animate().fadeIn().slideY(begin: .1);
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
  final FlowStep step; final String currency; final VoiceLocale locale;
  const _TopBar({required this.step, required this.currency, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: const Color(0xFF153D6B), borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.receipt_long, color: AppTheme.accent, size: 17)),
        const Gap(8),
        const Text('SplitCheck', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.accent)),
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
              color: si < ci ? AppTheme.success : si == ci ? AppTheme.accent : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }).toList()),
        const Gap(8),

        // Language toggle EN / AR
        GestureDetector(
          onTap: () {
            final next = locale == VoiceLocale.english ? VoiceLocale.arabic : VoiceLocale.english;
            ref.read(voiceLocaleProvider.notifier).state = next;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              locale == VoiceLocale.english ? 'EN' : 'AR',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
            ),
          ),
        ),
        const Gap(6),

        // Currency picker
        GestureDetector(
          onTap: () {
            final cur = ref.read(currencyProvider);
            final next = kCurrencies[(kCurrencies.indexOf(cur) + 1) % kCurrencies.length];
            ref.read(currencyProvider.notifier).state = next;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(currency, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accent)),
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
    final isBot = widget.msg.role == MessageRole.bot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
            child: Column(
              crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isBot ? AppTheme.card : AppTheme.accentDark,
                    border: isBot ? Border.all(color: AppTheme.accent.withOpacity(0.13)) : null,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isBot ? 5 : 18),
                      bottomRight: Radius.circular(isBot ? 18 : 5),
                    ),
                  ),
                  child: Text(widget.msg.text,
                    style: TextStyle(fontSize: 13, height: 1.65,
                      color: isBot ? AppTheme.textPrimary : Colors.white)),
                ),
                if (widget.msg.inlineWidget != null)
                  Padding(padding: const EdgeInsets.only(top: 6), child: widget.msg.inlineWidget!),
                if (widget.msg.chips?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 6, runSpacing: 6,
                      children: widget.msg.chips!.map((chip) {
                        return GestureDetector(
                          onTap: chip.used ? null : () { setState(() => chip.used = true); chip.onTap(); },
                          child: AnimatedOpacity(
                            opacity: chip.used ? 0.35 : 1,
                            duration: 200.ms,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withOpacity(0.08),
                                border: Border.all(color: AppTheme.accent.withOpacity(0.28)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(chip.label,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7EC8F5))),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 3, right: 3),
                  child: Text(
                    '${widget.msg.time.hour.toString().padLeft(2,'0')}:${widget.msg.time.minute.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 10, color: Color(0x33FFFFFF)),
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

class _TypingBubbleState extends State<_TypingBubble> with TickerProviderStateMixin {
  late final List<AnimationController> _cs;

  @override
  void initState() {
    super.initState();
    _cs = List.generate(3, (i) =>
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true));
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 140), () { if (mounted) _cs[i].forward(); });
    }
  }

  @override
  void dispose() { for (final c in _cs) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          border: Border.all(color: AppTheme.accent.withOpacity(0.12)),
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
              color: AppTheme.accent.withOpacity(0.5 + _cs[i].value * 0.5),
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
    required this.showScan, required this.onSend, required this.onVoice, required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (isRec && liveText.isNotEmpty)
          Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withOpacity(0.2))),
            child: Text(liveText, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (showScan) ...[
            _IBtn(onTap: onScan, icon: Icons.camera_alt_outlined,
              color: AppTheme.accent, bg: AppTheme.accent.withOpacity(0.1), border: AppTheme.accent.withOpacity(0.22)),
            const Gap(7),
          ],
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: 4, minLines: 1,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: isRec ? 'Listening…' : 'Type your answer…',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppTheme.accent, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const Gap(7),
          _IBtn(onTap: onVoice,
            icon: isRec ? Icons.stop : Icons.mic,
            color: isRec ? Colors.white : AppTheme.textMuted,
            bg: isRec ? const Color(0xFFB91C1C) : Colors.white.withOpacity(0.07),
            border: isRec ? const Color(0xFFB91C1C) : Colors.white.withOpacity(0.1)),
          const Gap(7),
          _IBtn(onTap: onSend, icon: Icons.send_rounded,
            color: Colors.white, bg: AppTheme.accentDark, border: AppTheme.accentDark),
        ]),
      ]),
    );
  }
}

class _IBtn extends StatelessWidget {
  final VoidCallback onTap; final IconData icon;
  final Color color, bg, border;
  const _IBtn({required this.onTap, required this.icon, required this.color, required this.bg, required this.border});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: border)),
      child: Icon(icon, color: color, size: 17),
    ));
  }
}
