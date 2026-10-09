import 'package:carmelitas_dormitory_system/core/utils/financial_snapshot.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Payment bill(String id, String status, double amount,
          {double? balance,
          double? verified,
          double? submitted,
          String category = 'rent',
          bool future = false}) =>
      Payment(
          id: id,
          label: id,
          amount: amount,
          status: status,
          category: category,
          dueDate: future ? DateTime(2026, 11) : DateTime(2026, 9),
          remainingBalance: balance,
          verifiedAmount: verified,
          submittedAmount: submitted);

  test('partial payments count as cash; remaining balances stay due', () {
    final snapshot = FinancialSnapshot([
      bill('partial', 'Partially paid', 3000, balance: 2200, verified: 800),
      bill('paid', 'Verified', 1200, balance: 0, verified: 1200),
    ], asOf: DateTime(2026, 10, 9));
    expect(snapshot.collected, 2000);
    expect(snapshot.outstanding, 2200);
    expect(snapshot.collectedBillCount, 2);
    expect(snapshot.settledBillCount, 1);
  });
  test('future rent, voided bills and separate deposits do not inflate dues',
      () {
    final snapshot = FinancialSnapshot([
      bill('future', 'Upcoming', 5000,
          balance: 5000, verified: 0, future: true),
      bill('voided', 'Voided', 900, balance: 0, verified: 0),
      bill('deposit', 'Due', 3000, category: 'deposit'),
      bill('rejected', 'Rejected', 400, balance: 400, verified: 0),
    ], asOf: DateTime(2026, 10, 9));
    expect(snapshot.collected, 0);
    expect(snapshot.outstanding, 400);
    expect(snapshot.eligibleBillCount, 1);
  });
  test('pending verification shows the proof amount and retains unpaid balance',
      () {
    final snapshot = FinancialSnapshot([
      bill('utility', 'Pending verification', 500,
          balance: 500, verified: 0, submitted: 100, category: 'electricity'),
    ], asOf: DateTime(2026, 10, 9));
    expect(snapshot.pending, 100);
    expect(snapshot.outstanding, 500);
    expect(snapshot.collected, 0);
  });
  test('deposit credits and bill credits cannot become cash collections', () {
    final snapshot = FinancialSnapshot([
      bill('damage', 'Verified', 0, balance: 0, verified: 0, category: 'other'),
      bill('credited', 'Verified', 50, balance: 0, verified: 100),
    ], asOf: DateTime(2026, 10, 9));
    expect(snapshot.collected, 100);
    expect(snapshot.outstanding, 0);
  });
  test('verified ledger amount survives JSON and model updates', () {
    final payment = Payment.fromJson({
      'id': 'paid',
      'amount': 50,
      'verified_amount': 100,
      'remaining_balance': 0,
      'status': 'verified',
      'due_date': '2026-10-09'
    });
    expect(payment.collectedAmount, 100);
    expect(payment.copyWith(status: 'Voided').collectedAmount, 100);
    expect(Payment.fromJson(payment.toJson()).verifiedAmount, 100);
  });
}
