import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/guardian_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/announcement_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../../services/usage_stats_service.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;

    return PageFrame(
      title: 'Home',
      subtitle: 'Guardian dashboard',
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
          final firstName =
              tenant?.name.trim().split(' ').first ?? 'Resident';

          final headerTitle = controller.hasLinkedTenant
              ? '$firstName is inside the dormitory perimeter.'
              : (controller.loading
                  ? 'Loading resident details...'
                  : 'Welcome to Carmelita\'s Dormitory');

          return RefreshIndicator(
            onRefresh: () => controller.loadData(force: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElegantHeader(
                    eyebrow: 'Guardian view',
                    title: headerTitle,
                    subtitle: controller.hasLinkedTenant
                        ? 'Real-time GPS geofencing confirms safe arrival and departure.'
                        : 'Manage linked resident information, room, and payments.',
                    trailing: const StatusPill(
                      'IN',
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
                            child: ChoiceChip(
                              label: Text(t.name),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) controller.selectTenant(t);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (tenant != null)
                    CarmelitaCard(
                      emphasis: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GuardianTenantInfoPage(),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                const Color(0xFF56886B).withValues(alpha: .15),
                            child: Text(
                              tenant.name.isNotEmpty
                                  ? tenant.name.substring(0, 1)
                                  : 'R',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                color: Color(0xFF56886B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tenant.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(controller.linkedTenantRoomSubtitle),
                                const SizedBox(height: 3),
                                Text(
                                  'Relationship: ${tenant.relationship}${tenant.isPrimary ? ' • Primary' : ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    )
                  else if (!controller.loading)
                    const CarmelitaCard(
                      child: ListTile(
                        leading: Icon(Icons.info_outline,
                            color: Color(0xFFB47A52)),
                        title: Text(
                          'No linked resident',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'Your account is not linked to an active resident. Please contact dormitory management.',
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const SectionTitle(
                    'At a glance',
                    subtitle: 'Presence, payment, and dormitory status',
                  ),
                  const SizedBox(height: 10),
                  MutedDashboardGrid(
                    items: [
                      MutedDashboardItem(
                        label: 'Curfew',
                        value: 'Inside',
                        detail: 'GPS Geofence • 8:14 PM',
                        icon: Icons.schedule_outlined,
                        color: const Color(0xFF56886B),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const GuardianPresenceMonitoringPage(),
                          ),
                        ),
                      ),
                      MutedDashboardItem(
                        label: 'Outstanding',
                        value: money(controller.outstandingTotal),
                        detail: controller.payments.isEmpty
                            ? 'No pending dues'
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
                    subtitle:
                        'Automated geofence tracking for resident safety',
                  ),
                  const SizedBox(height: 10),
                  CarmelitaCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_user_outlined,
                          color: Color(0xFF56886B)),
                      title: const Text(
                        'Perimeter status: Safe & Inside',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        controller.hasLinkedTenant
                            ? '${controller.linkedTenantName} is currently within Carmelita\'s Dormitory perimeter. No issues reported.'
                            : 'Resident monitoring is active when a resident is linked.',
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const GuardianPresenceMonitoringPage(),
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
              ),
            ),
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

          return RefreshIndicator(
            onRefresh: () => controller.loadData(force: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
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
              ),
            ),
          );
        },
      ),
    );
  }
}

class GuardianPresenceMonitoringPage extends StatelessWidget {
  const GuardianPresenceMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;
    final events = controller.geofenceEvents
        .where((event) => event.person == controller.linkedTenantName)
        .toList();
    return PageFrame(
      title: 'Curfew',
      subtitle: 'Linked tenant curfew & geofence status',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const MutedDashboardGrid(
              compact: true,
              items: [
                MutedDashboardItem(
                  label: 'Current status',
                  value: 'Inside',
                  detail: 'Last IN 8:14 PM',
                  icon: Icons.location_on_outlined,
                  color: Color(0xFF56886B),
                ),
                MutedDashboardItem(
                  label: 'Geofence zone',
                  value: '50m Radius',
                  detail: 'Carmelita\'s Dormitory',
                  icon: Icons.location_searching_outlined,
                  color: Color(0xFF627FA8),
                ),
              ],
            ),
            const SizedBox(height: 20),
            MutedActionGrid(
              items: [
                MutedActionItem(
                  label: 'Tenant information',
                  detail: 'View linked tenant',
                  icon: Icons.person_outline,
                  color: const Color(0xFF56886B),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const GuardianTenantInfoPage(),
                  )),
                ),
                MutedActionItem(
                  label: 'Payments',
                  detail: 'Check balances',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFFAA8A45),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const GuardianPaymentStatusPage(),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionTitle(
              'Recent presence records',
              subtitle: 'Automated GPS geofence arrival and departure logs',
            ),
            const SizedBox(height: 10),
            if (events.isEmpty)
              const EmptyState(
                icon: Icons.location_off_outlined,
                title: 'No recent presence records',
                message: 'Verified arrivals and departures will appear here.',
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
                      icon: event.direction == 'IN'
                          ? Icons.login_rounded
                          : Icons.logout_rounded,
                      color: event.direction == 'IN'
                          ? const Color(0xFF56886B)
                          : const Color(0xFF627FA8),
                      title: event.direction == 'IN'
                          ? 'Entered dormitory perimeter'
                          : 'Exited dormitory perimeter',
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

typedef GuardianCurfewOverviewPage = GuardianPresenceMonitoringPage;

class GuardianActivityPage extends StatefulWidget {
  const GuardianActivityPage({super.key});

  @override
  State<GuardianActivityPage> createState() => _GuardianActivityPageState();
}

typedef GuardianGateActivityPage = GuardianActivityPage;

class _GuardianActivityPageState extends State<GuardianActivityPage>
    with WidgetsBindingObserver {
  bool loading = true;
  bool hasPermission = false;
  String? error;
  List<AppUsageStat> usage = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadUsage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) loadUsage();
  }

  Future<void> loadUsage() async {
    if (!UsageStatsService.isSupported) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final allowed = await UsageStatsService.hasPermission();
      final result = allowed
          ? await UsageStatsService.getTodayUsage()
          : const <AppUsageStat>[];
      if (!mounted) return;
      setState(() {
        hasPermission = allowed;
        usage = result;
        error = null;
        loading = false;
      });
    } on PlatformException catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.message ?? 'Could not load app activity.';
        loading = false;
      });
    }
  }

  String durationText(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    if (hours == 0) return '${minutes < 1 ? 1 : minutes} min';
    return minutes == 0 ? '$hours hr' : '$hours hr $minutes min';
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Activity',
        subtitle: 'Today\'s device usage and recent presence events',
        actions: [
          IconButton(
            tooltip: 'Refresh activity',
            onPressed: loading ? null : loadUsage,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Device app activity',
                subtitle:
                    'Foreground usage recorded on this Android device today'),
            const SizedBox(height: 10),
            _usageCard(),
            const SizedBox(height: 24),
            const SectionTitle('Recent presence records',
                subtitle: 'Verified perimeter crossings'),
            const SizedBox(height: 10),
            const _GuardianPresenceRecords(),
          ],
        ),
      );

  Widget _usageCard() {
    if (!UsageStatsService.isSupported) {
      return const CarmelitaCard(
          child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.phone_android_outlined),
        title: Text('Available on Android'),
        subtitle:
            Text('Device app activity is not available on this platform.'),
      ));
    }
    if (loading) {
      return const CarmelitaCard(
          child: Center(child: CircularProgressIndicator()));
    }
    if (!hasPermission) {
      return CarmelitaCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.admin_panel_settings_outlined),
            title: Text('Usage access is required'),
            subtitle: Text(
                'Allow Carmelita\'s Dormitory to read app usage in Android settings.'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: UsageStatsService.openPermissionSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open usage access settings'),
          ),
        ],
      ));
    }
    if (error != null) {
      return CarmelitaCard(
          child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.error_outline),
        title: const Text('Could not load app activity'),
        subtitle: Text(error!),
        trailing:
            IconButton(onPressed: loadUsage, icon: const Icon(Icons.refresh)),
      ));
    }
    if (usage.isEmpty) {
      return const CarmelitaCard(
          child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.hourglass_empty_rounded),
        title: Text('No app activity recorded today'),
      ));
    }
    return CarmelitaCard(
        child: Column(
      children: usage
          .take(20)
          .map((stat) => TimelineTile(
                icon: Icons.apps_rounded,
                title: stat.appName,
                subtitle: stat.packageName,
                trailing: Text(durationText(stat.foregroundTime),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ))
          .toList(),
    ));
  }
}

