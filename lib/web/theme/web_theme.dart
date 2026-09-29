import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Light-mode aliases retained for the public marketing website. Authenticated
/// staff surfaces use Theme.of(context) so they can follow Light/Dark/System.
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
  static ThemeData light() => _fromAppTheme(AppTheme.light());

  static ThemeData dark() => _fromAppTheme(AppTheme.dark());

  static ThemeData _fromAppTheme(ThemeData base) {
    final scheme = base.colorScheme;
    final border = scheme.outlineVariant;
    final textTheme = base.textTheme.apply(fontFamily: 'Roboto').copyWith(
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface,
            height: 1.5,
            fontFamily: 'Roboto',
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurface,
            height: 1.6,
            fontFamily: 'Roboto',
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: base.scaffoldBackgroundColor,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dividerColor: border,
    );
  }
}
