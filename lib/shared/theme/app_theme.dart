// lib/shared/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const bg          = Color(0xFF07090F);
  static const surface     = Color(0xFF0B1120);
  static const card        = Color(0xFF131F35);
  static const accent      = Color(0xFF63B3ED);
  static const accentDark  = Color(0xFF1254A0);
  static const success     = Color(0xFF68D391);
  static const warning     = Color(0xFFF6AD55);
  static const danger      = Color(0xFFFC8181);
  static const textPrimary = Color(0xFFE2E8F0);
  static const textMuted   = Color(0xFF8FA3BF);
  static const textHint    = Color(0xFF4A6080);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: success,
      surface: surface,
      error: danger,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      iconTheme: IconThemeData(color: textPrimary),
    ),
  );
}
