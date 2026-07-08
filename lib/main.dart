// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    statusBarIconBrightness: Brightness.light,
  ));
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
    try {
      print('Loading theme...');
      await ref.read(themeProvider.notifier).init();
      print('Loading language...');
      await ref.read(languageProvider.notifier).init();
      print('Ready!');
      if (mounted) setState(() => _ready = true);
    } catch (e, st) {
      print('INIT ERROR: \$e');
      print(st);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const ChatScreen();
  }
}
