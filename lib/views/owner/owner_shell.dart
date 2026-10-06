import '../shared/notification_destination.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../controllers/owner_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../shared/shared_views.dart';
import '../shared/account_management_page.dart';
import 'guardian_link_management_page.dart';
import 'contracts_page.dart';
import 'owner_pages.dart';
import 'room_monitoring_page.dart';

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> with WidgetsBindingObserver {
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
    OwnerController.instance.loadContracts();
    OwnerController.instance.loadTenants();
    OwnerController.instance.loadGateEvents();
    OwnerController.instance.loadVisitors();
    OwnerController.instance.loadConcerns();
    _liveDataSubscription = TableRefreshSubscription(
      'owner-shell-live-data',
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
        'confidential_reports',
        'tenant_contracts',
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
        await controller.loadContracts(force: true);
        await controller.loadTenants(force: true);
        await controller.loadGateEvents(force: true);
        await controller.loadVisitors(force: true);
        await controller.loadConcerns(force: true);
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

  Widget _notificationDestination(AppNotificationItem notification) =>
      notificationDestination(notification, UserRole.owner);

  @override
  Widget build(BuildContext context) => RoleGuard(
        allowedRoles: {UserRole.owner},
        child: AdaptiveRoleShell(
          roleLabel: 'Owner',
          notificationPageBuilder: _notificationDestination,
          messagePage: OwnerMessagingPage(),
          webDestinations: [
            AppDestination(
                label: 'Rooms',
                icon: Icons.meeting_room_outlined,
                selectedIcon: Icons.meeting_room,
                page: RoomMonitoringPage()),
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
