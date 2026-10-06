import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cleaning report notification contract', () {
    test('database notification targets staff on submit and tenant on review',
        () {
      final source = File(
        'supabase/migrations/202610070003_report_alerts.sql',
      ).readAsStringSync();

      expect(source.contains("role::text in ('owner', 'caretaker')"), isTrue);
      expect(source.contains("'cleaning_report'"), isTrue);
      expect(source.contains('new.reporter_id'), isTrue);
      expect(source.contains('new.status is distinct from old.status'), isTrue);
      expect(
        source.contains('new.staff_notes is distinct from old.staff_notes'),
        isTrue,
      );
    });

    test('server push preserves exact notification route and record id', () {
      final source = File(
        'supabase/functions/process-report-pushes/handler.ts',
      ).readAsStringSync();

      expect(source.contains('notification_id: notification.id'), isTrue);
      expect(source.contains('route_type: notification.route_type'), isTrue);
      expect(source.contains('route_id: notification.route_id'), isTrue);
      expect(source.contains(".is('revoked_at', null)"), isTrue);
      expect(source.contains('notification_push_deliveries'), isTrue);
    });
  });
}
