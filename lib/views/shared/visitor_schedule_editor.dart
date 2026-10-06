import 'package:flutter/material.dart';

import '../../core/utils/visitor_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/visitor_service.dart';

Future<bool> editVisitorSchedule(
  BuildContext context,
  VisitorRequest request, {
  bool staffCanKeepApproval = false,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _VisitorScheduleEditor(
          request: request,
          staffCanKeepApproval: staffCanKeepApproval,
        ),
      ) ??
      false;
}

class _VisitorScheduleEditor extends StatefulWidget {
  const _VisitorScheduleEditor({
    required this.request,
    required this.staffCanKeepApproval,
  });

  final VisitorRequest request;
  final bool staffCanKeepApproval;

  @override
  State<_VisitorScheduleEditor> createState() => _VisitorScheduleEditorState();
}

class _VisitorScheduleEditorState extends State<_VisitorScheduleEditor> {
  late DateTime arrival = widget.request.schedule;
  late DateTime departure = widget.request.expectedDepartureAt ??
      VisitorPolicy.defaultDeparture(widget.request.schedule);
  final TextEditingController note = TextEditingController();

  bool keepApproval = false;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final firstDate = VisitorPolicy.minimumVisitDate();
    final initialDate = arrival.isBefore(firstDate)
        ? firstDate
        : VisitorPolicy.dateOnly(arrival);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;

    setState(() {
      arrival = DateTime(
        picked.year,
        picked.month,
        picked.day,
        arrival.hour,
        arrival.minute,
      );
      departure = DateTime(
        picked.year,
        picked.month,
        picked.day,
        departure.hour,
        departure.minute,
      );
    });
  }

  Future<void> _pickTime({required bool isArrival}) async {
    final source = isArrival ? arrival : departure;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(source),
    );
    if (picked == null || !mounted) return;

    setState(() {
      final value = DateTime(
        arrival.year,
        arrival.month,
        arrival.day,
        picked.hour,
        picked.minute,
      );
      if (isArrival) {
        arrival = value;
        if (!departure.isAfter(arrival)) {
          departure = VisitorPolicy.defaultDeparture(arrival);
        }
      } else {
        departure = value;
      }
    });
  }

  Future<bool> _confirmChange() async {
    final retainsApproval = widget.request.isApproved &&
        widget.staffCanKeepApproval &&
        keepApproval;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm schedule change?'),
            content: Text(
              retainsApproval
                  ? 'The revised schedule will stay approved. The change and your reason will be recorded in visitor history.'
                  : 'The revised schedule will be recorded and will require staff approval before arrival.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm change'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (saving) return;

    final cleanNote = note.text.trim();
    if (cleanNote.length < 5) {
      setState(() => error = 'Explain the change in at least 5 characters.');
      return;
    }

    final policyIssue = VisitorPolicy.validateVisit(
      schedule: arrival,
      expectedDepartureAt: departure,
      now: DateTime.now(),
    );
    if (policyIssue != null) {
      setState(() => error = policyIssue);
      return;
    }

    if (arrival.isAtSameMomentAs(widget.request.schedule) &&
        widget.request.expectedDepartureAt != null &&
        departure.isAtSameMomentAs(widget.request.expectedDepartureAt!)) {
      setState(() => error = 'Choose a different arrival or departure time.');
      return;
    }

    if (!await _confirmChange() || !mounted) return;

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await const VisitorService().reschedule(
        request: widget.request,
        arrival: arrival,
        departure: departure,
        note: cleanNote,
        keepApproval: widget.staffCanKeepApproval && keepApproval,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRetainApproval =
        widget.staffCanKeepApproval && widget.request.isApproved;
    final willRequireApproval = !canRetainApproval || !keepApproval;

    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: const Text('Change visitor schedule'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  willRequireApproval
                      ? 'This change will return the visit to Pending so staff can review the revised schedule.'
                      : 'Staff will keep the existing approval while recording the revised schedule.',
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(shortDate(arrival)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: saving ? null : () => _pickTime(isArrival: true),
                  icon: const Icon(Icons.login_rounded),
                  label: Text('Arrival • ${timeText(arrival)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: saving ? null : () => _pickTime(isArrival: false),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text('Departure • ${timeText(departure)}'),
                ),
                if (canRetainApproval) ...[
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: keepApproval,
                    onChanged: saving
                        ? null
                        : (value) => setState(() => keepApproval = value),
                    title: const Text('Keep current approval'),
                    subtitle: const Text(
                      'Use only when staff confirms the revised schedule still satisfies visitor policy.',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  enabled: !saving,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for schedule change',
                    hintText: 'Required for visitor history',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving ? null : _save,
            child: Text(saving ? 'Saving…' : 'Review change'),
          ),
        ],
      ),
    );
  }
}
