import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/security_deposit_service.dart';
import '../../services/table_refresh_subscription.dart';

class SecurityDepositCard extends StatefulWidget {
  const SecurityDepositCard({super.key, this.contractId, this.tenantId});
  final String? contractId, tenantId;

  @override
  State<SecurityDepositCard> createState() => _SecurityDepositCardState();
}

class _SecurityDepositCardState extends State<SecurityDepositCard> {
  final _service = const SecurityDepositService();
  late final TableRefreshSubscription _subscription;
  late Future<SecurityDepositRecord?> _future =
      _service.load(contractId: widget.contractId, tenantId: widget.tenantId);

  @override
  void initState() {
    super.initState();
    _subscription = TableRefreshSubscription(
      'deposit-receipt-${identityHashCode(this)}',
      ['security_deposit_receipts', 'legacy_security_deposit_links'],
      () {
        if (mounted) _reload();
      },
      catchUpInterval: null,
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _future = _service.load(
            contractId: widget.contractId, tenantId: widget.tenantId);
      });

  Future<void> _edit(SecurityDepositRecord record) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _DepositReceiptDialog(record: record, service: _service),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _linkLegacy(
      SecurityDepositRecord record, Map<String, dynamic> receipt) async {
    final amount = (receipt['received_amount'] as num).toDouble();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Link historical deposit receipt?'),
              content: Text(
                  'Confirm this receipt belongs to ${record.contractNumber}. '
                  'This adds ₱${amount.toStringAsFixed(2)} to its confirmed deposit. '
                  'Do not link money already included in the received total.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm link')),
              ],
            ));
    if (confirmed != true) return;
    try {
      await _service.linkLegacy(
          receipt['charge_id'] as String, record.contractId);
      if (mounted) _reload();
    } catch (_) {
      if (mounted)
        showAppSnackBar(context,
            'Receipt could not be linked. Refresh and check the contract and settlement status.');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SecurityDepositRecord?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return CarmelitaCard(
                child: Column(children: [
              const Text('Security deposit details are unavailable.'),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ]));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final record = snapshot.data;
          if (record == null) return const SizedBox.shrink();
          final owner =
              SessionController.instance.currentUser?.role == UserRole.owner;
          String money(double value) => '₱${value.toStringAsFixed(2)}';
          return CarmelitaCard(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(
                    child: Text('Security deposit',
                        style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(
                    tooltip: 'Refresh deposit',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded)),
              ]),
              Text(record.contractNumber),
              const SizedBox(height: 8),
              StatusPill(record.status),
              const SizedBox(height: 8),
              InfoRow(
                  label: 'Contract amount',
                  value: money(record.requiredAmount)),
              InfoRow(
                  label: 'Confirmed received',
                  value: money(record.receivedAmount)),
              if (!record.settled && record.receivedAmount > 0)
                InfoRow(
                    label: 'Held for settlement',
                    value: money(record.heldAmount)),
              if (record.receivedOn != null)
                InfoRow(
                    label: 'Received on',
                    value:
                        record.receivedOn!.toIso8601String().substring(0, 10)),
              if (record.method.isNotEmpty)
                InfoRow(label: 'Method', value: record.method),
              if (record.reference.isNotEmpty)
                InfoRow(label: 'Reference', value: record.reference),
              if (record.settled) ...[
                InfoRow(
                    label: 'Approved deductions',
                    value: money(record.deductions)),
                InfoRow(
                    label: 'Refund recorded',
                    value: money(record.refundedAmount)),
              ],
              const SizedBox(height: 8),
              const Text(
                  'Recorded separately from bills. Management confirms money received; refunds and approved deductions are recorded at move-out.'),
              if (record.unassignedReceipts.isNotEmpty) ...[
                const Divider(),
                const Text(
                    'Historical deposit receipts awaiting contract review'),
                for (final receipt in record.unassignedReceipts)
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${money((receipt['received_amount'] as num).toDouble())} · ${receipt['reference']}'),
                        if (owner && !record.settled)
                          TextButton(
                              onPressed: () => _linkLegacy(record, receipt),
                              child:
                                  const Text('Link receipt to this contract')),
                      ]),
              ],
              if (owner && !record.settled)
                TextButton.icon(
                    onPressed: record.unassignedReceipts.isEmpty
                        ? () => _edit(record)
                        : null,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Record or correct receipt')),
            ],
          ));
        },
      );
}

class _DepositReceiptDialog extends StatefulWidget {
  const _DepositReceiptDialog({required this.record, required this.service});
  final SecurityDepositRecord record;
  final SecurityDepositService service;

  @override
  State<_DepositReceiptDialog> createState() => _DepositReceiptDialogState();
}

class _DepositReceiptDialogState extends State<_DepositReceiptDialog> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
      text: widget.record.receivedAmount.toStringAsFixed(2));
  late final _date = TextEditingController(
      text: (widget.record.receivedOn ?? DateTime.now())
          .toIso8601String()
          .substring(0, 10));
  late final _method = TextEditingController(text: widget.record.method);
  late final _reference = TextEditingController(text: widget.record.reference);
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_amount, _date, _method, _reference, _reason]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.record(
          contractId: widget.record.contractId,
          amount: double.parse(_amount.text),
          receivedOn: DateTime.parse(_date.text),
          method: _method.text,
          reference: _reference.text,
          reason: _reason.text);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error =
              'Receipt could not be saved. Check permissions, deployment, and whether settlement is already finalized.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Confirm deposit received'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'Enter the total actually received, not an additional payment. Corrections are audited.'),
                TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Total received'),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');
                      return amount == null || !amount.isFinite || amount < 0
                          ? 'Enter a valid non-negative amount'
                          : null;
                    }),
                TextFormField(
                    controller: _date,
                    decoration: const InputDecoration(
                        labelText: 'Receipt date (YYYY-MM-DD)'),
                    validator: (value) {
                      final date = DateTime.tryParse(value ?? '');
                      return date == null ||
                              date.isAfter(DateTime.now()) ||
                              date.toIso8601String().substring(0, 10) != value
                          ? 'Enter a valid date on or before today'
                          : null;
                    }),
                TextFormField(
                    controller: _method,
                    decoration: const InputDecoration(
                        labelText: 'Method (cash, transfer, etc.)'),
                    validator: (value) => double.tryParse(_amount.text) != 0 &&
                            (value ?? '').trim().isEmpty
                        ? 'Enter a method'
                        : null),
                TextFormField(
                    controller: _reference,
                    decoration: const InputDecoration(
                        labelText: 'Receipt / reference number'),
                    validator: (value) => double.tryParse(_amount.text) != 0 &&
                            (value ?? '').trim().isEmpty
                        ? 'Enter a reference'
                        : null),
                TextFormField(
                    controller: _reason,
                    decoration: const InputDecoration(
                        labelText: 'Receipt or correction note'),
                    validator: (value) => (value ?? '').trim().length < 3
                        ? 'Add a note (at least 3 characters)'
                        : null),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ]),
            ))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save receipt')),
        ],
      );
}
