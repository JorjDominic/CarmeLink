import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/app_notification_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/notification_destination.dart';

// Only routes emitted by existing services/functions/migrations, plus the ten
// database notification categories. False means a safe readable fallback,
// not permission to open another role's protected module.
const coverage = <String, List<bool>>{
  'announcement': [true, true, true, true],
  'payment': [true, true, true, true],
  'maintenance': [true, true, true, false],
  'curfew': [true, true, true, true],
  'visitor': [true, true, true, false],
  'gate': [true, true, true, true],
  'safety': [true, true, true, true],
  'onboarding': [true, true, true, true],
  'message': [true, true, true, true],
  'system': [false, false, false, false],
  'conversation': [true, true, true, true],
  'gate_event': [true, true, true, true],
  'confidential_report': [true, true, true, false],
  'cleaning_report': [true, true, true, false],
  'conduct_case': [true, true, true, false],
  'inspection': [true, true, true, false],
  'location_monitoring_incident': [true, true, true, true],
  'guardian_presence_alert': [true, true, false, true],
  'location_status_request': [true, true, true, true],
  'location_settings': [false, false, true, false],
  'employee_curfew': [true, true, true, false],
  'cleaning_schedule': [true, true, true, false],
  'room_assignment': [true, true, true, true],
  'guardian_link': [true, true, true, true],
  'move_out': [true, true, true, false],
};

void main() {
  final roles = [
    UserRole.owner,
    UserRole.caretaker,
    UserRole.tenant,
    UserRole.guardian
  ];
  for (final entry in coverage.entries) {
    for (var i = 0; i < roles.length; i++) {
      final role = roles[i];
      test('${entry.key} resolves safely for ${role.name}', () {
        final item = AppNotificationItem(
            id: 'notification',
            recipientId: 'recipient',
            notificationType: entry.key,
            title: 'Update',
            body: 'Notification details',
            routeType: entry.key,
            routeId: 'record',
            createdAt: DateTime(2026));
        final page = notificationDestination(item, role);
        expect(page is NotificationDetailsPage, !entry.value[i]);
        if (page is NotificationTarget) {
          expect(page.route, entry.key);
          expect(page.recordId, 'record');
        }
      });
    }
  }
}
