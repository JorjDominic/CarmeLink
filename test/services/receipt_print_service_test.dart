import 'dart:io';
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
  test(
      'stored manual and test receipts render with saved verification metadata',
      () async {
    final directory = Directory('build/phase1_payment_validation')
      ..createSync(recursive: true);
    for (final environment in ['test', 'manual']) {
      final receipt = PaymentReceipt(
          id: 'transaction-1',
          number: 'PAY-TRANSACTION-1',
          tenantId: 'sample-tenant',
          tenantName: 'Sample Tenant',
          chargeId: 'sample-bill',
          billTitle: 'Sample October rent',
          amount: 750,
          reference: 'pay_FIXTURE',
          method: environment == 'test' ? 'PayMongo QR Ph (Demo Test)' : 'Cash',
          verifiedAt: DateTime(2026, 10, 16, 10),
          receivedAt: DateTime(2026, 10, 16, 9),
          environment: environment,
          balanceAfter: 0);
      final bytes =
          await const ReceiptPrintService().buildStoredReceipt(receipt);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      File('${directory.path}/${environment}_receipt.pdf')
          .writeAsBytesSync(bytes);
    }
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
