import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/owner_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/utils/move_out_settlement_policy.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/move_out_settlement_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'security_deposit_card.dart';

class MoveOutSettlementPage extends StatefulWidget {
  const MoveOutSettlementPage({super.key, this.initialCaseId});
  final String? initialCaseId;

  @override
  State<MoveOutSettlementPage> createState() => _MoveOutSettlementPageState();
}

class _MoveOutSettlementPageState extends State<MoveOutSettlementPage> {
  final _service = const MoveOutSettlementService();
  TableRefreshSubscription? _subscription;
  bool _loading = true;
  String? _error;
  List<MoveOutCaseRecord> _cases = const [];
  MoveOutCaseRecord? _tenantCase;
  String? _selectedCaseId;

  AppUser? get _user => SessionController.instance.currentUser;
  bool get _isTenant => _user?.role == UserRole.tenant;
  bool get _isOwner => _user?.role == UserRole.owner;
  bool get _isStaff =>
      _user?.role == UserRole.owner || _user?.role == UserRole.caretaker;

  @override
  void initState() {
    super.initState();
    if (_isStaff && !OwnerController.instance.tenantsLoadedOnce) {
      unawaited(OwnerController.instance.loadTenants());
    }
    unawaited(_initialize());
    _subscription = TableRefreshSubscription(
      'phase8-move-out-settlement',
      const [
        'move_out_cases',
        'move_out_clearance_items',
        'move_out_deductions',
        'move_out_settlements',
        'room_inspections',
        'billing_charges',
        'payment_transactions',
      ],
      () => unawaited(_load(silent: true)),
      debounceDuration: const Duration(milliseconds: 500),
      catchUpInterval: const Duration(seconds: 60),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.dispose());
    super.dispose();
  }

  String get _selectionKey =>
      'carmelink.phase8.selected_case.${_user?.role.name ?? 'unknown'}';

  Future<void> _initialize() async {
    if (_isStaff) {
      final prefs = await SharedPreferences.getInstance();
      _selectedCaseId = widget.initialCaseId ?? prefs.getString(_selectionKey);
    }
    await _load();
  }

  Future<void> _selectCase(String id) async {
    setState(() => _selectedCaseId = id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectionKey, id);
  }

