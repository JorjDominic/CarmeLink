import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/core/utils/financial_snapshot.dart';
import 'package:carmelitas_dormitory_system/services/dormitory_report_service.dart';

void main() {
  tearDown(OwnerController.instance.clear);
  List<Payment> ledger() => [
        Payment(
            id: 'future',
            tenantName: 'YEAR2027',
            label: 'Future rent',
            amount: 3000,
            remainingBalance: 3000,
            dueDate: DateTime(2027, 10, 12),
            status: 'Upcoming'),
        Payment(
            id: 'november',
            tenantName: 'NOV2026',
            label: 'Other repair',
            category: 'other',
            specificCategory: 'Aircon repair',
            amount: 100,
            remainingBalance: 100,
            dueDate: DateTime(2026, 11, 12),
            status: 'Upcoming'),
        Payment(
            id: 'partial',
            tenantName: 'OCT2026',
            label: 'Partial rent',
            amount: 3000,
            remainingBalance: 2500,
            verifiedAmount: 500,
            dueDate: DateTime(2026, 10, 12),
            status: 'Partially paid'),
        Payment.fromJson({
          'id': 'missing',
          'tenant_name': 'UNDATED',
          'title': 'Unknown date',
          'category': 'other',
          'amount': 0,
          'remaining_balance': 0,
          'verified_amount': 0,
          'due_date': null,
          'status': 'verified'
        }),
      ];
  test(
      'financial due dates cross years chronologically and undated rows stay last without mutating the ledger',
      () {
    final values = ledger();
    final original = values.map((p) => p.id).toList();
    final ordered = financialPaymentsByDueDate(values);
    expect(
        ordered.map((p) => p.id), ['partial', 'november', 'future', 'missing']);
    expect(values.map((p) => p.id), original);
    expect(ordered.last.hasDueDate, isFalse);
    expect(ordered.last.copyWith(status: 'Due').hasDueDate, isFalse);
    expect(ordered.last.toJson()['due_date'], isNull);
    final before = FinancialSnapshot(values, asOf: DateTime(2026, 10, 13));
    final after = FinancialSnapshot(ordered, asOf: DateTime(2026, 10, 13));
    expect(after.collected, before.collected);
    expect(after.outstanding, before.outstanding);
    expect(after.collected, 500);
    expect(after.outstanding, 2600);
  });
  test(
      'latest rejected proof does not erase partial cash or become verified evidence',
      () {
    final payment = ledger()[2].copyWith(
        latestTransactionId: 'proof',
        latestTransactionStatus: 'rejected',
        submittedAmount: 200,
        reviewNotes: 'Rejected evidence');
    expect(payment.isProofRejected, isTrue);
    expect(payment.isProofVerified, isFalse);
    expect(payment.collectedAmount, 500);
    expect(payment.outstandingAmount, 2500);
    expect(payment.verificationStatus, 'Rejected');
    expect(payment.toJson()['latest_transaction_status'], 'rejected');
    expect(ledger()[1].copyWith().categoryLabel, 'Aircon repair');
  });
  test('actual financial and executive PDFs preserve figures and source ledger',
      () async {
    OwnerController.instance.setPaymentsForTesting(ledger());
    final original =
        OwnerController.instance.payments.map((p) => p.id).toList();
    const service = DormitoryReportService();
    final bytes = await service.generateFinancialReportPdf();
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    await Directory('build/phase4_reports').create(recursive: true);
    await File('build/phase4_reports/financial.pdf').writeAsBytes(bytes);
    await File('build/phase4_reports/executive.pdf')
        .writeAsBytes(await service.generateExecutiveOverviewPdf());
    expect(OwnerController.instance.payments.map((p) => p.id), original);
  });
}
