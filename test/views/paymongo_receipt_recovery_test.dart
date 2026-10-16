import 'dart:typed_data';

import 'package:carmelitas_dormitory_system/services/paymongo_payment_service.dart';
import 'package:carmelitas_dormitory_system/services/receipt_print_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/paymongo_payment_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final receipt = PaymentReceipt(
    id: 'transaction',
    number: 'PAY-TRANSACTION',
    tenantId: 'sample',
    tenantName: 'Sample Tenant',
    chargeId: 'bill',
    billTitle: 'Sample rent',
    amount: 750,
    reference: 'pay_Fixture',
    method: 'PayMongo QR Ph (Demo Test)',
    verifiedAt: DateTime(2026, 10, 16, 10),
    receivedAt: DateTime(2026, 10, 16, 9),
    environment: 'test',
    balanceAfter: 0);

class Gateway extends PaymongoPaymentService {
  int receiptReads = 0, creates = 0;
  bool failRead = false;
  @override
  Future<List<PaymentReceipt>> receipts(String sessionId) async {
    receiptReads++;
    if (failRead) throw StateError('Unavailable');
    return [receipt];
  }

  @override
  Future<PaymongoPaymentSession> create(String id) async {
    creates++;
    throw StateError('No second payment allowed');
  }
}

class Printer extends ReceiptPrintService {
  int builds = 0, prints = 0;
  bool failBuild = false, failPrint = false;
  @override
  Future<Uint8List> buildStoredReceipt(PaymentReceipt value) async {
    builds++;
    expect(value.id, receipt.id);
    if (failBuild) throw StateError('PDF rendering failed');
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> printStoredReceipt(PaymentReceipt value,
      {Uint8List? bytes}) async {
    prints++;
    expect(bytes, [1, 2, 3]);
    if (failPrint) throw StateError('Print dialog unavailable');
  }
}

void main() {
  Future<void> open(
      WidgetTester tester, Gateway gateway, Printer printer) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PaymongoPaymentPage(
      service: gateway,
      receiptPrinter: printer,
      initialSession: const PaymongoPaymentSession(
          id: 'session',
          status: 'succeeded',
          amountCentavos: 75000,
          environment: 'test',
          reference: 'pay_Fixture'),
    ))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'reopening a confirmed payment prepares its existing test receipt',
      (tester) async {
    final gateway = Gateway(), printer = Printer();
    await open(tester, gateway, printer);
    expect(find.text('Test payment confirmed'), findsOneWidget);
    expect(find.textContaining(PaymentReceipt.testNotice), findsOneWidget);
    expect(printer.builds, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await open(tester, gateway, printer);
    expect(gateway.receiptReads, 2);
    expect(find.textContaining('PAY-TRANSACTION'), findsOneWidget);
    expect(gateway.creates, 0);
  });

  for (final failedRendering in [false, true]) {
    testWidgets(
        'receipt ${failedRendering ? 'rendering' : 'lookup'} failure preserves confirmation and can retry',
        (tester) async {
      final gateway = Gateway()..failRead = !failedRendering;
      final printer = Printer()..failBuild = failedRendering;
      await open(tester, gateway, printer);
      expect(find.text('Test payment confirmed'), findsOneWidget);
      expect(find.textContaining('Payment remains confirmed.'), findsOneWidget);
      expect(find.text('Generate payment request'), findsNothing);
      gateway.failRead = false;
      printer.failBuild = false;
      await tester.ensureVisible(find.text('Retry receipt'));
      await tester.tap(find.text('Retry receipt'));
      await tester.pumpAndSettle();
      expect(find.text('Receipt: Sample rent'), findsOneWidget);
      expect(gateway.creates, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'failed printing never reopens payment or rebuilds a cached receipt',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = Gateway(), printer = Printer()..failPrint = true;
    await open(tester, gateway, printer);
    await tester.ensureVisible(find.byTooltip('Print / save receipt'));
    await tester.tap(find.byTooltip('Print / save receipt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Payment remains confirmed.'), findsOneWidget);
    printer.failPrint = false;
    await tester.tap(find.byTooltip('Print / save receipt'));
    await tester.pumpAndSettle();
    expect(printer.prints, 2);
    expect(printer.builds, 1);
    expect(gateway.creates, 0);
    expect(tester.takeException(), isNull);
  });
}
