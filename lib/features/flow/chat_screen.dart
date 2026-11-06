// lib/features/flow/chat_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/models.dart';
import '../../core/services/providers.dart';
import '../../core/services/settings_provider.dart';
import '../../core/services/voice_service.dart';
import '../../core/utils/strings.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';
import '../history/history_screen.dart';
import '../result/result_card.dart';
import '../settings/settings_sheet.dart';
import 'chat_message.dart';
import 'flow_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _focus  = FocusNode();
  bool   _isRec = false;
  String _live  = '';
  bool   _voiceRetried = false;
  bool   _pickerOpen = false;

  @override
  void dispose() {
    _ctrl.dispose(); _scroll.dispose(); _focus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _send() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    HapticFeedback.lightImpact();
    _ctrl.clear();
    await ref.read(chatProvider.notifier).handleInput(v);
    _scrollToBottom();
  }

  // ── Receipt scan ───────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final s = ref.read(stringsProvider);
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(s.scanReceiptTitle),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(CupertinoIcons.camera, size: 20), const SizedBox(width: 8), Text(s.takePhoto),
            ]),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(CupertinoIcons.photo_on_rectangle, size: 20), const SizedBox(width: 8), Text(s.chooseGallery),
            ]),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(s.cancel),
        ),
      ),
    );
    if (source == null) return;
    final xf = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (xf == null) return;
    await ref.read(chatProvider.notifier).handleOcrFile(File(xf.path));
    _scrollToBottom();
  }

  // ── Voice ──────────────────────────────────────────────────────────────────
  Future<void> _toggleVoice() async {
    final voice  = ref.read(voiceServiceProvider);
    final locale = ref.read(voiceLocaleProvider);
    HapticFeedback.mediumImpact();
    if (_isRec) {
      await voice.stop();
      setState(() => _isRec = false);
      return;
    }
    setState(() { _isRec = true; _live = ''; _ctrl.text = ''; });
    await voice.listen(
      locale: locale,
      onResult: (text, isFinal) => setState(() => _live = text),
      onDone: () async {
        if (!mounted) return;
        setState(() => _isRec = false);
        final heard = _live.trim();
        if (heard.isEmpty) {
          if (!_voiceRetried) {
            _voiceRetried = true; // retry once automatically
            await SystemSound.play(SystemSoundType.click);
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) await _toggleVoice();
          } else {
            _voiceRetried = false;
            await voice.cancel();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ref.read(stringsProvider).couldntHear)),
              );
            }
          }
          return;
        }
        _voiceRetried = false;
        await _showVoiceConfirmation(heard);
      },
    );
  }

  Future<void> _showVoiceConfirmation(String heard) async {
    final s = ref.read(stringsProvider);
    final edit = TextEditingController(text: heard);
    final result = await showAppleSheet<String>(
      context: context,
      title: s.iHeard,
      builder: (ctx) {
        final p = Palette.of(ctx);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          CupertinoTextField(
            controller: edit,
            autofocus: false,
            minLines: 1, maxLines: 3,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            style: TextStyle(fontSize: 17, color: p.label),
            decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: AppleButton(
              label: s.tryAgain, icon: CupertinoIcons.arrow_counterclockwise, filled: false,
              onTap: () => Navigator.pop(ctx, '\u0000retry'),
            )),
            const SizedBox(width: 10),
            Expanded(child: AppleButton(
              label: s.send, icon: CupertinoIcons.arrow_up,
              onTap: () => Navigator.pop(ctx, edit.text.trim()),
            )),
          ]),
        ]);
      },
    );
    edit.dispose();
    if (!mounted || result == null) return;
    if (result == '\u0000retry') { await _toggleVoice(); return; }
    if (result.isNotEmpty) { _ctrl.text = result; await _send(); }
  }

  // ── Who-had-it picker ──────────────────────────────────────────────────────
  Future<void> _openPeoplePicker() async {
    if (_pickerOpen) return;
    _pickerOpen = true;
    final people = ref.read(billDraftProvider).people;
    final ctl = ref.read(chatProvider.notifier);
    final picked = await showAppleSheet<PickResult>(
      context: context,
      title: ref.read(stringsProvider).selectPeople,
      isDismissible: false,
      builder: (_) => PeoplePicker(people: people, initial: ctl.preselectedIds,
          initialPortions: ctl.preselectedPortions),
    );
    _pickerOpen = false;
    if (picked != null) {
      ctl.checkpoint();
      await ctl.confirmSelectedPeople(picked.ids, portions: picked.portions);
      _scrollToBottom();
    }
  }

  Future<void> _confirmRestart() async {
    final s = ref.read(stringsProvider);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.startOver),
        content: Text(s.startOverConfirm),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          CupertinoDialogAction(isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true), child: Text(s.startOver)),
        ],
      ),
    );
    if (ok == true) {
      HapticFeedback.mediumImpact();
      await ref.read(chatProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final isTyping = ref.watch(isTypingProvider);
    final step     = ref.watch(flowStepProvider);
    final result   = ref.watch(splitResultProvider);
    final bill     = ref.watch(finalBillProvider);
    final s        = ref.watch(stringsProvider);
    final p        = Palette.of(context);
    final canUndo  = ref.watch(canUndoProvider);
    final lastUserIndex = messages.lastIndexWhere((m) => m.role == MessageRole.user);

    ref.listen(chatProvider,     (_, __) => _scrollToBottom());
    ref.listen(isTypingProvider, (_, __) => _scrollToBottom());
    ref.listen(splitResultProvider, (_, __) => _scrollToBottom());
    ref.listen(flowStepProvider, (prev, next) {
      if (next == FlowStep.itemWho) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openPeoplePicker());
      }
    });

    final showScan = step == FlowStep.itemCount || step == FlowStep.itemName ||
        step == FlowStep.itemPrice;
    final topInset = MediaQuery.of(context).padding.top;
    const navHeight = 52.0;

    final count = messages.length + (isTyping ? 1 : 0) + (result != null && bill != null ? 1 : 0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.bg,
        body: Column(children: [
          Expanded(
            child: Stack(children: [
              // Messages scroll underneath the translucent nav bar.
              ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(12, topInset + navHeight + 12, 12, 12),
                itemCount: count,
                itemBuilder: (ctx, i) {
                  if (i >= messages.length) {
                    if (isTyping && i == messages.length) {
                      return const _TypingBubble(key: ValueKey('typing'));
                    }
                    return ResultCard(result: result!, bill: bill!)
                        .animate().fadeIn(duration: 350.ms).slideY(begin: .06, curve: Curves.easeOutCubic);
                  }
                  final msg  = messages[i];
                  final prev = i > 0 ? messages[i - 1] : null;
                  return _Bubble(
                    key: ValueKey(msg.id),
                    msg: msg,
                    grouped: prev?.role == msg.role,
                    // Undo sits under your most recent answer.
                    undoLabel: canUndo && i == lastUserIndex ? s.undo : null,
                    onUndo: () {
                      HapticFeedback.mediumImpact();
                      ref.read(chatProvider.notifier).undo();
                    },
                    onChip: (chip) {
                      HapticFeedback.selectionClick();
                      ref.read(chatProvider.notifier).chipTapped(msg, chip);
                    },
                  );
                },
              ),
              Positioned(
                top: 0, left: 0, right: 0,
                child: _NavBar(
                  height: navHeight,
                  progress: _progressFor(step),
                  title: s.appName,
                  onRestart: _confirmRestart,
                  onSettings: () => showSettingsSheet(context),
                  onHistory: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const HistoryScreen())),
                ),
              ),
            ]),
          ),
          _InputBar(
            ctrl: _ctrl, focus: _focus, isRec: _isRec, liveText: _live,
            showScan: showScan, s: s,
            onSend: _send, onVoice: _toggleVoice, onScan: _pickImage,
          ),
        ]),
      ),
    );
  }

  static double _progressFor(FlowStep step) => switch (step) {
    FlowStep.peopleCount => 0.05,
    FlowStep.people      => 0.14,
    FlowStep.itemCount   => 0.25,
    FlowStep.itemName || FlowStep.itemPrice || FlowStep.itemWho => 0.40,
    FlowStep.itemSummary || FlowStep.itemEdit => 0.55,
    FlowStep.vat         => 0.65,
    FlowStep.service     => 0.73,
    FlowStep.tip         => 0.79,
    FlowStep.delivery    => 0.84,
    FlowStep.discount    => 0.89,
    FlowStep.confirm || FlowStep.editMenu => 0.95,
    FlowStep.result      => 1.0,
    FlowStep.equalTotal  => 0.55,
  };
}

