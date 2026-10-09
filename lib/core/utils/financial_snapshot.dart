import '../../models/models.dart';

/// Verified cash is counted separately from deposit credits and unpaid bills.
class FinancialSnapshot {
  FinancialSnapshot(Iterable<Payment> payments, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final payment in payments) {
      if (payment.isDeposit) continue;
      final cash = payment.collectedAmount;
      collected += cash;
      if (cash > 0) collectedBillCount++;
      if (payment.isRent) {
        rentCollected += cash;
      } else if (payment.isUtility) {
        utilityCollected += cash;
      }
      if (payment.isVoided) continue;
      if (payment.isPending) {
        pending += payment.submittedAmount ?? payment.outstandingAmount;
        pendingProofCount++;
      }
      final due = DateTime(
          payment.dueDate.year, payment.dueDate.month, payment.dueDate.day);
      if (payment.isRent && due.isAfter(today)) continue;
      eligibleBillCount++;
      if (payment.outstandingAmount <= 0) {
        settledBillCount++;
      } else {
        outstanding += payment.outstandingAmount;
        outstandingBillCount++;
      }
    }
  }
  double collected = 0, pending = 0, outstanding = 0;
  double rentCollected = 0, utilityCollected = 0;
  int collectedBillCount = 0, pendingProofCount = 0, outstandingBillCount = 0;
  int eligibleBillCount = 0, settledBillCount = 0;
  double get compliancePercent =>
      eligibleBillCount == 0 ? 100 : settledBillCount / eligibleBillCount * 100;
}
