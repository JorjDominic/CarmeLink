import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../core/config/supabase_config.dart';

class PaymentReceipt {
  const PaymentReceipt(
      {required this.id,
      required this.number,
      required this.tenantId,
      required this.tenantName,
      required this.chargeId,
      required this.billTitle,
      required this.amount,
      required this.reference,
      required this.method,
      required this.verifiedAt,
      required this.receivedAt,
      required this.environment,
      required this.balanceAfter});
  final String id,
      number,
      tenantId,
      tenantName,
      chargeId,
      billTitle,
      reference,
      method,
      environment;
  final double amount, balanceAfter;
  final DateTime verifiedAt, receivedAt;
  bool get isTest => environment == 'test';
  static const testNotice =
      'TEST TRANSACTION - NOT VALID FOR OFFICIAL COLLECTION';
  factory PaymentReceipt.fromJson(Map<String, dynamic> row) => PaymentReceipt(
      id: row['id'] as String,
      number: row['receipt_number'] as String,
      tenantId: row['tenant_id'] as String,
      tenantName: row['tenant_name'] as String,
      chargeId: row['charge_id'] as String,
      billTitle: row['bill_title'] as String,
      amount: (row['amount'] as num).toDouble(),
      reference: row['reference_number'] as String,
      method: row['payment_method'] as String,
      environment: row['environment'] as String,
      verifiedAt: DateTime.parse(row['verified_at'] as String).toLocal(),
      receivedAt: DateTime.parse(row['received_at'] as String).toLocal(),
      balanceAfter: (row['balance_after'] as num).toDouble());
}

/// Uses the platform print dialog, including installed receipt printers.
class ReceiptPrintService {
  const ReceiptPrintService();

  Future<PaymentReceipt> loadTransaction(String transactionId) async {
    final result = await SupabaseConfig.client.rpc('get_payment_receipt',
        params: {'p_transaction_id': transactionId});
    return PaymentReceipt.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<Uint8List> buildStoredReceipt(PaymentReceipt receipt) =>
      buildPaymentReceipt(
          Payment(
              id: receipt.chargeId,
              tenantId: receipt.tenantId,
              tenantName: receipt.tenantName,
              label: receipt.billTitle,
              amount: receipt.amount,
              remainingBalance: receipt.balanceAfter,
              dueDate: receipt.verifiedAt,
              status: 'verified',
              paymentMethod: receipt.method),
          amount: receipt.amount,
          reference: receipt.reference,
          receivedOn: receipt.receivedAt,
          receiptNumber: receipt.number,
          verifiedAt: receipt.verifiedAt,
          isTest: receipt.isTest);

  Future<void> printStoredReceipt(PaymentReceipt receipt,
      {Uint8List? bytes}) async {
    final document = bytes ?? await buildStoredReceipt(receipt);
    await Printing.layoutPdf(
        name: 'Receipt-${receipt.number}',
        format:
            const PdfPageFormat(80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm),
        onLayout: (_) async => document);
  }

  Future<Uint8List> buildPaymentReceipt(
    Payment payment, {
    required double amount,
    required String reference,
    required DateTime receivedOn,
    String? receiptNumber,
    DateTime? verifiedAt,
    bool? isTest,
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
        if (isTest ?? payment.paymentMethod?.contains('Demo Test') == true)
          pw.Text(PaymentReceipt.testNotice,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
        pw.Text('Receipt: ${receiptNumber ?? reference}'),
        if (receiptNumber != null) pw.Text('Payment reference: $reference'),
        pw.Text('Received: ${receivedOn.toIso8601String().substring(0, 10)}'),
        if (verifiedAt != null)
          pw.Text('Verified: ${verifiedAt.toIso8601String()}'),
        pw.Text('Tenant: ${payment.tenantName ?? payment.tenantId}'),
        pw.Text('Bill: ${payment.label}'),
        pw.Text('Bill ID: ${payment.id}'),
        pw.Text('Method: ${payment.paymentMethod ?? 'Face-to-face receipt'}'),
        pw.Divider(),
        pw.Text('Amount received: PHP ${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(
            '${receiptNumber == null ? 'Current bill balance' : 'Balance after this payment'}: PHP ${payment.outstandingAmount.toStringAsFixed(2)}'),
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