// ── NAV BAR ───────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final double height, progress;
  final String title;
  final VoidCallback onRestart, onSettings, onHistory;
  const _NavBar({required this.height, required this.progress, required this.title,
      required this.onRestart, required this.onSettings, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: top + height,
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: p.barBg,
            border: Border(bottom: BorderSide(color: p.separator, width: 0.33)),
          ),
          child: Stack(children: [
            // Title stays centred no matter how many buttons sit on each side.
            Positioned.fill(
              child: IgnorePointer(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const AppGlyph(size: 26),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: p.label)),
                ]),
              ),
            ),
            Row(children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: onRestart,
                child: Icon(CupertinoIcons.arrow_counterclockwise, color: p.accent, size: 22),
              ),
              const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: onHistory,
                child: Icon(CupertinoIcons.clock, color: p.accent, size: 23),
              ),
              CupertinoButton(
                padding: const EdgeInsetsDirectional.only(start: 6, end: 14),
                onPressed: onSettings,
                child: Icon(CupertinoIcons.ellipsis_circle, color: p.accent, size: 24),
              ),
            ]),
            // Thin progress line along the bottom edge, like Safari's loader.
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  widthFactor: progress,
                  child: Container(height: 2, color: p.accent),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── MESSAGE BUBBLE ────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final bool grouped;
  final void Function(QuickChip chip) onChip;
  final String? undoLabel;   // shown as "↩ Undo" under this message when set
  final VoidCallback? onUndo;
  const _Bubble({super.key, required this.msg, required this.grouped, required this.onChip,
      this.undoLabel, this.onUndo});

  @override
  Widget build(BuildContext context) {
    final p     = Palette.of(context);
    final isBot = msg.role == MessageRole.bot;
    final maxW  = MediaQuery.of(context).size.width * 0.78;
    const r = Radius.circular(20);
    const tail = Radius.circular(6);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isBot ? p.botBubble : p.userBubble,
        borderRadius: BorderRadiusDirectional.only(
          topStart: r, topEnd: r,
          bottomStart: isBot ? tail : r,
          bottomEnd:   isBot ? r : tail,
        ),
      ),
      child: Text(msg.text, style: TextStyle(
        fontSize: 16, height: 1.32, letterSpacing: -0.2,
        color: isBot ? p.label : Colors.white,
      )),
    );

    final chips = msg.chips ?? const <QuickChip>[];

    return Padding(
      padding: EdgeInsets.only(top: grouped ? 3 : 12),
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          bubble,
          if (undoLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: PressableScale(
                onTap: onUndo,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(CupertinoIcons.arrow_uturn_left, size: 13, color: p.accent),
                  const SizedBox(width: 4),
                  Text(undoLabel!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.accent)),
                ]),
              ),
            ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: [for (final c in chips) _ChipButton(chip: c, onTap: () => onChip(c))],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).moveY(begin: 8, end: 0, duration: 260.ms, curve: Curves.easeOutCubic);
  }
}

