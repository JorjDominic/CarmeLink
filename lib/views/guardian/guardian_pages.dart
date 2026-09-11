import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/guardian_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/announcement_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../../services/usage_stats_service.dart';

class GuardianDashboardPage extends StatelessWidget {
  const GuardianDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;
    final linkedRequests = controller.curfewRequests
        .where(
          (request) => request.tenantName == controller.linkedTenantName,
        )
        .toList();

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
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ElegantHeader(
              eyebrow: 'Guardian view',
              title: 'Anna is inside the dormitory.',
              subtitle:
                  'Everything important about your linked tenant appears here first.',
              trailing: StatusPill(
                'IN',
                icon: Icons.home_rounded,
              ),
            ),
            const SizedBox(height: 22),
            CarmelitaCard(
              emphasis: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GuardianTenantInfoPage(),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Text(
                      'A',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anna Dela Cruz',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text('Room 204 • Bed 2'),
                        SizedBox(height: 3),
                        Text('Last IN • 8:14 PM'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle(
              'At a glance',
              subtitle: 'Gate, payment, and pending approvals',
            ),
            const SizedBox(height: 10),
            MutedDashboardGrid(
              items: [
                MutedDashboardItem(
                  label: 'Gate status',
                  value: 'Inside',
                  detail: 'Verified • 8:14 PM',
                  icon: Icons.sensor_door_outlined,
                  color: const Color(0xFF56886B),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GuardianCurfewOverviewPage(),
                    ),
                  ),
                ),
                MutedDashboardItem(
                  label: 'Outstanding',
                  value: money(controller.outstandingTotal),
                  detail: 'Unpaid / unverified',
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
              'Needs your attention',
              subtitle: 'Requests that require a guardian decision',
            ),
            const SizedBox(height: 10),
            if (controller.pendingCurfewCount == 0)
              const CarmelitaCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.task_alt_rounded),
                  title: Text(
                    'No pending curfew requests',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    'New requests from your linked tenant will appear here.',
                  ),
                ),
              )
            else
              ...linkedRequests
                  .where(
                    (request) => request.guardianStatus == 'Pending',
                  )
                  .map(
                    (request) => AttentionCard(
                      icon: Icons.schedule_outlined,
                      title: request.reason,
                      subtitle:
                          '${request.destination} • Return ${timeText(request.expectedReturn)}',
                      status: request.guardianStatus,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GuardianCurfewRequestsPage(),
                        ),
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
  }
}

class GuardianTenantInfoPage extends StatelessWidget {
  const GuardianTenantInfoPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
      title: 'Tenant information',
      subtitle: 'Linked tenant',
      child: CarmelitaCard(
          child: Column(children: [
        InfoRow(
            label: 'Tenant',
            value: 'Anna Dela Cruz',
            icon: Icons.person_outline),
        InfoRow(
            label: 'Room',
            value: '204 • Second Floor',
            icon: Icons.meeting_room_outlined),
        InfoRow(label: 'Bed space', value: 'Bed 2', icon: Icons.bed_outlined),
        InfoRow(
            label: 'Current status',
            value: 'Inside dormitory',
            icon: Icons.sensor_door_outlined),
      ])));
}

