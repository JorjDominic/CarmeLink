import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../../views/owner/contracts_page.dart';
import '../../views/owner/guardian_link_management_page.dart';
import '../../views/owner/owner_pages.dart';
import '../../views/owner/room_monitoring_page.dart';
import '../../views/shared/account_management_page.dart';
import '../../views/shared/conduct_case_pages.dart';
import '../../views/shared/employee_curfew_profile_pages.dart';
import '../../views/shared/retention_settings_page.dart';
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

  /// Desktop keeps every important module one click away while retaining the
  /// simpler mobile navigation. Groups are presentation metadata only; the
  /// underlying pages, services, role guards and RLS remain unchanged.
  static List<AppDestination> desktopTools(UserRole role) {
    assert(role == UserRole.owner || role == UserRole.caretaker);
    final owner = role == UserRole.owner;
    return [
      const AppDestination(
        label: 'Rooms',
        icon: Icons.meeting_room_outlined,
        selectedIcon: Icons.meeting_room,
        page: RoomMonitoringPage(),
        webGroup: 'Facilities',
        webDescription: 'Occupancy and floor plan',
      ),
      const AppDestination(
        label: 'Maintenance',
        icon: Icons.build_outlined,
        selectedIcon: Icons.build,
        page: MaintenanceManagementPage(),
        webGroup: 'Facilities',
        webDescription: 'Repair requests and progress',
      ),
      const AppDestination(
        label: 'Cleaning schedules',
        icon: Icons.cleaning_services_outlined,
        selectedIcon: Icons.cleaning_services,
        page: RoomMonitoringPage(),
        webGroup: 'Facilities',
        webDescription: 'Room and bed cleaning duties',
      ),
      const AppDestination(
        label: 'Room inspections',
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        page: RoomMonitoringPage(),
        webGroup: 'Facilities',
        webDescription: 'Inspection notices and findings',
      ),
      const AppDestination(
        label: 'Visitors',
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        page: VisitorManagementPage(),
        webGroup: 'Access & Safety',
        webDescription: 'Visitor requests and status',
      ),
      const AppDestination(
        label: 'Presence & Curfew',
        icon: Icons.location_on_outlined,
        selectedIcon: Icons.location_on,
        page: GeofenceMonitoringPage(),
        webGroup: 'Access & Safety',
        webDescription: 'Presence, boundary and curfew records',
      ),
      const AppDestination(
        label: 'Employee curfew',
        icon: Icons.badge_outlined,
        selectedIcon: Icons.badge,
        page: EmployeeCurfewProfilesPage(),
        webGroup: 'Access & Safety',
        webDescription: 'Employment-based curfew profiles',
      ),
      const AppDestination(
        label: 'Conduct & Cases',
        icon: Icons.gavel_outlined,
        selectedIcon: Icons.gavel,
        page: StaffConductCasesPage(),
        webGroup: 'Access & Safety',
        webDescription: 'Incidents, responses and appeals',
      ),
      const AppDestination(
        label: 'Payment verification',
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments,
        page: PaymentVerificationPage(),
        webGroup: 'Billing & Records',
        webDescription: 'Review submitted payment proof',
      ),
      const AppDestination(
        label: 'Report management',
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        page: ReportManagementPage(),
        webGroup: 'Billing & Records',
        webDescription: 'Operational and maintenance reports',
      ),
      if (owner) ...[
        const AppDestination(
          label: 'Income & expenses',
          icon: Icons.insights_outlined,
          selectedIcon: Icons.insights,
          page: ExpenseIncomeSummaryPage(),
          webGroup: 'Billing & Records',
          webDescription: 'Property financial summary',
        ),
        const AppDestination(
          label: 'Contracts',
          icon: Icons.description_outlined,
          selectedIcon: Icons.description,
          page: ContractsPage(),
          webGroup: 'Billing & Records',
          webDescription: 'Contracts and renewals',
        ),
        const AppDestination(
          label: 'Confidential reports',
          icon: Icons.shield_outlined,
          selectedIcon: Icons.shield,
          page: ConfidentialReportsPage(),
          webGroup: 'Billing & Records',
          webDescription: 'Private resident concerns',
        ),
        const AppDestination(
          label: 'Disciplinary records',
          icon: Icons.rule_outlined,
          selectedIcon: Icons.rule,
          page: DisciplinaryRecordsPage(),
          webGroup: 'Billing & Records',
          webDescription: 'Recorded violations and actions',
        ),
        const AppDestination(
          label: 'Analytics',
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics,
          page: ReportsAnalyticsPage(),
          webGroup: 'Billing & Records',
          webDescription: 'Operational metrics and trends',
        ),
      ],
      const AppDestination(
        label: 'Announcements',
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign,
        page: AnnouncementsManagementPage(),
        webGroup: 'Communication',
        webDescription: 'Publish dormitory notices',
      ),
      const AppDestination(
        label: 'Contact directory',
        icon: Icons.emergency_outlined,
        selectedIcon: Icons.emergency,
        page: EmergencyContactsPage(),
        webGroup: 'Communication',
        webDescription: 'Important contact information',
      ),
      const AppDestination(
        label: 'Accounts',
        icon: Icons.manage_accounts_outlined,
        selectedIcon: Icons.manage_accounts,
        page: AccountManagementPage(),
        webGroup: 'Administration',
        webDescription: 'Role-based user accounts',
      ),
      if (owner)
        const AppDestination(
          label: 'Guardian links',
          icon: Icons.family_restroom_outlined,
          selectedIcon: Icons.family_restroom,
          page: GuardianLinkManagementPage(),
          webGroup: 'Administration',
          webDescription: 'Tenant and guardian access links',
        ),
      const AppDestination(
        label: 'Security & retention',
        icon: Icons.security_outlined,
        selectedIcon: Icons.security,
        page: RetentionSettingsPage(),
        webGroup: 'Administration',
        webDescription: 'Sensitive-record retention controls',
      ),
    ];
  }
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