class _ChipButton extends StatelessWidget {
  final QuickChip chip;
  final VoidCallback onTap;
  const _ChipButton({required this.chip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: chip.used ? 0.38 : 1,
      child: PressableScale(
        onTap: chip.used ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: p.isDark ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(chip.label, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: p.accent)),
        ),
      ),
    );
  }
}

// ── TYPING INDICATOR ──────────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  const _TypingBubble({super.key});
  @override State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: p.botBubble, borderRadius: BorderRadius.circular(20)),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
              final t = ((_c.value - i * 0.18) % 1.0);
              final a = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Container(
                width: 8, height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: p.secondary.withValues(alpha: a), shape: BoxShape.circle),
              );
            })),
          ),
        ),
      ),
    );
  }
}

// ── INPUT BAR ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool isRec, showScan;
  final String liveText;
  final S s;
  final VoidCallback onSend, onVoice, onScan;

  const _InputBar({
    required this.ctrl, required this.focus, required this.isRec, required this.liveText,
    required this.showScan, required this.s,
    required this.onSend, required this.onVoice, required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottom),
          decoration: BoxDecoration(
            color: p.barBg,
            border: Border(top: BorderSide(color: p.separator, width: 0.33)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (isRec)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                child: Row(children: [
                  Icon(CupertinoIcons.waveform, color: p.red, size: 18)
                      .animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: .4, end: 1, duration: 600.ms),
                  const SizedBox(width: 8),
                  Expanded(child: Text(liveText.isEmpty ? s.listening : liveText,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: p.secondary))),
                ]),
              ),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: showScan
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: CircleIconButton(icon: CupertinoIcons.camera_fill, onTap: onScan),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.separator, width: 0.8),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: ctrl,
                        focusNode: focus,
                        minLines: 1, maxLines: 4,
                        placeholder: isRec ? s.listening : s.typeHint,
                        placeholderStyle: TextStyle(fontSize: 16, color: p.tertiary),
                        style: TextStyle(fontSize: 16, color: p.label),
                        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 6, 8),
                        decoration: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: ctrl,
                      builder: (_, v, __) {
                        final hasText = v.text.trim().isNotEmpty;
                        return Padding(
                          padding: const EdgeInsets.all(3),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                            child: hasText
                                ? PressableScale(
                                    key: const ValueKey('send'),
                                    onTap: onSend,
                                    child: Icon(CupertinoIcons.arrow_up_circle_fill, size: 30, color: p.accent),
                                  )
                                : PressableScale(
                                    key: const ValueKey('mic'),
                                    onTap: onVoice,
                                    child: Container(
                                      width: 30, height: 30,
                                      decoration: BoxDecoration(
                                        color: isRec ? p.red : Colors.transparent, shape: BoxShape.circle),
                                      child: Icon(isRec ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill,
                                          size: isRec ? 14 : 20, color: isRec ? Colors.white : p.secondary),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── PEOPLE PICKER (sheet body) ────────────────────────────────────────────────

/// What the picker returns: who had the item, and how many portions each.
typedef PickResult = ({List<String> ids, Map<String, int> portions});

class PeoplePicker extends ConsumerStatefulWidget {
  final List<Person> people;
  final List<String> initial;
  final Map<String, int> initialPortions;
  const PeoplePicker({super.key, required this.people, this.initial = const [],
      this.initialPortions = const {}});
  @override ConsumerState<PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends ConsumerState<PeoplePicker> {
  late final Set<String> _sel = {...widget.initial};
  late final Map<String, int> _portions = {...widget.initialPortions};

  bool get _all => _sel.length == widget.people.length;

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_sel.contains(id)) { _sel.remove(id); _portions.remove(id); } else { _sel.add(id); }
    });
  }

  void _bump(String id, int by) {
    HapticFeedback.selectionClick();
    setState(() => _portions[id] = ((_portions[id] ?? 1) + by).clamp(1, 20));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final maxH = MediaQuery.of(context).size.height * 0.5;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: InsetGroup(
          scrollable: true,
          inSheet: true,
          children: [
            _PickRow(
              leading: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: p.green, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.person_3_fill, color: Colors.white, size: 20),
              ),
              title: s.everyone,
              selected: _all,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (_all) { _sel.clear(); _portions.clear(); }
                  else { _sel.addAll(widget.people.map((e) => e.id)); }
                });
              },
            ),
            for (final person in widget.people)
              _PickRow(
                leading: Avatar(person: person, size: 34),
                title: person.name,
                selected: _sel.contains(person.id),
                portions: _sel.contains(person.id) ? (_portions[person.id] ?? 1) : null,
                onMinus: () => _bump(person.id, -1),
                onPlus: () => _bump(person.id, 1),
                onTap: () => _toggle(person.id),
              ),
          ],
        ),
      ),
      if (_sel.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(s.portionsHint, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.secondary)),
        ),
      const SizedBox(height: 16),
      AppleButton(
        label: s.confirm,
        onTap: _sel.isEmpty ? null : () {
          HapticFeedback.lightImpact();
          final ids = [for (final pp in widget.people) if (_sel.contains(pp.id)) pp.id];
          Navigator.pop<PickResult>(context, (
            ids: ids,
            portions: {for (final id in ids) if ((_portions[id] ?? 1) > 1) id: _portions[id]!},
          ));
        },
      ),
    ]);
  }
}

