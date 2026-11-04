// lib/main.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'shared/theme/app_theme.dart';
import 'core/services/settings_provider.dart';
import 'features/flow/chat_screen.dart';

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
    await ref.read(themeProvider.notifier).init();
    await ref.read(languageProvider.notifier).init();
    await ref.read(currencyProvider.notifier).init();
    await ref.read(roundUpProvider.notifier).init();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator(radius: 14)));
    }
    return const ChatScreen();
  }
}
