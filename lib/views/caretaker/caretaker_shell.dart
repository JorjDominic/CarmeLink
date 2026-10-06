import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../owner/owner_pages.dart';
import '../owner/room_monitoring_page.dart';
import '../shared/shared_views.dart';
import '../shared/conduct_case_pages.dart';
import '../shared/account_management_page.dart';

/// Operational workspace that excludes owner-only financial and analytics UI.
class CaretakerShell extends StatefulWidget {
  const CaretakerShell({super.key});

  @override
  State<CaretakerShell> createState() => _CaretakerShellState();
}

class _CaretakerShellState extends State<CaretakerShell>
    with WidgetsBindingObserver {
  TableRefreshSubscription? _liveDataSubscription;
  bool _refreshInFlight = false;
  bool _refreshAgain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OwnerController.instance.loadRooms();
    OwnerController.instance.loadPayments();
    OwnerController.instance.loadCurfewRequests();
    OwnerController.instance.loadStaffMaintenance();
    OwnerController.instance.loadTenants();
    OwnerController.instance.loadGateEvents();
    OwnerController.instance.loadVisitors();
    _liveDataSubscription = TableRefreshSubscription(
      'caretaker-shell-live-data',
      const [
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
      ],
      () => unawaited(_refreshLiveData()),
    );
  }

  Future<void> _refreshLiveData() async {
    if (_refreshInFlight) {
      _refreshAgain = true;
      return;
    }

    do {
      _refreshAgain = false;
      _refreshInFlight = true;
      try {
        final controller = OwnerController.instance;
        await controller.loadRooms(force: true);
        await controller.loadPayments(force: true);
        await controller.loadCurfewRequests(force: true);
        await controller.loadStaffMaintenance(force: true);
        await controller.loadTenants(force: true);
        await controller.loadGateEvents(force: true);
        await controller.loadVisitors(force: true);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_liveDataSubscription?.dispose());
    super.dispose();
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
      'conduct_case' => const StaffConductCasesPage(),
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
