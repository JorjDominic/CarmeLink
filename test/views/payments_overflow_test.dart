import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';
import 'package:carmelitas_dormitory_system/views/guardian/guardian_pages.dart';

void main() {
  setUp(() {
    OwnerController.instance.clear();
    TenantController.instance.clear();
  });

  tearDown(() {
    OwnerController.instance.clear();
    TenantController.instance.clear();
  });

  Widget buildTestable(Widget child, {double textScale = 1.0}) {
    return MaterialApp(
      builder: (context, widget) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: widget!,
        );
      },
      home: child,
    );
  }

  final samplePayments = [
    Payment(
      id: 'p-1',
      tenantId: 't-1',
      tenantName: 'Juan Dela Cruz Extra Long Name That Might Overflow',
      tenantRoom: 'Room 101 • Bed Space 2 Second Floor',
      label:
          'Monthly Dormitory Rent with Very Long Description - September 2026',
      amount: 14500.0,
      dueDate: DateTime.now().subtract(const Duration(days: 5)),
      status: 'Due',
      category: 'rent',
    ),
    Payment(
      id: 'p-2',
      tenantId: 't-2',
      tenantName: 'Maria Santos',
      tenantRoom: 'Room 102 • Bed 1',
      label: 'Electricity & Aircon Utility Surcharge',
      amount: 1850.50,
      dueDate: DateTime.now().add(const Duration(days: 3)),
      status: 'Pending verification',
      category: 'electricity',
      reference: 'GCASH-1234567890123-VERY-LONG-REFERENCE',
      paymentMethod: 'GCash e-Wallet Mobile Transfer',
      receiptPath: 'receipts/test.jpg',
    ),
    Payment(
      id: 'p-3',
      tenantId: 't-1',
      tenantName: 'Juan Dela Cruz Extra Long Name',
      tenantRoom: 'Room 101 • Bed 2',
      label: 'Water Utility Share for July-August',
      amount: 680.0,
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      status: 'Rejected',
      category: 'water',
      reference: 'REF-9988776655',
      paymentMethod: 'Maya',
      receiptPath: 'receipts/test2.jpg',
      reviewNotes: 'Receipt screenshot is too blurred to read reference code.',
    ),
  ];

  group('Narrow Viewport Overflow Tests (320px width)', () {
    testWidgets('PaymentsPage does not overflow on 320px width screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      TenantController.instance.setPaymentsForTesting(samplePayments);

      await tester.pumpWidget(buildTestable(const PaymentsPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Verify both 'Submit proof' and 'View receipt' are rendered for rejected payment
      expect(find.text('Submit proof'), findsWidgets);
      expect(find.text('View receipt'), findsWidgets);
    });

    testWidgets(
        'UploadPaymentProofPage does not overflow on 320px width screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      TenantController.instance.setPaymentsForTesting(samplePayments);

      await tester.pumpWidget(
        buildTestable(UploadPaymentProofPage(targetPayment: samplePayments[0])),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'PaymentVerificationPage does not overflow on 320px width screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setPaymentsForTesting(samplePayments);

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Utility charge dialog does not overflow on 320px width screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setPaymentsForTesting(samplePayments);

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Tap the in-page utility charge action.
      await tester.tap(
        find.widgetWithText(FilledButton, 'Add utility charge'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Utility Charge Cart'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Reject reason bottom sheet does not overflow even with virtual keyboard up',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      OwnerController.instance.setPaymentsForTesting(samplePayments);

      await tester.pumpWidget(buildTestable(const PaymentVerificationPage()));
      await tester.pumpAndSettle();

      // Tap 'Reject' on the pending payment
      final rejectButton = find.text('Reject').first;
      await tester.ensureVisible(rejectButton);
      await tester.tap(rejectButton);
      await tester.pumpAndSettle();

      expect(find.text('Reject Payment Proof'), findsOneWidget);

      // Simulate soft keyboard opening with 280px insets
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'GuardianPaymentStatusPage does not overflow on 320px width screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestable(const GuardianPaymentStatusPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'High text scaling (1.35x) on 320px width does not overflow PaymentVerificationPage',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setPaymentsForTesting(samplePayments);

      await tester.pumpWidget(
        buildTestable(const PaymentVerificationPage(), textScale: 1.35),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
