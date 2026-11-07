// lib/features/wizard/wizard_widgets.dart
//
// Building blocks shared by every full-screen page: the page layout (title,
// content, Back + main button), option cards, number grids and pills.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/settings_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';
import 'wizard_controller.dart';

/// Standard page: optional eyebrow ("ITEM 1 OF 3"), big title, hint, scrollable
/// content, and a footer with ‹ Back and the main button.
class WizardPage extends ConsumerWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String? primaryLabel;
  final VoidCallback? onPrimary;  // null = disabled
  final bool showBack;
  final bool centered;            // centred hero layout (VAT page, round-up)

  const WizardPage({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    required this.children,
    this.primaryLabel,
    this.onPrimary,
    this.showBack = true,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final w = ref.watch(wizardProvider);
    final bottom = MediaQuery.of(context).padding.bottom;
    final canBack = showBack && w.canGoBack;

    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            if (eyebrow != null)
              Text(eyebrow!.toUpperCase(), textAlign: centered ? TextAlign.center : TextAlign.start,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: .3, color: p.accent)),
            Text(title, textAlign: centered ? TextAlign.center : TextAlign.start,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.6, color: p.label, height: 1.15)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, textAlign: centered ? TextAlign.center : TextAlign.start,
                  style: TextStyle(fontSize: 15, color: p.secondary, height: 1.3)),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
      if (canBack || primaryLabel != null)
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottom),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(top: BorderSide(color: p.separator.withValues(alpha: .4), width: .5)),
          ),
          child: Row(children: [
            if (canBack)
              SizedBox(
                width: primaryLabel == null ? null : 110,
                child: primaryLabel == null
                    ? null
                    : AppleButton(label: (s.isAr ? '› ${s.back}' : '‹ ${s.back}'), filled: false,
                        onTap: () { HapticFeedback.selectionClick(); ref.read(wizardProvider.notifier).back(); }),
              ),
            if (canBack && primaryLabel == null)
              Expanded(child: AppleButton(label: (s.isAr ? '› ${s.back}' : '‹ ${s.back}'), filled: false,
                  onTap: () { HapticFeedback.selectionClick(); ref.read(wizardProvider.notifier).back(); })),
            if (canBack && primaryLabel != null) const SizedBox(width: 10),
            if (primaryLabel != null)
              Expanded(child: AppleButton(label: primaryLabel!, onTap: onPrimary == null ? null : () {
                HapticFeedback.lightImpact();
                onPrimary!();
              })),
          ]),
        ),
    ]);
  }
}

/// Big tappable card with an emoji, title and hint (Dine-in / Delivery, Scan / Manual).
class OptionCard extends StatelessWidget {
  final String emoji, title, hint;
  final bool selected;
  final VoidCallback onTap;
  const OptionCard({super.key, required this.emoji, required this.title, required this.hint,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true, selected: selected, label: '$title. $hint', excludeSemantics: true,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        scale: .98,
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected ? p.accent.withValues(alpha: p.isDark ? .18 : .07) : p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? p.accent : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.label)),
              const SizedBox(height: 3),
              Text(hint, style: TextStyle(fontSize: 14, color: p.secondary, height: 1.3)),
            ])),
            if (selected) Icon(CupertinoIcons.checkmark_circle_fill, color: p.accent, size: 24),
          ]),
        ),
      ),
    ));
  }
}

/// Grid of number buttons (people count, item count, tip %).
class NumberGrid extends StatelessWidget {
  final List<String> labels;
  final int? selected;            // index into labels
  final ValueChanged<int> onTap;
  final int columns;
  const NumberGrid({super.key, required this.labels, required this.selected, required this.onTap, this.columns = 5});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10,
      childAspectRatio: columns >= 5 ? 1.15 : 1.6,
      children: [
        for (var i = 0; i < labels.length; i++)
          Semantics(
            button: true, selected: i == selected, label: labels[i], excludeSemantics: true,
            child: PressableScale(
            onTap: () { HapticFeedback.selectionClick(); onTap(i); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == selected ? p.accent : p.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(labels[i], style: TextStyle(
                fontSize: labels[i].length > 3 ? 16 : 22, fontWeight: FontWeight.w600,
                color: i == selected ? Colors.white : p.label)),
            ),
          )),
      ],
    );
  }
}

/// Selectable pill (who shared an item, name suggestions).
class Pill extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool soft;   // suggestion style (white, no border)
  const Pill({super.key, required this.label, required this.on, required this.onTap, this.soft = false});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true, selected: on, label: label, excludeSemantics: true,
      child: PressableScale(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: soft ? 11 : 14, vertical: soft ? 7 : 9),
        decoration: BoxDecoration(
          color: on ? p.accent : p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? p.accent : (soft ? Colors.transparent : p.separator), width: 1.2),
        ),
        child: Text(label, style: TextStyle(
          fontSize: soft ? 14 : 15, fontWeight: soft ? FontWeight.w500 : FontWeight.w600,
          color: on ? Colors.white : p.label)),
      ),
    ));
  }
}

/// Small grey section label ("NAME", "PRICE", "WHO SHARED IT?") with an optional action.
class SectionLabel extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const SectionLabel(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: TextStyle(fontSize: 13, color: p.secondary))),
        if (action != null)
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onAction?.call(); },
            child: Text(action!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.accent)),
          ),
      ]),
    );
  }
}

/// Tap-to-advance: show the selection for a moment, then move on.
void advanceSoon(VoidCallback next) => Future.delayed(const Duration(milliseconds: 180), next);

/// Round → button shown inside an "Other number" field once something is typed.
class GoButton extends StatelessWidget {
  final VoidCallback? onTap;
  const GoButton({super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true, label: 'Go', excludeSemantics: true,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(34, 34),
        onPressed: onTap == null ? null : () { HapticFeedback.lightImpact(); onTap!(); },
        child: Icon(Directionality.of(context) == TextDirection.rtl
            ? CupertinoIcons.arrow_left_circle_fill : CupertinoIcons.arrow_right_circle_fill,
            color: onTap == null ? p.tertiary : p.accent, size: 30),
      ),
    );
  }
}

/// White rounded card.
class WCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const WCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14)),
      child: child,
    );
  }
}

/// Secondary full-width button (grey).
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SecondaryButton(this.label, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: AppleButton(label: label, filled: false, onTap: () { HapticFeedback.selectionClick(); onTap(); }),
  );
}
