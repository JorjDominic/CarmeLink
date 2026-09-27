import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/tenant_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../shared/shared_views.dart';
import 'tenant_pages.dart';

class TenantShell extends StatefulWidget {
  const TenantShell({super.key});

  @override
  State<TenantShell> createState() => _TenantShellState();
}

class _TenantShellState extends State<TenantShell> {
  TableRefreshSubscription? _liveDataSubscription;
  bool _refreshInFlight = false;
  bool _refreshAgain = false;

  @override
  void initState() {
    super.initState();

    TenantController.instance.loadMaintenance();
    TenantController.instance.loadMyRoom();
    TenantController.instance.loadCurfewRequests();
    TenantController.instance.loadPayments();
    TenantController.instance.loadGateEvents();
    TenantController.instance.loadVisitors();
    TenantController.instance.loadConcerns();
    _liveDataSubscription = TableRefreshSubscription(
      'tenant-shell-live-data',
      const [
        'maintenance_reports',
        'tenant_assignments',
        'bed_spaces',
        'rooms',
        'payments',
        'curfew_requests',
        'gate_events',
        'visitor_requests',
        'visitor_events',
        'confidential_reports',
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
        final controller = TenantController.instance;
        await controller.loadMaintenance(force: true);
        await controller.loadMyRoom(force: true);
        await controller.loadCurfewRequests(force: true);
        await controller.loadPayments(force: true);
        await controller.loadGateEvents(force: true);
        await controller.loadVisitors(force: true);
        await controller.loadConcerns(force: true);
      } finally {
        _refreshInFlight = false;
      }
    } while (_refreshAgain && mounted);
  }

  @override
  void dispose() {
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
      'message' || 'conversation' => const TenantConversationPage(),
      'payment' => const PaymentsPage(),
      'maintenance' => const MaintenanceReportsPage(),
      'visitor' => const VisitorRequestPage(),
      'curfew' ||
      'gate' ||
      'gate_event' ||
      'safety' =>
        const TenantPresencePage(),
      'announcement' => const TenantAnnouncementsPage(),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) => RoleGuard(
        allowedRoles: {
          UserRole.tenant,
        },
        child: AdaptiveRoleShell(
          roleLabel: 'Tenant',
          notificationPageBuilder: _notificationDestination,
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
              label: 'Curfew',
              icon: Icons.schedule_outlined,
              selectedIcon: Icons.schedule,
              page: TenantPresencePage(),
              isWorkInProgress: true,
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
