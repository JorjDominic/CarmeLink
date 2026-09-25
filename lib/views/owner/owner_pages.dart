import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../controllers/messaging_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/visitor_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/boundary_config_service.dart';
import '../../services/geofence_service.dart';
import '../../services/payment_service.dart';
import '../../services/tenant_service.dart';
import '../../services/announcement_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../widgets/feature_widgets.dart';
import '../shared/account_management_page.dart';
import '../shared/staff_quick_panel.dart';
import '../shared/employee_curfew_profile_pages.dart';
import 'floor_plan_page.dart';
import 'guardian_link_management_page.dart';
import 'staff_maintenance_page.dart';
import 'room_monitoring_page.dart';
import 'geofence_dev_dashboard_page.dart';
import 'contracts_page.dart';
import 'tenant_onboarding_flow.dart';
import 'utility_charge_cart_dialog.dart';

/// Filters existing Supabase-backed directory entries; no client-side
/// tenant records are created or mutated here.
List<TenantDirectoryEntry> filterTenantDirectory(
  List<TenantDirectoryEntry> tenants, {
  String query = '',
  String residency = 'all',
}) {
  final needle = query.trim().toLowerCase();
  return tenants.where((tenant) {
    if (residency != 'all' && tenant.residencyStatus != residency) return false;
    if (needle.isEmpty) return true;
    return [
      tenant.name,
      tenant.room,
      tenant.bedSpace,
      tenant.phone,
      tenant.guardianName,
    ].any((field) => field.toLowerCase().contains(needle));
  }).toList();
}

void _ownerPush(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => page),
  );
}

// Temporarily hidden until the full contract-onboarding flow is resumed.
const _showOnboardingIncomplete = false;

class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({
    this.isCaretaker = false,
    super.key,
  });

  /// Keeps the shared staff dashboard focused on the work available to the
  /// signed-in role. Caretakers use the same operational data without seeing
  /// owner-only contract reminders.
  final bool isCaretaker;

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Dashboard',
      subtitle: 'Priority-ranked Today view',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final occupancyValue = controller.roomsLoadedOnce
              ? '${controller.occupiedBeds}/${controller.totalCapacity}'
              : controller.roomsLoading
                  ? '...'
                  : 'â€”';
          final presenceValue = controller.tenantsLoadedOnce
              ? '${controller.tenantsInsideCount} Inside'
              : controller.tenantsLoading
                  ? 'Loading'
                  : 'Unavailable';
          final paymentValue = controller.paymentsLoadedOnce
              ? '${controller.pendingPaymentProofs}'
              : controller.paymentsLoading
                  ? '...'
                  : 'â€”';
          final maintenanceValue = controller.maintenanceLoadedOnce
              ? '${controller.openMaintenance}'
              : controller.maintenanceLoading
                  ? '...'
                  : 'â€”';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElegantHeader(
                eyebrow: isCaretaker ? 'Caretaker operations' : 'Operations',
                title: 'Good afternoon.',
                subtitle: controller.roomsLoadedOnce
                    ? '${controller.occupiedBeds} of ${controller.totalCapacity} beds are currently occupied.'
                    : controller.roomsLoading
                        ? 'Loading current property status...'
                        : controller.roomsError != null
                            ? 'Property status is unavailable.'
                            : 'No room data available.',
                trailing: StatusPill(
                  controller.tenantsLoadedOnce
                      ? '${controller.tenantsInsideCount} inside'
                      : controller.tenantsLoading
                          ? 'Loading'
                          : 'No data',
                  icon: Icons.location_on_outlined,
                ),
              ),
              const SizedBox(height: 16),
              const PhotoHero(
                image: AppAssets.dormOverview,
                title: 'CarmeLink',
                subtitle: 'Quick monitoring for daily operations',
                height: 176,
              ),
              const SizedBox(height: 16),
              const SectionTitle(
                'Property status',
                subtitle: 'The numbers that matter most right now',
              ),
              const SizedBox(height: 10),
              MutedDashboardGrid(
                compact: true,
                denseFourColumn: true,
                items: [
                  MutedDashboardItem(
                    label: 'Occupancy',
                    value: occupancyValue,
                    detail: controller.roomsLoadedOnce
                        ? '${controller.rooms.length} rooms'
                        : controller.roomsError != null
                            ? 'Room data unavailable'
                            : 'No room data',
                    icon: Icons.bed_outlined,
                    color: const Color(0xFF56886B),
                    onTap: () => _ownerPush(
                      context,
                      const RoomMonitoringPage(),
                    ),
                  ),
                  MutedDashboardItem(
                    label: 'Payment reviews',
                    value: paymentValue,
                    detail: controller.paymentsLoadedOnce
                        ? 'Proofs waiting'
                        : controller.paymentsError != null
                            ? 'Payment data unavailable'
                            : 'No payment data',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFFAA8A45),
                    onTap: () => _ownerPush(
                      context,
                      const PaymentVerificationPage(),
                    ),
                  ),
                  MutedDashboardItem(
                    label: 'Maintenance',
                    value: maintenanceValue,
                    detail: controller.maintenanceLoadedOnce
                        ? 'Open reports'
                        : controller.maintenanceError != null
                            ? 'Maintenance unavailable'
                            : 'No maintenance data',
                    icon: Icons.build_outlined,
                    color: const Color(0xFFB47A52),
                    onTap: () => _ownerPush(
                      context,
                      const MaintenanceManagementPage(),
                    ),
                  ),
                  MutedDashboardItem(
                    label: 'Curfew',
                    value: presenceValue,
                    detail: controller.tenantsLoadedOnce
                        ? '${controller.tenantsOutsideCount} Outside â€¢ ${controller.tenantsUnavailableCount} Unavailable'
                        : controller.tenantsError != null
                            ? 'Presence data unavailable'
                            : 'No presence data',
                    icon: Icons.schedule_outlined,
                    color: const Color(0xFF56886B),
                    onTap: () => _ownerPush(
                      context,
                      const GeofenceMonitoringPage(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionTitle(
                'Today • highest priority first',
                subtitle: 'Actionable items before routine monitoring',
              ),
              const SizedBox(height: 10),
              if (isCaretaker)
                AttentionCard(
                  compact: true,
                  icon: Icons.build_outlined,
                  title: controller.maintenanceLoadedOnce
                      ? '${controller.openMaintenance} maintenance report(s) open'
                      : 'Maintenance data unavailable',
                  subtitle: controller.maintenanceLoadedOnce
                      ? 'Review assignments and update repair progress.'
                      : controller.maintenanceError ??
                          'No maintenance information has been loaded.',
                  status: controller.maintenanceLoadedOnce
                      ? controller.openMaintenance > 0
                          ? 'Open'
                          : 'Clear'
                      : controller.maintenanceLoading
                          ? 'Loading'
                          : 'No data',
                  onTap: () => _ownerPush(
                    context,
                    const MaintenanceManagementPage(),
                  ),
                )
              else
                AttentionCard(
                  compact: true,
                  icon: Icons.event_busy_outlined,
                  title: controller.contractsLoadedOnce
                      ? '${controller.contractsExpiringWithin30Days} contract(s) expire within 30 days'
                      : 'Contract data unavailable',
                  subtitle: controller.contractsLoadedOnce
                      ? 'Review renewal or move-out arrangements.'
                      : controller.contractsError ??
                          'No contract information has been loaded.',
                  status: controller.contractsLoadedOnce
                      ? controller.contractsExpiringWithin30Days > 0
                          ? 'Soon'
                          : 'Clear'
                      : controller.contractsLoading
                          ? 'Loading'
                          : 'No data',
                  onTap: () => _ownerPush(context, const ContractsPage()),
                ),
              const SizedBox(height: 8),
              AttentionCard(
                compact: true,
                icon: Icons.receipt_long_outlined,
                title: controller.paymentsLoadedOnce
                    ? '${controller.pendingPaymentProofs} payment proof(s) waiting'
                    : 'Payment data unavailable',
                subtitle: controller.paymentsLoadedOnce
                    ? 'Review uploaded proof before changing payment status.'
                    : controller.paymentsError ??
                        'No payment information has been loaded.',
                status: controller.paymentsLoadedOnce
                    ? controller.pendingPaymentProofs > 0
                        ? 'Pending'
                        : 'Clear'
                    : controller.paymentsLoading
                        ? 'Loading'
                        : 'No data',
                onTap: () => _ownerPush(
                  context,
                  const PaymentVerificationPage(),
                ),
              ),
              const SizedBox(height: 8),
              AttentionCard(
                compact: true,
                icon: Icons.location_on_outlined,
                title: controller.tenantsLoadedOnce
                    ? 'Resident presence overview'
                    : 'Presence data unavailable',
                subtitle: controller.tenantsLoadedOnce
                    ? '${controller.tenantsInsideCount} inside, ${controller.tenantsOutsideCount} outside, and ${controller.tenantsUnavailableCount} unavailable.'
                    : controller.tenantsError ??
                        'No resident presence information has been loaded.',
                status: controller.tenantsLoadedOnce
                    ? 'Current'
                    : controller.tenantsLoading
                        ? 'Loading'
                        : 'No data',
                onTap: () => _ownerPush(
                  context,
                  const GeofenceMonitoringPage(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TenantDirectoryPage extends StatefulWidget {
  const TenantDirectoryPage({super.key});

  @override
  State<TenantDirectoryPage> createState() => _TenantDirectoryPageState();
}

class _TenantDirectoryPageState extends State<TenantDirectoryPage> {
  final _service = const TenantService();
  List<TenantDirectoryEntry>? _tenants;
  bool _loading = true;
  String? _errorMessage;
  late final TableRefreshSubscription _subscription;
  String query = '';
  String residencyFilter = 'all';
  bool _creatingTenant = false;

  Future<void> _createTenant() async {
    if (_creatingTenant) return;
    setState(() => _creatingTenant = true);
    bool accountCreated = false;
    try {
      final created = await showCreateTenantAccount(context);
      if (created == null || !mounted) return;
      accountCreated = true;
      TenantService.invalidateCache();
      await _fetchTenants(showSpinner: false);
      await OwnerController.instance.loadTenants(force: true);
      if (!mounted) return;
      if (SessionController.instance.currentUser?.role == UserRole.owner) {
        final createContract = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Tenant account created'),
            content:
                Text('Create a draft contract for ${created.fullName} now? '
                    'You can also do this later from the tenant details.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Do this later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Create contract'),
              ),
            ],
          ),
        );
        if (createContract == true && mounted) {
          await showContractEditor(
            context,
            initialTenantId: created.id,
            initialTenantName: created.fullName,
            lockTenant: true,
          );
          if (!mounted) return;
          await _fetchTenants(showSpinner: false);
        }
      } else {
        showAppSnackBar(context, 'Tenant account created.');
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          accountCreated
              ? 'Tenant account was created, but a follow-up step failed: $error'
              : 'Could not create tenant: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _creatingTenant = false);
    }
  }

  Future<void> _openTenant(TenantDirectoryEntry tenant) async {
    // On wide web, quick inspection should not lose search/filter position.
    // On mobile and narrow web, preserve the existing full-page behavior.
    if (kIsWeb && MediaQuery.sizeOf(context).width >= 1024) {
      final action = await showStaffQuickPanel<_TenantQuickAction>(
        context,
        builder: (panelContext) => TenantQuickPreview(
          tenant: tenant,
          onClose: () => Navigator.of(panelContext).pop(),
          onFullDetails: () =>
              Navigator.of(panelContext).pop(_TenantQuickAction.full),
          onManageAccount: () =>
              Navigator.of(panelContext).pop(_TenantQuickAction.manage),
        ),
      );
      if (!mounted) return;
      if (action == _TenantQuickAction.manage) {
        await _editTenant(tenant);
      } else if (action == _TenantQuickAction.full) {
        await _openFullTenantDetails(tenant);
      }
    } else {
      await _openFullTenantDetails(tenant);
    }
  }

  Future<void> _openFullTenantDetails(TenantDirectoryEntry tenant) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TenantDetailsPage(tenant: tenant)),
    );
    if (mounted) await _fetchTenants(showSpinner: false);
  }

  Future<void> _editTenant(TenantDirectoryEntry tenant) async {
    try {
      final changed = await showEditTenantAccount(context, tenant.id);
      if (!changed || !mounted) return;
      TenantService.invalidateCache();
      await _fetchTenants(showSpinner: false);
      await OwnerController.instance.loadTenants(force: true);
      if (mounted) showAppSnackBar(context, 'Tenant account updated.');
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Could not manage tenant: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    _tenants = TenantService.cachedTenants;
    _loading = _tenants == null;
    _fetchTenants(showSpinner: _tenants == null);
    _subscription = TableRefreshSubscription(
      'tenant-directory',
      [
        'profiles',
        'tenant_details',
        'guardian_tenant_links',
        'tenant_assignments',
        'bed_spaces',
        'rooms',
        'tenant_contracts',
      ],
      () => _fetchTenants(showSpinner: false),
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  Future<void> _fetchTenants({bool showSpinner = false}) async {
    if (showSpinner && mounted) {
      setState(() => _loading = true);
    }
    try {
      final latest = await _service.loadTenants(
        forceRefresh: true,
        includeContractStatus:
            SessionController.instance.currentUser?.role == UserRole.owner,
      );
      if (mounted) {
        setState(() {
          _tenants = latest;
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTenants = _tenants;

    Widget body;
    if (_loading && currentTenants == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null && currentTenants == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load tenants',
              message: _errorMessage!,
            ),
            FilledButton.icon(
              onPressed: () => _fetchTenants(showSpinner: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    } else {
      final allTenants = currentTenants ?? [];
      final filtered = kIsWeb
          ? filterTenantDirectory(
              allTenants,
              query: query,
              residency: residencyFilter,
            )
          : allTenants
              .where((tenant) =>
                  tenant.name.toLowerCase().contains(query.toLowerCase()) ||
                  tenant.room.contains(query))
              .toList();

      body = Column(
        children: [
          if (kIsWeb)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 340,
                  child: TextField(
                    key: const Key('web-tenant-search'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search name, room, phone or guardian',
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    key: const Key('web-tenant-residency-filter'),
                    initialValue: residencyFilter,
                    decoration:
                        const InputDecoration(labelText: 'Residency status'),
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('All statuses')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'moving_out', child: Text('Moving out')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => residencyFilter = value);
                      }
                    },
                  ),
                ),
                Text('${filtered.length} of ${allTenants.length} tenants'),
              ],
            )
          else
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tenant name or room',
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'No tenant found',
              message: 'Try another name or room number.',
            )
          else
            ...filtered.map(
              (tenant) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CarmelitaCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -2),
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 19,
                      backgroundColor:
                          const Color(0xFF56886B).withValues(alpha: .10),
                      foregroundColor: const Color(0xFF56886B),
                      child:
                          Text(tenant.name.isNotEmpty ? tenant.name[0] : '?'),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tenant.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_showOnboardingIncomplete &&
                            tenant.hasContract == false)
                          const _OnboardingIncompleteBadge(),
                      ],
                    ),
                    subtitle: Text('Room ${tenant.room} • ${tenant.bedSpace}'),
                    trailing: kIsWeb
                        ? SizedBox(
                            width: 156,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: StatusPill(
                                      _residencyLabel(tenant.residencyStatus)),
                                ),
                                IconButton(
                                  key: Key('web-edit-tenant-${tenant.id}'),
                                  tooltip: 'Edit or delete tenant account',
                                  icon: const Icon(
                                      Icons.manage_accounts_outlined),
                                  onPressed: () => _editTenant(tenant),
                                ),
                              ],
                            ),
                          )
                        : StatusPill(_residencyLabel(tenant.residencyStatus)),
                    onTap: () => _openTenant(tenant),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return PageFrame(
      title: 'Tenants',
      subtitle: kIsWeb
          ? 'Search and manage tenant records'
          : 'Search and view tenant records',
      floatingActionButton: kIsWeb
          ? FloatingActionButton.extended(
              key: const Key('web-create-tenant'),
              onPressed: _creatingTenant ? null : _createTenant,
              icon: const Icon(Icons.person_add_outlined),
              label: Text(_creatingTenant ? 'Creating...' : 'Add tenant'),
            )
          : null,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _fetchTenants(showSpinner: currentTenants == null),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: body,
    );
  }
}