  Future<void> _clearSelectedCase() async {
    setState(() => _selectedCaseId = null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectionKey);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      if (_isTenant) {
        _tenantCase = widget.initialCaseId == null
            ? await _service.currentCase()
            : await _service.caseById(widget.initialCaseId!);
      } else if (_isStaff) {
        if (!OwnerController.instance.tenantsLoadedOnce) {
          await OwnerController.instance.loadTenants();
        }
        _cases = await _service.listCases();
      }
      if (!mounted) return;
      setState(() {
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = moveOutSettlementError(error);
        _loading = false;
      });
    }
  }

  Future<void> _createNotice({String? forcedTenantId}) async {
    final tenantId = forcedTenantId ?? _user?.id;
    if (tenantId == null) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _MoveOutNoticeDialog(
        tenantId: tenantId,
        staffMode: _isStaff,
      ),
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTenant && !_isStaff) {
      return const PageFrame(
        title: 'Move-out',
        child: WorkInProgressNotice(
          message:
              'Move-out settlement is available to tenants and authorized dormitory staff.',
        ),
      );
    }

    return PageFrame(
      title: _isTenant ? 'Move-out' : 'Move-out',
      subtitle: _isTenant
          ? 'Submit and track your notice, final inspection, clearance, and deposit settlement.'
          : 'Coordinate notice, final inspection, clearance, deposit settlement, and closure handoff.',
      onRefresh: () => _load(),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : _error != null
              ? _Phase8Error(message: _error!, onRetry: () => _load())
              : _isTenant
                  ? _tenantContent()
                  : _staffContent(),
    );
  }

  Widget _tenantContent() {
    final record = _tenantCase;
    if (record == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Phase8BoundaryNotice(),
          const SizedBox(height: 14),
          CarmelitaCard(
            emphasis: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planning to move out?',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'CarmeLink records a minimum 30-day move-out notice. Final inspection, clearance, and any deposit settlement are reviewed separately.',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const Key('phase8-submit-notice'),
                  onPressed: () => _createNotice(),
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: const Text('Submit move-out notice'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return _MoveOutCaseDetail(
      record: record,
      service: _service,
      isOwner: false,
      isStaff: false,
      onChanged: () => _load(),
    );
  }

  Widget _staffContent() {
    final controller = OwnerController.instance;
    MoveOutCaseRecord? selected;
    if (_selectedCaseId != null) {
      for (final item in _cases) {
        if (item.id == _selectedCaseId) {
          selected = item;
          break;
        }
      }
    }
    if (selected != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            key: const Key('phase8-back-to-queue'),
            onPressed: () => _clearSelectedCase(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to move-out queue'),
          ),
          const SizedBox(height: 8),
          _MoveOutCaseDetail(
            record: selected,
            service: _service,
            isOwner: _isOwner,
            isStaff: true,
            onChanged: () => _load(),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Phase8BoundaryNotice(),
        const SizedBox(height: 14),
        CarmelitaCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Move-out queue',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_cases.where((item) => item.status != 'cancelled').length} active case(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Record move-out notice',
                enabled: controller.tenants.isNotEmpty,
                onSelected: (id) => _createNotice(forcedTenantId: id),
                itemBuilder: (_) => controller.tenants
                    .map(
                      (tenant) => PopupMenuItem(
                        value: tenant.id,
                        child: Text(
                          '${tenant.name} · ${tenant.room}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                child: const FilledButtonIconPreview(
                  icon: Icons.add_rounded,
                  label: 'Record notice',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_cases.isEmpty)
          const CarmelitaCard(
            child: Text('No move-out cases have been recorded yet.'),
          )
        else
          for (final record in _cases) ...[
            CarmelitaCard(
              onTap: () => _selectCase(record.id),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      record.tenantName.isEmpty
                          ? 'T'
                          : record.tenantName[0].toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.tenantName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Planned ${shortDate(record.plannedMoveOutOn)} · ${_roomLabel(record)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(_statusLabel(record.status)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class FilledButtonIconPreview extends StatelessWidget {
  const FilledButtonIconPreview({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: FilledButton.icon(
          onPressed: () {},
          icon: Icon(icon),
          label: Text(label),
        ),
      );
}

class _MoveOutCaseDetail extends StatefulWidget {
  const _MoveOutCaseDetail({
    required this.record,
    required this.service,
    required this.isOwner,
    required this.isStaff,
    required this.onChanged,
  });

  final MoveOutCaseRecord record;
  final MoveOutSettlementService service;
  final bool isOwner;
  final bool isStaff;
  final Future<void> Function() onChanged;

  @override
  State<_MoveOutCaseDetail> createState() => _MoveOutCaseDetailState();
}

class _MoveOutCaseDetailState extends State<_MoveOutCaseDetail> {
  bool get _editable => !['closed', 'cancelled'].contains(widget.record.status);
  late Future<MoveOutCaseDetails> _future =
      widget.service.getDetails(widget.record);

  @override
  void didUpdateWidget(covariant _MoveOutCaseDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id ||
        oldWidget.record.updatedAt != widget.record.updatedAt) {
      _future = widget.service.getDetails(widget.record);
    }
  }

  void _reload() {
    setState(() {
      _future = widget.service.getDetails(widget.record);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      _reload();
      await widget.onChanged();
    } catch (error) {
      if (mounted) {
        _reload();
        showAppSnackBar(context, moveOutSettlementError(error));
      }
    }
  }

  Future<void> _cancel() async {
    final reason = await _textDialog(
      context,
      title: 'Cancel move-out notice',
      label: 'Reason',
    );
    if (reason == null) return;
    await _run(() => widget.service.cancelCase(widget.record.id, reason));
  }

  Future<void> _scheduleInspection() async {
    final result = await showDialog<_InspectionDraft>(
      context: context,
      builder: (_) => const _FinalInspectionDialog(),
    );
    if (result == null) return;
    await _run(() async {
      await widget.service.scheduleFinalInspection(
        caseId: widget.record.id,
        scheduledAt: result.scheduledAt,
        noticeText: result.noticeText,
      );
    });
  }

  void _openInspections() {
    final nav = CarmelitaNavScope.maybeOf(context);
    if (nav != null) {
      nav.selectLabel('Room inspections');
      return;
    }
    showAppSnackBar(
      context,
      'Open Management → Rooms → Room inspections to manage the final inspection.',
    );
  }

  Future<void> _editClearance(MoveOutClearanceRecord item) async {
    final result = await showDialog<_ClearanceDraft>(
      context: context,
      builder: (_) => _ClearanceDialog(item: item),
    );
    if (result == null) return;
    await _run(() => widget.service.setClearanceItem(
          caseId: widget.record.id,
          itemKey: item.itemKey,
          status: result.status,
          notes: result.notes,
        ));
  }

  Future<void> _setDeposit(MoveOutSettlementRecord settlement) async {
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Security deposit receipt'),
              content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                      child: SecurityDepositCard(
                          contractId: widget.record.contractId))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
    if (mounted) _reload();
  }

  Future<void> _addDeduction() async {
    List<Payment> charges;
    try {
      charges = await widget.service.listDeductibleCharges(widget.record.id);
    } catch (error) {
      if (mounted) showAppSnackBar(context, moveOutSettlementError(error));
      return;
    }
    if (!mounted) return;
    final draft = await showDialog<_DeductionDraft>(
      context: context,
      builder: (_) => MoveOutChargeDeductionDialog(charges: charges),
    );
    if (draft == null) return;
    await _run(() => widget.service.addDeduction(
          caseId: widget.record.id,
          category: draft.category,
          label: draft.label,
          amount: draft.amount,
          evidenceNote: draft.evidenceNote,
          chargeId: draft.chargeId,
        ));
  }

  Future<void> _reviewDeduction(
    MoveOutDeductionRecord item,
    bool approve,
  ) async {
    final note = await _textDialog(
      context,
      title: approve ? 'Approve deduction' : 'Reject deduction',
      label: 'Review note',
      requiredLength: 0,
    );
    if (note == null) return;
    await _run(() => widget.service.reviewDeduction(
          deductionId: item.id,
          approve: approve,
          note: note,
        ));
  }

  Future<void> _recordOutcome(MoveOutSettlementRecord settlement) async {
    if (settlement.refundableAmount > 0) {
      final draft = await showDialog<_RefundDraft>(
        context: context,
        builder: (_) => _RefundDialog(amount: settlement.refundableAmount),
      );
      if (draft == null) return;
      await _run(() => widget.service.recordRefundWithProof(
            caseId: widget.record.id,
            expectedRefund: settlement.refundableAmount,
            expectedDeductions: settlement.approvedDeductions,
            refundMethod: draft.method,
            refundReference: draft.reference,
            bytes: draft.bytes,
            fileName: draft.fileName,
            contentType: draft.contentType,
          ));
      return;
    }

    if (settlement.shortfallAmount > 0) {
      final note = await _textDialog(
        context,
        title: 'Apply deposit and bill the remaining balance',
        label:
            'Explain the ₱${settlement.shortfallAmount.toStringAsFixed(2)} shortfall. The uncovered amount will remain payable on the linked bills.',
      );
      if (note == null) return;
      await _run(() => widget.service.recordSettlementOutcome(
            caseId: widget.record.id,
            expectedRefund: settlement.refundableAmount,
            expectedDeductions: settlement.approvedDeductions,
            shortfallNote: note,
          ));
      return;
    }

    await _run(() => widget.service.recordSettlementOutcome(
          caseId: widget.record.id,
          expectedRefund: settlement.refundableAmount,
          expectedDeductions: settlement.approvedDeductions,
        ));
  }

  Future<void> _markReady() async {
    final note = await _textDialog(
      context,
      title: 'Ready for contract / occupancy closure',
      label: 'Closure handoff note',
    );
    if (note == null) return;
    await _run(
        () => widget.service.markReadyForClosure(widget.record.id, note));
  }

  Future<void> _acknowledgeSettlement() async {
    final response = await _textDialog(
      context,
      title: 'Acknowledge settlement',
      label: 'Optional response or note',
      requiredLength: 0,
    );
    if (response == null) return;
    await _run(() => widget.service.acknowledgeSettlement(
          caseId: widget.record.id,
          response: response,
        ));
  }

  Future<void> _openRefundProof(String path) async {
    final url = await widget.service.createRefundProofUrl(path);
    if (!mounted) return;
    if (url == null) {
      showAppSnackBar(context, 'Refund proof is currently unavailable.');
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MoveOutCaseDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _Phase8Error(
              message: snapshot.hasError
                  ? moveOutSettlementError(snapshot.error!)
                  : 'Move-out case is unavailable.',
              onRetry: _reload,
            );
          }
          final details = snapshot.data!;
          final settlement = details.settlement;
          final inspectionComplete =
              details.finalInspectionStatus == 'completed';
          final clearanceComplete =
              MoveOutSettlementPolicy.clearanceAllowsClosure(
            details.clearance.map((item) => item.status),
          );
          final financialClear = details.outstandingNonDepositBalance <= .005;
          final settlementReady =
              MoveOutSettlementPolicy.settlementAllowsClosure(
            settlement.refundStatus,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _caseHeader(details),
              const SizedBox(height: 14),
              _readinessCard(
                details,
                inspectionComplete: inspectionComplete,
                clearanceComplete: clearanceComplete,
                financialClear: financialClear,
                settlementReady: settlementReady,
              ),
              const SizedBox(height: 18),
              _inspectionCard(details),
              const SizedBox(height: 18),
              _clearanceCard(details),
              const SizedBox(height: 18),
              _settlementCard(details),
              if (widget.isOwner &&
                  !['ready_for_closure', 'closed', 'cancelled']
                      .contains(details.caseRecord.status)) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('phase8-ready-for-closure'),
                    onPressed: inspectionComplete &&
                            clearanceComplete &&
                            financialClear &&
                            settlementReady
                        ? _markReady
                        : null,
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('Mark ready for closure handoff'),
                  ),
                ),
              ],
              if (widget.isOwner &&
                  details.caseRecord.status == 'ready_for_closure') ...[
                const SizedBox(height: 18),
                const CarmelitaCard(
                  emphasis: true,
                  child: Row(
                    children: [
                      Icon(Icons.task_alt_rounded),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ready for authorized contract and occupancy closure handoff.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!widget.isStaff &&
                  details.caseRecord.caseType == 'voluntary' &&
                  details.caseRecord.finalInspectionId == null &&
                  _editable) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancel,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel notice'),
                  ),
                ),
              ],
            ],
          );
        },
      );

  Widget _caseHeader(MoveOutCaseDetails details) => CarmelitaCard(
        emphasis: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    details.caseRecord.tenantName,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                StatusPill(_statusLabel(details.caseRecord.status)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _Fact(
                    'Notice', shortDate(details.caseRecord.noticeSubmittedOn)),
                _Fact(
                    details.caseRecord.caseType == 'eviction'
                        ? 'Owner departure deadline'
                        : 'Planned move-out',
                    shortDate(details.caseRecord.plannedMoveOutOn)),
                _Fact('Room', _roomLabel(details.caseRecord)),
                _Fact('Contract',
                    details.caseRecord.contractNumber ?? 'Not linked'),
                if (details.caseRecord.contractEndsOn != null)
                  _Fact('Lease end',
                      shortDate(details.caseRecord.contractEndsOn!)),
                _Fact('Refund deadline',
                    shortDate(details.caseRecord.refundDueOn)),
              ],
            ),
            if (details.caseRecord.reason.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(details.caseRecord.reason),
            ],
          ],
        ),
      );

  Widget _readinessCard(
    MoveOutCaseDetails details, {
    required bool inspectionComplete,
    required bool clearanceComplete,
    required bool financialClear,
    required bool settlementReady,
  }) =>
      CarmelitaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Closure readiness'),
            const SizedBox(height: 10),
            _CheckRow('Final move-out inspection', inspectionComplete),
            _CheckRow('Clearance checklist', clearanceComplete),
            _CheckRow(
              'Outstanding non-deposit charges',
              financialClear,
              detail: financialClear
                  ? 'Clear'
                  : '₱${details.outstandingNonDepositBalance.toStringAsFixed(2)} remaining',
            ),
            _CheckRow('Deposit settlement outcome', settlementReady),
            const Divider(height: 22),
            Text(
              'Ready for closure is a handoff marker. Any damage balance remaining after the deposit is applied must be paid before closure. Contract termination, assignment ending, and bed release are separate actions.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _inspectionCard(MoveOutCaseDetails details) => CarmelitaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Final inspection',
              trailing: widget.isStaff
                  ? TextButton.icon(
                      onPressed: _openInspections,
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('Room inspections'),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            if (details.caseRecord.finalInspectionId == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('No move-out inspection has been scheduled yet.'),
                  if (widget.isStaff && _editable) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('phase8-schedule-final-inspection'),
                      onPressed: _scheduleInspection,
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Schedule final inspection'),
                    ),
                  ],
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      details.finalInspectionScheduledAt == null
                          ? 'Move-out inspection'
                          : 'Scheduled ${shortDate(details.finalInspectionScheduledAt!)} · ${timeText(details.finalInspectionScheduledAt!)}',
                    ),
                  ),
                  StatusPill(_statusLabel(
                      details.finalInspectionStatus ?? 'scheduled')),
                ],
              ),
          ],
        ),
      );

  Widget _clearanceCard(MoveOutCaseDetails details) => CarmelitaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Clearance'),
            const SizedBox(height: 8),
            for (final item in details.clearance) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.status == 'cleared' || item.status == 'not_applicable'
                      ? Icons.check_circle_outline
                      : item.status == 'blocked'
                          ? Icons.error_outline
                          : Icons.radio_button_unchecked,
                ),
                title: Text(item.label),
                subtitle: item.notes.isEmpty ? null : Text(item.notes),
                trailing: StatusPill(_statusLabel(item.status)),
                onTap: widget.isStaff && _editable
                    ? () => _editClearance(item)
                    : null,
              ),
              if (item != details.clearance.last) const Divider(height: 1),
            ],
          ],
        ),
      );

  Widget _settlementCard(MoveOutCaseDetails details) {
    final s = details.settlement;
    final settlementFinal =
        MoveOutSettlementPolicy.settlementAllowsClosure(s.refundStatus);
    final proposedDeductions =
        details.deductions.any((item) => item.status == 'proposed');
    final inspectionComplete = details.finalInspectionStatus == 'completed';
    final clearanceComplete = MoveOutSettlementPolicy.clearanceAllowsClosure(
      details.clearance.map((item) => item.status),
    );
    final financialClear = details.outstandingNonDepositBalance <= .005;
    final canFinalize = inspectionComplete &&
        clearanceComplete &&
        financialClear &&
        !proposedDeductions;
    final today = DateTime.now();
    final refundDeadline = DateTime(
      s.refundDueOn.year,
      s.refundDueOn.month,
      s.refundDueOn.day,
    );
    final refundOverdue = s.refundStatus == 'pending' &&
        DateTime(today.year, today.month, today.day).isAfter(refundDeadline);

    return CarmelitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Deposit settlement',
            subtitle:
                'Approved deductions credit the linked bills when settlement is finalized. Only the uncovered balance stays payable.',
            trailing: widget.isOwner && !settlementFinal
                ? TextButton.icon(
                    onPressed: () => _setDeposit(s),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Review receipt'),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _Fact('Contract deposit',
                  _money(details.caseRecord.contractDepositAmount)),
              _Fact('Confirmed received', _money(s.depositReceivedAmount)),
              _Fact('Approved deductions', _money(s.approvedDeductions)),
              _Fact('Refundable', _money(s.refundableAmount)),
              _Fact('Shortfall', _money(s.shortfallAmount)),
              _Fact(
                'Outcome',
                refundOverdue ? 'Refund overdue' : _statusLabel(s.refundStatus),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Itemized deductions',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (widget.isStaff && !settlementFinal)
                TextButton.icon(
                  key: const Key('phase8-add-deduction'),
                  onPressed: _addDeduction,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Propose'),
                ),
            ],
          ),
          if (details.deductions.isEmpty)
            Text('No deductions recorded.',
                style: Theme.of(context).textTheme.bodySmall)
          else
            for (final item in details.deductions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.label),
                subtitle: Text(
                    '${_categoryLabel(item.category)} · ${item.evidenceNote}'
                    '${item.billingChargeId == null ? "" : "\nLinked bill: ${item.billingTitle ?? item.label}"}'
                    '${item.depositAppliedAmount > 0 ? "\nCovered by deposit: ${_money(item.depositAppliedAmount)}" : ""}'
                    '${item.billingChargeId != null ? "\nBill balance: ${_money(item.outstandingAmount ?? 0)}" : ""}'),
                leading: Text(
                  _money(item.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: item.status == 'proposed' &&
                        widget.isOwner &&
                        !settlementFinal
                    ? Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Reject',
                            onPressed: () => _reviewDeduction(item, false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                          IconButton(
                            tooltip: 'Approve',
                            onPressed: () => _reviewDeduction(item, true),
                            icon: const Icon(Icons.check_rounded),
                          ),
                        ],
                      )
                    : StatusPill(_statusLabel(item.status)),
              ),
          if (widget.isOwner && !settlementFinal) ...[
            const SizedBox(height: 12),
            if (!canFinalize) ...[
              Text(
                'Complete the final inspection, resolve clearance, clear ordinary balances, and review every proposed deduction before recording the settlement outcome.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const Key('phase8-record-settlement-outcome'),
                onPressed: canFinalize ? () => _recordOutcome(s) : null,
                icon: Icon(s.refundableAmount > 0
                    ? Icons.receipt_long_outlined
                    : s.shortfallAmount > 0
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline),
                label: Text(s.refundableAmount > 0
                    ? 'Record refund + proof'
                    : s.shortfallAmount > 0
                        ? 'Apply deposit + bill remaining balance'
                        : 'Finalize zero settlement'),
              ),
            ),
          ],
          if (s.refundedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Refund recorded ${shortDate(s.refundedAt!)}${s.refundReference == null ? '' : ' · ${s.refundReference}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (s.shortfallNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Shortfall handoff: ${s.shortfallNote}'),
          ],
          if (s.refundProofPath != null && s.refundProofPath!.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _openRefundProof(s.refundProofPath!),
              icon: const Icon(Icons.receipt_long_outlined, size: 17),
              label: const Text('View refund proof'),
            ),
          ],
          if (s.tenantAcknowledgedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tenant acknowledged ${shortDate(s.tenantAcknowledgedAt!)}'
              '${s.tenantResponse.isEmpty ? '' : ' · ${s.tenantResponse}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (!widget.isStaff && settlementFinal) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('phase8-acknowledge-settlement'),
                onPressed: _acknowledgeSettlement,
                icon: const Icon(Icons.task_alt_outlined),
                label: const Text('Acknowledge settlement'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoveOutNoticeDialog extends StatefulWidget {
  const _MoveOutNoticeDialog({required this.tenantId, required this.staffMode});
  final String tenantId;
  final bool staffMode;

  @override
  State<_MoveOutNoticeDialog> createState() => _MoveOutNoticeDialogState();
}

class _MoveOutNoticeDialogState extends State<_MoveOutNoticeDialog> {
  final _reason = TextEditingController();
  final _service = const MoveOutSettlementService();
  late DateTime _notice = DateTime.now();
  late DateTime _planned = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool notice) async {
    final current = notice ? _notice : _planned;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (notice) {
        _notice = picked;
        final minimum = picked.add(const Duration(days: 30));
        if (_planned.isBefore(minimum)) _planned = minimum;
      } else {
        _planned = picked;
      }
    });
  }

  Future<void> _submit() async {
    final error = MoveOutSettlementPolicy.validateNoticeDates(
      noticeDate: _notice,
      plannedMoveOutDate: _planned,
    );
    if (error != null) {
      showAppSnackBar(context, error);
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.createCase(
        tenantId: widget.tenantId,
        noticeDate: _notice,
        plannedMoveOutDate: _planned,
        reason: _reason.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(context, moveOutSettlementError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.staffMode
            ? 'Record move-out notice'
            : 'Submit move-out notice'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DateField(
                label: 'Notice date',
                value: _notice,
                onTap: widget.staffMode ? () => _pick(true) : null,
              ),
              const SizedBox(height: 12),
              _DateField(
                  label: 'Planned move-out',
                  value: _planned,
                  onTap: () => _pick(false)),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Reason / note (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'The planned date must be at least 30 days after notice.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving…' : 'Save notice')),
        ],
      );
}

