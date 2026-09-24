import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/messaging_controller.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/tenant_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/visitor_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/announcement_service.dart';
import '../../services/geofence_service.dart';
import '../../services/receipt_ocr_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../../services/tripwire_geofence_service.dart';
import '../shared/room_cleaning_pages.dart';
import '../shared/room_inspection_pages.dart';
import '../shared/employee_curfew_profile_pages.dart';
import '../shared/conduct_case_pages.dart';
import '../widgets/feature_widgets.dart';

class TenantDashboardPage extends StatelessWidget {
  const TenantDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TenantController.instance;
    if (!controller.concernsLoadedOnce && !controller.concernsLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadConcerns();
      });
    }

    return PageFrame(
      title: 'Home',
      subtitle: 'Tenant dashboard',
      maxWidth: 760,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final session = SessionController.instance;
          final room = controller.room;
          final firstName =
              session.currentUser?.name.trim().split(' ').first ?? 'Resident';

          final nextDue = controller.nextDuePayment ??
              (controller.payments.isNotEmpty
                  ? controller.payments.first
                  : null);
          final outstanding = controller.outstandingBalance;
          final maintenance = controller.maintenance.isEmpty
              ? null
              : controller.maintenance.first;
          final presenceLabel = controller.checkingPresence ||
                  (controller.gateLoading && !controller.gateLoadedOnce)
              ? 'Loading'
              : controller.isInside
                  ? 'Inside'
                  : controller.isOutside
                      ? 'Outside'
                      : 'Unavailable';
          final presenceDetail = controller.gateError != null
              ? 'Presence data unavailable'
              : controller.lastGateEventAt != null
                  ? 'Updated ${shortDate(controller.lastGateEventAt!)} at ${timeText(controller.lastGateEventAt!)}'
                  : 'No presence event recorded';

          final roomSubtitle = room != null
              ? 'Room ${room.number} • ${room.bedSpace} • Floor ${room.floor}'
              : (controller.roomLoading
                  ? 'Loading room assignment...'
                  : 'No active room assignment');

          final roomCardDetail = room != null
              ? 'Room ${room.number} • ${room.bedSpace} • ${room.occupied}/${room.capacity} occupied'
              : (controller.roomLoading
                  ? 'Checking room status...'
                  : 'No active assignment • Tap to view');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElegantHeader(
                eyebrow: 'Welcome home',
                title: 'Good afternoon, $firstName.',
                subtitle: roomSubtitle,
                trailing: StatusPill(
                  presenceLabel,
                  icon: Icons.home_rounded,
                ),
              ),
              const SizedBox(height: 22),
              CarmelitaCard(
                emphasis: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MyRoomPage(),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .10),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(18),
                        ),
                      ),
                      child: Icon(
                        Icons.bed_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your room',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(roomCardDetail),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                'Today',
                subtitle: 'What matters right now',
              ),
              const SizedBox(height: 10),
              MutedDashboardGrid(
                items: [
                  MutedDashboardItem(
                    label: 'Rent balance',
                    value: money(controller.outstandingRent),
                    detail: 'Fixed by your contract',
                    icon: Icons.home_work_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  MutedDashboardItem(
                    label: 'Utility balance',
                    value: money(controller.outstandingUtilities),
                    detail: 'Based on recorded usage',
                    icon: Icons.bolt_outlined,
                    color: const Color(0xFFD97706),
                  ),
                  MutedDashboardItem(
                    label: 'Amount due',
                    value: nextDue != null
                        ? money(nextDue.amount)
                        : controller.paymentsLoadedOnce
                            ? money(0)
                            : '—',
                    detail: nextDue != null
                        ? '${nextDue.label} • Due ${shortDate(nextDue.dueDate)}'
                        : (outstanding > 0
                            ? '₱${outstanding.toStringAsFixed(2)} balance'
                            : controller.paymentsLoading
                                ? 'Loading billing records'
                                : controller.paymentsError != null
                                    ? 'Billing data unavailable'
                                    : controller.paymentsLoadedOnce
                                        ? 'No outstanding charges'
                                        : 'No billing data'),
                    icon: Icons.account_balance_wallet_outlined,
                    color: (nextDue != null || outstanding > 0)
                        ? const Color(0xFFAA8A45)
                        : const Color(0xFF56886B),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PaymentsPage(),
                      ),
                    ),
                  ),
                  MutedDashboardItem(
                    label: 'Curfew',
                    value: presenceLabel,
                    detail: presenceDetail,
                    icon: Icons.schedule_outlined,
                    color: const Color(0xFF56886B),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TenantPresencePage(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                'Needs your attention',
                subtitle: 'Important items before everything else',
              ),
              const SizedBox(height: 10),
              if (nextDue != null)
                AttentionCard(
                  icon: Icons.payments_outlined,
                  title: nextDue.isOverdue
                      ? '${nextDue.label} is overdue'
                      : '${nextDue.label} is due soon',
                  subtitle:
                      '${money(nextDue.amount)} • Due ${shortDate(nextDue.dueDate)}',
                  status: nextDue.isOverdue ? 'Overdue' : nextDue.status,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PaymentsPage(),
                    ),
                  ),
                )
              else if (controller.paymentsLoadedOnce)
                AttentionCard(
                  icon: Icons.payments_outlined,
                  title: 'All bills are up to date',
                  subtitle: 'No outstanding dormitory charges at this time.',
                  status: 'Clear',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PaymentsPage(),
                    ),
                  ),
                )
              else
                AttentionCard(
                  icon: Icons.payments_outlined,
                  title: controller.paymentsLoading
                      ? 'Loading billing records'
                      : 'Billing data unavailable',
                  subtitle: controller.paymentsError ??
                      'No billing information has been loaded yet.',
                  status: controller.paymentsLoading ? 'Loading' : 'No data',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PaymentsPage(),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (maintenance != null)
                AttentionCard(
                  icon: Icons.build_outlined,
                  title: maintenance.category,
                  subtitle:
                      '${maintenance.location} • ${maintenance.description}',
                  status: maintenance.status,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MaintenanceReportsPage(),
                    ),
                  ),
                )
              else
                AttentionCard(
                  icon: Icons.build_outlined,
                  title: controller.maintenanceLoading
                      ? 'Loading maintenance reports'
                      : 'No maintenance reports',
                  subtitle: controller.maintenanceError ??
                      'No submitted maintenance issue needs attention.',
                  status: controller.maintenanceLoading
                      ? 'Loading'
                      : controller.maintenanceError != null
                          ? 'No data'
                          : 'Clear',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MaintenanceReportsPage(),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const SectionTitle(
                'Quick actions',
                subtitle: 'Common tasks, one tap away',
              ),
              const SizedBox(height: 10),
              MutedActionGrid(
                items: [
                  MutedActionItem(
                    label: 'Upload proof',
                    detail: 'Submit a receipt',
                    icon: Icons.upload_file_outlined,
                    color: const Color(0xFF627FA8),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UploadPaymentProofPage(),
                      ),
                    ),
                  ),
                  MutedActionItem(
                    label: 'Report issue',
                    detail: 'Request maintenance',
                    icon: Icons.handyman_outlined,
                    color: const Color(0xFFB47A52),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubmitMaintenancePage(),
                      ),
                    ),
                  ),
                  MutedActionItem(
                    label: 'Curfew log',
                    detail: 'Review geofence',
                    icon: Icons.schedule_outlined,
                    color: const Color(0xFF7D70A0),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TenantPresencePage(),
                      ),
                    ),
                  ),
                  MutedActionItem(
                    label: 'Visitor',
                    detail: 'Register a visitor',
                    icon: Icons.person_add_alt_1_outlined,
                    color: const Color(0xFF568F8E),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VisitorRequestPage(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SectionTitle(
                'Latest announcement',
                trailing: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TenantAnnouncementsPage(),
                    ),
                  ),
                  child: const Text('View all'),
                ),
              ),
              const SizedBox(height: 10),
              const _TenantLatestAnnouncementCard(),
            ],
          );
        },
      ),
    );
  }
}

class MyRoomPage extends StatefulWidget {
  const MyRoomPage({super.key});

  @override
  State<MyRoomPage> createState() => _MyRoomPageState();
}

