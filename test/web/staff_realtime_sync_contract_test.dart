import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('staff web realtime sync contract', () {
    test('persistent staff shell listens to core operational data', () {
      final source = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();

      expect(source.contains("'staff-web-live-sync'"), isTrue);
      for (final table in [
        'profiles',
        'rooms',
        'payments',
        'maintenance_reports',
        'visitor_requests',
        'curfew_requests',
        'gate_events',
        'confidential_reports',
        'tenant_contracts',
        'announcements',
        'cleaning_schedules',
        'room_inspections',
        'conduct_cases',
      ]) {
        expect(source.contains("'$table'"), isTrue, reason: 'Missing $table');
      }

      expect(source.contains('loadRooms(force: true)'), isTrue);
      expect(source.contains('loadPayments(force: true)'), isTrue);
      expect(source.contains('loadGateEvents(force: true)'), isTrue);
      expect(source.contains('loadTenants(force: true)'), isTrue);
      expect(source.contains('Duration(seconds: 60)'), isTrue);
      expect(source.contains('AppLifecycleState.resumed'), isTrue);
    });

    test(
        'legacy payment subscriptions also observe authoritative billing tables',
        () {
      final source = File(
        'lib/services/table_refresh_subscription.dart',
      ).readAsStringSync();

      expect(source.contains("if (table == 'payments')"), isTrue);
      expect(source.contains("yield 'billing_charges'"), isTrue);
      expect(source.contains("yield 'payment_transactions'"), isTrue);
      expect(source.contains("yield 'billing_charge_actions'"), isTrue);
    });

    test('live in-app alerts update unread badges and keep navigation in shell',
        () {
      final source = File(
        'lib/core/widgets/adaptive_shell.dart',
      ).readAsStringSync();

      expect(source.contains('streamMyNotifications(limit: 30)'), isTrue);
      expect(source.contains('fetchMyNotifications(limit: 30)'), isTrue);
      expect(source.contains('Duration(seconds: 60)'), isTrue);
      expect(source.contains("label: 'View'"), isTrue);
      expect(source.contains('_UnreadCountBadge'), isTrue);
      expect(source.contains('openNotifications: _openNotifications'), isTrue);
      expect(
        source.contains('_openWebWorkspacePage(_notificationsPage())'),
        isTrue,
      );
    });

    test('actionable notifications map to existing live staff modules', () {
      final source = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();

      for (final route in [
        'payment',
        'maintenance',
        'visitor',
        'curfew',
        'gate',
        'gate_event',
        'conduct_case',
        'inspection',
        'announcement',
        'message',
        'conversation',
        'onboarding',
      ]) {
        expect(source.contains("'$route'"), isTrue, reason: 'Missing $route');
      }
      expect(
          source.contains('notificationPageBuilder: _notificationDestination'),
          isTrue);
      expect(source.contains('initialConversationId: notification.routeId'),
          isTrue);
    });
  });
}
