import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/tenant_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/payment_collection_settings_service.dart';
import '../../services/paymongo_payment_service.dart';

/// Demo mode is local and never calls the gateway or billing service.
class PaymongoPaymentPage extends StatefulWidget {
  const PaymongoPaymentPage(
      {super.key,
      this.payment,
      this.demo = false,
      this.environment = 'test',
      this.service = const PaymongoPaymentService(),
      this.initialSession});
  final Payment? payment;
  final bool demo;
  final String environment;
  final PaymongoPaymentService service;
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
  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
    _session = widget.initialSession;
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
      final latest = await widget.service.latest(_payment!.id);
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
      if (newlyPaid && session?.isTest == false)
        unawaited(TenantController.instance.loadPayments(force: true));
    } catch (error) {
      if (mounted)
        setState(() => _error = error is PaymentGatewayException
            ? error.message
            : 'Could not check this payment. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
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
    if (_payment != null) _run(() => widget.service.create(_payment!.id));
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
            : 'Bill-specific payment and confirmation',
        maxWidth: 680,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (isTest)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(widget.demo
                        ? 'DEMO ONLY — no money moves and no tenant bills are updated.'
                        : 'PAYMONGO TEST MODE — use the test payment page. Do not scan or pay this QR with a real wallet. Actual bills remain unchanged.'))),
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
                        setState(() => _payment = p);
                        _resume();
                      }),
            const SizedBox(height: 12),
          ],
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    Text(
                        widget.demo
                            ? 'Sample rent bill'
                            : _payment?.label ??
                                session?.billTitle ??
                                'Bill payment',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                        'PHP ${(session?.amount ?? (widget.demo ? 3500 : _payment?.outstandingAmount ?? 0)).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text(statusLabel, key: const Key('gateway-payment-status')),
                    if (session?.status == 'pending') ...[
                      const SizedBox(height: 16),
                      if (widget.demo)
                        const Column(children: [
                          Icon(Icons.qr_code_2, size: 160),
                          Text('Illustration only — no payable QR')
                        ])
                      else if (session?.qrImage != null && !isTest)
                        _qr(session!.qrImage!)
                      else if (isTest)
                        const Text(
                            'Use the test payment page below to simulate payment.'),
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
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (session == null || session.canRestart)
            FilledButton.icon(
                onPressed: _busy || (!widget.demo && _payment == null)
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
