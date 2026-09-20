import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../owner/owner_pages.dart';
import '../shared/shared_views.dart';

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
  }

  @override
  Widget build(BuildContext context) => const RoleGuard(
        allowedRoles: {UserRole.caretaker},
        child: AdaptiveRoleShell(
          roleLabel: 'Caretaker',
          messagePage: OwnerMessagingPage(),
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
