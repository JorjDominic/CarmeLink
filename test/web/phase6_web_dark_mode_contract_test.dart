import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final webApp = File('lib/web/app/carmelink_web_app.dart').readAsStringSync();
  final webTheme = File('lib/web/theme/web_theme.dart').readAsStringSync();
  final overview =
      File('lib/web/dashboard/staff_overview_page.dart').readAsStringSync();
  final cards = File('lib/web/dashboard/widgets/staff_overview_card.dart')
      .readAsStringSync();
  final chrome = File('lib/web/dashboard/widgets/staff_workspace_chrome.dart')
      .readAsStringSync();

  test('production web MaterialApp follows ThemeController', () {
    expect(webApp.contains("import '../../controllers/theme_controller.dart';"),
        isTrue);
    expect(webApp.contains('animation: controller'), isTrue);
    expect(webApp.contains('darkTheme: WebTheme.dark()'), isTrue);
    expect(webApp.contains('themeMode: controller.themeMode'), isTrue);
  });

  test('web theme exposes a dark ThemeData', () {
    expect(webTheme.contains('static ThemeData dark()'), isTrue);
    expect(webTheme.contains('AppTheme.dark()'), isTrue);
  });

  test('staff web surfaces use active theme colors instead of light palette',
      () {
    expect(overview.contains('WebPalette.'), isFalse);
    expect(cards.contains('WebPalette.'), isFalse);
    expect(chrome.contains('WebPalette.'), isFalse);
    expect(
        overview.contains('Theme.of(context).scaffoldBackgroundColor'), isTrue);
    expect(cards.contains('Theme.of(context).colorScheme.surface'), isTrue);

    // StaffWorkspaceChrome caches Theme.of(context) and derives the active
    // ColorScheme from that ThemeData. Keep this contract semantic instead of
    // requiring one exact inline expression.
    expect(chrome.contains('final theme = Theme.of(context);'), isTrue);
    expect(chrome.contains('final scheme = theme.colorScheme;'), isTrue);
    expect(chrome.contains('final onSurface = scheme.onSurface;'), isTrue);
  });
}
