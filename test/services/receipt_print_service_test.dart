import 'dart:convert';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/receipt_print_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final payment = Payment(
      id: 'bill-1',
      tenantName: 'Maria Santos',
      label: 'October rent',
      amount: 4000,
      remainingBalance: 2500,
      dueDate: DateTime(2026, 10, 1),
      status: 'partially_paid');
  test('creates a printable PDF for a partial payment receipt', () async {
    final bytes = await const ReceiptPrintService().buildPaymentReceipt(payment,
        amount: 1500, reference: 'F2F-TEST', receivedOn: DateTime(2026, 10, 8));
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });
  test('rejects missing references and invalid receipt amounts', () async {
    for (final amount in [0.0, -1.0, double.nan]) {
      await expectLater(
          const ReceiptPrintService().buildPaymentReceipt(payment,
              amount: amount,
              reference: 'F2F-TEST',
              receivedOn: DateTime(2026, 10, 8)),
          throwsArgumentError);
    }
    await expectLater(
        const ReceiptPrintService().buildPaymentReceipt(payment,
            amount: 1, reference: '', receivedOn: DateTime(2026, 10, 8)),
        throwsArgumentError);
  });
}
