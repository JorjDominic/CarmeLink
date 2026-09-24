import 'package:flutter/material.dart';

import '../../core/utils/cleaning_schedule_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/room_operations_service.dart';
import '../../services/room_service.dart';
import '../../services/table_refresh_subscription.dart';

class StaffRoomCleaningPage extends StatefulWidget {
  const StaffRoomCleaningPage({
    required this.roomId,
    required this.roomNumber,
    required this.beds,
    super.key,
  });

  final String roomId;
  final String roomNumber;
  final List<BedRecord> beds;

  @override
  State<StaffRoomCleaningPage> createState() => _StaffRoomCleaningPageState();
}

class _StaffRoomCleaningPageState extends State<StaffRoomCleaningPage> {
  final service = const RoomOperationsService();
  late final TableRefreshSubscription subscription;
  List<CleaningScheduleRecord> schedules = const [];
  List<CleaningNoncomplianceReport> reports = const [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
      'room-cleaning-${widget.roomId}',
      const [
        'cleaning_schedules',
        'cleaning_noncompliance_reports',
        'cleaning_report_history',
      ],
      () {
        if (mounted) _load(showSpinner: false);
      },
    );
  }

  @override
  void dispose() {
    subscription.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final ids = widget.beds.map((bed) => bed.id);
      final latestSchedules = await service.listSchedulesForBeds(ids);
      final latestReports = await service.listReportsForBeds(ids);

      if (!mounted) return;
      setState(() {
        schedules = latestSchedules;
        reports = latestReports;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = roomOperationsError(error);
      });
    }
  }

  List<CleaningScheduleRecord> _forBed(String bedId) =>
      schedules.where((item) => item.bedSpaceId == bedId).toList()
        ..sort((a, b) => a.weekday.compareTo(b.weekday));

  Future<void> _editBed(BedRecord bed) async {
    final current = _forBed(bed.id);
    final selected = current.map((item) => item.weekday).toSet();
    final notes = TextEditingController(
      text: current.isEmpty ? '' : current.first.taskNotes,
    );
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('${bed.label} cleaning schedule'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign duties by bed identifier. Tenant names are not shown in the rota.',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(7, (index) {
                    final day = index + 1;
                    return CheckboxListTile(
                      value: selected.contains(day),
                      contentPadding: EdgeInsets.zero,
                      title: Text(cleaningWeekdayLabel(day)),
                      onChanged: saving
                          ? null
                          : (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selected.add(day);
                                } else {
                                  selected.remove(day);
                                }
                              });
                            },
                    );
                  }),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    enabled: !saving,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Cleaning instructions (optional)',
                      hintText: 'e.g. Sweep floor and take out trash',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await service.setBedSchedule(
                          bedSpaceId: bed.id,
                          weekdays: normalizeCleaningWeekdays(selected),
                          taskNotes: notes.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            roomOperationsError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save schedule'),
            ),
          ],
        ),
      ),
    );

    notes.dispose();

    if (changed == true && mounted) {
      await _load(showSpinner: false);
    }
  }

  Future<void> _reviewReport(CleaningNoncomplianceReport report) async {
    var status = report.status;
    final notes = TextEditingController(text: report.staffNotes);
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Review ${report.reportedBedLabel} report'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoRow(
                    label: 'Reporter',
                    value: report.reporterName ?? 'Tenant',
                    icon: Icons.person_outline,
                  ),
                  InfoRow(
                    label: 'Reported bed',
                    value: report.reportedBedLabel,
                    icon: Icons.bed_outlined,
                  ),
                  const SizedBox(height: 10),
                  Text(report.description),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(
                        value: 'reviewing',
                        child: Text('Reviewing'),
                      ),
                      DropdownMenuItem(
                        value: 'resolved',
                        child: Text('Resolved'),
                      ),
                      DropdownMenuItem(
                        value: 'dismissed',
                        child: Text('Dismissed'),
                      ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => status = value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notes,
                    enabled: !saving,
                    maxLength: 2000,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Staff notes',
                      hintText:
                          'Required when resolving or dismissing the report',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await service.updateCleaningReport(
                          report: report,
                          status: status,
                          staffNotes: notes.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            roomOperationsError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save review'),
            ),
          ],
        ),
      ),
    );

    notes.dispose();

    if (changed == true && mounted) {
      await _load(showSpinner: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Room ${widget.roomNumber} cleaning',
      subtitle: 'Bed-based schedule and restricted compliance reports',
      useScriptTitle: false,
      onRefresh: () => _load(showSpinner: false),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading ? null : () => _load(showSpinner: false),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: loading && schedules.isEmpty && reports.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CarmelitaCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.privacy_tip_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cleaning duties use bed identifiers. Private reports and reporter identities are visible only to authorized staff.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  CarmelitaCard(
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded),
                        const SizedBox(width: 10),
                        Expanded(child: Text(errorMessage!)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const SectionTitle(
                  'Weekly cleaning rota',
                  subtitle: 'Set one or more cleaning days for each bed',
                ),
                const SizedBox(height: 10),
                if (widget.beds.isEmpty)
                  const EmptyState(
                    icon: Icons.bed_outlined,
                    title: 'No bed spaces',
                    message: 'Configure bed spaces before adding a rota.',
                  )
                else
                  ...widget.beds.map((bed) {
                    final entries = _forBed(bed.id);
                    final days = entries.isEmpty
                        ? 'No cleaning days assigned'
                        : entries
                            .map((item) => cleaningWeekdayShort(item.weekday))
                            .join(' • ');
                    final note =
                        entries.isEmpty ? '' : entries.first.taskNotes.trim();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarmelitaCard(
                        onTap: () => _editBed(bed),
                        child: Row(
                          children: [
                            CircleAvatar(
                              child: Icon(
                                bed.occupied
                                    ? Icons.person_outline
                                    : Icons.bed_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bed.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(days),
                                  if (note.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      note,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_calendar_outlined),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 22),
                SectionTitle(
                  'Private reports',
                  subtitle:
                      '${reports.where((r) => r.status == 'open' || r.status == 'reviewing').length} active • ${reports.length} total',
                ),
                const SizedBox(height: 10),
                if (reports.isEmpty)
                  const EmptyState(
                    icon: Icons.verified_outlined,
                    title: 'No cleaning reports',
                    message:
                        'Private tenant non-compliance reports will appear here.',
                  )
                else
                  ...reports.map(
                    (report) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarmelitaCard(
                        onTap: () => _reviewReport(report),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.reportedBedLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                StatusPill(
                                  cleaningReportStatusLabel(report.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Reporter: ${report.reporterName ?? 'Tenant'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              report.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (report.staffNotes.trim().isNotEmpty) ...[
                              const Divider(height: 24),
                              Text(
                                'Staff notes: ${report.staffNotes}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class TenantCleaningSchedulePage extends StatefulWidget {
  const TenantCleaningSchedulePage({super.key});

  @override
  State<TenantCleaningSchedulePage> createState() =>
      _TenantCleaningSchedulePageState();
}

class _TenantCleaningSchedulePageState
    extends State<TenantCleaningSchedulePage> {
  final service = const RoomOperationsService();
  late final TableRefreshSubscription subscription;
  TenantCleaningContext? contextData;
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
      'tenant-cleaning',
      const [
        'cleaning_schedules',
        'cleaning_noncompliance_reports',
      ],
      () {
        if (mounted) _load(showSpinner: false);
      },
    );
  }

  @override
  void dispose() {
    subscription.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final latest = await service.loadMyCleaningContext();
      if (!mounted) return;
      setState(() {
        contextData = latest;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = roomOperationsError(error);
      });
    }
  }

  Map<String, List<CleaningScheduleRecord>> _grouped(
    List<CleaningScheduleRecord> values,
  ) {
    final grouped = <String, List<CleaningScheduleRecord>>{};
    for (final item in values) {
      grouped.putIfAbsent(item.bedSpaceId, () => []).add(item);
    }
    for (final items in grouped.values) {
      items.sort((a, b) => a.weekday.compareTo(b.weekday));
    }
    return grouped;
  }

  Future<void> _reportMissedDuty() async {
    final data = contextData;
    if (data == null) return;

    final grouped = _grouped(data.schedules);
    final reportable = grouped.entries
        .where((entry) => entry.key != data.ownBedSpaceId)
        .map((entry) => entry.value.first)
        .toList()
      ..sort((a, b) => a.bedLabel.compareTo(b.bedLabel));

    if (reportable.isEmpty) {
      showAppSnackBar(
        context,
        'There is no active roommate cleaning duty to report.',
      );
      return;
    }

    var selectedBedId = reportable.first.bedSpaceId;
    final description = TextEditingController();
    var saving = false;

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Report missed cleaning duty'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This report is private. Roommates cannot see who submitted it.',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBedId,
                    decoration: const InputDecoration(
                      labelText: 'Assigned bed',
                    ),
                    items: reportable
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.bedSpaceId,
                            child: Text(item.bedLabel),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => selectedBedId = value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: description,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1500,
                    decoration: const InputDecoration(
                      labelText: 'What happened?',
                      hintText:
                          'Describe the cleaning duty that was not completed.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final validation =
                          validateCleaningReportDescription(description.text);
                      if (validation != null) {
                        showAppSnackBar(dialogContext, validation);
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        await service.submitCleaningReport(
                          reportedBedSpaceId: selectedBedId,
                          description: description.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            roomOperationsError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Submitting…' : 'Submit privately'),
            ),
          ],
        ),
      ),
    );

    description.dispose();

    if (submitted == true && mounted) {
      showAppSnackBar(context, 'Cleaning report submitted privately.');
      await _load(showSpinner: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = contextData;

    return PageFrame(
      title: 'Cleaning schedule',
      subtitle: data == null
          ? 'Room cleaning duties'
          : 'Room ${data.roomNumber} • ${data.ownBedLabel}',
      onRefresh: () => _load(showSpinner: false),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading ? null : () => _load(showSpinner: false),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _reportMissedDuty,
              icon: const Icon(Icons.report_outlined),
              label: const Text('Report missed duty'),
            ),
      child: loading && data == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : data == null
              ? EmptyState(
                  icon: Icons.bed_outlined,
                  title: 'No active room assignment',
                  message: errorMessage ??
                      'A room assignment is required before a cleaning schedule can be shown.',
                  action: FilledButton.icon(
                    onPressed: () => _load(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                )
              : _TenantCleaningBody(
                  data: data,
                  errorMessage: errorMessage,
                ),
    );
  }
}

class _TenantCleaningBody extends StatelessWidget {
  const _TenantCleaningBody({
    required this.data,
    required this.errorMessage,
  });

  final TenantCleaningContext data;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<CleaningScheduleRecord>>{};
    for (final item in data.schedules) {
      grouped.putIfAbsent(item.bedSpaceId, () => []).add(item);
    }
    for (final items in grouped.values) {
      items.sort((a, b) => a.weekday.compareTo(b.weekday));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CarmelitaCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The rota uses bed identifiers instead of roommate names. Any non-compliance report you submit is restricted to authorized staff.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          CarmelitaCard(child: Text(errorMessage!)),
        ],
        const SizedBox(height: 22),
        const SectionTitle(
          'Weekly rota',
          subtitle: 'Cleaning assignments for your room',
        ),
        const SizedBox(height: 10),
        if (grouped.isEmpty)
          const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No cleaning schedule yet',
            message:
                'Dormitory staff have not published cleaning duties for this room.',
          )
        else
          ...grouped.values.map((entries) {
            final first = entries.first;
            final isSelf = first.bedSpaceId == data.ownBedSpaceId;
            final days = entries
                .map((item) => cleaningWeekdayShort(item.weekday))
                .join(' • ');
            final note = first.taskNotes.trim();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CarmelitaCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      child: Icon(Icons.cleaning_services),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  first.bedLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (isSelf) ...[
                                const SizedBox(width: 8),
                                const StatusPill('Your bed'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(days),
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              note,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 22),
        SectionTitle(
          'Your private reports',
          subtitle: '${data.reports.length} submitted',
        ),
        const SizedBox(height: 10),
        if (data.reports.isEmpty)
          const EmptyState(
            icon: Icons.verified_user_outlined,
            title: 'No reports submitted',
            message:
                'Reports about missed cleaning duties remain private from roommates.',
          )
        else
          ...data.reports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CarmelitaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.reportedBedLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusPill(
                          cleaningReportStatusLabel(report.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(report.description),
                    if (report.staffNotes.trim().isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        'Staff response: ${report.staffNotes}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
