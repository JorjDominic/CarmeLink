import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/core/utils/financial_snapshot.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/dormitory_configuration_service.dart';
import 'package:carmelitas_dormitory_system/services/dormitory_report_service.dart';
import 'package:carmelitas_dormitory_system/services/payment_service.dart';
import 'package:carmelitas_dormitory_system/services/receipt_print_service.dart';
import 'package:carmelitas_dormitory_system/views/owner/billing_management_page.dart';

class ChargeSaver extends PaymentService {
  final calls = <Map<String, dynamic>>[];
  bool fail = true;
  @override
  Future<Payment> createAdditionalCharge(
      {required String tenantId,
      required String title,
      required String category,
      required double amount,
      required DateTime dueDate,
      required String reason,
      String? notes,
      String? specificCategory,
      String? requestId}) async {
    calls.add({
      'tenant': tenantId,
      'title': title,
      'category': category,
      'amount': amount,
      'date': dueDate,
      'reason': reason,
      'notes': notes,
      'specific': specificCategory,
      'request': requestId
    });
    if (fail) throw StateError('Interrupted response');
    return Payment(
        id: 'charge',
        label: title,
        amount: amount,
        dueDate: dueDate,
        status: 'due');
  }
}

Future<List<DormitoryOption>> categories(String group) async => [
      DormitoryOption(
          id: 'other',
          groupKey: group,
          code: 'other',
          label: 'Other',
          categoryCode: 'other',
          isActive: true,
          isSystem: false,
          sortOrder: 0)
    ];
void main() {
  tearDown(OwnerController.instance.clear);
  test(
      'test credits never inflate actual collections; mixed manual cash and sandbox bill balance remain separate',
      () {
    final payment = Payment.fromJson({
      'id': 'mixed',
      'title': 'Rent',
      'tenant_id': 'sample',
      'amount': 1000,
      'due_date': '2026-10-16',
      'status': 'verified',
      'verified_amount': 1000,
      'test_verified_amount': 750,
      'remaining_balance': 0,
      'latest_gateway_session_id': 'session'
    });
    expect(payment.collectedAmount, 250);
    expect(payment.outstandingAmount, 0);
    expect(payment.isGatewayPayment, isTrue);
    expect(FinancialSnapshot([payment]).collected, 250);
    final copy = Payment.fromJson(payment.copyWith(tenantRoom: '101').toJson());
    expect(copy.collectedAmount, 250);
    expect(copy.testVerifiedAmount, 750);
    expect(copy.latestGatewaySessionId, 'session');
    final testOnly = payment.copyWith(verifiedAmount: 750);
    expect(FinancialSnapshot([testOnly]).collected, 0);
    expect(FinancialSnapshot([testOnly]).collectedBillCount, 0);
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets(
        'charge save failures freeze the original request and retry safely at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.reset);
      final service = ChargeSaver();
      OwnerController.instance.setTenantsForTesting(const [
        TenantDirectoryEntry(
            id: 'tenant',
            name: 'Tenant',
            room: '101',
            bedSpace: 'A',
            phone: '',
            guardianName: '',
            guardianPhone: '')
      ]);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showDialog<bool>(
                          context: context,
                          builder: (_) => AdditionalChargeDialog(
                              paymentService: service,
                              categoryOptionsLoader: categories)),
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final category =
          find.widgetWithText(DropdownButtonFormField<String>, 'Category');
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      for (final field in {
        'Specify Category': 'Aircon repair',
        'Charge title': 'Repair charge',
        'Amount': '125.50',
        'Reason (Required)': 'Owner approved repair',
        'Notes (optional)': 'Original notes'
      }.entries) {
        final finder = find.widgetWithText(TextFormField, field.key);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, field.value);
      }
      await tester.ensureVisible(find.text('Create charge'));
      await tester.tap(find.text('Create charge'));
      await tester.pumpAndSettle();
      expect(service.calls.length, 1);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(
                  find.widgetWithText(TextFormField, 'Charge title'))
              .enabled,
          isFalse);
      expect(
          service.calls.first['request'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      service.fail = false;
      await tester.tap(find.text('Create charge'));
      await tester.pumpAndSettle();
      expect(service.calls.length, 2);
      expect(service.calls[0], service.calls[1]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  test(
      'stored receipts and mixed test collection reports produce inspectable PDFs',
      () async {
    final dir = Directory('build/financial_receipt_validation')
      ..createSync(recursive: true);
    for (final source in ['verification', 'recovery', 'legacy']) {
      for (final environment in ['manual', 'test', 'live']) {
        final receipt = PaymentReceipt(
            id: 'transaction-fixture',
            number: 'PAY-TRANSACTION-FIXTURE',
            tenantId: 'sample',
            tenantName: 'Original Tenant',
            chargeId: 'bill-fixture',
            billTitle: 'Original October rent',
            amount: 200,
            reference: 'PAYMENT-REF',
            method: environment == 'manual' ? 'Cash' : 'PayMongo QR Ph',
            verifiedAt: DateTime(2026, 10, 16, 10),
            receivedAt: DateTime(2026, 10, 16, 9),
            environment: environment,
            balanceAfter: 800,
            snapshotSource: source);
        final bytes =
            await const ReceiptPrintService().buildStoredReceipt(receipt);
        expect(bytes.take(5).toList(), [37, 80, 68, 70, 45]);
        File('${dir.path}/${environment}_$source.pdf').writeAsBytesSync(bytes);
      }
    }
    OwnerController.instance.setPaymentsForTesting([
      Payment(
          id: 'mixed',
          tenantName: 'Mixed Tenant',
          label: 'October rent',
          amount: 1000,
          dueDate: DateTime(2026, 10, 16),
          status: 'verified',
          verifiedAmount: 1000,
          testVerifiedAmount: 750,
          remainingBalance: 0,
          paymentMethod: 'PayMongo QR Ph (Demo Test)')
    ]);
    File('${dir.path}/financial.pdf').writeAsBytesSync(
        await const DormitoryReportService().generateFinancialReportPdf());
    File('${dir.path}/executive.pdf').writeAsBytesSync(
        await const DormitoryReportService().generateExecutiveOverviewPdf());
  });
}