class _GuardianPresenceRecords extends StatelessWidget {
  const _GuardianPresenceRecords();
  @override
  Widget build(BuildContext context) {
    final tenantName = GuardianController.instance.linkedTenantName;
    final events = GuardianController.instance.geofenceEvents
        .where((e) => e.person == tenantName || e.person == 'Anna Dela Cruz')
        .toList();
    return CarmelitaCard(
        child: Column(
            children: events
                .map((e) => TimelineTile(
                    icon: e.direction == 'IN' ? Icons.login : Icons.logout,
                    title: '${e.direction} • ${e.verification}',
                    subtitle: '${shortDate(e.time)} • ${timeText(e.time)}',
                    trailing: StatusPill(e.status)))
                .toList()));
  }
}

typedef GuardianCurfewRequestsPage = GuardianPresenceMonitoringPage;

class GuardianPaymentStatusPage extends StatelessWidget {
  const GuardianPaymentStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;

    return PageFrame(
      title: 'Payment status',
      subtitle: 'Linked resident balances and verification',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => RefreshIndicator(
          onRefresh: () => controller.loadData(force: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
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

class GuardianMessagesPage extends StatelessWidget {
  const GuardianMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;

    return PageFrame(
      title: 'Messages',
      subtitle: 'Choose who you want to chat with',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ConversationListCard(
          name: 'Caretaker',
          role: 'Owner / Caretaker',
          lastMessage: controller.messages.last,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const GuardianConversationPage(),
            ),
          ),
        ),
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
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;

    return PageFrame(
      title: 'Caretaker',
      subtitle: 'Owner / Caretaker',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Column(
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
                child: Column(
                  children: controller.messages
                      .map(
                        (item) => Align(
                          alignment: item.senderRole == 'guardian'
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 560),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: item.senderRole == 'guardian'
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
                                    item.senderRole == 'guardian' ? 15 : 4),
                                bottomRight: Radius.circular(
                                    item.senderRole == 'guardian' ? 4 : 15),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: item.senderRole == 'guardian'
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
                  prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_outlined),
                    onPressed: () {
                      if (message.text.trim().isEmpty) return;
                      controller.sendMessage(message.text);
                      message.clear();
                    },
                  ),
                ),
                onSubmitted: (value) {
                  if (value.trim().isEmpty) return;
                  controller.sendMessage(value);
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
