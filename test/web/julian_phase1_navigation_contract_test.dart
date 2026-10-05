import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Julian Phase 1 navigation contract', () {
    test('web utility actions live in the header without sidebar duplicates',
        () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(source.contains("Key('web-header-account')"), isTrue);
      expect(source.contains("tooltip: 'Notifications'"), isTrue);
      expect(source.contains("tooltip: 'Messages'"), isTrue);
      expect(source.contains("Key('web-staff-messages')"), isFalse);
      expect(source.contains("Key('web-staff-notifications')"), isFalse);
      expect(source.contains("Key('web-staff-settings')"), isFalse);
    });

    test('compact web menu hides duplicate utilities while mobile keeps them',
        () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(source.contains('this.showUtilityDestinations = true'), isTrue);
      expect(source.contains('showUtilityDestinations: false'), isTrue);
      expect(source.contains('if (showUtilityDestinations) ...['), isTrue);
    });

    test('management areas behave like a one-open-group accordion', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();
      final toggleStart = source.indexOf('void _toggleWebGroup(String group)');
      final toggleEnd = source.indexOf('void _select(int value)', toggleStart);

      expect(toggleStart, greaterThanOrEqualTo(0));
      expect(toggleEnd, greaterThan(toggleStart));

      final toggle = source.substring(toggleStart, toggleEnd);
      expect(toggle.contains('_expandedWebGroups.remove(group)'), isTrue);
      expect(toggle.contains('..clear()'), isTrue);
      expect(toggle.contains('..add(group)'), isTrue);
    });

    test('web navigation text wraps instead of forcing one-line ellipsis', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();
      final tileStart = source.indexOf(
        'Widget _destinationTile(BuildContext context, int itemIndex)',
      );
      final tileEnd = source.indexOf('@override', tileStart);

      expect(tileStart, greaterThanOrEqualTo(0));
      expect(tileEnd, greaterThan(tileStart));

      final tile = source.substring(tileStart, tileEnd);
      expect(tile.contains('maxLines: 2'), isTrue);
      expect(tile.contains('softWrap: true'), isTrue);
      expect(tile.contains('TextOverflow.ellipsis'), isFalse);
    });

    test('logout belongs to Profile account actions, not Settings', () {
      final source =
          File('lib/views/shared/shared_views.dart').readAsStringSync();
      final settingsStart = source.indexOf('class SettingsPage');
      final settingsEnd = source.indexOf('class FeedbackPage', settingsStart);

      expect(source.contains("Key('profile-logout')"), isTrue);
      expect(source.contains("label: const Text('Logout')"), isTrue);
      expect(settingsStart, greaterThanOrEqualTo(0));
      expect(settingsEnd, greaterThan(settingsStart));

      final settings = source.substring(settingsStart, settingsEnd);
      expect(settings.contains("Text('Sign out')"), isFalse);
      expect(settings.contains('Icons.logout_rounded'), isFalse);
    });
  });
}
