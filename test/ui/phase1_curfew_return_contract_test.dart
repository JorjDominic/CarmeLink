import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('staff reuses the existing Requests page with a type filter', () {
    final page = source('lib/views/shared/staff_curfew_requests_page.dart');

    expect(page, contains('StaffCurfewRequestsPage'));
    expect(page, contains("_requestTypeFilter = 'all'"));
    expect(page, contains("'late_return'"));
    expect(page, contains("'overnight_leave'"));
    expect(page, contains('Guardian notes:'));
    expect(page, contains('Guardian decision:'));
    expect(page, contains('Record return'));
    expect(page, contains('Edit recorded return'));
    expect(page, contains('Edit expected return'));
    expect(page, contains('request.isOverdue'));
  });

  test('service reads actual return and saves only verified staff input', () {
    final service = source('lib/services/curfew_service.dart');

    expect(service, contains('actual_return_time, created_at'));
    expect(service, contains('recordVerifiedReturn('));
    expect(service, contains('updateLateReturnExpectedTime('));
  });

  test('model treats outstanding approved overdue separately from completed',
      () {
    final now = DateTime.now();

    CurfewRequest request(DateTime expected, {DateTime? actual}) =>
        CurfewRequest(
          id: 'request-1',
          tenantId: 'tenant-1',
          destination: 'Library',
          reason: 'Study time',
          departureTime: now.subtract(const Duration(hours: 3)),
          expectedReturnTime: expected,
          status: 'approved',
          actualReturnTime: actual,
        );

    final overdue = request(now.subtract(const Duration(minutes: 5)));

    expect(overdue.isOverdue, isTrue);
    expect(overdue.isCompleted, isFalse);
    expect(overdue.statusLabel, 'Approved');

    final upcoming = request(now.add(const Duration(hours: 1)));

    expect(upcoming.isOverdue, isFalse);

    final returned = request(
      now.subtract(const Duration(minutes: 5)),
      actual: now.subtract(const Duration(minutes: 1)),
    );

    expect(returned.isOverdue, isFalse);
    expect(returned.isCompleted, isTrue);
    expect(returned.statusLabel, 'Returned');
  });

  test(
    'migration requires staff verification and deduped alerts without auto-scheduling',
    () {
      final sql = source(
        'supabase/migrations/202610080008_curfew_return_and_reminders.sql',
      );

      expect(sql, contains('Only staff can record or correct a return'));
      expect(sql, contains('curfew_return_reminder_log'));
      expect(sql, contains('on conflict do nothing'));
      expect(sql, isNot(contains('cron.schedule(')));
      expect(sql, contains('actual_return_time is null'));
      expect(sql, contains('emit_tenant_circle_notification'));
      expect(
        sql,
        contains(
          'revoke all on function public.process_curfew_return_reminders()',
        ),
      );
    },
  );
}
