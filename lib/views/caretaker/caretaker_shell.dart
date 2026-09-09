import 'package:flutter/material.dart';

import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../owner/owner_pages.dart';
import '../shared/shared_views.dart';
import '../shared/account_management_page.dart';

/// Operational workspace that excludes owner-only financial and analytics UI.
class CaretakerShell extends StatelessWidget {
  const CaretakerShell({super.key});

  @override
  Widget build(BuildContext context) => const RoleGuard(
        allowedRoles: {UserRole.caretaker},
        child: AdaptiveRoleShell(
          roleLabel: 'Caretaker',
          messagePage: OwnerMessagingPage(),
          destinations: [
            AppDestination(
              label: 'Tenants',
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              page: TenantDirectoryPage(),
            ),
            AppDestination(
              label: 'Rooms',
              icon: Icons.bed_outlined,
              selectedIcon: Icons.bed,
              page: RoomMonitoringPage(),
            ),
            AppDestination(
              label: 'Maintenance',
              icon: Icons.build_outlined,
              selectedIcon: Icons.build,
              page: MaintenanceManagementPage(),
            ),
            AppDestination(
              label: 'Gate',
              icon: Icons.sensor_door_outlined,
              selectedIcon: Icons.sensor_door,
              page: GateMonitoringPage(),
            ),
            AppDestination(
              label: 'Accounts',
              icon: Icons.manage_accounts_outlined,
              selectedIcon: Icons.manage_accounts,
              page: AccountManagementPage(),
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
