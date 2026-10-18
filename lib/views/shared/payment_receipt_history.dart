import 'package:flutter/material.dart';
import '../../services/receipt_print_service.dart';
import '../../core/config/supabase_config.dart';
import 'issued_receipt_register.dart';

class PaymentReceiptHistoryDialog extends StatefulWidget {
  const PaymentReceiptHistoryDialog(
      {super.key,
      required this.chargeId,
      this.service = const ReceiptPrintService()});
  final String chargeId;
  final ReceiptPrintService service;
  @override
  State<PaymentReceiptHistoryDialog> createState() =>
      _PaymentReceiptHistoryDialogState();
}

class _PaymentReceiptHistoryDialogState
    extends State<PaymentReceiptHistoryDialog> {
  late Future<List<PaymentReceipt>> receipts =
      widget.service.listForCharge(widget.chargeId);
  String? printing, error;
  Future<void> printReceipt(PaymentReceipt receipt) async {
    if (printing != null) return;
    setState(() {
      printing = receipt.id;
      error = null;
    });
    try {
      await widget.service.printStoredReceipt(receipt);
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Payment remains verified. Could not print this saved receipt. Try again.');
    } finally {
      if (mounted) setState(() => printing = null);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: const Text('Payment receipts'),
        content: SizedBox(
            width: 620,
            child: FutureBuilder<List<PaymentReceipt>>(
                future: receipts,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Payment records are unchanged. Could not load receipts. Check your access and connection, then retry.'),
                      TextButton(
                          onPressed: () {
                            final retry =
                                widget.service.listForCharge(widget.chargeId);
                            setState(() {
                              receipts = retry;
                            });
                          },
                          child: const Text('Retry')),
                    ]);
                  final rows = snapshot.data ?? [];
                  return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rows.isEmpty)
                          const Text(
                              'No verified payment receipts are available for this bill.'),
                        if (error != null) Text(error!),
                        for (final receipt in rows)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(receipt.number,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    if (receipt.isTest)
                                      const Text(PaymentReceipt.testNotice),
                                    Text(
                                        '${receipt.tenantName} · ${receipt.billTitle}'),
                                    Text(
                                        'PHP ${receipt.amount.toStringAsFixed(2)} · ${receipt.method}'),
                                    Text('Received ${receipt.receivedAt}'),
                                    SelectableText(
                                        'Payment reference: ${receipt.reference}'),
                                    OutlinedButton.icon(
                                        onPressed: printing != null
                                            ? null
                                            : () => printReceipt(receipt),
                                        icon: const Icon(Icons.print_outlined),
                                        label: Text(printing == receipt.id
                                            ? 'Printing...'
                                            : 'Print receipt')),
                                    if (SupabaseConfig.isInitialized)
                                      IssuedReceiptRegister(
                                          key: ValueKey(receipt.id),
                                          receipt: receipt),
                                  ])),
                      ]);
                })),
        actions: [
          TextButton(
              onPressed: printing != null ? null : () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      );
}
