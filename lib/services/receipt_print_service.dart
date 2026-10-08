import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

/// Uses the platform print dialog, including installed receipt printers.
class ReceiptPrintService {
  const ReceiptPrintService();

  Future<Uint8List> buildPaymentReceipt(
    Payment payment, {
    required double amount,
    required String reference,
    required DateTime receivedOn,
  }) async {
    if (!amount.isFinite || amount <= 0 || reference.trim().isEmpty) {
      throw ArgumentError(
          'A saved receipt reference and positive amount are required.');
    }
    final document = pw.Document();
    document.addPage(pw.MultiPage(
      pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm),
      build: (_) => [
        pw.Text("Carmelita's Dormitory",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text('PAYMENT RECEIPT'),
        pw.Divider(),
        pw.Text('Receipt: $reference'),
        pw.Text('Received: ${receivedOn.toIso8601String().substring(0, 10)}'),
        pw.Text('Tenant: ${payment.tenantName ?? payment.tenantId}'),
        pw.Text('Bill: ${payment.label}'),
        pw.Text('Bill ID: ${payment.id}'),
        pw.Text('Method: ${payment.paymentMethod ?? 'Face-to-face receipt'}'),
        pw.Divider(),
        pw.Text('Amount received: PHP ${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(
            'Current bill balance: PHP ${payment.outstandingAmount.toStringAsFixed(2)}'),
        pw.SizedBox(height: 12),
        pw.Text('Thank you. Keep this receipt for your records.'),
      ],
    ));
    return document.save();
  }

  Future<void> printPayment(
    Payment payment, {
    required double amount,
    required String reference,
    required DateTime receivedOn,
  }) async {
    final bytes = await buildPaymentReceipt(payment,
        amount: amount, reference: reference, receivedOn: receivedOn);
    await Printing.layoutPdf(
        name: 'Receipt-$reference',
        format:
            const PdfPageFormat(80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm),
        onLayout: (_) async => bytes);
  }
}
