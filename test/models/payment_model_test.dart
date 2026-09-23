import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';

void main() {
  group('Payment Model', () {
    final dueDate = DateTime(2026, 9, 20);
    final paidDate = DateTime(2026, 9, 18, 14, 30);
    final reviewedDate = DateTime(2026, 9, 19, 10, 0);

    test('constructor sets all properties correctly', () {
      final payment = Payment(
        id: 'pay-001',
        label: 'September Rent',
        amount: 3500.0,
        dueDate: dueDate,
        status: 'Due',
        reference: 'REF123456',
        tenantId: 'tenant-1',
        tenantName: 'Anna Dela Cruz',
        tenantRoom: 'Room 201',
        category: 'rent',
        paymentMethod: 'GCash',
        receiptPath: 'receipts/pay-001.jpg',
        paidAt: paidDate,
        reviewedBy: 'staff-1',
        reviewedAt: reviewedDate,
        reviewNotes: 'Verified via GCash statement',
      );

      expect(payment.id, 'pay-001');
      expect(payment.label, 'September Rent');
      expect(payment.amount, 3500.0);
      expect(payment.dueDate, dueDate);
      expect(payment.status, 'Due');
      expect(payment.reference, 'REF123456');
      expect(payment.tenantId, 'tenant-1');
      expect(payment.tenantName, 'Anna Dela Cruz');
      expect(payment.tenantRoom, 'Room 201');
      expect(payment.category, 'rent');
      expect(payment.isRent, isTrue);
      expect(payment.isUtility, isFalse);
      expect(payment.paymentMethod, 'GCash');
      expect(payment.receiptPath, 'receipts/pay-001.jpg');
      expect(payment.paidAt, paidDate);
      expect(payment.reviewedBy, 'staff-1');
      expect(payment.reviewedAt, reviewedDate);
      expect(payment.reviewNotes, 'Verified via GCash statement');
      expect(payment.formattedAmount, '₱3500.00');
    });

    test('status getters work across all lifecycle states', () {
      final due = Payment(
        id: 'p-due',
        label: 'Water Bill',
        amount: 250.0,
        dueDate: dueDate,
        status: 'Due',
      );
      expect(due.isDue, isTrue);
      expect(due.isPending, isFalse);
      expect(due.isVerified, isFalse);
      expect(due.isRejected, isFalse);
      expect(due.canSubmitProof, isTrue);

      final pending = due.copyWith(status: 'Pending verification');
      expect(pending.isDue, isFalse);
      expect(pending.isPending, isTrue);
      expect(pending.isVerified, isFalse);
      expect(pending.isRejected, isFalse);
      expect(pending.canSubmitProof, isFalse);

      final verified = due.copyWith(status: 'Verified');
      expect(verified.isDue, isFalse);
      expect(verified.isPending, isFalse);
      expect(verified.isVerified, isTrue);
      expect(verified.isRejected, isFalse);
      expect(verified.canSubmitProof, isFalse);

      final rejected = due.copyWith(status: 'Rejected');
      expect(rejected.isDue, isFalse);
      expect(rejected.isPending, isFalse);
      expect(rejected.isVerified, isFalse);
      expect(rejected.isRejected, isTrue);
      expect(rejected.canSubmitProof, isTrue);
    });

    test('parses an audited rent override without losing contract rate', () {
      final payment = Payment.fromJson({
        'id': 'rent-adjusted',
        'tenant_id': 'tenant-1',
        'title': 'October 2026 Rent',
        'category': 'rent',
        'amount': 3800,
        'contract_amount': 3500,
        'rent_adjustment': 300,
        'due_date': '2026-10-01',
        'status': 'upcoming',
      });

      expect(payment.isRent, isTrue);
      expect(payment.hasRentOverride, isTrue);
      expect(payment.contractAmount, 3500);
      expect(payment.rentAdjustment, 300);
      expect(payment.amount, 3800);
    });

    test('isOverdue correctly evaluates past due dates for unpaid bills', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 3));
      final futureDate = DateTime.now().add(const Duration(days: 3));

      final overdueBill = Payment(
        id: 'p-overdue',
        label: 'Electricity Bill',
        amount: 600.0,
        dueDate: pastDate,
        status: 'Due',
      );
      expect(overdueBill.isOverdue, isTrue);

      final futureBill = Payment(
        id: 'p-future',
        label: 'Electricity Bill',
        amount: 600.0,
        dueDate: futureDate,
        status: 'Due',
      );
      expect(futureBill.isOverdue, isFalse);

      // Even if date is in the past, if verified or pending, it is not overdue
      final paidPastBill = overdueBill.copyWith(status: 'Verified');
      expect(paidPastBill.isOverdue, isFalse);

      final pendingPastBill =
          overdueBill.copyWith(status: 'Pending verification');
      expect(pendingPastBill.isOverdue, isFalse);
    });

    test('fromJson and toJson round-trip preserves fields', () {
      final json = {
        'id': 'pay-db-1',
        'tenant_id': 'tenant-99',
        'title': 'Internet Fee',
        'category': 'internet',
        'amount': 300.0,
        'due_date': '2026-09-25',
        'status': 'pending_verification',
        'payment_method': 'Maya',
        'reference_number': 'MYA987654',
        'receipt_path': 'proofs/pay-db-1.png',
        'paid_at': '2026-09-24T08:00:00.000Z',
        'reviewed_by': 'admin-1',
        'reviewed_at': '2026-09-24T09:00:00.000Z',
        'review_notes': 'Please confirm reference match',
      };

      final payment = Payment.fromJson(
        json,
        tenantName: 'Maria Santos',
        tenantRoom: 'Room 102',
      );

      expect(payment.id, 'pay-db-1');
      expect(payment.tenantId, 'tenant-99');
      expect(payment.label, 'Internet Fee');
      expect(payment.category, 'internet');
      expect(payment.amount, 300.0);
      expect(payment.status, 'Pending verification');
      expect(payment.paymentMethod, 'Maya');
      expect(payment.reference, 'MYA987654');
      expect(payment.receiptPath, 'proofs/pay-db-1.png');
      expect(payment.tenantName, 'Maria Santos');
      expect(payment.tenantRoom, 'Room 102');

      final serialized = payment.toJson();
      expect(serialized['id'], 'pay-db-1');
      expect(serialized['tenant_id'], 'tenant-99');
      expect(serialized['title'], 'Internet Fee');
      expect(serialized['category'], 'internet');
      expect(serialized['amount'], 300.0);
      expect(serialized['status'], 'pending_verification');
      expect(serialized['payment_method'], 'Maya');
      expect(serialized['reference_number'], 'MYA987654');
      expect(serialized['receipt_path'], 'proofs/pay-db-1.png');
    });

    test('copyWith updates specified fields and preserves untouched fields',
        () {
      final original = Payment(
        id: 'p-orig',
        label: 'Aircon Surcharge',
        amount: 500.0,
        dueDate: dueDate,
        status: 'Due',
      );

      final updated = original.copyWith(
        amount: 550.0,
        status: 'Verified',
        reference: 'REF999',
      );

      expect(updated.id, 'p-orig');
      expect(updated.label, 'Aircon Surcharge');
      expect(updated.amount, 550.0);
      expect(updated.dueDate, dueDate);
      expect(updated.status, 'Verified');
      expect(updated.reference, 'REF999');
    });

    test('equality and hashCode are based on id', () {
      final p1 = Payment(
        id: 'same-id',
        label: 'Rent',
        amount: 3000.0,
        dueDate: dueDate,
        status: 'Due',
      );
      final p2 = Payment(
        id: 'same-id',
        label: 'Updated Rent',
        amount: 3200.0,
        dueDate: dueDate,
        status: 'Verified',
      );
      final p3 = Payment(
        id: 'different-id',
        label: 'Rent',
        amount: 3000.0,
        dueDate: dueDate,
        status: 'Due',
      );

      expect(p1 == p2, isTrue);
      expect(p1.hashCode, p2.hashCode);
      expect(p1 == p3, isFalse);
    });
  });

  group('TenantController Payment State', () {
    final controller = TenantController.instance;

    setUp(() {
      controller.clear();
    });

    tearDown(() {
      controller.clear();
    });

    test('initial state when cleared', () {
      expect(controller.paymentsLoading, isFalse);
      expect(controller.paymentsError, isNull);
      expect(controller.paymentsLoadedOnce, isFalse);
      expect(controller.payments, isEmpty);
    });

    test('setPaymentsForTesting updates lists and metrics properly', () {
      final testPayments = [
        Payment(
          id: 't-1',
          label: 'Rent 1',
          amount: 3000.0,
          dueDate: DateTime(2026, 9, 20),
          status: 'Due',
        ),
        Payment(
          id: 't-2',
          label: 'Electric',
          amount: 500.0,
          dueDate: DateTime(2026, 9, 25),
          status: 'Pending verification',
        ),
        Payment(
          id: 't-3',
          label: 'Water',
          amount: 200.0,
          dueDate: DateTime(2026, 9, 10),
          status: 'Verified',
        ),
      ];

      controller.setPaymentsForTesting(testPayments);

      expect(controller.payments.length, 3);
      expect(controller.paymentsLoadedOnce, isTrue);
      expect(controller.duePayments.length, 1);
      expect(controller.pendingPayments.length, 1);
      expect(controller.verifiedPayments.length, 1);

      // Outstanding balance is sum of non-verified payments (3000 + 500 = 3500)
      expect(controller.outstandingBalance, 3500.0);

      // Next due payment should be the due payment
      expect(controller.nextDuePayment?.id, 't-1');
    });

    test(
        'submitPaymentProof does not fabricate success when backend is unavailable',
        () async {
      final initialPayment = Payment(
        id: 't-submit',
        label: 'Rent October',
        amount: 3500.0,
        dueDate: DateTime(2026, 10, 1),
        status: 'Due',
      );

      controller.setPaymentsForTesting([initialPayment]);

      await expectLater(
        controller.submitPaymentProof(
          paymentId: 't-submit',
          amount: 3500.0,
          method: 'GCash',
          reference: 'GCASH-123456',
        ),
        throwsA(anything),
      );

      expect(controller.payments.single.status, 'Due');
      expect(controller.paymentsError, isNotNull);
    });
  });
}
