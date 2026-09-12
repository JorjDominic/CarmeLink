import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../controllers/owner_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/payment_service.dart';
import '../../services/tenant_service.dart';
import '../../services/announcement_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../widgets/feature_widgets.dart';
import '../shared/account_management_page.dart';
import 'floor_plan_page.dart';
import 'guardian_link_management_page.dart';
import 'staff_maintenance_page.dart';
import 'room_monitoring_page.dart';

void _ownerPush(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => page),
  );
}

class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Dashboard',
      subtitle: 'Priority-ranked Today view',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElegantHeader(
              eyebrow: 'Operations',
              title: 'Good afternoon.',
              subtitle:
                  '${controller.occupiedBeds} of ${controller.totalCapacity} beds are currently occupied.',
              trailing: StatusPill(
                '${controller.tenantsInsideCount} inside',
                icon: Icons.location_on_outlined,
              ),
            ),
            const SizedBox(height: 22),
            const PhotoHero(
              image: AppAssets.dormOverview,
              title: 'CarmeLink',
              subtitle: 'Quick monitoring for daily operations',
              height: 220,
            ),
            const SizedBox(height: 22),
            const SectionTitle(
              'Property status',
              subtitle: 'The numbers that matter most right now',
            ),
            const SizedBox(height: 10),
            MutedDashboardGrid(
              denseFourColumn: true,
              items: [
                MutedDashboardItem(
                  label: 'Occupancy',
                  value:
                      '${controller.occupiedBeds}/${controller.totalCapacity}',
                  detail: '${controller.rooms.length} rooms',
                  icon: Icons.bed_outlined,
                  color: const Color(0xFF56886B),
                  onTap: () => _ownerPush(
                    context,
                    const RoomMonitoringPage(),
                  ),
                ),
                MutedDashboardItem(
                  label: 'Payment reviews',
                  value: '${controller.pendingPaymentProofs}',
                  detail: 'Proofs waiting',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFFAA8A45),
                  onTap: () => _ownerPush(
                    context,
                    const PaymentVerificationPage(),
                  ),
                ),
                MutedDashboardItem(
                  label: 'Maintenance',
                  value: '${controller.openMaintenance}',
                  detail: 'Open reports',
                  icon: Icons.build_outlined,
                  color: const Color(0xFFB47A52),
                  onTap: () => _ownerPush(
                    context,
                    const MaintenanceManagementPage(),
                  ),
                ),
                MutedDashboardItem(
                  label: 'Curfew',
                  value: '${controller.tenantsInsideCount} Inside',
                  detail: '${controller.tenantsOutsideCount} Outside',
                  icon: Icons.schedule_outlined,
                  color: const Color(0xFF56886B),
                  onTap: () => _ownerPush(
                    context,
                    const GeofenceMonitoringPage(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle(
              'Today • highest priority first',
              subtitle: 'Actionable items before routine monitoring',
            ),
            const SizedBox(height: 10),
            AttentionCard(
              compact: true,
              icon: Icons.event_busy_outlined,
              title: '1 contract expires within 30 days',
              subtitle: 'Review renewal or move-out arrangements.',
              status: 'Soon',
              onTap: () =>
                  _ownerPush(context, const ContractExpiryAlertsPage()),
            ),
            const SizedBox(height: 8),
            AttentionCard(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title:
                  '${controller.pendingPaymentProofs} payment proof(s) waiting',
              subtitle: 'Review uploaded proof before changing payment status.',
              status: controller.pendingPaymentProofs > 0 ? 'Pending' : 'Clear',
              onTap: () => _ownerPush(
                context,
                const PaymentVerificationPage(),
              ),
            ),
            const SizedBox(height: 8),
            AttentionCard(
              compact: true,
              icon: Icons.location_on_outlined,
              title: 'Dormitory geofencing active',
              subtitle:
                  'GPS perimeter monitoring ${controller.tenants.length} registered residents.',
              status: 'Active',
              onTap: () => _ownerPush(
                context,
                const GeofenceMonitoringPage(),
              ),
            ),
          ],
        ),
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
        'rooms'
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
      final latest = await _service.loadTenants(forceRefresh: true);
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
      final filtered = allTenants
          .where(
            (tenant) =>
                tenant.name.toLowerCase().contains(
                      query.toLowerCase(),
                    ) ||
                tenant.room.contains(query),
          )
          .toList();

      body = Column(
        children: [
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
                    title: Text(
                      tenant.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text('Room ${tenant.room} • ${tenant.bedSpace}'),
                    trailing:
                        StatusPill(_residencyLabel(tenant.residencyStatus)),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => TenantDetailsPage(tenant: tenant),
                      ));
                      if (mounted) _fetchTenants(showSpinner: false);
                    },
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return PageFrame(
      title: 'Tenants',
      subtitle: 'Search and view tenant records',
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

class TenantDetailsPage extends StatelessWidget {
  const TenantDetailsPage({
    required this.tenant,
    super.key,
  });

  final TenantDirectoryEntry tenant;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: tenant.name,
      subtitle: 'Tenant details',
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
          const SizedBox(height: 14),
          _TenantAssignmentManager(tenant: tenant),
        ],
      ),
    );
  }
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
  final Set<String> _quickAccess = {'Payments', 'Maintenance', 'Floor plan'};
  String query = '';

  List<_OperationItem> get _allOperationItems =>
      _operationCategories.expand((category) => category.items).toList();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;
    final categories = _operationCategories;
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.tune_rounded,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ]),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
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
                  childAspectRatio: constraints.maxWidth < 600 ? 1.55 : 1.2,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) =>
                    _OperationsStatusCard(data: cards[index]),
              );
            }),
            const SizedBox(height: 24),
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
            const SizedBox(height: 16),
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
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: constraints.maxWidth < 520 ? 3.15 : 3.5,
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
      case 'Maintenance':
        return 'Maintenance (${controller.openMaintenance})';
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
      _OperationItem('Maintenance', 'Manage repair requests',
          Icons.build_outlined, MaintenanceManagementPage()),
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
      _OperationItem('Visitors', 'Manage visitor requests',
          Icons.people_outline, VisitorManagementPage()),
      _OperationItem('Confidential reports', 'Review private reports',
          Icons.shield_outlined, ConfidentialReportsPage()),
      _OperationItem('Disciplinary records', 'Manage violations',
          Icons.gavel_outlined, DisciplinaryRecordsPage()),
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
          Icons.insights_outlined, ExpenseIncomeSummaryPage()),
      _OperationItem('Contract expiry', 'Track renewals and move-outs',
          Icons.event_busy_outlined, ContractExpiryAlertsPage()),
      _OperationItem('Reports & analytics', 'View detailed reports',
          Icons.analytics_outlined, ReportsAnalyticsPage()),
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: category.color.withValues(alpha: .14)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: category.color.withValues(alpha: .12),
                    foregroundColor: category.color,
                    child: Icon(category.icon),
                  ),
                  const SizedBox(width: 14),
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
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: category.items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: constraints.maxWidth < 520 ? 4.5 : 4.2,
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
    this.page,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
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
  String _filter = 'pending'; // 'pending', 'verified', 'rejected', 'all'
  late final TableRefreshSubscription _subscription;
  String? _processingPaymentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OwnerController.instance.loadPayments();
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
    super.dispose();
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
      subtitle: 'Inspect tenant receipts and verify balances',
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
          final pendingCount = allPayments.where((p) => p.isPending).length;
          final verifiedCount = allPayments.where((p) => p.isVerified).length;
          final rejectedCount = allPayments.where((p) => p.isRejected).length;

          final displayed = switch (_filter) {
            'pending' => allPayments.where((p) => p.isPending).toList(),
            'verified' => allPayments.where((p) => p.isVerified).toList(),
            'rejected' => allPayments.where((p) => p.isRejected).toList(),
            _ => allPayments,
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      : Icons.receipt_long_outlined,
                  title: _filter == 'pending'
                      ? 'No pending reviews'
                      : 'No payments in this tab',
                  message: _filter == 'pending'
                      ? 'All resident proof uploads have been reviewed and verified.'
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
                      onReEvaluate: () => _handleVerify(payment, true),
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
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
              StatusPill(payment.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Payment details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${payment.category.toUpperCase()} • ${payment.paymentMethod ?? "GCash"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                money(payment.amount),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
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
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
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
                  ),
                ),
              ],
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
            Text(
              'No photo receipt attached (Reference provided)',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
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
                      Text(
                        'Tap to inspect receipt full screen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${payment.label} • ${money(payment.amount)} • Ref: ${payment.reference ?? "—"}',
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
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            );
                          },
                        ),
                ),
              ),
            ),
            if (payment.isPending)
              Container(
                color: Colors.black.withValues(alpha: .9),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
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
                      ),
                    ),
                  ],
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
    return Padding(
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
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
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
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
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
                ),
              ),
            ],
          ),
        ],
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