class _FinalInspectionDialog extends StatefulWidget {
  const _FinalInspectionDialog();
  @override
  State<_FinalInspectionDialog> createState() => _FinalInspectionDialogState();
}

class _FinalInspectionDialogState extends State<_FinalInspectionDialog> {
  final _notice = TextEditingController(
      text: 'Final move-out room inspection and clearance review.');
  late DateTime _date = DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);

  @override
  void dispose() {
    _notice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Schedule final inspection'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DateField(
                label: 'Inspection date',
                value: _date,
                onTap: () async {
                  final value = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (value != null && mounted) setState(() => _date = value);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Time'),
                subtitle: Text(_time.format(context)),
                trailing: const Icon(Icons.schedule_outlined),
                onTap: () async {
                  final value = await showTimePicker(
                      context: context, initialTime: _time);
                  if (value != null && mounted) setState(() => _time = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notice,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Written notice'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (_notice.text.trim().length < 5) {
                showAppSnackBar(context, 'Enter a written inspection notice.');
                return;
              }
              Navigator.pop(
                context,
                _InspectionDraft(
                  scheduledAt: DateTime(_date.year, _date.month, _date.day,
                      _time.hour, _time.minute),
                  noticeText: _notice.text.trim(),
                ),
              );
            },
            child: const Text('Schedule'),
          ),
        ],
      );
}

