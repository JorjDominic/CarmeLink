import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/conduct_case_service.dart';
import '../../services/contract_service.dart';
import '../../services/eviction_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'move_out_settlement_page.dart';

class EvictionPage extends StatefulWidget {
  const EvictionPage(
      {super.key,
      this.initialTenantId,
      this.initialConductCaseId,
      this.service = const EvictionService()});
  final String? initialTenantId, initialConductCaseId;
  final EvictionService service;
  @override
  State<EvictionPage> createState() => _EvictionPageState();
}

class _EvictionPageState extends State<EvictionPage> {
  List<EvictionRecord> _items = [];
  bool _loading = true, _busy = false;
  String? _error;
  late final TableRefreshSubscription _subscription;
  AppUser? get _user => SessionController.instance.currentUser;
  bool get _owner => _user?.role == UserRole.owner;
  bool get _staff => _owner || _user?.role == UserRole.caretaker;
  @override
  void initState() {
    super.initState();
    _load();
    _subscription = TableRefreshSubscription(
        'eviction-workflow',
        [
          'eviction_cases',
          'eviction_events',
          'move_out_cases',
          'move_out_settlements'
        ],
        _load);
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  String _message(Object e) =>
      e is PostgrestException ? e.message : e.toString();
  Future<void> _load() async {
    try {
      final items = await widget.service.list();
      if (mounted)
        setState(() {
          _items = items;
          _error = null;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = _message(e);
          _loading = false;
        });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      await _load();
      if (mounted) showAppSnackBar(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _note(String title,
      {String label = 'Reason / note', int maxLength = 2000}) async {
    final c = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(title),
                content: TextField(
                    controller: c,
                    maxLength: maxLength,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: label)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        if (c.text.trim().length >= 3)
                          Navigator.pop(context, c.text.trim());
                      },
                      child: const Text('Confirm'))
                ]));
    c.dispose();
    return result;
  }

  Future<void> _decision() async => _run(() async {
        final results = await Future.wait([
          const ContractService().listContracts(),
          const ConductCaseService().listStaffCases()
        ]);
        final contracts = (results[0] as List<TenantContract>)
            .where((c) => c.isActive)
            .toList();
        if (!mounted) return;
        if (contracts.isEmpty) {
          showAppSnackBar(context, 'No active tenant contracts.');
          return;
        }
        final draft = await showDialog<EvictionDecisionDraft>(
            context: context,
            builder: (_) => EvictionDecisionDialog(
                contracts: contracts,
                cases: results[1] as List<ConductCaseRecord>,
                initialTenantId: widget.initialTenantId,
                initialConductCaseId: widget.initialConductCaseId));
        if (draft == null) return;
        await widget.service.recordDecision(
            tenantId: draft.tenantId,
            deadline: draft.deadline,
            reason: draft.reason,
            conductCaseId: draft.conductCaseId);
      });
  Future<void> _notice(EvictionRecord e, {bool draft = false}) async =>
      _run(() async {
        final bytes = draft
            ? await EvictionService.buildNoticePdf(e)
            : await widget.service.downloadNotice(e);
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(
                appBar: AppBar(
                    title: Text(draft
                        ? 'Draft departure notice'
                        : 'Issued departure notice')),
                body: PdfPreview(
                    build: (_) async => bytes,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    pdfFileName: '${e.contractNumber}-departure-notice.pdf'))));
      });
  Future<void> _publish(EvictionRecord e) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Publish departure notice'),
                content: Text(
                    'Send ${e.tenantName} the owner decision and departure deadline ${e.deadline}? This creates the linked inspection and settlement case.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Publish & notify'))
                ]));
    if (confirmed == true) await _run(() => widget.service.publishNotice(e));
  }

  Future<void> _depart(EvictionRecord e) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
        context: context,
        initialDate: today,
        firstDate: DateTime.parse(e.row['notice_on'] as String),
        lastDate: today);
    if (date == null || !mounted) return;
    final note = await _note('Record actual departure',
        label: 'Departure evidence and key / property handover');
    if (note != null)
      await _run(() => widget.service.recordDeparture(e.id, date, note));
  }

  Future<void> _settlement(EvictionRecord e) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MoveOutSettlementPage(initialCaseId: e.moveOutCaseId)));
    await _load();
  }

  Future<void> _close(EvictionRecord e) async {
    final note = await _note('Close contract and room assignment',
        label: 'Confirm departure, inspection, clearance and settlement');
    if (note == null || !mounted) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Confirm final closure'),
                content: Text(
                    'Terminate contract ${e.contractNumber} and end ${e.tenantName}’s assignment to ${e.room}? The server will recheck inspection, clearance, settlement and outstanding charges.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Close tenancy'))
                ]));
    if (confirmed == true) await _run(() => widget.service.close(e.id, note));
  }

  Future<void> _history(EvictionRecord e) async => _run(() async {
        final rows = await widget.service.history(e.id);
        if (!mounted) return;
        await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Case history'),
                    content: SizedBox(
                        width: 480,
                        height: 360,
                        child: ListView(children: [
                          for (final event in rows)
                            ListTile(
                                title: Text((event['snapshot'] as Map)['status']
                                    .toString()
                                    .replaceAll('_', ' ')),
                                subtitle: Text(
                                    '${event['created_at']}\n${(event['snapshot'] as Map)['tenant_response'] ?? ''}'))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'))
                    ]));
      });
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Eviction & departure notices',
      subtitle: 'Owner decision → notice → departure → settlement → closure',
      maxWidth: 900,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'The owner records the reason and departure deadline. Inspection, clearance, approved deposit deductions, and outstanding charges are reviewed before final closure.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh')),
          if (_owner)
            FilledButton.icon(
                key: const Key('record-eviction-decision'),
                onPressed: _busy ? null : _decision,
                icon: const Icon(Icons.gavel),
                label: const Text('Record owner decision'))
        ]),
        if (_busy || _loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (!_loading && _error == null && _items.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No issued eviction notices or cases.')),
        for (final e in _items) _card(e),
      ]));
  Widget _card(EvictionRecord e) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(e.tenantName, style: Theme.of(context).textTheme.titleMedium),
            Text('${e.contractNumber} · ${e.room}'),
            Text('Status: ${e.status.replaceAll('_', ' ')}'),
            Text('Departure deadline: ${e.deadline}'),
            Text('Owner reason: ${e.reason}'),
            if (e.row['actual_departure_on'] != null)
              Text(
                  'Actual departure: ${e.row['actual_departure_on']} · ${e.row['departure_note']}'),
            if (e.tenantResponse.isNotEmpty)
              Text('Tenant response: ${e.tenantResponse}'),
            if (e.row['closure_note'] != null)
              Text('Owner closure: ${e.row['closure_note']}'),
            if (e.row['cancellation_reason'] != null)
              Text('Rescinded: ${e.row['cancellation_reason']}'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (e.noticePath != null)
                OutlinedButton(
                    onPressed: _busy ? null : () => _notice(e),
                    child: const Text('View issued notice PDF')),
              if (_owner && e.status == 'decision_recorded') ...[
                OutlinedButton(
                    onPressed: _busy ? null : () => _notice(e, draft: true),
                    child: const Text('Preview notice')),
                FilledButton(
                    onPressed: _busy ? null : () => _publish(e),
                    child: const Text('Publish notice & notify'))
              ],
              if (_staff && e.status == 'notice_sent')
                FilledButton(
                    onPressed: _busy ? null : () => _depart(e),
                    child: const Text('Record actual departure')),
              if (e.moveOutCaseId != null &&
                  (_staff || _user?.role == UserRole.tenant))
                OutlinedButton(
                    onPressed: _busy ? null : () => _settlement(e),
                    child: const Text('Inspection & deposit settlement')),
              if (_user?.role == UserRole.tenant &&
                  _user?.id == e.tenantId &&
                  e.noticePath != null &&
                  e.status != 'cancelled')
                OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final response = await _note('Record a response',
                                label:
                                    'Response / acknowledgement (not consent to eviction)');
                            if (response != null)
                              await _run(
                                  () => widget.service.respond(e.id, response));
                          },
                    child: const Text('Respond / acknowledge')),
              if (_owner && e.status == 'departure_recorded')
                FilledButton(
                    key: ValueKey('close-eviction-${e.id}'),
                    onPressed: _busy || !e.canClose ? null : () => _close(e),
                    child: const Text('Close contract & room')),
              if (_owner &&
                  ['decision_recorded', 'notice_sent'].contains(e.status))
                TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final reason = await _note('Rescind owner decision',
                                maxLength: 1200);
                            if (reason != null)
                              await _run(
                                  () => widget.service.cancel(e.id, reason));
                          },
                    child: const Text('Rescind decision')),
              TextButton(
                  onPressed: _busy ? null : () => _history(e),
                  child: const Text('Case history')),
            ]),
            if (e.status == 'departure_recorded' && !e.canClose)
              const Text(
                  'Complete final inspection, clearance and settlement in the linked workspace before closure.'),
          ])));
}

