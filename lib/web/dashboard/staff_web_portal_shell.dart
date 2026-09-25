import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../views/owner/contracts_page.dart';
import '../../views/owner/guardian_link_management_page.dart';
import '../../views/owner/owner_pages.dart';
import '../../views/owner/room_monitoring_page.dart';
import '../../views/shared/account_management_page.dart';
import '../../views/shared/shared_views.dart';
import '../../views/shared/conduct_case_pages.dart';
import '../../views/shared/employee_curfew_profile_pages.dart';
import '../../views/shared/retention_settings_page.dart';
import 'staff_overview_page.dart';

/// A browser-only destination composition. Every management destination is
/// the EXISTING live module: no demo store or duplicate business service.
/// The separate mobile OwnerShell and CaretakerShell are not modified.
abstract final class StaffWebDestinations {
  static List<AppDestination> primary(UserRole role) {
    final owner = role == UserRole.owner;
    assert(owner || role == UserRole.caretaker);
    return [
      AppDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        page: StaffOverviewPage(role: role),
      ),
      const AppDestination(
        label: 'Tenants',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        page: TenantDirectoryPage(),
      ),
      const AppDestination(
        label: 'Operations',
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        page: OperationsHubPage(),
      ),
      if (owner)
        const AppDestination(
          label: 'Curfew',
          icon: Icons.schedule_outlined,
          selectedIcon: Icons.schedule,
          page: GeofenceMonitoringPage(),
          isWorkInProgress: true,
        ),
      const AppDestination(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: ProfilePage(),
      ),
    ];
  }

  static List<AppDestination> desktopTools(UserRole role) => [
        const AppDestination(
          label: 'Rooms',
          icon: Icons.meeting_room_outlined,
          selectedIcon: Icons.meeting_room,
          page: RoomMonitoringPage(),
        ),
        const AppDestination(
          label: 'Accounts',
          icon: Icons.manage_accounts_outlined,
          selectedIcon: Icons.manage_accounts,
          page: AccountManagementPage(),
        ),
        const AppDestination(
          label: 'Cleaning',
          icon: Icons.cleaning_services_outlined,
          selectedIcon: Icons.cleaning_services,
          page: RoomMonitoringPage(),
        ),
        const AppDestination(
          label: 'Inspections',
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check,
          page: RoomMonitoringPage(),
        ),
        const AppDestination(
          label: 'Visitors',
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          page: VisitorManagementPage(),
        ),
        const AppDestination(
          label: 'Conduct & cases',
          icon: Icons.gavel_outlined,
          selectedIcon: Icons.gavel,
          page: StaffConductCasesPage(),
        ),
        const AppDestination(
          label: 'Employee curfew',
          icon: Icons.badge_outlined,
          selectedIcon: Icons.badge,
          page: EmployeeCurfewProfilesPage(),
        ),
        const AppDestination(
          label: 'Security & retention',
          icon: Icons.security_outlined,
          selectedIcon: Icons.security,
          page: RetentionSettingsPage(),
        ),
        if (role == UserRole.owner) ...[
          const AppDestination(
            label: 'Guardian links',
            icon: Icons.family_restroom_outlined,
            selectedIcon: Icons.family_restroom,
            page: GuardianLinkManagementPage(),
          ),
          const AppDestination(
            label: 'Contracts',
            icon: Icons.description_outlined,
            selectedIcon: Icons.description,
            page: ContractsPage(),
          ),
        ],
      ];
}

/// RoleGuard remains in front of every route; Supabase RLS remains authoritative.
class StaffWebPortalShell extends StatefulWidget {
  const StaffWebPortalShell({super.key, required this.role});

  final UserRole role;

  @override
  State<StaffWebPortalShell> createState() => _StaffWebPortalShellState();
}

class _StaffWebPortalShellState extends State<StaffWebPortalShell> {
  @override
  void initState() {
    super.initState();
    final data = OwnerController.instance;
    data.loadRooms();
    data.loadPayments();
    data.loadCurfewRequests();
    data.loadStaffMaintenance();
    data.loadTenants();
    data.loadGateEvents();
    if (widget.role == UserRole.owner) data.loadContracts();
  }

  @override
  void didUpdateWidget(covariant StaffWebPortalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != UserRole.owner && widget.role == UserRole.owner) {
      OwnerController.instance.loadContracts();
    }
  }

  @override
  Widget build(BuildContext context) => RoleGuard(
        allowedRoles: {widget.role},
        child: AdaptiveRoleShell(
          roleLabel: widget.role == UserRole.owner ? 'Owner' : 'Caretaker',
          messagePage: const OwnerMessagingPage(),
          destinations: StaffWebDestinations.primary(widget.role),
          webDestinations: StaffWebDestinations.desktopTools(widget.role),
        ),
      );
}
