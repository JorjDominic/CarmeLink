import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../widgets/feature_widgets.dart';
import '../shared/account_management_page.dart';
import 'floor_plan_page.dart';
import 'guardian_link_management_page.dart';

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
                '${controller.pendingGateReviews} gate alert',
                icon: Icons.shield_outlined,
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
                  label: 'Gate alerts',
                  value: '${controller.pendingGateReviews}',
                  detail: 'Flagged events',
                  icon: Icons.sensor_door_outlined,
                  color: const Color(0xFFAA6870),
                  onTap: () => _ownerPush(
                    context,
                    const GateMonitoringPage(),
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
              icon: Icons.schedule_outlined,
              title:
                  '${controller.pendingCurfewReviews} curfew request(s) waiting',
              subtitle:
                  'Guardian input is supporting information; your decision is final.',
              status: controller.pendingCurfewReviews > 0 ? 'Pending' : 'Clear',
              onTap: () => _ownerPush(
                context,
                const CurfewRequestReviewPage(),
              ),
            ),
            const SizedBox(height: 8),
            AttentionCard(
              compact: true,
              icon: Icons.videocam_outlined,
              title: '${controller.pendingGateReviews} flagged gate event(s)',
              subtitle:
                  'Review identity mismatch, unrecognized person, or tailgating alerts.',
              status: controller.pendingGateReviews > 0 ? 'Review' : 'Clear',
              onTap: () => _ownerPush(
                context,
                const GateMonitoringPage(),
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
  String query = '';

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Tenants',
      subtitle: 'Search and view tenant records',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final filtered = controller.tenants
              .where(
                (tenant) =>
                    tenant.name.toLowerCase().contains(
                          query.toLowerCase(),
                        ) ||
                    tenant.room.contains(query),
              )
              .toList();

          return Column(
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
                          child: Text(tenant.name[0]),
                        ),
                        title: Text(
                          tenant.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle:
                            Text('Room ${tenant.room} • ${tenant.bedSpace}'),
                        trailing: StatusPill(tenant.gateStatus),
                        onTap: () => _ownerPush(
                          context,
                          TenantDetailsPage(
                            tenant: tenant,
                          ),
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
                  label: 'Payment',
                  value: tenant.paymentSummary,
                  icon: Icons.payments_outlined,
                ),
                InfoRow(
                  label: 'Gate status',
                  value: tenant.gateStatus,
                  icon: Icons.sensor_door_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CarmelitaCard(
            child: Column(
              children: [
                _OwnerRouteTile(
                  title: 'Payment verification',
                  icon: Icons.receipt_long_outlined,
                  onTap: () => _ownerPush(
                    context,
                    const PaymentVerificationPage(),
                  ),
                ),
                const Divider(),
                _OwnerRouteTile(
                  title: 'Gate logs',
                  icon: Icons.sensor_door_outlined,
                  onTap: () => _ownerPush(
                    context,
                    const GateMonitoringPage(),
                  ),
                ),
                const Divider(),
                _OwnerRouteTile(
                  title: 'Confidential reports',
                  icon: Icons.shield_outlined,
                  onTap: () => _ownerPush(
                    context,
                    const ConfidentialReportsPage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerRouteTile extends StatelessWidget {
  const _OwnerRouteTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
                _OperationsStatus('Alerts', '${controller.pendingGateReviews}',
                    Icons.warning_amber_rounded, const Color(0xFFAA6870)),
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
        final total = controller.pendingCurfewReviews +
            controller.pendingVisitors +
            controller.pendingGateReviews;
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
      case 'Curfew':
        return 'Curfew (${controller.pendingCurfewReviews})';
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
      _OperationItem('System status', 'Monitor cameras and services',
          Icons.memory_outlined, IotDeviceStatusPage()),
    ],
  ),
  _OperationCategory(
    'Tenants & safety',
    'People, access, conduct and private reports',
    Icons.health_and_safety_outlined,
    Color(0xFF627FA8),
    [
      _OperationItem('Curfew', 'Review curfew activity and requests',
          Icons.schedule_outlined, CurfewMonitoringPage()),
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

class RoomMonitoringPage extends StatelessWidget {
  const RoomMonitoringPage({super.key});

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

class PaymentVerificationPage extends StatelessWidget {
  const PaymentVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Payment review',
      subtitle: 'Confirm or correct OCR-extracted receipt details',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final pending = controller.payments
              .where(
                (payment) =>
                    payment.status == 'Pending verification' ||
                    payment.status == 'Pending review',
              )
              .toList();

          if (pending.isEmpty) {
            return const EmptyState(
              icon: Icons.task_alt,
              title: 'No pending payment reviews',
              message:
                  'New receipts and their OCR-extracted values will appear here.',
            );
          }

          return Column(
            children: pending
                .map(
                  (payment) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CarmelitaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const InfoRow(
                            label: 'Tenant',
                            value: 'Anna Dela Cruz',
                          ),
                          InfoRow(
                            label: 'Amount',
                            value: money(payment.amount),
                          ),
                          InfoRow(
                            label: 'Reference',
                            value: payment.reference ?? '—',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => controller.verifyPayment(
                                    payment,
                                    false,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => controller.verifyPayment(
                                    payment,
                                    true,
                                  ),
                                  child: const Text('Confirm'),
                                ),
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
    );
  }
}

class MaintenanceManagementPage extends StatelessWidget {
  const MaintenanceManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Maintenance management',
      subtitle: 'Pending, ongoing, and completed reports',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => CarmelitaCard(
          child: Column(
            children: controller.maintenanceByPriority
                .map(
                  (report) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.build_outlined),
                    ),
                    title: Text(
                      '${report.category} • ${report.location}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${report.description}\n'
                      'Priority: ${report.urgency}',
                    ),
                    trailing: StatusPill(report.status),
                    onTap: () => _ownerPush(
                      context,
                      MaintenanceDetailsPage(
                        report: report,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class MaintenanceDetailsPage extends StatefulWidget {
  const MaintenanceDetailsPage({
    required this.report,
    super.key,
  });

  final MaintenanceReport report;

  @override
  State<MaintenanceDetailsPage> createState() => _MaintenanceDetailsPageState();
}

class _MaintenanceDetailsPageState extends State<MaintenanceDetailsPage> {
  late String status = widget.report.status;
  final notes = TextEditingController();
  bool evidenceSelected = false;

  @override
  void initState() {
    super.initState();
    notes.text = widget.report.notes;
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Maintenance details',
      subtitle: widget.report.location,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CarmelitaCard(
              child: Column(
                children: [
                  InfoRow(
                    label: 'Category',
                    value: widget.report.category,
                  ),
                  InfoRow(
                    label: 'Urgency',
                    value: widget.report.urgency,
                  ),
                  InfoRow(
                    label: 'Description',
                    value: widget.report.description,
                  ),
                  InfoRow(
                    label: 'Created',
                    value: shortDate(
                      widget.report.createdAt,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                'Submitted',
                'Ongoing',
                'Completed',
                'Closed',
              ]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => status = value ?? status),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notes,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Caretaker notes',
              ),
            ),
            const SizedBox(height: 14),
            CarmelitaCard(
              onTap: () {
                setState(() => evidenceSelected = true);
                showAppSnackBar(
                  context,
                  'Completion evidence selected in the frontend demo.',
                );
              },
              child: Row(
                children: [
                  Icon(
                    evidenceSelected
                        ? Icons.check_circle_outline
                        : Icons.add_photo_alternate_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      evidenceSelected
                          ? 'Completion evidence ready'
                          : 'Upload completion evidence',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  OwnerController.instance.updateMaintenance(
                    widget.report,
                    status,
                    notes: notes.text,
                  );
                  showAppSnackBar(
                    context,
                    'Maintenance report updated.',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Save update'),
              ),
            ),
          ],
        ),
      ),
    );
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

class GateMonitoringPage extends StatelessWidget {
  const GateMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Gate monitoring',
      subtitle: 'Facial recognition events with geofence cross-checks',
      floatingActionButton: FloatingActionButton(
        tooltip: 'System status',
        backgroundColor: const Color(0xFF568F8E),
        foregroundColor: Colors.white,
        onPressed: () => _ownerPush(
          context,
          const IotDeviceStatusPage(),
        ),
        child: const Icon(Icons.memory_outlined),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveGrid(
              children: [
                const MetricCard(
                  label: 'Recognition processor',
                  value: 'Online',
                  detail: 'Last capture: 8:14 PM',
                  icon: Icons.router_outlined,
                ),
                const MetricCard(
                  label: 'Geofence service',
                  value: 'Online',
                  detail: 'Supporting location signal',
                  icon: Icons.location_on_outlined,
                ),
                MetricCard(
                  label: 'Alerts',
                  value: '${controller.pendingGateReviews}',
                  detail: 'Needs review',
                  icon: Icons.warning_amber_outlined,
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (controller.gateReviews.isNotEmpty) ...[
              const SectionTitle('Flagged events'),
              const SizedBox(height: 10),
              ...controller.gateReviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GateReviewCard(review: review),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SectionTitle('Recent gate events'),
            const SizedBox(height: 10),
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
                        ? Icons.login
                        : event.direction == 'OUT'
                            ? Icons.logout
                            : Icons.videocam_outlined,
                    color: event.status == 'Review'
                        ? const Color(0xFFAA6870)
                        : event.direction == 'IN'
                            ? const Color(0xFF56886B)
                            : const Color(0xFF627FA8),
                    title: '${event.person} • ${event.direction}',
                    subtitle: '${timeText(event.time)} • '
                        '${event.verification}',
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

class _GateReviewCard extends StatefulWidget {
  const _GateReviewCard({
    required this.review,
  });

  final GateReviewRecord review;

  @override
  State<_GateReviewCard> createState() => _GateReviewCardState();
}

class _GateReviewCardState extends State<_GateReviewCard> {
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;

    return CarmelitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${review.event.person} • '
                  '${review.event.direction}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              StatusPill(review.reviewStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${shortDate(review.event.time)} • '
            '${timeText(review.event.time)} • '
            '${review.event.verification}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Review note',
              hintText: 'Optional note',
            ),
          ),
          if (review.reviewStatus == 'Pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => OwnerController.instance.reviewGateEvent(
                      review,
                      status: 'Escalated',
                      note: note.text,
                    ),
                    child: const Text('Escalate'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => OwnerController.instance.reviewGateEvent(
                      review,
                      status: 'Resolved',
                      note: note.text,
                    ),
                    child: const Text('Resolve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ManualGateOverridePage extends StatefulWidget {
  const ManualGateOverridePage({super.key});

  @override
  State<ManualGateOverridePage> createState() => _ManualGateOverridePageState();
}

class _ManualGateOverridePageState extends State<ManualGateOverridePage> {
  final reason = TextEditingController();
  String action = 'OPEN';

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Manual gate override',
      subtitle: 'Record operator action and reason',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: action,
              decoration: const InputDecoration(labelText: 'Action'),
              items: const ['OPEN', 'LOCK']
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => action = value ?? action),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reason,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Example: power interruption or verified emergency',
              ),
            ),
            const SizedBox(height: 14),
            const CarmelitaCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text(
                  'Audit-ready frontend',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'The backend should later save the operator account, '
                  'timestamp, reason, device state, and action.',
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (reason.text.trim().isEmpty) {
                    showAppSnackBar(
                      context,
                      'Enter the reason for the override.',
                    );
                    return;
                  }

                  OwnerController.instance.addManualOverride(
                    reason: reason.text,
                    action: action,
                  );
                  showAppSnackBar(
                    context,
                    'Manual override recorded.',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Record override'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CurfewMonitoringPage extends StatelessWidget {
  const CurfewMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Curfew monitoring',
      subtitle: 'Outside tenants, late records, and exceptions',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveGrid(
              children: [
                const MetricCard(
                  label: 'Currently outside',
                  value: '4',
                  detail: 'Before curfew',
                  icon: Icons.directions_walk_outlined,
                ),
                MetricCard(
                  label: 'Approved exceptions',
                  value:
                      '${controller.curfewRequests.where((r) => r.ownerStatus == 'Approved').length}',
                  detail: 'Current records',
                  icon: Icons.event_available_outlined,
                ),
                const MetricCard(
                  label: 'Late arrivals',
                  value: '0',
                  detail: 'Today',
                  icon: Icons.warning_amber_outlined,
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => _ownerPush(
                context,
                const CurfewRequestReviewPage(),
              ),
              icon: const Icon(Icons.approval_outlined),
              label: const Text('Review curfew requests'),
            ),
          ],
        ),
      ),
    );
  }
}

class CurfewRequestReviewPage extends StatelessWidget {
  const CurfewRequestReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Curfew request review',
      subtitle: 'Owner / caretaker decision',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          children: controller.curfewRequests
              .map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CarmelitaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                request.tenantName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            StatusPill(
                              request.ownerStatus,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InfoRow(
                          label: 'Reason',
                          value: request.reason,
                        ),
                        InfoRow(
                          label: 'Destination',
                          value: request.destination,
                        ),
                        InfoRow(
                          label: 'Guardian',
                          value: request.guardianStatus,
                        ),
                        InfoRow(
                          label: 'Return',
                          value: '${shortDate(request.expectedReturn)} • '
                              '${timeText(request.expectedReturn)}',
                        ),
                        if (request.guardianStatus == 'Approved' &&
                            request.ownerStatus == 'Pending') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => controller.decideCurfew(
                                    request,
                                    false,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => controller.decideCurfew(
                                    request,
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
        ),
      ),
    );
  }
}

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
  final title = TextEditingController();
  final body = TextEditingController();
  String audience = 'All tenants';

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'Announcements',
      subtitle: 'Create and publish dormitory notices',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          children: [
            CarmelitaCard(
              child: Column(
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: body,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Announcement',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: audience,
                    decoration: const InputDecoration(
                      labelText: 'Audience',
                    ),
                    items: const [
                      'All tenants',
                      'Guardians',
                      'All users',
                    ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(
                      () => audience = value ?? audience,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (title.text.trim().isEmpty ||
                            body.text.trim().isEmpty) {
                          showAppSnackBar(
                            context,
                            'Enter a title and announcement.',
                          );
                          return;
                        }

                        controller.publishAnnouncement(
                          title: title.text,
                          body: body.text,
                          audience: audience,
                        );
                        title.clear();
                        body.clear();
                        showAppSnackBar(
                          context,
                          'Announcement published in the frontend.',
                        );
                      },
                      child: const Text('Publish'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle('Published'),
            const SizedBox(height: 10),
            ...controller.announcements.map(
              (announcement) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CarmelitaCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.campaign_outlined,
                    ),
                    title: Text(
                      announcement.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${announcement.audience}\n'
                      '${announcement.body}',
                    ),
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

class IotDeviceStatusPage extends StatelessWidget {
  const IotDeviceStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;

    return PageFrame(
      title: 'System status',
      subtitle: 'Camera, processing device, and connectivity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CarmelitaCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text(
                'Frontend demonstration',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                'These states are mock values. Live camera captures, processing '
                'heartbeats, and connectivity require the backend monitoring feed.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          AdaptiveGrid(
            minTileWidth: 250,
            children: controller.devices
                .map(
                  (device) => CarmelitaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Icon(
                                Icons.memory_outlined,
                                size: 26,
                              ),
                            ),
                            StatusPill(device.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          device.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          device.detail,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
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
                label: 'Curfew flags',
                value: '1',
                detail: 'Awaiting final review',
                icon: Icons.schedule_outlined),
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
