import 'package:flutter/material.dart';

String reportTransitionDescription(String status) =>
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      'assigned' =>
        'Record that staff have taken responsibility for this request.',
      'in_progress' =>
        'Staff are handling this report. Reopening a resolved report retains its history.',
      'under_review' ||
      'reviewing' =>
        'Authorized staff are reviewing the submitted concern.',
      'resolved' => 'Record the completed action and finalize this report.',
      'cancelled' => 'Cancel this request with a recorded reason.',
      'dismissed' =>
        'Finalize the report without further action. Record the reason.',
      _ => 'The report is awaiting staff review.',
    };

class ReportStatusActions extends StatelessWidget {
  const ReportStatusActions(
      {required this.currentStatus,
      required this.selectedStatus,
      required this.allowedStatuses,
      required this.labels,
      required this.onChanged,
      this.enabled = true,
      super.key});
  final String currentStatus, selectedStatus;
  final List<String> allowedStatuses;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Administrative action',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('$currentStatus-$selectedStatus'),
          initialValue: selectedStatus,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Next action'),
          items: [
            DropdownMenuItem(
                value: currentStatus, child: const Text('Keep current status')),
            for (final status
                in allowedStatuses.where((value) => value != currentStatus))
              DropdownMenuItem(
                  value: status, child: Text(labels[status] ?? status)),
          ],
          onChanged: !enabled ? null : (value) => onChanged(value!),
        ),
        const SizedBox(height: 8),
        Text(selectedStatus == currentStatus
            ? 'Save a tenant-visible update without changing the status.'
            : reportTransitionDescription(selectedStatus)),
      ]);
}

Future<bool> confirmReportTransition(
        BuildContext context, String from, String to,
        {String? tenantUpdate}) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('Confirm report status change'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$from → $to'),
                    const SizedBox(height: 12),
                    Text(reportTransitionDescription(to)),
                    if (tenantUpdate != null) ...[
                      const SizedBox(height: 12),
                      const Text('Tenant-visible update',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(tenantUpdate)
                    ],
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm change'))
              ],
            )) ??
    false;
