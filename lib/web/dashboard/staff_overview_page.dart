import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../models/models.dart';
import '../../views/owner/billing_management_page.dart';
import '../../views/owner/contracts_page.dart';
import '../../views/owner/owner_pages.dart';
import '../../views/owner/room_monitoring_page.dart';
import '../../views/shared/conduct_case_pages.dart';
import '../../views/shared/employee_curfew_profile_pages.dart';
import '../../views/shared/retention_settings_page.dart';
import '../../views/shared/cleaning_schedule_management_page.dart';
import 'widgets/staff_overview_card.dart';

/// New LIVE dashboard on the browser route only. Reuses existing management
/// destinations and OwnerController; no writes, demo values, or Supabase changes.
class StaffOverviewPage extends StatefulWidget {
  const StaffOverviewPage({super.key, required this.role});
  final UserRole role;

  @override
  State<StaffOverviewPage> createState() => _StaffOverviewPageState();
}

class _StaffOverviewPageState extends State<StaffOverviewPage> {
  bool refreshing = false;

  void _open(Widget page, {String? destinationLabel}) {
    final nav = CarmelitaNavScope.maybeOf(context);
    if (destinationLabel != null && nav != null) {
      nav.selectLabel(destinationLabel);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Future<void> _refresh() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    final data = OwnerController.instance;
    try {
      await Future.wait([
        data.loadRooms(force: true),
        data.loadTenants(force: true),
        data.loadPayments(force: true),
        data.loadStaffMaintenance(force: true),
        data.loadGateEvents(force: true),
        data.loadCurfewRequests(force: true),
        if (widget.role == UserRole.owner) data.loadContracts(force: true),
      ]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Some data could not be refreshed. Check the status below.'),
        ));
      }
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AnimatedBuilder(
          animation: OwnerController.instance,
          builder: (context, _) {
            final data = OwnerController.instance;
            final owner = widget.role == UserRole.owner;
            final metrics = <_Metric>[
              _Metric(
                'Occupancy',
                _display(data.roomsLoadedOnce, data.roomsLoading,
                    '${data.occupiedBeds} / ${data.totalCapacity}'),
                data.roomsLoadedOnce
                    ? '${data.roomRecords.length} rooms recorded'
                    : data.roomsError ?? 'Room records unavailable',
                Icons.bed_outlined,
                const RoomMonitoringPage(),
                'Rooms',
              ),
              _Metric(
                'Residents inside',
                _display(data.tenantsLoadedOnce, data.tenantsLoading,
                    '${data.tenantsInsideCount}'),
                data.tenantsLoadedOnce
                    ? '${data.tenantsOutsideCount} outside · ${data.tenantsUnavailableCount} unavailable'
                    : data.tenantsError ?? 'Presence records unavailable',
                Icons.location_on_outlined,
                const GeofenceMonitoringPage(),
                'Presence & Curfew',
              ),
              _Metric(
                'Maintenance',
                _display(data.maintenanceLoadedOnce, data.maintenanceLoading,
                    '${data.openMaintenance}'),
                data.maintenanceLoadedOnce
                    ? 'Open reports'
                    : data.maintenanceError ??
                        'Maintenance records unavailable',
                Icons.handyman_outlined,
                const MaintenanceManagementPage(),
                'Maintenance',
              ),
              _Metric(
                'Payment reviews',
                _display(data.paymentsLoadedOnce, data.paymentsLoading,
                    '${data.pendingPaymentProofs}'),
                data.paymentsLoadedOnce
                    ? 'Proofs awaiting review'
                    : data.paymentsError ?? 'Payment records unavailable',
                Icons.receipt_long_outlined,
                const PaymentVerificationPage(),
                'Payment verification',
              ),
            ];
            return LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;
              final inset = compact ? 16.0 : 26.0;
              return SingleChildScrollView(
                key: const Key('staff-overview-scroll'),
                padding: EdgeInsets.fromLTRB(inset, 24, inset, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _OverviewHeader(
                          roleLabel: owner ? 'OWNER' : 'CARETAKER',
                          refreshing: refreshing,
                          onRefresh: _refresh,
                        ),
                        const SizedBox(height: 14),
                        const _StaffPropertyHero(),
                        const SizedBox(height: 22),
                        const _SectionLabel(
                          title: 'Property at a glance',
                          subtitle: 'Live operational records, not estimates',
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(builder: (context, grid) {
                          final columns = grid.maxWidth >= 1040
                              ? 4
                              : grid.maxWidth >= 550
                                  ? 2
                                  : 1;
                          const spacing = 12.0;
                          final tileWidth =
                              (grid.maxWidth - spacing * (columns - 1)) /
                                  columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final metric in metrics)
                                SizedBox(
                                  width: tileWidth,
                                  child: StaffOverviewCard(
                                    label: metric.label,
                                    value: metric.value,
                                    detail: metric.detail,
                                    icon: metric.icon,
                                    onTap: () => _open(
                                      metric.page,
                                      destinationLabel: metric.destinationLabel,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }),
                        const SizedBox(height: 28),
                        const _SectionLabel(
                          title: 'Work requiring attention',
                          subtitle:
                              'Open the original management module to act',
                        ),
                        const SizedBox(height: 12),
                        StaffActionRow(
                          title: 'Maintenance requests',
                          description: data.maintenanceLoadedOnce
                              ? 'Review open reports and repair progress'
                              : data.maintenanceError ??
                                  'Waiting for maintenance data',
                          value: data.maintenanceLoadedOnce
                              ? '${data.openMaintenance}'
                              : null,
                          icon: Icons.build_outlined,
                          onTap: () => _open(const MaintenanceManagementPage(),
                              destinationLabel: 'Maintenance'),
                        ),
                        const SizedBox(height: 9),
                        StaffActionRow(
                          title: 'Billing & charges',
                          description: data.paymentsLoadedOnce
                              ? 'Review balances, utilities and approved charges'
                              : data.paymentsError ??
                                  'Waiting for billing data',
                          value: data.paymentsLoadedOnce
                              ? '${data.overduePaymentCount} overdue'
                              : null,
                          icon: Icons.account_balance_wallet_outlined,
                          onTap: () => _open(
                            const BillingManagementPage(),
                            destinationLabel: 'Billing & charges',
                          ),
                        ),
                        const SizedBox(height: 9),
                        StaffActionRow(
                          title: 'Payment proofs',
                          description: data.paymentsLoadedOnce
                              ? 'Verify submitted payment evidence'
                              : data.paymentsError ??
                                  'Waiting for payment data',
                          value: data.paymentsLoadedOnce
                              ? '${data.pendingPaymentProofs}'
                              : null,
                          icon: Icons.receipt_long_outlined,
                          onTap: () => _open(const PaymentVerificationPage(),
                              destinationLabel: 'Payment verification'),
                        ),
                        if (owner) ...[
                          const SizedBox(height: 9),
                          StaffActionRow(
                            title: 'Contract renewals',
                            description: data.contractsLoadedOnce
                                ? 'Active contracts expiring within 30 days'
                                : data.contractsError ??
                                    'Waiting for contract data',
                            value: data.contractsLoadedOnce
                                ? '${data.contractsExpiringWithin30Days}'
                                : null,
                            icon: Icons.description_outlined,
                            onTap: () => _open(const ContractsPage(),
                                destinationLabel: 'Contracts'),
                          ),
                        ],
                        const SizedBox(height: 28),
                        const _SectionLabel(
                          title: 'Jump into management',
                          subtitle:
                              'Existing live pages and permissions are preserved',
                        ),
                        const SizedBox(height: 12),
                        Wrap(spacing: 9, runSpacing: 9, children: [
                          OutlinedButton.icon(
                            onPressed: () => _open(const TenantDirectoryPage(),
                                destinationLabel: 'Residents'),
                            icon: const Icon(Icons.groups_outlined, size: 18),
                            label: const Text('Tenant directory'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _open(const RoomMonitoringPage(),
                                destinationLabel: 'Rooms'),
                            icon: const Icon(Icons.meeting_room_outlined,
                                size: 18),
                            label: const Text('Room monitoring'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _open(const OperationsHubPage(),
                                destinationLabel: 'Operations'),
                            icon: const Icon(Icons.tune_outlined, size: 18),
                            label: const Text('Operations'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _open(
                              const BillingManagementPage(),
                              destinationLabel: 'Billing & charges',
                            ),
                            icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18,
                            ),
                            label: const Text('Billing & charges'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _open(
                                const VisitorManagementPage(),
                                destinationLabel: 'Visitors'),
                            icon: const Icon(Icons.people_outline, size: 18),
                            label: const Text('Visitors'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _open(
                              const CleaningScheduleManagementPage(),
                              destinationLabel: 'Cleaning schedules',
                            ),
                            icon: const Icon(
                              Icons.cleaning_services_outlined,
                              size: 18,
                            ),
                            label: const Text('Cleaning schedules'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _open(const RoomMonitoringPage(),
                                destinationLabel: 'Room inspections'),
                            icon:
                                const Icon(Icons.fact_check_outlined, size: 18),
                            label: const Text('Room inspections'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _open(
                                const StaffConductCasesPage(),
                                destinationLabel: 'Conduct & Cases'),
                            icon: const Icon(Icons.gavel_outlined, size: 18),
                            label: const Text('Conduct & cases'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _open(
                                const EmployeeCurfewProfilesPage(),
                                destinationLabel: 'Employee curfew'),
                            icon: const Icon(Icons.badge_outlined, size: 18),
                            label: const Text('Employee curfew'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _open(
                                const RetentionSettingsPage(),
                                destinationLabel: 'Security & retention'),
                            icon: const Icon(Icons.security_outlined, size: 18),
                            label: const Text('Security & retention'),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              );
            });
          },
        ),
      );
}

String _display(bool ready, bool loading, String value) => ready
    ? value
    : loading
        ? 'Loading…'
        : 'Unavailable';

class _Metric {
  const _Metric(
    this.label,
    this.value,
    this.detail,
    this.icon,
    this.page,
    this.destinationLabel,
  );
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Widget page;
  final String destinationLabel;
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.roleLabel,
    required this.refreshing,
    required this.onRefresh,
  });

  final String roleLabel;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;

    return Container(
      key: const Key('staff-overview-header'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CARMELITA / $roleLabel',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The day in focus.',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 29,
                  letterSpacing: -.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Your operational overview, drawn from current records.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            key: const Key('staff-overview-refresh'),
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(refreshing ? 'Refreshing' : 'Refresh records'),
          ),
        ],
      ),
    );
  }
}

class _StaffPropertyHero extends StatelessWidget {
  const _StaffPropertyHero();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          return ClipRRect(
            key: const Key('staff-dashboard-property-hero'),
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: double.infinity,
              height: compact ? 170 : 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    AppAssets.dormOverview,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .70),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 22,
                    right: 22,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CarmeLink',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Quick monitoring for daily operations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
