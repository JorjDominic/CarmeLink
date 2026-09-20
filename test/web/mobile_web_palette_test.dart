import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/constants/app_colors.dart';
import 'package:carmelitas_dormitory_system/core/theme/app_theme.dart';
import 'package:carmelitas_dormitory_system/web/theme/web_theme.dart';

void main() {
  test('Web palette uses the same brand tokens as mobile', () {
    expect(WebPalette.plum, AppColors.lightPrimary);
    expect(WebPalette.background, AppColors.lightBackground);
    expect(WebPalette.surface, AppColors.lightSurface);
    expect(WebPalette.ink, AppColors.lightText);
    expect(WebPalette.muted, AppColors.brown);
    expect(WebPalette.border, AppColors.softBorder);
  });

  test('Web and mobile share the same light color scheme', () {
    final mobile = AppTheme.light();
    final web = WebTheme.light();
    expect(web.colorScheme.primary, mobile.colorScheme.primary);
    expect(web.colorScheme.secondary, mobile.colorScheme.secondary);
    expect(web.colorScheme.surface, mobile.colorScheme.surface);
    expect(web.colorScheme.onSurface, mobile.colorScheme.onSurface);
    expect(web.scaffoldBackgroundColor, mobile.scaffoldBackgroundColor);
  });
}
