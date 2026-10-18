import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/issued_receipt_service.dart';
import 'package:carmelitas_dormitory_system/services/receipt_print_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/issued_receipt_register.dart';

class Register extends IssuedReceiptService {
  final rows = <Map<String, dynamic>>[];
  final attempts = <String>[];
  bool loseReply = true;
  @override
  Future<List<Map<String, dynamic>>> list(String transactionId) async =>
      List.of(rows);
  @override
  Future<void> record(
      {required String id,
      required String transactionId,
      required String number,
      required String date,
      String? photo}) async {
    attempts.add(id);
    if (rows.isEmpty)
      rows.add({
        'id': id,
        'receipt_number': number,
        'issued_on': date,
        'created_at': date,
        'status': 'issued',
        'environment': 'test'
      });
    if (loseReply) {
      loseReply = false;
      throw StateError('Lost response');
    }
  }

  @override
  Future<void> voidReceipt(String id, String reason) async {
    rows.single['status'] = 'voided';
    rows.single['void_reason'] = reason;
    rows.single['voided_at'] = '2026-10-18';
  }
}

PaymentReceipt receipt() => PaymentReceipt(
    id: 'txn',
    number: 'PAY-txn',
    tenantId: 'tenant',
    tenantName: 'Tenant',
    chargeId: 'bill',
    billTitle: 'Rent',
    amount: 100,
    reference: 'REF',
    method: 'Cash',
    verifiedAt: DateTime(2026, 1, 1),
    receivedAt: DateTime(2026, 1, 1),
    environment: 'test',
    balanceAfter: 900);

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets(
        'issued receipt retries preserve request and voiding requires reason at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = Register();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: IssuedReceiptRegister(
                      receipt: receipt(),
                      service: service,
                      canManage: true)))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record issued receipt'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Save receipt'))
              .onPressed,
          isNull);
      await tester.enterText(find.byType(TextField), 'OR-123');
      await tester.pump();
      await tester.tap(find.text('Save receipt'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(service.attempts.length, 2);
      expect(service.attempts.first, service.attempts.last);
      expect(find.text('OR-123 (TEST) · issued'), findsOneWidget);
      await tester.tap(find.text('Void receipt'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Void receipt'))
              .onPressed,
          isNull);
      await tester.enterText(find.byType(TextField), 'Incorrect number');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Void receipt'));
      await tester.pumpAndSettle();
      expect(find.text('OR-123 (TEST) · voided'), findsOneWidget);
      expect(find.text('Record issued receipt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('participant sees history without staff actions', (tester) async {
    final service = Register();
    service.rows.add({
      'id': 'r',
      'receipt_number': 'OR-321',
      'environment': 'live',
      'status': 'issued',
      'issued_on': '2026-10-18',
      'created_at': '2026-10-18'
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: IssuedReceiptRegister(
                receipt: receipt(), service: service, canManage: false))));
    await tester.pumpAndSettle();
    expect(find.text('OR-321 · issued'), findsOneWidget);
    expect(find.text('Void receipt'), findsNothing);
    expect(find.text('Record issued receipt'), findsNothing);
  });
}
