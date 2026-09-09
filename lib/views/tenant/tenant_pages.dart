import 'package:flutter/material.dart';
import '../../controllers/tenant_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../widgets/feature_widgets.dart';

class TenantDashboardPage extends StatelessWidget {
  const TenantDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TenantController.instance;
    final payment = controller.payments.first;
    final maintenance =
        controller.maintenance.isEmpty ? null : controller.maintenance.first;

    return PageFrame(
      title: 'Home',
      subtitle: 'Tenant dashboard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElegantHeader(
            eyebrow: 'Welcome home',
            title: 'Good afternoon, Anna.',
            subtitle: 'Room 204 • Bed 2 • Second Floor',
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your room',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Room 204 • Bed 2 • 4/4 occupied',
                      ),
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
                label: 'Amount due',
                value: money(payment.amount),
                detail: 'August rent • Due Aug 15',
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFFAA8A45),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PaymentsPage(),
                  ),
                ),
              ),
              MutedDashboardItem(
                label: 'Gate status',
                value: 'Inside',
                detail: 'Last IN • 8:14 PM',
                icon: Icons.sensor_door_outlined,
                color: const Color(0xFF56886B),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GateCurfewPage(),
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
          AttentionCard(
            icon: Icons.payments_outlined,
            title: 'August rent is due soon',
            subtitle: '${money(payment.amount)} • Due Aug 15',
            status: payment.status,
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
              subtitle: '${maintenance.location} • ${maintenance.description}',
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
              status: controller.maintenanceLoading ? 'Loading' : 'Clear',
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
                label: 'Curfew request',
                detail: 'Request an exception',
                icon: Icons.schedule_outlined,
                color: const Color(0xFF7D70A0),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CurfewExceptionPage(),
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
          AttentionCard(
            icon: Icons.campaign_outlined,
            title: MockData.announcements.first.title,
            subtitle: MockData.announcements.first.body,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TenantAnnouncementsPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MyRoomPage extends StatelessWidget {
  const MyRoomPage({super.key});
  @override
  Widget build(BuildContext context) {
    final room = TenantController.instance.room;
    return PageFrame(
        title: 'My room',
        subtitle: 'Assignment and utility information',
        child: Column(children: [
          const PhotoHero(
              image: AppAssets.room,
              title: 'Room 204',
              subtitle: 'Second Floor • Bed 2',
              height: 250),
          const SizedBox(height: 16),
          CarmelitaCard(
              child: Column(children: [
            InfoRow(
                label: 'Room',
                value: room.number,
                icon: Icons.meeting_room_outlined),
            InfoRow(
                label: 'Bed space',
                value: room.bedSpace,
                icon: Icons.bed_outlined),
            InfoRow(
                label: 'Occupancy',
                value: '${room.occupied}/${room.capacity}',
                icon: Icons.groups_outlined),
            InfoRow(
                label: 'Utilities',
                value: room.utilitySummary,
                icon: Icons.bolt_outlined),
          ])),
          const SizedBox(height: 16),
          CarmelitaCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Roommates',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 8),
                ...room.roommates.map((name) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(name))),
              ])),
        ]));
  }
}

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = TenantController.instance;
    return PageFrame(
      title: 'Payments & utilities',
      subtitle: 'Balances, due dates, and history',
      floatingActionButton: FloatingActionButton(
        tooltip: 'Upload payment proof',
        backgroundColor: const Color(0xFF627FA8),
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UploadPaymentProofPage()),
        ),
        child: const Icon(Icons.upload_file_outlined),
      ),
      child: AnimatedBuilder(
          animation: c,
          builder: (context, _) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                const MutedDashboardGrid(compact: true, items: [
                  MutedDashboardItem(
                      label: 'Outstanding',
                      value: '₱4,400',
                      detail: 'Rent + utilities',
                      icon: Icons.account_balance_wallet_outlined,
                      color: Color(0xFFAA8A45)),
                  MutedDashboardItem(
                      label: 'Next due date',
                      value: 'Aug 10',
                      detail: 'Utilities',
                      icon: Icons.event_outlined,
                      color: Color(0xFF627FA8)),
                ]),
                const SizedBox(height: 22),
                const SectionTitle('Payment records'),
                const SizedBox(height: 10),
                ...c.payments.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CarmelitaCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: TimelineTile(
                          compact: true,
                          icon: Icons.receipt_long_outlined,
                          color: p.status.toLowerCase().contains('verified')
                              ? const Color(0xFF56886B)
                              : p.status.toLowerCase().contains('rejected')
                                  ? const Color(0xFFAA6870)
                                  : const Color(0xFFAA8A45),
                          title: p.label,
                          subtitle:
                              '${money(p.amount)} • Due ${shortDate(p.dueDate)}',
                          trailing: StatusPill(p.status)),
                    ),
                  ),
                ),
              ])),
    );
  }
}

