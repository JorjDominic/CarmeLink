import 'package:flutter/material.dart';

import '../../controllers/guardian_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../guardian/guardian_documents_page.dart';
import '../guardian/guardian_pages.dart';
import '../owner/contracts_page.dart';
import '../owner/owner_pages.dart';
import '../owner/room_monitoring_page.dart';
import '../owner/staff_maintenance_page.dart';
import '../tenant/tenant_pages.dart';
import '../tenant/tenant_requirements_page.dart';
import 'cleaning_report_detail.dart';
import 'cleaning_schedule_management_page.dart';
import 'conduct_case_pages.dart';
import 'employee_curfew_profile_pages.dart';
import 'move_out_settlement_page.dart';
import 'room_cleaning_pages.dart';
import 'room_inspection_pages.dart';
import 'staff_curfew_requests_page.dart';
import 'staff_message_contacts.dart';

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
      'onboarding' => const ContractsPage(),
      'guardian_link' => const TenantDirectoryPage(),
      'move_out' => const MoveOutSettlementPage(),
      'cleaning_schedule' => const CleaningScheduleManagementPage(),
      'employee_curfew' => const EmployeeCurfewProfilesPage(),
      'room_assignment' => const RoomMonitoringPage(),
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
      'location_settings' ||
      'employee_curfew' =>
        const TenantPresencePage(),
      'inspection' => const TenantRoomInspectionsPage(),
      'announcement' => const TenantAnnouncementsPage(),
      'onboarding' => const TenantRequirementsPage(),
      'move_out' => const MoveOutSettlementPage(),
      'cleaning_schedule' => const TenantCleaningSchedulePage(),
      'room_assignment' => const MyRoomPage(),
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
      'onboarding' => const GuardianDocumentsPage(),
      'room_assignment' || 'guardian_link' => const GuardianTenantInfoPage(),
      _ => null,
    };
  }

  if (page == null) return NotificationDetailsPage(notification: item);

  final targeted = NotificationTarget(route: route, recordId: id, child: page);
  final tenantId = item.data['tenant_id']?.toString().trim();
  if (role == UserRole.guardian &&
      tenantId != null &&
      tenantId.isNotEmpty &&
      {'payment', 'onboarding', 'room_assignment', 'guardian_link'}
          .contains(route)) {
    return _GuardianTenantNotificationTarget(
      tenantId: tenantId,
      child: targeted,
    );
  }
  return targeted;
}

class _GuardianTenantNotificationTarget extends StatefulWidget {
  const _GuardianTenantNotificationTarget({
    required this.tenantId,
    required this.child,
  });

  final String tenantId;
  final Widget child;

  @override
  State<_GuardianTenantNotificationTarget> createState() =>
      _GuardianTenantNotificationTargetState();
}

class _GuardianTenantNotificationTargetState
    extends State<_GuardianTenantNotificationTarget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _selectTenant());
  }

  Future<void> _selectTenant() async {
    final controller = GuardianController.instance;
    if (!controller.loadedOnce) {
      await controller.loadData(force: true);
    }
    final matches = controller.linkedTenants
        .where((tenant) => tenant.tenantId == widget.tenantId);
    if (matches.isNotEmpty) {
      await controller.selectTenant(matches.first);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
