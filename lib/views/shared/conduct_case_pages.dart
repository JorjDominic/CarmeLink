import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/utils/conduct_case_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/conduct_case_service.dart';
import '../../services/table_refresh_subscription.dart';

import 'conduct_case_appeal_panel.dart';

String _conductDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final amPm = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day}/${local.year} • $hour:$minute $amPm';
}

List<ConductCaseRecord> _visibleCases(
  List<ConductCaseRecord> source,
  RecordListScope scope,
  RecordListSort sort,
) {
  final values = source.where((item) {
    final active = !conductCaseIsClosed(item.status);
    return scope == RecordListScope.active ? active : !active;
  }).toList();
  values.sort((a, b) => switch (sort) {
        RecordListSort.oldest => a.incidentAt.compareTo(b.incidentAt),
        RecordListSort.status => a.status.compareTo(b.status),
        RecordListSort.title => a.title.compareTo(b.title),
        _ => b.incidentAt.compareTo(a.incidentAt),
      });
  return values;
}

class StaffConductCasesPage extends StatefulWidget {
  const StaffConductCasesPage({super.key});

  @override
  State<StaffConductCasesPage> createState() => _StaffConductCasesPageState();
}

class _StaffConductCasesPageState extends State<StaffConductCasesPage> {
  final service = const ConductCaseService();
  late final TableRefreshSubscription subscription;
  List<ConductCaseRecord> cases = const [];
  List<ConductTenantOption> tenants = const [];
  bool loading = true;
  String? errorMessage;
  RecordListScope scope = RecordListScope.active;
  RecordListSort sort = RecordListSort.newest;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
      'staff-conduct-cases',
      const [
        'conduct_cases',
        'conduct_case_responses',
        'conduct_case_warnings',
        'conduct_case_events',
        'conduct_case_evidence',
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
      final latestCases = await service.listStaffCases();
      if (!mounted) return;
      setState(() {
        tenants = latestTenants;
        cases = latestCases;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = conductCaseError(error);
      });
    }
  }

  int _repeatCount(ConductCaseRecord record) {
    final tenantId = record.tenantId;
    if (tenantId == null) return 0;
    return cases.where((item) => item.tenantId == tenantId).length;
  }

  Future<void> _create() async {
    if (tenants.isEmpty) {
      showAppSnackBar(context, 'No tenant accounts are available.');
      return;
    }

    var tenantId = tenants.first.id;
    var category = 'rule_violation';
    var source = 'manual';
    var incidentAt = DateTime.now();
    final title = TextEditingController();
    final description = TextEditingController();
    final sourceRecord = TextEditingController();
    var saving = false;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Create conduct case'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CarmelitaCard(
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'Creating a case records an incident for review. It does not create a penalty, charge, or tenancy termination.',
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
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => tenantId = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: conductCaseCategories
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(conductCategoryLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => category = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    enabled: !saving,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Case title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Incident description',
                      hintText:
                          'Record observed or reported facts without deciding guilt.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Incident date and time'),
                    subtitle: Text(_conductDateTime(incidentAt)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: dialogContext,
                              initialDate: incidentAt,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date == null || !dialogContext.mounted) return;
                            final time = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay.fromDateTime(incidentAt),
                            );
                            if (time == null) return;
                            setDialogState(() {
                              incidentAt = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: source,
                    decoration:
                        const InputDecoration(labelText: 'Record source'),
                    items: conductCaseSources
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(conductSourceLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => source = value);
                            }
                          },
                  ),
                  if (source != 'manual') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: sourceRecord,
                      enabled: !saving,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Source record ID (optional)',
                        helperText:
                            'Internal staff reference only; never shown to the affected tenant.',
                      ),
                    ),
                  ],
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
                      final titleError = validateConductCaseTitle(title.text);
                      if (titleError != null) {
                        showAppSnackBar(dialogContext, titleError);
                        return;
                      }
                      final descriptionError =
                          validateConductCaseDescription(description.text);
                      if (descriptionError != null) {
                        showAppSnackBar(dialogContext, descriptionError);
                        return;
                      }
                      if (incidentAt.isAfter(
                        DateTime.now().add(const Duration(minutes: 5)),
                      )) {
                        showAppSnackBar(
                          dialogContext,
                          'Incident time cannot be in the future.',
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        await service.createCase(
                          tenantId: tenantId,
                          category: category,
                          title: title.text,
                          description: description.text,
                          incidentAt: incidentAt,
                          sourceModule: source,
                          sourceRecordId:
                              source == 'manual' ? null : sourceRecord.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            conductCaseError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Creating…' : 'Create draft'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    description.dispose();
    sourceRecord.dispose();

    if (created == true && mounted) {
      await _load(showSpinner: false);
    }
  }

  Future<void> _open(ConductCaseRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffConductCaseDetailPage(
          initialRecord: record,
          repeatCount: _repeatCount(record),
        ),
      ),
    );
    if (mounted) await _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    final active =
        cases.where((record) => !conductCaseIsClosed(record.status)).length;
    final visible = _visibleCases(cases, scope, sort);

    return PageFrame(
      title: 'Conduct & cases',
      subtitle: '$active active • ${cases.length} total',
      useScriptTitle: false,
      onRefresh: () => _load(showSpinner: false),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading ? null : () => _load(showSpinner: false),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_outlined),
        label: const Text('New case'),
      ),
      child: loading && cases.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CollapsibleInfoCard(
                  title: 'How conduct cases work',
                  icon: Icons.gavel_outlined,
                  body:
                      'Cases document incidents, responses, warnings, and review history. The system does not determine guilt, create charges, or automatically terminate a tenancy.',
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  CarmelitaCard(child: Text(errorMessage!)),
                ],
                const SizedBox(height: 22),
                RecordListToolbar(
                  scope: scope,
                  sort: sort,
                  activeCount: active,
                  historyCount: cases.length - active,
                  onScopeChanged: (value) => setState(() => scope = value),
                  onSortChanged: (value) => setState(() => sort = value),
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: scope == RecordListScope.active
                        ? 'No active conduct cases'
                        : 'No closed-case history',
                    message: scope == RecordListScope.active
                        ? 'Restricted conduct cases created by authorized staff will appear here.'
                        : 'Closed cases remain available here for audit history.',
                  )
                else
                  PagedRecordList(
                    key: ValueKey('staff-cases-$scope-$sort'),
                    children: visible
                        .map(
                          (record) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CarmelitaCard(
                              onTap: () => _open(record),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          record.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 17,
                                          ),
                                        ),
                                      ),
                                      StatusPill(
                                        conductStatusLabel(record.status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    record.tenantName ?? 'Tenant',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${conductCategoryLabel(record.category)} • ${_conductDateTime(record.incidentAt)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    record.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Recorded cases for this tenant: ${_repeatCount(record)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
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

class StaffConductCaseDetailPage extends StatefulWidget {
  const StaffConductCaseDetailPage({
    required this.initialRecord,
    required this.repeatCount,
    super.key,
  });

  final ConductCaseRecord initialRecord;
  final int repeatCount;

  @override
  State<StaffConductCaseDetailPage> createState() =>
      _StaffConductCaseDetailPageState();
}

class _StaffConductCaseDetailPageState
    extends State<StaffConductCaseDetailPage> {
  final service = const ConductCaseService();
  late ConductCaseRecord record = widget.initialRecord;
  List<ConductCaseResponse> responses = const [];
  List<ConductCaseWarning> warnings = const [];
  List<ConductCaseEvent> events = const [];
  List<ConductCaseEvidence> evidence = const [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final allCases = await service.listStaffCases();
      final latest = allCases.firstWhere(
        (item) => item.id == record.id,
        orElse: () => record,
      );
      final latestResponses = await service.listStaffResponses(record.id);
      final latestWarnings = await service.listStaffWarnings(record.id);
      final latestEvents = await service.listEvents(record.id);
      final latestEvidence = await service.listEvidence(record.id);

      if (!mounted) return;
      setState(() {
        record = latest;
        responses = latestResponses;
        warnings = latestWarnings;
        events = latestEvents;
        evidence = latestEvidence;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = conductCaseError(error);
      });
    }
  }

  Future<void> _publish() async {
    try {
      await service.publishCase(record);
      await _refresh();
    } catch (error) {
      if (mounted) showAppSnackBar(context, conductCaseError(error));
    }
  }

  Future<void> _issueWarning() async {
    final controller = TextEditingController();
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Issue warning'),
          content: TextField(
            controller: controller,
            enabled: !saving,
            minLines: 3,
            maxLines: 6,
            maxLength: 3000,
            decoration: const InputDecoration(
              labelText: 'Warning',
              hintText:
                  'Document the warning clearly. This does not create a financial penalty.',
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
                      final validation =
                          validateConductWarning(controller.text);
                      if (validation != null) {
                        showAppSnackBar(dialogContext, validation);
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await service.issueWarning(
                          record: record,
                          message: controller.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            conductCaseError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Issuing…' : 'Issue warning'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _setReviewStatus(String status) async {
    final controller = TextEditingController(
      text: status == 'under_review' ? '' : record.resolutionNotes,
    );
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            status == 'resolved'
                ? 'Resolve case'
                : status == 'dismissed'
                    ? 'Dismiss case'
                    : 'Move to review',
          ),
          content: TextField(
            controller: controller,
            enabled: !saving,
            minLines: 3,
            maxLines: 6,
            maxLength: 4000,
            decoration: InputDecoration(
              labelText: status == 'under_review'
                  ? 'Review notes (optional)'
                  : 'Notes',
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
                      if ((status == 'resolved' || status == 'dismissed') &&
                          controller.text.trim().length < 5) {
                        showAppSnackBar(
                          dialogContext,
                          'Add at least 5 characters of review notes.',
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        await service.setReviewStatus(
                          record: record,
                          status: status,
                          notes: controller.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            conductCaseError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _recommendTerminationReview() async {
    final controller = TextEditingController();
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Recommend termination review'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CarmelitaCard(
                  padding: const EdgeInsets.all(12),
                  child: const Text(
                    'This records a recommendation only. It does not evict the tenant, deactivate the account, end a contract, remove a room assignment, or create a charge.',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  enabled: !saving,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Reason for separate administrative review',
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
                      final validation =
                          validateTerminationReviewReason(controller.text);
                      if (validation != null) {
                        showAppSnackBar(dialogContext, validation);
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        await service.recommendTerminationReview(
                          record: record,
                          reason: controller.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            conductCaseError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Record recommendation'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _addEvidence() async {
    final selected = await FilePicker.pickFile(type: FileType.image);
    if (selected == null) return;

    final length = selected.lengthSync() ?? await selected.length();
    if (!mounted) return;

    if (length == null) {
      showAppSnackBar(context, 'Unable to read the selected image.');
      return;
    }
    if (length > 10 * 1024 * 1024) {
      showAppSnackBar(context, 'Evidence image must be 10 MB or smaller.');
      return;
    }

    final caption = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Attach evidence'),
        content: TextField(
          controller: caption,
          maxLength: 1000,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Caption (optional)',
            helperText: selected.name,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      caption.dispose();
      return;
    }

    try {
      final lower = selected.name.toLowerCase();
      final contentType = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';

      await service.uploadEvidence(
        caseId: record.id,
        originalName: selected.name,
        contentType: contentType,
        bytes: await selected.readAsBytes(),
        caption: caption.text,
      );
      if (mounted) {
        showAppSnackBar(context, 'Evidence attached.');
        await _refresh();
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, conductCaseError(error));
    } finally {
      caption.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = conductCaseIsClosed(record.status);
    final canAct = record.status != 'draft' && !closed;

    return PageFrame(
      title: record.title,
      subtitle: '${record.tenantName ?? 'Tenant'} • Conduct case',
      useScriptTitle: false,
      onRefresh: _refresh,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMessage != null) ...[
                  CarmelitaCard(child: Text(errorMessage!)),
                  const SizedBox(height: 12),
                ],
                CarmelitaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conductCategoryLabel(record.category),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          StatusPill(conductStatusLabel(record.status)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InfoRow(
                        label: 'Incident',
                        value: _conductDateTime(record.incidentAt),
                        icon: Icons.schedule_outlined,
                      ),
                      InfoRow(
                        label: 'Source',
                        value: conductSourceLabel(
                          record.sourceModule ?? 'manual',
                        ),
                        icon: Icons.link_outlined,
                      ),
                      InfoRow(
                        label: 'Recorded cases',
                        value: '${widget.repeatCount}',
                        icon: Icons.history_outlined,
                      ),
                      const Divider(height: 24),
                      Text(record.description),
                      if (record.resolutionNotes.trim().isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          'Review outcome: ${record.resolutionNotes}',
                        ),
                      ],
                      if (record.terminationReviewReason.trim().isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          'Termination review recommendation: ${record.terminationReviewReason}',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (record.status == 'draft')
                      FilledButton.icon(
                        onPressed: _publish,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Publish to tenant'),
                      ),
                    if (canAct && record.status != 'under_review')
                      OutlinedButton.icon(
                        onPressed: () => _setReviewStatus('under_review'),
                        icon: const Icon(Icons.manage_search_outlined),
                        label: const Text('Under review'),
                      ),
                    if (canAct)
                      OutlinedButton.icon(
                        onPressed: _issueWarning,
                        icon: const Icon(Icons.warning_amber_outlined),
                        label: const Text('Issue warning'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _addEvidence,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add evidence'),
                    ),
                    if (canAct)
                      OutlinedButton.icon(
                        onPressed: _recommendTerminationReview,
                        icon: const Icon(Icons.rule_folder_outlined),
                        label: const Text('Recommend termination review'),
                      ),
                    if (canAct)
                      FilledButton.icon(
                        onPressed: () => _setReviewStatus('resolved'),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Resolve'),
                      ),
                    if (canAct)
                      TextButton.icon(
                        onPressed: () => _setReviewStatus('dismissed'),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Dismiss'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SectionTitle(
                  'Tenant responses',
                  subtitle: '${responses.length} submitted',
                ),
                const SizedBox(height: 10),
                if (responses.isEmpty)
                  const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No tenant response',
                    message:
                        'A published case allows the affected tenant to submit their explanation.',
                  )
                else
                  ...responses.map(
                    (response) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarmelitaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(response.body),
                            const SizedBox(height: 6),
                            Text(
                              _conductDateTime(response.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                SectionTitle(
                  'Warnings',
                  subtitle: '${warnings.length} issued',
                ),
                const SizedBox(height: 10),
                if (warnings.isEmpty)
                  const EmptyState(
                    icon: Icons.warning_amber_outlined,
                    title: 'No warning recorded',
                    message:
                        'Warnings remain separate from financial penalties or charges.',
                  )
                else
                  ...warnings.map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarmelitaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(warning.message),
                            const SizedBox(height: 6),
                            Text(
                              _conductDateTime(warning.issuedAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                SectionTitle(
                  'Evidence',
                  subtitle: '${evidence.length} staff-only image records',
                ),
                const SizedBox(height: 10),
                if (evidence.isEmpty)
                  const EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'No evidence attached',
                    message:
                        'Evidence images remain restricted to authorized staff in this phase.',
                  )
                else
                  ...evidence.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarmelitaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.originalName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            if (item.caption.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(item.caption),
                            ],
                            const SizedBox(height: 5),
                            Text(
                              _conductDateTime(item.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                ConductCaseAppealPanel(
                  caseId: record.id,
                  caseStatus: record.status,
                  staffMode: true,
                ),
                const SizedBox(height: 20),
                SectionTitle(
                  'Audit history',
                  subtitle: '${events.length} events',
                ),
                const SizedBox(height: 10),
                ...events.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CarmelitaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.eventType
                                .split('_')
                                .map(
                                  (part) =>
                                      '${part[0].toUpperCase()}${part.substring(1)}',
                                )
                                .join(' '),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                              '${event.actorName} • ${_conductDateTime(event.createdAt)}'),
                          if (event.notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(event.notes),
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

class TenantConductCasesPage extends StatefulWidget {
  const TenantConductCasesPage({super.key});

  @override
  State<TenantConductCasesPage> createState() => _TenantConductCasesPageState();
}

class _TenantConductCasesPageState extends State<TenantConductCasesPage> {
  final service = const ConductCaseService();
  late final TableRefreshSubscription subscription;
  List<ConductCaseRecord> cases = const [];
  bool loading = true;
  String? errorMessage;
  RecordListScope scope = RecordListScope.active;
  RecordListSort sort = RecordListSort.newest;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
      'tenant-conduct-cases',
      const [
        'conduct_cases',
        'conduct_case_responses',
        'conduct_case_warnings',
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
      final latest = await service.listMyCases();
      if (!mounted) return;
      setState(() {
        cases = latest;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = conductCaseError(error);
      });
    }
  }

  Future<void> _open(ConductCaseRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TenantConductCaseDetailPage(initialRecord: record),
      ),
    );
    if (mounted) await _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    final active =
        cases.where((record) => !conductCaseIsClosed(record.status)).length;
    final visible = _visibleCases(cases, scope, sort);
    return PageFrame(
      title: 'Conduct & cases',
      subtitle: 'Your published conduct records and responses',
      onRefresh: () => _load(showSpinner: false),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading ? null : () => _load(showSpinner: false),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: loading && cases.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CollapsibleInfoCard(
                  title: 'Privacy and visibility',
                  icon: Icons.privacy_tip_outlined,
                  body:
                      'Only conduct cases published to your account appear here. Confidential reporter/source identities and staff-only evidence are not exposed.',
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  CarmelitaCard(child: Text(errorMessage!)),
                ],
                const SizedBox(height: 22),
                RecordListToolbar(
                  scope: scope,
                  sort: sort,
                  activeCount: active,
                  historyCount: cases.length - active,
                  onScopeChanged: (value) => setState(() => scope = value),
                  onSortChanged: (value) => setState(() => sort = value),
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: scope == RecordListScope.active
                        ? 'No active published cases'
                        : 'No closed-case history',
                    message: scope == RecordListScope.active
                        ? 'Any applicable conduct case published for your response will appear here.'
                        : 'Closed cases remain available here for your records.',
                  )
                else
                  PagedRecordList(
                    key: ValueKey('tenant-cases-$scope-$sort'),
                    children: visible
                        .map(
                          (record) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CarmelitaCard(
                              onTap: () => _open(record),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          record.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 17,
                                          ),
                                        ),
                                      ),
                                      StatusPill(
                                        conductStatusLabel(record.status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${conductCategoryLabel(record.category)} • ${_conductDateTime(record.incidentAt)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    record.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
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

class TenantConductCaseDetailPage extends StatefulWidget {
  const TenantConductCaseDetailPage({
    required this.initialRecord,
    super.key,
  });

  final ConductCaseRecord initialRecord;

  @override
  State<TenantConductCaseDetailPage> createState() =>
      _TenantConductCaseDetailPageState();
}

class _TenantConductCaseDetailPageState
    extends State<TenantConductCaseDetailPage> {
  final service = const ConductCaseService();
  late ConductCaseRecord record = widget.initialRecord;
  List<ConductCaseResponse> responses = const [];
  List<ConductCaseWarning> warnings = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final allCases = await service.listMyCases();
      final latest = allCases.firstWhere(
        (item) => item.id == record.id,
        orElse: () => record,
      );
      final latestResponses = await service.listMyResponses(record.id);
      final latestWarnings = await service.listMyWarnings(record.id);

      if (!mounted) return;
      setState(() {
        record = latest;
        responses = latestResponses;
        warnings = latestWarnings;
        loading = false;
      });
    } catch (error) {
      if (mounted) showAppSnackBar(context, conductCaseError(error));
    }
  }

  Future<void> _respond() async {
    final controller = TextEditingController();
    var saving = false;

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Submit response'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Use this response to provide your explanation or relevant context. A response does not automatically decide the case.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  enabled: !saving,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Your response',
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
                      final validation =
                          validateConductResponse(controller.text);
                      if (validation != null) {
                        showAppSnackBar(dialogContext, validation);
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await service.submitResponse(
                          caseId: record.id,
                          body: controller.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            conductCaseError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Submitting…' : 'Submit response'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (submitted == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: record.title,
      subtitle: 'Conduct case',
      onRefresh: _refresh,
      floatingActionButton: tenantCanRespondToConductCase(record.status)
          ? FloatingActionButton.extended(
              onPressed: _respond,
              icon: const Icon(Icons.reply_outlined),
              label: const Text('Respond'),
            )
          : null,
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CarmelitaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conductCategoryLabel(record.category),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          StatusPill(conductStatusLabel(record.status)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_conductDateTime(record.incidentAt)),
                      const Divider(height: 24),
                      Text(record.description),
                      if (record.resolutionNotes.trim().isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          'Review outcome: ${record.resolutionNotes}',
                        ),
                      ],
                      if (record.terminationReviewReason.trim().isNotEmpty) ...[
                        const Divider(height: 24),
                        const Text(
                          'A separate termination review has been recommended. This status is not itself an eviction or contract termination.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(record.terminationReviewReason),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SectionTitle(
                  'Your responses',
                  subtitle: '${responses.length} submitted',
                ),
                const SizedBox(height: 10),
                if (responses.isEmpty)
                  const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No response submitted',
                    message:
                        'You can provide your explanation while responses remain open.',
                  )
                else
                  ...responses.map(
                    (response) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarmelitaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(response.body),
                            const SizedBox(height: 6),
                            Text(
                              _conductDateTime(response.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                ConductCaseAppealPanel(
                  caseId: record.id,
                  caseStatus: record.status,
                  staffMode: false,
                ),
                const SizedBox(height: 22),
                SectionTitle(
                  'Warnings',
                  subtitle: '${warnings.length} recorded',
                ),
                const SizedBox(height: 10),
                if (warnings.isEmpty)
                  const EmptyState(
                    icon: Icons.warning_amber_outlined,
                    title: 'No warning recorded',
                    message:
                        'Any warning recorded for this case will appear here.',
                  )
                else
                  ...warnings.map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarmelitaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(warning.message),
                            const SizedBox(height: 6),
                            Text(
                              _conductDateTime(warning.issuedAt),
                              style: Theme.of(context).textTheme.bodySmall,
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
