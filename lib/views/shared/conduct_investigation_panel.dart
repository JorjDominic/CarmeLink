import '../../models/tenant_conduct_status.dart';
import 'package:flutter/material.dart';
import '../../core/utils/conduct_case_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/conduct_case_service.dart';

class ConductInvestigationPanel extends StatefulWidget {
  const ConductInvestigationPanel(
      {super.key,
      required this.record,
      this.canDecide = false,
      this.service = const ConductCaseService(),
      this.onSaved});
  final ConductCaseRecord record;
  final bool canDecide;
  final ConductCaseService service;
  final Future<void> Function()? onSaved;
  @override
  State<ConductInvestigationPanel> createState() =>
      _ConductInvestigationPanelState();
}

class _ConductInvestigationPanelState extends State<ConductInvestigationPanel> {
  Map<String, dynamic>? data;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant ConductInvestigationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.updatedAt != widget.record.updatedAt) load();
  }

  Future<void> load() async {
    final request = ++generation;
    try {
      final result = await widget.service.investigation(widget.record.id);
      if (mounted && request == generation)
        setState(() {
          data = result;
          error = null;
        });
    } catch (e) {
      if (mounted && request == generation)
        setState(() {
          data = null;
          error = conductCaseError(e);
        });
    }
  }

  Future<void> decide(String outcome) async {
    final reason = TextEditingController();
    final appeal = TextEditingController();
    final requestId = widget.service.createResponseRequestId();
    var saving = false;
    var submitted = false;
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  scrollable: true,
                  title: Text(outcome == 'overturned'
                      ? 'Record appeal overturn'
                      : 'Record investigation decision'),
                  content: SizedBox(
                      width: 560,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            'Outcome: ${outcome.replaceAll('_', ' ')}. The reason is visible to the tenant. Administrative closure remains a separate action.'),
                        const SizedBox(height: 12),
                        TextField(
                            controller: reason,
                            enabled: !saving && !submitted,
                            minLines: 3,
                            maxLines: 8,
                            maxLength: 4000,
                            decoration: const InputDecoration(
                                labelText: 'Documented reason')),
                        if (outcome == 'overturned')
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Accepted appeal'),
                            items: ((data?['accepted_appeals'] as List?) ?? [])
                                .map((a) => DropdownMenuItem<String>(
                                    value: a['id'] as String,
                                    child: Text(
                                        'Accepted appeal submitted ${DateTime.parse(a['submitted_at'] as String).toLocal()}',
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: saving || submitted
                                ? null
                                : (value) => appeal.text = value ?? '',
                          ),
                      ])),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (reason.text.trim().length < 5 ||
                                    (outcome == 'overturned' &&
                                        !RegExp(r'^[0-9a-fA-F-]{36}$')
                                            .hasMatch(appeal.text.trim()))) {
                                  showAppSnackBar(context,
                                      'Enter a documented reason and, for an overturn, a valid accepted appeal reference.');
                                  return;
                                }
                                update(() {
                                  saving = true;
                                  submitted = true;
                                });
                                try {
                                  await widget.service.recordDecision(
                                      record: widget.record,
                                      outcome: outcome,
                                      reason: reason.text,
                                      requestId: requestId,
                                      appealId: outcome == 'overturned'
                                          ? appeal.text.trim()
                                          : null);
                                  if (context.mounted)
                                    Navigator.pop(context, true);
                                } catch (e) {
                                  if (context.mounted) {
                                    showAppSnackBar(
                                        context, conductCaseError(e));
                                    update(() => saving = false);
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Save decision')),
                  ],
                )));
    // Dialog animations may still reference the text controllers until this frame ends.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    reason.dispose();
    appeal.dispose();
    if (saved == true && mounted) {
      await widget.onSaved?.call();
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final decisions = (data?['decisions'] as List?) ?? [];
    final counts = (data?['counts'] as Map?) ?? {};
    final tenantStatus = data?['tenant_status'] is Map
        ? TenantConductStatus.fromJson(
            Map<String, dynamic>.from(data!['tenant_status'] as Map))
        : null;
    final outcome = decisions.isEmpty ? null : decisions.first['outcome'];
    final state = widget.record.status == 'dismissed'
        ? 'Dismissed / not confirmed'
        : outcome == 'confirmed'
            ? 'Confirmed violation'
            : outcome != null
                ? 'Not confirmed / overturned'
                : widget.record.status == 'resolved'
                    ? 'Closed — no confirmed outcome recorded'
                    : widget.record.status == 'under_review'
                        ? 'Under investigation'
                        : 'Reported — not confirmed';
    return CarmelitaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Investigation outcome'),
      const SizedBox(height: 8),
      if (error != null) ...[
        Text(error!),
        TextButton(onPressed: load, child: const Text('Retry'))
      ] else if (data == null)
        const LinearProgressIndicator()
      else ...[
        if (tenantStatus != null) ...[
          Text('Tenant conduct status: ${tenantStatus.label}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
              '${tenantStatus.confirmed} confirmed incidents; ${tenantStatus.recentConfirmed} within 90 days.'),
          const Text(
              'Repeated: 2+ confirmed incidents. Continuous: 3+ within 90 days. This flag requires staff review and does not change residency.'),
          const SizedBox(height: 12),
        ],
        Text(state, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
            'Published cases: ${counts['total']} · Confirmed incidents: ${counts['confirmed']} · Pending investigation: ${counts['pending']} · Dismissed / unconfirmed: ${counts['unconfirmed']} · Closed without outcome: ${counts['closed_without_outcome']} · With appeals: ${counts['appealed']}'),
        const Text(
            'Linked duplicate incidents count once when confirmed. Warnings, allegations and closure alone do not confirm a violation.'),
        for (final decision in decisions)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${decision['outcome'].toString().replaceAll('_', ' ')} · ${decision['actor_name']} · ${DateTime.parse(decision['created_at'] as String).toLocal()}'),
                    Text(decision['reason'] as String),
                    if (decision['appeal_id'] != null)
                      SelectableText('Appeal: ${decision['appeal_id']}'),
                  ])),
        if (widget.canDecide && widget.record.tenantNotifiedAt != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                if (!conductCaseIsClosed(widget.record.status)) ...[
                  OutlinedButton(
                      onPressed: () => decide('confirmed'),
                      child: const Text('Confirm violation')),
                  OutlinedButton(
                      onPressed: () => decide('not_confirmed'),
                      child: const Text('Not confirmed')),
                ],
                if (outcome == 'confirmed' &&
                    ((data?['accepted_appeals'] as List?) ?? []).isNotEmpty)
                  OutlinedButton(
                      onPressed: () => decide('overturned'),
                      child: const Text('Record accepted appeal overturn')),
              ])),
      ],
    ]));
  }
}

class ConductEvidencePreview extends StatefulWidget {
  const ConductEvidencePreview(
      {super.key,
      required this.evidence,
      this.service = const ConductCaseService()});
  final ConductCaseEvidence evidence;
  final ConductCaseService service;
  @override
  State<ConductEvidencePreview> createState() => _ConductEvidencePreviewState();
}

class _ConductEvidencePreviewState extends State<ConductEvidencePreview> {
  bool loading = false;
  Future<void> preview() async {
    setState(() => loading = true);
    try {
      final url = await widget.service.evidencePreview(widget.evidence);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  scrollable: true,
                  title: Text(widget.evidence.originalName),
                  content: SizedBox(
                      width: 720,
                      height: 420,
                      child: InteractiveViewer(
                          child: Image.network(url,
                              fit: BoxFit.contain,
                              errorBuilder: (_, error, stack) => const Center(
                                  child: Text(
                                      'Unable to load image. Close and retry.'))))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
    } catch (e) {
      if (mounted)
        showAppSnackBar(context,
            'Unable to open evidence. Check your access and connection, then retry.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
      onPressed: loading ? null : preview,
      icon: const Icon(Icons.image_outlined),
      label: Text(loading ? 'Opening…' : 'Preview image'));
}