// Only preview and navigation here. Changes still go through the existing
// tenant/account services and the full mobile-equivalent detail screen.
enum _TenantQuickAction { full, manage }

class TenantQuickPreview extends StatelessWidget {
  const TenantQuickPreview({
    required this.tenant,
    required this.onFullDetails,
    required this.onManageAccount,
    required this.onClose,
    super.key,
  });

  final TenantDirectoryEntry tenant;
  final VoidCallback onFullDetails;
  final VoidCallback onManageAccount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Column(
        key: const Key('tenant-quick-preview'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Tenant details',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Close quick details',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(tenant.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 6),
          StatusPill(_residencyLabel(tenant.residencyStatus)),
          const Divider(height: 32),
          InfoRow(
            label: 'Room and bed',
            value: '${tenant.room} • ${tenant.bedSpace}',
            icon: Icons.bed_outlined,
          ),
          InfoRow(
            label: 'Phone',
            value: tenant.phone,
            icon: Icons.phone_outlined,
          ),
          InfoRow(
            label: 'Guardian',
            value: tenant.guardianName,
            icon: Icons.family_restroom_outlined,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('tenant-quick-full-details'),
            onPressed: onFullDetails,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open full tenant details'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('tenant-quick-manage-account'),
            onPressed: onManageAccount,
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('Manage account'),
          ),
        ],
      );
}

class TenantDetailsPage extends StatelessWidget {
  const TenantDetailsPage({
    required this.tenant,
    super.key,
  });

  final TenantDirectoryEntry tenant;

  @override
  Widget build(BuildContext context) {
    final isOwnerWeb = kIsWeb &&
        SessionController.instance.currentUser?.role == UserRole.owner;
    final isStaffWeb = kIsWeb &&
        {UserRole.owner, UserRole.caretaker}.contains(
          SessionController.instance.currentUser?.role,
        );
    final needsContract = tenant.hasContract == false;
    final needsBed = tenant.assignmentId == null;
    final needsGuardian = tenant.guardianName == 'Not assigned';

    return PageFrame(
      title: tenant.name,
      subtitle: 'Tenant details',
      actions: isStaffWeb
          ? [
              IconButton(
                tooltip: 'Edit or delete tenant account',
                icon: const Icon(Icons.manage_accounts_outlined),
                onPressed: () async {
                  try {
                    final changed =
                        await showEditTenantAccount(context, tenant.id);
                    if (changed && context.mounted) {
                      TenantService.invalidateCache();
                      Navigator.of(context).pop();
                    }
                  } catch (error) {
                    if (context.mounted) {
                      showAppSnackBar(
                          context, 'Could not manage tenant: $error');
                    }
                  }
                },
              ),
            ]
          : null,
      child: Column(
        children: [
          CarmelitaCard(
            child: Column(
              children: [
                InfoRow(
                  label: 'Room',
                  value: '${tenant.room} • ${tenant.bedSpace}',
                  icon: Icons.meeting_room_outlined,
                ),
                InfoRow(
                  label: 'Phone',
                  value: tenant.phone,
                  icon: Icons.phone_outlined,
                ),
                InfoRow(
                  label: 'Guardian',
                  value: tenant.guardianName,
                  icon: Icons.family_restroom_outlined,
                ),
                InfoRow(
                  label: 'Guardian phone',
                  value: tenant.guardianPhone,
                  icon: Icons.contact_phone_outlined,
                ),
                InfoRow(
                    label: 'Residency status',
                    value: _residencyLabel(tenant.residencyStatus),
                    icon: Icons.badge_outlined),
                InfoRow(
                    label: 'Contract starts',
                    value: _dateOrNone(tenant.contractStartsOn),
                    icon: Icons.event_available_outlined),
                InfoRow(
                    label: 'Contract ends',
                    value: _dateOrNone(tenant.contractEndsOn),
                    icon: Icons.event_busy_outlined),
              ],
            ),
          ),
          if (isOwnerWeb && (needsContract || needsBed || needsGuardian)) ...[
            const SizedBox(height: 14),
            CarmelitaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Onboarding checklist'),
                  const SizedBox(height: 8),
                  Text(
                      'Contract: ${needsContract ? 'Not created' : 'Created'}'),
                  Text('Bed: ${needsBed ? 'Not assigned' : 'Assigned'}'),
                  Text('Primary guardian: '
                      '${needsGuardian ? 'Not assigned' : 'Assigned'}'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('web-tenant-onboarding-action'),
                    onPressed: () async {
                      if (needsContract) {
                        final saved = await showContractEditor(
                          context,
                          initialTenantId: tenant.id,
                          initialTenantName: tenant.name,
                          lockTenant: true,
                        );
                        if (saved == true && context.mounted) {
                          Navigator.pop(context);
                        }
                      } else {
                        await continueTenantOnboarding(
                          context,
                          tenantId: tenant.id,
                          tenantName: tenant.name,
                          fromSavedContract: false,
                        );
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: Icon(needsContract
                        ? Icons.description_outlined
                        : Icons.task_alt_outlined),
                    label: Text(needsContract
                        ? 'Create draft contract'
                        : 'Continue onboarding'),
                  ),
                ],
              ),
            ),
          ],
          if (_showOnboardingIncomplete && tenant.hasContract == false) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.pending_actions_outlined,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Onboarding incomplete',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This tenant does not have a contract yet. Create a draft to continue onboarding.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final saved = await showContractEditor(
                        context,
                        initialTenantId: tenant.id,
                        initialTenantName: tenant.name,
                        lockTenant: true,
                      );
                      if (saved == true && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Create contract'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _TenantAssignmentManager(tenant: tenant),
        ],
      ),
    );
  }
}

class _OnboardingIncompleteBadge extends StatelessWidget {
  const _OnboardingIncompleteBadge();

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'No contract has been created for this tenant',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.priority_high_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 3),
              Text(
                'Incomplete',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      );
}

String _residencyLabel(String value) => switch (value) {
      'moving_out' => 'Moving out',
      'inactive' => 'Inactive',
      _ => 'Active',
    };

String _dateOrNone(DateTime? value) => value == null
    ? 'Not set'
    : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class _TenantAssignmentManager extends StatefulWidget {
  const _TenantAssignmentManager({required this.tenant});
  final TenantDirectoryEntry tenant;
  @override
  State<_TenantAssignmentManager> createState() =>
      _TenantAssignmentManagerState();
}

class _TenantAssignmentManagerState extends State<_TenantAssignmentManager> {
  final service = const TenantService();
  bool saving = false;

