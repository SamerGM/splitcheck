// lib/shared/theme/app_theme.dart
//
// Apple-inspired design tokens: iOS system colours, grouped backgrounds,
// iMessage-style bubbles, generous rounding and tight large-title type.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colours for one brightness. Read with `Palette.of(context)`.
class Palette {
  final Brightness brightness;
  final Color bg;            // systemGroupedBackground
  final Color surface;       // secondarySystemGroupedBackground (cards, sheets)
  final Color elevated;      // tertiary surfaces inside cards
  final Color label;         // primary text
  final Color secondary;     // secondary text
  final Color tertiary;      // hints, placeholders
  final Color separator;
  final Color fill;          // tinted fills for fields / gray buttons
  final Color accent;        // systemBlue
  final Color green;         // systemGreen
  final Color red;           // systemRed
  final Color botBubble;     // iMessage gray
  final Color userBubble;    // iMessage blue
  final Color barBg;         // translucent nav / input bars

  const Palette._({
    required this.brightness, required this.bg, required this.surface,
    required this.elevated, required this.label, required this.secondary,
    required this.tertiary, required this.separator, required this.fill,
    required this.accent, required this.green, required this.red,
    required this.botBubble, required this.userBubble, required this.barBg,
  });

  bool get isDark => brightness == Brightness.dark;

  static const light = Palette._(
    brightness: Brightness.light,
    bg:         Color(0xFFF2F2F7),
    surface:    Color(0xFFFFFFFF),
    elevated:   Color(0xFFF2F2F7),
    label:      Color(0xFF000000),
    secondary:  Color(0x993C3C43),
    tertiary:   Color(0x4D3C3C43),
    separator:  Color(0x4A3C3C43),
    fill:       Color(0x1F767680),
    accent:     Color(0xFF007AFF),
    green:      Color(0xFF34C759),
    red:        Color(0xFFFF3B30),
    botBubble:  Color(0xFFE9E9EB),
    userBubble: Color(0xFF007AFF),
    barBg:      Color(0xD9F9F9F9),
  );

  static const dark = Palette._(
    brightness: Brightness.dark,
    bg:         Color(0xFF000000),
    surface:    Color(0xFF1C1C1E),
    elevated:   Color(0xFF2C2C2E),
    label:      Color(0xFFFFFFFF),
    secondary:  Color(0x99EBEBF5),
    tertiary:   Color(0x4DEBEBF5),
    separator:  Color(0xA6545458),
    fill:       Color(0x3D767680),
    accent:     Color(0xFF0A84FF),
    green:      Color(0xFF30D158),
    red:        Color(0xFFFF453A),
    botBubble:  Color(0xFF26252A),
    userBubble: Color(0xFF0A84FF),
    barBg:      Color(0xCC1C1C1E),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class AppTheme {
  static ThemeData get light => _build(Palette.light);
  static ThemeData get dark  => _build(Palette.dark);

  static ThemeData _build(Palette p) {
    final base = p.isDark ? ThemeData.dark() : ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bg,
      splashFactory: NoSplash.splashFactory,   // no Material ripples
      highlightColor: Colors.transparent,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.accent,
        onPrimary: Colors.white,
        secondary: p.green,
        onSecondary: Colors.white,
        surface: p.surface,
        onSurface: p.label,
        error: p.red,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme)
          .apply(bodyColor: p.label, displayColor: p.label),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: p.brightness,
        primaryColor: p.accent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      dividerColor: p.separator,
    );
  }
}
