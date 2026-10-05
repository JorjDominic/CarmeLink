import 'dart:io';

import 'package:carmelitas_dormitory_system/core/constants/app_colors.dart';
import 'package:carmelitas_dormitory_system/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('navigation and dark mode cleanup contract', () {
    test('web PageFrame does not duplicate message and notification actions',
        () {
      final source =
          File('lib/core/widgets/common_widgets.dart').readAsStringSync();
      final pageFrameStart = source.indexOf('class PageFrame');
      final pageFrameEnd =
          source.indexOf('class _PageEntrance', pageFrameStart);
      expect(pageFrameStart, greaterThanOrEqualTo(0));
      expect(pageFrameEnd, greaterThan(pageFrameStart));

      final pageFrame = source.substring(pageFrameStart, pageFrameEnd);
      expect(pageFrame.contains('final canShowNotifications = !webPortal &&'),
          isTrue);
      expect(
          pageFrame.contains('final canShowMessages = !webPortal &&'), isTrue);
      expect(pageFrame.contains("tooltip: 'Messages'"), isTrue);
      expect(pageFrame.contains("tooltip: 'Notifications'"), isTrue);
    });

    test('web communication destinations replace stacked utility routes', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();
      final helperStart = source.indexOf('void _openWebCommunicationPage(');
      final helperEnd = source.indexOf('Widget _webWorkspace(', helperStart);
      expect(helperStart, greaterThanOrEqualTo(0));
      expect(helperEnd, greaterThan(helperStart));

      final helper = source.substring(helperStart, helperEnd);
      expect(helper.contains('if (_workspaceLabelOverride == label) return;'),
          isTrue);
      expect(helper.contains('pushAndRemoveUntil('), isTrue);
      expect(helper.contains('(route) => route.isFirst'), isTrue);
      expect(
          source.contains(
              "_openWebCommunicationPage(\n        _notificationsPage(),"),
          isTrue);
      expect(
          source.contains(
              "_openWebCommunicationPage(\n        widget.messagePage,"),
          isTrue);
    });

    test('mobile profile owns logout while web relies on top header', () {
      final source =
          File('lib/views/shared/shared_views.dart').readAsStringSync();
      final profileStart = source.indexOf('class _ProfileAccountActions');
      final profileEnd = source.indexOf('class ProfilePage', profileStart);
      final settingsStart = source.indexOf('class SettingsPage');
      final settingsEnd = source.indexOf('class FeedbackPage', settingsStart);

      expect(profileStart, greaterThanOrEqualTo(0));
      expect(profileEnd, greaterThan(profileStart));
      expect(settingsStart, greaterThanOrEqualTo(0));
      expect(settingsEnd, greaterThan(settingsStart));

      final profile = source.substring(profileStart, profileEnd);
      final settings = source.substring(settingsStart, settingsEnd);
      expect(
          profile.contains(
              'final webPortal = CarmeLinkSurfaceScope.isWebPortal(context);'),
          isTrue);
      expect(profile.contains('if (!webPortal) ...['), isTrue);
      expect(profile.contains("Key('profile-logout')"), isTrue);
      expect(settings.contains("Key('profile-logout')"), isFalse);
      expect(settings.contains('Icons.logout_rounded'), isFalse);
    });

    test('dark palette is neutral while retaining CarmeLink accent', () {
      final dark = AppTheme.dark();
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF18191A));
      expect(dark.colorScheme.surface, const Color(0xFF242526));
      expect(dark.colorScheme.surfaceContainerHighest, const Color(0xFF3A3B3C));
      expect(dark.colorScheme.onSurface, const Color(0xFFE4E6EB));
      expect(dark.colorScheme.onSurfaceVariant, const Color(0xFFB0B3B8));
      expect(dark.colorScheme.primary, const Color(0xFFC7A98E));

      final light = AppTheme.light();
      expect(light.scaffoldBackgroundColor, AppColors.lightBackground);
      expect(light.colorScheme.primary, AppColors.lightPrimary);
    });
  });
}