class _ClearanceDialog extends StatefulWidget {
  const _ClearanceDialog({required this.item});
  final MoveOutClearanceRecord item;
  @override
  State<_ClearanceDialog> createState() => _ClearanceDialogState();
}

class _ClearanceDialogState extends State<_ClearanceDialog> {
  late String _status = widget.item.status;
  late final TextEditingController _notes =
      TextEditingController(text: widget.item.notes);
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.item.label),
        content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['pending', 'cleared', 'blocked', 'not_applicable']
                    .map((v) => DropdownMenuItem(
                        value: v, child: Text(_statusLabel(v))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes')),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  context, _ClearanceDraft(_status, _notes.text.trim())),
              child: const Text('Save')),
        ],
      );
}

class MoveOutChargeDeductionDialog extends StatefulWidget {
  const MoveOutChargeDeductionDialog({super.key, this.charges = const []});
  final List<Payment> charges;
  @override
  State<MoveOutChargeDeductionDialog> createState() => _DeductionDialogState();
}

class _DeductionDialogState extends State<MoveOutChargeDeductionDialog> {
  String _category = 'damage';
  String? _chargeId;
  final _label = TextEditingController();
  final _amount = TextEditingController();
  final _evidence = TextEditingController();
  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _evidence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Propose deposit deduction'),
        content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: _chargeId ?? '',
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Link an existing bill'),
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('New item (no existing bill)')),
                  for (final charge in widget.charges)
                    DropdownMenuItem(
                        value: charge.id,
                        child: Text(
                            '${charge.label} · ${_money(charge.outstandingAmount)}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() {
                  _chargeId = value == '' ? null : value;
                  final charge = widget.charges
                      .where((item) => item.id == _chargeId)
                      .firstOrNull;
                  if (charge != null) {
                    _category = charge.category;
                    _label.text = charge.label;
                    _amount.text = charge.outstandingAmount.toStringAsFixed(2);
                    _evidence.text = charge.notes ?? '';
                  }
                }),
              ),
              const SizedBox(height: 12),
              const Text(
                  'The owner must approve this proposal. Link existing bills to avoid charging for the same damage twice.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  key: ValueKey(_category),
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    'damage',
                    'cleaning',
                    'replacement',
                    'utility',
                    'other'
                  ]
                      .map((v) => DropdownMenuItem(
                          value: v, child: Text(_categoryLabel(v))))
                      .toList(),
                  onChanged: _chargeId != null
                      ? null
                      : (v) {
                          if (v != null) setState(() => _category = v);
                        }),
              const SizedBox(height: 12),
              TextField(
                  controller: _label,
                  readOnly: _chargeId != null,
                  decoration:
                      const InputDecoration(labelText: 'Deduction label')),
              const SizedBox(height: 12),
              TextField(
                  controller: _amount,
                  readOnly: _chargeId != null,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount', prefixText: '₱ ')),
              const SizedBox(height: 12),
              TextField(
                  controller: _evidence,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Evidence / basis note',
                      helperText:
                          'Reference inspection photos or repair receipts.')),
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final amount = double.tryParse(_amount.text.trim()) ?? 0;
                if (_label.text.trim().length < 2 ||
                    !amount.isFinite ||
                    amount <= 0 ||
                    (amount * 100 - (amount * 100).round()).abs() > .0001 ||
                    _evidence.text.trim().length < 3) {
                  showAppSnackBar(context,
                      'Complete the label, amount, and evidence note.');
                  return;
                }
                Navigator.pop(
                    context,
                    _DeductionDraft(_category, _label.text.trim(), amount,
                        _evidence.text.trim(), _chargeId));
              },
              child: const Text('Propose'))
        ],
      );
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.amount});
  final double amount;
  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _method = TextEditingController();
  final _reference = TextEditingController();
  PlatformFile? _file;
  bool _saving = false;
  @override
  void dispose() {
    _method.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (file != null && mounted) setState(() => _file = file);
  }

  Future<void> _submit() async {
    final f = _file;
    if (_method.text.trim().isEmpty ||
        _reference.text.trim().isEmpty ||
        f == null) {
      showAppSnackBar(
          context, 'Method, reference, and refund proof are required.');
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = await f.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted)
          showAppSnackBar(context, 'The selected refund proof is empty.');
        return;
      }
      final ext = f.extension?.toLowerCase();
      final type = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      if (!mounted) return;
      Navigator.pop(
          context,
          _RefundDraft(_method.text.trim(), _reference.text.trim(), bytes,
              f.name, type));
    } catch (_) {
      if (mounted)
        showAppSnackBar(context,
            'Unable to read the selected refund proof. Try another image.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Record refund · ${_money(widget.amount)}'),
        content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: _method,
                  enabled: !_saving,
                  decoration:
                      const InputDecoration(labelText: 'Refund method')),
              const SizedBox(height: 12),
              TextField(
                  controller: _reference,
                  enabled: !_saving,
                  decoration:
                      const InputDecoration(labelText: 'Reference number')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _saving ? null : _pickProof,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(_file?.name ?? 'Select refund proof')),
            ])),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Reading proof…' : 'Record refund'))
        ],
      );
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(shortDate(value)),
      trailing: Icon(Icons.calendar_month_outlined,
          color: onTap == null ? Theme.of(context).disabledColor : null),
      onTap: onTap);
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800))
      ]));
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.label, this.ok, {this.detail});
  final String label;
  final bool ok;
  final String? detail;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(
            ok
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: ok
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 9),
        Expanded(child: Text(detail == null ? label : '$label · $detail'))
      ]));
}