class UploadPaymentProofPage extends StatefulWidget {
  const UploadPaymentProofPage({super.key});

  @override
  State<UploadPaymentProofPage> createState() => _UploadPaymentProofPageState();
}

class _UploadPaymentProofPageState extends State<UploadPaymentProofPage> {
  final amount = TextEditingController();
  final reference = TextEditingController();
  final receiptDate = TextEditingController();
  String method = 'GCash';
  bool receiptSelected = false;

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    receiptDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Upload payment proof',
      subtitle: 'Extract receipt details with OCR, review, then submit',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
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
            const SizedBox(height: 14),
            TextField(
                controller: receiptDate,
                decoration: const InputDecoration(
                    labelText: 'Receipt date', hintText: 'Extracted by OCR')),
            const SizedBox(height: 14),
            TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reference,
              decoration: const InputDecoration(
                labelText: 'Reference number',
                hintText: 'Optional for cash payments',
              ),
            ),
            const SizedBox(height: 14),
            CarmelitaCard(
              onTap: () {
                setState(() => receiptSelected = true);
                showAppSnackBar(
                  context,
                  'Receipt selected. OCR backend is not connected; review or enter the values manually.',
                );
              },
              child: Row(
                children: [
                  Icon(
                    receiptSelected
                        ? Icons.check_circle_outline
                        : Icons.add_photo_alternate_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      receiptSelected
                          ? 'Receipt selected • OCR values ready for review'
                          : 'Add receipt or screenshot',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                  final parsedAmount = double.tryParse(amount.text.trim());
                  if (parsedAmount == null || parsedAmount <= 0) {
                    showAppSnackBar(context, 'Enter a valid payment amount.');
                    return;
                  }
                  if (!receiptSelected && method != 'Cash') {
                    showAppSnackBar(
                      context,
                      'Add the receipt or screenshot first.',
                    );
                    return;
                  }

                  TenantController.instance.submitPaymentProof(
                    amount: parsedAmount,
                    method: method,
                    reference: reference.text,
                  );
                  showAppSnackBar(
                    context,
                    'Payment proof submitted for owner/caretaker review.',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Submit for review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TenantReportsHubPage extends StatelessWidget {
  const TenantReportsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TenantController.instance;

    return PageFrame(
      title: 'Reports',
      subtitle: 'Maintenance and confidential concerns',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
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
                  value: '${controller.maintenance.length}',
                  detail: 'Submitted issues',
                  icon: Icons.build_outlined,
                  color: const Color(0xFFB47A52),
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
        ),
      ),
    );
  }

  Widget _hub(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget page,
  ) {
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
        trailing: const Icon(Icons.chevron_right),
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

  @override
  void initState() {
    super.initState();
    controller.loadMaintenance();
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
        title: const Text('Delete maintenance report?'),
        content: Text(
          'Delete the ${report.category.toLowerCase()} report for '
          '${report.location}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await controller.deleteMaintenance(report.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Maintenance report deleted.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Maintenance reports',
      subtitle: 'Submitted issues and progress',
      actions: [
        IconButton(
          tooltip: 'Refresh reports',
          onPressed:
              controller.maintenanceLoading ? null : controller.loadMaintenance,
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
                      onPressed: controller.loadMaintenance,
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
              const SizedBox(height: 22),
              const SectionTitle('Submitted reports'),
              const SizedBox(height: 10),
              if (controller.maintenanceError != null) ...[
                CarmelitaCard(
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 10),
                      Expanded(child: Text(controller.maintenanceError!)),
                      TextButton(
                        onPressed: controller.loadMaintenance,
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
              else
                ...reports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CarmelitaCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
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
                            '${report.description}\n${shortDate(report.createdAt)}',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusPill(report.status),
                            if (report.status == 'Pending') ...[
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
                                        Text('Delete'),
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
    'Other',
  ];

  static const locations = [
    'Room 204',
    'Room 204 • Bathroom',
    'Second-floor corridor',
    'Kitchen',
    'Laundry area',
    'Other common area',
  ];

  static const urgencies = ['Low', 'Medium', 'High'];

  late final TextEditingController description;
  late String category;
  late String urgency;
  late String location;
  bool saving = false;

  bool get editing => widget.report != null;

  @override
  void initState() {
    super.initState();
    final report = widget.report;
    description = TextEditingController(text: report?.description ?? '');
    category = categories.contains(report?.category)
        ? report!.category
        : categories.first;
    urgency = urgencies.contains(report?.urgency) ? report!.urgency : 'Medium';
    location = locations.contains(report?.location)
        ? report!.location
        : locations.first;
  }

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cleanDescription = description.text.trim();
    if (cleanDescription.length < 3) {
      showAppSnackBar(context, 'Enter a short description first.');
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
        );
      } else {
        await TenantController.instance.submitMaintenance(
          category: category,
          description: cleanDescription,
          location: location,
          urgency: urgency,
        );
      }

      if (!mounted) return;
      showAppSnackBar(
        context,
        editing ? 'Maintenance report updated.' : 'Maintenance report added.',
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
              DropdownButtonFormField<String>(
                initialValue: location,
                decoration: const InputDecoration(labelText: 'Room / area'),
                items: locations
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (value) => setState(() => location = value ?? location),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: urgency,
                decoration: const InputDecoration(labelText: 'Urgency'),
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
              const SizedBox(height: 14),
              CarmelitaCard(
                onTap: saving
                    ? null
                    : () => showAppSnackBar(
                          context,
                          'Photo upload will be connected in a later feature.',
                        ),
                child: const Row(
                  children: [
                    Icon(Icons.add_a_photo_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add photo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
              const SizedBox(height: 18),
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

class InteractiveFloorPlanPage extends StatelessWidget {
  const InteractiveFloorPlanPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
      title: 'Interactive floor plan',
      subtitle: 'Select an exact maintenance location',
      child: FloorPlanCanvas());
}

class TenantAnnouncementsPage extends StatelessWidget {
  const TenantAnnouncementsPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Announcements',
      subtitle: 'Dormitory notices and reminders',
      child: Column(
          children: MockData.announcements
              .map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CarmelitaCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(a.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 17)),
                          const SizedBox(height: 7),
                          Text(a.body),
                          const SizedBox(height: 10),
                          Text('${shortDate(a.createdAt)} • ${a.audience}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ])),
                  ))
              .toList()));
}

class TenantMessagesPage extends StatelessWidget {
  const TenantMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TenantController.instance;

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
              builder: (_) => const TenantConversationPage(),
            ),
          ),
        ),
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
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = TenantController.instance;

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
                          alignment: item.senderRole == 'tenant'
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
                              color: item.senderRole == 'tenant'
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
                                  item.senderRole == 'tenant' ? 15 : 4,
                                ),
                                bottomRight: Radius.circular(
                                  item.senderRole == 'tenant' ? 4 : 15,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: item.senderRole == 'tenant'
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
                                Text(
                                  timeText(item.sentAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
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
                    onPressed: () {
                      if (message.text.trim().isEmpty) return;
                      controller.sendMessage(message.text);
                      message.clear();
                    },
                    icon: const Icon(Icons.send_outlined),
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

class GateCurfewPage extends StatelessWidget {
  const GateCurfewPage({super.key});
  @override
  Widget build(BuildContext context) {
    final events = TenantController.instance.gateEvents
        .where((e) => e.person == 'Anna Dela Cruz')
        .toList();
    return PageFrame(
        title: 'Gate & curfew',
        subtitle: 'Current status and recent gate activity',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'GATE SUMMARY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 1.3,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          CarmelitaCard(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 330;
                final copy = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CURRENT STATUS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Inside dormitory',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text('Last IN: 8:14 PM • Face recognition'),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Color(0x1356886B),
                            foregroundColor: Color(0xFF56886B),
                            child: Icon(Icons.home_outlined),
                          ),
                          SizedBox(width: 12),
                          StatusPill('IN'),
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
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0x1356886B),
                      foregroundColor: Color(0xFF56886B),
                      child: Icon(Icons.home_outlined),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: copy),
                    const SizedBox(width: 10),
                    const StatusPill('IN'),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          const MutedDashboardGrid(compact: true, items: [
            MutedDashboardItem(
                label: 'Curfew',
                value: '10:00 PM',
                detail: 'Standard schedule',
                icon: Icons.schedule_outlined,
                color: Color(0xFF7D70A0)),
            MutedDashboardItem(
                label: 'Late records',
                value: '0',
                detail: 'This month',
                icon: Icons.warning_amber_outlined,
                color: Color(0xFFAA8A45))
          ]),
          const SizedBox(height: 20),
          MutedActionGrid(items: [
            MutedActionItem(
                label: 'Curfew exception',
                detail: 'Request a late return',
                color: const Color(0xFF7D70A0),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CurfewExceptionPage())),
                icon: Icons.event_available_outlined),
            MutedActionItem(
                label: 'Visitor request',
                detail: 'Register a visitor',
                color: const Color(0xFF568F8E),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const VisitorRequestPage())),
                icon: Icons.person_add_alt_outlined),
          ]),
          const SizedBox(height: 22),
          const SectionTitle('Recent gate records'),
          const SizedBox(height: 10),
          ...events.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CarmelitaCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: TimelineTile(
                    compact: true,
                    icon: e.direction == 'IN' ? Icons.login : Icons.logout,
                    color: e.direction == 'IN'
                        ? const Color(0xFF56886B)
                        : const Color(0xFF627FA8),
                    title: e.direction,
                    subtitle:
                        '${shortDate(e.time)} • ${timeText(e.time)} • ${e.verification}',
                    trailing: StatusPill(e.status)),
              ),
            ),
          ),
        ]));
  }
}

