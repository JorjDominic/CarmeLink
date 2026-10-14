import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../services/conduct_case_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../../core/utils/conduct_case_policy.dart';
import 'administrative_entry_dialog.dart';

class ConductOfficialResponses extends StatefulWidget {
  const ConductOfficialResponses(
      {required this.record,
      required this.staffMode,
      required this.onSaved,
      this.service = const ConductCaseService(),
      super.key});
  final ConductCaseRecord record;
  final bool staffMode;
  final Future<void> Function() onSaved;
  final ConductCaseService service;
  @override
  State<ConductOfficialResponses> createState() =>
      _ConductOfficialResponsesState();
}

class _ConductOfficialResponsesState extends State<ConductOfficialResponses> {
  List<ConductOfficialResponse> entries = [];
  String? error;
  bool composing = false;
  late final TableRefreshSubscription subscription;
  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
        'official-${widget.record.id}-${widget.staffMode}',
        ['conduct_case_events'],
        _load);
  }

  @override
  void dispose() {
    subscription.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await widget.service
          .listOfficialResponses(widget.record.id, staffMode: widget.staffMode);
      if (mounted)
        setState(() {
          entries = values;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = conductCaseError(e));
    }
  }

  Future<void> _compose() async {
    if (composing) return;
    setState(() => composing = true);
    final saved = await showAdministrativeEntryDialog(context,
        title: 'Add official response',
        allowTenantVisibility: true,
        onSave: (body, visibility, requestId) => widget.service
            .addOfficialResponse(
                record: widget.record,
                body: body,
                visibility: visibility,
                requestId: requestId));
    if (!mounted) return;
    setState(() => composing = false);
    if (saved) {
      showAppSnackBar(context, 'Administrative response saved.');
      await widget.onSaved();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Official staff responses',
              subtitle:
                  'Formal responses are separate from explanations, warnings and decisions.'),
          const SizedBox(height: 10),
          if (error != null)
            CarmelitaCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(error!),
                  TextButton(
                      onPressed: _load,
                      child: const Text('Retry response loading'))
                ])),
          if (entries.isEmpty && error == null)
            const Text('No official staff responses recorded.'),
          for (final entry in entries)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CarmelitaCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          entry.visibility == 'internal'
                              ? 'Internal administrative note'
                              : 'Tenant-visible official response',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('${entry.authorName} • ${entry.authorRole}'),
                      Text(
                          '${shortDate(entry.createdAt)} ${TimeOfDay.fromDateTime(entry.createdAt).format(context)}'),
                      const Divider(),
                      SelectableText(entry.body),
                    ]))),
          if (widget.staffMode &&
              widget.record.status != 'draft' &&
              !conductCaseIsClosed(widget.record.status)) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
                onPressed: composing ? null : _compose,
                icon: const Icon(Icons.post_add_outlined),
                label: const Text('Add Official Response')),
          ],
        ],
      );
}
