import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/views/shared/notification_destination.dart';
import 'package:carmelitas_dormitory_system/views/shared/payment_receipt_history.dart';

void main() {
  final controller = OwnerController.instance;
  setUp(controller.clear);
  tearDown(controller.clear);
  List<Payment> ledger() => [
        Payment(
            id: 'due',
            tenantId: 'tenant-0',
            tenantName: 'Unpaid Tenant',
            label: 'Unsubmitted rent',
            amount: 6000,
            dueDate: DateTime(2026, 10, 12),
            status: 'Due'),
        Payment(
            id: 'pending',
            tenantId: 'tenant-1',
            tenantName: 'Pending Tenant',
            tenantRoom: 'Room 101',
            label: 'Partial rent proof',
            amount: 3000,
            submittedAmount: 500,
            remainingBalance: 2500,
            verifiedAmount: 500,
            dueDate: DateTime(2026, 10, 12),
            paidAt: DateTime(2026, 10, 13),
            status: 'Pending verification',
            latestTransactionId: 'transaction-pending',
            latestTransactionStatus: 'pending_verification',
            paymentMethod: 'GCash',
            reference: 'REF-PENDING'),
        Payment(
            id: 'verified',
            tenantName: 'Verified Tenant',
            label: 'Reviewed payment',
            amount: 3000,
            submittedAmount: 500,
            remainingBalance: 2500,
            verifiedAmount: 500,
            dueDate: DateTime(2026, 10, 12),
            paidAt: DateTime(2026, 10, 13),
            reviewedAt: DateTime(2026, 10, 13),
            status: 'Partially paid',
            latestTransactionStatus: 'verified',
            reference: 'REF-VERIFIED'),
        Payment(
            id: 'rejected',
            tenantName: 'Rejected Tenant',
            label: 'Rejected partial proof',
            amount: 3000,
            submittedAmount: 200,
            remainingBalance: 2500,
            verifiedAmount: 500,
            dueDate: DateTime(2026, 10, 12),
            paidAt: DateTime(2026, 10, 13),
            status: 'Partially paid',
            latestTransactionStatus: 'rejected',
            reference: 'REF-REJECTED',
            reviewNotes: 'Blurry receipt'),
        Payment(
            id: 'deposit',
            tenantName: 'Deposit Tenant',
            label: 'Deposit ledger',
            amount: 1500,
            category: 'deposit',
            dueDate: DateTime(2026, 10, 12),
            status: 'Verified',
            reference: 'DEPOSIT-REFERENCE'),
      ];
  Future<void> open(WidgetTester tester) async {
    controller.setPaymentsForTesting(ledger());
    controller.setTenantsForTesting(const [
      TenantDirectoryEntry(
          id: 'tenant-1',
          name: 'Pending Tenant',
          room: 'QA-Room-101',
          bedSpace: 'Bed A',
          phone: '',
          guardianName: '',
          guardianPhone: '')
    ]);
    await tester.pumpWidget(const MaterialApp(home: PaymentVerificationPage()));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(320, 900), const Size(1280, 1100)]) {
    testWidgets(
        'verification is primary and billing controls stay out at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester);
      expect(find.text('Payment Verification'), findsOneWidget);
      expect(find.text('Pending Tenant'), findsOneWidget);
      expect(find.text('QA-Room-101'), findsOneWidget);
      expect(find.text('Pending (1)'), findsOneWidget);
      expect(find.text('Verified (1)'), findsOneWidget);
      expect(find.text('Rejected (1)'), findsOneWidget);
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Unsubmitted rent'), findsNothing);
      for (final label in [
        'Bills',
        'Payment review',
        'Add other charge',
        'Add utility charge',
        'Manage bill',
        'Collected',
        'Outstanding'
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.byTooltip('Record payment received'), findsNothing);
      expect(find.byTooltip('Send payment due alerts to staff'), findsNothing);
      expect(find.text('GCash'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('REF-PENDING'), findsOneWidget);
      expect(find.text('Bill total'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'verified and rejected proofs remain visible after partial payment',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Verified (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Reviewed payment'), findsOneWidget);
    expect(find.text('View receipts'), findsOneWidget);
    await tester.ensureVisible(find.text('View receipts'));
    await tester.tap(find.text('View receipts'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<PaymentReceiptHistoryDialog>(
                find.byType(PaymentReceiptHistoryDialog))
            .chargeId,
        'verified');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Rejected (1)'));
    await tester.tap(find.text('Rejected (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Rejected partial proof'), findsOneWidget);
    expect(find.text('Rejection reason: Blurry receipt'), findsOneWidget);
    expect(find.text('View receipts'), findsOneWidget);
    expect(find.text('Confirm payment'), findsNothing);
  });
  testWidgets(
      'All and reference/room search show submissions without including unpaid invoices or deposits',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Partial rent proof'), findsOneWidget);
    expect(find.text('Reviewed payment'), findsOneWidget);
    expect(find.text('Rejected partial proof'), findsOneWidget);
    expect(find.text('Deposit ledger'), findsNothing);
    final search = find.byKey(const Key('payment-review-search'));
    await tester.enterText(search, 'REF-REJECTED');
    await tester.pumpAndSettle();
    expect(find.text('Rejected partial proof'), findsOneWidget);
    expect(find.text('Partial rent proof'), findsNothing);
    await tester.enterText(search, 'QA-Room-101');
    await tester.pumpAndSettle();
    expect(find.text('Partial rent proof'), findsOneWidget);
    expect(find.text('Rejected partial proof'), findsNothing);
  });
  testWidgets(
      'failed rejection preserves the pending record and requires a reason',
      (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text('Reject'));
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other reason (details below)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Rejection'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Rejection'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last,
        'Proof is incomplete and cannot be confirmed');
    await tester.tap(find.text('Confirm Rejection'));
    await tester.pumpAndSettle();
    expect(
        controller.payments
            .singleWhere((p) => p.id == 'pending')
            .isProofPending,
        isTrue);
    expect(find.textContaining('Failed to update payment:'), findsOneWidget);
  });
  testWidgets(
      'reviewed proof notifications bypass the Pending filter and keep the target scoped',
      (tester) async {
    controller.setPaymentsForTesting(ledger());
    await tester.pumpWidget(const MaterialApp(
        home: NotificationTarget(
            route: 'payment',
            recordId: 'verified',
            child: PaymentVerificationPage())));
    await tester.pumpAndSettle();
    expect(find.text('Reviewed payment'), findsOneWidget);
    expect(find.text('Partial rent proof'), findsNothing);
  });
  testWidgets(
      'unsubmitted bill notifications retain a route to existing Billing actions',
      (tester) async {
    controller.setPaymentsForTesting(ledger());
    await tester.pumpWidget(const MaterialApp(
        home: NotificationTarget(
            route: 'payment',
            recordId: 'due',
            child: PaymentVerificationPage())));
    await tester.pumpAndSettle();
    expect(find.text('No payment proof for this bill'), findsOneWidget);
    expect(find.text('Open Billing'), findsOneWidget);
    expect(find.text('Confirm payment'), findsNothing);
  });
}
