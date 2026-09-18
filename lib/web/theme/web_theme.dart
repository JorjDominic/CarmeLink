import 'package:flutter/material.dart';

/// Web-only design tokens; does not change the mobile AppTheme.
abstract final class WebPalette {
  static const primary = Color(0xFF755189);
  static const ink = Color(0xFF2B263C);
  static const muted = Color(0xFF676174);
  static const soft = Color(0xFFF5F0F7);
  static const background = Color(0xFFFBF9FC);
  static const border = Color(0xFFE9E1EC);
}

abstract final class WebTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: WebPalette.primary);
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: WebPalette.background,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: WebPalette.ink,
        surfaceTintColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: WebPalette.primary),
      ),
    );
  }
}
