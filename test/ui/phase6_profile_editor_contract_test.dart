import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final page =
      File('lib/views/shared/profile_edit_page.dart').readAsStringSync();
  final shared = File('lib/views/shared/shared_views.dart').readAsStringSync();
  final session =
      File('lib/controllers/session_controller.dart').readAsStringSync();
  final theme =
      File('lib/controllers/theme_controller.dart').readAsStringSync();

  test('settings exposes profile editor', () {
    expect(shared.contains("import 'profile_edit_page.dart';"), isTrue);
    expect(shared.contains('ProfileEditPage()'), isTrue);
    expect(shared.contains('Edit profile'), isTrue);
  });

  test('profile editor keeps protected account identity read only', () {
    expect(page.contains("title: const Text('Email')"), isTrue);
    expect(page.contains("title: const Text('Role')"), isTrue);
    expect(page.contains('Icons.lock_outline'), isTrue);
    expect(page.contains('Save profile'), isTrue);
  });

  test('tenant fields exclude emergency contact editing', () {
    expect(page.contains('Home address'), isTrue);
    expect(page.contains('School / institution'), isTrue);
    expect(page.contains('Course / program'), isTrue);
    expect(
        page.contains(
            'Emergency contact remains in the onboarding details workflow.'),
        isTrue);
    expect(page.contains("labelText: 'Emergency contact'"), isFalse);
  });

  test('session refresh and theme persistence are wired', () {
    expect(session.contains('refreshCurrentUser()'), isTrue);
    expect(session.contains('ThemeController.instance.loadForCurrentUser()'),
        isTrue);
    expect(theme.contains('UserPreferencesService'), isTrue);
    expect(theme.contains('saveThemeMode'), isTrue);
  });
}
