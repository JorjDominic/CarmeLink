import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../services/report_administration_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'administrative_entry_dialog.dart';

class ConfidentialReportHistory extends StatefulWidget {
  const ConfidentialReportHistory(
      {required this.reportId, required this.finalized, super.key});
  final String reportId;
  final bool finalized;
  @override
  State<ConfidentialReportHistory> createState() =>
      _ConfidentialReportHistoryState();
}

class _ConfidentialReportHistoryState extends State<ConfidentialReportHistory> {
  final service = const ReportAdministrationService();
  List<Map<String, dynamic>>? history;
  String? error;
  bool saving = false;
  TableRefreshSubscription? subscription;

  @override
  void dispose() {
    subscription?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await service.confidentialHistory(widget.reportId);
      if (mounted)
        setState(() {
          history = rows;
          error = null;
        });
    } catch (exception) {
      if (mounted) setState(() => error = reportAdministrationError(exception));
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OutlinedButton.icon(
            onPressed: saving || widget.finalized
                ? null
                : () async {
                    if (saving) return;
                    setState(() => saving = true);
                    final saved = await showAdministrativeEntryDialog(context,
                        title: 'Add internal staff note',
                        onSave: (body, visibility, requestId) =>
                            service.addInternalNote('confidential',
                                widget.reportId, body, requestId));
                    if (!mounted) return;
                    setState(() => saving = false);
                    if (saved) {
                      showAppSnackBar(context, 'Internal staff note saved.');
                      await _load();
                    }
                  },
            icon: const Icon(Icons.lock_outline),
            label: const Text('Add internal staff note')),
        ExpansionTile(
            title: const Text('Report history • staff only'),
            onExpansionChanged: (open) {
              if (open) {
                _load();
                // The audit table remains inaccessible to client SELECT/realtime.
                // The existing catch-up timer reads through the protected RPC.
                subscription ??= TableRefreshSubscription(
                    'confidential-history-${widget.reportId}',
                    ['confidential_reports'],
                    _load);
              } else {
                subscription?.dispose();
                subscription = null;
              }
            },
            children: [
              if (error != null)
                Padding(padding: const EdgeInsets.all(12), child: Text(error!))
              else if (history == null)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator())
              else if (history!.isEmpty)
                const Text('No administrative history recorded.')
              else
                for (final row in history!)
                  ListTile(
                    title: Text(row['action'] == 'internal_note'
                        ? 'Internal administrative note'
                        : '${row['previous_status']} → ${row['new_status']}'),
                    subtitle: Text(
                        '${row['actor_name']} • ${DateTime.parse(row['created_at'] as String).toLocal()}\n${row['notes'] ?? ''}'),
                  ),
            ]),
      ]);
}
