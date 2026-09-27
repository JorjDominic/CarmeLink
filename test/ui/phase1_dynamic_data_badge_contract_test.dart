import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 1 dynamic data and compact badge contract', () {
    test('sidebar counts stay attached to icons instead of stretching rows', () {
      final adaptive = File(
        'lib/core/widgets/adaptive_shell.dart',
      ).readAsStringSync();

      expect(adaptive.contains('class _MenuIconWithBadge'), isTrue);
      expect(adaptive.contains("key: const Key('web-staff-messages')"), isTrue);
      expect(adaptive.contains("key: const Key('web-staff-notifications')"), isTrue);
      expect(adaptive.contains('leading: _MenuIconWithBadge('), isTrue);
      expect(adaptive.contains('textAlign: TextAlign.center'), isTrue);
      expect(adaptive.contains('trailing: unreadMessageCount > 0'), isFalse);
      expect(adaptive.contains('trailing: unreadNotificationCount > 0'), isFalse);
    });

    test('table subscriptions have realtime plus bounded catch-up refresh', () {
      final source = File(
        'lib/services/table_refresh_subscription.dart',
      ).readAsStringSync();

      expect(source.contains('onPostgresChanges('), isTrue);
      expect(source.contains('catchUpInterval = const Duration(seconds: 30)'), isTrue);
      expect(source.contains('Timer.periodic('), isTrue);
      expect(source.contains('_catchUpTimer?.cancel()'), isTrue);
    });

    test('role shells keep primary controller-backed data live', () {
      final tenant = File('lib/views/tenant/tenant_shell.dart').readAsStringSync();
      final owner = File('lib/views/owner/owner_shell.dart').readAsStringSync();
      final caretaker = File('lib/views/caretaker/caretaker_shell.dart').readAsStringSync();
      final guardian = File('lib/controllers/guardian_controller.dart').readAsStringSync();

      expect(tenant.contains("'tenant-shell-live-data'"), isTrue);
      expect(tenant.contains('loadPayments(force: true)'), isTrue);
      expect(tenant.contains('loadGateEvents(force: true)'), isTrue);
      expect(tenant.contains('loadVisitors(force: true)'), isTrue);

      expect(owner.contains("'owner-shell-live-data'"), isTrue);
      expect(owner.contains('loadContracts(force: true)'), isTrue);
      expect(owner.contains('loadStaffMaintenance(force: true)'), isTrue);
      expect(owner.contains('loadVisitors(force: true)'), isTrue);

      expect(caretaker.contains("'caretaker-shell-live-data'"), isTrue);
      expect(caretaker.contains('loadStaffMaintenance(force: true)'), isTrue);
      expect(caretaker.contains('loadGateEvents(force: true)'), isTrue);

      expect(guardian.contains("'guardian-data-sync'"), isTrue);
      expect(guardian.contains("'gate_events'"), isTrue);
    });

    test('feature pages retain live subscriptions for operational modules', () {
      final files = <String, List<String>>{
        'lib/views/tenant/tenant_pages.dart': [
          'tenant-payments',
          'tenant-maintenance',
          'tenant-announcements-page',
          'tenant-curfew-presence',
          'tenant-visitors',
        ],
        'lib/views/owner/owner_pages.dart': [
          'tenant-directory',
          'owner-payment-verification',
          'staff-visitors',
          'owner-announcements',
        ],
        'lib/views/owner/room_monitoring_page.dart': ['rooms'],
        'lib/views/owner/staff_maintenance_page.dart': ['staff-maintenance'],
        'lib/views/shared/room_cleaning_pages.dart': ['room-cleaning-'],
        'lib/views/shared/room_inspection_pages.dart': ['room-inspections-'],
        'lib/views/shared/conduct_case_pages.dart': ['staff-conduct-cases'],
        'lib/views/shared/employee_curfew_profile_pages.dart': [
          'employee-curfew-profiles',
        ],
        'lib/views/shared/retention_settings_page.dart': [
          'retention-policy-settings',
        ],
        'lib/views/shared/account_management_page.dart': ['accounts'],
      };

      for (final entry in files.entries) {
        final source = File(entry.key).readAsStringSync();
        for (final token in entry.value) {
          expect(source.contains(token), isTrue, reason: '${entry.key}: $token');
        }
      }
    });

    test('messages and notifications keep their own realtime streams', () {
      final messaging = File(
        'lib/services/messaging_service.dart',
      ).readAsStringSync();
      final notifications = File(
        'lib/services/app_notification_service.dart',
      ).readAsStringSync();

      expect(messaging.contains('onPostgresChanges('), isTrue);
      expect(notifications.contains(".stream(primaryKey: ['id'])"), isTrue);
    });
  });
}
