import 'package:flutter/material.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../shared/shared_views.dart';
import 'owner_pages.dart';

class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key});
  @override
  Widget build(BuildContext context) => const RoleGuard(
        allowedRoles: {UserRole.owner},
        child: AdaptiveRoleShell(
          roleLabel: 'Owner',
          messagePage: OwnerMessagingPage(),
          destinations: [
            AppDestination(
                label: 'Dashboard',
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
                page: OwnerDashboardPage()),
            AppDestination(
                label: 'Tenants',
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups,
                page: TenantDirectoryPage()),
            AppDestination(
                label: 'Operations',
                icon: Icons.tune_outlined,
                selectedIcon: Icons.tune,
                page: OperationsHubPage()),
            AppDestination(
                label: 'Gate',
                icon: Icons.sensor_door_outlined,
                selectedIcon: Icons.sensor_door,
                page: GateMonitoringPage()),
            AppDestination(
                label: 'Profile',
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                page: ProfilePage()),
          ],
        ),
      );
}
