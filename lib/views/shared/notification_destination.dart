import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../guardian/guardian_pages.dart';
import '../owner/owner_pages.dart';
import '../owner/room_monitoring_page.dart';
import '../owner/staff_maintenance_page.dart';
import '../tenant/tenant_pages.dart';
import 'cleaning_report_detail.dart';
import 'conduct_case_pages.dart';
import 'room_inspection_pages.dart';
import 'staff_message_contacts.dart';
import 'staff_curfew_requests_page.dart';

/// Shared by the inbox, foreground alerts, and mobile push taps.
Widget notificationDestination(AppNotificationItem item, UserRole role) {
  final route = item.destinationType;
  final id = item.destinationId;
  final staff = role == UserRole.owner || role == UserRole.caretaker;
  if (route == 'message' || route == 'conversation') {
    if (staff) return OwnerMessagingPage(initialConversationId: id);
    if (id != null) return DirectStaffConversationPage(conversationId: id);
    return role == UserRole.tenant
        ? const TenantMessagesPage()
        : const GuardianMessagesPage();
  }
  if (route == 'cleaning_report' && id != null) {
    if (staff || role == UserRole.tenant) {
      return CleaningReportDetail(reportId: id);
    }
  }

  final Widget? page;
  if (staff) {
    page = switch (route) {
      'payment' => const PaymentVerificationPage(),
      'maintenance' => id == null
          ? const MaintenanceManagementPage()
          : StaffMaintenanceDetailsPage(id: id),
      'visitor' => const VisitorManagementPage(),
      'confidential_report' => ConfidentialReportsPage(initialReportId: id),
      'conduct_case' => StaffConductCasesPage(initialCaseId: id),
      'curfew' => const StaffCurfewRequestsPage(),
      'gate' ||
      'gate_event' ||
      'safety' ||
      'location_monitoring_incident' ||
      'guardian_presence_alert' ||
      'location_status_request' =>
        const GeofenceMonitoringPage(),
      'inspection' => const RoomMonitoringPage(),
      'announcement' => const AnnouncementsManagementPage(),
      'onboarding' => const TenantDirectoryPage(),
      _ => null,
    };
  } else if (role == UserRole.tenant) {
    page = switch (route) {
      'payment' => const TenantBillingDetailsPage(),
      'maintenance' => const MaintenanceReportsPage(),
      'visitor' => const VisitorRequestPage(),
      'confidential_report' => const ConfidentialConcernPage(),
      'conduct_case' => TenantConductCasesPage(initialCaseId: id),
      'curfew' ||
      'gate' ||
      'gate_event' ||
      'safety' ||
      'location_monitoring_incident' ||
      'location_status_request' ||
      'location_settings' =>
        const TenantPresencePage(),
      'inspection' => const TenantRoomInspectionsPage(),
      'announcement' => const TenantAnnouncementsPage(),
      _ => null,
    };
  } else {
    page = switch (route) {
      'payment' => const GuardianPaymentStatusPage(),
      'curfew' => const GuardianPresenceMonitoringPage(initialSegment: 0),
      'gate' ||
      'gate_event' ||
      'safety' ||
      'guardian_presence_alert' ||
      'location_monitoring_incident' ||
      'location_status_request' =>
        const GuardianPresenceMonitoringPage(initialSegment: 1),
      'announcement' => const GuardianAnnouncementsPage(),
      _ => null,
    };
  }
  return page == null
      ? NotificationDetailsPage(notification: item)
      : NotificationTarget(route: route, recordId: id, child: page);
}

/// Keeps a notification's record selected even when it is already archived.
class NotificationTarget extends InheritedWidget {
  const NotificationTarget({
    required this.route,
    required this.recordId,
    required super.child,
    super.key,
  });
  final String route;
  final String? recordId;

  static String? recordIdOf(BuildContext context, String route) {
    final target =
        context.dependOnInheritedWidgetOfExactType<NotificationTarget>();
    return target?.route == route ? target?.recordId : null;
  }

  @override
  bool updateShouldNotify(NotificationTarget oldWidget) =>
      route != oldWidget.route || recordId != oldWidget.recordId;
}

/// Unknown or informational notifications still open their full readable text.
class NotificationDetailsPage extends StatelessWidget {
  const NotificationDetailsPage({required this.notification, super.key});
  final AppNotificationItem notification;

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Notification',
        subtitle: notification.title,
        child: SelectableText(notification.body),
      );
}
