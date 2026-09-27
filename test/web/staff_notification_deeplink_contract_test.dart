import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('staff notification deep-link contract', () {
    test('notification rows invoke the shell navigation callback after read state', () {
      final source = File(
        'lib/views/shared/shared_views.dart',
      ).readAsStringSync();

      expect(source.contains('this.onOpenNotification'), isTrue);
      expect(source.contains('await _service.markAsRead(item.id)'), isTrue);
      expect(source.contains('await widget.onOpenNotification?.call(item)'), isTrue);
      expect(source.contains('Icons.chevron_right_rounded'), isTrue);
    });

    test('persistent web shell resolves notification taps inside the workspace', () {
      final source = File(
        'lib/core/widgets/adaptive_shell.dart',
      ).readAsStringSync();

      expect(source.contains('onOpenNotification: _openNotificationDestination'), isTrue);
      expect(source.contains('widget.notificationPageBuilder?.call(item)'), isTrue);
      expect(source.contains('_openWebWorkspacePage(destination)'), isTrue);
      expect(source.contains('onTap: onOpenNotifications'), isTrue);
    });

    test('message notifications open their exact conversation when route id exists', () {
      final source = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();

      expect(source.contains('notification.notificationType.trim().toLowerCase()'), isTrue);
      expect(source.contains("'message' || 'conversation' => OwnerMessagingPage("), isTrue);
      expect(source.contains('initialConversationId: notification.routeId'), isTrue);
    });
  });
}
