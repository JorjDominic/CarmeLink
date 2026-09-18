import 'package:flutter/material.dart';

/// Website-only tokens. Mobile AppTheme is intentionally untouched.
abstract final class WebPalette {
  static const ink = Color(0xFF292431);
  static const plum = Color(0xFF47304C);
  static const plumLight = Color(0xFF795D7C);
  static const background = Color(0xFFFBF9F5);
  static const cream = Color(0xFFF3EEE7);
  static const sand = Color(0xFFE8DDCF);
  static const muted = Color(0xFF665F69);
  static const border = Color(0xFFDDD4CC);
  static const gold = Color(0xFFCEAB79);
}

abstract final class WebTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: WebPalette.plum,
      brightness: Brightness.light,
      surface: WebPalette.background,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: WebPalette.background,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: WebPalette.ink, height: 1.5),
        bodyLarge: TextStyle(color: WebPalette.ink, height: 1.6),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: WebPalette.background,
        foregroundColor: WebPalette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: WebPalette.plum,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WebPalette.plum,
          side: const BorderSide(color: WebPalette.border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dividerColor: WebPalette.border,
    );
  }
}