class _PickRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final bool selected;
  final int? portions;            // shown as a − n + stepper when not null
  final VoidCallback onTap;
  final VoidCallback? onMinus, onPlus;
  const _PickRow({required this.leading, required this.title, required this.selected,
      required this.onTap, this.portions, this.onMinus, this.onPlus});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget stepBtn(IconData icon, VoidCallback? cb, bool enabled) => PressableScale(
      onTap: enabled ? cb : null,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: p.fill, shape: BoxShape.circle),
        child: Icon(icon, size: 15, color: enabled ? p.accent : p.tertiary),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontSize: 17, letterSpacing: -0.4, color: p.label))),
          if (portions != null) ...[
            stepBtn(CupertinoIcons.minus, onMinus, portions! > 1),
            SizedBox(
              width: 34,
              child: Text('×$portions', textAlign: TextAlign.center, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: portions! > 1 ? p.accent : p.secondary)),
            ),
            stepBtn(CupertinoIcons.plus, onPlus, true),
            const SizedBox(width: 10),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              key: ValueKey(selected),
              color: selected ? p.accent : p.tertiary,
              size: 26,
            ),
          ),
        ]),
      ),
    );
  }
}

/// Keeps the voice locale in step with the app language.
VoiceLocale voiceLocaleFor(String lang) => lang == 'ar' ? VoiceLocale.arabic : VoiceLocale.english;
