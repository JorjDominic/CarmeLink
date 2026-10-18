import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/record_details.dart';
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
        insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 400 ? 12 : 40,
            vertical: 24),
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
                              child: RecordSection(
                                  title: 'Saved payment receipt',
                                  icon: Icons.receipt_long_outlined,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SelectableText(receipt.number,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        if (receipt.isTest)
                                          const Text(PaymentReceipt.testNotice),
                                        const SizedBox(height: 10),
                                        Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(1.1),
                                            1: FlexColumnWidth(1.7)
                                          },
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.top,
                                          children: [
                                            for (final fact
                                                in <(String, String)>[
                                              (
                                                'Amount received',
                                                'PHP ' +
                                                    receipt.amount
                                                        .toStringAsFixed(2)
                                              ),
                                              ('Payer', receipt.tenantName),
                                              ('Bill', receipt.billTitle),
                                              ('Method', receipt.method),
                                              (
                                                'Received',
                                                shortDate(receipt.receivedAt) +
                                                    ' ' +
                                                    MaterialLocalizations.of(
                                                            context)
                                                        .formatTimeOfDay(TimeOfDay
                                                            .fromDateTime(receipt
                                                                .receivedAt))
                                              ),
                                            ])
                                              TableRow(
                                                  decoration: BoxDecoration(
                                                      border: Border(
                                                          bottom: BorderSide(
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .outlineVariant
                                                                  .withValues(
                                                                      alpha:
                                                                          .5)))),
                                                  children: [
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .fromLTRB(
                                                                0, 8, 12, 8),
                                                        child: Text(fact.$1,
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .onSurfaceVariant))),
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 8),
                                                        child: Text(fact.$2,
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600))),
                                                  ]),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        SelectableText('Payment reference: ' +
                                            receipt.reference),
                                        const SizedBox(height: 10),
                                        OutlinedButton.icon(
                                            onPressed: printing != null
                                                ? null
                                                : () => printReceipt(receipt),
                                            icon: const Icon(
                                                Icons.print_outlined),
                                            label: Text(printing == receipt.id
                                                ? 'Printing...'
                                                : 'Print receipt')),
                                        if (SupabaseConfig.isInitialized)
                                          IssuedReceiptRegister(
                                              key: ValueKey(receipt.id),
                                              receipt: receipt),
                                      ]))),
                      ]);
                })),
        actions: [
          TextButton(
              onPressed: printing != null ? null : () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      );
}
