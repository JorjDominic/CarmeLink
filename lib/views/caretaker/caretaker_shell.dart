import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
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

  @override
  Widget build(BuildContext context) => const RoleGuard(
        allowedRoles: {UserRole.caretaker},
        child: AdaptiveRoleShell(
          roleLabel: 'Caretaker',
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