class CurfewExceptionPage extends StatefulWidget {
  const CurfewExceptionPage({super.key});
  @override
  State<CurfewExceptionPage> createState() => _CurfewExceptionPageState();
}

class _CurfewExceptionPageState extends State<CurfewExceptionPage> {
  final reason = TextEditingController();
  final destination = TextEditingController();
  DateTime expected = DateTime(2026, 8, 9, 23);
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Curfew exception',
      subtitle: 'Guardian approval is required',
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'REQUEST DETAILS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1.3,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 10),
            LabeledField(
                label: 'Reason',
                hint: 'Why do you need to return late?',
                controller: reason,
                maxLines: 3),
            const SizedBox(height: 14),
            LabeledField(
                label: 'Destination',
                hint: 'Where will you be?',
                controller: destination),
            const SizedBox(height: 14),
            CarmelitaCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color:
                              const Color(0xFF7D70A0).withValues(alpha: .075),
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.schedule_outlined,
                          color: Color(0xFF7D70A0), size: 19)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          'Expected return: ${shortDate(expected)} • ${timeText(expected)}',
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  TextButton(
                      onPressed: () => setState(() =>
                          expected = expected.add(const Duration(minutes: 30))),
                      child: const Text('+30 min'))
                ])),
            const SizedBox(height: 14),
            CarmelitaCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -2),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.verified_user_outlined,
                        color: Color(0xFF56886B)),
                    title: const Text('Guardian confirmation',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                    subtitle: const Text(
                        'Guardian input supports the owner/caretaker’s final decision.',
                        style: TextStyle(fontSize: 11)))),
            const SizedBox(height: 18),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () {
                      if (reason.text.trim().isEmpty ||
                          destination.text.trim().isEmpty) {
                        showAppSnackBar(
                            context, 'Complete the reason and destination.');
                        return;
                      }
                      TenantController.instance.submitCurfew(
                          reason: reason.text.trim(),
                          destination: destination.text.trim(),
                          expectedReturn: expected);
                      showAppSnackBar(context, 'Curfew request submitted.');
                      Navigator.of(context).pop();
                    },
                    child: const Text('Submit request'))),
          ])));
}

