import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/app_notification_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/notification_destination.dart';
import 'package:carmelitas_dormitory_system/views/shared/conduct_case_pages.dart';
import 'package:carmelitas_dormitory_system/views/shared/staff_message_contacts.dart';
import 'package:carmelitas_dormitory_system/views/shared/staff_curfew_requests_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/views/owner/staff_maintenance_page.dart';
import 'package:carmelitas_dormitory_system/views/guardian/guardian_pages.dart';

AppNotificationItem item(String route,
        {String? id = 'record-id', Map<String, dynamic> data = const {}}) =>
    AppNotificationItem(
        id: 'notification-id',
        recipientId: 'recipient',
        notificationType: 'safety',
        title: 'Update',
        body: 'Full notification body',
        routeType: route,
        routeId: id,
        data: data,
        createdAt: DateTime(2026, 10, 6));

Widget child(Widget page) => page is NotificationTarget ? page.child : page;

void main() {
  test('all operational notifications have the same staff destination', () {
    for (final route in [
      'payment',
      'maintenance',
      'visitor',
      'conduct_case',
      'confidential_report',
      'curfew',
      'gate_event',
      'inspection',
      'announcement',
      'onboarding',
      'location_monitoring_incident',
      'guardian_presence_alert',
      'location_status_request'
    ]) {
      final owner = child(notificationDestination(item(route), UserRole.owner));
      final caretaker =
          child(notificationDestination(item(route), UserRole.caretaker));
      expect(owner, isNot(isA<NotificationDetailsPage>()), reason: route);
      expect(caretaker.runtimeType, owner.runtimeType, reason: route);
    }
  });

  test('staff opens the exact maintenance and conduct records', () {
    for (final role in [UserRole.owner, UserRole.caretaker]) {
      final maintenance =
          child(notificationDestination(item('maintenance'), role))
              as StaffMaintenanceDetailsPage;
      expect(maintenance.id, 'record-id');
      final conduct = child(notificationDestination(item('conduct_case'), role))
          as StaffConductCasesPage;
      expect(conduct.initialCaseId, 'record-id');
      expect(child(notificationDestination(item('curfew'), role)),
          isA<StaffCurfewRequestsPage>());
    }
    final tenant =
        child(notificationDestination(item('conduct_case'), UserRole.tenant))
            as TenantConductCasesPage;
    expect(tenant.initialCaseId, 'record-id');
  });

  test('confidential reports support both staff roles and select the report',
      () {
    final owner = child(notificationDestination(
            item('confidential_report'), UserRole.owner))
        as ConfidentialReportsPage;
    expect(owner.initialReportId, 'record-id');
    expect(
        child(notificationDestination(
            item('confidential_report'), UserRole.caretaker)),
        isA<ConfidentialReportsPage>());
    expect(
        notificationDestination(item('confidential_report'), UserRole.guardian),
        isA<NotificationDetailsPage>());
  });

  test('conversation IDs survive inbox and push routes for every role', () {
    for (final role in UserRole.values) {
      for (final route in ['conversation', 'message']) {
        final page = notificationDestination(item(route), role);
        if (role == UserRole.owner || role == UserRole.caretaker) {
          expect(
              (page as OwnerMessagingPage).initialConversationId, 'record-id');
        } else {
          expect((page as DirectStaffConversationPage).conversationId,
              'record-id');
        }
      }
    }
  });

  test('guardian opens requests and presence in the correct segments', () {
    final request =
        child(notificationDestination(item('curfew'), UserRole.guardian))
            as GuardianPresenceMonitoringPage;
    final presence =
        child(notificationDestination(item('gate_event'), UserRole.guardian))
            as GuardianPresenceMonitoringPage;
    expect(request.initialSegment, 0);
    expect(presence.initialSegment, 1);
  });

  test('payload normalization and legacy data preserve target IDs', () {
    final push = AppNotificationItem.fromPush({
      'notification_id': 'notice',
      'notification_type': 'safety',
      'route_type': ' CONDUCT_CASE ',
      'route_id': ' ',
      'case_id': 'case',
    }, recipientId: 'recipient');
    expect(push.destinationType, 'conduct_case');
    expect(push.destinationId, 'case');
    expect(
        item('maintenance', id: null, data: {'report_id': 'report'})
            .destinationId,
        'report');
    expect(item(' ', id: null).destinationType, 'safety');
    expect(item('payment', id: ' ').destinationId, isNull);
  });

  testWidgets(
      'record focus survives navigation and does not affect other modules',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: NotificationTarget(
      route: 'visitor',
      recordId: 'visitor-id',
      child: Builder(
          builder: (context) => Text(
              '${NotificationTarget.recordIdOf(context, 'visitor')}/${NotificationTarget.recordIdOf(context, 'payment')}')),
    )));
    expect(find.text('visitor-id/null'), findsOneWidget);
  });

  testWidgets('unknown routes open readable details instead of a dead tap',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: notificationDestination(item('future_module'), UserRole.owner)));
    expect(find.text('Full notification body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
