import 'package:flutter/material.dart';

import '../../core/utils/employee_curfew_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/employee_curfew_profile_service.dart';
import '../../services/table_refresh_subscription.dart';

String _profileDate(DateTime value) =>
    '${value.month}/${value.day}/${value.year}';

String _profileWeekdays(List<int> weekdays) {
  final sorted = [...weekdays]..sort();
  return sorted.map(employeeCurfewWeekdayLabel).join(', ');
}

class EmployeeCurfewProfilesPage extends StatefulWidget {
  const EmployeeCurfewProfilesPage({super.key});

  @override
  State<EmployeeCurfewProfilesPage> createState() =>
      _EmployeeCurfewProfilesPageState();
}

class _EmployeeCurfewProfilesPageState
    extends State<EmployeeCurfewProfilesPage> {
  final service = const EmployeeCurfewProfileService();
  late final TableRefreshSubscription subscription;
  List<EmployeeCurfewTenantOption> tenants = const [];
  List<EmployeeCurfewProfileRecord> profiles = const [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
      'employee-curfew-profiles',
      const [
        'employee_curfew_profiles',
        'employee_curfew_profile_events',
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
      final latestTenants = await service.listTenantOptions();
      final latestProfiles = await service.listStaffProfiles();
      if (!mounted) return;
      setState(() {
        tenants = latestTenants;
        profiles = latestProfiles;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = employeeCurfewProfileError(error);
      });
    }
  }

  Future<void> _edit({EmployeeCurfewProfileRecord? profile}) async {
    if (profile != null && profile.status != 'draft') return;

    if (tenants.isEmpty) {
      showAppSnackBar(context, 'No tenant accounts are available.');
      return;
    }

    var tenantId = profile?.tenantId ?? tenants.first.id;
    var returnMinutes = profile?.allowedReturnMinutes ?? 23 * 60;
    var weekdays = (profile?.weekdays.toSet() ?? <int>{1, 2, 3, 4, 5}).toSet();
    var effectiveFrom = profile?.effectiveFrom ?? DateTime.now();
    DateTime? effectiveUntil = profile?.effectiveUntil;
    final note = TextEditingController(
      text: profile?.workScheduleNote ?? '',
    );
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            profile == null
                ? 'New employee curfew profile'
                : 'Edit employee curfew profile',
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CarmelitaCard(
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'This profile records an approved employment-based curfew schedule. It does not change gate/geofence evaluation until the shared evaluator integration is reviewed.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: tenantId,
                    decoration: const InputDecoration(labelText: 'Tenant'),
                    items: tenants
                        .map(
                          (tenant) => DropdownMenuItem(
                            value: tenant.id,
                            child: Text(tenant.name),
                          ),
                        )
                        .toList(),
                    onChanged: profile != null || saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => tenantId = value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Approved return time'),
                    subtitle: Text(
                      employeeCurfewTimeLabel(returnMinutes),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: saving
                        ? null
                        : () async {
                            final selected = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay(
                                hour: returnMinutes ~/ 60,
                                minute: returnMinutes % 60,
                              ),
                            );
                            if (selected == null) return;
                            setDialogState(() {
                              returnMinutes =
                                  selected.hour * 60 + selected.minute;
                            });
                          },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Applicable weekdays',
                    style: Theme.of(dialogContext)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: employeeCurfewWeekdays.map((day) {
                      final selected = weekdays.contains(day);
                      return FilterChip(
                        selected: selected,
                        label: Text(employeeCurfewWeekdayLabel(day)),
                        onSelected: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  if (value) {
                                    weekdays.add(day);
                                  } else {
                                    weekdays.remove(day);
                                  }
                                });
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('Effective from'),
                    subtitle: Text(_profileDate(effectiveFrom)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: saving
                        ? null
                        : () async {
                            final selected = await showDatePicker(
                              context: dialogContext,
                              initialDate: effectiveFrom,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 1460)),
                            );
                            if (selected != null) {
                              setDialogState(() => effectiveFrom = selected);
                            }
                          },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_busy_outlined),
                    title: const Text('Effective until'),
                    subtitle: Text(
                      effectiveUntil == null
                          ? 'No end date'
                          : _profileDate(effectiveUntil!),
                    ),
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        if (effectiveUntil != null)
                          IconButton(
                            tooltip: 'Clear end date',
                            onPressed: saving
                                ? null
                                : () => setDialogState(
                                      () => effectiveUntil = null,
                                    ),
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'Choose end date',
                          onPressed: saving
                              ? null
                              : () async {
                                  final selected = await showDatePicker(
                                    context: dialogContext,
                                    initialDate:
                                        effectiveUntil ?? effectiveFrom,
                                    firstDate: effectiveFrom,
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 1460)),
                                  );
                                  if (selected != null) {
                                    setDialogState(
                                      () => effectiveUntil = selected,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.edit_calendar_outlined),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Work schedule note',
                      hintText:
                          'Document the approved employment schedule or operational basis.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final weekdayError =
                          validateEmployeeCurfewWeekdays(weekdays);
                      if (weekdayError != null) {
                        showAppSnackBar(dialogContext, weekdayError);
                        return;
                      }

                      final dateError = validateEmployeeCurfewEffectiveDates(
                        effectiveFrom,
                        effectiveUntil,
                      );
                      if (dateError != null) {
                        showAppSnackBar(dialogContext, dateError);
                        return;
                      }

                      final noteError =
                          validateEmployeeCurfewWorkNote(note.text);
                      if (noteError != null) {
                        showAppSnackBar(dialogContext, noteError);
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        final selectedDays = weekdays.toList()..sort();
                        if (profile == null) {
                          await service.createProfile(
                            tenantId: tenantId,
                            allowedReturnMinutes: returnMinutes,
                            weekdays: selectedDays,
                            effectiveFrom: effectiveFrom,
                            effectiveUntil: effectiveUntil,
                            workScheduleNote: note.text,
                          );
                        } else {
                          await service.updateProfile(
                            profile: profile,
                            allowedReturnMinutes: returnMinutes,
                            weekdays: selectedDays,
                            effectiveFrom: effectiveFrom,
                            effectiveUntil: effectiveUntil,
                            workScheduleNote: note.text,
                          );
                        }

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            employeeCurfewProfileError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save draft'),
            ),
          ],
        ),
      ),
    );

    note.dispose();

    if (changed == true && mounted) {
      await _load(showSpinner: false);
    }
  }

  Future<void> _approve(EmployeeCurfewProfileRecord profile) async {
    final note = TextEditingController();
    var saving = false;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Approve employee curfew profile'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Approval makes this schedule visible to the tenant. Gate/geofence evaluation remains unchanged until the shared evaluator integration is reviewed.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  enabled: !saving,
                  maxLength: 2000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Approval note (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await service.approveProfile(
                          profile: profile,
                          note: note.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            employeeCurfewProfileError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Approving…' : 'Approve'),
            ),
          ],
        ),
      ),
    );

    note.dispose();
    if (approved == true && mounted) {
      await _load(showSpinner: false);
    }
  }

  Future<void> _revoke(EmployeeCurfewProfileRecord profile) async {
    final reason = TextEditingController();
    var saving = false;

    final revoked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Revoke employee curfew profile'),
          content: TextField(
            controller: reason,
            enabled: !saving,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Revocation reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (reason.text.trim().length < 5) {
                        showAppSnackBar(
                          dialogContext,
                          'Revocation reason must contain at least 5 characters.',
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        await service.revokeProfile(
                          profile: profile,
                          reason: reason.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            employeeCurfewProfileError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Revoking…' : 'Revoke'),
            ),
          ],
        ),
      ),
    );

    reason.dispose();
    if (revoked == true && mounted) {
      await _load(showSpinner: false);
    }
  }

  Future<void> _showHistory(EmployeeCurfewProfileRecord profile) async {
    List<EmployeeCurfewProfileEvent> events = const [];
    String? loadError;

    try {
      events = await service.listEvents(profile.id);
    } catch (error) {
      loadError = employeeCurfewProfileError(error);
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${profile.tenantName ?? 'Tenant'} • Profile history',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (loadError != null)
                Text(loadError)
              else if (events.isEmpty)
                const Text('No profile history recorded.')
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 18),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history_outlined),
                        title: Text(
                          event.eventType
                              .split('_')
                              .map(
                                (part) =>
                                    '${part[0].toUpperCase()}${part.substring(1)}',
                              )
                              .join(' '),
                        ),
                        subtitle: Text(
                          '${event.actorName}\n${event.notes}',
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final approved =
        profiles.where((profile) => profile.status == 'approved').length;

    return PageFrame(
      title: 'Employee curfew profiles',
      subtitle: '$approved approved • ${profiles.length} total',
      useScriptTitle: false,
      onRefresh: () => _load(showSpinner: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_outlined),
        label: const Text('New profile'),
      ),
      child: loading && profiles.isEmpty
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
                      const Icon(Icons.badge_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Use this only for an approved employment-based schedule. Exact employee-curfew policy is not assumed here; staff records the approved time, days, dates, and basis. Gate/geofence evaluator changes require separate integration review.',
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
                if (profiles.isEmpty)
                  const EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'No employee curfew profiles',
                    message:
                        'Create a draft only after an employment-based curfew schedule has been approved operationally.',
                  )
                else
                  ...profiles.map(
                    (profile) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarmelitaCard(
                        onTap: () => _showHistory(profile),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    profile.tenantName ?? 'Tenant',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                StatusPill(
                                  employeeCurfewStatusLabel(profile.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${employeeCurfewTimeLabel(profile.allowedReturnMinutes)} • ${_profileWeekdays(profile.weekdays)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${_profileDate(profile.effectiveFrom)} → ${profile.effectiveUntil == null ? 'No end date' : _profileDate(profile.effectiveUntil!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(profile.workScheduleNote),
                            if (profile.approvalNote.trim().isNotEmpty) ...[
                              const Divider(height: 22),
                              Text('Approval note: ${profile.approvalNote}'),
                            ],
                            if (profile.revocationReason.trim().isNotEmpty) ...[
                              const Divider(height: 22),
                              Text(
                                'Revocation: ${profile.revocationReason}',
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (profile.status == 'draft')
                                  OutlinedButton.icon(
                                    onPressed: () => _edit(profile: profile),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                if (profile.status == 'draft')
                                  FilledButton.icon(
                                    onPressed: () => _approve(profile),
                                    icon: const Icon(Icons.verified_outlined),
                                    label: const Text('Approve'),
                                  ),
                                if (profile.status == 'approved')
                                  OutlinedButton.icon(
                                    onPressed: () => _revoke(profile),
                                    icon: const Icon(Icons.block_outlined),
                                    label: const Text('Revoke'),
                                  ),
                                TextButton.icon(
                                  onPressed: () => _showHistory(profile),
                                  icon: const Icon(Icons.history_outlined),
                                  label: const Text('History'),
                                ),
                              ],
                            ),
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

class TenantEmployeeCurfewProfileCard extends StatefulWidget {
  const TenantEmployeeCurfewProfileCard({super.key});

  @override
  State<TenantEmployeeCurfewProfileCard> createState() =>
      _TenantEmployeeCurfewProfileCardState();
}

class _TenantEmployeeCurfewProfileCardState
    extends State<TenantEmployeeCurfewProfileCard> {
  final service = const EmployeeCurfewProfileService();
  late final TableRefreshSubscription subscription;
  EmployeeCurfewProfileRecord? profile;
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
      'tenant-employee-curfew-profile',
      const ['employee_curfew_profiles'],
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
      final resolved = await service.resolveMyEffectiveProfile();
      if (!mounted) return;
      setState(() {
        profile = resolved;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = employeeCurfewProfileError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const CarmelitaCard(
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Checking employee curfew profile…'),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return CarmelitaCard(
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(errorMessage!)),
            IconButton(
              tooltip: 'Retry',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }

    final current = profile;
    if (current == null) {
      return const CarmelitaCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No approved employee curfew profile applies today. Your normal curfew and approved exception requests remain unchanged.',
              ),
            ),
          ],
        ),
      );
    }

    return CarmelitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'EMPLOYEE CURFEW PROFILE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill('Approved'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            employeeCurfewTimeLabel(current.allowedReturnMinutes),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_profileWeekdays(current.weekdays)} • '
            '${_profileDate(current.effectiveFrom)} → '
            '${current.effectiveUntil == null ? 'No end date' : _profileDate(current.effectiveUntil!)}',
          ),
          const SizedBox(height: 8),
          Text(current.workScheduleNote),
          const SizedBox(height: 10),
          Text(
            'Profile display is active. Gate/geofence evaluator integration is reviewed separately before this schedule can alter automated curfew classification.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