class VisitorRequestPage extends StatefulWidget {
  const VisitorRequestPage({super.key});

  @override
  State<VisitorRequestPage> createState() => _VisitorRequestPageState();
}

class _VisitorRequestPageState extends State<VisitorRequestPage> {
  final name = TextEditingController();
  final relation = TextEditingController();
  DateTime schedule = DateTime(2026, 8, 10, 14);

  @override
  void dispose() {
    name.dispose();
    relation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Visitor request',
      subtitle: 'Register an expected visitor',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            CarmelitaCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  InfoRow(
                    label: 'Schedule',
                    value: '${shortDate(schedule)} • ${timeText(schedule)}',
                    icon: Icons.event_outlined,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => setState(
                          () =>
                              schedule = schedule.add(const Duration(days: 1)),
                        ),
                        child: const Text('+1 day'),
                      ),
                      OutlinedButton(
                        onPressed: () => setState(
                          () => schedule =
                              schedule.add(const Duration(minutes: 30)),
                        ),
                        child: const Text('+30 min'),
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
                onPressed: () {
                  if (name.text.trim().isEmpty ||
                      relation.text.trim().isEmpty) {
                    showAppSnackBar(
                      context,
                      'Complete the visitor name and relationship.',
                    );
                    return;
                  }

                  TenantController.instance.submitVisitor(
                    visitorName: name.text.trim(),
                    relationship: relation.text.trim(),
                    schedule: schedule,
                  );
                  showAppSnackBar(context, 'Visitor request submitted.');
                  Navigator.of(context).pop();
                },
                child: const Text('Submit visitor request'),
              ),
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
                  'Only authorized owner/caretaker accounts should review '
                  'these reports after backend role policies are applied.',
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
              onChanged: (value) =>
                  setState(() => category = value ?? category),
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
                onPressed: () {
                  if (details.text.trim().isEmpty) {
                    showAppSnackBar(
                      context,
                      'Enter the concern details before submitting.',
                    );
                    return;
                  }

                  TenantController.instance.submitConcern(
                    category: category,
                    summary: details.text.trim(),
                  );
                  showAppSnackBar(
                    context,
                    'Confidential report submitted.',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Submit confidential report'),
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
            title: 'Curfew',
            icon: Icons.schedule_outlined,
            body:
                'Return by the standard curfew unless an exception has been approved by the guardian and owner/caretaker.'),
        SizedBox(height: 12),
        _PolicyCard(
            title: 'Payments',
            icon: Icons.payments_outlined,
            body:
                'Submit payments according to the agreed schedule. Uploaded proof remains pending until verified.'),
        SizedBox(height: 12),
        _PolicyCard(
            title: 'Safety and access',
            icon: Icons.shield_outlined,
            body:
                'Do not allow unregistered people to enter through the gate. Report unusual access events immediately.'),
      ]));
}

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
