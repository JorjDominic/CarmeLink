import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';

void main() {
  setUp(() {
    OwnerController.instance.clear();
  });

  tearDown(() {
    OwnerController.instance.clear();
  });

  Widget buildTestable(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  List<Payment> createTestPayments() => [
        Payment(
          id: 'pay-1',
          tenantId: 't-1',
          tenantName: 'Juan Dela Cruz',
          tenantRoom: 'Room 101',
          label: 'Monthly Rent - Sept',
          amount: 4000.0,
          dueDate: DateTime.now().subtract(const Duration(days: 3)), // Overdue
          status: 'Due',
          category: 'rent',
        ),
        Payment(
          id: 'pay-2',
          tenantId: 't-2',
          tenantName: 'Maria Santos',
          tenantRoom: 'Room 102',
          label: 'Electricity Share',
          amount: 600.0,
          dueDate: DateTime.now().add(const Duration(days: 5)),
          status: 'Pending verification',
          category: 'electricity',
          reference: 'GCASH-998877',
          paymentMethod: 'GCash',
        ),
        Payment(
          id: 'pay-3',
          tenantId: 't-3',
          tenantName: 'Pedro Penduko',
          tenantRoom: 'Room 201',
          label: 'August Rent',
          amount: 4000.0,
          dueDate: DateTime(2026, 8, 5),
          status: 'Verified',
          category: 'rent',
          reference: 'BDO-554433',
        ),
        Payment(
          id: 'pay-4',
          tenantId: 't-4',
          tenantName: 'Ana Reyes',
          tenantRoom: 'Room 202',
          label: 'Internet Fee',
          amount: 300.0,
          dueDate: DateTime(2026, 8, 10),
          status: 'Rejected',
          category: 'internet',
          reviewNotes: 'Reference number was invalid',
        ),
      ];

  group('PaymentVerificationPage Widget Tests', () {
    testWidgets('renders financial metrics grid and status chips',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setPaymentsForTesting(createTestPayments());

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Page Title
      expect(find.text('Billing and payments'), findsOneWidget);
      expect(find.text('Bills'), findsOneWidget);
      expect(find.text('Payment review'), findsOneWidget);

      // Financial Metrics Cards
      expect(find.text('Pending review'), findsNothing);
      expect(find.text('Collected'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('Overdue'), findsWidgets);

      // Filter Chips
      expect(find.text('Pending (1)'), findsNothing);
      expect(find.text('Due (0)'), findsOneWidget);
      expect(find.text('Overdue (1)'), findsOneWidget);
      expect(find.text('Verified (1)'), findsOneWidget);
      expect(find.text('Rejected (1)'), findsNothing);
      expect(find.text('All (4)'), findsOneWidget);

      // Bills is the default workspace and shows the complete ledger.
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('Electricity Share'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
    });

    testWidgets('filtering by All displays all payments', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setPaymentsForTesting(createTestPayments());

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Tap 'All' chip
      await tester.ensureVisible(find.text('All (4)'));
      await tester.tap(find.text('All (4)'));
      await tester.pumpAndSettle();

      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('Pedro Penduko'), findsOneWidget);
      expect(find.text('Ana Reyes'), findsOneWidget);
    });

    testWidgets('search bar filters payments by tenant name or reference',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setPaymentsForTesting(createTestPayments());

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Switch to All tab
      await tester.ensureVisible(find.text('All (4)'));
      await tester.tap(find.text('All (4)'));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(
        find.byType(TextField).first,
        'Pedro',
      );
      await tester.pumpAndSettle();

      expect(find.text('Pedro Penduko'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsNothing);
      expect(find.text('Maria Santos'), findsNothing);

      // Search by reference number
      await tester.enterText(
        find.byType(TextField).first,
        'GCASH-998877',
      );
      await tester.pumpAndSettle();

      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('Pedro Penduko'), findsNothing);
    });

    testWidgets('failed approval preserves pending payment and reports error',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final payments = createTestPayments();
      OwnerController.instance.setPaymentsForTesting(payments);

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Confirm button on pending card
      final confirmBtn = find.widgetWithText(FilledButton, 'Confirm');
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(payments[1].isPending, isTrue);
      expect(find.textContaining('Failed to update payment:'), findsOneWidget);
    });

    testWidgets('failed rejection preserves pending payment and reports error',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final payments = createTestPayments();
      OwnerController.instance.setPaymentsForTesting(payments);

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Reject button on pending card
      final rejectBtn = find.widgetWithText(OutlinedButton, 'Reject');
      expect(rejectBtn, findsOneWidget);

      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();

      // Rejection bottom sheet should appear
      expect(find.text('Reject Payment Proof'), findsOneWidget);
      expect(find.text('Confirm Rejection'), findsOneWidget);

      await tester.tap(find.text('Confirm Rejection'));
      await tester.pumpAndSettle();

      expect(payments[1].isPending, isTrue);
      expect(find.textContaining('Failed to update payment:'), findsOneWidget);
    });

    testWidgets(
        'unpaid bill does not expose an unsafe one-click mark-paid action',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final payments = createTestPayments();
      OwnerController.instance.setPaymentsForTesting(payments);

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Switch to Overdue tab where pay-1 is displayed
      await tester.ensureVisible(find.text('Overdue (1)'));
      await tester.tap(find.text('Overdue (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Awaiting tenant payment proof'), findsOneWidget);

      final markPaidBtn = find.widgetWithText(OutlinedButton, 'Mark paid');
      expect(markPaidBtn, findsNothing);
      expect(payments[0].isDue, isTrue);
    });

    testWidgets('tapping Issue invoice button opens utility charge dialog',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setPaymentsForTesting(createTestPayments());

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Tap the in-page utility charge action.
      final issueBtn = find.widgetWithText(FilledButton, 'Add utility charge');
      expect(issueBtn, findsOneWidget);

      await tester.tap(issueBtn);
      await tester.pumpAndSettle();

      // Dialog should be open
      expect(find.text('Utility Charge Cart'), findsOneWidget);
      expect(find.text('Charging scope'), findsOneWidget);
      expect(find.text('Utility type'), findsOneWidget);
      expect(find.text('Source bill total'), findsOneWidget);
      expect(find.text('Add to cart'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Charging scope'), findsNothing);
    });

    testWidgets('tapping Collected dashboard item switches to verified filter',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setPaymentsForTesting(createTestPayments());

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Tap 'Collected' metric card
      await tester.tap(find.text('Collected'));
      await tester.pumpAndSettle();

      // Verified payment pay-3 (Pedro Penduko) should be displayed
      expect(find.text('Pedro Penduko'), findsOneWidget);
      expect(find.text('August Rent'), findsOneWidget);
      // Pending payment Maria Santos should not be displayed
      expect(find.text('Maria Santos'), findsNothing);
    });

    testWidgets('rent adjustment is not exposed from the billing workspace',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setPaymentsForTesting(createTestPayments());
      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      expect(find.text('Override future rent'), findsNothing);
      expect(find.text('Adjust future contract rent'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failed backend submission does not fabricate an invoice',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setPaymentsForTesting(createTestPayments());

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Tap the in-page utility charge action.
      await tester.tap(
        find.widgetWithText(FilledButton, 'Add utility charge'),
      );
      await tester.pumpAndSettle();

      // Use the all-rooms scope so this backend-failure test does not depend
      // on a seeded tenant directory.
      await tester.tap(find.text('Individual tenant').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('All occupied rooms').last);
      await tester.pumpAndSettle();

      // Fill in amount
      final amountField =
          find.widgetWithText(TextFormField, 'Source bill total');
      await tester.enterText(amountField, '5000');
      await tester.pump();

      await tester.tap(find.text('Add to cart'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Issue cart'));
      await tester.pumpAndSettle();

      expect(OwnerController.instance.payments.first.amount, equals(4000.0));
      expect(
          find.textContaining('Failed to issue utility cart:'), findsOneWidget);
    });
  });
}
