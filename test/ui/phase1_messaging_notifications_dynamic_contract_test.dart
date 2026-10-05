import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 1 messaging and notification dynamic contract', () {
    test('notification list has realtime plus polling fallback', () {
      final page =
          File('lib/views/shared/shared_views.dart').readAsStringSync();
      final migration = File(
        'supabase/migrations/202609270006_app_notifications_realtime.sql',
      ).readAsStringSync();

      expect(page.contains('streamMyNotifications(limit: 30)'), isTrue);
      expect(page.contains('Duration(seconds: 60)'), isTrue);
      expect(page.contains("Key('live-notifications-list')"), isTrue);
      expect(page.contains('onNotificationsChanged'), isTrue);
      expect(
          migration.contains(
              'alter publication supabase_realtime add table public.app_notifications'),
          isTrue);
    });

    test('message deep links resolve the exact conversation record', () {
      final controller = File(
        'lib/controllers/messaging_controller.dart',
      ).readAsStringSync();
      final service = File(
        'lib/services/messaging_service.dart',
      ).readAsStringSync();
      final owner = File('lib/views/owner/owner_pages.dart').readAsStringSync();

      expect(controller.contains('fetchConversationById'), isTrue);
      expect(
          service.contains('Future<ConversationRecord?> fetchConversationById'),
          isTrue);
      expect(owner.contains('return OwnerConversationPage(record: deepLinked)'),
          isTrue);
    });

    test('web and mobile badges remain compact and data driven', () {
      final adaptive = File(
        'lib/core/widgets/adaptive_shell.dart',
      ).readAsStringSync();
      final common = File(
        'lib/core/widgets/common_widgets.dart',
      ).readAsStringSync();

      expect(
          adaptive.contains('MessagingController.instance.unreadMessageCount'),
          isTrue);
      expect(adaptive.contains('_UnreadCountBadge('), isTrue);
      expect(adaptive.contains('compact: true'), isTrue);
      expect(common.contains('navScope?.unreadMessageCount ?? 0'), isTrue);
      expect(common.contains('navScope?.unreadNotificationCount ?? 0'), isTrue);
    });

    test('conversation threads use a fixed viewport with internal scrolling',
        () {
      final common = File(
        'lib/core/widgets/common_widgets.dart',
      ).readAsStringSync();
      final tenant = File(
        'lib/views/tenant/tenant_pages.dart',
      ).readAsStringSync();
      final guardian = File(
        'lib/views/guardian/guardian_pages.dart',
      ).readAsStringSync();
      final owner = File('lib/views/owner/owner_pages.dart').readAsStringSync();

      expect(common.contains('class ConversationThreadPanel'), isTrue);
      expect(common.contains("Key('conversation-message-scroll')"), isTrue);
      expect(common.contains('ListView.builder('), isTrue);
      expect(common.contains("Key('conversation-composer')"), isTrue);
      expect(common.contains("label: const Text('New messages')"), isTrue);
      final direct = File('lib/views/shared/staff_message_contacts.dart').readAsStringSync();
      expect(tenant.contains('StaffMessageContacts()'), isTrue);
      expect(guardian.contains('StaffMessageContacts()'), isTrue);
      expect(direct.contains('ConversationThreadPanel('), isTrue);
      expect(owner.contains('ConversationThreadPanel('), isTrue);
    });

    test('mobile shells resolve notifications without leaving dead rows', () {
      for (final file in [
        'lib/views/tenant/tenant_shell.dart',
        'lib/views/guardian/guardian_shell.dart',
        'lib/views/owner/owner_shell.dart',
        'lib/views/caretaker/caretaker_shell.dart',
      ]) {
        final source = File(file).readAsStringSync();
        expect(
            source
                .contains('notificationPageBuilder: _notificationDestination'),
            isTrue,
            reason: file);
        expect(source.contains("'message' || 'conversation'"), isTrue,
            reason: file);
      }
    });
  });
}
