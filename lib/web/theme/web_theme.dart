import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Website colors are aliases of the MOBILE palette, not a second brand.
/// The legacy `plum` names are kept temporarily so existing web screens
/// continue compiling; their actual colors are now Carmelita brown/taupe.
abstract final class WebPalette {
  static const ink = AppColors.lightText;
  static const plum = AppColors.lightPrimary;
  static const plumLight = AppColors.brown;
  static const background = AppColors.lightBackground;
  static const surface = AppColors.lightSurface;
  static const cream = AppColors.cream;
  static const sand = AppColors.lightSurfaceMuted;
  static const muted = AppColors.brown;
  static const border = AppColors.softBorder;
  static const gold = AppColors.warning;
  static const danger = AppColors.danger;
}

abstract final class WebTheme {
  static ThemeData light() {
    // Same color scheme as the mobile app; web keeps its own layouts,
    // typography, button geometry and motion system.
    final scheme = AppTheme.light().colorScheme;
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
      cardTheme: CardThemeData(
        color: WebPalette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WebPalette.border),
        ),
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
