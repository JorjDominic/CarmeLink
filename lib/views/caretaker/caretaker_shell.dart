import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../owner/owner_pages.dart';
import '../owner/room_monitoring_page.dart';
import '../shared/shared_views.dart';
import '../shared/account_management_page.dart';

/// Operational workspace that excludes owner-only financial and analytics UI.
class CaretakerShell extends StatefulWidget {
  const CaretakerShell({super.key});

  @override
  State<CaretakerShell> createState() => _CaretakerShellState();
}

class _CaretakerShellState extends State<CaretakerShell> {
  @override
  void initState() {
    super.initState();
    OwnerController.instance.loadRooms();
    OwnerController.instance.loadPayments();
    OwnerController.instance.loadCurfewRequests();
    OwnerController.instance.loadStaffMaintenance();
    OwnerController.instance.loadTenants();
    OwnerController.instance.loadGateEvents();
  }


  Widget? _notificationDestination(AppNotificationItem notification) {
    final routeType = notification.routeType?.trim();
    final route = (routeType == null || routeType.isEmpty
            ? notification.notificationType.trim()
            : routeType)
        .toLowerCase();
    return switch (route) {
      'message' || 'conversation' => OwnerMessagingPage(
          initialConversationId: notification.routeId,
        ),
      'payment' => const PaymentVerificationPage(),
      'maintenance' => const MaintenanceManagementPage(),
      'visitor' => const VisitorManagementPage(),
      'curfew' || 'gate' || 'gate_event' => const GeofenceMonitoringPage(),
      'announcement' => const AnnouncementsManagementPage(),
      'inspection' => const RoomMonitoringPage(),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) => RoleGuard(
        allowedRoles: {UserRole.caretaker},
        child: AdaptiveRoleShell(
          roleLabel: 'Caretaker',
          notificationPageBuilder: _notificationDestination,
          messagePage: OwnerMessagingPage(),
          webDestinations: [
            AppDestination(
              label: 'Rooms',
              icon: Icons.meeting_room_outlined,
              selectedIcon: Icons.meeting_room,
              page: RoomMonitoringPage(),
            ),
            AppDestination(
              label: 'Accounts',
              icon: Icons.manage_accounts_outlined,
              selectedIcon: Icons.manage_accounts,
              page: AccountManagementPage(),
            ),
          ],
          destinations: [
            AppDestination(
              label: 'Dashboard',
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              page: OwnerDashboardPage(isCaretaker: true),
            ),
            AppDestination(
              label: 'Tenants',
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              page: TenantDirectoryPage(),
            ),
            AppDestination(
              label: 'Operations',
              icon: Icons.tune_outlined,
              selectedIcon: Icons.tune,
              page: OperationsHubPage(),
            ),
            AppDestination(
              label: 'Profile',
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              page: ProfilePage(),
            ),
          ],
        ),
      );
}
