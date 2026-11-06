// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter_animate/flutter_animate.dart';

import 'shared/theme/app_theme.dart';
import 'shared/widgets/apple_widgets.dart';
import 'core/services/providers.dart';
import 'core/services/settings_provider.dart';
import 'core/services/voice_service.dart';
import 'features/wizard/wizard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Hive.initFlutter();
  runApp(const ProviderScope(child: SplitCheckApp()));
}

class SplitCheckApp extends ConsumerWidget {
  const SplitCheckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final language  = ref.watch(languageProvider);

    return MaterialApp(
      title: 'SplitCheck',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  themeMode,
      locale: Locale(language),
      // Enables right-to-left layout + Arabic system text in Arabic mode.
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      // Status/navigation bar icons follow light/dark on every screen.
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
          child: child!,
        );
      },
      home: const _AppInit(),
    );
  }
}

/// Loads saved settings before showing the main screen
class _AppInit extends ConsumerStatefulWidget {
  const _AppInit();
  @override
  ConsumerState<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends ConsumerState<_AppInit> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // The welcome screen stays up for ~1.8 s (or until settings load, if slower).
    final minSplash = Future.delayed(const Duration(milliseconds: 1800));
    await ref.read(themeProvider.notifier).init();
    await ref.read(languageProvider.notifier).init();
    await ref.read(currencyProvider.notifier).init();
    await ref.read(myNameProvider.notifier).init();
    await ref.read(groupsProvider.notifier).init();
    // Voice input starts in the saved app language.
    ref.read(voiceLocaleProvider.notifier).value =
        voiceLocaleFor(ref.read(languageProvider));
    if (mounted) setState(() => _loaded = true); // shows the slogan in the saved language
    await minSplash;
    if (mounted) setState(() => _ready = true);
  }

  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _ready ? const WizardScreen() : _Splash(showText: _loaded),
    );
  }
}

/// Welcome screen: app icon, name and slogan.
class _Splash extends ConsumerWidget {
  final bool showText;
  const _Splash({required this.showText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              boxShadow: [BoxShadow(
                color: const Color(0xFF0A5BDB).withValues(alpha: 0.30),
                blurRadius: 30, offset: const Offset(0, 12))],
            ),
            child: const AppGlyph(size: 120),
          ).animate().scale(begin: const Offset(.85, .85), duration: 500.ms, curve: Curves.easeOutBack)
              .fadeIn(duration: 300.ms),
          const SizedBox(height: 26),
          Text(s.appName, style: TextStyle(
            fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1, color: p.label))
              .animate().fadeIn(delay: 200.ms, duration: 400.ms).moveY(begin: 8, end: 0),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: showText ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            child: Text(s.slogan, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: p.secondary, height: 1.35)),
          ),
        ]),
      ),
    );
  }
}
