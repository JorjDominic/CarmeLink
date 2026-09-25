import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/utils/room_inspection_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/room_inspection_service.dart';
import '../../services/table_refresh_subscription.dart';

String _inspectionDateTime(DateTime value) {
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

List<RoomInspectionRecord> _visibleInspections(
  List<RoomInspectionRecord> source,
  RecordListScope scope,
  RecordListSort sort,
) {
  final values = source.where((item) {
    final active = item.status == 'scheduled' || item.status == 'in_progress';
    return scope == RecordListScope.active ? active : !active;
  }).toList();
  values.sort((a, b) => switch (sort) {
        RecordListSort.oldest => a.scheduledAt.compareTo(b.scheduledAt),
        RecordListSort.status => a.status.compareTo(b.status),
        RecordListSort.title => a.inspectionType.compareTo(b.inspectionType),
        _ => b.scheduledAt.compareTo(a.scheduledAt),
      });
  return values;
}

class StaffRoomInspectionsPage extends StatefulWidget {
  const StaffRoomInspectionsPage({
    required this.roomId,
    required this.roomNumber,
    super.key,
  });

  final String roomId;
  final String roomNumber;

  @override
  State<StaffRoomInspectionsPage> createState() =>
      _StaffRoomInspectionsPageState();
}

class _StaffRoomInspectionsPageState extends State<StaffRoomInspectionsPage> {
  final service = const RoomInspectionService();
  late final TableRefreshSubscription subscription;
  List<RoomInspectionRecord> inspections = const [];
  bool loading = true;
  String? errorMessage;
  RecordListScope scope = RecordListScope.active;
  RecordListSort sort = RecordListSort.newest;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
      'room-inspections-${widget.roomId}',
      const [
        'room_inspections',
        'room_inspection_findings',
        'room_inspection_evidence',
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
      final latest = await service.listRoomInspections(widget.roomId);
      if (!mounted) return;
      setState(() {
        inspections = latest;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = roomInspectionError(error);
      });
    }
  }

  Future<void> _schedule({
    RoomInspectionRecord? parent,
  }) async {
    final isFollowUp = parent != null;
    var scheduledAt = DateTime.now().add(
      isFollowUp ? const Duration(days: 1) : const Duration(days: 4),
    );
    final notice = TextEditingController(
      text: isFollowUp
          ? 'Follow-up inspection for previously recorded room findings.'
          : 'Monthly room inspection notice. Authorized staff will inspect the room condition and record any findings.',
    );
    var saving = false;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            isFollowUp ? 'Schedule follow-up' : 'Schedule monthly inspection',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isFollowUp)
                    CarmelitaCard(
                      padding: const EdgeInsets.all(12),
                      child: const Text(
                        'Monthly inspections require at least three days written notice before the scheduled time.',
                      ),
                    ),
                  if (!isFollowUp) const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Scheduled date and time'),
                    subtitle: Text(_inspectionDateTime(scheduledAt)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: dialogContext,
                              initialDate: scheduledAt,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 730)),
                            );
                            if (date == null || !dialogContext.mounted) return;

                            final time = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay.fromDateTime(scheduledAt),
                            );
                            if (time == null) return;

                            setDialogState(() {
                              scheduledAt = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notice,
                    enabled: !saving,
                    maxLength: 2000,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Written notice',
                      hintText:
                          'This notice will be visible to tenants assigned to the room.',
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
                      final noticeError = validateInspectionNotice(notice.text);
                      if (noticeError != null) {
                        showAppSnackBar(dialogContext, noticeError);
                        return;
                      }
                      if (!isFollowUp) {
                        final scheduleError =
                            validateMonthlyInspectionSchedule(scheduledAt);
                        if (scheduleError != null) {
                          showAppSnackBar(dialogContext, scheduleError);
                          return;
                        }
                      } else if (!scheduledAt.isAfter(DateTime.now())) {
                        showAppSnackBar(
                          dialogContext,
                          'Follow-up schedule must be in the future.',
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        await service.createInspection(
                          roomId: widget.roomId,
                          inspectionType: isFollowUp ? 'follow_up' : 'monthly',
                          scheduledAt: scheduledAt,
                          noticeText: notice.text,
                          parentInspectionId: parent?.id,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            roomInspectionError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Scheduling…' : 'Publish notice'),
            ),
          ],
        ),
      ),
    );

    notice.dispose();

    if (created == true && mounted) {
      await _load(showSpinner: false);
    }
  }

  Future<void> _open(RoomInspectionRecord inspection) async {
    final followUpParent =
        await Navigator.of(context).push<RoomInspectionRecord>(
      MaterialPageRoute(
        builder: (_) => StaffInspectionDetailPage(
          inspection: inspection,
          roomNumber: widget.roomNumber,
        ),
      ),
    );

    if (!mounted) return;

    if (followUpParent != null) {
      await _schedule(parent: followUpParent);
    }

    if (mounted) {
      await _load(showSpinner: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = inspections
        .where(
          (item) => item.status == 'scheduled' || item.status == 'in_progress',
        )
        .length;
    final visible = _visibleInspections(inspections, scope, sort);

    return PageFrame(
      title: 'Room ${widget.roomNumber} inspections',
      subtitle: '$active active • ${inspections.length} total',
      useScriptTitle: false,
      onRefresh: () => _load(showSpinner: false),
      actions: [
        IconButton(
          tooltip: 'Schedule monthly inspection',
          onPressed: () => _schedule(),
          icon: const Icon(Icons.add_task_outlined),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _schedule(),
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Schedule inspection'),
      ),
      child: loading && inspections.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CollapsibleInfoCard(
                  title: 'How room inspections work',
                  icon: Icons.fact_check_outlined,
                  body:
                      'Monthly inspections publish a written room notice at least three days ahead. Findings, evidence, corrective actions, and follow-ups stay in this inspection record and do not automatically create penalties or charges.',
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
                  historyCount: inspections.length - active,
                  onScopeChanged: (value) => setState(() => scope = value),
                  onSortChanged: (value) => setState(() => sort = value),
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: scope == RecordListScope.active
                        ? 'No active inspections'
                        : 'No inspection history',
                    message: scope == RecordListScope.active
                        ? 'Schedule the next monthly room inspection when ready.'
                        : 'Completed and cancelled inspections appear here.',
                  )
                else
                  PagedRecordList(
                    key: ValueKey('staff-inspections-$scope-$sort'),
                    children: visible
                        .map(
                          (inspection) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CarmelitaCard(
                              onTap: () => _open(inspection),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          inspectionTypeLabel(
                                            inspection.inspectionType,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      StatusPill(
                                        inspectionStatusLabel(
                                            inspection.status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _inspectionDateTime(inspection.scheduledAt),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    inspection.noticeText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (inspection.summary.trim().isNotEmpty) ...[
                                    const Divider(height: 22),
                                    Text(
                                      inspection.summary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
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

class StaffInspectionDetailPage extends StatefulWidget {
  const StaffInspectionDetailPage({
    required this.inspection,
    required this.roomNumber,
    super.key,
  });

  final RoomInspectionRecord inspection;
  final String roomNumber;

  @override
  State<StaffInspectionDetailPage> createState() =>
      _StaffInspectionDetailPageState();
}

class _StaffInspectionDetailPageState extends State<StaffInspectionDetailPage> {
  final service = const RoomInspectionService();
  late RoomInspectionRecord inspection = widget.inspection;
  List<RoomInspectionFinding> findings = const [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final inspections = await service.listRoomInspections(inspection.roomId);
      final refreshed = inspections.firstWhere(
        (item) => item.id == inspection.id,
        orElse: () => inspection,
      );
      final latestFindings = await service.listFindings(
        inspection.id,
        includeEvidenceCount: true,
      );

      if (!mounted) return;
      setState(() {
        inspection = refreshed;
        findings = latestFindings;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = roomInspectionError(error);
      });
    }
  }

  Future<void> _start() async {
    try {
      await service.startInspection(inspection);
      await _refresh();
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, roomInspectionError(error));
      }
    }
  }

  Future<void> _addFinding() async {
    var category = 'condition';
    var severity = 'minor';
    final location = TextEditingController();
    final description = TextEditingController();
    final action = TextEditingController();
    PlatformFile? evidence;
    var saving = false;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add inspection finding'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration:
                        const InputDecoration(labelText: 'Finding category'),
                    items: roomInspectionFindingCategories
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(titleCaseInspectionValue(value)),
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
                  DropdownButtonFormField<String>(
                    initialValue: severity,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: roomInspectionFindingSeverities
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(titleCaseInspectionValue(value)),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => severity = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: location,
                    enabled: !saving,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'e.g. Bed 2 frame, bathroom sink, window',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Finding',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: action,
                    enabled: !saving,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Corrective action (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final file = await FilePicker.pickFile(
                              type: FileType.image,
                            );
                            if (file == null) return;

                            final fileLength =
                                file.lengthSync() ?? await file.length();
                            if (fileLength == null) {
                              if (dialogContext.mounted) {
                                showAppSnackBar(
                                  dialogContext,
                                  'Unable to read the selected image.',
                                );
                              }
                              return;
                            }
                            if (fileLength > 10 * 1024 * 1024) {
                              if (dialogContext.mounted) {
                                showAppSnackBar(
                                  dialogContext,
                                  'Evidence image must be 10 MB or smaller.',
                                );
                              }
                              return;
                            }
                            setDialogState(() => evidence = file);
                          },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      evidence == null
                          ? 'Attach evidence image'
                          : evidence!.name,
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
                      if (location.text.trim().length < 2) {
                        showAppSnackBar(
                          dialogContext,
                          'Enter the location of the finding.',
                        );
                        return;
                      }
                      final validation = validateInspectionFindingDescription(
                        description.text,
                      );
                      if (validation != null) {
                        showAppSnackBar(dialogContext, validation);
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        final findingId = await service.addFinding(
                          inspection: inspection,
                          category: category,
                          locationLabel: location.text,
                          severity: severity,
                          description: description.text,
                          correctiveAction: action.text,
                        );

                        final selected = evidence;
                        if (selected != null) {
                          final lower = selected.name.toLowerCase();
                          final contentType = lower.endsWith('.png')
                              ? 'image/png'
                              : lower.endsWith('.webp')
                                  ? 'image/webp'
                                  : 'image/jpeg';
                          final selectedBytes = await selected.readAsBytes();

                          await service.uploadEvidence(
                            inspectionId: inspection.id,
                            findingId: findingId,
                            originalName: selected.name,
                            contentType: contentType,
                            bytes: selectedBytes,
                          );
                        }

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            roomInspectionError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save finding'),
            ),
          ],
        ),
      ),
    );

    location.dispose();
    description.dispose();
    action.dispose();

    if (created == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _updateFinding(RoomInspectionFinding finding) async {
    var status = finding.status;
    final action = TextEditingController(text: finding.correctiveAction);
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Update ${finding.locationLabel}'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration:
                      const InputDecoration(labelText: 'Finding status'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'monitoring',
                      child: Text('Monitoring'),
                    ),
                    DropdownMenuItem(
                      value: 'corrected',
                      child: Text('Corrected'),
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
                  controller: action,
                  enabled: !saving,
                  maxLength: 2000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Corrective action',
                  ),
                ),
              ],
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
                        await service.updateFinding(
                          finding: finding,
                          status: status,
                          correctiveAction: action.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            roomInspectionError(error),
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

    action.dispose();

    if (changed == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _complete() async {
    final summary = TextEditingController();
    var saving = false;

    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Complete inspection'),
          content: TextField(
            controller: summary,
            enabled: !saving,
            minLines: 3,
            maxLines: 6,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Inspection summary',
              hintText:
                  'Summarize the room condition, findings, and required follow-up.',
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
                      if (summary.text.trim().length < 5) {
                        showAppSnackBar(
                          dialogContext,
                          'Add an inspection summary before completing.',
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await service.completeInspection(
                          inspection: inspection,
                          summary: summary.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            roomInspectionError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Completing…' : 'Complete'),
            ),
          ],
        ),
      ),
    );

    summary.dispose();

    if (completed == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _cancel() async {
    final reason = TextEditingController();
    var saving = false;

    final cancelled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Cancel inspection'),
          content: TextField(
            controller: reason,
            enabled: !saving,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Cancellation reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep inspection'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (reason.text.trim().length < 5) {
                        showAppSnackBar(
                          dialogContext,
                          'Add a reason before cancelling.',
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await service.cancelInspection(
                          inspection: inspection,
                          reason: reason.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            roomInspectionError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Cancelling…' : 'Cancel inspection'),
            ),
          ],
        ),
      ),
    );

    reason.dispose();

    if (cancelled == true && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: '${inspectionTypeLabel(inspection.inspectionType)} inspection',
      subtitle:
          'Room ${widget.roomNumber} • ${_inspectionDateTime(inspection.scheduledAt)}',
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
                              inspectionTypeLabel(inspection.inspectionType),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          StatusPill(
                            inspectionStatusLabel(inspection.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InfoRow(
                        label: 'Schedule',
                        value: _inspectionDateTime(inspection.scheduledAt),
                        icon: Icons.event_outlined,
                      ),
                      const Divider(height: 24),
                      Text(
                        'WRITTEN NOTICE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(inspection.noticeText),
                      if (inspection.summary.trim().isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          'SUMMARY',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(inspection.summary),
                      ],
                      if (inspection.cancellationReason.trim().isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          'Cancelled: ${inspection.cancellationReason}',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (inspection.status == 'scheduled')
                      FilledButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start inspection'),
                      ),
                    if (inspection.status == 'in_progress')
                      FilledButton.icon(
                        onPressed: _addFinding,
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('Add finding'),
                      ),
                    if (inspection.status == 'in_progress')
                      OutlinedButton.icon(
                        onPressed: _complete,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Complete inspection'),
                      ),
                    if (inspection.status == 'scheduled' ||
                        inspection.status == 'in_progress')
                      TextButton.icon(
                        onPressed: _cancel,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                SectionTitle(
                  'Findings',
                  subtitle: '${findings.length} recorded',
                ),
                const SizedBox(height: 10),
                if (findings.isEmpty)
                  const EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No findings recorded',
                    message:
                        'Record only observed room conditions. A completed inspection may also have no findings.',
                  )
                else
                  ...findings.map(
                    (finding) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarmelitaCard(
                        onTap: inspection.status == 'cancelled'
                            ? null
                            : () => _updateFinding(finding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    finding.locationLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                StatusPill(
                                  findingStatusLabel(finding.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${titleCaseInspectionValue(finding.category)} • ${titleCaseInspectionValue(finding.severity)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(finding.description),
                            if (finding.correctiveAction.trim().isNotEmpty) ...[
                              const Divider(height: 22),
                              Text(
                                'Corrective action: ${finding.correctiveAction}',
                              ),
                            ],
                            if (finding.evidenceCount > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${finding.evidenceCount} evidence image${finding.evidenceCount == 1 ? '' : 's'} attached',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                if (inspection.status == 'completed') ...[
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(inspection),
                    icon: const Icon(Icons.follow_the_signs_outlined),
                    label: const Text('Schedule follow-up'),
                  ),
                ],
              ],
            ),
    );
  }
}

class TenantRoomInspectionsPage extends StatefulWidget {
  const TenantRoomInspectionsPage({super.key});

  @override
  State<TenantRoomInspectionsPage> createState() =>
      _TenantRoomInspectionsPageState();
}

class _TenantRoomInspectionsPageState extends State<TenantRoomInspectionsPage> {
  final service = const RoomInspectionService();
  late final TableRefreshSubscription subscription;
  List<RoomInspectionRecord> inspections = const [];
  Map<String, List<RoomInspectionFinding>> findingsByInspection = const {};
  bool loading = true;
  String? errorMessage;
  RecordListScope scope = RecordListScope.active;
  RecordListSort sort = RecordListSort.newest;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
      'tenant-room-inspections',
      const [
        'room_inspections',
        'room_inspection_findings',
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
      final latest = await service.listMyRoomInspections();
      final mapped = <String, List<RoomInspectionFinding>>{};
      for (final inspection in latest) {
        mapped[inspection.id] = await service.listFindings(inspection.id);
      }

      if (!mounted) return;
      setState(() {
        inspections = latest;
        findingsByInspection = mapped;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = roomInspectionError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = inspections
        .where((item) =>
            item.status == 'scheduled' || item.status == 'in_progress')
        .length;
    final visible = _visibleInspections(inspections, scope, sort);
    return PageFrame(
      title: 'Room inspections',
      subtitle: 'Inspection notices, findings, and follow-up',
      onRefresh: () => _load(showSpinner: false),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading ? null : () => _load(showSpinner: false),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: loading && inspections.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CollapsibleInfoCard(
                  title: 'About inspection notices',
                  icon: Icons.notifications_active_outlined,
                  body:
                      'Published inspection notices for your currently assigned room appear here. Evidence photos remain restricted to authorized staff.',
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
                  historyCount: inspections.length - active,
                  onScopeChanged: (value) => setState(() => scope = value),
                  onSortChanged: (value) => setState(() => sort = value),
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: scope == RecordListScope.active
                        ? 'No active inspection notices'
                        : 'No inspection history',
                    message: scope == RecordListScope.active
                        ? 'Published inspection notices for your room will appear here.'
                        : 'Completed and cancelled inspections appear here.',
                  )
                else
                  PagedRecordList(
                    key: ValueKey('tenant-inspections-$scope-$sort'),
                    children: visible.map((inspection) {
                      final findings =
                          findingsByInspection[inspection.id] ?? const [];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CarmelitaCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      inspectionTypeLabel(
                                        inspection.inspectionType,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                  StatusPill(
                                    inspectionStatusLabel(inspection.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _inspectionDateTime(inspection.scheduledAt),
                              ),
                              const Divider(height: 24),
                              Text(
                                'WRITTEN NOTICE',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(inspection.noticeText),
                              if (inspection.summary.trim().isNotEmpty) ...[
                                const Divider(height: 24),
                                Text(
                                  'Inspection summary: ${inspection.summary}',
                                ),
                              ],
                              if (inspection.cancellationReason
                                  .trim()
                                  .isNotEmpty) ...[
                                const Divider(height: 24),
                                Text(
                                  'Cancelled: ${inspection.cancellationReason}',
                                ),
                              ],
                              if (findings.isNotEmpty) ...[
                                const Divider(height: 24),
                                Text(
                                  'FINDINGS',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                ...findings.map(
                                  (finding) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                finding.locationLabel,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            StatusPill(
                                              findingStatusLabel(
                                                finding.status,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(finding.description),
                                        if (finding.correctiveAction
                                            .trim()
                                            .isNotEmpty)
                                          Text(
                                            'Corrective action: ${finding.correctiveAction}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
    );
  }
}
