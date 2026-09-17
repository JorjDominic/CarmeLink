import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';

void main() {
  setUp(() {
    TenantController.instance.clear();
  });

  tearDown(() {
    TenantController.instance.clear();
  });

  Widget buildTestable(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  final testPayments = [
    Payment(
      id: 'p-1',
      label: 'September Dorm Rent',
      amount: 3500.0,
      dueDate: DateTime.now().subtract(const Duration(days: 2)), // Overdue
      status: 'Due',
      category: 'rent',
    ),
    Payment(
      id: 'p-2',
      label: 'Electricity Fee',
      amount: 450.0,
      dueDate: DateTime.now().add(const Duration(days: 5)),
      status: 'Pending verification',
      category: 'electricity',
      reference: 'GCASH-998877',
      paymentMethod: 'GCash',
    ),
    Payment(
      id: 'p-3',
      label: 'August Water Bill',
      amount: 150.0,
      dueDate: DateTime(2026, 8, 15),
      status: 'Verified',
      category: 'water',
      receiptPath: 'receipts/water-aug.png',
    ),
  ];

  group('PaymentsPage Widget Test', () {
    testWidgets('renders account summary, filters, and payment cards',
        (tester) async {
      TenantController.instance.setPaymentsForTesting(testPayments);

      await tester.pumpWidget(buildTestable(const PaymentsPage()));
      await tester.pump();

      // Account summary headers
      expect(find.text('ACCOUNT SUMMARY'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('Next due date'), findsOneWidget);

      // Overdue indicator in summary
      expect(find.text('1 overdue bill'), findsOneWidget);

      // Filter chips with dynamic counts
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Due (1)'), findsOneWidget);
      expect(find.text('Pending (1)'), findsOneWidget);
      expect(find.text('Verified (1)'), findsOneWidget);

      // Payment titles
      expect(find.text('September Dorm Rent'), findsOneWidget);
      expect(find.text('Electricity Fee'), findsOneWidget);
      expect(find.text('August Water Bill'), findsOneWidget);

      // Overdue badge on September rent
      expect(find.textContaining('Overdue • Due'), findsOneWidget);
    });

    testWidgets('filter chips filter displayed payment cards accurately',
        (tester) async {
      TenantController.instance.setPaymentsForTesting(testPayments);

      await tester.pumpWidget(buildTestable(const PaymentsPage()));
      await tester.pump();

      // Initially all 3 are displayed
      expect(find.text('September Dorm Rent'), findsOneWidget);
      expect(find.text('Electricity Fee'), findsOneWidget);
      expect(find.text('August Water Bill'), findsOneWidget);

      // Tap 'Due' chip
      await tester.tap(find.text('Due (1)'));
      await tester.pumpAndSettle();

      expect(find.text('September Dorm Rent'), findsOneWidget);
      expect(find.text('Electricity Fee'), findsNothing);
      expect(find.text('August Water Bill'), findsNothing);

      // Tap 'Pending' chip
      await tester.tap(find.text('Pending (1)'));
      await tester.pumpAndSettle();

      expect(find.text('September Dorm Rent'), findsNothing);
      expect(find.text('Electricity Fee'), findsOneWidget);
      expect(find.text('August Water Bill'), findsNothing);

      // Tap 'Verified' chip
      await tester.tap(find.text('Verified (1)'));
      await tester.pumpAndSettle();

      expect(find.text('September Dorm Rent'), findsNothing);
      expect(find.text('Electricity Fee'), findsNothing);
      expect(find.text('August Water Bill'), findsOneWidget);
    });

    testWidgets('tapping Submit proof opens UploadPaymentProofPage',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      TenantController.instance.setPaymentsForTesting([testPayments[0]]);

      await tester.pumpWidget(buildTestable(const PaymentsPage()));
      await tester.pump();

      final submitProofBtn = find.text('Submit proof');
      expect(submitProofBtn, findsOneWidget);

      await tester.ensureVisible(submitProofBtn);
      await tester.pumpAndSettle();

      await tester.tap(submitProofBtn);
      await tester.pumpAndSettle();

      expect(find.text('Upload payment proof'), findsOneWidget);
      expect(find.text('Submit transaction receipt for verification'),
          findsOneWidget);
      expect(find.text('September Dorm Rent'), findsOneWidget);
    });

    testWidgets('tapping View receipt opens receipt dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      TenantController.instance.setPaymentsForTesting([testPayments[2]]);

      await tester.pumpWidget(buildTestable(const PaymentsPage()));
      await tester.pump();

      final viewReceiptBtn = find.text('View receipt');
      expect(viewReceiptBtn, findsOneWidget);

      await tester.ensureVisible(viewReceiptBtn);
      await tester.pumpAndSettle();

      await tester.tap(viewReceiptBtn);
      await tester.pumpAndSettle();

      expect(find.text('August Water Bill Receipt'), findsOneWidget);
    });
  });

  group('UploadPaymentProofPage Widget Test', () {
    testWidgets('renders preselected bill and dynamic payment instruction card',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(UploadPaymentProofPage(targetPayment: testPayments[0])),
      );
      await tester.pump();

      // Header card with bill info
      expect(find.text('September Dorm Rent'), findsOneWidget);
      expect(find.text('Payment method'), findsOneWidget);

      // Default method is GCash, instruction card should render GCash details
      expect(find.text('GCash Account'), findsOneWidget);
      expect(find.text('0917-123-4567 (Carmelita D.)'), findsOneWidget);

      // Amount field prefilled with 3500.00
      expect(find.text('3500.00'), findsOneWidget);
    });

    testWidgets('switching payment method updates instruction card',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(UploadPaymentProofPage(targetPayment: testPayments[0])),
      );
      await tester.pump();

      expect(find.text('GCash Account'), findsOneWidget);

      // Open dropdown and select Bank transfer
      await tester.tap(find.text('GCash'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bank transfer').last);
      await tester.pumpAndSettle();

      expect(find.text('BDO Bank Deposit / Transfer'), findsOneWidget);
      expect(find.text('0012-3456-7890 (Carmelita Dormitory Management)'),
          findsOneWidget);
    });
  });
}
