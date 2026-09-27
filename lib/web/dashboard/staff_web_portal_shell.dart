import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../views/owner/owner_pages.dart';
import '../../views/shared/shared_views.dart';
import 'staff_overview_page.dart';

/// A browser-only destination composition. Every management destination is
/// the EXISTING live module: no demo store or duplicate business service.
/// The separate mobile OwnerShell and CaretakerShell are not modified.
abstract final class StaffWebDestinations {
  static List<AppDestination> primary(UserRole role) {
    assert(role == UserRole.owner || role == UserRole.caretaker);
    return [
      AppDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        page: StaffOverviewPage(role: role),
      ),
      const AppDestination(
        label: 'Residents',
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
      const AppDestination(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: ProfilePage(),
      ),
    ];
  }

  /// Detailed staff modules now live inside the six Operations groups instead
  /// of competing for permanent sidebar space.
  static List<AppDestination> desktopTools(UserRole role) => const [];
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