class _Phase8Error extends StatelessWidget {
  const _Phase8Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => CarmelitaCard(
          child: Column(children: [
        const Icon(Icons.cloud_off_outlined, size: 34),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'))
      ]));
}

class _Phase8BoundaryNotice extends StatelessWidget {
  const _Phase8BoundaryNotice();
  @override
  Widget build(BuildContext context) => CarmelitaCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        const Expanded(
            child: Text(
                'Owner-approved deductions are linked to bills when settlement is recorded. The deposit covers those bills first; any uncovered amount remains payable. Contract termination, assignment ending, and bed release remain separate authorized actions.'))
      ]));
}

class _InspectionDraft {
  const _InspectionDraft({required this.scheduledAt, required this.noticeText});
  final DateTime scheduledAt;
  final String noticeText;
}

class _ClearanceDraft {
  const _ClearanceDraft(this.status, this.notes);
  final String status;
  final String notes;
}

class _DeductionDraft {
  const _DeductionDraft(
      this.category, this.label, this.amount, this.evidenceNote,
      [this.chargeId]);
  final String category;
  final String label;
  final double amount;
  final String evidenceNote;
  final String? chargeId;
}

class _RefundDraft {
  const _RefundDraft(
      this.method, this.reference, this.bytes, this.fileName, this.contentType);
  final String method;
  final String reference;
  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

Future<String?> _textDialog(BuildContext context,
    {required String title,
    required String label,
    int requiredLength = 3}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
              title: Text(title),
              content: TextField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                      labelText: label, alignLabelWithHint: true)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.length < requiredLength) {
                        showAppSnackBar(dialogContext, 'Enter a valid note.');
                        return;
                      }
                      Navigator.pop(dialogContext, value);
                    },
                    child: const Text('Continue'))
              ]));
  controller.dispose();
  return result;
}

String _roomLabel(MoveOutCaseRecord record) {
  final room = record.roomNumber?.trim();
  final bed = record.bedLabel?.trim();
  if (room == null || room.isEmpty) return 'Unassigned';
  return bed == null || bed.isEmpty ? 'Room $room' : 'Room $room · Bed $bed';
}

String _statusLabel(String value) {
  final clean = value.trim().replaceAll('_', ' ');
  if (clean.isEmpty) return 'Unknown';
  return '${clean[0].toUpperCase()}${clean.substring(1)}';
}

String _categoryLabel(String value) => _statusLabel(value);
String _money(double value) => '₱${value.toStringAsFixed(2)}';
