import 'package:flutter/material.dart';

import '../../controllers/tenant_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../shared/shared_views.dart';
import 'tenant_pages.dart';

class TenantShell extends StatefulWidget {
  const TenantShell({super.key});

  @override
  State<TenantShell> createState() => _TenantShellState();
}

class _TenantShellState extends State<TenantShell> {
  @override
  void initState() {
    super.initState();

    TenantController.instance.loadMaintenance();
  }

  @override
  Widget build(BuildContext context) => const RoleGuard(
        allowedRoles: {
          UserRole.tenant,
        },
        child: AdaptiveRoleShell(
          roleLabel: 'Tenant',
          messagePage: TenantMessagesPage(),
          destinations: [
            AppDestination(
              label: 'Home',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              page: TenantDashboardPage(),
            ),
            AppDestination(
              label: 'Payments',
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet,
              page: PaymentsPage(),
            ),
            AppDestination(
              label: 'Reports',
              icon: Icons.assignment_outlined,
              selectedIcon: Icons.assignment,
              page: TenantReportsHubPage(),
            ),
            AppDestination(
              label: 'Gate',
              icon: Icons.sensor_door_outlined,
              selectedIcon: Icons.sensor_door,
              page: GateCurfewPage(),
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
