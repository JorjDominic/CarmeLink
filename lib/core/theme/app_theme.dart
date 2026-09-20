import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static const _lightBackground = AppColors.lightBackground;
  static const _lightSurface = AppColors.lightSurface;
  static const _lightSurfaceMuted = AppColors.lightSurfaceMuted;
  static const _darkBackground = Color(0xFF151310);
  static const _darkSurface = Color(0xFF211D19);
  static const _darkSurfaceMuted = Color(0xFF2B2520);
  static const _darkBorder = Color(0xFF3C342E);
  static const _lightText = AppColors.lightText;
  static const _darkText = Color(0xFFF7F0E7);
  static const _lightPrimary = AppColors.lightPrimary;
  static const _darkPrimary = Color(0xFFD9C0A7);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      brightness: Brightness.light,
      surface: _lightSurface,
    ).copyWith(
      primary: _lightPrimary,
      secondary: AppColors.taupe,
      surface: _lightSurface,
      onSurface: _lightText,
      outline: AppColors.softBorder,
    );

    return _base(
      scheme: scheme,
      scaffold: _lightBackground,
      surfaceMuted: _lightSurfaceMuted,
      border: AppColors.softBorder,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      brightness: Brightness.dark,
      surface: _darkSurface,
    ).copyWith(
      primary: _darkPrimary,
      secondary: const Color(0xFFB59A84),
      surface: _darkSurface,
      onSurface: _darkText,
      outline: _darkBorder,
    );

    return _base(
      scheme: scheme,
      scaffold: _darkBackground,
      surfaceMuted: _darkSurfaceMuted,
      border: _darkBorder,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Color scaffold,
    required Color surfaceMuted,
    required Color border,
    required Brightness brightness,
  }) {
    const largeRadius = BorderRadius.all(Radius.circular(24));
    const mediumRadius = BorderRadius.all(Radius.circular(18));
    const smallRadius = BorderRadius.all(Radius.circular(14));

    final textTheme = ThemeData(
      brightness: brightness,
      useMaterial3: true,
    )
        .textTheme
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        )
        .copyWith(
          displaySmall: TextStyle(
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            color: scheme.onSurface,
            fontFamilyFallback: const ['Georgia', 'Times New Roman'],
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            height: 1.10,
            fontWeight: FontWeight.w700,
            letterSpacing: -.55,
            color: scheme.onSurface,
            fontFamilyFallback: const ['Georgia', 'Times New Roman'],
          ),
          headlineSmall: TextStyle(
            fontSize: 23,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -.35,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            height: 1.20,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.45,
            color: scheme.onSurface,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.42,
            color: scheme.onSurface,
          ),
          bodySmall: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: scheme.onSurface.withValues(alpha: .68),
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      dividerColor: border,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _CarmelitaPageTransitionsBuilder(),
          TargetPlatform.iOS: _CarmelitaPageTransitionsBuilder(),
          TargetPlatform.macOS: _CarmelitaPageTransitionsBuilder(),
          TargetPlatform.windows: _CarmelitaPageTransitionsBuilder(),
          TargetPlatform.linux: _CarmelitaPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: largeRadius,
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light ? Colors.white : surfaceMuted,
        labelStyle: TextStyle(
          color: scheme.onSurface.withValues(alpha: .72),
        ),
        hintStyle: TextStyle(
          color: scheme.onSurface.withValues(alpha: .45),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: const RoundedRectangleBorder(
            borderRadius: mediumRadius,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          side: BorderSide(color: border),
          shape: const RoundedRectangleBorder(
            borderRadius: mediumRadius,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(46, 46),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: largeRadius,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFFEFE5D9)
            : const Color(0xFF2A211B),
        contentTextStyle: TextStyle(
          color: brightness == Brightness.dark
              ? const Color(0xFF241C17)
              : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: smallRadius,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        CarmelitaThemeExtension(
          surfaceMuted: surfaceMuted,
          border: border,
        ),
      ],
    );
  }
}

class _CarmelitaPageTransitionsBuilder extends PageTransitionsBuilder {
  const _CarmelitaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == Navigator.defaultRouteName) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.065, .012),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class CarmelitaThemeExtension extends ThemeExtension<CarmelitaThemeExtension> {
  const CarmelitaThemeExtension({
    required this.surfaceMuted,
    required this.border,
  });

  final Color surfaceMuted;
  final Color border;

  @override
  CarmelitaThemeExtension copyWith({
    Color? surfaceMuted,
    Color? border,
  }) {
    return CarmelitaThemeExtension(
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
    );
  }

  @override
  CarmelitaThemeExtension lerp(
    ThemeExtension<CarmelitaThemeExtension>? other,
    double t,
  ) {
    if (other is! CarmelitaThemeExtension) return this;
    return CarmelitaThemeExtension(
      surfaceMuted: Color.lerp(
            surfaceMuted,
            other.surfaceMuted,
            t,
          ) ??
          surfaceMuted,
      border: Color.lerp(border, other.border, t) ?? border,
    );
  }
}