class GeofenceMonitoringPage extends StatelessWidget {
  const GeofenceMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Curfew',
      subtitle: 'Geofence perimeter and live tenant status',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveGrid(
              children: [
                const MetricCard(
                  label: 'Dormitory perimeter',
                  value: '50m Radius',
                  detail: 'Carmelita\'s Dormitory',
                  icon: Icons.location_searching_outlined,
                ),
                MetricCard(
                  label: 'Inside perimeter',
                  value: '${controller.tenantsInsideCount}',
                  detail: 'Residents on premises',
                  icon: Icons.home_outlined,
                ),
                MetricCard(
                  label: 'Outside perimeter',
                  value: '${controller.tenantsOutsideCount}',
                  detail: 'Residents away',
                  icon: Icons.directions_walk_outlined,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionTitle(
              'Resident presence directory',
              subtitle:
                  'Current presence verified via background GPS geofencing',
            ),
            const SizedBox(height: 10),
            ...controller.tenants.map(
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
                        backgroundColor: (tenant.gateStatus == 'IN' ||
                                tenant.gateStatus == 'Inside')
                            ? const Color(0x1556886B)
                            : const Color(0x15627FA8),
                        foregroundColor: (tenant.gateStatus == 'IN' ||
                                tenant.gateStatus == 'Inside')
                            ? const Color(0xFF56886B)
                            : const Color(0xFF627FA8),
                        child: Icon(
                          (tenant.gateStatus == 'IN' ||
                                  tenant.gateStatus == 'Inside')
                              ? Icons.home_rounded
                              : Icons.directions_walk_rounded,
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
                              'Room ${tenant.room} • Bed ${tenant.bedSpace}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        (tenant.gateStatus == 'IN' ||
                                tenant.gateStatus == 'Inside')
                            ? 'Inside'
                            : 'Outside',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SectionTitle(
              'Recent geofence transitions',
              subtitle: 'Automated perimeter arrival and departure logs',
            ),
            const SizedBox(height: 10),
            ...controller.geofenceEvents.map(
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
                        : Icons.logout_rounded,
                    color: event.direction == 'IN'
                        ? const Color(0xFF56886B)
                        : const Color(0xFF627FA8),
                    title:
                        '${event.person} • ${event.direction == 'IN' ? 'Entered' : 'Exited'} perimeter',
                    subtitle:
                        '${shortDate(event.time)} • ${timeText(event.time)} • ${event.verification}',
                    trailing: StatusPill(event.status),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef GateMonitoringPage = GeofenceMonitoringPage;
typedef CurfewMonitoringPage = GeofenceMonitoringPage;
typedef CurfewRequestReviewPage = GeofenceMonitoringPage;

class VisitorManagementPage extends StatelessWidget {
  const VisitorManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Visitor management',
      subtitle: 'Expected visitors and permission status',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.visitors.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No visitor requests',
              message: 'Tenant visitor requests will appear here.',
            );
          }

          return Column(
            children: controller.visitors
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
                              StatusPill(visitor.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InfoRow(
                            label: 'Relationship',
                            value: visitor.relationship,
                          ),
                          InfoRow(
                            label: 'Schedule',
                            value: '${shortDate(visitor.schedule)} • '
                                '${timeText(visitor.schedule)}',
                          ),
                          if (visitor.status == 'Pending') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => controller.decideVisitor(
                                      visitor,
                                      false,
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => controller.decideVisitor(
                                      visitor,
                                      true,
                                    ),
                                    child: const Text('Approve'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class ConfidentialReportsPage extends StatelessWidget {
  const ConfidentialReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Confidential reports',
      subtitle: 'Authorized review only',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
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
                        Text(report.summary),
                        const SizedBox(height: 8),
                        Text(
                          shortDate(report.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => controller.updateConcernStatus(
                                report,
                                'Under review',
                              ),
                              child: const Text(
                                'Mark under review',
                              ),
                            ),
                            FilledButton(
                              onPressed: () => controller.updateConcernStatus(
                                report,
                                'Resolved',
                              ),
                              child: const Text('Resolve'),
                            ),
                          ],
                        ),
                      ],
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

class OwnerMessagingPage extends StatelessWidget {
  const OwnerMessagingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Messages',
      subtitle: 'Tenant and guardian conversations',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          children: controller.conversations
              .map(
                (conversation) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ConversationListCard(
                    name: conversation.personName,
                    role: conversation.personRole,
                    lastMessage: conversation.messages.last,
                    onTap: () => _ownerPush(
                      context,
                      OwnerConversationPage(
                        conversation: conversation,
                      ),
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

class OwnerConversationPage extends StatefulWidget {
  const OwnerConversationPage({
    required this.conversation,
    super.key,
  });

  final OwnerConversation conversation;

  @override
  State<OwnerConversationPage> createState() => _OwnerConversationPageState();
}

class _OwnerConversationPageState extends State<OwnerConversationPage> {
  final message = TextEditingController();

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: widget.conversation.personName,
      subtitle: widget.conversation.personRole,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CONVERSATION',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.3,
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 8),
              CarmelitaCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: widget.conversation.messages
                      .map(
                        (item) => Align(
                          alignment: item.senderRole == 'ownerCaretaker'
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(
                              maxWidth: 560,
                            ),
                            margin: const EdgeInsets.symmetric(
                              vertical: 6,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: item.senderRole == 'ownerCaretaker'
                                  ? const Color(0xFF627FA8)
                                      .withValues(alpha: .10)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: .55),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(15),
                                topRight: const Radius.circular(15),
                                bottomLeft: Radius.circular(
                                    item.senderRole == 'ownerCaretaker'
                                        ? 15
                                        : 4),
                                bottomRight: Radius.circular(
                                    item.senderRole == 'ownerCaretaker'
                                        ? 4
                                        : 15),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  item.senderRole == 'ownerCaretaker'
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                              children: [
                                Text(item.senderName,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(item.body,
                                    style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 3),
                                Text(timeText(item.sentAt),
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: message,
                decoration: InputDecoration(
                  hintText: 'Write a message',
                  prefixIcon: const Icon(Icons.chat_bubble_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      if (message.text.trim().isEmpty) {
                        return;
                      }
                      controller.sendOwnerMessage(
                        widget.conversation,
                        message.text,
                      );
                      message.clear();
                    },
                    icon: const Icon(Icons.send_outlined),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.trim().isEmpty) return;
                  controller.sendOwnerMessage(
                    widget.conversation,
                    value,
                  );
                  message.clear();
                },
              ),
            ],
          ),
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
  Widget build(BuildContext context) => const PageFrame(
        title: 'Contract expiry alerts',
        subtitle: 'Tenants with contracts ending soon',
        child: Column(children: [
          CarmelitaCard(
              child: TimelineTile(
                  icon: Icons.event_busy_outlined,
                  title: 'Ella Garcia • Room 105',
                  subtitle: 'Expires September 5, 2026 • 16 days remaining',
                  trailing: StatusPill('Soon'))),
          SizedBox(height: 12),
          CarmelitaCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('Backend data required'),
                  subtitle: Text(
                      'Contract dates are sample values until tenant contracts are stored in the backend.'))),
        ]),
      );
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
        title: 'Reports & analytics',
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
