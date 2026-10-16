import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/receipt_print_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/payment_receipt_history.dart';

class Receipts extends ReceiptPrintService {
  bool failLoad = false, failPrint = false;
  Completer<void>? pending;
  final printed = <String>[];
  final loaded = <String>[];
  @override
  Future<List<PaymentReceipt>> listForCharge(String chargeId) async {
    loaded.add(chargeId);
    if (failLoad) throw StateError('Offline');
    return [
      for (final id in ['older', 'newer'])
        PaymentReceipt(
            id: id,
            number: 'PAY-$id',
            tenantId: 'tenant',
            tenantName: 'Original saved tenant name',
            chargeId: chargeId,
            billTitle:
                'Original saved bill title with a long reference that must wrap on narrow screens',
            amount: 200,
            reference: 'ORIGINAL-TRANSACTION-REFERENCE-$id',
            method: 'Cash',
            verifiedAt: DateTime(2026, 10, 16),
            receivedAt: DateTime(2026, 10, 16),
            environment: id == 'older' ? 'manual' : 'test',
            balanceAfter: id == 'older' ? 800 : 600,
            snapshotSource: 'verification')
    ];
  }

  @override
  Future<void> printStoredReceipt(PaymentReceipt receipt,
      {Uint8List? bytes}) async {
    printed.add(receipt.id);
    if (failPrint) throw StateError('Printer unavailable');
    await pending?.future;
  }
}

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets(
        'stored receipt history and print failure remain usable at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = Receipts()..failPrint = true;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: PaymentReceiptHistoryDialog(
                  chargeId: 'bill', service: service))));
      await tester.pumpAndSettle();
      expect(service.loaded, ['bill']);
      expect(find.text('PAY-older'), findsOneWidget);
      expect(find.text('PAY-newer'), findsOneWidget);
      expect(find.text(PaymentReceipt.testNotice), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Print receipt').first);
      await tester.tap(find.text('Print receipt').first);
      await tester.pumpAndSettle();
      expect(service.printed, ['older']);
      expect(find.textContaining('Payment remains verified.'), findsOneWidget);
      expect(find.text('PAY-older'), findsOneWidget);
      service.failPrint = false;
      service.pending = Completer<void>();
      await tester.ensureVisible(find.text('Print receipt').first);
      await tester.tap(find.text('Print receipt').first);
      await tester.pump();
      expect(service.printed, ['older', 'older']);
      expect(find.text('Printing...'), findsOneWidget);
      for (final button
          in tester.widgetList<OutlinedButton>(find.byType(OutlinedButton)))
        expect(button.onPressed, isNull);
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Printing...'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('receipt lookup failure retries without implying payment failure',
      (tester) async {
    final service = Receipts()..failLoad = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PaymentReceiptHistoryDialog(
                chargeId: 'bill', service: service))));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Payment records are unchanged.'), findsOneWidget);
    expect(find.text('PAY-older'), findsNothing);
    service.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(service.loaded, ['bill', 'bill']);
    expect(find.text('PAY-older'), findsOneWidget);
  });
}
