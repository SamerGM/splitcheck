// lib/features/wizard/wizard_screen.dart
//
// The app's main screen: top bar (Start over · step · History · Settings),
// a thin progress line, and the current full-screen page.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/settings_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../history/history_screen.dart';
import '../settings/settings_page.dart';
import 'pages_charges.dart';
import 'pages_items.dart';
import 'pages_setup.dart';
import 'wizard_controller.dart';

class WizardScreen extends ConsumerWidget {
  const WizardScreen({super.key});

  Widget _page(WizardState w) => switch (w.step) {
    WStep.orderType   => const OrderTypePage(),
    WStep.pricesIncluded => const PricesIncludedPage(),
    WStep.country     => const CountryPage(),
    WStep.rates       => const RatesPage(),
    WStep.peopleCount => const PeopleCountPage(),
    WStep.names       => const NamesPage(),
    WStep.itemsMethod => const ItemsMethodPage(),
    WStep.itemCount   => const ItemCountPage(),
    WStep.itemEntry   => ItemEntryPage(index: w.nav.index),
    WStep.itemsReview => const ItemsReviewPage(),
    WStep.tip         => const TipPage(),
    WStep.delivery    => const DeliveryPage(),
    WStep.discount    => const DiscountPage(),
    WStep.roundUp     => const RoundUpPage(),
    WStep.quickCheck  => const QuickCheckPage(),
    WStep.chargesEdit => const ChargesEditPage(),
    WStep.result      => const ResultPage(),
  };

  Future<void> _confirmStartOver(BuildContext context, WidgetRef ref) async {
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
      ref.read(wizardProvider.notifier).startOver();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final w = ref.watch(wizardProvider);
    final n = WizardController.stepNumber(w.step);
    final progress = w.step == WStep.result ? 1.0 : n / WizardController.totalSteps;
    final top = MediaQuery.of(context).padding.top;
    // Android back button / gesture = the page's Back.
    return PopScope(
      canPop: !w.canGoBack,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) ref.read(wizardProvider.notifier).back(); },
      child: Scaffold(
        backgroundColor: p.bg,
        body: Column(children: [
          Container(
            padding: EdgeInsets.only(top: top),
            decoration: BoxDecoration(
              color: p.barBg,
              border: Border(bottom: BorderSide(color: p.separator, width: .33)),
            ),
            child: SizedBox(
              height: 52,
              child: Stack(children: [
                Positioned.fill(child: IgnorePointer(child: Center(
                  child: Text(n == 0 ? s.appName : s.stepOf(n, WizardController.totalSteps),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.secondary)),
                ))),
                Row(children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    onPressed: () => _confirmStartOver(context, ref),
                    child: Text(s.startOver, style: TextStyle(fontSize: 17, color: p.accent, letterSpacing: -.4)),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const HistoryScreen())),
                    child: Icon(CupertinoIcons.clock, color: p.accent, size: 23),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsetsDirectional.only(start: 6, end: 14),
                    onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SettingsPage())),
                    child: Icon(CupertinoIcons.gear_alt, color: p.accent, size: 24),
                  ),
                ]),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      widthFactor: progress,
                      child: Container(height: 3, decoration: BoxDecoration(
                        color: p.accent, borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(2)))),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              // A new key per page (and per item) so each page starts fresh.
              child: KeyedSubtree(
                key: ValueKey('${w.stack.length}-${w.step.name}-${w.nav.index}'),
                child: _page(w),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
