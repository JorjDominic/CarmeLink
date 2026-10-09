import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../../services/room_inspection_service.dart';
import '../../core/config/supabase_config.dart';
import '../guardian/guardian_pages.dart';
import '../guardian/guardian_documents_page.dart';
import '../owner/owner_pages.dart';
import '../owner/room_monitoring_page.dart';
import '../owner/staff_maintenance_page.dart';
import '../tenant/tenant_pages.dart';
import '../tenant/tenant_requirements_page.dart';
import 'conduct_case_pages.dart';
import 'cleaning_report_detail.dart';
import 'room_inspection_pages.dart';
import 'staff_message_contacts.dart';
import 'staff_curfew_requests_page.dart';
import 'employee_curfew_profile_pages.dart';
import 'cleaning_schedule_management_page.dart';
import 'move_out_settlement_page.dart';
import 'room_transfer_page.dart';
import 'eviction_page.dart';
import 'shared_views.dart';
import '../owner/guardian_link_management_page.dart';

/// Shared by the inbox, foreground alerts, and mobile push taps.
Widget notificationDestination(AppNotificationItem item, UserRole role) {
  final route = item.destinationType;
  final id = item.destinationId;
  final staff = role == UserRole.owner || role == UserRole.caretaker;
  if (route == 'room_transfer') return const RoomTransferPage();
  if (route == 'eviction') return const EvictionPage();
  if (route == 'message' || route == 'conversation') {
    if (staff) return OwnerMessagingPage(initialConversationId: id);
    if (id != null) return DirectStaffConversationPage(conversationId: id);
    return role == UserRole.tenant
        ? const TenantMessagesPage()
        : const GuardianMessagesPage();
  }
  if (route == 'cleaning_report' &&
      id != null &&
      (staff || role == UserRole.tenant))
    return CleaningReportDetail(reportId: id);
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
      'curfew' => StaffCurfewRequestsPage(initialRequestId: id),
      'gate' ||
      'gate_event' ||
      'safety' ||
      'location_monitoring_incident' ||
      'guardian_presence_alert' ||
      'location_status_request' =>
        const GeofenceMonitoringPage(),
      'inspection' => id == null
          ? const RoomMonitoringPage()
          : NotificationInspectionPage(inspectionId: id),
      'employee_curfew' => const EmployeeCurfewProfilesPage(),
      'cleaning_schedule' => const CleaningScheduleManagementPage(),
      'room_assignment' => const RoomMonitoringPage(),
      'move_out' => const MoveOutSettlementPage(),
      'guardian_link' => role == UserRole.owner
          ? const GuardianLinkManagementPage()
          : const TenantDirectoryPage(),
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
      'employee_curfew' => const TenantPresencePage(),
      'cleaning_schedule' => const MyRoomPage(),
      'room_assignment' => const MyRoomPage(),
      'guardian_link' => const ProfilePage(),
      'move_out' => const MoveOutSettlementPage(),
      'onboarding' => const TenantRequirementsPage(),
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
      'guardian_link' || 'room_assignment' => const GuardianTenantInfoPage(),
      'onboarding' => const GuardianDocumentsPage(),
      _ => null,
    };
  }
  return page == null
      ? NotificationDetailsPage(notification: item)
      : NotificationTarget(route: route, recordId: id, child: page);
}

/// Fetches through the caller's RLS-protected session, never an admin client.
class NotificationInspectionPage extends StatefulWidget {
  const NotificationInspectionPage({required this.inspectionId, super.key});
  final String inspectionId;

  @override
  State<NotificationInspectionPage> createState() =>
      _NotificationInspectionPageState();
}

class _NotificationInspectionPageState
    extends State<NotificationInspectionPage> {
  late final _inspection = _load();

  Future<(RoomInspectionRecord, String)?> _load() async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) throw StateError('Please sign in again.');
    final row = await client
        .from('room_inspections')
        .select('*, room:rooms(room_number)')
        .eq('id', widget.inspectionId)
        .maybeSingle();
    if (row == null) return null;
    return (
      RoomInspectionRecord.fromRow(row),
      (row['room'] as Map?)?['room_number']?.toString() ?? 'Unavailable'
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<(RoomInspectionRecord, String)?>(
        future: _inspection,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PageFrame(
                title: 'Inspection',
                child: Center(child: CircularProgressIndicator()));
          }
          final record = snapshot.data;
          if (snapshot.hasError || record == null) {
            return const PageFrame(
                title: 'Inspection unavailable',
                child: Text(
                    'This inspection is unavailable or you do not have access. Please return to Notifications and retry.'));
          }
          return StaffInspectionDetailPage(
              inspection: record.$1, roomNumber: record.$2);
        },
      );
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
