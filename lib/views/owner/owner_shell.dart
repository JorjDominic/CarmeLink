import 'package:flutter/material.dart';
import '../../controllers/owner_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../shared/shared_views.dart';
import '../shared/account_management_page.dart';
import 'guardian_link_management_page.dart';
import 'contracts_page.dart';
import 'owner_pages.dart';

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  @override
  void initState() {
    super.initState();
    OwnerController.instance.loadRooms();
    OwnerController.instance.loadPayments();
    OwnerController.instance.loadCurfewRequests();
    OwnerController.instance.loadStaffMaintenance();
    OwnerController.instance.loadContracts();
    OwnerController.instance.loadTenants();
    OwnerController.instance.loadGateEvents();
  }

  @override
  Widget build(BuildContext context) => const RoleGuard(
        allowedRoles: {UserRole.owner},
        child: AdaptiveRoleShell(
          roleLabel: 'Owner',
          messagePage: OwnerMessagingPage(),
          webDestinations: [
            AppDestination(
                label: 'Accounts',
                icon: Icons.manage_accounts_outlined,
                selectedIcon: Icons.manage_accounts,
                page: AccountManagementPage()),
            AppDestination(
                label: 'Guardian links',
                icon: Icons.family_restroom_outlined,
                selectedIcon: Icons.family_restroom,
                page: GuardianLinkManagementPage()),
            AppDestination(
                label: 'Contracts',
                icon: Icons.description_outlined,
                selectedIcon: Icons.description,
                page: ContractsPage()),
          ],
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
                label: 'Curfew',
                icon: Icons.schedule_outlined,
                selectedIcon: Icons.schedule,
                page: GeofenceMonitoringPage(),
                isWorkInProgress: true),
            AppDestination(
                label: 'Profile',
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                page: ProfilePage()),
          ],
        ),
      );
}
