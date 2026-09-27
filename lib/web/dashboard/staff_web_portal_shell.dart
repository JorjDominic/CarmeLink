import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../../views/owner/owner_pages.dart';
import '../../views/owner/room_monitoring_page.dart';
import '../../views/shared/conduct_case_pages.dart';
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

class _StaffWebPortalShellState extends State<StaffWebPortalShell>
    with WidgetsBindingObserver {
  TableRefreshSubscription? _liveRefreshSubscription;
  Timer? _catchUpTimer;
  bool _refreshInFlight = false;
  bool _refreshAgain = false;

  static const _liveStaffTables = <String>[
    'profiles',
    'tenant_details',
    'guardian_tenant_links',
    'tenant_assignments',
    'bed_spaces',
    'rooms',
    'payments',
    'maintenance_reports',
    'maintenance_staff_history',
    'visitor_requests',
    'visitor_events',
    'curfew_requests',
    'gate_events',
    'confidential_reports',
    'tenant_contracts',
    'announcements',
    'cleaning_schedules',
    'cleaning_noncompliance_reports',
    'room_inspections',
    'room_inspection_findings',
    'conduct_cases',
    'conduct_case_events',
    'conduct_case_appeals',
    'employee_curfew_profiles',
    'retention_policy_settings',
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
    _liveRefreshSubscription = TableRefreshSubscription(
      'staff-web-live-sync',
      _liveStaffTables,
      () => unawaited(_refreshLiveData()),
      debounceDuration: const Duration(milliseconds: 700),
      catchUpInterval: null,
    );
    _catchUpTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_refreshLiveData()),
    );
  }

  void _loadInitialData() {
    final data = OwnerController.instance;
    data.loadRooms();
    data.loadPayments();
    data.loadCurfewRequests();
    data.loadStaffMaintenance();
    data.loadTenants();
    data.loadGateEvents();
    data.loadVisitors();
    if (widget.role == UserRole.owner) {
      data.loadConcerns();
      data.loadContracts();
    }
  }

  Future<void> _refreshLiveData() async {
    if (_refreshInFlight) {
      _refreshAgain = true;
      return;
    }

    do {
      _refreshAgain = false;
      _refreshInFlight = true;
      final data = OwnerController.instance;
      try {
        await data.loadRooms(force: true);
        await data.loadPayments(force: true);
        await data.loadCurfewRequests(force: true);
        await data.loadStaffMaintenance(force: true);
        await data.loadTenants(force: true);
        await data.loadGateEvents(force: true);
        await data.loadVisitors(force: true);
        if (widget.role == UserRole.owner) {
          await data.loadConcerns(force: true);
          await data.loadContracts(force: true);
        }
      } finally {
        _refreshInFlight = false;
      }
    } while (_refreshAgain && mounted);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLiveData());
    }
  }

  Widget? _notificationDestination(AppNotificationItem notification) {
    final routeType = notification.routeType?.trim().toLowerCase();
    final route = routeType == null || routeType.isEmpty
        ? notification.notificationType.trim().toLowerCase()
        : routeType;
    return switch (route) {
      'payment' => const PaymentVerificationPage(),
      'maintenance' => const MaintenanceManagementPage(),
      'visitor' => const VisitorManagementPage(),
      'curfew' || 'gate' || 'gate_event' => const GeofenceMonitoringPage(),
      'conduct_case' => const StaffConductCasesPage(),
      'inspection' => const RoomMonitoringPage(),
      'announcement' => const AnnouncementsManagementPage(),
      'message' || 'conversation' => OwnerMessagingPage(
          initialConversationId: notification.routeId,
        ),
      'onboarding' => const TenantDirectoryPage(),
      _ => null,
    };
  }

  @override
  void didUpdateWidget(covariant StaffWebPortalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      unawaited(_refreshLiveData());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _catchUpTimer?.cancel();
    unawaited(_liveRefreshSubscription?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RoleGuard(
        allowedRoles: {widget.role},
        child: AdaptiveRoleShell(
          roleLabel: widget.role == UserRole.owner ? 'Owner' : 'Caretaker',
          messagePage: const OwnerMessagingPage(),
          destinations: StaffWebDestinations.primary(widget.role),
          webDestinations: StaffWebDestinations.desktopTools(widget.role),
          notificationPageBuilder: _notificationDestination,
        ),
      );
}
