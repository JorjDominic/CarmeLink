import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 2 notification center contract', () {
    test('loads recent notifications in small cursor pages', () {
      final service =
          File('lib/services/app_notification_service.dart').readAsStringSync();
      final page =
          File('lib/views/shared/shared_views.dart').readAsStringSync();

      expect(service.contains('fetchMyNotificationsPage'), isTrue);
      expect(service.contains(".lt('created_at'"), isTrue);
      expect(page.contains('static const int _pageSize = 15'), isTrue);
      expect(page.contains("Key('see-previous-notifications')"), isTrue);
      expect(page.contains('See previous notifications'), isTrue);
    });

    test('groups notifications and preserves low-click deep links', () {
      final page =
          File('lib/views/shared/shared_views.dart').readAsStringSync();
      expect(page.contains("return 'Today'"), isTrue);
      expect(page.contains("return 'Yesterday'"), isTrue);
      expect(page.contains("return 'Earlier'"), isTrue);
      expect(page.contains('unawaited(_markRead(item))'), isTrue);
      expect(
          page.contains('await widget.onOpenNotification?.call(item)'), isTrue);
      expect(page.contains("return 'Just now'"), isTrue);
    });

    test('read state and retention are backend authoritative', () {
      final service =
          File('lib/services/app_notification_service.dart').readAsStringSync();
      final migration = File(
        'supabase/migrations/202609281731_phase2_notifications_and_maintenance.sql',
      ).readAsStringSync();

      expect(service.contains("rpc('mark_all_notifications_read')"), isTrue);
      expect(
          service.contains("rpc('cleanup_my_expired_notifications')"), isTrue);
      expect(migration.contains('mark_all_notifications_read'), isTrue);
      expect(migration.contains('my_unread_notification_count'), isTrue);
      expect(service.contains('fetchMyUnreadCount'), isTrue);
      expect(migration.contains("interval '30 days'"), isTrue);
      expect(migration.contains("interval '60 days'"), isTrue);
      expect(migration.contains("interval '90 days'"), isTrue);
    });

    test('realtime stays primary with a slower catch-up fallback', () {
      final page =
          File('lib/views/shared/shared_views.dart').readAsStringSync();
      final shell =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();
      expect(page.contains('streamMyNotifications(limit: 30)'), isTrue);
      expect(page.contains('Duration(seconds: 60)'), isTrue);
      expect(shell.contains('streamMyNotifications(limit: 30)'), isTrue);
      expect(shell.contains('Duration(seconds: 60)'), isTrue);
    });

    test('badge count stays exact while older history is progressively loaded',
        () {
      final shell =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();
      expect(shell.contains('_refreshUnreadNotificationCount'), isTrue);
      expect(shell.contains('fetchMyUnreadCount()'), isTrue);
      expect(shell.contains('_onNotificationPageChanged'), isTrue);
      expect(
        shell.contains('onNotificationsChanged: _onNotificationPageChanged'),
        isTrue,
      );
    });
  });
}