class GuardianCurfewOverviewPage extends StatelessWidget {
  const GuardianCurfewOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;
    final events = controller.gateEvents
        .where((event) => event.person == controller.linkedTenantName)
        .toList();
    return PageFrame(
      title: 'Curfew',
      subtitle: 'Linked tenant status and curfew activity',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CURFEW SUMMARY',
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
                  icon: Icons.home_outlined,
                  color: Color(0xFF56886B),
                ),
                MutedDashboardItem(
                  label: 'Standard curfew',
                  value: '10:00 PM',
                  detail: 'Daily schedule',
                  icon: Icons.schedule_outlined,
                  color: Color(0xFF7D70A0),
                ),
              ],
            ),
            const SizedBox(height: 20),
            MutedActionGrid(
              items: [
                MutedActionItem(
                  label: 'Curfew requests',
                  detail: 'Provide supporting input',
                  icon: Icons.approval_outlined,
                  color: const Color(0xFF7D70A0),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const GuardianCurfewRequestsPage(),
                  )),
                ),
                MutedActionItem(
                  label: 'Tenant information',
                  detail: 'View linked tenant',
                  icon: Icons.person_outline,
                  color: const Color(0xFF56886B),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const GuardianTenantInfoPage(),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionTitle('Recent gate records'),
            const SizedBox(height: 10),
            if (events.isEmpty)
              const EmptyState(
                icon: Icons.sensor_door_outlined,
                title: 'No recent gate records',
                message: 'Recognized entries and exits will appear here.',
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
                      title: event.direction,
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

class GuardianGateActivityPage extends StatefulWidget {
  const GuardianGateActivityPage({super.key});

  @override
  State<GuardianGateActivityPage> createState() =>
      _GuardianGateActivityPageState();
}

class _GuardianGateActivityPageState extends State<GuardianGateActivityPage>
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
        subtitle: 'Today\'s device usage and recent gate events',
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
            const SectionTitle('Recent gate records',
                subtitle: 'Verified IN and OUT events'),
            const SizedBox(height: 10),
            const _GuardianGateRecords(),
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

class _GuardianGateRecords extends StatelessWidget {
  const _GuardianGateRecords();
  @override
  Widget build(BuildContext context) {
    final events = GuardianController.instance.gateEvents
        .where((e) => e.person == 'Anna Dela Cruz')
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

class GuardianCurfewRequestsPage extends StatelessWidget {
  const GuardianCurfewRequestsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GuardianController.instance;
    return PageFrame(
        title: 'Curfew requests',
        subtitle: 'Review requests and provide guardian input',
        child: AnimatedBuilder(
            animation: c,
            builder: (context, _) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'REQUEST SUMMARY',
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
                        label: 'Needs input',
                        value: '${c.pendingCurfewCount}',
                        detail: 'Guardian response',
                        icon: Icons.pending_actions_outlined,
                        color: const Color(0xFFAA8A45),
                      ),
                      MutedDashboardItem(
                        label: 'Total requests',
                        value:
                            '${c.curfewRequests.where((r) => r.tenantName == c.linkedTenantName).length}',
                        detail: 'Linked tenant',
                        icon: Icons.schedule_outlined,
                        color: const Color(0xFF7D70A0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle('Curfew requests'),
                  const SizedBox(height: 10),
                  ...c.curfewRequests
                      .where((r) => r.tenantName == 'Anna Dela Cruz')
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: CarmelitaCard(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(r.reason,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 17))),
                                        StatusPill(r.guardianStatus)
                                      ]),
                                      const SizedBox(height: 10),
                                      InfoRow(
                                          label: 'Destination',
                                          value: r.destination),
                                      InfoRow(
                                          label: 'Expected return',
                                          value:
                                              '${shortDate(r.expectedReturn)} • ${timeText(r.expectedReturn)}'),
                                      if (r.guardianStatus ==
                                          'Input pending') ...[
                                        const SizedBox(height: 12),
                                        Row(children: [
                                          Expanded(
                                              child: OutlinedButton(
                                                  onPressed: () =>
                                                      c.decideCurfew(r, false),
                                                  child: const Text(
                                                      'Note concern'))),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: FilledButton(
                                                  onPressed: () =>
                                                      c.decideCurfew(r, true),
                                                  child: const Text(
                                                      'Confirm details'))),
                                        ])
                                      ],
                                    ])),
                          )),
                ])));
  }
}

class GuardianPaymentStatusPage extends StatelessWidget {
  const GuardianPaymentStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GuardianController.instance;

    return PageFrame(
      title: 'Payment status',
      subtitle: 'Linked tenant balances and verification',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MetricCard(
              label: 'Outstanding total',
              value: money(controller.outstandingTotal),
              detail: 'Unverified and unpaid records',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 16),
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
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search notices...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: Icon(
                      cat.$3,
                      size: 16,
                      color: isSelected ? Colors.white : _categoryColor(cat.$1),
                    ),
                    label: Text(cat.$2),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat.$1),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
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
                padding: const EdgeInsets.only(bottom: 12),
                child: CarmelitaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 14, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  _categoryTitle(item.category),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.isPinned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
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
                                    size: 12,
                                    color: Color(0xFFD48806),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Pinned',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD48806),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.body,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppColors.taupe,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.authorName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: AppColors.taupe,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${shortDate(item.createdAt)} • ${timeText(item.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
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
