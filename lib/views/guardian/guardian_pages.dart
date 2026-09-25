import 'package:flutter/material.dart';
import '../../controllers/guardian_controller.dart';
import '../../controllers/messaging_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/announcement_service.dart';
import '../../services/guardian_alert_service.dart';
import '../../services/table_refresh_subscription.dart';

class GuardianDashboardPage extends StatefulWidget {
  const GuardianDashboardPage({super.key});

  @override
  State<GuardianDashboardPage> createState() => _GuardianDashboardPageState();
}

class _GuardianDashboardPageState extends State<GuardianDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GuardianController.instance.loadData();
      GuardianController.instance.loadCurfewRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;

    return PageFrame(
      title: 'Home',
      subtitle: 'Guardian dashboard',
      onRefresh: () => controller.loadData(force: true),
      actions: [
        IconButton(
          tooltip: 'Safety alerts',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const EmergencySafetyAlertsPage(),
            ),
          ),
          icon: const Icon(Icons.shield_outlined),
        ),
      ],
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final tenant = controller.selectedTenant;
          final firstName = tenant?.name.trim().split(' ').first ?? 'Resident';
          final presence = controller.linkedTenantPresence;
          final hasPresence = presence == 'Inside' || presence == 'Outside';
          final latestPresenceAt = controller.gateEvents.isEmpty
              ? null
              : controller.gateEvents.first.time;

          final headerTitle = controller.hasLinkedTenant
              ? hasPresence
                  ? '$firstName\'s last crossing was ${presence == 'Inside' ? 'IN' : 'OUT'}.'
                  : '$firstName has no recorded crossing yet.'
              : (controller.loading
                  ? 'Loading resident details...'
                  : 'Welcome to Carmelita\'s Dormitory');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElegantHeader(
                eyebrow: 'Guardian view',
                title: headerTitle,
                subtitle: controller.hasLinkedTenant
                    ? hasPresence
                        ? 'Based on the latest automatic tripwire event${latestPresenceAt == null ? '' : ' at ${timeText(latestPresenceAt)}'}.'
                        : 'No automatic entry or exit event is available.'
                    : 'Manage linked resident information, room, and payments.',
                trailing: StatusPill(
                  controller.loading ? 'Loading' : presence,
                  icon: Icons.location_on_rounded,
                ),
              ),
              if (controller.linkedTenants.length > 1) ...[
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: controller.linkedTenants.map((t) {
                      final isSelected =
                          t.tenantId == controller.selectedTenant?.tenantId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(t.name),
                          selected: isSelected,
                          onSelected: (_) => controller.selectTenant(t),
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            child: Text(
                              t.name.isNotEmpty ? t.name[0] : '?',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (controller.hasLinkedTenant)
                CarmelitaCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0x1556886B),
                        foregroundColor: const Color(0xFF56886B),
                        child: const Icon(Icons.person, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  controller.linkedTenantName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1556886B),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Active Resident',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF56886B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              controller.linkedTenantRoomSubtitle,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (!controller.loading)
                const CarmelitaCard(
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: Color(0xFFB47A52)),
                    title: Text(
                      'No linked resident',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Your account is not linked to an active resident. Please contact dormitory management.',
                    ),
                  ),
                ),
              if (controller.pendingGuardianCurfewCount > 0) ...[
                const SizedBox(height: 16),
                AttentionCard(
                  compact: true,
                  icon: Icons.pending_actions_outlined,
                  title:
                      '${controller.pendingGuardianCurfewCount} overnight leave request(s) waiting',
                  subtitle:
                      'Your parental endorsement is needed for ${controller.linkedTenantName}.',
                  status: 'Action needed',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GuardianPresenceMonitoringPage(
                        initialSegment: 0,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const SectionTitle(
                'At a glance',
                subtitle: 'Presence, payment, and dormitory status',
              ),
              const SizedBox(height: 10),
              MutedDashboardGrid(
                compact: true,
                items: [
                  MutedDashboardItem(
                    label: 'Curfew',
                    value: controller.hasLinkedTenant ? presence : '—',
                    detail: controller.pendingGuardianCurfewCount > 0
                        ? '${controller.pendingGuardianCurfewCount} waiting your review'
                        : latestPresenceAt != null
                            ? 'Updated ${shortDate(latestPresenceAt)} at ${timeText(latestPresenceAt)}'
                            : 'No presence event recorded',
                    icon: Icons.schedule_outlined,
                    color: const Color(0xFF56886B),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GuardianPresenceMonitoringPage(
                            initialSegment: 0),
                      ),
                    ),
                  ),
                  MutedDashboardItem(
                    label: 'Outstanding',
                    value: controller.hasLinkedTenant && controller.loadedOnce
                        ? money(controller.outstandingTotal)
                        : '—',
                    detail: controller.loading
                        ? 'Loading payment records'
                        : controller.error != null
                            ? 'Payment data unavailable'
                            : !controller.hasLinkedTenant
                                ? 'No linked resident'
                                : controller.payments.isEmpty
                                    ? 'No pending charges'
                                    : '${controller.payments.where((p) => !p.isVerified).length} unverified/due',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFFAA8A45),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GuardianPaymentStatusPage(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                'Safety & presence status',
                subtitle: 'Automated geofence tracking for resident safety',
              ),
              const SizedBox(height: 10),
              CarmelitaCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    hasPresence
                        ? Icons.location_on_outlined
                        : Icons.location_off_outlined,
                    color: hasPresence
                        ? const Color(0xFF56886B)
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text(
                    controller.hasLinkedTenant
                        ? 'Perimeter status: $presence'
                        : 'No linked resident',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    controller.hasLinkedTenant
                        ? latestPresenceAt != null
                            ? 'Latest recorded event: ${shortDate(latestPresenceAt)} at ${timeText(latestPresenceAt)}.'
                            : 'No presence history is available for ${controller.linkedTenantName}.'
                        : 'Link a resident to display presence information.',
                  ),
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GuardianPresenceMonitoringPage(),
                      ),
                    ),
                    child: const Text('View history'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                'Quick access',
                subtitle: 'Common information without searching',
              ),
              const SizedBox(height: 10),
              MutedActionGrid(
                items: [
                  MutedActionItem(
                    label: 'Tenant info',
                    detail: 'View linked resident',
                    icon: Icons.person_outline,
                    color: const Color(0xFF56886B),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GuardianTenantInfoPage(),
                      ),
                    ),
                  ),
                  MutedActionItem(
                    label: 'Payments',
                    detail: 'Check balances',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFFAA8A45),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GuardianPaymentStatusPage(),
                      ),
                    ),
                  ),
                  MutedActionItem(
                    label: 'Announcements',
                    detail: 'Read dormitory news',
                    icon: Icons.campaign_outlined,
                    color: const Color(0xFF7D70A0),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GuardianAnnouncementsPage(),
                      ),
                    ),
                  ),
                  MutedActionItem(
                    label: 'Contact info',
                    detail: 'Office and emergency',
                    icon: Icons.emergency_outlined,
                    color: const Color(0xFFAA6870),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmergencySafetyAlertsPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class GuardianTenantInfoPage extends StatelessWidget {
  const GuardianTenantInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;

    return PageFrame(
      title: 'Tenant information',
      subtitle: 'Linked resident profile & room assignment',
      onRefresh: () => controller.loadData(force: true),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final tenant = controller.selectedTenant;
          final room = controller.room;

          if (tenant == null) {
            return const CarmelitaCard(
              child: ListTile(
                leading: Icon(Icons.info_outline, color: Color(0xFFB47A52)),
                title: Text(
                  'No linked resident',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'There is no resident currently linked to your account.',
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CarmelitaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RESIDENT PROFILE',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        fontSize: 12,
                        color: Color(0xFF56886B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InfoRow(
                      label: 'Resident name',
                      value: tenant.name,
                      icon: Icons.person_outline,
                    ),
                    InfoRow(
                      label: 'Relationship',
                      value:
                          '${tenant.relationship}${tenant.isPrimary ? ' (Primary)' : ''}',
                      icon: Icons.family_restroom_outlined,
                    ),
                    if (tenant.phone.isNotEmpty)
                      InfoRow(
                        label: 'Contact phone',
                        value: tenant.phone,
                        icon: Icons.phone_outlined,
                      ),
                    InfoRow(
                      label: 'Residency status',
                      value: tenant.residencyStatus.toUpperCase(),
                      icon: Icons.verified_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CarmelitaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ROOM ASSIGNMENT',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        fontSize: 12,
                        color: Color(0xFF627FA8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (room != null) ...[
                      InfoRow(
                        label: 'Room',
                        value: 'Room ${room.number} • Floor ${room.floor}',
                        icon: Icons.meeting_room_outlined,
                      ),
                      InfoRow(
                        label: 'Bed space',
                        value: room.bedSpace,
                        icon: Icons.bed_outlined,
                      ),
                      InfoRow(
                        label: 'Capacity & Occupancy',
                        value: '${room.occupied} / ${room.capacity} occupied',
                        icon: Icons.people_outline,
                      ),
                      if (room.utilitySummary.isNotEmpty)
                        InfoRow(
                          label: 'Utilities',
                          value: room.utilitySummary,
                          icon: Icons.bolt_outlined,
                        ),
                      if (room.roommateDetails.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        const Text(
                          'Roommates',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...room.roommateDetails.map(
                          (rm) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.person,
                                    size: 16, color: Color(0xFF7D70A0)),
                                const SizedBox(width: 8),
                                Text(
                                  rm.name,
                                  style: TextStyle(
                                    fontWeight: rm.isSelf
                                        ? FontWeight.w800
                                        : FontWeight.normal,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  rm.bed,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ] else
                      InfoRow(
                        label: 'Room',
                        value: controller.loading
                            ? 'Loading room details...'
                            : 'No active room assignment',
                        icon: Icons.meeting_room_outlined,
                      ),
                  ],
                ),
              ),
              if (tenant.schoolName.isNotEmpty ||
                  tenant.courseOrProgram.isNotEmpty ||
                  tenant.emergencyContactName.isNotEmpty) ...[
                const SizedBox(height: 16),
                CarmelitaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EDUCATION & EMERGENCY',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          fontSize: 12,
                          color: Color(0xFF7D70A0),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (tenant.schoolName.isNotEmpty)
                        InfoRow(
                          label: 'School / Institution',
                          value: tenant.schoolName,
                          icon: Icons.school_outlined,
                        ),
                      if (tenant.courseOrProgram.isNotEmpty)
                        InfoRow(
                          label: 'Program',
                          value: tenant.yearLevel != null
                              ? '${tenant.courseOrProgram} (Year ${tenant.yearLevel})'
                              : tenant.courseOrProgram,
                          icon: Icons.menu_book_outlined,
                        ),
                      if (tenant.emergencyContactName.isNotEmpty)
                        InfoRow(
                          label: 'Emergency contact',
                          value:
                              '${tenant.emergencyContactName} (${tenant.emergencyContactPhone})',
                          icon: Icons.emergency_outlined,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class GuardianPresenceMonitoringPage extends StatefulWidget {
  const GuardianPresenceMonitoringPage({
    super.key,
    this.initialSegment = 0,
  });

  final int initialSegment;

  @override
  State<GuardianPresenceMonitoringPage> createState() =>
      _GuardianPresenceMonitoringPageState();
}

class _GuardianPresenceMonitoringPageState
    extends State<GuardianPresenceMonitoringPage> {
  late int _selectedSegment;
  String _filter = 'pending'; // 'pending', 'approved', 'rejected', 'all'
  TableRefreshSubscription? _subscription;
  String? _processingRequestId;

  @override
  void initState() {
    super.initState();
    _selectedSegment = widget.initialSegment;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GuardianController.instance.loadCurfewRequests();
        GuardianController.instance.loadGateEvents();
      }
    });

    _subscription = TableRefreshSubscription(
      'guardian-curfew-monitoring',
      ['curfew_requests', 'gate_events', 'tenant_details'],
      () {
        if (mounted) {
          GuardianController.instance.loadCurfewRequests(force: true);
          GuardianController.instance.loadGateEvents(force: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.dispose();
    super.dispose();
  }

  Future<void> _handleDecision({
    required CurfewRequest request,
    required bool approve,
    String? remarks,
  }) async {
    setState(() => _processingRequestId = request.id);
    try {
      await GuardianController.instance.decideCurfewRequest(
        requestId: request.id,
        approve: approve,
        remarks: remarks,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Overnight leave endorsed and sent to dormitory staff for review.'
                : 'Overnight leave declined.',
          ),
          backgroundColor:
              approve ? const Color(0xFF56886B) : const Color(0xFFB3261E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update request: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingRequestId = null);
      }
    }
  }

  void _promptEndorseDialog(CurfewRequest request) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => _GuardianCurfewEndorseSheet(
        request: request,
        onConfirmEndorse: (remarks) {
          Navigator.of(bottomSheetContext).pop();
          _handleDecision(request: request, approve: true, remarks: remarks);
        },
      ),
    );
  }

  void _promptDeclineDialog(CurfewRequest request) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => _GuardianCurfewDeclineSheet(
        request: request,
        onConfirmDecline: (remarks) {
          Navigator.of(bottomSheetContext).pop();
          _handleDecision(request: request, approve: false, remarks: remarks);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;
    final allEvents = controller.gateEvents;
    final events = allEvents.any((e) => e.person == controller.linkedTenantName)
        ? allEvents
            .where((e) => e.person == controller.linkedTenantName)
            .toList()
        : allEvents;

    return PageFrame(
      title: 'Curfew',
      subtitle: 'Linked resident exceptions & boundary tracking',
      maxWidth: 720,
      actions: [
        IconButton(
          tooltip: 'Refresh curfew data',
          icon: (controller.curfewLoading || controller.gateLoading)
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          onPressed: (controller.curfewLoading || controller.gateLoading)
              ? null
              : () {
                  controller.loadCurfewRequests(force: true);
                  controller.loadGateEvents(force: true);
                },
        ),
      ],
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final allRequests = controller.curfewRequests;
          final pendingCount = controller.pendingGuardianCurfewCount;
          final approvedCount = allRequests.where((r) => r.isApproved).length;
          final rejectedCount = allRequests.where((r) => r.isRejected).length;

          final displayedRequests = switch (_filter) {
            'pending' => allRequests
                .where((r) =>
                    r.isPendingGuardian ||
                    (r.isPending && r.status == 'pending_staff'))
                .toList(),
            'approved' => allRequests.where((r) => r.isApproved).toList(),
            'rejected' => allRequests.where((r) => r.isRejected).toList(),
            _ => allRequests,
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkInProgressNotice(),
              const SizedBox(height: 16),
              AdaptiveGrid(
                children: [
                  MetricCard(
                    label: 'Endorsements waiting',
                    value: '$pendingCount',
                    detail: pendingCount > 0
                        ? 'Parental action needed'
                        : 'All clear',
                    icon: Icons.pending_actions_outlined,
                  ),
                  MetricCard(
                    label: 'Resident presence',
                    value: controller.linkedTenantPresence,
                    detail: controller.hasLinkedTenant
                        ? controller.linkedTenantName
                        : 'No active linked resident',
                    icon: Icons.location_on_outlined,
                  ),
                  const MetricCard(
                    label: 'Perimeter radius',
                    value: '50m Radius',
                    detail: "Carmelita's Dormitory",
                    icon: Icons.location_searching_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: [
                        ButtonSegment<int>(
                          value: 0,
                          label: Text(
                            pendingCount > 0
                                ? 'Exceptions ($pendingCount)'
                                : 'Exceptions',
                          ),
                          icon: const Icon(Icons.schedule_outlined),
                        ),
                        const ButtonSegment<int>(
                          value: 1,
                          label: Text('Perimeter & Presence'),
                          icon: Icon(Icons.radar_outlined),
                        ),
                      ],
                      selected: {_selectedSegment},
                      onSelectionChanged: (value) {
                        setState(() => _selectedSegment = value.first);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_selectedSegment == 0) ...[
                // Curfew Exceptions Tab
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CurfewFilterChip(
                        label: 'Pending ($pendingCount)',
                        selected: _filter == 'pending',
                        badgeColor: const Color(0xFFAA8A45),
                        onTap: () => setState(() => _filter = 'pending'),
                      ),
                      const SizedBox(width: 8),
                      _CurfewFilterChip(
                        label: 'Approved ($approvedCount)',
                        selected: _filter == 'approved',
                        badgeColor: const Color(0xFF56886B),
                        onTap: () => setState(() => _filter = 'approved'),
                      ),
                      const SizedBox(width: 8),
                      _CurfewFilterChip(
                        label: 'Rejected ($rejectedCount)',
                        selected: _filter == 'rejected',
                        badgeColor: const Color(0xFFB3261E),
                        onTap: () => setState(() => _filter = 'rejected'),
                      ),
                      const SizedBox(width: 8),
                      _CurfewFilterChip(
                        label: 'All (${allRequests.length})',
                        selected: _filter == 'all',
                        badgeColor: Colors.grey,
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (controller.curfewLoading && displayedRequests.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (displayedRequests.isEmpty)
                  EmptyState(
                    icon: _filter == 'pending'
                        ? Icons.task_alt_outlined
                        : Icons.schedule_outlined,
                    title: _filter == 'pending'
                        ? 'No pending curfew endorsements'
                        : 'No requests in this tab',
                    message: _filter == 'pending'
                        ? 'All resident curfew and leave requests have been reviewed.'
                        : 'Curfew exception requests submitted by your linked resident will appear here.',
                  )
                else
                  ...displayedRequests.map(
                    (req) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GuardianCurfewRequestCard(
                        request: req,
                        isProcessing: _processingRequestId == req.id,
                        onEndorse: () => _promptEndorseDialog(req),
                        onDecline: () => _promptDeclineDialog(req),
                      ),
                    ),
                  ),
              ] else ...[
                // Perimeter & Presence Tab
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
                () {
                  final presence = controller.linkedTenantPresence;
                  final isInside = presence == 'Inside' || presence == 'IN';
                  final isOutside = presence == 'Outside' || presence == 'OUT';
                  final isUnavailable =
                      presence == 'Unavailable' || presence == 'UNAVAILABLE';

                  final statusColor = isInside
                      ? const Color(0xFF56886B)
                      : (isOutside
                          ? const Color(0xFFC77800)
                          : const Color(0xFFB03A2E));
                  final statusIcon = isInside
                      ? Icons.location_on_outlined
                      : (isOutside
                          ? Icons.directions_walk_outlined
                          : Icons.location_disabled_outlined);
                  final latestEvent = events.firstOrNull;
                  final presenceDetail = latestEvent != null
                      ? '${latestEvent.direction != null ? "Last ${latestEvent.direction}: " : ""}${timeText(latestEvent.time)} • ${latestEvent.verification}'
                      : (isUnavailable
                          ? 'Signal unavailable'
                          : 'Boundary monitoring active');

                  return MutedDashboardGrid(
                    compact: true,
                    items: [
                      MutedDashboardItem(
                        label: 'Current status',
                        value: presence,
                        detail: presenceDetail,
                        icon: statusIcon,
                        color: statusColor,
                      ),
                      const MutedDashboardItem(
                        label: 'Geofence zone',
                        value: '50m Radius',
                        detail: "Carmelita's Dormitory",
                        icon: Icons.location_searching_outlined,
                        color: Color(0xFF627FA8),
                      ),
                    ],
                  );
                }(),
                const SizedBox(height: 14),
                CarmelitaCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF627FA8).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF627FA8),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Guardian Alert Preference',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Alert me if resident is outside past ${GuardianAlertService.preferredAlertTime.format(context)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                GuardianAlertService.preferredAlertTime,
                          );
                          if (picked != null) {
                            setState(() {
                              GuardianAlertService.setPreferredAlertTime(
                                  picked);
                            });
                          }
                        },
                        child: const Text('Set time'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                MutedActionGrid(
                  items: [
                    MutedActionItem(
                      label: 'Tenant information',
                      detail: 'View linked tenant',
                      icon: Icons.person_outline,
                      color: const Color(0xFF56886B),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GuardianTenantInfoPage(),
                        ),
                      ),
                    ),
                    MutedActionItem(
                      label: 'Payments',
                      detail: 'Check balances',
                      icon: Icons.payments_outlined,
                      color: const Color(0xFFAA8A45),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GuardianPaymentStatusPage(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionTitle(
                  'Recent presence records',
                  subtitle: 'Automatic tripwire entry and exit records',
                ),
                const SizedBox(height: 10),
                if (events.isEmpty)
                  const EmptyState(
                    icon: Icons.location_off_outlined,
                    title: 'No recent presence records',
                    message:
                        'Verified arrivals and departures will appear here.',
                  )
                else
                  ...events.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CarmelitaCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: TimelineTile(
                          compact: true,
                          icon: event.isUnavailable
                              ? Icons.location_disabled_outlined
                              : (event.direction == 'IN'
                                  ? Icons.login_rounded
                                  : Icons.logout_rounded),
                          color: event.isUnavailable
                              ? const Color(0xFFB03A2E)
                              : (event.direction == 'IN'
                                  ? const Color(0xFF56886B)
                                  : const Color(0xFF627FA8)),
                          title: event.isUnavailable
                              ? 'Location check unavailable'
                              : (event.direction == 'IN'
                                  ? 'Entered dormitory perimeter'
                                  : 'Exited dormitory perimeter'),
                          subtitle:
                              '${shortDate(event.time)} • ${timeText(event.time)} • ${event.verification}${event.notes != null && event.notes!.isNotEmpty ? ' (${event.notes})' : ''}',
                          trailing: StatusPill(event.status),
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
}

class _GuardianCurfewRequestCard extends StatelessWidget {
  const _GuardianCurfewRequestCard({
    required this.request,
    required this.isProcessing,
    required this.onEndorse,
    required this.onDecline,
  });

  final CurfewRequest request;
  final bool isProcessing;
  final VoidCallback onEndorse;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final residentName =
        request.tenantName ?? GuardianController.instance.linkedTenantName;

    return CarmelitaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: .12),
                child: Text(
                  residentName.isNotEmpty ? residentName[0].toUpperCase() : 'R',
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
                      residentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          request.isOvernightLeave
                              ? Icons.hotel_outlined
                              : Icons.nightlight_outlined,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          request.requestTypeLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusPill(request.statusLabel),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined,
                  size: 16, color: Color(0xFF627FA8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  request.destination,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                request.reason,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: .85),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: .4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.flight_takeoff_outlined, size: 15),
                    const SizedBox(width: 6),
                    const Text(
                      'Departure: ',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Expanded(
                      child: Text(
                        '${shortDate(request.departureTime)} • ${timeText(request.departureTime)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.flight_land_outlined, size: 15),
                    const SizedBox(width: 6),
                    const Text(
                      'Expected return: ',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Expanded(
                      child: Text(
                        '${shortDate(request.expectedReturnTime)} • ${timeText(request.expectedReturnTime)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (request.isLateReturn) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x12627FA8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x35627FA8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 15, color: Color(0xFF627FA8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Same-night late returns past 10 PM are reviewed directly by the caretaker or owner. Displayed here for your parental awareness.',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: .85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (request.staffNotes != null &&
                request.staffNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Staff remarks: ${request.staffNotes}',
                  style: const TextStyle(
                      fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ] else if (request.isOvernightLeave) ...[
            if (request.canReviewGuardian) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x15AA8A45),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x40AA8A45)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notification_important_outlined,
                        size: 16, color: Color(0xFFAA8A45)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Resident requested an overnight stay off-premises. Your parental approval is required before dormitory staff can review and authorize the request.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (isProcessing)
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDecline,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text(
                          'Decline',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB3261E),
                          side: const BorderSide(color: Color(0x60B3261E)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onEndorse,
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text(
                          'Endorse Leave',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF56886B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
            ] else if (request.guardianDecision == 'approved') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x1556886B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x4056886B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 15, color: Color(0xFF56886B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You endorsed this leave${request.guardianRemarks != null && request.guardianRemarks!.isNotEmpty ? ": \"${request.guardianRemarks}\"" : ""}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF56886B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (request.status == 'pending_staff') ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Forwarded to dormitory staff for final review.',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: .7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ] else if (request.guardianDecision == 'rejected') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x15B3261E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x40B3261E)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gpp_bad_outlined,
                        size: 15, color: Color(0xFFB3261E)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You declined this overnight leave${request.guardianRemarks != null && request.guardianRemarks!.isNotEmpty ? ": \"${request.guardianRemarks}\"" : ""}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB3261E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _GuardianCurfewEndorseSheet extends StatefulWidget {
  const _GuardianCurfewEndorseSheet({
    required this.request,
    required this.onConfirmEndorse,
  });

  final CurfewRequest request;
  final ValueChanged<String?> onConfirmEndorse;

  @override
  State<_GuardianCurfewEndorseSheet> createState() =>
      _GuardianCurfewEndorseSheetState();
}

class _GuardianCurfewEndorseSheetState
    extends State<_GuardianCurfewEndorseSheet> {
  final TextEditingController _notesController = TextEditingController();

  final List<String> _quickRemarks = const [
    'Staying with family/relatives.',
    'Authorized by parents for weekend visit.',
    'I can be reached on my mobile phone.',
    'Return travel arrangements confirmed.',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.request.tenantName ?? 'Resident';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
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
                    color: const Color(0xFF56886B).withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_outlined,
                      color: Color(0xFF56886B), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Endorse Overnight Leave',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      Text(
                        '$name • ${widget.request.requestTypeLabel}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick parental notes (tap to append):',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickRemarks.map((remark) {
                return ActionChip(
                  label: Text(remark, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    final current = _notesController.text.trim();
                    if (current.isEmpty) {
                      _notesController.text = remark;
                    } else {
                      _notesController.text = '$current $remark';
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Parental remarks for staff (optional)',
                hintText: 'e.g. Accompanied by family members',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        widget.onConfirmEndorse(_notesController.text.trim()),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'Endorse Leave',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF56886B),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianCurfewDeclineSheet extends StatefulWidget {
  const _GuardianCurfewDeclineSheet({
    required this.request,
    required this.onConfirmDecline,
  });

  final CurfewRequest request;
  final ValueChanged<String?> onConfirmDecline;

  @override
  State<_GuardianCurfewDeclineSheet> createState() =>
      _GuardianCurfewDeclineSheetState();
}

class _GuardianCurfewDeclineSheetState
    extends State<_GuardianCurfewDeclineSheet> {
  final TextEditingController _notesController = TextEditingController();
  String _selectedReason = 'Parental permission not granted';

  final List<String> _quickReasons = const [
    'Parental permission not granted',
    'Midterms/academic obligations scheduled',
    'Family commitment scheduled',
    'Unclear destination or accommodations',
    'Other reason (details below)',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.request.tenantName ?? 'Resident';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
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
                    color: const Color(0xFFB3261E).withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel_outlined,
                      color: Color(0xFFB3261E), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Decline Overnight Leave',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      Text(
                        '$name • ${widget.request.requestTypeLabel}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Select reason for declining:',
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
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
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
              decoration: InputDecoration(
                labelText: 'Additional notes for resident (optional)',
                hintText: 'e.g. Please return home directly after classes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final custom = _notesController.text.trim();
                      final finalReason = custom.isNotEmpty
                          ? '$_selectedReason: $custom'
                          : _selectedReason;
                      widget.onConfirmDecline(finalReason);
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB3261E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CurfewFilterChip extends StatelessWidget {
  const _CurfewFilterChip({
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

typedef GuardianCurfewOverviewPage = GuardianPresenceMonitoringPage;
typedef GuardianCurfewRequestsPage = GuardianPresenceMonitoringPage;

class GuardianActivityPage extends StatelessWidget {
  const GuardianActivityPage({super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Activity',
        subtitle: 'Recent verified presence events',
        onRefresh: () =>
            GuardianController.instance.loadGateEvents(force: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Recent presence records',
                subtitle: 'Verified perimeter crossings'),
            const SizedBox(height: 10),
            const _GuardianPresenceRecords(),
          ],
        ),
      );
}

typedef GuardianGateActivityPage = GuardianActivityPage;

class _GuardianPresenceRecords extends StatelessWidget {
  const _GuardianPresenceRecords();
  @override
  Widget build(BuildContext context) {
    final tenantName = GuardianController.instance.linkedTenantName;
    final allEvents = GuardianController.instance.gateEvents;
    final events = allEvents.any((e) => e.person == tenantName)
        ? allEvents.where((e) => e.person == tenantName).toList()
        : allEvents;

    if (events.isEmpty) {
      return const CarmelitaCard(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No presence records recorded yet.')),
        ),
      );
    }

    return CarmelitaCard(
      child: Column(
        children: events
            .map(
              (e) => TimelineTile(
                icon: e.isUnavailable
                    ? Icons.location_disabled_outlined
                    : (e.direction == 'IN' ? Icons.login : Icons.logout),
                color: e.isUnavailable
                    ? const Color(0xFFB03A2E)
                    : (e.direction == 'IN'
                        ? const Color(0xFF56886B)
                        : const Color(0xFF627FA8)),
                title: e.isUnavailable
                    ? 'Unavailable • ${e.verification}'
                    : '${e.direction} • ${e.verification}',
                subtitle:
                    '${shortDate(e.time)} • ${timeText(e.time)}${e.notes != null && e.notes!.isNotEmpty ? ' (${e.notes})' : ''}',
                trailing: StatusPill(e.status),
              ),
            )
            .toList(),
      ),
    );
  }
}

class GuardianPaymentStatusPage extends StatelessWidget {
  const GuardianPaymentStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;

    return PageFrame(
      title: 'Payment status',
      subtitle: 'Linked resident balances and verification',
      onRefresh: () => controller.loadData(force: true),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MetricCard(
              label: 'Outstanding total',
              value: money(controller.outstandingTotal),
              detail: controller.payments.isEmpty
                  ? 'No pending dues'
                  : 'Unverified and unpaid records',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 16),
            if (controller.payments.isEmpty)
              CarmelitaCard(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined,
                      color: Color(0xFF56886B)),
                  title: const Text(
                    'No payment records',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    controller.hasLinkedTenant
                        ? 'No payment records found for ${controller.linkedTenantName}.'
                        : 'No payment records available.',
                  ),
                ),
              )
            else
              CarmelitaCard(
                child: Column(
                  children: controller.payments
                      .map(
                        (payment) => TimelineTile(
                          icon: Icons.receipt_long_outlined,
                          title: payment.label,
                          subtitle: '${money(payment.amount)} • Due '
                              '${shortDate(payment.dueDate)}',
                          trailing: StatusPill(payment.status),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GuardianAnnouncementsPage extends StatefulWidget {
  const GuardianAnnouncementsPage({super.key});

  @override
  State<GuardianAnnouncementsPage> createState() =>
      _GuardianAnnouncementsPageState();
}

class _GuardianAnnouncementsPageState extends State<GuardianAnnouncementsPage> {
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
    _announcements = AnnouncementService.cachedAnnouncements('guardians');
    _loading = _announcements == null;
    _fetchAnnouncements(showSpinner: _announcements == null);
    _subscription = TableRefreshSubscription(
      'guardian-announcements-page',
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
        audienceFilter: 'guardians',
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
      subtitle: 'Notices relevant to guardians',
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

class GuardianMessagesPage extends StatefulWidget {
  const GuardianMessagesPage({super.key});

  @override
  State<GuardianMessagesPage> createState() => _GuardianMessagesPageState();
}

class _GuardianMessagesPageState extends State<GuardianMessagesPage> {
  @override
  void initState() {
    super.initState();
    final uid = SessionController.instance.currentUser?.id ?? '';
    MessagingController.instance.loadGuardianConversation(guardianId: uid);
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
                builder: (_) => const GuardianConversationPage(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class GuardianConversationPage extends StatefulWidget {
  const GuardianConversationPage({super.key});

  @override
  State<GuardianConversationPage> createState() =>
      _GuardianConversationPageState();
}

class _GuardianConversationPageState extends State<GuardianConversationPage> {
  final message = TextEditingController();

  @override
  void initState() {
    super.initState();
    final uid = SessionController.instance.currentUser?.id ?? '';
    MessagingController.instance.loadGuardianConversation(
      guardianId: uid,
      openThread: true,
    );
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
                            final isMe = item.senderRole == 'guardian';
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
                            icon: const Icon(Icons.send_outlined),
                            onPressed: _handleSend,
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

class EmergencySafetyAlertsPage extends StatelessWidget {
  const EmergencySafetyAlertsPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
      title: 'Dormitory contact info',
      subtitle: 'Static office and emergency contact details',
      child: Column(children: [
        CarmelitaCard(
            child: TimelineTile(
                icon: Icons.info_outline,
                title: 'Dormitory office',
                subtitle: '+63 917 000 0001 • 8:00 AM–8:00 PM',
                trailing: StatusPill('Contact'))),
        SizedBox(height: 12),
        CarmelitaCard(
            child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.emergency_outlined),
                title: Text('Emergency services',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                    'For immediate danger, contact local emergency services. This page is a directory, not a live SOS or push-alert feature.'))),
      ]));
}