class _MyRoomPageState extends State<MyRoomPage> {
  late final TableRefreshSubscription _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TenantController.instance.loadMyRoom();
      }
    });
    _subscription = TableRefreshSubscription(
      'tenant-my-room',
      ['tenant_assignments', 'bed_spaces', 'rooms'],
      () {
        if (mounted) {
          TenantController.instance.loadMyRoom(force: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = TenantController.instance;

    return PageFrame(
      title: 'My room',
      subtitle: 'Assignment and utility information',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => controller.loadMyRoom(force: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final room = controller.room;
          final loading = controller.roomLoading;
          final error = controller.roomError;

          if (loading && room == null) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (room == null) {
            return CarmelitaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bed_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No Active Room Assignment',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error != null
                        ? 'Could not load your room assignment: $error'
                        : 'You are currently not assigned to a bed space. Please contact the dormitory management or administration office for assignment details.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => controller.loadMyRoom(force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhotoHero(
                image: AppAssets.room,
                title: 'Room ${room.number}',
                subtitle: 'Floor ${room.floor} • ${room.bedSpace}',
                height: 250,
              ),
              const SizedBox(height: 16),
              CarmelitaCard(
                child: Column(
                  children: [
                    InfoRow(
                      label: 'Room',
                      value: room.number,
                      icon: Icons.meeting_room_outlined,
                    ),
                    InfoRow(
                      label: 'Floor',
                      value: room.floor,
                      icon: Icons.layers_outlined,
                    ),
                    InfoRow(
                      label: 'Bed space',
                      value: room.bedSpace,
                      icon: Icons.bed_outlined,
                    ),
                    InfoRow(
                      label: 'Occupancy',
                      value: '${room.occupied} of ${room.capacity} occupied',
                      icon: Icons.groups_outlined,
                    ),
                    InfoRow(
                      label: 'Utilities',
                      value: room.utilitySummary,
                      icon: Icons.bolt_outlined,
                    ),
                    if (room.description.isNotEmpty)
                      InfoRow(
                        label: 'Description',
                        value: room.description,
                        icon: Icons.info_outline,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CarmelitaCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TenantCleaningSchedulePage(),
                  ),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      child: Icon(Icons.cleaning_services_outlined),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cleaning schedule',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'View your room rota or privately report a missed duty',
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CarmelitaCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TenantRoomInspectionsPage(),
                  ),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      child: Icon(Icons.fact_check_outlined),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room inspections',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'View inspection notices, findings, and follow-up',
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CarmelitaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Roommates (${room.roommateDetails.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Room ${room.number}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (room.roommateDetails.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No other residents assigned to this room yet.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      )
                    else
                      ...room.roommateDetails.map((mate) {
                        final initials = mate.name.trim().isNotEmpty
                            ? mate.name.trim().substring(0, 1).toUpperCase()
                            : 'R';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: mate.isSelf
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: .15)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              foregroundColor: mate.isSelf
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    mate.name,
                                    style: TextStyle(
                                      fontWeight: mate.isSelf
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (mate.isSelf) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'You',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: mate.bed.isNotEmpty
                                ? Text(
                                    mate.bed,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  )
                                : null,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  late final TableRefreshSubscription _subscription;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TenantController.instance.loadPayments();
      }
    });
    _subscription = TableRefreshSubscription(
      'tenant-payments',
      ['payments'],
      () {
        if (mounted) {
          TenantController.instance.loadPayments(force: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = TenantController.instance;
    return PageFrame(
      title: 'Payments & utilities',
      subtitle: 'Balances, due dates, and history',
      actions: [
        IconButton(
          tooltip: 'Refresh payments',
          icon: c.paymentsLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          onPressed:
              c.paymentsLoading ? null : () => c.loadPayments(force: true),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Upload payment proof',
        backgroundColor: const Color(0xFF627FA8),
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UploadPaymentProofPage()),
        ),
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Pay now'),
      ),
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final nextDue = c.nextDuePayment;
          final allPayments = c.payments;
          final duePayments = c.duePayments;
          final pendingPayments = c.pendingPayments;
          final verifiedPayments = c.verifiedPayments;
          final overdueCount = c.overduePayments.length;

          final displayedPayments = switch (_selectedFilter) {
            'due' => duePayments,
            'pending' => pendingPayments,
            'verified' => verifiedPayments,
            _ => allPayments,
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACCOUNT SUMMARY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              MutedDashboardGrid(
                compact: true,
                items: [
                  MutedDashboardItem(
                    label: 'Rent balance',
                    value: money(c.outstandingRent),
                    detail: 'Fixed by your contract',
                    icon: Icons.home_work_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  MutedDashboardItem(
                    label: 'Utility balance',
                    value: money(c.outstandingUtilities),
                    detail: 'Based on recorded usage',
                    icon: Icons.bolt_outlined,
                    color: const Color(0xFFD97706),
                  ),
                  MutedDashboardItem(
                    label: 'Outstanding',
                    value: money(c.outstandingBalance),
                    detail: overdueCount > 0
                        ? '$overdueCount overdue bill${overdueCount > 1 ? 's' : ''}'
                        : (c.outstandingBalance > 0
                            ? '${duePayments.length} unpaid bill${duePayments.length > 1 ? 's' : ''}'
                            : 'All clear'),
                    icon: Icons.account_balance_wallet_outlined,
                    color: overdueCount > 0
                        ? const Color(0xFFDC2626)
                        : (c.outstandingBalance > 0
                            ? const Color(0xFFAA8A45)
                            : const Color(0xFF56886B)),
                  ),
                  MutedDashboardItem(
                    label: 'Next due date',
                    value:
                        nextDue != null ? shortDate(nextDue.dueDate) : 'None',
                    detail: nextDue != null
                        ? (nextDue.isOverdue ? 'Overdue bill!' : nextDue.label)
                        : 'No pending bills',
                    icon: Icons.event_outlined,
                    color: nextDue?.isOverdue == true
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF627FA8),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      selected: _selectedFilter == 'all',
                      label: Text('All (${allPayments.length})'),
                      onSelected: (_) =>
                          setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedFilter == 'due',
                      label: Text('Due (${duePayments.length})'),
                      onSelected: (_) =>
                          setState(() => _selectedFilter = 'due'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedFilter == 'pending',
                      label: Text('Pending (${pendingPayments.length})'),
                      onSelected: (_) =>
                          setState(() => _selectedFilter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedFilter == 'verified',
                      label: Text('Verified (${verifiedPayments.length})'),
                      onSelected: (_) =>
                          setState(() => _selectedFilter = 'verified'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(
                'Payment records',
                trailing: c.paymentsLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              if (displayedPayments.isEmpty)
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No payment records',
                  message: _selectedFilter == 'all'
                      ? 'Invoices and billing statements will appear here.'
                      : 'No $_selectedFilter payments found.',
                )
              else
                ...displayedPayments.map((p) => _TenantPaymentCard(payment: p)),
            ],
          );
        },
      ),
    );
  }
}

class _TenantPaymentCard extends StatelessWidget {
  const _TenantPaymentCard({required this.payment});
  final Payment payment;

  IconData _categoryIcon(String category) =>
      switch (category.toLowerCase().trim()) {
        'rent' => Icons.home_work_outlined,
        'electricity' || 'electric' || 'power' => Icons.bolt_outlined,
        'water' => Icons.water_drop_outlined,
        'internet' || 'wifi' => Icons.wifi_outlined,
        _ => Icons.receipt_long_outlined,
      };

  Color _categoryColor(BuildContext context, String category) =>
      switch (category.toLowerCase().trim()) {
        'rent' => Theme.of(context).colorScheme.primary,
        'electricity' || 'electric' || 'power' => const Color(0xFFD97706),
        'water' => const Color(0xFF0284C7),
        'internet' || 'wifi' => const Color(0xFF7C3AED),
        _ => const Color(0xFF627FA8),
      };

  void _showReceiptDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final maxHeight = MediaQuery.sizeOf(dialogCtx).height * 0.85;
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_outlined,
                          color: Color(0xFF627FA8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${payment.label} Receipt',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (payment.reference != null &&
                      payment.reference!.isNotEmpty)
                    Text(
                      'Reference: ${payment.reference}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (payment.paymentMethod != null)
                    Text('Method: ${payment.paymentMethod}'),
                  if (payment.paidAt != null)
                    Text('Submitted: ${shortDate(payment.paidAt!)}'),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: FutureBuilder<String?>(
                        future: TenantController.instance
                            .paymentReceiptUrl(payment.receiptPath),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          final url = snapshot.data;
                          if (url == null || url.isEmpty) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 6),
                                    Text('Receipt photo unavailable'),
                                  ],
                                ),
                              ),
                            );
                          }
                          return InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.8,
                            maxScale: 3.5,
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Text('Could not load receipt photo'),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(context, payment.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: CarmelitaCard(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _categoryIcon(payment.category),
                      color: catColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          payment.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(payment.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    money(payment.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: payment.isOverdue
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Text(
                              'Overdue • Due ${shortDate(payment.dueDate)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade800,
                              ),
                            ),
                          )
                        : Text(
                            'Due ${shortDate(payment.dueDate)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                  ),
                ],
              ),
              if (payment.reference != null &&
                  payment.reference!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Ref: ${payment.reference}${payment.paymentMethod != null ? ' (${payment.paymentMethod})' : ''}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ],
              if (payment.paidAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Submitted ${shortDate(payment.paidAt!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
              if (payment.periodStart != null && payment.periodEnd != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Billing period: ${shortDate(payment.periodStart!)} – ${shortDate(payment.periodEnd!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                ),
              ],
              if (payment.hasRentOverride) ...[
                const SizedBox(height: 4),
                Text(
                  'Contract rent ${money(payment.contractAmount ?? payment.amount - payment.rentAdjustment)} → adjusted rent ${money(payment.amount)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
              if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  payment.notes!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (payment.reviewNotes != null &&
                  payment.reviewNotes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: payment.isRejected
                        ? Colors.red.shade50
                        : const Color(0xFF627FA8).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: payment.isRejected
                          ? Colors.red.shade200
                          : const Color(0xFF627FA8).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        payment.isRejected
                            ? Icons.error_outline
                            : Icons.info_outline,
                        size: 16,
                        color: payment.isRejected
                            ? Colors.red.shade700
                            : const Color(0xFF627FA8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          payment.reviewNotes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: payment.isRejected
                                ? Colors.red.shade800
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (payment.canSubmitProof ||
                  (payment.receiptPath != null &&
                      payment.receiptPath!.isNotEmpty)) ...[
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final canSubmit = payment.canSubmitProof;
                    final hasReceipt = payment.receiptPath != null &&
                        payment.receiptPath!.isNotEmpty;
                    final isNarrow = constraints.maxWidth < 280;

                    final submitBtn = FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              UploadPaymentProofPage(targetPayment: payment),
                        ),
                      ),
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      label: const Text('Submit proof'),
                    );

                    final receiptBtn = OutlinedButton.icon(
                      onPressed: () => _showReceiptDialog(context),
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: const Text('View receipt'),
                    );

                    if (canSubmit && hasReceipt) {
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            submitBtn,
                            const SizedBox(height: 8),
                            receiptBtn,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: submitBtn),
                          const SizedBox(width: 8),
                          Expanded(child: receiptBtn),
                        ],
                      );
                    }

                    if (canSubmit) {
                      return SizedBox(
                        width: double.infinity,
                        child: submitBtn,
                      );
                    }

                    return SizedBox(
                      width: double.infinity,
                      child: receiptBtn,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class UploadPaymentProofPage extends StatefulWidget {
  const UploadPaymentProofPage({this.targetPayment, super.key});
  final Payment? targetPayment;

  @override
  State<UploadPaymentProofPage> createState() => _UploadPaymentProofPageState();
}

class _UploadPaymentProofPageState extends State<UploadPaymentProofPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final ReceiptOcrService _ocrService = const ReceiptOcrService();

  late final TextEditingController amountController;
  final referenceController = TextEditingController();
  String method = 'GCash';
  Payment? selectedPayment;

  Uint8List? receiptBytes;
  String? receiptFileName;
  String? receiptMimeType;
  bool submitting = false;
  bool _scanningOcr = false;
  ReceiptExtractionResult? _lastOcrResult;

  @override
  void initState() {
    super.initState();
    selectedPayment = widget.targetPayment;
    amountController = TextEditingController(
      text: widget.targetPayment != null
          ? widget.targetPayment!.amount.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    referenceController.dispose();
    super.dispose();
  }

  Future<void> _showPhotoSource() async {
    if (submitting) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo with camera'),
              subtitle: const Text('Capture printed receipt or terminal slip'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Upload GCash or bank transfer screenshot'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickReceipt(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (!mounted) return;
        showAppSnackBar(context, 'Receipt image must be smaller than 5 MB.');
        return;
      }

      setState(() {
        receiptBytes = bytes;
        receiptFileName = picked.name;
        receiptMimeType = picked.mimeType ?? 'image/jpeg';
        _scanningOcr = true;
      });

      // Run on-device OCR scan to instantly capture amount, ref number, and method
      try {
        final result = await _ocrService.scanReceiptFile(picked.path);
        if (!mounted) return;

        setState(() {
          _scanningOcr = false;
          _lastOcrResult = result;

          if (result.referenceNumber != null &&
              result.referenceNumber!.isNotEmpty) {
            referenceController.text = result.referenceNumber!;
          }

          if (result.amount != null) {
            amountController.text = result.amount!.toStringAsFixed(2);
          }

          if (result.paymentMethod != null) {
            method = result.paymentMethod!;
          }
        });

        if (result.hasMatches) {
          final captured = <String>[];
          if (result.amount != null) {
            captured.add('Amount: ₱${result.amount!.toStringAsFixed(2)}');
          }
          if (result.referenceNumber != null) {
            captured.add('Ref: ${result.referenceNumber}');
          }
          if (result.paymentMethod != null) {
            captured.add(result.paymentMethod!);
          }
          showAppSnackBar(
            context,
            'Receipt auto-scanned! Captured: ${captured.join(' • ')}',
          );
        }
      } catch (_) {
        if (mounted) {
          setState(() => _scanningOcr = false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Could not open receipt image: $e');
    }
  }

  void _previewSelectedReceipt() {
    if (receiptBytes == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.8,
                maxScale: 3.5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    receiptBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final parsedAmount = double.tryParse(amountController.text.trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      showAppSnackBar(context, 'Enter a valid payment amount.');
      return;
    }

    if (receiptBytes == null && method != 'Cash') {
      showAppSnackBar(
        context,
        'Please attach your GCash or bank transfer screenshot.',
      );
      return;
    }

    setState(() => submitting = true);

    try {
      await TenantController.instance.submitPaymentProof(
        paymentId: selectedPayment?.id,
        amount: parsedAmount,
        method: method,
        reference: referenceController.text.trim(),
        receiptBytes: receiptBytes,
        fileName: receiptFileName,
        mimeType: receiptMimeType,
      );

      if (!mounted) return;
      showAppSnackBar(
        context,
        'Payment proof submitted for owner/caretaker review.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Failed to submit payment proof: $e');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unpaidBills = TenantController.instance.payments
        .where((p) => p.isDue || p.isRejected)
        .toList();

    return PageFrame(
      title: 'Upload payment proof',
      subtitle: 'Submit transaction receipt for verification',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.targetPayment != null) ...[
              SizedBox(
                width: double.infinity,
                child: CarmelitaCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        color: Color(0xFF627FA8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.targetPayment!.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Due ${shortDate(widget.targetPayment!.dueDate)} • ${money(widget.targetPayment!.amount)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      StatusPill(widget.targetPayment!.status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else if (unpaidBills.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedPayment?.id,
                decoration:
                    const InputDecoration(labelText: 'Select bill to pay'),
                items: unpaidBills
                    .map(
                      (p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(
                          '${p.label} (${money(p.amount)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPayment = unpaidBills.firstWhere(
                      (p) => p.id == value,
                      orElse: () => unpaidBills.first,
                    );
                    amountController.text =
                        selectedPayment!.amount.toStringAsFixed(2);
                  });
                },
              ),
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<String>(
              key: ValueKey(method),
              isExpanded: true,
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: const ['GCash', 'Maya', 'Bank transfer', 'Cash']
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => method = value ?? method),
            ),
            const SizedBox(height: 10),
            _PaymentMethodInstructionCard(method: method),
            const SizedBox(height: 14),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (PHP)',
                suffixIcon: _lastOcrResult?.amount != null
                    ? const Tooltip(
                        message: 'Auto-captured from receipt',
                        child: Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: Color(0xFF059669),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: referenceController,
              decoration: InputDecoration(
                labelText: 'Reference number',
                hintText: method == 'Cash'
                    ? 'Optional notes'
                    : 'e.g. 1002 9384 1029 (from receipt)',
                suffixIcon: _lastOcrResult?.referenceNumber != null
                    ? const Tooltip(
                        message: 'Auto-captured from receipt',
                        child: Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: Color(0xFF059669),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: receiptBytes != null
                  ? CarmelitaCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _previewSelectedReceipt,
                            child: Tooltip(
                              message: 'Tap to zoom receipt',
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      receiptBytes!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      borderRadius: const BorderRadius.only(
                                        bottomRight: Radius.circular(8),
                                        topLeft: Radius.circular(4),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  receiptFileName ?? 'Receipt selected',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: _showPhotoSource,
                                  child: const Text(
                                    'Change screenshot',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF627FA8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove photo',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              receiptBytes = null;
                              receiptFileName = null;
                              receiptMimeType = null;
                              _lastOcrResult = null;
                            }),
                          ),
                        ],
                      ),
                    )
                  : CarmelitaCard(
                      onTap: _showPhotoSource,
                      child: const Row(
                        children: [
                          Icon(Icons.add_photo_alternate_outlined),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Attach GCash or bank screenshot',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
            ),
            if (_scanningOcr) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF627FA8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Scanning receipt with OCR for amount & ref number...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_lastOcrResult != null &&
                _lastOcrResult!.hasMatches) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Auto-captured from receipt. Please verify details before submitting.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: submitting ? null : _submit,
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit proof for review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodInstructionCard extends StatelessWidget {
  const _PaymentMethodInstructionCard({required this.method});
  final String method;

  @override
  Widget build(BuildContext context) {
    final (icon, title, account, note) = switch (method.toLowerCase().trim()) {
      'gcash' => (
          Icons.account_balance_wallet_outlined,
          'GCash Account',
          '0917-123-4567 (Carmelita D.)',
          'Ensure the 13-digit reference number is clearly visible on your screenshot.'
        ),
      'maya' => (
          Icons.account_balance_wallet_outlined,
          'Maya Account',
          '0917-123-4567 (Carmelita D.)',
          'Ensure the reference number and date are clearly readable.'
        ),
      'bank transfer' || 'bank' => (
          Icons.account_balance_outlined,
          'BDO Bank Deposit / Transfer',
          '0012-3456-7890 (Carmelita Dormitory Management)',
          'Attach a clear photo or screenshot of the deposit slip or mobile banking transfer.'
        ),
      _ => (
          Icons.payments_outlined,
          'Cash at Front Desk',
          'Dormitory Administration Office',
          'Hand payment directly to the caretaker and request an official receipt slip.'
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF627FA8).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF627FA8).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF627FA8), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF2C4A6F),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  note,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.grey.shade700,
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

class TenantReportsHubPage extends StatelessWidget {
  const TenantReportsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TenantController.instance;
    if (!controller.concernsLoadedOnce && !controller.concernsLoading) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => controller.loadConcerns());
    }

    return PageFrame(
      title: 'Reports',
      subtitle: 'Maintenance and confidential concerns',
      onRefresh: () async {
        await Future.wait([
          controller.loadMaintenance(force: true),
          controller.loadConcerns(force: true),
        ]);
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SubmitMaintenancePage(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Report issue'),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final reports = controller.maintenance;
          final openMaintenance = reports
              .where(
                (report) => !{'Resolved', 'Cancelled'}.contains(report.status),
              )
              .length;
          final resolvedMaintenance =
              reports.where((report) => report.isResolved).length;
          final latestOpen = reports
              .where(
                (report) => !{'Resolved', 'Cancelled'}.contains(report.status),
              )
              .firstOrNull;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REPORT SUMMARY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              MutedDashboardGrid(
                compact: true,
                items: [
                  MutedDashboardItem(
                    label: 'Maintenance',
                    value: '${reports.length}',
                    detail: openMaintenance == 0
                        ? 'All resolved'
                        : '$openMaintenance in progress',
                    icon: Icons.build_outlined,
                    color: const Color(0xFFB47A52),
                  ),
                  MutedDashboardItem(
                    label: 'Resolved',
                    value: '$resolvedMaintenance',
                    detail: 'Completed issues',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF568F8E),
                  ),
                  MutedDashboardItem(
                    label: 'Confidential',
                    value: '${controller.concerns.length}',
                    detail: 'Private concerns',
                    icon: Icons.shield_outlined,
                    color: const Color(0xFF7D70A0),
                  ),
                ],
              ),
              if (latestOpen != null) ...[
                const SizedBox(height: 18),
                Text(
                  'ACTIVE MAINTENANCE ISSUE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1.1,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                CarmelitaCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MaintenanceReportsPage(),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB47A52).withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.handyman_outlined,
                          color: Color(0xFFB47A52),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${latestOpen.category} • ${latestOpen.location}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              latestOpen.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(latestOpen.status),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              const SectionTitle('Report options'),
              const SizedBox(height: 10),
              _hub(
                context,
                'Maintenance reports',
                'Report room or property issues and follow progress.',
                Icons.build_outlined,
                const Color(0xFFB47A52),
                const MaintenanceReportsPage(),
                badge: openMaintenance > 0 ? '$openMaintenance active' : null,
              ),
              const SizedBox(height: 12),
              _hub(
                context,
                'Confidential concern',
                'Securely report a rule, safety, or roommate concern.',
                Icons.shield_outlined,
                const Color(0xFF7D70A0),
                const ConfidentialConcernPage(),
              ),
              const SizedBox(height: 12),
              _hub(
                context,
                'Conduct & cases',
                'View conduct records published to you and submit responses.',
                Icons.gavel_outlined,
                const Color(0xFF7B6D62),
                const TenantConductCasesPage(),
              ),
              if (controller.concerns.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionTitle('Submitted confidential concerns'),
                const SizedBox(height: 10),
                ...controller.concerns.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CarmelitaCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: TimelineTile(
                        compact: true,
                        icon: Icons.shield_outlined,
                        color: const Color(0xFF7D70A0),
                        title: report.category,
                        subtitle:
                            '${report.summary}\n${shortDate(report.createdAt)}',
                        trailing: StatusPill(report.status),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _hub(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget page, {
    String? badge,
  }) {
    return CarmelitaCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .075),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null) ...[
              StatusPill(badge),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class MaintenanceReportsPage extends StatefulWidget {
  const MaintenanceReportsPage({super.key});

  @override
  State<MaintenanceReportsPage> createState() => _MaintenanceReportsPageState();
}

class _MaintenanceReportsPageState extends State<MaintenanceReportsPage> {
  final controller = TenantController.instance;
  late final TableRefreshSubscription subscription;
  String _selectedFilter = 'All';

  static const List<String> _filters = [
    'All',
    'Pending',
    'In Progress',
    'Resolved',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    controller.loadMaintenance();
    subscription = TableRefreshSubscription(
      'tenant-maintenance',
      ['maintenance_reports'],
      () => controller.loadMaintenance(force: true),
    );
  }

  @override
  void dispose() {
    subscription.dispose();
    super.dispose();
  }

  Future<void> _edit(MaintenanceReport report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubmitMaintenancePage(report: report),
      ),
    );
  }

  Future<void> _delete(MaintenanceReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel maintenance report?'),
        content: Text(
          'Cancel the ${report.category.toLowerCase()} report for '
          '${report.location}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep report'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel report'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await controller.deleteMaintenance(report.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Maintenance report cancelled.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _showReportDetails(BuildContext context, MaintenanceReport report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (report.urgency == 'High'
                                ? const Color(0xFFAA6870)
                                : report.urgency == 'Medium'
                                    ? const Color(0xFFB47A52)
                                    : const Color(0xFF627FA8))
                            .withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.build_outlined,
                        color: report.urgency == 'High'
                            ? const Color(0xFFAA6870)
                            : report.urgency == 'Medium'
                                ? const Color(0xFFB47A52)
                                : const Color(0xFF627FA8),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  report.location,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    StatusPill(report.status),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      '${report.urgency} priority',
                      icon: Icons.priority_high_rounded,
                    ),
                    StatusPill(
                      'Reported ${shortDate(report.createdAt)}',
                      icon: Icons.access_time_outlined,
                    ),
                    if (report.resolvedAt != null)
                      StatusPill(
                        'Resolved ${shortDate(report.resolvedAt!)}',
                        icon: Icons.check_circle_outline,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                CarmelitaCard(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    report.description,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
                if (report.photoPath != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'ATTACHED PHOTO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<String?>(
                    future: controller.maintenancePhotoUrl(report.photoPath),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CarmelitaCard(
                          child: SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }

                      final url = snapshot.data;
                      if (url == null) {
                        return const CarmelitaCard(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.broken_image_outlined),
                                SizedBox(width: 8),
                                Text('Photo could not be loaded.'),
                              ],
                            ),
                          ),
                        );
                      }

                      return InkWell(
                        onTap: () => _showFullScreenPhoto(context, url),
                        borderRadius: BorderRadius.circular(14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Image.network(
                                url,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.zoom_in,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'View full photo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
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
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'STAFF UPDATES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                if (report.staffNotes.isNotEmpty)
                  CarmelitaCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.assignment_ind_outlined,
                          size: 20,
                          color: Color(0xFF568F8E),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Caretaker / Staff remark:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                report.staffNotes,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  CarmelitaCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          report.isPending
                              ? Icons.hourglass_top_outlined
                              : (report.isResolved
                                  ? Icons.check_circle_outline
                                  : Icons.engineering_outlined),
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            report.isPending
                                ? 'Your request has been submitted and is queued for staff review.'
                                : (report.isResolved
                                    ? 'This issue has been marked as resolved.'
                                    : 'A caretaker has been assigned and is addressing this issue.'),
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                if (report.canEdit) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _edit(report);
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit report'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            foregroundColor:
                                Theme.of(sheetContext).colorScheme.error,
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _delete(report);
                          },
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Cancel request'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreenPhoto(BuildContext context, String photoUrl) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  tooltip: 'Close full view',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Maintenance reports',
      subtitle: 'Submitted issues and progress',
      onRefresh: () => controller.loadMaintenance(force: true),
      actions: [
        IconButton(
          tooltip: 'Refresh reports',
          onPressed: controller.maintenanceLoading
              ? null
              : () => controller.loadMaintenance(force: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SubmitMaintenancePage(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Report issue'),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final reports = controller.maintenance;
          final openCount = reports
              .where(
                (report) => !{'Resolved', 'Cancelled'}.contains(report.status),
              )
              .length;
          final highCount = reports
              .where(
                (report) =>
                    report.urgency == 'High' &&
                    !{'Resolved', 'Cancelled'}.contains(report.status),
              )
              .length;

          final pendingCount = reports.where((r) => r.isPending).length;
          final inProgressCount =
              reports.where((r) => r.isAssigned || r.isInProgress).length;
          final resolvedCount = reports.where((r) => r.isResolved).length;
          final cancelledCount = reports.where((r) => r.isCancelled).length;

          final filteredReports = switch (_selectedFilter) {
            'Pending' => reports.where((r) => r.isPending).toList(),
            'In Progress' =>
              reports.where((r) => r.isAssigned || r.isInProgress).toList(),
            'Resolved' => reports.where((r) => r.isResolved).toList(),
            'Cancelled' => reports.where((r) => r.isCancelled).toList(),
            _ => reports,
          };

          if (controller.maintenanceLoading && reports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.maintenanceError != null && reports.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 44),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load maintenance reports',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.maintenanceError!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => controller.loadMaintenance(force: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REPORT SUMMARY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              MutedDashboardGrid(
                compact: true,
                items: [
                  MutedDashboardItem(
                    label: 'Open reports',
                    value: '$openCount',
                    detail: 'Needs attention',
                    icon: Icons.build_outlined,
                    color: const Color(0xFFB47A52),
                  ),
                  MutedDashboardItem(
                    label: 'High priority',
                    value: '$highCount',
                    detail: 'Urgent issues',
                    icon: Icons.priority_high_rounded,
                    color: const Color(0xFFAA6870),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    final count = switch (filter) {
                      'Pending' => pendingCount,
                      'In Progress' => inProgressCount,
                      'Resolved' => resolvedCount,
                      'Cancelled' => cancelledCount,
                      _ => reports.length,
                    };

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$filter ($count)'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilter = filter);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedFilter == 'All'
                        ? 'All reports'
                        : '$_selectedFilter reports',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${filteredReports.length} ${filteredReports.length == 1 ? 'item' : 'items'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (controller.maintenanceError != null) ...[
                CarmelitaCard(
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 10),
                      Expanded(child: Text(controller.maintenanceError!)),
                      TextButton(
                        onPressed: () =>
                            controller.loadMaintenance(force: true),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (reports.isEmpty)
                const CarmelitaCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No maintenance reports yet. Use Report issue to submit one.',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filteredReports.isEmpty)
                CarmelitaCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const Icon(Icons.filter_list_off, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'No $_selectedFilter maintenance reports.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedFilter = 'All'),
                          child: const Text('Show all reports'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredReports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CarmelitaCard(
                      onTap: () => _showReportDetails(context, report),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: TimelineTile(
                        compact: true,
                        icon: Icons.build_outlined,
                        color: report.urgency == 'High'
                            ? const Color(0xFFAA6870)
                            : report.urgency == 'Medium'
                                ? const Color(0xFFB47A52)
                                : const Color(0xFF627FA8),
                        title: '${report.category} • ${report.location}',
                        subtitle:
                            '${report.description}\n${shortDate(report.createdAt)}'
                            '${report.photoPath != null ? ' • Photo attached' : ''}'
                            '${report.staffNotes.isNotEmpty ? ' • Staff updated' : ''}',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusPill(report.status),
                            if (report.canEdit) ...[
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                tooltip: 'Report actions',
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _edit(report);
                                  } else if (value == 'delete') {
                                    _delete(report);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined),
                                        SizedBox(width: 10),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline),
                                        SizedBox(width: 10),
                                        Text('Cancel request'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
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

class SubmitMaintenancePage extends StatefulWidget {
  const SubmitMaintenancePage({super.key, this.report});

  final MaintenanceReport? report;

  @override
  State<SubmitMaintenancePage> createState() => _SubmitMaintenancePageState();
}

class _SubmitMaintenancePageState extends State<SubmitMaintenancePage> {
  static const categories = [
    'Plumbing',
    'Electrical',
    'Furniture',
    'Air conditioning',
    'Locks & Keys',
    'Structural',
    'Other',
  ];

  static const urgencies = ['Low', 'Medium', 'High'];
  static const int _maximumPhotoBytes = 5 * 1024 * 1024;

  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController description;
  late String category;
  late String urgency;
  late String location;

  Uint8List? selectedPhotoBytes;
  String? selectedPhotoName;
  String? selectedPhotoMimeType;
  String? existingPhotoUrl;
  bool removeExistingPhoto = false;
  bool photoLoading = false;
  bool saving = false;

  bool get editing => widget.report != null;
  bool get hasExistingPhoto =>
      widget.report?.photoPath != null && !removeExistingPhoto;
  bool get hasPhoto => selectedPhotoBytes != null || hasExistingPhoto;

  List<String> get _availableLocations {
    final room = TenantController.instance.room;
    final locs = <String>[];
    if (room != null) {
      locs.add('Room ${room.number}');
      locs.add('Room ${room.number} • Bathroom');
    } else {
      locs.add('Room 204');
      locs.add('Room 204 • Bathroom');
    }
    locs.addAll(const [
      'Second-floor corridor',
      'First-floor hallway',
      'Kitchen / Dining area',
      'Laundry area',
      'Study lounge',
      'Ground floor lobby',
      'Other common area',
    ]);
    if (!locs.contains(location)) {
      locs.insert(0, location);
    }
    return locs;
  }

  @override
  void initState() {
    super.initState();
    final report = widget.report;
    final room = TenantController.instance.room;
    final defaultLocation = room != null ? 'Room ${room.number}' : 'Room 204';

    description = TextEditingController(text: report?.description ?? '');
    category = categories.contains(report?.category)
        ? report!.category
        : categories.first;
    urgency = urgencies.contains(report?.urgency) ? report!.urgency : 'Medium';
    location = report?.location ?? defaultLocation;

    if (report?.photoPath != null) {
      _loadExistingPhoto();
    }
  }

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPhoto() async {
    setState(() => photoLoading = true);
    try {
      final url = await TenantController.instance
          .maintenancePhotoUrl(widget.report?.photoPath);
      if (!mounted) return;
      setState(() => existingPhotoUrl = url);
    } catch (_) {
      if (!mounted) return;
      setState(() => existingPhotoUrl = null);
    } finally {
      if (mounted) setState(() => photoLoading = false);
    }
  }

  Future<void> _showPhotoSource() async {
    if (saving) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              subtitle: const Text('Use the device camera'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Select an existing photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );

      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        showAppSnackBar(context, 'The selected photo is empty.');
        return;
      }

      if (bytes.length > _maximumPhotoBytes) {
        if (!mounted) return;
        showAppSnackBar(context, 'Photo must be 5 MB or smaller.');
        return;
      }

      if (!mounted) return;
      setState(() {
        selectedPhotoBytes = bytes;
        selectedPhotoName = photo.name;
        selectedPhotoMimeType = photo.mimeType;
        removeExistingPhoto = false;
      });
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Unable to open the ${source == ImageSource.camera ? 'camera' : 'gallery'}: '
        '${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  void _removePhoto() {
    setState(() {
      selectedPhotoBytes = null;
      selectedPhotoName = null;
      selectedPhotoMimeType = null;
      if (widget.report?.photoPath != null) {
        removeExistingPhoto = true;
      }
    });
  }

  void _pickLocationFromFloorPlan() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select room on floor plan',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap a room or area on the interactive map to set it as your maintenance location.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              FloorPlanCanvas(
                onLocationSelected: (pickedRoom) {
                  setState(() {
                    location = pickedRoom;
                  });
                  Navigator.pop(sheetContext);
                  showAppSnackBar(
                      context, 'Selected $pickedRoom from floor plan.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final cleanDescription = description.text.trim();
    if (cleanDescription.length < 5) {
      showAppSnackBar(
          context, 'Please enter a description (at least 5 characters).');
      return;
    }

    setState(() => saving = true);

    try {
      if (editing) {
        await TenantController.instance.updateMaintenance(
          id: widget.report!.id,
          category: category,
          description: cleanDescription,
          location: location,
          urgency: urgency,
          photoBytes: selectedPhotoBytes,
          photoFileName: selectedPhotoName,
          photoMimeType: selectedPhotoMimeType,
          removePhoto: removeExistingPhoto && selectedPhotoBytes == null,
        );
      } else {
        await TenantController.instance.submitMaintenance(
          category: category,
          description: cleanDescription,
          location: location,
          urgency: urgency,
          photoBytes: selectedPhotoBytes,
          photoFileName: selectedPhotoName,
          photoMimeType: selectedPhotoMimeType,
        );
      }

      if (!mounted) return;
      showAppSnackBar(
        context,
        editing
            ? 'Maintenance report updated.'
            : 'Maintenance report submitted.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _photoSection(BuildContext context) {
    if (selectedPhotoBytes != null) {
      return _PhotoPreviewCard(
        image: Image.memory(
          selectedPhotoBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200,
        ),
        onChange: _showPhotoSource,
        onRemove: _removePhoto,
      );
    }

    if (hasExistingPhoto) {
      if (photoLoading) {
        return const CarmelitaCard(
          child: SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }

      if (existingPhotoUrl != null) {
        return _PhotoPreviewCard(
          image: Image.network(
            existingPhotoUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 140,
              child: Center(
                child: Icon(Icons.broken_image_outlined, size: 44),
              ),
            ),
          ),
          onChange: _showPhotoSource,
          onRemove: _removePhoto,
        );
      }
    }

    return CarmelitaCard(
      onTap: _showPhotoSource,
      child: const Row(
        children: [
          Icon(Icons.add_a_photo_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add photo (optional)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text('Take a photo or choose from gallery (max 5 MB)'),
              ],
            ),
          ),
          Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title:
            editing ? 'Edit maintenance report' : 'Submit maintenance report',
        subtitle: editing
            ? 'Update this report while it is still pending'
            : 'Describe the issue and exact location',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Issue category'),
                items: categories
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (value) => setState(() => category = value ?? category),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'Description',
                hint: 'Explain what is wrong and what you observed.',
                controller: description,
                maxLines: 4,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('location-$location'),
                      initialValue: location,
                      decoration: const InputDecoration(
                        labelText: 'Room / area',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                      ),
                      items: _availableLocations
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) =>
                              setState(() => location = value ?? location),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton.outlined(
                      tooltip: 'Pick on floor plan',
                      onPressed: saving ? null : _pickLocationFromFloorPlan,
                      icon: const Icon(Icons.map_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: urgency,
                decoration: InputDecoration(
                  labelText: 'Urgency',
                  helperText: urgency == 'High'
                      ? 'High: Urgent safety hazard or active water leak'
                      : urgency == 'Medium'
                          ? 'Medium: Issue affecting daily routine'
                          : 'Low: Minor cosmetic or low priority issue',
                ),
                items: urgencies
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (value) => setState(() => urgency = value ?? urgency),
              ),
              const SizedBox(height: 16),
              _photoSection(context),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : _save,
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(editing ? 'Save changes' : 'Submit report'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _PhotoPreviewCard extends StatelessWidget {
  const _PhotoPreviewCard({
    required this.image,
    required this.onChange,
    required this.onRemove,
  });

  final Widget image;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return CarmelitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: image,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChange,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Change photo'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove photo',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InteractiveFloorPlanPage extends StatelessWidget {
  const InteractiveFloorPlanPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
      title: 'Interactive floor plan',
      subtitle: 'Select an exact maintenance location',
      child: FloorPlanCanvas());
}

class _TenantLatestAnnouncementCard extends StatefulWidget {
  const _TenantLatestAnnouncementCard();

  @override
  State<_TenantLatestAnnouncementCard> createState() =>
      _TenantLatestAnnouncementCardState();
}

class _TenantLatestAnnouncementCardState
    extends State<_TenantLatestAnnouncementCard> {
  final _service = const AnnouncementService();
  AnnouncementRecord? _latest;
  late final TableRefreshSubscription _subscription;

  @override
  void initState() {
    super.initState();
    final cached = AnnouncementService.cachedAnnouncements('tenants');
    _latest = cached?.isNotEmpty == true ? cached!.first : null;
    _loadLatest();
    _subscription = TableRefreshSubscription(
      'tenant-dashboard-announcements',
      ['announcements'],
      _loadLatest,
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  Future<void> _loadLatest() async {
    try {
      final items = await _service.listAnnouncements(
        forceRefresh: true,
        audienceFilter: 'tenants',
      );
      if (mounted) {
        setState(() {
          _latest = items.isNotEmpty ? items.first : null;
        });
      }
    } catch (_) {
      // Keep cached on background error
    }
  }

  IconData _iconForCategory(String? category) =>
      switch (category?.toLowerCase()) {
        'emergency' => Icons.warning_amber_rounded,
        'maintenance' => Icons.build_outlined,
        'utility' => Icons.bolt_outlined,
        'billing' => Icons.payments_outlined,
        'event' => Icons.event_outlined,
        _ => Icons.campaign_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final item = _latest;
    if (item == null) {
      return AttentionCard(
        icon: Icons.campaign_outlined,
        title: 'No announcements',
        subtitle: 'No notices posted at this time.',
        status: 'Clear',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TenantAnnouncementsPage(),
          ),
        ),
      );
    }

    return AttentionCard(
      icon: _iconForCategory(item.category),
      title: item.title,
      subtitle: item.body,
      status: item.isPinned ? 'Pinned' : item.category.toUpperCase(),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TenantAnnouncementsPage(),
        ),
      ),
    );
  }
}

class TenantAnnouncementsPage extends StatefulWidget {
  const TenantAnnouncementsPage({super.key});

  @override
  State<TenantAnnouncementsPage> createState() =>
      _TenantAnnouncementsPageState();
}

class _TenantAnnouncementsPageState extends State<TenantAnnouncementsPage> {
  final _service = const AnnouncementService();
  List<AnnouncementRecord>? _announcements;
  bool _loading = true;
  String? _errorMessage;
  late final TableRefreshSubscription _subscription;

  String _selectedCategory = 'all';
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

  @override
  void initState() {
    super.initState();
    _announcements = AnnouncementService.cachedAnnouncements('tenants');
    _loading = _announcements == null;
    _fetchAnnouncements(showSpinner: _announcements == null);
    _subscription = TableRefreshSubscription(
      'tenant-announcements-page',
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
      final items = await _service.listAnnouncements(
        forceRefresh: true,
        audienceFilter: 'tenants',
      );
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
          _errorMessage = 'Failed to load notices: $e';
        });
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

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasActive = _selectedCategory != 'all';
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
                            setState(() => _selectedCategory = 'all');
                            setSheetState(() {});
                          },
                          child: const Text('Reset'),
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
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Apply Filter'),
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
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final inTitle = item.title.toLowerCase().contains(q);
        final inBody = item.body.toLowerCase().contains(q);
        if (!inTitle && !inBody) return false;
      }
      return true;
    }).toList();

    final hasActiveFilter = _selectedCategory != 'all';

    return PageFrame(
      title: 'Announcements',
      subtitle: 'Dormitory notices and updates',
      actions: [
        IconButton(
          tooltip: 'Refresh board',
          onPressed: () => _fetchAnnouncements(showSpinner: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notices...',
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
                  'Filter:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.taupe,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                InputChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_categoryTitle(_selectedCategory)),
                  avatar: Icon(_categoryIcon(_selectedCategory), size: 14),
                  onDeleted: () => setState(() => _selectedCategory = 'all'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: () => setState(() => _selectedCategory = 'all'),
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
              message: _searchQuery.isNotEmpty || _selectedCategory != 'all'
                  ? 'No notices match your filter.'
                  : 'There are no announcements posted at this time.',
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
                      Wrap(
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class TenantMessagesPage extends StatefulWidget {
  const TenantMessagesPage({super.key});

  @override
  State<TenantMessagesPage> createState() => _TenantMessagesPageState();
}

class _TenantMessagesPageState extends State<TenantMessagesPage> {
  @override
  void initState() {
    super.initState();
    final uid = SessionController.instance.currentUser?.id ?? '';
    MessagingController.instance.loadTenantConversation(uid);
  }

  @override
  Widget build(BuildContext context) {
    final messaging = MessagingController.instance;

    return PageFrame(
      title: 'Messages',
      subtitle: 'Official Dormitory Communication',
      child: AnimatedBuilder(
        animation: messaging,
        builder: (context, _) {
          final lastMsg = messaging.activeMessages.isNotEmpty
              ? messaging.activeMessages.last
              : null;
          final previewText = lastMsg?.body ??
              messaging.activeConversation?.lastMessagePreview ??
              'Tap to chat with Dormitory Management';

          return ConversationListCard(
            name: 'Caretaker / Management',
            role: 'Owner & Caretaker',
            lastMessage: lastMsg,
            lastMessageText: previewText,
            lastMessageTime:
                lastMsg?.sentAt ?? messaging.activeConversation?.lastMessageAt,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TenantConversationPage(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TenantConversationPage extends StatefulWidget {
  const TenantConversationPage({super.key});

  @override
  State<TenantConversationPage> createState() => _TenantConversationPageState();
}

class _TenantConversationPageState extends State<TenantConversationPage> {
  final message = TextEditingController();

  @override
  void initState() {
    super.initState();
    final uid = SessionController.instance.currentUser?.id ?? '';
    MessagingController.instance.loadTenantConversation(uid, openThread: true);
  }

  @override
  void dispose() {
    message.dispose();
    MessagingController.instance.closeActiveConversation();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = message.text.trim();
    if (text.isEmpty) return;
    message.clear();
    await MessagingController.instance.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final messaging = MessagingController.instance;

    return PageFrame(
      title: 'Dormitory Management',
      subtitle: 'Owner & Caretaker',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: AnimatedBuilder(
          animation: messaging,
          builder: (context, _) {
            final messagesList = messaging.activeMessages;

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
                              'No messages yet. Send a message to start chatting with dormitory management.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Column(
                          children: messagesList.map((item) {
                            final isMe = item.senderRole == 'tenant';
                            return Align(
                              alignment: isMe
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
                                  color: isMe
                                      ? const Color(0xFF627FA8)
                                          .withValues(alpha: .10)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: .55),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft: Radius.circular(isMe ? 15 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
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
                    hintText: 'Write a message to management...',
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
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

class TenantPresencePage extends StatefulWidget {
  const TenantPresencePage({super.key});

  @override
  State<TenantPresencePage> createState() => _TenantPresencePageState();
}

class _TenantPresencePageState extends State<TenantPresencePage> {
  TableRefreshSubscription? _subscription;
  Map<String, dynamic> _monitoringStatus = const {'registered': false};
  bool _monitoringStatusLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TenantController.instance.loadCurfewRequests();
        TenantController.instance.loadGateEvents();
        _loadMonitoringStatus(sync: true);
      }
    });
    _subscription = TableRefreshSubscription(
      'tenant-curfew-presence',
      ['curfew_requests', 'gate_events', 'tenant_details'],
      () {
        if (mounted) {
          TenantController.instance.loadCurfewRequests(force: true);
          TenantController.instance.loadGateEvents(force: true);
        }
      },
    );
  }

  Future<void> _loadMonitoringStatus({bool sync = false}) async {
    if (_monitoringStatusLoading) return;
    setState(() => _monitoringStatusLoading = true);
    if (sync) {
      await TripwireGeofenceService.instance.syncPending();
    }
    final status = await TripwireGeofenceService.instance.status();
    if (!mounted) return;
    setState(() {
      _monitoringStatus = status;
      _monitoringStatusLoading = false;
    });
  }

  @override
  void dispose() {
    _subscription?.dispose();
    super.dispose();
  }

  Future<void> _confirmCancel(CurfewRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cancel curfew request?'),
        content: Text(
          'Are you sure you want to cancel your exception request to ${request.destination}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
            ),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await TenantController.instance.cancelCurfewRequest(request.id);
        if (mounted) {
          showAppSnackBar(context, 'Curfew request cancelled.');
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, 'Failed to cancel: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = TenantController.instance;

    return PageFrame(
      title: 'Curfew',
      subtitle: 'Automatic boundary crossings and exception requests',
      maxWidth: 720,
      actions: [
        IconButton(
          tooltip: 'Refresh presence & requests',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            controller.loadCurfewRequests(force: true);
            controller.loadGateEvents(force: true);
            _loadMonitoringStatus(sync: true);
          },
        ),
      ],
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final requests = controller.curfewRequests;
          final loading = controller.curfewLoading;
          final error = controller.curfewError;

          final events = controller.gateEvents;
          final monitoringActive = _monitoringStatus['registered'] == true;
          final pendingTransitions =
              (_monitoringStatus['pendingCount'] as num?)?.toInt() ?? 0;

          final isInside = controller.isInside;
          final isOutside = controller.isOutside;
          final isUnavailable = controller.isUnavailable;

          final statusLabel = isInside
              ? 'Last crossing: IN'
              : (isOutside ? 'Last crossing: OUT' : 'No crossing recorded');
          final statusPillText =
              isInside ? 'IN' : (isOutside ? 'OUT' : 'NO EVENT');
          final statusColor = isInside
              ? const Color(0xFF56886B)
              : (isOutside ? const Color(0xFFC77800) : const Color(0xFFB03A2E));
          final statusIcon = isInside
              ? Icons.location_on_outlined
              : (isOutside
                  ? Icons.directions_walk_outlined
                  : Icons.location_disabled_outlined);
          final lastEventText = controller.lastGateEventAt != null
              ? 'Recorded ${shortDate(controller.lastGateEventAt!)} at ${timeText(controller.lastGateEventAt!)} • Automatic GPS tripwire'
              : (isUnavailable
                  ? 'No automatic boundary event is available yet'
                  : 'Automatic tripwire monitoring');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkInProgressNotice(),
              const SizedBox(height: 16),
              const TenantEmployeeCurfewProfileCard(),
              const SizedBox(height: 16),
              Text(
                'CURFEW STATUS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: CarmelitaCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 330;
                          final copy = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'LAST RECORDED CROSSING',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                statusLabel,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(lastEventText),
                            ],
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          statusColor.withValues(alpha: 0.12),
                                      foregroundColor: statusColor,
                                      child: Icon(statusIcon),
                                    ),
                                    const SizedBox(width: 12),
                                    StatusPill(statusPillText),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                copy,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                    statusColor.withValues(alpha: 0.12),
                                foregroundColor: statusColor,
                                child: Icon(statusIcon),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: copy),
                              const SizedBox(width: 10),
                              StatusPill(statusPillText),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (monitoringActive
                                  ? const Color(0xFF56886B)
                                  : const Color(0xFFC77800))
                              .withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              monitoringActive
                                  ? Icons.sensors_rounded
                                  : Icons.sensors_off_rounded,
                              color: monitoringActive
                                  ? const Color(0xFF56886B)
                                  : const Color(0xFFC77800),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    monitoringActive
                                        ? 'Automatic logging active'
                                        : 'Automatic logging needs attention',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    pendingTransitions > 0
                                        ? '$pendingTransitions crossing event(s) waiting to sync.'
                                        : monitoringActive
                                            ? 'Crossings are monitored automatically. You can also manually check in below.'
                                            : 'Enable Always / Allow all the time location access.',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh monitoring status',
                              onPressed: _monitoringStatusLoading
                                  ? null
                                  : () => _loadMonitoringStatus(sync: true),
                              icon: _monitoringStatusLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: controller.checkingPresence
                              ? null
                              : () async {
                                  try {
                                    final result = await controller
                                        .performGeofenceCheckIn();
                                    if (context.mounted) {
                                      final msg = switch (result.status) {
                                        'Verified' => result.errorMessage !=
                                                null
                                            ? 'Presence confirmed (${result.direction == "IN" ? "Inside perimeter" : "Outside perimeter"}), but server sync warning: ${result.errorMessage}'
                                            : 'Presence confirmed: ${result.direction == "IN" ? "Inside perimeter" : "Outside perimeter"}',
                                        'Flagged' =>
                                          'Presence check recorded (Flagged: curfew hours active)',
                                        _ =>
                                          'Location check failed: ${result.errorMessage ?? (result.failureReason.name != 'none' ? result.failureReason.name : 'Signal error')}',
                                      };
                                      showAppSnackBar(context, msg);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showAppSnackBar(
                                        context,
                                        'Location check error: $e',
                                      );
                                    }
                                  }
                                },
                          icon: controller.checkingPresence
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded, size: 18),
                          label: Text(
                            controller.checkingPresence
                                ? 'Checking boundary...'
                                : 'Manual Check-in / Verify Location',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!monitoringActive) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB03A2E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFB03A2E).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFB03A2E)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Automatic logging needs attention',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB03A2E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Turn on location services and grant Always / Allow all the time access so crossings can be logged while CarmeLink is closed.',
                              style: TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      GeofenceService.openAppSettings(),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: const Color(0xFFB03A2E),
                                    side: const BorderSide(
                                      color: Color(0xFFB03A2E),
                                    ),
                                  ),
                                  icon: const Icon(Icons.settings_outlined,
                                      size: 14),
                                  label: const Text('App Permissions',
                                      style: TextStyle(fontSize: 12)),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      GeofenceService.openLocationSettings(),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: const Color(0xFFB03A2E),
                                    side: const BorderSide(
                                      color: Color(0xFFB03A2E),
                                    ),
                                  ),
                                  icon: const Icon(Icons.gps_fixed, size: 14),
                                  label: const Text('Turn On GPS',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              MutedDashboardGrid(
                compact: true,
                items: [
                  const MutedDashboardItem(
                    label: 'Geofence boundary',
                    value: 'Configured zone',
                    detail: 'Server-managed tripwire boundary',
                    icon: Icons.location_searching_outlined,
                    color: Color(0xFF56886B),
                  ),
                  MutedDashboardItem(
                    label: 'Detection signal',
                    value: monitoringActive ? 'Active' : 'Needs attention',
                    detail: monitoringActive
                        ? 'Native background monitoring'
                        : 'Check Always location access',
                    icon: !monitoringActive
                        ? Icons.location_disabled_outlined
                        : Icons.gps_fixed_outlined,
                    color: !monitoringActive
                        ? const Color(0xFFB03A2E)
                        : const Color(0xFF627FA8),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              MutedActionGrid(
                items: [
                  MutedActionItem(
                    label: 'Curfew exception',
                    detail: 'Late return / overnight leave',
                    color: const Color(0xFFC77800),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TenantCurfewExceptionPage(),
                      ),
                    ),
                    icon: Icons.access_time_outlined,
                  ),
                  MutedActionItem(
                    label: 'Visitor request',
                    detail: 'Register a visitor',
                    color: const Color(0xFF568F8E),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VisitorRequestPage(),
                      ),
                    ),
                    icon: Icons.person_add_alt_outlined,
                  ),
                  MutedActionItem(
                    label: 'Dormitory rules',
                    detail: 'Guidelines & policies',
                    color: const Color(0xFF7D70A0),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DormitoryRulesPage(),
                      ),
                    ),
                    icon: Icons.rule_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SectionTitle(
                'Curfew & leave requests',
                trailing: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TenantCurfewExceptionPage(),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New request'),
                ),
              ),
              const SizedBox(height: 8),
              if (loading && requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null && requests.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: CarmelitaCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(error, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () =>
                              controller.loadCurfewRequests(force: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (requests.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: CarmelitaCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFC77800),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.nightlife_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No exception requests',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Standard curfew is 10:00 PM. Tap "New request" for late return or overnight leave.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...requests.map(
                  (r) => _CurfewRequestCard(
                    request: r,
                    onCancel: () => _confirmCancel(r),
                  ),
                ),
              const SizedBox(height: 22),
              const SectionTitle('Recent presence records'),
              const SizedBox(height: 10),
              if (events.isEmpty)
                const SizedBox(
                  width: double.infinity,
                  child: CarmelitaCard(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('No presence records recorded yet.'),
                    ),
                  ),
                )
              else
                ...events.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: CarmelitaCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: TimelineTile(
                          compact: true,
                          icon: e.isUnavailable
                              ? Icons.location_disabled_outlined
                              : (e.direction == 'IN'
                                  ? Icons.login_rounded
                                  : Icons.logout_rounded),
                          color: e.isUnavailable
                              ? const Color(0xFFB03A2E)
                              : (e.direction == 'IN'
                                  ? const Color(0xFF56886B)
                                  : const Color(0xFF627FA8)),
                          title: e.isUnavailable
                              ? 'Location check unavailable'
                              : (e.direction == 'IN'
                                  ? 'Entered dormitory perimeter'
                                  : 'Exited dormitory perimeter'),
                          subtitle:
                              '${shortDate(e.time)} • ${timeText(e.time)} • ${e.verification}${e.notes != null && e.notes!.isNotEmpty ? ' (${e.notes})' : ''}',
                          trailing: StatusPill(e.status),
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

class _CurfewRequestCard extends StatelessWidget {
  const _CurfewRequestCard({
    required this.request,
    required this.onCancel,
  });

  final CurfewRequest request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: CarmelitaCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              request.isOvernightLeave
                                  ? Icons.hotel_outlined
                                  : Icons.nightlight_outlined,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              request.requestTypeLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          request.destination,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(request.statusLabel),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                request.reason,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flight_takeoff_outlined, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Departure: ',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${shortDate(request.departureTime)} ${timeText(request.departureTime)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.flight_land_outlined, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Expected return: ',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${shortDate(request.expectedReturnTime)} ${timeText(request.expectedReturnTime)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (request.guardianNotes != null &&
                  request.guardianNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Guardian note: ${request.guardianNotes!}',
                  style: const TextStyle(
                      fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
              if (request.staffNotes != null &&
                  request.staffNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Staff note: ${request.staffNotes!}',
                  style: const TextStyle(
                      fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
              if (request.canCancel) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancel request'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TenantCurfewExceptionPage extends StatefulWidget {
  const TenantCurfewExceptionPage({super.key});

  @override
  State<TenantCurfewExceptionPage> createState() =>
      _TenantCurfewExceptionPageState();
}

class _TenantCurfewExceptionPageState extends State<TenantCurfewExceptionPage> {
  final _destinationController = TextEditingController();
  final _reasonController = TextEditingController();

  String _requestType = 'late_return';
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 2));
  DateTime _expectedReturnTime = DateTime.now().add(const Duration(hours: 12));
  bool _submitting = false;

  @override
  void dispose() {
    _destinationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({
    required bool isDeparture,
  }) async {
    final current = isDeparture ? _departureTime : _expectedReturnTime;
    final initialDate = current;
    final firstDate = DateTime.now().subtract(const Duration(days: 1));
    final lastDate = DateTime.now().add(const Duration(days: 90));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isDeparture) {
        _departureTime = combined;
        if (_expectedReturnTime.isBefore(_departureTime)) {
          _expectedReturnTime = _departureTime.add(const Duration(hours: 4));
        }
      } else {
        _expectedReturnTime = combined;
      }
    });
  }

  Future<void> _submit() async {
    final destination = _destinationController.text.trim();
    final reason = _reasonController.text.trim();

    if (destination.isEmpty) {
      showAppSnackBar(context, 'Please enter your destination.');
      return;
    }

    if (reason.isEmpty) {
      showAppSnackBar(context, 'Please enter the reason for your request.');
      return;
    }

    if (!_expectedReturnTime.isAfter(_departureTime)) {
      showAppSnackBar(
        context,
        'Expected return time must be after departure time.',
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await TenantController.instance.submitCurfewRequest(
        destination: destination,
        reason: reason,
        departureTime: _departureTime,
        expectedReturnTime: _expectedReturnTime,
        requestType: _requestType,
      );

      if (mounted) {
        final message = _requestType == 'late_return'
            ? 'Late return request submitted directly for caretaker review!'
            : 'Overnight leave submitted! Awaiting guardian approval.';
        showAppSnackBar(context, message);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Failed to submit request: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLate = _requestType == 'late_return';

    return PageFrame(
      title: 'Curfew exception',
      subtitle: 'Request late return or overnight leave',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkInProgressNotice(
              message:
                  'Work in progress: requests are available, but automated curfew and geofence behavior is still undergoing physical-device validation.',
            ),
            const SizedBox(height: 16),
            Text(
              'REQUEST TYPE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _requestType = 'late_return'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLate
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLate
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.nightlight_outlined,
                                size: 18,
                                color: isLate
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Late Return',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isLate
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Direct Caretaker approval',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        setState(() => _requestType = 'overnight_leave'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !isLate
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !isLate
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.hotel_outlined,
                                size: 18,
                                color: !isLate
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Overnight Leave',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: !isLate
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Guardian endorsement first',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CarmelitaCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isLate
                              ? const Color(0xFF56886B)
                              : Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLate ? Icons.bolt_outlined : Icons.shield_outlined,
                      color: isLate
                          ? const Color(0xFF56886B)
                          : Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLate
                              ? 'Fast-track Caretaker Approval'
                              : 'Two-tier Guardian & Caretaker Approval',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLate
                              ? 'Forwarded directly to the caretaker / owner on duty for prompt staff review. Your guardian will see this on their read-only curfew activity log.'
                              : 'Since you will be off-premises overnight, your registered guardian must review and approve this first before caretaker sign-off.',
                          style: const TextStyle(fontSize: 12, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'REQUEST DETAILS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 10),
            LabeledField(
              label: 'Destination',
              controller: _destinationController,
              hint:
                  'e.g., Home (Batangas), University Library, Friend\'s House',
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Reason for request',
              controller: _reasonController,
              hint: 'e.g., Family weekend gathering, Overnight project study',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'SCHEDULE & TIMING',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 10),
            CarmelitaCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _DateTimeTile(
                    title: 'Departure date & time',
                    dateTime: _departureTime,
                    icon: Icons.flight_takeoff_outlined,
                    onTap: () => _pickDateTime(isDeparture: true),
                  ),
                  const Divider(height: 20),
                  _DateTimeTile(
                    title: 'Expected return date & time',
                    dateTime: _expectedReturnTime,
                    icon: Icons.flight_land_outlined,
                    onTap: () => _pickDateTime(isDeparture: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isLate
                            ? 'Submit late return request'
                            : 'Submit overnight leave request',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.title,
    required this.dateTime,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final DateTime dateTime;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${shortDate(dateTime)} at ${timeText(dateTime)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Change', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

typedef GateCurfewPage = TenantPresencePage;

class VisitorRequestPage extends StatefulWidget {
  const VisitorRequestPage({super.key});

  @override
  State<VisitorRequestPage> createState() => _VisitorRequestPageState();
}

class _VisitorRequestPageState extends State<VisitorRequestPage> {
  final name = TextEditingController();
  final relation = TextEditingController();
  final purpose = TextEditingController();
  final contact = TextEditingController();

  late DateTime schedule;
  late DateTime expectedDepartureAt;
  late final TableRefreshSubscription _subscription;

  bool saving = false;
  VisitorRequest? editingRequest;

  Future<void> _pickArrival() async {
    final now = DateTime.now();
    final firstDate = VisitorPolicy.minimumVisitDate(now: now);
    final initialDate = schedule.isBefore(firstDate)
        ? firstDate
        : VisitorPolicy.dateOnly(schedule);

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(schedule),
    );
    if (time == null || !mounted) return;

    final arrival =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final issue = VisitorPolicy.validateArrival(arrival, now: now);
    if (issue != null) {
      showAppSnackBar(context, issue);
      return;
    }

    setState(() {
      schedule = arrival;
      expectedDepartureAt = VisitorPolicy.defaultDeparture(arrival);
    });
  }

  Future<void> _pickDeparture() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(expectedDepartureAt),
    );
    if (time == null || !mounted) return;

    final departure = DateTime(
      schedule.year,
      schedule.month,
      schedule.day,
      time.hour,
      time.minute,
    );

    final issue = VisitorPolicy.validateDeparture(schedule, departure);
    if (issue != null) {
      showAppSnackBar(context, issue);
      return;
    }

    setState(() => expectedDepartureAt = departure);
  }

  void _edit(VisitorRequest request) {
    setState(() {
      editingRequest = request;
      name.text = request.visitorName;
      relation.text = request.relationship;
      purpose.text = request.purpose;
      contact.text = request.contactNumber;
      schedule = request.schedule;
      expectedDepartureAt = request.expectedDepartureAt ??
          VisitorPolicy.defaultDeparture(request.schedule);
    });
  }

  void _resetForm() {
    setState(() {
      editingRequest = null;
      name.clear();
      relation.clear();
      purpose.clear();
      contact.clear();
      schedule = VisitorPolicy.defaultArrival();
      expectedDepartureAt = VisitorPolicy.defaultDeparture(schedule);
    });
  }

  Future<void> _showHistory(VisitorRequest request) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${request.visitorName} history'),
          content: SizedBox(
            width: 460,
            child: FutureBuilder<List<VisitorEvent>>(
              future: TenantController.instance.loadVisitorEvents(request.id),
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
  void initState() {
    super.initState();
    schedule = VisitorPolicy.defaultArrival();
    expectedDepartureAt = VisitorPolicy.defaultDeparture(schedule);

    TenantController.instance.loadVisitors();
    _subscription = TableRefreshSubscription(
      'tenant-visitors',
      const ['visitor_requests', 'visitor_events'],
      () => TenantController.instance.loadVisitors(force: true),
    );
  }

  @override
  void dispose() {
    name.dispose();
    relation.dispose();
    purpose.dispose();
    contact.dispose();
    _subscription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Visitor request',
      subtitle: 'Advance registration required',
      onRefresh: () => TenantController.instance.loadVisitors(force: true),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CarmelitaCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Submit the request at least one calendar day before the visit. '
                      'Visiting hours are 9:00 AM–9:00 PM, and visitors must leave on the same day.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'VISITOR DETAILS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1.3,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 10),
            LabeledField(
              label: 'Visitor name',
              controller: name,
              hint: 'Full name',
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Relationship',
              controller: relation,
              hint: 'Parent, guardian, sibling, etc.',
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Purpose',
              controller: purpose,
              hint: 'Reason for the visit',
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Visitor contact number',
              controller: contact,
              hint: 'e.g. 0917 123 4567',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            CarmelitaCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  InfoRow(
                    label: 'Expected arrival',
                    value: '${shortDate(schedule)} • ${timeText(schedule)}',
                    icon: Icons.event_outlined,
                  ),
                  const SizedBox(height: 8),
                  InfoRow(
                    label: 'Expected departure',
                    value:
                        '${shortDate(expectedDepartureAt)} • ${timeText(expectedDepartureAt)}',
                    icon: Icons.schedule_outlined,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Advance registration • 9:00 AM–9:00 PM visiting hours • same-day departure only.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickArrival,
                        icon: const Icon(Icons.event_outlined),
                        label: const Text('Choose arrival'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickDeparture,
                        icon: const Icon(Icons.schedule_outlined),
                        label: const Text('Choose departure'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (name.text.trim().isEmpty ||
                            relation.text.trim().isEmpty ||
                            purpose.text.trim().isEmpty ||
                            contact.text.trim().length < 7) {
                          showAppSnackBar(
                            context,
                            'Complete all visitor details with a valid contact number.',
                          );
                          return;
                        }

                        final policyError = VisitorPolicy.validateVisit(
                          schedule: schedule,
                          expectedDepartureAt: expectedDepartureAt,
                          now: DateTime.now(),
                        );
                        if (policyError != null) {
                          showAppSnackBar(context, policyError);
                          return;
                        }

                        setState(() => saving = true);
                        try {
                          final editing = editingRequest;
                          if (editing == null) {
                            await TenantController.instance.submitVisitor(
                              visitorName: name.text.trim(),
                              relationship: relation.text.trim(),
                              purpose: purpose.text.trim(),
                              contactNumber: contact.text.trim(),
                              schedule: schedule,
                              expectedDepartureAt: expectedDepartureAt,
                            );
                          } else {
                            await TenantController.instance.updateVisitor(
                              request: editing,
                              visitorName: name.text.trim(),
                              relationship: relation.text.trim(),
                              purpose: purpose.text.trim(),
                              contactNumber: contact.text.trim(),
                              schedule: schedule,
                              expectedDepartureAt: expectedDepartureAt,
                            );
                          }

                          if (context.mounted) {
                            showAppSnackBar(
                              context,
                              editing == null
                                  ? 'Visitor request submitted.'
                                  : 'Visitor request updated.',
                            );
                            _resetForm();
                          }
                        } catch (error) {
                          if (context.mounted) {
                            showAppSnackBar(
                              context,
                              'Unable to submit visitor request: $error',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                child: Text(
                  saving
                      ? 'Saving…'
                      : editingRequest == null
                          ? 'Submit visitor request'
                          : 'Save changes',
                ),
              ),
            ),
            if (editingRequest != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: saving ? null : _resetForm,
                  child: const Text('Discard changes'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const SectionTitle(
              'Request history',
              subtitle: 'Live approval and visit status',
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: TenantController.instance,
              builder: (context, _) {
                final controller = TenantController.instance;

                if (controller.visitorsLoading && controller.visitors.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.visitorsError != null &&
                    controller.visitors.isEmpty) {
                  return EmptyState(
                    icon: Icons.error_outline,
                    title: 'Unable to load visitor requests',
                    message: controller.visitorsError!,
                  );
                }

                if (controller.visitors.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No visitor requests',
                    message: 'Submitted requests will appear here.',
                  );
                }

                return Column(
                  children: controller.visitors
                      .map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CarmelitaCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        request.visitorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    StatusPill(request.statusLabel),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(request.purpose),
                                Text(
                                  'Arrival: ${shortDate(request.schedule)} • ${timeText(request.schedule)}',
                                ),
                                if (request.expectedDepartureAt != null)
                                  Text(
                                    'Departure: ${timeText(request.expectedDepartureAt!)}',
                                  ),
                                if (request.contactNumber.isNotEmpty)
                                  Text('Contact: ${request.contactNumber}'),
                                if (request.reviewNote?.isNotEmpty == true)
                                  Text('Staff note: ${request.reviewNote}'),
                                TextButton.icon(
                                  onPressed: () => _showHistory(request),
                                  icon: const Icon(Icons.history_rounded),
                                  label: const Text('View history'),
                                ),
                                if (request.isPending) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => _edit(request),
                                        child: const Text('Edit'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () async {
                                          try {
                                            await controller
                                                .cancelVisitor(request);
                                          } catch (error) {
                                            if (context.mounted) {
                                              showAppSnackBar(
                                                context,
                                                'Cancellation failed: $error',
                                              );
                                            }
                                          }
                                        },
                                        child: const Text('Cancel request'),
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
          ],
        ),
      ),
    );
  }
}

class ConfidentialConcernPage extends StatefulWidget {
  const ConfidentialConcernPage({super.key});

  @override
  State<ConfidentialConcernPage> createState() =>
      _ConfidentialConcernPageState();
}

class _ConfidentialConcernPageState extends State<ConfidentialConcernPage> {
  String category = 'Safety concern';
  final details = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    TenantController.instance.loadConcerns();
  }

  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Confidential concern',
      subtitle: 'Safety, rules, or roommate concerns',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CONFIDENTIAL REPORT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1.3,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            CarmelitaCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7D70A0).withValues(alpha: .075),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_outline,
                      color: Color(0xFF7D70A0), size: 20),
                ),
                title: const Text(
                  'Confidential handling',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                subtitle: const Text(
                  'Your report is stored in a restricted record. In this '
                  'phase, only you can view your submitted history.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              isDense: true,
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                'Safety concern',
                'Rule violation',
                'Roommate concern',
                'Other',
              ]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: saving
                  ? null
                  : (value) => setState(() => category = value ?? category),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Details',
              controller: details,
              maxLines: 5,
              hint: 'Describe the concern clearly.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final summary = details.text.trim();
                        if (summary.length < 10) {
                          showAppSnackBar(
                            context,
                            'Enter at least 10 characters describing the concern.',
                          );
                          return;
                        }
                        setState(() => saving = true);
                        try {
                          await TenantController.instance.submitConcern(
                            category: category,
                            summary: summary,
                          );
                          if (!context.mounted) return;
                          showAppSnackBar(
                              context, 'Confidential report submitted.');
                          Navigator.of(context).pop();
                        } catch (error) {
                          if (!context.mounted) return;
                          showAppSnackBar(
                            context,
                            'Unable to submit confidential report: $error',
                          );
                          setState(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit confidential report'),
              ),
            ),
            if (TenantController.instance.concerns.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionTitle('Submitted concerns'),
              const SizedBox(height: 10),
              ...TenantController.instance.concerns.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CarmelitaCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: TimelineTile(
                      compact: true,
                      icon: Icons.shield_outlined,
                      color: const Color(0xFF7D70A0),
                      title: report.category,
                      subtitle:
                          '${report.summary}\n${shortDate(report.createdAt)}',
                      trailing: StatusPill(report.status),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RulesPoliciesPage extends StatelessWidget {
  const RulesPoliciesPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
      title: 'Rules & policies',
      subtitle: 'Dormitory guidelines and procedures',
      child: Column(children: [
        _PolicyCard(
            title: 'Curfew & geofencing',
            icon: Icons.schedule_outlined,
            body:
                'Automated GPS geofencing records dormitory arrival and departure for curfew monitoring and resident safety. Keep location access enabled.'),
        SizedBox(height: 12),
        _PolicyCard(
            title: 'Payments',
            icon: Icons.payments_outlined,
            body:
                'Submit payments according to the agreed schedule. Uploaded proof remains pending until verified.'),
        SizedBox(height: 12),
        _PolicyCard(
            title: 'Safety and community',
            icon: Icons.shield_outlined,
            body:
                'Maintain a safe, respectful environment. Register any visitors in advance through the visitor request tool.'),
      ]));
}

typedef DormitoryRulesPage = RulesPoliciesPage;

class _PolicyCard extends StatelessWidget {
  const _PolicyCard(
      {required this.title, required this.icon, required this.body});
  final String title;
  final IconData icon;
  final String body;
  @override
  Widget build(BuildContext context) => CarmelitaCard(
      child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(icon)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Padding(
              padding: const EdgeInsets.only(top: 6), child: Text(body))));
}
