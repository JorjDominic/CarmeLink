import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';

void main() {
  setUp(() {
    OwnerController.instance.clear();
  });

  tearDown(() {
    OwnerController.instance.clear();
  });

  final testPayments = [
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
      reference: 'GCASH-123456',
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

  group('OwnerController Payment Logic Tests', () {
    test('setPaymentsForTesting sets items and updates paymentsLoadedOnce', () {
      final controller = OwnerController.instance;
      expect(controller.paymentsLoadedOnce, isFalse);

      controller.setPaymentsForTesting(testPayments);

      expect(controller.paymentsLoadedOnce, isTrue);
      expect(controller.payments.length, equals(4));
    });

    test('calculates revenue and status counts accurately', () {
      final controller = OwnerController.instance;
      controller.setPaymentsForTesting(testPayments);

      // Total collected: pay-3 (4000.0)
      expect(controller.totalCollectedRevenue, equals(4000.0));

      // Total outstanding: Due (4000.0) + Pending (600.0) = 4600.0
      expect(controller.totalOutstandingRevenue, equals(4600.0));

      // Pending proofs: pay-2
      expect(controller.pendingPaymentProofs, equals(1));

      // Overdue payments: pay-1 (Due and dueDate is in the past)
      expect(controller.overduePaymentCount, equals(1));
    });

    test('createInvoice prepends new payment invoice and notifies listeners',
        () async {
      final controller = OwnerController.instance;
      controller.setPaymentsForTesting(testPayments);

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      final newInvoice = await controller.createInvoice(
        tenantId: 't-1',
        title: 'October Dorm Rent',
        category: 'rent',
        amount: 4200.0,
        dueDate: DateTime.now().add(const Duration(days: 14)),
      );

      expect(newInvoice.label, equals('October Dorm Rent'));
      expect(newInvoice.amount, equals(4200.0));
      expect(newInvoice.status.toLowerCase(), equals('due'));
      expect(controller.payments.first.id, equals(newInvoice.id));
      expect(notifyCount, greaterThan(0));
    });

    test('verifyPayment approves and updates payment in place', () async {
      final controller = OwnerController.instance;
      controller.setPaymentsForTesting(testPayments);

      final target = testPayments[1]; // Pending verification
      expect(target.isPending, isTrue);

      await controller.verifyPayment(target, true);

      expect(target.isVerified, isTrue);
      expect(target.status, equals('Verified'));
    });

    test('verifyPayment rejects and updates payment with notes', () async {
      final controller = OwnerController.instance;
      controller.setPaymentsForTesting(testPayments);

      final target = testPayments[1]; // Pending verification
      await controller.verifyPayment(target, false, notes: 'Invalid proof');

      expect(target.isRejected, isTrue);
      expect(target.status, equals('Rejected'));
    });

    test('clear resets payments and paymentsLoadedOnce', () {
      final controller = OwnerController.instance;
      controller.setPaymentsForTesting(testPayments);

      expect(controller.paymentsLoadedOnce, isTrue);
      expect(controller.payments.length, equals(4));

      controller.clear();

      expect(controller.paymentsLoadedOnce, isFalse);
      // When empty, controller.payments falls back to MockData.payments
    });
  });
}