class EvictionDecisionDraft {
  const EvictionDecisionDraft(
      this.tenantId, this.deadline, this.reason, this.conductCaseId);
  final String tenantId, reason;
  final String? conductCaseId;
  final DateTime deadline;
}

class EvictionDecisionDialog extends StatefulWidget {
  const EvictionDecisionDialog(
      {super.key,
      required this.contracts,
      required this.cases,
      this.initialTenantId,
      this.initialConductCaseId});
  final List<TenantContract> contracts;
  final List<ConductCaseRecord> cases;
  final String? initialTenantId, initialConductCaseId;
  @override
  State<EvictionDecisionDialog> createState() => _EvictionDecisionDialogState();
}

class _EvictionDecisionDialogState extends State<EvictionDecisionDialog> {
  String? _tenantId, _caseId;
  DateTime _deadline = DateUtils.dateOnly(DateTime.now());
  final _reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    _tenantId =
        widget.contracts.any((c) => c.tenantId == widget.initialTenantId)
            ? widget.initialTenantId
            : null;
    if (widget.cases.any((c) =>
        c.id == widget.initialConductCaseId &&
        c.tenantId == _tenantId &&
        c.status == 'termination_review_recommended'))
      _caseId = widget.initialConductCaseId;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Record owner eviction decision'),
          content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                    initialValue: _tenantId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Tenant / active contract'),
                    items: widget.contracts
                        .map((c) => DropdownMenuItem(
                            value: c.tenantId,
                            child: Text('${c.tenantName} · ${c.contractNumber}',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() {
                          _tenantId = v;
                          _caseId = null;
                        })),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    key: ValueKey(_tenantId),
                    initialValue: _caseId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText:
                            'Supporting conduct recommendation (optional)'),
                    items: [
                      const DropdownMenuItem(
                          value: '',
                          child: Text('Owner decision without a conduct link')),
                      for (final c in widget.cases.where((c) =>
                          c.tenantId == _tenantId &&
                          c.status == 'termination_review_recommended'))
                        DropdownMenuItem(
                            value: c.id,
                            child:
                                Text(c.title, overflow: TextOverflow.ellipsis))
                    ],
                    onChanged: (v) =>
                        setState(() => _caseId = v == '' ? null : v)),
                TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                          context: context,
                          initialDate: _deadline,
                          firstDate: DateUtils.dateOnly(DateTime.now()),
                          lastDate: DateTime(2100));
                      if (date != null && mounted)
                        setState(() => _deadline = date);
                    },
                    child: Text(
                        'Owner-specified deadline: ${_deadline.toIso8601String().split('T').first}')),
                TextField(
                    controller: _reason,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                        labelText:
                            'Owner decision and reason (included in the notice)')),
                const Text(
                    'The decision is saved for review first. Publishing the notice is a separate owner action. Contract and room closure follow departure and settlement.'),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (_tenantId == null || _reason.text.trim().length < 10) {
                    showAppSnackBar(context,
                        'Choose a tenant and document the owner reason in at least 10 characters.');
                    return;
                  }
                  Navigator.pop(
                      context,
                      EvictionDecisionDraft(
                          _tenantId!, _deadline, _reason.text.trim(), _caseId));
                },
                child: const Text('Record decision'))
          ]);
}
