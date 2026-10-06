import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/app_notification_service.dart';

void main() {
  test('announcement audiences cannot accidentally broaden to all roles', () {
    expect(announcementRecipientRole(' Staff '), 'staff');
    expect(announcementRecipientRole('tenants'), 'tenant');
    expect(announcementRecipientRole('guardians'), 'guardian');
    expect(announcementRecipientRole('all'), 'all');
    expect(() => announcementRecipientRole('typo'), throwsArgumentError);
  });

  test('simultaneous notifications have deterministic newest-first ordering',
      () {
    final time = DateTime.utc(2026, 10, 7);
    AppNotificationItem row(String id, DateTime date) => AppNotificationItem(
          id: id,
          recipientId: 'recipient',
          notificationType: 'payment',
          title: 'Bill',
          body: 'Update',
          createdAt: date,
        );
    final rows = [
      row('a', time),
      row('c', time),
      row('b', time),
      row('d', time.subtract(const Duration(seconds: 1)))
    ];
    rows.sort(compareNotificationsNewestFirst);
    expect(rows.map((row) => row.id), ['c', 'b', 'a', 'd']);
    const id = '00000000-0000-0000-0000-000000000002';
    expect(notificationPageCursorFilter(time, id),
        'created_at.lt.2026-10-07T00:00:00.000Z,and(created_at.eq.2026-10-07T00:00:00.000Z,id.lt.$id)');
    expect(() => notificationPageCursorFilter(time, 'invalid,filter'),
        throwsArgumentError);
  });

  test('cron bearer handlers are reachable without disabling their own auth',
      () {
    final config = File('supabase/config.toml').readAsStringSync();
    for (final name in [
      'process-report-pushes',
      'process-guardian-presence-alerts',
      'process-location-monitoring-alerts'
    ]) {
      expect(
          RegExp('\\[functions\\.$name\\]\\s*verify_jwt = false')
              .hasMatch(config),
          isTrue,
          reason: name);
      final handler = File('supabase/functions/$name/handler.ts');
      final source = (handler.existsSync()
              ? handler
              : File('supabase/functions/$name/index.ts'))
          .readAsStringSync();
      expect(source, contains('guardian_alert_cron_credentials'));
      expect(source, contains('401'));
    }
  });
}
