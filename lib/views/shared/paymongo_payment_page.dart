import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../controllers/tenant_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/payment_collection_settings_service.dart';
import '../../services/paymongo_payment_service.dart';
import '../../services/receipt_print_service.dart';

/// Demo mode is local and never calls the gateway or billing service.
class PaymongoPaymentPage extends StatefulWidget {
  const PaymongoPaymentPage(
      {super.key,
      this.payment,
      this.demo = false,
      this.environment = 'test',
      this.service = const PaymongoPaymentService(),
      this.receiptPrinter = const ReceiptPrintService(),
      this.initialSession});
  final Payment? payment;
  final bool demo;
  final String environment;
  final PaymongoPaymentService service;
  final ReceiptPrintService receiptPrinter;
  final PaymongoPaymentSession? initialSession;
  @override
  State<PaymongoPaymentPage> createState() => _PaymongoPaymentPageState();
}

class _PaymongoPaymentPageState extends State<PaymongoPaymentPage> {
  Payment? _payment;
  PaymongoPaymentSession? _session;
  Timer? _poll;
  bool _busy = false;
  String? _error;
  String? _receiptError;
  List<PaymentReceipt> _receipts = [];
  final Map<String, Uint8List> _receiptDocuments = {};
  final Set<String> _selectedRentIds = {};
  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
    if (_payment?.isRent == true) _selectedRentIds.add(_payment!.id);
    _session = widget.initialSession;
    if (!widget.demo && _session?.paid == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadReceipts();
      });
    }
    if (!widget.demo && _session?.isActive == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
    if (!widget.demo && _payment != null && _session == null) _resume();
    if (!widget.demo)
      _poll = Timer.periodic(const Duration(seconds: 8), (_) {
        if (_session?.isActive == true && !_busy) _refresh();
      });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _resume() async {
    if (_payment == null) return;
    await _run(() async {
      final latest = _payment!.outstandingAmount <= 0
          ? await widget.service.confirmed(_payment!.id)
          : await widget.service.latest(_payment!.id);
      return latest != null && !latest.canRestart ? latest : null;
    });
  }

  Future<void> _run(Future<PaymongoPaymentSession?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await action();
      if (!mounted) return;
      final newlyPaid = session?.paid == true && _session?.paid != true;
      setState(() => _session = session);
      if (newlyPaid)
        unawaited(TenantController.instance.loadPayments(force: true));
      if (session?.paid == true) await _loadReceipts();
    } catch (error) {
      if (mounted)
        setState(() => _error = error is PaymentGatewayException
            ? error.message
            : 'Could not check this payment. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadReceipts() async {
    final session = _session;
    if (widget.demo || session?.paid != true) return;
    try {
      final receipts = await widget.service.receipts(session!.id);
      for (final receipt in receipts) {
        _receiptDocuments[receipt.id] ??=
            await widget.receiptPrinter.buildStoredReceipt(receipt);
      }
      if (mounted && _session?.id == session.id)
        setState(() {
          _receipts = receipts;
          _receiptError = receipts.isEmpty
              ? 'Receipt is not ready. Retry to check again.'
              : null;
        });
    } catch (_) {
      if (mounted)
        setState(() => _receiptError =
            'Payment remains confirmed. Could not load the receipt; retry safely.');
    }
  }

  Future<void> _printReceipt(PaymentReceipt receipt) async {
    try {
      await widget.receiptPrinter
          .printStoredReceipt(receipt, bytes: _receiptDocuments[receipt.id]);
      if (mounted) setState(() => _receiptError = null);
    } catch (_) {
      if (mounted)
        setState(() => _receiptError =
            'Payment remains confirmed. Could not open the receipt; try again.');
    }
  }

  void _demoOutcome(String status) {
    setState(() => _session = PaymongoPaymentSession(
        id: 'demo',
        status: status,
        amountCentavos: 350000,
        environment: 'demo',
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        reference: status == 'succeeded' ? 'DEMO-PAYMENT' : null));
  }

  void _create() {
    if (widget.demo) {
      _demoOutcome('pending');
      return;
    }
    if (_payment?.isRent == true) {
      _run(() => widget.service.createAdvance(_selectedRentIds.toList()));
    } else if (_session?.canRestart == true &&
        _session!.billBreakdown.isNotEmpty) {
      _run(() => widget.service.createAdvance(
          _session!.billBreakdown.map((item) => item.chargeId).toList()));
    } else if (_payment != null) {
      _run(() => widget.service.create(_payment!.id));
    }
  }

  void _refresh() {
    if (_session != null) _run(() => widget.service.refresh(_session!.id));
  }

  void _cancel() {
    if (widget.demo) {
      _demoOutcome('cancelled');
      return;
    }
    if (_session != null) _run(() => widget.service.cancel(_session!.id));
  }

  Future<void> _openSimulation(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'paymongo.com' || uri.host.endsWith('.paymongo.com')))
      return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(() => _error = 'Could not open the test payment page.');
    }
  }

  Widget _qr(String value) {
    try {
      if (!value.startsWith('data:image/png;base64,') &&
          !value.startsWith('data:image/jpeg;base64,')) {
        return const Text('QR preview unavailable. Refresh payment status.');
      }
      return Image.memory(base64Decode(value.split(',').last),
          width: 240,
          height: 240,
          errorBuilder: (_, __, ___) => const Text('QR preview unavailable.'));
    } catch (_) {
      return const Text('QR preview unavailable. Refresh payment status.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final isTest =
        widget.demo || (session?.isTest ?? widget.environment != 'live');
    final bills = TenantController.instance.payments
        .where((p) => p.canSubmitProof && !p.isDeposit)
        .toList();
    if (_payment != null && !bills.any((p) => p.id == _payment!.id)) {
      bills.add(_payment!);
    }
    final rentBills = bills.where((p) => p.isRent && p.canSubmitProof).toList()
      ..sort((a, b) =>
          (a.periodStart ?? a.dueDate).compareTo(b.periodStart ?? b.dueDate));
    final selectedBills = _payment?.isRent == true
        ? rentBills.where((p) => _selectedRentIds.contains(p.id)).toList()
        : <Payment>[if (_payment != null) _payment!];
    final breakdown = session != null
        ? session.billBreakdown
        : selectedBills
            .map((p) => PaymongoBillBreakdown(
                chargeId: p.id,
                title: p.label,
                amountCentavos: (p.outstandingAmount * 100).round(),
                periodStart: p.periodStart,
                periodEnd: p.periodEnd,
                dueDate: p.dueDate))
            .toList();
    final selectedTotal =
        selectedBills.fold<double>(0, (sum, p) => sum + p.outstandingAmount);
    final statusLabel = switch (session?.status) {
      'succeeded' => isTest ? 'Test payment confirmed' : 'Payment confirmed',
      'pending' => 'Awaiting payment',
      'creating' => 'Preparing payment request',
      'expired' => 'QR expired',
      'failed' => 'Payment failed',
      'cancelled' => 'Payment cancelled',
      'needs_review' => 'Payment needs staff reconciliation',
      _ => 'Ready to start',
    };
    return PageFrame(
        title:
            widget.demo ? 'Payment workflow demo' : 'Pay with PayMongo QR Ph',
        subtitle: widget.demo
            ? 'No account or API keys required'
            : 'Pay a bill or select rent months in advance',
        maxWidth: 680,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (isTest)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(widget.demo
                        ? 'DEMO ONLY — no money moves and no tenant bills are updated.'
                        : 'TEST MODE — use the test payment page. The displayed QR cannot collect payment. Successful simulations can update registered sample bills in the testing environment only. No real money is received.'))),
          if (!widget.demo &&
              widget.payment == null &&
              widget.initialSession == null) ...[
            DropdownButtonFormField<Payment>(
                initialValue: _payment,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Bill'),
                items: bills
                    .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.label, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: _busy || session != null
                    ? null
                    : (p) {
                        setState(() {
                          _payment = p;
                          _selectedRentIds.clear();
                          if (p?.isRent == true) _selectedRentIds.add(p!.id);
                        });
                        _resume();
                      }),
            const SizedBox(height: 12),
          ],
          if (!widget.demo &&
              _payment?.isRent == true &&
              (session == null || session.canRestart)) ...[
            Text('Select rent months',
                style: Theme.of(context).textTheme.titleMedium),
            const Text(
                'Select the scheduled months you want to cover. Amounts include any remaining balance.'),
            ...rentBills.map((p) => CheckboxListTile(
                key: ValueKey('rent-month-${p.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${DateFormat('MMMM yyyy').format(p.periodStart ?? p.dueDate)} — ${p.label}'),
                subtitle: Text(
                    'Due ${DateFormat.yMMMd().format(p.dueDate)} · PHP ${p.outstandingAmount.toStringAsFixed(2)}'),
                value: _selectedRentIds.contains(p.id),
                onChanged: _busy
                    ? null
                    : (selected) => setState(() {
                          _session = null;
                          if (selected == true) {
                            _selectedRentIds.add(p.id);
                          } else {
                            _selectedRentIds.remove(p.id);
                          }
                        }))),
            if (rentBills.length == 1)
              const Text(
                  'Additional months appear when management creates your scheduled rent bills.'),
            const SizedBox(height: 12),
          ],
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    Text(
                        widget.demo
                            ? 'Sample rent bill'
                            : breakdown.length > 1
                                ? 'Rent payment · ${breakdown.length} months'
                                : _payment?.label ??
                                    session?.billTitle ??
                                    'Bill payment',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                        'PHP ${(session?.amount ?? (widget.demo ? 3500 : selectedTotal)).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    if (!widget.demo && breakdown.isNotEmpty) ...[
                      const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Payment breakdown',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      ...breakdown.map((item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.periodStart != null
                              ? DateFormat('MMMM yyyy')
                                  .format(item.periodStart!)
                              : item.title),
                          subtitle: Text([
                            if (item.periodStart != null) item.title,
                            if (item.periodStart != null &&
                                item.periodEnd != null)
                              '${DateFormat.yMMMd().format(item.periodStart!)} – ${DateFormat.yMMMd().format(item.periodEnd!)}',
                            if (item.dueDate != null)
                              'Due ${DateFormat.yMMMd().format(item.dueDate!)}',
                          ].join('\n')),
                          trailing: Text(
                              'PHP ${(item.amountCentavos / 100).toStringAsFixed(2)}'))),
                      const Divider(),
                    ],
                    Text(statusLabel, key: const Key('gateway-payment-status')),
                    if (session?.status == 'pending') ...[
                      const SizedBox(height: 16),
                      if (isTest)
                        Column(children: [
                          QrImageView(
                            key: const Key('demo-payment-qr'),
                            data:
                                'CARMELITA DEMO ONLY - NOT A PAYMENT: ${session!.id}',
                            size: 220,
                            backgroundColor: Colors.white,
                            semanticsLabel:
                                'Demo QR code. Cannot collect payment.',
                          ),
                          const SizedBox(height: 8),
                          const Text('DEMO QR - no real payment'),
                          Text(widget.demo
                              ? 'Use the simulation buttons below to demonstrate payment.'
                              : 'Use the test payment page below to simulate payment.'),
                        ])
                      else if (session?.qrImage != null)
                        _qr(session!.qrImage!),
                    ],
                    if (session?.expiresAt != null &&
                        session?.isActive == true) ...[
                      const SizedBox(height: 8),
                      Text(
                          'Valid until ${TimeOfDay.fromDateTime(session!.expiresAt!.toLocal()).format(context)}'),
                    ],
                    if (session?.reference != null) ...[
                      const SizedBox(height: 8),
                      SelectableText('Reference: ${session!.reference}')
                    ],
                    if (session?.issue != null) ...[
                      const SizedBox(height: 8),
                      Text(session!.issue!)
                    ],
                    if (widget.demo && session?.paid == true) ...[
                      const SizedBox(height: 8),
                      const Text(
                          'Sample balance: PHP 0.00. Actual balances unchanged.'),
                    ],
                  ]))),
          if (_busy) const LinearProgressIndicator(),
          if (!widget.demo && session?.paid == true) ...[
            for (final receipt in _receipts)
              Card(
                  child: ListTile(
                title: Text('Receipt: ${receipt.billTitle}'),
                subtitle: Text(
                    '${receipt.number}\n${receipt.isTest ? PaymentReceipt.testNotice : 'Verified payment receipt'}'),
                isThreeLine: true,
                trailing: IconButton(
                    tooltip: 'Print / save receipt',
                    onPressed: () => _printReceipt(receipt),
                    icon: const Icon(Icons.print_outlined)),
              )),
            if (_receiptError != null) Text(_receiptError!),
            if (_receiptError != null)
              TextButton(
                  onPressed: _loadReceipts, child: const Text('Retry receipt')),
          ],
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (session == null || session.canRestart)
            FilledButton.icon(
                onPressed: _busy ||
                        (!widget.demo &&
                            selectedBills.isEmpty &&
                            !(session?.canRestart == true &&
                                session!.billBreakdown.isNotEmpty))
                    ? null
                    : _create,
                icon: const Icon(Icons.qr_code),
                label: Text(widget.demo
                    ? 'Start demo payment'
                    : 'Generate payment request')),
          if (session != null && !widget.demo && !session.paid)
            OutlinedButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Check payment status')),
          if (!widget.demo &&
              session?.isTest == true &&
              session?.testUrl != null &&
              session?.status == 'pending')
            FilledButton(
                onPressed:
                    _busy ? null : () => _openSimulation(session!.testUrl!),
                child: const Text('Open test payment page')),
          if (widget.demo && session?.isActive == true) ...[
            FilledButton(
                onPressed: () => _demoOutcome('succeeded'),
                child: const Text('Simulate successful payment')),
            OutlinedButton(
                onPressed: () => _demoOutcome('failed'),
                child: const Text('Simulate failed payment')),
            OutlinedButton(
                onPressed: () => _demoOutcome('expired'),
                child: const Text('Simulate expired QR')),
          ],
          if (session?.isActive == true)
            TextButton(
                onPressed: _busy ? null : _cancel,
                child: const Text('Cancel payment request')),
          const SizedBox(height: 12),
          Text(widget.demo
              ? 'This preview is local. It does not contact PayMongo or modify payment history.'
              : 'You can leave this page and return to check the same payment. A payment is confirmed only after backend verification.'),
        ]));
  }
}
