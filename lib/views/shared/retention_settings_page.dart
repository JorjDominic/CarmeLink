import 'package:flutter/material.dart';

import '../../core/utils/retention_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/retention_policy_service.dart';
import '../../services/table_refresh_subscription.dart';

class RetentionSettingsPage extends StatefulWidget {
  const RetentionSettingsPage({super.key});

  @override
  State<RetentionSettingsPage> createState() => _RetentionSettingsPageState();
}

class _RetentionSettingsPageState extends State<RetentionSettingsPage> {
  final service = const RetentionPolicyService();
  late final TableRefreshSubscription subscription;
  List<RetentionPolicySetting> settings = const [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
      'retention-policy-settings',
      const [
        'retention_policy_settings',
        'retention_policy_events',
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
      final latest = await service.listSettings();
      if (!mounted) return;
      setState(() {
        settings = latest;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = retentionPolicyError(error);
      });
    }
  }

  Future<void> _edit(RetentionPolicySetting setting) async {
    final days = TextEditingController(
      text: setting.proposedRetentionDays?.toString() ?? '',
    );
    final notes = TextEditingController(text: setting.reviewNotes);
    var status = setting.reviewStatus;
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(setting.displayName),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CarmelitaCard(
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'This screen stores retention policy configuration only. '
                      'Automatic cleanup, deletion, archiving, and anonymization '
                      'are disabled in this phase.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(setting.description),
                  const SizedBox(height: 16),
                  TextField(
                    controller: days,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Proposed retention days',
                      hintText: 'Leave blank until policy is confirmed',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Review status',
                    ),
                    items: retentionReviewStatuses
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              retentionReviewStatusLabel(value),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => status = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Client / legal / privacy review notes',
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
                      final daysError = validateRetentionDays(days.text);
                      if (daysError != null) {
                        showAppSnackBar(dialogContext, daysError);
                        return;
                      }

                      final notesError =
                          validateRetentionReviewNotes(notes.text);
                      if (notesError != null) {
                        showAppSnackBar(dialogContext, notesError);
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        await service.updateSetting(
                          recordKey: setting.recordKey,
                          proposedRetentionDays: days.text.trim().isEmpty
                              ? null
                              : int.parse(days.text.trim()),
                          reviewStatus: status,
                          reviewNotes: notes.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            retentionPolicyError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save configuration'),
            ),
          ],
        ),
      ),
    );

    days.dispose();
    notes.dispose();

    if (changed == true && mounted) {
      await _load(showSpinner: false);
    }
  }

  Future<void> _history(RetentionPolicySetting setting) async {
    List<RetentionPolicyEvent> events = const [];
    String? loadError;

    try {
      events = await service.listEvents(setting.recordKey);
    } catch (error) {
      loadError = retentionPolicyError(error);
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
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${setting.displayName} • History',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (loadError != null)
                Text(loadError)
              else if (events.isEmpty)
                const Text('No retention-setting changes recorded.')
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final before = event.previousDays == null
                          ? 'Not set'
                          : '${event.previousDays} days';
                      final after = event.proposedDays == null
                          ? 'Not set'
                          : '${event.proposedDays} days';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history_outlined),
                        title: Text('$before → $after'),
                        subtitle: Text(
                          '${event.actorName} • '
                          '${retentionReviewStatusLabel(event.reviewStatus)}'
                          '${event.notes.trim().isEmpty ? '' : '\n${event.notes}'}',
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
    return RoleGuard(
      allowedRoles: const {
        UserRole.owner,
        UserRole.caretaker,
      },
      child: PageFrame(
        title: 'Security & retention',
        subtitle: 'Retention configuration and privacy review',
        useScriptTitle: false,
        onRefresh: () => _load(showSpinner: false),
        child: loading && settings.isEmpty
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
                        const Icon(Icons.security_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Retention periods remain configuration-only until '
                            'client and legal/privacy review is complete. '
                            'Deletion jobs are not enabled by this feature.',
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
                    'Sensitive record groups',
                    subtitle:
                        'Proposed retention periods; enforcement remains disabled',
                  ),
                  const SizedBox(height: 10),
                  if (settings.isEmpty)
                    const EmptyState(
                      icon: Icons.policy_outlined,
                      title: 'No retention settings',
                      message:
                          'Retention record groups will appear after backend '
                          'configuration is deployed.',
                    )
                  else
                    ...settings.map(
                      (setting) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CarmelitaCard(
                          onTap: () => _edit(setting),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      setting.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  StatusPill(
                                    retentionReviewStatusLabel(
                                      setting.reviewStatus,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(setting.description),
                              const SizedBox(height: 10),
                              InfoRow(
                                label: 'Proposed retention',
                                value: setting.proposedRetentionDays == null
                                    ? 'Not set'
                                    : '${setting.proposedRetentionDays} days',
                                icon: Icons.calendar_month_outlined,
                              ),
                              const InfoRow(
                                label: 'Automated enforcement',
                                value: 'Disabled',
                                icon: Icons.lock_outline,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _edit(setting),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Configure'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _history(setting),
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
      ),
    );
  }
}