  Future<void> _assign() async {
    setState(() => saving = true);
    try {
      final bedRooms = await service.loadAvailableBedsGroupedByRoom();
      if (!mounted) return;
      if (bedRooms.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No available beds'),
            content: const Text(
              'All rooms and bed spaces are currently occupied or unavailable. Free an existing bed by ending its active assignment first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }
      final selected = await showModalBottomSheet<AvailableBed>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => RoomBedSelectorSheet(
          rooms: bedRooms,
          tenantName: widget.tenant.name,
        ),
      );
      if (selected == null || !mounted) return;
      await service.assignBed(widget.tenant.id, selected.id);
      if (mounted) {
        showAppSnackBar(
          context,
          'Assigned ${widget.tenant.name} to Room ${selected.room} • ${selected.label}',
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, tenantAssignmentError(error));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _setStatus(String status) => _save(
      () => service.updateResidencyStatus(widget.tenant.id, status),
      'Residency status updated. Refresh the directory to see it.');

  Future<void> _end() => _save(() => service.endAssignment(widget.tenant.id),
      'Assignment ended. Refresh the directory to see it.');

  Future<void> _save(Future<void> Function() action, String message) async {
    setState(() => saving = true);
    try {
      await action();
      if (mounted) {
        showAppSnackBar(context, message);
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Unable to save: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => CarmelitaCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Room and residency management'),
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed: saving ? null : _assign,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bed_outlined),
              label: Text(widget.tenant.assignmentId == null
                  ? 'Assign bed'
                  : 'Move to another bed')),
          if (widget.tenant.assignmentId != null)
            TextButton(
                onPressed: saving ? null : _end,
                child: const Text('End current assignment')),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
              initialValue: widget.tenant.residencyStatus,
              decoration: const InputDecoration(labelText: 'Residency status'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(
                    value: 'moving_out', child: Text('Moving out')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive'))
              ],
              onChanged: saving
                  ? null
                  : (value) {
                      if (value != null) _setStatus(value);
                    }),
        ],
      ));
}

String tenantAssignmentError(Object error) {
  final message = error.toString();
  if (message.contains('no longer available') ||
      message.contains('tenant_assignments_one_active_per_bed')) {
    return 'That bed was just assigned to someone else. Choose another bed.';
  }
  if (message.contains('Staff access required') || message.contains('42501')) {
    return 'Your account is not authorized to manage bed assignments.';
  }
  return 'Unable to load or save bed assignments. Check your connection and retry.';
}

class RoomBedSelectorSheet extends StatefulWidget {
  const RoomBedSelectorSheet({
    required this.rooms,
    required this.tenantName,
    super.key,
  });

  final List<RoomWithAvailableBeds> rooms;
  final String tenantName;

  @override
  State<RoomBedSelectorSheet> createState() => _RoomBedSelectorSheetState();
}

class _RoomBedSelectorSheetState extends State<RoomBedSelectorSheet> {
  String? _expandedRoom;

  @override
  void initState() {
    super.initState();
    if (widget.rooms.isNotEmpty) {
      _expandedRoom = widget.rooms.first.roomNumber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalBeds =
        widget.rooms.fold<int>(0, (sum, r) => sum + r.beds.length);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .80,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.bed_outlined,
                      color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select bed space',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalBeds open bed spaces across ${widget.rooms.length} rooms',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.rooms.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final room = widget.rooms[index];
                  final isExpanded = _expandedRoom == room.roomNumber;

                  return CarmelitaCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _expandedRoom =
                                  isExpanded ? null : room.roomNumber;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 17,
                                  backgroundColor: isExpanded
                                      ? theme.colorScheme.primary
                                          .withValues(alpha: .15)
                                      : theme
                                          .colorScheme.surfaceContainerHighest,
                                  foregroundColor: isExpanded
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                  child: const Icon(Icons.meeting_room_outlined,
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Room ${room.roomNumber}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        room.floor,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF56886B)
                                        .withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${room.beds.length} open',
                                    style: const TextStyle(
                                      color: Color(0xFF56886B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                AnimatedRotation(
                                  duration: const Duration(milliseconds: 200),
                                  turns: isExpanded ? .25 : 0,
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            child: Column(
                              children: room.beds.map((bed) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => Navigator.of(context).pop(bed),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme.surfaceContainerHighest
                                            .withValues(alpha: .35),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.bed_outlined,
                                            size: 19,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              bed.label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: .12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Assign',
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme.primary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 13,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OperationsHubPage extends StatefulWidget {
  const OperationsHubPage({super.key});

  @override
  State<OperationsHubPage> createState() => _OperationsHubPageState();
}

class _OperationsHubPageState extends State<OperationsHubPage> {
  final searchController = TextEditingController();
  final Set<String> _quickAccess = {
    'Payments',
    'Report management',
    'Floor plan'
  };
  String query = '';

  bool get _isCaretaker =>
      SessionController.instance.currentUser?.role == UserRole.caretaker;

  List<_OperationCategory> get _visibleCategories => _operationCategories
      .map(
        (category) => _OperationCategory(
          category.title,
          category.subtitle,
          category.icon,
          category.color,
          category.items
              .where((item) => !_isCaretaker || !item.ownerOnly)
              .toList(),
        ),
      )
      .where((category) => category.items.isNotEmpty)
      .toList();

  List<_OperationItem> get _allOperationItems =>
      _visibleCategories.expand((category) => category.items).toList();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;
    final categories = _visibleCategories;
    final filtered = categories.where((category) {
      final searchable = [
        category.title,
        category.subtitle,
        ...category.items.expand((item) => [item.title, item.subtitle]),
      ].join(' ').toLowerCase();
      return searchable.contains(query.toLowerCase());
    }).toList();

    return PageFrame(
      title: 'Operations',
      subtitle: 'CarmeLink',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search categories or tools...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              searchController.clear();
                              setState(() => query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.tune_rounded,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ]),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final cards = [
                _OperationsStatus(
                    'Occupied rooms',
                    '${controller.occupiedBeds}/${controller.totalCapacity}',
                    Icons.bed_outlined,
                    const Color(0xFF56886B)),
                _OperationsStatus(
                    'Pending payments',
                    '${controller.pendingPaymentProofs}',
                    Icons.payments_outlined,
                    const Color(0xFFAA8A45)),
                _OperationsStatus(
                    'Open requests',
                    '${controller.openMaintenance}',
                    Icons.assignment_outlined,
                    const Color(0xFF627FA8)),
                _OperationsStatus(
                    'Inside perimeter',
                    '${controller.tenantsInsideCount}',
                    Icons.location_on_outlined,
                    const Color(0xFF4C8C65)),
              ];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth < 600 ? 2 : 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 110 + ((textScale - 1).clamp(0, 1) * 65),
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) =>
                    _OperationsStatusCard(data: cards[index]),
              );
            }),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text('Quick access',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                ),
                IconButton.filledTonal(
                  tooltip: 'Customize quick access',
                  onPressed: _showQuickAccessPicker,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._allOperationItems
                    .where((item) => _quickAccess.contains(item.title))
                    .map((item) => InputChip(
                          avatar: Icon(item.icon, size: 15),
                          label: Text(_quickAccessLabel(item, controller)),
                          labelStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -2,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                          tooltip: 'Open ${item.title}',
                          onPressed: () => _ownerPush(context, item.page),
                          onDeleted: () =>
                              setState(() => _quickAccess.remove(item.title)),
                          deleteIcon: const Icon(Icons.close_rounded, size: 14),
                        )),
              ],
            ),
            const SizedBox(height: 12),
            Text('Management areas',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Related tools are grouped together for quicker navigation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No operations found',
                  message: 'Try a different search term.')
            else
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 2 : 1;
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 76 + ((textScale - 1).clamp(0, 1) * 60),
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _OperationCategoryCard(
                    category: filtered[index],
                    badge: _categoryBadge(filtered[index], controller),
                    onTap: () => _ownerPush(
                      context,
                      OperationsCategoryPage(category: filtered[index]),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String? _categoryBadge(
      _OperationCategory category, OwnerController controller) {
    switch (category.title) {
      case 'Property':
        return controller.openMaintenance == 0
            ? null
            : '${controller.openMaintenance} open';
      case 'Tenants & safety':
        final total = controller.pendingVisitors;
        return total == 0 ? null : '$total pending';
      case 'Finance & contracts':
        return controller.pendingPaymentProofs == 0
            ? null
            : '${controller.pendingPaymentProofs} review';
      default:
        return null;
    }
  }

  String _quickAccessLabel(_OperationItem item, OwnerController controller) {
    switch (item.title) {
      case 'Payments':
        return 'Payments (${controller.pendingPaymentProofs})';
      case 'Report management':
        return 'Reports (${controller.openMaintenance})';
      case 'Visitors':
        return 'Visitors (${controller.pendingVisitors})';
      default:
        return item.title;
    }
  }

  void _showQuickAccessPicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customize quick access',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Choose the tools you use most often.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _allOperationItems.map((item) {
                    final selected = _quickAccess.contains(item.title);
                    return CheckboxListTile(
                      value: selected,
                      secondary: Icon(item.icon),
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (checked) {
                        setState(() {
                          if (checked ?? false) {
                            _quickAccess.add(item.title);
                          } else {
                            _quickAccess.remove(item.title);
                          }
                        });
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _operationCategories = [
  _OperationCategory(
    'Accounts & access',
    'Create users and manage system access',
    Icons.manage_accounts_outlined,
    Color(0xFF7D70A0),
    [
      _OperationItem(
        'User accounts',
        'Create and review role-based accounts',
        Icons.person_add_alt_1_outlined,
        AccountManagementPage(),
      ),
      _OperationItem(
        'Guardian links',
        'Connect guardians to tenant accounts',
        Icons.family_restroom_outlined,
        GuardianLinkManagementPage(),
        ownerOnly: true,
      ),
    ],
  ),
  _OperationCategory(
    'Property',
    'Rooms, floor plan, maintenance and devices',
    Icons.apartment_outlined,
    Color(0xFF56886B),
    [
      _OperationItem('Rooms', 'Manage room occupancy', Icons.bed_outlined,
          RoomMonitoringPage()),
      _OperationItem('Floor plan', 'Explore the interactive room map',
          Icons.map_outlined, AdminFloorPlanPage()),
      _OperationItem(
          'Report management',
          'Maintenance, confidential, and cleaning reports',
          Icons.assignment_outlined,
          ReportManagementPage()),
    ],
  ),
  _OperationCategory(
    'Tenants & safety',
    'People, access, conduct and private reports',
    Icons.health_and_safety_outlined,
    Color(0xFF627FA8),
    [
      _OperationItem(
          'Geofence presence',
          'Review live tenant presence and boundary',
          Icons.location_on_outlined,
          GeofenceMonitoringPage()),
      _OperationItem(
          'Employee curfew profiles',
          'Manage approved employment-based curfew schedules',
          Icons.badge_outlined,
          EmployeeCurfewProfilesPage()),
      _OperationItem('Visitors', 'Manage visitor requests',
          Icons.people_outline, VisitorManagementPage()),
      _OperationItem('Disciplinary records', 'Manage violations',
          Icons.gavel_outlined, DisciplinaryRecordsPage(),
          ownerOnly: true),
    ],
  ),
  _OperationCategory(
    'Finance & contracts',
    'Payments, accounting, renewals and reports',
    Icons.account_balance_wallet_outlined,
    Color(0xFFAA8A45),
    [
      _OperationItem('Payments', 'Verify and track payments',
          Icons.payments_outlined, PaymentVerificationPage()),
      _OperationItem('Income & expenses', 'Monitor property finances',
          Icons.insights_outlined, ExpenseIncomeSummaryPage(),
          ownerOnly: true),
      _OperationItem('Contracts', 'Create contracts and track renewals',
          Icons.event_busy_outlined, ContractsPage(),
          ownerOnly: true),
      _OperationItem('Analytics', 'View operational metrics and trends',
          Icons.analytics_outlined, ReportsAnalyticsPage(),
          ownerOnly: true),
    ],
  ),
  _OperationCategory(
    'Communication',
    'Announcements, messages and important contacts',
    Icons.forum_outlined,
    Color(0xFF7D70A0),
    [
      _OperationItem('Announcements', 'Post updates', Icons.campaign_outlined,
          AnnouncementsManagementPage()),
      _OperationItem('Messages', 'Send and receive messages',
          Icons.chat_bubble_outline, OwnerMessagingPage()),
      _OperationItem('Contact directory', 'View important contacts',
          Icons.emergency_outlined, EmergencyContactsPage()),
    ],
  ),
];

class OperationsCategoryPage extends StatelessWidget {
  const OperationsCategoryPage({required this.category, super.key});
  final _OperationCategory category;

  @override
  Widget build(BuildContext context) => PageFrame(
        title: category.title,
        subtitle: category.subtitle,
        useScriptTitle: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: category.color.withValues(alpha: .14)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: category.color.withValues(alpha: .12),
                    foregroundColor: category.color,
                    child: Icon(category.icon),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${category.items.length} connected pages',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 2 : 1;
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: category.items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 62 + ((textScale - 1).clamp(0, 1) * 28),
                ),
                itemBuilder: (context, index) => _OperationShortcut(
                  item: category.items[index],
                  color: category.color,
                  onTap: () => _ownerPush(context, category.items[index].page),
                ),
              );
            }),
          ],
        ),
      );
}

class _OperationCategoryCard extends StatelessWidget {
  const _OperationCategoryCard(
      {required this.category, required this.onTap, this.badge});
  final _OperationCategory category;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => CarmelitaCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(category.icon, color: category.color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    category.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('${category.items.length} pages',
                          style: TextStyle(
                              color: category.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 10)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Color(0xFFAA6870),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(badge!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFFAA6870),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
}

class _OperationCategory {
  const _OperationCategory(
      this.title, this.subtitle, this.icon, this.color, this.items);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_OperationItem> items;
}

class _OperationsStatus {
  const _OperationsStatus(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _OperationsStatusCard extends StatelessWidget {
  const _OperationsStatusCard({required this.data});
  final _OperationsStatus data;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: .035),
          border: Border.all(color: data.color.withValues(alpha: .10)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: data.color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(data.icon, color: data.color, size: 19)),
          const Spacer(),
          Text(data.value,
              style: TextStyle(
                  color: data.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          const SizedBox(height: 2),
          Text(data.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, height: 1.15)),
        ]),
      );
}

class _OperationShortcut extends StatelessWidget {
  const _OperationShortcut(
      {required this.item, required this.color, required this.onTap});
  final _OperationItem item;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CarmelitaCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(children: [
          Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .075),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(item.icon, color: color, size: 17)),
          const SizedBox(width: 7),
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 1),
                Text(item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 10)),
              ])),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: Theme.of(context).colorScheme.outline),
        ]),
      );
}

