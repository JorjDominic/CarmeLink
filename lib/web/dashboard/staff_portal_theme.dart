import 'package:flutter/material.dart';

import '../theme/web_theme.dart';

/// Strictly scoped to the staff web workspace. Uses the EXACT existing palette
/// and inherited font family, without changing global or mobile ThemeData.
abstract final class StaffPortalTheme {
  static ThemeData from(ThemeData base) {
    const rounded = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: WebPalette.border),
    );
    const focused = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: WebPalette.plum, width: 1.6),
    );
    return base.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: WebPalette.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: rounded,
        enabledBorder: rounded,
        focusedBorder: focused,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: WebPalette.danger),
        ),
        labelStyle: TextStyle(color: WebPalette.muted),
        hintStyle: TextStyle(color: WebPalette.muted),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(WebPalette.cream),
        dataRowMinHeight: 54,
        dataRowMaxHeight: 66,
        headingRowHeight: 48,
        dividerThickness: .65,
        horizontalMargin: 18,
        columnSpacing: 22,
        headingTextStyle: TextStyle(
          color: WebPalette.plum,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: TextStyle(color: WebPalette.ink, fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: WebPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WebPalette.border),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: WebPalette.sand,
        selectedColor: WebPalette.cream,
        side: const BorderSide(color: WebPalette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: const TextStyle(color: WebPalette.ink, fontSize: 12),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: WebPalette.plum,
        textColor: WebPalette.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 14),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: WebPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: WebPalette.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: const TextStyle(color: WebPalette.surface, fontSize: 12),
        decoration: BoxDecoration(
          color: WebPalette.ink,
          borderRadius: BorderRadius.circular(9),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: WebPalette.ink,
        contentTextStyle: TextStyle(color: WebPalette.surface),
      ),
      dividerTheme: const DividerThemeData(
        color: WebPalette.border,
        thickness: .7,
      ),
    );
  }
}
