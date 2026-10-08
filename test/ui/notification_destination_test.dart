import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/app_notification_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/notification_destination.dart';
import 'package:carmelitas_dormitory_system/views/shared/cleaning_report_detail.dart';
import 'package:carmelitas_dormitory_system/views/shared/conduct_case_pages.dart';
import 'package:carmelitas_dormitory_system/views/shared/staff_message_contacts.dart';
import 'package:carmelitas_dormitory_system/views/shared/staff_curfew_requests_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/views/owner/staff_maintenance_page.dart';
import 'package:carmelitas_dormitory_system/views/guardian/guardian_pages.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';

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
  test('legacy curfew taps retain request identity for all authorized roles',
      () {
    for (final alias in [
      'curfew_pass',
      'curfew_request',
      'late_return',
      'overnight_leave'
    ]) {
      final push = AppNotificationItem.fromPush({
        'notification_type': alias,
        'data': '{"request_id":"request-123"}',
      }, recipientId: 'recipient');
      expect(push.destinationType, 'curfew');
      expect(push.destinationId, 'request-123');
      for (final role in UserRole.values) {
        final target =
            notificationDestination(push, role) as NotificationTarget;
        expect(target.route, 'curfew');
        expect(target.recordId, 'request-123');
        if (role == UserRole.tenant)
          expect(target.child, isA<TenantPresencePage>());
        if (role == UserRole.guardian) {
          expect(
              (target.child as GuardianPresenceMonitoringPage).initialSegment,
              0);
        }
        if (role == UserRole.owner || role == UserRole.caretaker) {
          expect((target.child as StaffCurfewRequestsPage).initialRequestId,
              'request-123');
        }
      }
    }
  });

  test('inspection taps select the exact protected staff report', () {
    for (final role in [UserRole.owner, UserRole.caretaker]) {
      final page = child(notificationDestination(item('room_inspection'), role))
          as NotificationInspectionPage;
      expect(page.inspectionId, 'record-id');
    }
    expect(notificationDestination(item('inspection'), UserRole.guardian),
        isA<NotificationDetailsPage>());
  });

  test('malformed nested push data cannot break a tap', () {
    final push = AppNotificationItem.fromPush(
        {'notification_type': 'curfew_pass', 'data': '{broken'},
        recipientId: 'recipient');
    expect(push.destinationType, 'curfew');
    expect(push.destinationId, isNull);
  });

  testWidgets('unavailable inspection shows an actionable protected fallback',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: NotificationInspectionPage(inspectionId: 'deleted')));
    await tester.pumpAndSettle();
    expect(find.textContaining('unavailable or you do not have access'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('all operational notifications have the same staff destination', () {
    for (final route in [
      'payment',
      'maintenance',
      'visitor',
      'conduct_case',
      'confidential_report',
      'cleaning_report',
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

  test('cleaning reports open the exact report for staff and tenant', () {
    for (final role in [UserRole.owner, UserRole.caretaker, UserRole.tenant]) {
      final page =
          child(notificationDestination(item('cleaning_report'), role));
      expect(page, isA<CleaningReportDetail>());
      expect((page as CleaningReportDetail).reportId, 'record-id');
    }
    expect(
      notificationDestination(item('cleaning_report'), UserRole.guardian),
      isA<NotificationDetailsPage>(),
    );
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
    expect(
        item('cleaning_report', id: null, data: {'report_id': 'cleaning'})
            .destinationId,
        'cleaning');
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