class _OperationItem {
  const _OperationItem(
    this.title,
    this.subtitle,
    this.icon,
    this.page, {
    this.ownerOnly = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
  final bool ownerOnly;
}

class LegacyRoomMonitoringPage extends StatelessWidget {
  const LegacyRoomMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Room monitoring',
      subtitle: 'Visual vacant/occupied room board',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveGrid(
              children: [
                MetricCard(
                  label: 'Occupied beds',
                  value: '${controller.occupiedBeds}',
                  detail: 'of ${controller.totalCapacity} total',
                  icon: Icons.bed_outlined,
                ),
                MetricCard(
                  label: 'Available beds',
                  value:
                      '${controller.totalCapacity - controller.occupiedBeds}',
                  detail: 'Across all rooms',
                  icon: Icons.event_available_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            AdaptiveGrid(
              minTileWidth: 220,
              children: controller.rooms
                  .map(
                    (room) => CarmelitaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LinearProgressIndicator(
                              value: room.occupied / room.capacity),
                          const SizedBox(height: 12),
                          Text(
                            'Room ${room.roomNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(room.floor),
                          const SizedBox(height: 4),
                          Text(
                            '${room.occupied}/${room.capacity} occupied • '
                            '${room.available} available',
                          ),
                          const SizedBox(height: 8),
                          StatusPill(
                            room.available == 0 ? 'Full' : 'Available',
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentVerificationPage extends StatefulWidget {
  const PaymentVerificationPage({super.key});

  @override
  State<PaymentVerificationPage> createState() =>
      _PaymentVerificationPageState();
}

class _PaymentVerificationPageState extends State<PaymentVerificationPage> {
  String _filter =
      'pending'; // 'pending', 'due', 'overdue', 'verified', 'rejected', 'all'
  late final TableRefreshSubscription _subscription;
  String? _processingPaymentId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OwnerController.instance.loadPayments();
        OwnerController.instance.loadTenants();
      }
    });

    _subscription = TableRefreshSubscription(
      'owner-payment-verification',
      ['payments'],
      () {
        if (mounted) {
          OwnerController.instance.loadPayments(force: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateInvoiceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const UtilityChargeCartDialog(),
    );
  }

  Future<void> _handleVerify(Payment payment, bool approve,
      {String? notes}) async {
    setState(() => _processingPaymentId = payment.id);
    try {
      await OwnerController.instance.verifyPayment(
        payment,
        approve,
        notes: notes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Payment of ${money(payment.amount)} from ${payment.tenantName ?? "tenant"} verified.'
                : 'Payment marked as rejected.',
          ),
          backgroundColor:
              approve ? const Color(0xFF56886B) : const Color(0xFFB3261E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update payment: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingPaymentId = null);
      }
    }
  }

  void _promptRejectDialog(Payment payment) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => _RejectReasonSheet(
        payment: payment,
        onConfirmReject: (reason) {
          Navigator.of(bottomSheetContext).pop();
          _handleVerify(payment, false, notes: reason);
        },
      ),
    );
  }

  void _openReceiptViewer(Payment payment, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ReceiptViewerModal(
          payment: payment,
          imageUrl: imageUrl,
          onConfirm: () => _handleVerify(payment, true),
          onReject: () => _promptRejectDialog(payment),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Payment review',
      subtitle: 'Inspect tenant receipts, issue invoices, and verify balances',
      onRefresh: () => OwnerController.instance.loadPayments(force: true),
      actions: [
        IconButton(
          tooltip: 'Refresh payments',
          icon: controller.paymentsLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          onPressed: controller.paymentsLoading
              ? null
              : () => controller.loadPayments(force: true),
        ),
      ],
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final allPayments = controller.payments;
          final pendingCount = controller.pendingPaymentProofs;
          final overdueCount = controller.overduePaymentCount;
          final verifiedCount = allPayments.where((p) => p.isVerified).length;
          final dueCount =
              allPayments.where((p) => p.isDue && !p.isOverdue).length;
          final rejectedCount = allPayments.where((p) => p.isRejected).length;

          final totalCollected = controller.totalCollectedRevenue;
          final totalOutstanding = controller.totalOutstandingRevenue;

          final dashboardItems = [
            MutedDashboardItem(
              label: 'Pending review',
              value: '$pendingCount',
              detail: pendingCount > 0 ? 'Needs staff action' : 'All clear',
              icon: Icons.pending_actions_rounded,
              color: const Color(0xFFAA8A45),
              onTap: () => setState(() => _filter = 'pending'),
            ),
            MutedDashboardItem(
              label: 'Collected',
              value: money(totalCollected),
              detail: '$verifiedCount verified',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF56886B),
              onTap: () => setState(() => _filter = 'verified'),
            ),
            MutedDashboardItem(
              label: 'Outstanding',
              value: money(totalOutstanding),
              detail: '${dueCount + pendingCount + overdueCount} uncollected',
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF8C7355),
              onTap: () => setState(() => _filter = 'due'),
            ),
            MutedDashboardItem(
              label: 'Overdue',
              value: '$overdueCount',
              detail: overdueCount > 0 ? 'Urgent attention' : 'None overdue',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFB3261E),
              onTap: () => setState(() => _filter = 'overdue'),
            ),
          ];

          final filteredByTab = switch (_filter) {
            'pending' => allPayments.where((p) => p.isPending).toList(),
            'due' => allPayments.where((p) => p.isDue && !p.isOverdue).toList(),
            'overdue' => allPayments.where((p) => p.isOverdue).toList(),
            'verified' => allPayments.where((p) => p.isVerified).toList(),
            'rejected' => allPayments.where((p) => p.isRejected).toList(),
            _ => allPayments,
          };

          final displayed = _searchQuery.trim().isEmpty
              ? filteredByTab
              : filteredByTab.where((p) {
                  final q = _searchQuery.trim().toLowerCase();
                  return (p.tenantName?.toLowerCase().contains(q) ?? false) ||
                      (p.tenantRoom?.toLowerCase().contains(q) ?? false) ||
                      p.label.toLowerCase().contains(q) ||
                      p.category.toLowerCase().contains(q) ||
                      (p.reference?.toLowerCase().contains(q) ?? false) ||
                      (p.paymentMethod?.toLowerCase().contains(q) ?? false);
                }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const _RentOverrideDialog(),
                    ),
                    icon: const Icon(Icons.price_change_outlined),
                    label: const Text('Override future rent'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openCreateInvoiceDialog(context),
                    icon: const Icon(Icons.add_card_rounded),
                    label: const Text('Add utility charge'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Financial Summary Metrics
              MutedDashboardGrid(items: dashboardItems),
              const SizedBox(height: 16),

              // Search Input
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by resident, room, title, or ref...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: .35),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color:
                          Theme.of(context).dividerColor.withValues(alpha: .2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color:
                          Theme.of(context).dividerColor.withValues(alpha: .2),
                    ),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 14),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Pending ($pendingCount)',
                      selected: _filter == 'pending',
                      badgeColor: const Color(0xFFAA8A45),
                      onTap: () => setState(() => _filter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Due ($dueCount)',
                      selected: _filter == 'due',
                      badgeColor: const Color(0xFF8C7355),
                      onTap: () => setState(() => _filter = 'due'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Overdue ($overdueCount)',
                      selected: _filter == 'overdue',
                      badgeColor: const Color(0xFFB3261E),
                      onTap: () => setState(() => _filter = 'overdue'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Verified ($verifiedCount)',
                      selected: _filter == 'verified',
                      badgeColor: const Color(0xFF56886B),
                      onTap: () => setState(() => _filter = 'verified'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Rejected ($rejectedCount)',
                      selected: _filter == 'rejected',
                      badgeColor: const Color(0xFFB3261E),
                      onTap: () => setState(() => _filter = 'rejected'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'All (${allPayments.length})',
                      selected: _filter == 'all',
                      badgeColor: Colors.grey,
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (controller.paymentsLoading && displayed.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (displayed.isEmpty)
                EmptyState(
                  icon: _filter == 'pending'
                      ? Icons.task_alt_outlined
                      : _filter == 'overdue'
                          ? Icons.check_circle_outline
                          : Icons.receipt_long_outlined,
                  title: _searchQuery.isNotEmpty
                      ? 'No matching payments'
                      : _filter == 'pending'
                          ? 'No pending reviews'
                          : _filter == 'overdue'
                              ? 'No overdue payments'
                              : 'No payments in this tab',
                  message: _searchQuery.isNotEmpty
                      ? 'Try searching with a different name, room, or reference.'
                      : _filter == 'pending'
                          ? 'All resident proof uploads have been reviewed and verified.'
                          : _filter == 'overdue'
                              ? 'All tenant balances are current and within terms.'
                              : 'Payments will appear here once submitted or updated.',
                )
              else
                ...displayed.map(
                  (payment) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PaymentReviewCard(
                      payment: payment,
                      isProcessing: _processingPaymentId == payment.id,
                      onOpenReceipt: (url) => _openReceiptViewer(payment, url),
                      onConfirm: () => _handleVerify(payment, true),
                      onReject: () => _promptRejectDialog(payment),
                      onReEvaluate: () => _handleVerify(
                        payment,
                        !payment.isVerified,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.badgeColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 32,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: .14)
              : isDark
                  ? const Color(0xFF28231F)
                  : const Color(0xFFF1EBE4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: .2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateInvoiceDialog extends StatefulWidget {
  const _CreateInvoiceDialog();

  @override
  State<_CreateInvoiceDialog> createState() => _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends State<_CreateInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedTenantId;
  String _selectedCategory = 'electricity';
  late final TextEditingController _titleController;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late DateTime _dueDate;
  late DateTime _periodStart;
  late DateTime _periodEnd;
  bool _isSubmitting = false;

  final List<String> _categories = const [
    'electricity',
    'water',
    'internet',
    'utility',
  ];

  @override
  void initState() {
    super.initState();
    final tenants = OwnerController.instance.tenants;
    _selectedTenantId = tenants.isNotEmpty ? tenants.first.id : 't1';
    _dueDate = DateTime.now().add(const Duration(days: 7));
    _periodStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _periodEnd = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
    _titleController =
        TextEditingController(text: _defaultTitleForCategory('electricity'));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _defaultTitleForCategory(String category) {
    return switch (category.toLowerCase()) {
      'electricity' => 'Electricity Utility Share',
      'water' => 'Water Utility Share',
      'internet' => 'WiFi Internet Fee',
      _ => 'Other Utility Charge',
    };
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickPeriodDate({required bool start}) async {
    final current = start ? _periodStart : _periodEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _periodStart = picked;
        if (_periodEnd.isBefore(picked)) _periodEnd = picked;
      } else {
        _periodEnd = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isSubmitting = true);
    try {
      await OwnerController.instance.createUtilityCharge(
        tenantId: _selectedTenantId,
        title: _titleController.text.trim(),
        category: _selectedCategory,
        amount: amount,
        dueDate: _dueDate,
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Utility charge for ${_titleController.text.trim()} issued successfully.'),
          backgroundColor: const Color(0xFF56886B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to issue utility charge: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenants = OwnerController.instance.tenants;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      actionsOverflowButtonSpacing: 8,
      actionsOverflowDirection: VerticalDirection.down,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded,
                color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Add Utility Charge',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedTenantId,
                  decoration: const InputDecoration(
                    labelText: 'Tenant / Resident',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  items: tenants.isNotEmpty
                      ? tenants.map((t) {
                          return DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              '${t.name} (${t.room})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList()
                      : const [
                          DropdownMenuItem(
                            value: 't1',
                            child: Text(
                              'Anna Dela Cruz (Room 204)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedTenantId = val);
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Rent is fixed by the active contract and cannot be entered here. Add only the tenant’s actual variable utility charge.',
                    style: TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Billing Category',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  items: _categories.map((c) {
                    final capitalized = c[0].toUpperCase() + c.substring(1);
                    return DropdownMenuItem(
                      value: c,
                      child: Text(
                        capitalized,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                        _titleController.text = _defaultTitleForCategory(val);
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Invoice Title / Description',
                    hintText: 'e.g. September Electricity',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide an invoice title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    prefixText: '₱ ',
                    prefixIcon: Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter an amount';
                    }
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Please enter a valid amount greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _UtilityPeriodField(
                  label: 'Billing period start',
                  value: _periodStart,
                  onTap: () => _pickPeriodDate(start: true),
                ),
                const SizedBox(height: 14),
                _UtilityPeriodField(
                  label: 'Billing period end',
                  value: _periodEnd,
                  onTap: () => _pickPeriodDate(start: false),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: .5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Due Date',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 11),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_dueDate.year}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Change',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Usage notes (optional)',
                    hintText: 'e.g. Higher electricity usage for September',
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: const Text('Add Utility Charge',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _UtilityPeriodField extends StatelessWidget {
  const _UtilityPeriodField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.date_range_outlined),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          child: Text(
            '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
}

class _RentOverrideDialog extends StatefulWidget {
  const _RentOverrideDialog();

  @override
  State<_RentOverrideDialog> createState() => _RentOverrideDialogState();
}

class _RentOverrideDialogState extends State<_RentOverrideDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  late String _tenantId;
  late DateTime _effectiveDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final tenants = OwnerController.instance.tenants;
    _tenantId = tenants.isNotEmpty ? tenants.first.id : '';
    final now = DateTime.now();
    _effectiveDate = DateTime(now.year, now.month + 1, 1);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) setState(() => _effectiveDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final count = await OwnerController.instance.applyRentRateOverride(
        tenantId: _tenantId,
        newMonthlyRent: double.parse(_amountController.text.trim()),
        effectiveDate: _effectiveDate,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Rent override applied to $count future charge${count == 1 ? '' : 's'}.',
        ),
      ));
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'Failed to override rent: $error');
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenants = OwnerController.instance.tenants;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Override Future Rent'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Increase or decrease unpaid future rent. Contract terms and historical charges remain unchanged.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _tenantId.isEmpty ? null : _tenantId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tenant / Resident',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: tenants
                      .map((tenant) => DropdownMenuItem(
                            value: tenant.id,
                            child: Text('${tenant.name} (${tenant.room})',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Select a tenant' : null,
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _tenantId = value);
                        },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'New monthly rent',
                    prefixText: '₱ ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || amount <= 0
                        ? 'Enter a valid rent amount'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                _UtilityPeriodField(
                  label: 'Effective date',
                  value: _effectiveDate,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Reason for increase or decrease',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  validator: (value) =>
                      (value?.trim().length ?? 0) < 3 ? 'Enter a reason' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Applying…' : 'Apply Override'),
        ),
      ],
    );
  }
}

IconData _paymentCategoryIcon(String category) =>
    switch (category.toLowerCase()) {
      'rent' => Icons.home_outlined,
      'electricity' => Icons.bolt_outlined,
      'water' => Icons.water_drop_outlined,
      'internet' => Icons.wifi_rounded,
      'maintenance' || 'maintenance fee' => Icons.build_outlined,
      'penalty' => Icons.warning_amber_rounded,
      _ => Icons.receipt_outlined,
    };

Color _paymentCategoryColor(String category) =>
    switch (category.toLowerCase()) {
      'rent' => const Color(0xFF1E88E5),
      'electricity' => const Color(0xFFF57C00),
      'water' => const Color(0xFF00ACC1),
      'internet' => const Color(0xFF8E24AA),
      'maintenance' || 'maintenance fee' => const Color(0xFFD84315),
      'penalty' => const Color(0xFFC62828),
      _ => const Color(0xFF757575),
    };

class _PaymentReviewCard extends StatelessWidget {
  const _PaymentReviewCard({
    required this.payment,
    required this.isProcessing,
    required this.onOpenReceipt,
    required this.onConfirm,
    required this.onReject,
    required this.onReEvaluate,
  });

  final Payment payment;
  final bool isProcessing;
  final ValueChanged<String> onOpenReceipt;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onReEvaluate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenantName = payment.tenantName ?? 'Tenant';
    final roomName = payment.tenantRoom ?? 'Room 204 • Bed 2';

    return CarmelitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tenant header & Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: .12),
                child: Text(
                  tenantName.isNotEmpty ? tenantName[0].toUpperCase() : 'T',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenantName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      roomName,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(payment.status),
                  if (payment.isOverdue) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB3261E).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFB3261E).withValues(alpha: .3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 11, color: Color(0xFFB3261E)),
                          SizedBox(width: 3),
                          Text(
                            'OVERDUE',
                            style: TextStyle(
                              color: Color(0xFFB3261E),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Payment details
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 320;

              final categoryBadge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _paymentCategoryColor(payment.category)
                      .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _paymentCategoryIcon(payment.category),
                      size: 12,
                      color: _paymentCategoryColor(payment.category),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        payment.category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _paymentCategoryColor(payment.category),
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              final amountText = FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  money(payment.amount),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              );

              final dueDateText = Text(
                'Due: ${_dateOrNone(payment.dueDate)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      payment.isOverdue ? FontWeight.w700 : FontWeight.w500,
                  color: payment.isOverdue
                      ? const Color(0xFFB3261E)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              categoryBadge,
                              if (payment.paymentMethod != null &&
                                  payment.paymentMethod!.isNotEmpty)
                                Text(
                                  '• ${payment.paymentMethod!}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: amountText),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      payment.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    dueDateText,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            categoryBadge,
                            if (payment.paymentMethod != null &&
                                payment.paymentMethod!.isNotEmpty)
                              Text(
                                '• ${payment.paymentMethod!}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          payment.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        dueDateText,
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: amountText),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Reference row with copy action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: .4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ref: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    payment.reference ?? 'Not specified',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (payment.reference != null && payment.reference!.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: payment.reference!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Reference number copied to clipboard.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // RECEIPT PROOF IMAGE SECTION
          _ReceiptProofThumbnail(
            receiptPath: payment.receiptPath,
            onTapFullscreen: onOpenReceipt,
          ),

          // Review Notes if rejected
          if (payment.reviewNotes != null &&
              payment.reviewNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: .3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejection reason: ${payment.reviewNotes}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ACTION BUTTONS
          if (payment.isPending)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 260;
                final rejectBtn = OutlinedButton.icon(
                  onPressed: isProcessing ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB3261E),
                    side: const BorderSide(color: Color(0xFFB3261E)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text(
                    'Reject',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
                final confirmBtn = FilledButton.icon(
                  onPressed: isProcessing ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF56886B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded,
                          size: 18),
                  label: const Text(
                    'Confirm',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      confirmBtn,
                      const SizedBox(height: 8),
                      rejectBtn,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: rejectBtn),
                    const SizedBox(width: 10),
                    Expanded(child: confirmBtn),
                  ],
                );
              },
            )
          else if (payment.isDue)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 280;
                final statusBanner = Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Awaiting tenant proof',
                          style:
                              theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
                final markPaidBtn = OutlinedButton.icon(
                  onPressed: isProcessing ? null : onConfirm,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                  label: const Text(
                    'Mark paid',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      statusBanner,
                      const SizedBox(height: 8),
                      markPaidBtn,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: statusBanner),
                    const SizedBox(width: 8),
                    markPaidBtn,
                  ],
                );
              },
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReEvaluate,
                icon: const Icon(Icons.sync_alt_rounded, size: 16),
                label: Text(
                  payment.isVerified ? 'Mark as rejected' : 'Re-verify payment',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReceiptProofThumbnail extends StatefulWidget {
  const _ReceiptProofThumbnail({
    required this.receiptPath,
    required this.onTapFullscreen,
  });

  final String? receiptPath;
  final ValueChanged<String> onTapFullscreen;

  @override
  State<_ReceiptProofThumbnail> createState() => _ReceiptProofThumbnailState();
}

class _ReceiptProofThumbnailState extends State<_ReceiptProofThumbnail> {
  String? _resolvedUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  @override
  void didUpdateWidget(covariant _ReceiptProofThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receiptPath != widget.receiptPath) {
      _resolveUrl();
    }
  }

  Future<void> _resolveUrl() async {
    final path = widget.receiptPath;
    if (path == null || path.isEmpty) {
      setState(() => _resolvedUrl = null);
      return;
    }

    setState(() => _loading = true);
    final url = await const PaymentService().createReceiptUrl(path);
    if (mounted) {
      setState(() {
        _resolvedUrl = url;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.receiptPath == null || widget.receiptPath!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: .25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: .3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No photo receipt attached (Reference provided)',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: .3),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final url = _resolvedUrl;
    if (url == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.broken_image_outlined,
                size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Receipt photo unavailable or expired.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isAsset = url.startsWith('assets/');

    return InkWell(
      onTap: () => widget.onTapFullscreen(url),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: .4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isAsset)
                Image.asset(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 36),
                  ),
                )
              else
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 36),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              // Bottom gradient inspection banner
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black87,
                      ],
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.zoom_in_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Tap to inspect receipt full screen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptViewerModal extends StatelessWidget {
  const _ReceiptViewerModal({
    required this.payment,
    required this.imageUrl,
    required this.onConfirm,
    required this.onReject,
  });

  final Payment payment;
  final String imageUrl;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isAsset = imageUrl.startsWith('assets/');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: .85),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${payment.tenantName ?? "Tenant"} - Receipt Proof',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${payment.label} • Submitted ${money(payment.submittedAmount ?? payment.amount)} • Bill ${money(payment.amount)} • Ref: ${payment.reference ?? "—"}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Center(
                  child: isAsset
                      ? Image.asset(imageUrl)
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_outlined,
                                    color: Colors.white70, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Receipt image could not be displayed. Close and try again.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (payment.isPending)
              Container(
                color: Colors.black.withValues(alpha: .9),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final rejectBtn = OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onReject();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF8A80),
                        side: const BorderSide(color: Color(0xFFFF8A80)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text(
                        'Reject',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                    final confirmBtn = FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onConfirm();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF56886B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded,
                          size: 18),
                      label: const Text(
                        'Confirm',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );

                    if (constraints.maxWidth < 280) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          confirmBtn,
                          const SizedBox(height: 8),
                          rejectBtn,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: rejectBtn),
                        const SizedBox(width: 12),
                        Expanded(child: confirmBtn),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RejectReasonSheet extends StatefulWidget {
  const _RejectReasonSheet({
    required this.payment,
    required this.onConfirmReject,
  });

  final Payment payment;
  final ValueChanged<String> onConfirmReject;

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  final TextEditingController _notesController = TextEditingController();
  String _selectedReason = 'Screenshot is blurred or unreadable';

  final List<String> _quickReasons = const [
    'Screenshot is blurred or unreadable',
    'Reference number not found in GCash/Bank records',
    'Amount paid is less than invoice amount',
    'Sent to wrong account name/number',
    'Duplicate payment receipt',
    'Other reason (details below)',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3261E).withValues(alpha: .1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel_outlined,
                      color: Color(0xFFB3261E), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reject Payment Proof',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      Text(
                        'Tenant will be notified to correct and re-upload.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Select rejection reason:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ..._quickReasons.map(
              (reason) {
                final isSelected = _selectedReason == reason;
                return InkWell(
                  onTap: () => setState(() => _selectedReason = reason),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 18,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Additional remarks / instructions for tenant...',
                labelText: 'Remarks (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final cancelBtn = OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                );
                final confirmBtn = FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB3261E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final extra = _notesController.text.trim();
                    final fullReason = extra.isNotEmpty
                        ? '$_selectedReason: $extra'
                        : _selectedReason;
                    widget.onConfirmReject(fullReason);
                  },
                  child: const Text('Confirm Rejection'),
                );

                if (constraints.maxWidth < 280) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      confirmBtn,
                      const SizedBox(height: 8),
                      cancelBtn,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: cancelBtn),
                    const SizedBox(width: 10),
                    Expanded(child: confirmBtn),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ReportManagementPage extends StatelessWidget {
  const ReportManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isOwner =
        SessionController.instance.currentUser?.role == UserRole.owner;

    return PageFrame(
      title: 'Report management',
      subtitle: 'Review reporting workflows from one place',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Reporting queues',
            subtitle: 'Access remains limited by staff role and report type',
          ),
          const SizedBox(height: 12),
          _reportQueue(
            context,
            title: 'Maintenance reports',
            subtitle: 'Triage repair requests, assignments, and resolutions.',
            icon: Icons.build_outlined,
            color: const Color(0xFFB47A52),
            page: const MaintenanceManagementPage(),
          ),
          if (isOwner) ...[
            const SizedBox(height: 12),
            _reportQueue(
              context,
              title: 'Confidential reports',
              subtitle:
                  'Review restricted safety, rules, and roommate concerns.',
              icon: Icons.shield_outlined,
              color: const Color(0xFF7D70A0),
              page: const ConfidentialReportsPage(),
            ),
          ],
          const SizedBox(height: 12),
          _reportQueue(
            context,
            title: 'Cleaning compliance reports',
            subtitle: 'Select a room to review private missed-duty reports.',
            icon: Icons.cleaning_services_outlined,
            color: const Color(0xFF56886B),
            page: const RoomMonitoringPage(),
          ),
        ],
      ),
    );
  }

  Widget _reportQueue(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget page,
  }) {
    return CarmelitaCard(
      onTap: () => _ownerPush(context, page),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class MaintenanceManagementPage extends StatelessWidget {
  const MaintenanceManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaffMaintenancePage();
  }
}

class FloorPlanMonitoringPage extends StatelessWidget {
  const FloorPlanMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageFrame(
      title: 'Floor plan monitoring',
      subtitle: 'Maintenance concerns by location',
      child: FloorPlanCanvas(monitorMode: true),
    );
  }
}

class GeofenceMonitoringPage extends StatefulWidget {
  const GeofenceMonitoringPage({super.key});

  @override
  State<GeofenceMonitoringPage> createState() => _GeofenceMonitoringPageState();
}

class _GeofenceMonitoringPageState extends State<GeofenceMonitoringPage> {
  String _presenceFilter = 'all';
  bool _showTestPanel = false;

  @override
  void initState() {
    super.initState();
    OwnerController.instance.loadGateEvents();
    OwnerController.instance.loadTenants();
    const BoundaryConfigService().loadActiveConfig();
  }

  void _openManualLogDialog({TenantDirectoryEntry? preselected}) {
    showDialog(
      context: context,
      builder: (_) => _StaffManualLogDialog(preselectedTenant: preselected),
    );
  }

  void _openBoundaryEditor() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _EditBoundaryDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;
    final isOwner =
        SessionController.instance.currentUser?.role == UserRole.owner;

    return PageFrame(
      title: 'Curfew',
      subtitle: 'Automatic dormitory entry and exit records',
      maxWidth: 780,
      actions: [
        IconButton(
          tooltip: 'Refresh presence & events',
          icon: controller.gateLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          onPressed: controller.gateLoading
              ? null
              : () {
                  controller.loadGateEvents(force: true);
                  controller.loadTenants(force: true);
                  const BoundaryConfigService().loadActiveConfig();
                },
        ),
        PopupMenuButton<String>(
          tooltip: 'Perimeter & logging options',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            if (value == 'dev_dashboard') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GeofenceDevDashboardPage(),
                ),
              );
            } else if (value == 'staff_log') {
              _openManualLogDialog();
            } else if (value == 'edit_boundary') {
              _openBoundaryEditor();
            } else if (value == 'test_panel') {
              setState(() => _showTestPanel = !_showTestPanel);
            }
          },
          itemBuilder: (_) => [
            if (isOwner) ...[
              const PopupMenuItem(
                value: 'edit_boundary',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune_rounded),
                  title: Text('Edit Boundary Config'),
                ),
              ),
              const PopupMenuItem(
                value: 'test_panel',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.science_outlined),
                  title: Text('Location Test Panel'),
                ),
              ),
              const PopupMenuItem(
                value: 'dev_dashboard',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.map_outlined),
                  title: Text('Perimeter Visualizer'),
                ),
              ),
            ],
            const PopupMenuItem(
              value: 'staff_log',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_note_rounded),
                title: Text('Staff Manual Log'),
              ),
            ),
          ],
        ),
      ],
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final allTenants = controller.tenants;
          final filteredTenants = allTenants.where((t) {
            switch (_presenceFilter) {
              case 'in':
                return t.isInside;
              case 'out':
                return t.isOutside;
              case 'unavailable':
                return t.isUnavailable;
              default:
                return true;
            }
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkInProgressNotice(),
              const SizedBox(height: 16),
              // ── Owner-only Location Test Panel ───────────────────────
              if (isOwner && _showTestPanel) ...[
                _LocationTestPanel(tenants: allTenants),
                const SizedBox(height: 16),
              ],
              AdaptiveGrid(
                children: [
                  MetricCard(
                    label: 'Last event: IN',
                    value: '${controller.tenantsInsideCount}',
                    detail: 'Latest recorded crossing was entry',
                    icon: Icons.home_outlined,
                  ),
                  MetricCard(
                    label: 'Last event: OUT',
                    value: '${controller.tenantsOutsideCount}',
                    detail: 'Latest recorded crossing was exit',
                    icon: Icons.directions_walk_outlined,
                  ),
                  MetricCard(
                    label: 'Unavailable',
                    value: '${controller.tenantsUnavailableCount}',
                    detail: 'GPS disabled or no signal',
                    icon: Icons.location_off_outlined,
                  ),
                  const MetricCard(
                    label: 'Dormitory perimeter',
                    value: 'Polygon Lot',
                    detail: '4 Measured Corners (Baliwag)',
                    icon: Icons.polyline_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 420;
                  if (isCompact) {
                    return Column(
                      children: [
                        if (isOwner) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const GeofenceDevDashboardPage(),
                                ),
                              ),
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('View Perimeter Map & Overlay'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _openManualLogDialog(),
                            icon: const Icon(Icons.edit_note_rounded, size: 18),
                            label: const Text('Staff Manual Log'),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      if (isOwner) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const GeofenceDevDashboardPage(),
                              ),
                            ),
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('View Perimeter Map & Overlay'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openManualLogDialog(),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Staff Manual Log'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              const SectionTitle(
                'Last recorded crossing by resident',
                subtitle:
                    'Tripwire history is supporting evidence, not live tracking',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'All (${allTenants.length})',
                    selected: _presenceFilter == 'all',
                    badgeColor: const Color(0xFF627FA8),
                    onTap: () => setState(() => _presenceFilter = 'all'),
                  ),
                  _FilterChip(
                    label: 'Inside (${controller.tenantsInsideCount})',
                    selected: _presenceFilter == 'in',
                    badgeColor: const Color(0xFF56886B),
                    onTap: () => setState(() => _presenceFilter = 'in'),
                  ),
                  _FilterChip(
                    label: 'Outside (${controller.tenantsOutsideCount})',
                    selected: _presenceFilter == 'out',
                    badgeColor: const Color(0xFF627FA8),
                    onTap: () => setState(() => _presenceFilter = 'out'),
                  ),
                  _FilterChip(
                    label:
                        'Unavailable (${controller.tenantsUnavailableCount})',
                    selected: _presenceFilter == 'unavailable',
                    badgeColor: const Color(0xFFC77800),
                    onTap: () =>
                        setState(() => _presenceFilter = 'unavailable'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredTenants.isEmpty)
                const EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'No residents match filter',
                  message: 'No residents found with this presence status.',
                )
              else
                ...filteredTenants.map(
                  (tenant) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CarmelitaCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: tenant.isInside
                                ? const Color(0x1556886B)
                                : (tenant.isOutside
                                    ? const Color(0x15627FA8)
                                    : const Color(0x15C77800)),
                            foregroundColor: tenant.isInside
                                ? const Color(0xFF56886B)
                                : (tenant.isOutside
                                    ? const Color(0xFF627FA8)
                                    : const Color(0xFFC77800)),
                            child: Icon(
                              tenant.isInside
                                  ? Icons.home_rounded
                                  : (tenant.isOutside
                                      ? Icons.directions_walk_rounded
                                      : Icons.location_off_rounded),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tenant.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Room ${tenant.room} • ${tenant.bedSpace}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          StatusPill(
                            tenant.isInside
                                ? 'Inside'
                                : (tenant.isOutside
                                    ? 'Outside'
                                    : 'Unavailable'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Log observed entry/exit',
                            icon: const Icon(Icons.edit_note_rounded, size: 20),
                            onPressed: () =>
                                _openManualLogDialog(preselected: tenant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              const SectionTitle(
                'Recent presence events',
                subtitle:
                    'Automated discrete transition logs (data-minimization compliant)',
              ),
              const SizedBox(height: 10),
              if (controller.gateEvents.isEmpty)
                const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No recent presence events',
                  message:
                      'Discrete entry, exit, and manual logs will appear here.',
                )
              else
                ...controller.gateEvents.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CarmelitaCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: TimelineTile(
                        compact: true,
                        icon: event.direction == 'IN'
                            ? Icons.login_rounded
                            : (event.direction == 'OUT'
                                ? Icons.logout_rounded
                                : Icons.location_off_rounded),
                        color: event.direction == 'IN'
                            ? const Color(0xFF56886B)
                            : (event.direction == 'OUT'
                                ? const Color(0xFF627FA8)
                                : const Color(0xFFC77800)),
                        title:
                            '${event.person} • ${event.isUnavailable ? 'Presence unavailable' : (event.direction == 'IN' ? 'Entered perimeter' : 'Exited perimeter')}',
                        subtitle:
                            '${shortDate(event.time)} • ${timeText(event.time)} • ${event.verificationMethod}${event.notes != null && event.notes!.isNotEmpty ? ' • "${event.notes}"' : ''}',
                        trailing: StatusPill(event.status),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StaffManualLogDialog extends StatefulWidget {
  const _StaffManualLogDialog({this.preselectedTenant});

  final TenantDirectoryEntry? preselectedTenant;

  @override
  State<_StaffManualLogDialog> createState() => _StaffManualLogDialogState();
}

class _StaffManualLogDialogState extends State<_StaffManualLogDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  TenantDirectoryEntry? _selectedTenant;
  String _direction = 'IN';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final tenants = OwnerController.instance.tenants;
    if (widget.preselectedTenant != null) {
      _selectedTenant = widget.preselectedTenant;
    } else if (tenants.isNotEmpty) {
      _selectedTenant = tenants.first;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenant == null) return;

    setState(() => _submitting = true);

    try {
      await OwnerController.instance.recordStaffManualLog(
        tenantId: _selectedTenant!.id,
        direction: _direction,
        notes: _notesController.text.trim(),
        tenantName: _selectedTenant!.name,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded manual $_direction log for ${_selectedTenant!.name}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record staff manual log: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenants = OwnerController.instance.tenants;

    return AlertDialog(
      title: const Text('Staff Manual Log'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log a directly observed resident entry or exit to resolve an unavailable status gap. Mandatory observation notes are required for auditing.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TenantDirectoryEntry>(
                initialValue: _selectedTenant,
                decoration: const InputDecoration(
                  labelText: 'Select Tenant',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: tenants.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text('${t.name} (Rm ${t.room})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedTenant = val),
              ),
              const SizedBox(height: 16),
              const Text(
                'Observed Direction',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'IN',
                    label: Text('IN (Entry)'),
                    icon: Icon(Icons.login_rounded),
                  ),
                  ButtonSegment(
                    value: 'OUT',
                    label: Text('OUT (Exit)'),
                    icon: Icon(Icons.logout_rounded),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (set) =>
                    setState(() => _direction = set.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observation Notes *',
                  hintText:
                      'e.g. Directly observed arriving on the premises; phone drained.',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Observation notes are mandatory for staff manual log.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit Log'),
        ),
      ],
    );
  }
}

typedef GateMonitoringPage = GeofenceMonitoringPage;
typedef CurfewMonitoringPage = GeofenceMonitoringPage;
typedef CurfewRequestReviewPage = GeofenceMonitoringPage;

// ─────────────────────────────────────────────────────────────────────────────
// Location Test Panel — evaluates arbitrary coordinates against the active
// boundary configuration without writing any coordinate data to the database.
// The "Simulate Crossing" action fires the real gate_events / notification
// pipeline using the evaluated IN/OUT direction.
// ─────────────────────────────────────────────────────────────────────────────

class _LocationTestPanel extends StatefulWidget {
  const _LocationTestPanel({required this.tenants});

  final List<TenantDirectoryEntry> tenants;

  @override
  State<_LocationTestPanel> createState() => _LocationTestPanelState();
}

class _LocationTestPanelState extends State<_LocationTestPanel> {
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  bool _evaluating = false;
  bool _simulating = false;
  bool _fetchingGps = false;

  // Live evaluation result — null until Evaluate is tapped.
  String? _evalDirection;   // 'IN' or 'OUT'
  double? _evalDistMeters;  // metres from nearest edge

  TenantDirectoryEntry? _selectedTenant;

  @override
  void initState() {
    super.initState();
    if (widget.tenants.isNotEmpty) _selectedTenant = widget.tenants.first;
    _latCtrl.addListener(_clearResult);
    _lngCtrl.addListener(_clearResult);
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _clearResult() => setState(() {
        _evalDirection = null;
        _evalDistMeters = null;
      });

  double? get _lat => double.tryParse(_latCtrl.text.trim());
  double? get _lng => double.tryParse(_lngCtrl.text.trim());

  Future<void> _fetchGps() async {
    setState(() => _fetchingGps = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission not granted.')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _latCtrl.text = pos.latitude.toStringAsFixed(8);
      _lngCtrl.text = pos.longitude.toStringAsFixed(8);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  void _setPreset(double lat, double lng, String label) {
    _latCtrl.text = lat.toStringAsFixed(8);
    _lngCtrl.text = lng.toStringAsFixed(8);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Preset loaded: $label'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _evaluate() async {
    final lat = _lat;
    final lng = _lng;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid latitude and longitude.')),
      );
      return;
    }
    setState(() => _evaluating = true);
    try {
      final result = GeofenceLocationService.evaluateCoordinates(
        latitude: lat,
        longitude: lng,
      );
      final dist = _distToEdge(lat, lng);
      setState(() {
        _evalDirection = result.direction;
        _evalDistMeters = dist;
      });
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  /// Approximate distance from point to the polygon centroid edge.
  double _distToEdge(double lat, double lng) {
    final polygon = GeofenceLocationService.activePolygon;
    if (polygon.isEmpty) return 0;
    // Use centroid distance as a rough indication.
    double sumLat = 0, sumLng = 0;
    for (final p in polygon) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    final cLat = sumLat / polygon.length;
    final cLng = sumLng / polygon.length;
    final dist = Geolocator.distanceBetween(lat, lng, cLat, cLng);
    return dist;
  }

  Future<void> _simulate() async {
    final lat = _lat;
    final lng = _lng;
    final tenant = _selectedTenant;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter coordinates first.')),
      );
      return;
    }
    if (tenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a tenant to simulate for.')),
      );
      return;
    }

    // Evaluate direction for the entered coordinates.
    final result = GeofenceLocationService.evaluateCoordinates(
      latitude: lat,
      longitude: lng,
    );
    final direction = result.direction ?? 'OUT';

    setState(() => _simulating = true);
    try {
      await OwnerController.instance.recordStaffManualLog(
        tenantId: tenant.id,
        direction: direction,
        notes: 'Location test simulation from owner panel '
            '($direction at ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})',
        tenantName: tenant.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Simulated $direction crossing recorded for ${tenant.name}',
            ),
          ),
        );
        setState(() {
          _evalDirection = direction;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulation failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIn = _evalDirection == 'IN';
    final hasResult = _evalDirection != null;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: scheme.outlineVariant,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Icon(Icons.science_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Test Panel',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Owner only • no coordinates stored',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20, indent: 14, endIndent: 14),

          // Coordinate inputs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '14.949402',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lngCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: '120.884676',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Preset + GPS buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: _fetchingGps
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 14),
                  label: const Text('My GPS'),
                  onPressed: _fetchingGps ? null : _fetchGps,
                  visualDensity: VisualDensity.compact,
                ),
                ActionChip(
                  avatar: const Icon(Icons.home_outlined, size: 14),
                  label: const Text('Dorm Center'),
                  onPressed: () => _setPreset(
                    GeofenceLocationService.carmelitaLatitude,
                    GeofenceLocationService.carmelitaLongitude,
                    'Dorm Center',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                ActionChip(
                  avatar: const Icon(Icons.directions_walk_rounded, size: 14),
                  label: const Text('50 m Outside'),
                  onPressed: () => _setPreset(
                    GeofenceLocationService.carmelitaLatitude + 0.00045,
                    GeofenceLocationService.carmelitaLongitude,
                    '50 m Outside (north)',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                ActionChip(
                  avatar: const Icon(Icons.location_on_outlined, size: 14),
                  label: const Text('Active Center'),
                  onPressed: () {
                    final poly = GeofenceLocationService.activePolygon;
                    if (poly.isEmpty) return;
                    double sLat = 0, sLng = 0;
                    for (final p in poly) {
                      sLat += p.latitude;
                      sLng += p.longitude;
                    }
                    _setPreset(
                      sLat / poly.length,
                      sLng / poly.length,
                      'Active polygon centroid',
                    );
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Evaluate button + result (Wrap prevents right-side overflow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _evaluating ? null : _evaluate,
                  icon: _evaluating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Evaluate'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (hasResult)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIn
                          ? const Color(0xFF56886B).withValues(alpha: 0.15)
                          : const Color(0xFFB03A2E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isIn
                            ? const Color(0xFF56886B)
                            : const Color(0xFFB03A2E),
                      ),
                    ),
                    child: Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          isIn ? Icons.home_rounded : Icons.directions_walk_rounded,
                          size: 14,
                          color: isIn
                              ? const Color(0xFF56886B)
                              : const Color(0xFFB03A2E),
                        ),
                        Text(
                          _evalDirection!,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isIn
                                ? const Color(0xFF56886B)
                                : const Color(0xFFB03A2E),
                            fontSize: 13,
                          ),
                        ),
                        if (_evalDistMeters != null)
                          Text(
                            '≈ ${_evalDistMeters!.toStringAsFixed(0)} m from centroid',
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Simulate Crossing section
          const Divider(height: 20, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Simulate Crossing',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Creates a real gate_events record for the selected tenant '
                  'using the evaluated direction — useful for testing push '
                  'notifications and curfew alerts end-to-end.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 340;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<TenantDirectoryEntry>(
                            initialValue: _selectedTenant,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tenant',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                            items: widget.tenants.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(
                                  '${t.name} (Rm ${t.room})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedTenant = val),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _simulating ? null : _simulate,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF627FA8),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: _simulating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.play_circle_outline, size: 16),
                            label: const Text('Simulate'),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<TenantDirectoryEntry>(
                            initialValue: _selectedTenant,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tenant',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                            items: widget.tenants.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(
                                  '${t.name} (Rm ${t.room})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedTenant = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _simulating ? null : _simulate,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF627FA8),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: _simulating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.play_circle_outline, size: 16),
                          label: const Text('Simulate'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Boundary Editor Dialog — lets owners update the active dorm boundary saved
// in Supabase.  Changes take effect immediately in the in-memory geofence
// state; the native tripwire is re-registered on the next app resume.
// ─────────────────────────────────────────────────────────────────────────────

class _EditBoundaryDialog extends StatefulWidget {
  const _EditBoundaryDialog();

  @override
  State<_EditBoundaryDialog> createState() => _EditBoundaryDialogState();
}

class _EditBoundaryDialogState extends State<_EditBoundaryDialog> {
  final _service = const BoundaryConfigService();

  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _bufferCtrl = TextEditingController();

  // 4 Polygon corner coordinate controllers
  final _p1LatCtrl = TextEditingController();
  final _p1LngCtrl = TextEditingController();
  final _p2LatCtrl = TextEditingController();
  final _p2LngCtrl = TextEditingController();
  final _p3LatCtrl = TextEditingController();
  final _p3LngCtrl = TextEditingController();
  final _p4LatCtrl = TextEditingController();
  final _p4LngCtrl = TextEditingController();

  String _mode = 'polygon';
  bool _loading = true;
  bool _saving = false;
  bool _fetchingGps = false;

  BoundarySnapshot? _current;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    _bufferCtrl.dispose();
    _p1LatCtrl.dispose();
    _p1LngCtrl.dispose();
    _p2LatCtrl.dispose();
    _p2LngCtrl.dispose();
    _p3LatCtrl.dispose();
    _p3LngCtrl.dispose();
    _p4LatCtrl.dispose();
    _p4LngCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    setState(() => _loading = true);
    try {
      final row = await _service.loadActiveConfig();
      if (row != null) {
        final snap = BoundaryConfigService.configFromRow(row);
        _current = snap;
        _latCtrl.text = snap.centerLat.toStringAsFixed(8);
        _lngCtrl.text = snap.centerLng.toStringAsFixed(8);
        _radiusCtrl.text = snap.radiusMeters.toStringAsFixed(1);
        _bufferCtrl.text = snap.edgeBufferMeters.toStringAsFixed(1);
        _mode = snap.boundaryMode;
        _populatePolygonCorners(snap.polygonPoints);
      } else {
        // Fallback to compiled-in defaults
        _latCtrl.text =
            GeofenceLocationService.carmelitaLatitude.toStringAsFixed(8);
        _lngCtrl.text =
            GeofenceLocationService.carmelitaLongitude.toStringAsFixed(8);
        _radiusCtrl.text =
            GeofenceLocationService.geofenceRadiusMeters.toStringAsFixed(1);
        _bufferCtrl.text =
            GeofenceLocationService.debounceBufferMeters.toStringAsFixed(1);
        _mode = 'polygon';
        _populatePolygonCorners(GeofenceLocationService.productionDormitoryPolygon);
      }
    } catch (_) {
      // If load fails, show defaults
      _latCtrl.text =
          GeofenceLocationService.carmelitaLatitude.toStringAsFixed(8);
      _lngCtrl.text =
          GeofenceLocationService.carmelitaLongitude.toStringAsFixed(8);
      _radiusCtrl.text =
          GeofenceLocationService.geofenceRadiusMeters.toStringAsFixed(1);
      _bufferCtrl.text =
          GeofenceLocationService.debounceBufferMeters.toStringAsFixed(1);
      _populatePolygonCorners(GeofenceLocationService.productionDormitoryPolygon);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populatePolygonCorners(List<LatLngPoint> points) {
    final list = points.isNotEmpty
        ? points
        : GeofenceLocationService.productionDormitoryPolygon;
    if (list.isNotEmpty) {
      _p1LatCtrl.text = list[0].latitude.toStringAsFixed(8);
      _p1LngCtrl.text = list[0].longitude.toStringAsFixed(8);
    }
    if (list.length > 1) {
      _p2LatCtrl.text = list[1].latitude.toStringAsFixed(8);
      _p2LngCtrl.text = list[1].longitude.toStringAsFixed(8);
    }
    if (list.length > 2) {
      _p3LatCtrl.text = list[2].latitude.toStringAsFixed(8);
      _p3LngCtrl.text = list[2].longitude.toStringAsFixed(8);
    }
    if (list.length > 3) {
      _p4LatCtrl.text = list[3].latitude.toStringAsFixed(8);
      _p4LngCtrl.text = list[3].longitude.toStringAsFixed(8);
    }
  }

  void _autoCalculateCorners() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    final radius = double.tryParse(_radiusCtrl.text.trim()) ?? 50.0;
    if (lat == null || lng == null) return;
    final r = radius / 111000;
    _p1LatCtrl.text = (lat + r).toStringAsFixed(8);
    _p1LngCtrl.text = (lng + r).toStringAsFixed(8);
    _p2LatCtrl.text = (lat - r).toStringAsFixed(8);
    _p2LngCtrl.text = (lng + r).toStringAsFixed(8);
    _p3LatCtrl.text = (lat - r).toStringAsFixed(8);
    _p3LngCtrl.text = (lng - r).toStringAsFixed(8);
    _p4LatCtrl.text = (lat + r).toStringAsFixed(8);
    _p4LngCtrl.text = (lng - r).toStringAsFixed(8);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto-calculated 4 corners around center.'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _captureGps() async {
    setState(() => _fetchingGps = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission not granted.')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        _latCtrl.text = pos.latitude.toStringAsFixed(8);
        _lngCtrl.text = pos.longitude.toStringAsFixed(8);
        _autoCalculateCorners();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Center and 4 corners set to your GPS: '
              '${pos.latitude.toStringAsFixed(5)}, '
              '${pos.longitude.toStringAsFixed(5)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  Future<void> _save() async {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    final radius = double.tryParse(_radiusCtrl.text.trim());
    final buffer = double.tryParse(_bufferCtrl.text.trim());

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid latitude and longitude.')),
      );
      return;
    }
    if (radius != null && radius < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radius must be at least 10 metres.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      List<LatLngPoint>? newPolygon;
      if (_mode == 'polygon') {
        final p1Lat = double.tryParse(_p1LatCtrl.text.trim());
        final p1Lng = double.tryParse(_p1LngCtrl.text.trim());
        final p2Lat = double.tryParse(_p2LatCtrl.text.trim());
        final p2Lng = double.tryParse(_p2LngCtrl.text.trim());
        final p3Lat = double.tryParse(_p3LatCtrl.text.trim());
        final p3Lng = double.tryParse(_p3LngCtrl.text.trim());
        final p4Lat = double.tryParse(_p4LatCtrl.text.trim());
        final p4Lng = double.tryParse(_p4LngCtrl.text.trim());

        if (p1Lat != null && p1Lng != null &&
            p2Lat != null && p2Lng != null &&
            p3Lat != null && p3Lng != null &&
            p4Lat != null && p4Lng != null) {
          newPolygon = [
            LatLngPoint(p1Lat, p1Lng),
            LatLngPoint(p2Lat, p2Lng),
            LatLngPoint(p3Lat, p3Lng),
            LatLngPoint(p4Lat, p4Lng),
          ];
        } else {
          final r = (radius ?? _current?.radiusMeters ?? 50.0) / 111000;
          newPolygon = [
            LatLngPoint(lat + r, lng + r),
            LatLngPoint(lat - r, lng + r),
            LatLngPoint(lat - r, lng - r),
            LatLngPoint(lat + r, lng - r),
          ];
        }
      }

      await _service.updateConfig(
        centerLat: lat,
        centerLng: lng,
        radiusMeters: radius,
        edgeBufferMeters: buffer,
        boundaryMode: _mode,
        polygonPoints: newPolygon,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Boundary configuration saved and applied.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildCornerRow(String label, TextEditingController latCtrl, TextEditingController lngCtrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: latCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lat',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: lngCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lng',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune_rounded, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Edit Boundary Configuration',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: _loading
          ? const SizedBox(
              width: 260,
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Changes take effect immediately for all users. '
                        'You can fine-tune all 4 corner coordinates of the polygon below, '
                        'or auto-calculate them from the center & radius.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Center coordinates
                    const Text(
                      'Boundary Center',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lngCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _fetchingGps ? null : _captureGps,
                        icon: _fetchingGps
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded, size: 16),
                        label: const Text('Use My Current GPS Location'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Radius and buffer
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _radiusCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Radius (m)',
                              helperText: 'Wake-up circle',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _bufferCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Edge Buffer (m)',
                              helperText: 'Debounce zone',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Boundary mode
                    const Text(
                      'Detection Mode',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'polygon',
                          label: Text('Polygon'),
                          icon: Icon(Icons.polyline_outlined),
                        ),
                        ButtonSegment(
                          value: 'circle',
                          label: Text('Circle'),
                          icon: Icon(Icons.radio_button_unchecked_rounded),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                    ),
                    if (_mode == 'polygon') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Polygon 4 Corners',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _autoCalculateCorners,
                            icon: const Icon(Icons.sync_rounded, size: 14),
                            label: const Text('Auto-fit from Center', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildCornerRow('Corner 1 (NE / East)', _p1LatCtrl, _p1LngCtrl),
                      _buildCornerRow('Corner 2 (SE / South)', _p2LatCtrl, _p2LngCtrl),
                      _buildCornerRow('Corner 3 (SW / West)', _p3LatCtrl, _p3LngCtrl),
                      _buildCornerRow('Corner 4 (NW / North)', _p4LatCtrl, _p4LngCtrl),
                    ],

                    // Updated at
                    if (_current?.updatedAt != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Last saved: ${_current!.updatedAt!.toLocal()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving || _loading ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 16),
          label: const Text('Save & Apply'),
        ),
      ],
    );
  }
}

class VisitorManagementPage extends StatefulWidget {
  const VisitorManagementPage({super.key});

  @override
  State<VisitorManagementPage> createState() => _VisitorManagementPageState();
}

class _VisitorManagementPageState extends State<VisitorManagementPage> {
  final controller = OwnerController.instance;
  late final TableRefreshSubscription _subscription;
  RecordListScope scope = RecordListScope.active;
  RecordListSort sort = RecordListSort.newest;

  @override
  void initState() {
    super.initState();
    controller.loadVisitors();
    _subscription = TableRefreshSubscription(
      'staff-visitors',
      const ['visitor_requests', 'visitor_events'],
      () => controller.loadVisitors(force: true),
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  String? _policyIssue(VisitorRequest request) {
    final departure = request.expectedDepartureAt;
    if (departure == null) return 'Expected departure time is required.';

    final submittedAt =
        request.createdAt ?? request.schedule.subtract(const Duration(days: 1));

    return VisitorPolicy.validateVisit(
      schedule: request.schedule,
      expectedDepartureAt: departure,
      now: submittedAt,
    );
  }

  String _policySummary(VisitorRequest request) {
    final issue = _policyIssue(request);
    return issue == null
        ? 'Compliant • ${VisitorPolicy.visitingHoursLabel} • advance registration'
        : 'Needs correction • $issue';
  }

  Future<void> _transition(
    VisitorRequest request,
    String action, {
    String? note,
  }) async {
    try {
      await controller.transitionVisitor(request, action, note: note);
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Visitor update failed: $error');
    }
  }

  Future<void> _reject(VisitorRequest request) async {
    final notes = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject visitor request'),
        content: TextField(
          controller: notes,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Required for the tenant and audit history',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (notes.text.trim().length < 2) {
                showAppSnackBar(context, 'Enter a rejection reason.');
                return;
              }

              Navigator.pop(dialogContext);
              await _transition(request, 'reject', note: notes.text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    notes.dispose();
  }

  Future<void> _showHistory(VisitorRequest request) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${request.visitorName} history'),
          content: SizedBox(
            width: 460,
            child: FutureBuilder<List<VisitorEvent>>(
              future: controller.loadVisitorEvents(request.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final events = snapshot.data ?? const <VisitorEvent>[];
                if (events.isEmpty) {
                  return const Text('No review or presence events yet.');
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: events
                      .map(
                        (event) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(event.eventLabel),
                          subtitle: Text(
                            '${event.actorName.isEmpty ? 'Authorized user' : event.actorName} • '
                            '${shortDate(event.occurredAt)} • ${timeText(event.occurredAt)}'
                            '${event.note?.isNotEmpty == true ? '\n${event.note}' : ''}',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Visitor management',
      subtitle: 'Advance requests, approvals, arrivals, and departures',
      onRefresh: () => controller.loadVisitors(force: true),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final activeVisitors = controller.visitors
              .where((item) =>
                  item.isPending || item.isApproved || item.hasArrived)
              .toList();
          final historyVisitors = controller.visitors
              .where((item) =>
                  item.isRejected || item.isCancelled || item.isCompleted)
              .toList();
          final visible = List<VisitorRequest>.from(
            scope == RecordListScope.active ? activeVisitors : historyVisitors,
          )..sort((a, b) => switch (sort) {
                RecordListSort.oldest => a.schedule.compareTo(b.schedule),
                RecordListSort.status => a.status.compareTo(b.status),
                RecordListSort.title => a.visitorName.compareTo(b.visitorName),
                _ => b.schedule.compareTo(a.schedule),
              });
          if (controller.visitorsLoading && controller.visitors.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.visitorsError != null && controller.visitors.isEmpty) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Unable to load visitor requests',
              message: controller.visitorsError!,
            );
          }

          return Column(
            children: [
              CarmelitaCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.rule_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Visitor policy: requests are filed at least one calendar day in advance, '
                        'visiting hours are 9:00 AM–9:00 PM, and visitors leave the same day. '
                        'Arrival can only be recorded after staff approval.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              RecordListToolbar(
                scope: scope,
                sort: sort,
                activeCount: activeVisitors.length,
                historyCount: historyVisitors.length,
                onScopeChanged: (value) => setState(() => scope = value),
                onSortChanged: (value) => setState(() => sort = value),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                EmptyState(
                  icon: Icons.people_outline,
                  title: scope == RecordListScope.active
                      ? 'No active visitor requests'
                      : 'No visitor history',
                  message: scope == RecordListScope.active
                      ? 'Pending and approved visitor requests appear here.'
                      : 'Completed, rejected, and cancelled visits appear here.',
                ),
              PagedRecordList(
                key: ValueKey('staff-visitors-$scope-$sort'),
                children: visible
                    .map(
                      (visitor) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CarmelitaCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      visitor.visitorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                  StatusPill(visitor.statusLabel),
                                ],
                              ),
                              const SizedBox(height: 8),
                              InfoRow(
                                label: 'Relationship',
                                value: visitor.relationship,
                              ),
                              if (visitor.tenantName.isNotEmpty)
                                InfoRow(
                                  label: 'Resident',
                                  value: visitor.tenantName,
                                ),
                              InfoRow(
                                label: 'Purpose',
                                value: visitor.purpose,
                              ),
                              if (visitor.contactNumber.isNotEmpty)
                                InfoRow(
                                  label: 'Visitor contact',
                                  value: visitor.contactNumber,
                                ),
                              InfoRow(
                                label: 'Expected arrival',
                                value:
                                    '${shortDate(visitor.schedule)} • ${timeText(visitor.schedule)}',
                              ),
                              if (visitor.expectedDepartureAt != null)
                                InfoRow(
                                  label: 'Expected departure',
                                  value:
                                      '${shortDate(visitor.expectedDepartureAt!)} • ${timeText(visitor.expectedDepartureAt!)}',
                                ),
                              InfoRow(
                                label: 'Policy check',
                                value: _policySummary(visitor),
                              ),
                              if (visitor.reviewNote?.isNotEmpty == true)
                                InfoRow(
                                  label: 'Review note',
                                  value: visitor.reviewNote!,
                                ),
                              TextButton.icon(
                                onPressed: () => _showHistory(visitor),
                                icon: const Icon(Icons.history_rounded),
                                label: const Text('View history'),
                              ),
                              if (visitor.isPending) ...[
                                if (_policyIssue(visitor) != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'Approval is disabled until the visit schedule follows visitor policy.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _reject(visitor),
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _policyIssue(visitor) == null
                                            ? () =>
                                                _transition(visitor, 'approve')
                                            : null,
                                        child: const Text('Approve'),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (visitor.isApproved) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () =>
                                        _transition(visitor, 'record_arrival'),
                                    icon: const Icon(Icons.login_rounded),
                                    label: const Text('Record arrival'),
                                  ),
                                ),
                              ] else if (visitor.hasArrived) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => _transition(
                                        visitor, 'record_departure'),
                                    icon: const Icon(Icons.logout_rounded),
                                    label: const Text('Record departure'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ConfidentialReportsPage extends StatefulWidget {
  const ConfidentialReportsPage({super.key});

  @override
  State<ConfidentialReportsPage> createState() =>
      _ConfidentialReportsPageState();
}

class _ConfidentialReportsPageState extends State<ConfidentialReportsPage> {
  final controller = OwnerController.instance;

  @override
  void initState() {
    super.initState();
    controller.loadConcerns();
  }

  Future<void> _review(ConcernReport report, String status) async {
    final notes = TextEditingController(text: report.responseNotes);
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(status == 'resolved'
              ? 'Resolve confidential report'
              : status == 'dismissed'
                  ? 'Dismiss confidential report'
                  : 'Begin confidential review'),
          content: TextField(
            controller: notes,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Private review notes',
              hintText: 'Record the action taken or reason for this decision.',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (notes.text.trim().length < 5) {
                        showAppSnackBar(
                          context,
                          'Enter at least 5 characters of review notes.',
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await controller.reviewConcern(
                          report: report,
                          status: status,
                          notes: notes.text,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        if (context.mounted) {
                          showAppSnackBar(context, 'Review failed: $error');
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Confirm'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const {UserRole.owner},
      child: PageFrame(
        title: 'Confidential reports',
        subtitle: 'Owner-authorized review with audit logging',
        onRefresh: () => controller.loadConcerns(force: true),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.concernsLoading && controller.concerns.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.concernsError != null &&
                controller.concerns.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_outline, size: 42),
                  const SizedBox(height: 10),
                  Text(controller.concernsError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => controller.loadConcerns(force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ]),
              );
            }
            if (controller.concerns.isEmpty) {
              return const Center(
                child: Text('No confidential reports have been submitted.'),
              );
            }
            return Column(
              children: controller.concerns
                  .map(
                    (report) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CarmelitaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                StatusPill(report.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(report.tenantName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            SelectableText(report.summary),
                            const SizedBox(height: 8),
                            Text(
                              shortDate(report.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (report.responseNotes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Private notes: ${report.responseNotes}'),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: report.isResolved
                                      ? null
                                      : () => _review(report, 'under_review'),
                                  child: const Text('Mark under review'),
                                ),
                                FilledButton(
                                  onPressed: report.isResolved
                                      ? null
                                      : () => _review(report, 'resolved'),
                                  child: const Text('Resolve'),
                                ),
                                TextButton(
                                  onPressed: report.isResolved
                                      ? null
                                      : () => _review(report, 'dismissed'),
                                  child: const Text('Dismiss'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class AnnouncementsManagementPage extends StatefulWidget {
  const AnnouncementsManagementPage({super.key});

  @override
  State<AnnouncementsManagementPage> createState() =>
      _AnnouncementsManagementPageState();
}

class _AnnouncementsManagementPageState
    extends State<AnnouncementsManagementPage> {
  final _service = const AnnouncementService();
  List<AnnouncementRecord>? _announcements;
  bool _loading = true;
  String? _errorMessage;
  late final TableRefreshSubscription _subscription;

  String _selectedCategory = 'all';
  String _selectedAudience = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _categories = [
    ('all', 'All', Icons.apps_outlined),
    ('general', 'General', Icons.campaign_outlined),
    ('maintenance', 'Maintenance', Icons.build_outlined),
    ('utility', 'Utility', Icons.bolt_outlined),
    ('billing', 'Billing', Icons.payments_outlined),
    ('emergency', 'Emergency', Icons.warning_amber_rounded),
    ('event', 'Event', Icons.event_outlined),
  ];

  static const _audiences = [
    ('all', 'All Audiences'),
    ('tenants', 'Tenants'),
    ('guardians', 'Guardians'),
    ('staff', 'Staff only'),
  ];

  @override
  void initState() {
    super.initState();
    _announcements = AnnouncementService.cachedAnnouncements('all');
    _loading = _announcements == null;
    _fetchAnnouncements(showSpinner: _announcements == null);
    _subscription = TableRefreshSubscription(
      'owner-announcements',
      ['announcements'],
      () => _fetchAnnouncements(showSpinner: false),
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnnouncements({bool showSpinner = false}) async {
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final items = await _service.listAnnouncements(forceRefresh: true);
      if (mounted) {
        setState(() {
          _announcements = items;
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Failed to load announcements: $e';
        });
      }
    }
  }

  Future<void> _openComposer({AnnouncementRecord? editing}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AnnouncementComposerSheet(announcement: editing),
    );

    if (changed == true && mounted) {
      _fetchAnnouncements(showSpinner: false);
    }
  }

  Future<void> _togglePin(AnnouncementRecord item) async {
    try {
      await _service.togglePin(item.id, !item.isPinned);
      if (mounted) {
        showAppSnackBar(
          context,
          item.isPinned ? 'Notice unpinned.' : 'Notice pinned to top of board.',
        );
      }
      _fetchAnnouncements(showSpinner: false);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Failed to update pin: $e');
      }
    }
  }

  Future<void> _confirmDelete(AnnouncementRecord item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete notice?'),
        content: Text(
          'Are you sure you want to delete "${item.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteAnnouncement(item.id);
        if (mounted) {
          showAppSnackBar(context, 'Notice deleted.');
        }
        _fetchAnnouncements(showSpinner: false);
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Failed to delete notice: $e');
        }
      }
    }
  }

  Color _categoryColor(String category) => switch (category.toLowerCase()) {
        'emergency' => AppColors.danger,
        'maintenance' => AppColors.warning,
        'utility' => AppColors.info,
        'billing' => const Color(0xFFAA8A45),
        'event' => AppColors.success,
        _ => AppColors.taupe,
      };

  IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
        'emergency' => Icons.warning_amber_rounded,
        'maintenance' => Icons.build_outlined,
        'utility' => Icons.bolt_outlined,
        'billing' => Icons.payments_outlined,
        'event' => Icons.event_outlined,
        _ => Icons.campaign_outlined,
      };

  String _categoryTitle(String category) {
    for (final c in _categories) {
      if (c.$1 == category.toLowerCase()) return c.$2;
    }
    return category;
  }

  String _audienceTitle(String audience) {
    for (final a in _audiences) {
      if (a.$1 == audience.toLowerCase()) return a.$2;
    }
    return audience;
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasActive =
                _selectedCategory != 'all' || _selectedAudience != 'all';
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Notices',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (hasActive)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = 'all';
                              _selectedAudience = 'all';
                            });
                            setSheetState(() {});
                          },
                          child: const Text('Reset all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'CATEGORY',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.taupe,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat.$1;
                      return FilterChip(
                        avatar: Icon(
                          cat.$3,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : _categoryColor(cat.$1),
                        ),
                        label: Text(cat.$2),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedCategory = cat.$1);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'TARGET AUDIENCE',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.taupe,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _audiences.map((aud) {
                      final isSelected = _selectedAudience == aud.$1;
                      return ChoiceChip(
                        label: Text(aud.$2),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedAudience = aud.$1);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawList = _announcements ?? [];
    final filtered = rawList.where((item) {
      if (_selectedCategory != 'all' &&
          item.category.toLowerCase() != _selectedCategory) {
        return false;
      }
      if (_selectedAudience != 'all' &&
          item.audience.toLowerCase() != _selectedAudience) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final inTitle = item.title.toLowerCase().contains(q);
        final inBody = item.body.toLowerCase().contains(q);
        final inAuthor = item.authorName.toLowerCase().contains(q);
        if (!inTitle && !inBody && !inAuthor) return false;
      }
      return true;
    }).toList();

    final hasActiveFilter =
        _selectedCategory != 'all' || _selectedAudience != 'all';

    return PageFrame(
      title: 'Announcements',
      subtitle: 'Post and manage dormitory notices',
      actions: [
        IconButton(
          tooltip: 'Refresh board',
          onPressed: () => _fetchAnnouncements(showSpinner: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposer(),
        icon: const Icon(Icons.campaign),
        label: const Text('Post notice'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notices by title, keyword...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: hasActiveFilter
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _openFilterSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasActiveFilter
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.6),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 22,
                          color: hasActiveFilter
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        if (hasActiveFilter)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFB800),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (hasActiveFilter) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Filters:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.taupe,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (_selectedCategory != 'all')
                  InputChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(_categoryTitle(_selectedCategory)),
                    avatar: Icon(_categoryIcon(_selectedCategory), size: 14),
                    onDeleted: () => setState(() => _selectedCategory = 'all'),
                  ),
                if (_selectedAudience != 'all')
                  InputChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(_audienceTitle(_selectedAudience)),
                    onDeleted: () => setState(() => _selectedAudience = 'all'),
                  ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: () => setState(() {
                    _selectedCategory = 'all';
                    _selectedAudience = 'all';
                  }),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            CarmelitaCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!)),
                    TextButton(
                      onPressed: () => _fetchAnnouncements(showSpinner: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            EmptyState(
              icon: Icons.campaign_outlined,
              title: 'No announcements',
              message: _searchQuery.isNotEmpty ||
                      _selectedCategory != 'all' ||
                      _selectedAudience != 'all'
                  ? 'No notices match your selected filters.'
                  : 'No notices posted yet. Tap "Post notice" to create one.',
            )
          else
            ...filtered.map((item) {
              final color = _categoryColor(item.category);
              final icon = _categoryIcon(item.category);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CarmelitaCard(
                  emphasis: item.isPinned,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon, size: 13, color: color),
                                      const SizedBox(width: 4),
                                      Text(
                                        _categoryTitle(item.category),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _audienceTitle(item.audience),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                if (item.isPinned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7E6),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFFFD591),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.push_pin,
                                          size: 11,
                                          color: Color(0xFFD48806),
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Pinned',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFD48806),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (action) {
                              if (action == 'pin') {
                                _togglePin(item);
                              } else if (action == 'edit') {
                                _openComposer(editing: item);
                              } else if (action == 'delete') {
                                _confirmDelete(item);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'pin',
                                child: Row(
                                  children: [
                                    Icon(
                                      item.isPinned
                                          ? Icons.push_pin_outlined
                                          : Icons.push_pin,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.isPinned
                                          ? 'Unpin notice'
                                          : 'Pin to top',
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Edit notice'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppColors.danger,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delete notice',
                                      style: TextStyle(color: AppColors.danger),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.38,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 13,
                                color: AppColors.taupe,
                              ),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  item.authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 13,
                                color: AppColors.taupe,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${shortDate(item.createdAt)} • ${timeText(item.createdAt)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 11.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _AnnouncementComposerSheet extends StatefulWidget {
  const _AnnouncementComposerSheet({this.announcement});

  final AnnouncementRecord? announcement;

  @override
  State<_AnnouncementComposerSheet> createState() =>
      _AnnouncementComposerSheetState();
}

class _AnnouncementComposerSheetState
    extends State<_AnnouncementComposerSheet> {
  final _service = const AnnouncementService();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late String _category;
  late String _audience;
  late bool _isPinned;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final a = widget.announcement;
    _titleController = TextEditingController(text: a?.title ?? '');
    _bodyController = TextEditingController(text: a?.body ?? '');
    _category = a?.category ?? 'general';
    _audience = a?.audience ?? 'all';
    _isPinned = a?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      setState(() => _errorMessage = 'Please enter both a title and content.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      if (widget.announcement == null) {
        await _service.createAnnouncement(
          title: title,
          body: body,
          category: _category,
          audience: _audience,
          isPinned: _isPinned,
        );
      } else {
        await _service.updateAnnouncement(
          id: widget.announcement!.id,
          title: title,
          body: body,
          category: _category,
          audience: _audience,
          isPinned: _isPinned,
        );
      }

      if (mounted) {
        showAppSnackBar(
          context,
          widget.announcement == null
              ? 'Notice posted successfully.'
              : 'Notice updated successfully.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Failed to save notice: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.announcement != null;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    final categoryDropdown = DropdownButtonFormField<String>(
      initialValue: _category,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Category'),
      items: const [
        DropdownMenuItem(
          value: 'general',
          child: Text('General', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'maintenance',
          child: Text('Maintenance', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'utility',
          child: Text('Utility', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'billing',
          child: Text('Billing', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'emergency',
          child: Text('Emergency', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'event',
          child: Text('Event', overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: _saving
          ? null
          : (val) {
              if (val != null) setState(() => _category = val);
            },
    );

    final audienceDropdown = DropdownButtonFormField<String>(
      initialValue: _audience,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Audience'),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('All users', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'tenants',
          child: Text('Tenants only', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'guardians',
          child: Text('Guardians only', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'staff',
          child: Text('Staff only', overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: _saving
          ? null
          : (val) {
              if (val != null) setState(() => _audience = val);
            },
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + viewInsetsBottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit announcement' : 'Post announcement',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                isEditing
                    ? 'Update the announcement details below'
                    : 'Publish a new notice to tenants and guardians',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _titleController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Notice Title',
                  hintText: 'e.g., Scheduled Water Interruption',
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 360) {
                    return Column(
                      children: [
                        categoryDropdown,
                        const SizedBox(height: 14),
                        audienceDropdown,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: categoryDropdown),
                      const SizedBox(width: 12),
                      Expanded(child: audienceDropdown),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _bodyController,
                enabled: !_saving,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notice Content',
                  hintText: 'Write the details of the announcement here...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pin to top of board'),
                subtitle: const Text(
                  'Pinned notices remain visible at the very top of all feeds',
                ),
                value: _isPinned,
                onChanged:
                    _saving ? null : (val) => setState(() => _isPinned = val),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'Save Changes' : 'Publish Notice'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OwnerMessagingPage extends StatefulWidget {
  const OwnerMessagingPage({super.key, this.initialConversationId});

  final String? initialConversationId;

  @override
  State<OwnerMessagingPage> createState() => _OwnerMessagingPageState();
}

class _OwnerMessagingPageState extends State<OwnerMessagingPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final conversationId = widget.initialConversationId;
      if (conversationId == null || conversationId.isEmpty) {
        await MessagingController.instance.loadConversations();
      } else {
        await MessagingController.instance.openConversationById(conversationId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messaging = MessagingController.instance;

    return PageFrame(
      title: 'Messages',
      subtitle: 'Tenant, guardian and staff conversations',
      child: AnimatedBuilder(
        animation: messaging,
        builder: (context, _) {
          final filter = messaging.selectedFilter;
          final conversations = messaging.filteredConversations;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by resident name or room...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            messaging.setSearchQuery('');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => messaging.setSearchQuery(value),
              ),
              const SizedBox(height: 12),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: filter == 'all',
                      badgeColor: Theme.of(context).colorScheme.primary,
                      onTap: () => messaging.setFilter('all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Tenants',
                      selected: filter == 'tenant',
                      badgeColor: Theme.of(context).colorScheme.primary,
                      onTap: () => messaging.setFilter('tenant'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Guardians',
                      selected: filter == 'guardian',
                      badgeColor: Theme.of(context).colorScheme.primary,
                      onTap: () => messaging.setFilter('guardian'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Staff Channel',
                      selected: filter == 'staff',
                      badgeColor: Theme.of(context).colorScheme.primary,
                      onTap: () => messaging.setFilter('staff'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Conversation list
              if (messaging.loadingConversations && conversations.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (conversations.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No conversations found',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...conversations.map(
                  (conv) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ConversationListCard(
                      name: conv.title,
                      role: conv.subtitle,
                      lastMessageText:
                          conv.lastMessagePreview ?? 'No messages yet',
                      lastMessageTime: conv.lastMessageAt,
                      unreadCount: conv.unreadCount,
                      onTap: () => _ownerPush(
                        context,
                        OwnerConversationPage(
                          record: conv,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class OwnerConversationPage extends StatefulWidget {
  const OwnerConversationPage({
    this.conversation,
    this.record,
    super.key,
  }) : assert(conversation != null || record != null);

  final OwnerConversation? conversation;
  final ConversationRecord? record;

  @override
  State<OwnerConversationPage> createState() => _OwnerConversationPageState();
}

class _OwnerConversationPageState extends State<OwnerConversationPage> {
  final message = TextEditingController();

  @override
  void initState() {
    super.initState();
    final rec = widget.record;
    if (rec != null) {
      MessagingController.instance.openConversation(rec);
    }
  }

  @override
  void dispose() {
    message.dispose();
    if (widget.record != null) {
      MessagingController.instance.closeActiveConversation();
    }
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = message.text.trim();
    if (text.isEmpty) return;
    message.clear();

    if (widget.record != null) {
      await MessagingController.instance.sendMessage(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messaging = MessagingController.instance;
    final title = widget.record?.title ??
        widget.conversation?.personName ??
        'Conversation';
    final subtitle =
        widget.record?.subtitle ?? widget.conversation?.personRole ?? '';

    return PageFrame(
      title: title,
      subtitle: subtitle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: AnimatedBuilder(
          animation: messaging,
          builder: (context, _) {
            final messagesList = widget.record != null
                ? messaging.activeMessages
                : (widget.conversation?.messages ?? []);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONVERSATION',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 1.3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                CarmelitaCard(
                  padding: const EdgeInsets.all(12),
                  child: messagesList.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No messages yet. Send a message to start.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Column(
                          children: messagesList.map((item) {
                            final isStaff = item.senderRole == 'owner' ||
                                item.senderRole == 'caretaker' ||
                                item.senderRole == 'ownerCaretaker';

                            return Align(
                              alignment: isStaff
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 560),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: isStaff
                                      ? const Color(0xFF627FA8)
                                          .withValues(alpha: .10)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: .55),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft:
                                        Radius.circular(isStaff ? 15 : 4),
                                    bottomRight:
                                        Radius.circular(isStaff ? 4 : 15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isStaff
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.senderName,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.body,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 3),
                                    MessageDeliveryMeta(
                                      message: item,
                                      isMine: item.isMine(SessionController
                                          .instance.currentUser?.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: message,
                  enabled: !messaging.sendingMessage,
                  decoration: InputDecoration(
                    hintText: 'Write a message...',
                    prefixIcon: const Icon(Icons.chat_bubble_outline),
                    suffixIcon: messaging.sendingMessage
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            onPressed: _handleSend,
                            icon: const Icon(Icons.send_outlined),
                          ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Dormitory contact directory',
      subtitle: 'Guardian and emergency contacts for internal reference',
      child: CarmelitaCard(
        child: Column(
          children: controller.tenants
              .map(
                (tenant) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons.contact_phone_outlined,
                    ),
                  ),
                  title: Text(
                    tenant.guardianName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${tenant.name} • '
                    '${tenant.guardianPhone}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Call',
                    onPressed: () => showAppSnackBar(
                      context,
                      'Phone launcher integration placeholder.',
                    ),
                    icon: const Icon(
                      Icons.call_outlined,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class ContractExpiryAlertsPage extends StatelessWidget {
  const ContractExpiryAlertsPage({super.key});
  @override
  Widget build(BuildContext context) => const ContractsPage();
}

class ExpenseIncomeSummaryPage extends StatelessWidget {
  const ExpenseIncomeSummaryPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
        title: 'Expense & income summary',
        subtitle: 'August 2026 monthly snapshot',
        child: Column(children: [
          AdaptiveGrid(children: [
            MetricCard(
                label: 'Collected rent',
                value: '₱17,500',
                detail: '5 recorded payments',
                icon: Icons.savings_outlined),
            MetricCard(
                label: 'Outstanding',
                value: '₱7,900',
                detail: 'Rent and utilities',
                icon: Icons.pending_actions_outlined),
            MetricCard(
                label: 'Penalties',
                value: '₱350',
                detail: 'Recorded this month',
                icon: Icons.receipt_long_outlined),
          ]),
          SizedBox(height: 14),
          CarmelitaCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('Backend data required'),
                  subtitle: Text(
                      'Totals are illustrative until payment and expense ledgers are persisted.'))),
        ]),
      );
}

class DisciplinaryRecordsPage extends StatelessWidget {
  const DisciplinaryRecordsPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
        title: 'Disciplinary records',
        subtitle: 'Verified violations and issued notices by tenant',
        child: EmptyState(
            icon: Icons.gavel_outlined,
            title: 'No disciplinary records',
            message:
                'Backend storage and links to confidential reports are not connected yet.'),
      );
}

class ReportsAnalyticsPage extends StatelessWidget {
  const ReportsAnalyticsPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
        title: 'Analytics',
        subtitle: 'Operational drill-downs',
        child: Column(children: [
          AdaptiveGrid(children: [
            MetricCard(
                label: 'Occupancy',
                value: '75%',
                detail: '30 of 40 beds',
                icon: Icons.bed_outlined),
            MetricCard(
                label: 'Payment compliance',
                value: '67%',
                detail: 'Current sample records',
                icon: Icons.payments_outlined),
            MetricCard(
                label: 'Open maintenance',
                value: '2',
                detail: '1 medium • 1 low',
                icon: Icons.build_outlined),
            MetricCard(
                label: 'Geofence coverage',
                value: '100%',
                detail: '50m perimeter monitoring',
                icon: Icons.location_on_outlined),
          ]),
          SizedBox(height: 14),
          CarmelitaCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('Backend data required'),
                  subtitle: Text(
                      'Date filters, historical trends, and exports need persisted operational data.'))),
        ]),
      );
}
