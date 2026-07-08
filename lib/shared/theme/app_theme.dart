// lib/shared/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Dark colors ────────────────────────────────────────────────────────────
  static const darkBg          = Color(0xFF07090F);
  static const darkSurface     = Color(0xFF0B1120);
  static const darkCard        = Color(0xFF131F35);
  static const darkAccent      = Color(0xFF63B3ED);
  static const darkAccentDark  = Color(0xFF1254A0);
  static const darkSuccess     = Color(0xFF68D391);
  static const darkTextPrimary = Color(0xFFE2E8F0);
  static const darkTextMuted   = Color(0xFF8FA3BF);
  static const darkTextHint    = Color(0xFF4A6080);

  // ── Light colors ───────────────────────────────────────────────────────────
  static const lightBg          = Color(0xFFF7F9FC);
  static const lightSurface     = Color(0xFFFFFFFF);
  static const lightCard        = Color(0xFFEEF2F7);
  static const lightAccent      = Color(0xFF2B7EC1);
  static const lightAccentDark  = Color(0xFF1A5FA8);
  static const lightSuccess     = Color(0xFF2E9E5B);
  static const lightTextPrimary = Color(0xFF1A202C);
  static const lightTextMuted   = Color(0xFF4A5568);
  static const lightTextHint    = Color(0xFF9AA5B4);

  // ── Shared ─────────────────────────────────────────────────────────────────
  static const danger  = Color(0xFFFC8181);
  static const warning = Color(0xFFF6AD55);

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    bg: darkBg, surface: darkSurface, card: darkCard,
    accent: darkAccent, textPrimary: darkTextPrimary,
    textMuted: darkTextMuted, textHint: darkTextHint,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    bg: lightBg, surface: lightSurface, card: lightCard,
    accent: lightAccent, textPrimary: lightTextPrimary,
    textMuted: lightTextMuted, textHint: lightTextHint,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg, required Color surface, required Color card,
    required Color accent, required Color textPrimary,
    required Color textMuted, required Color textHint,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: Colors.white,
        secondary: isDark ? darkSuccess : lightSuccess,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: danger,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).apply(bodyColor: textPrimary, displayColor: textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardColor: card,
      dividerColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08),
    );
  }
}
