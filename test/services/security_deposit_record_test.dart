import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/security_deposit_service.dart';

void main() {
  test('contract amount is not evidence of a deposit held', () {
    const record = SecurityDepositRecord(
        contractId: 'c', contractNumber: 'C1', requiredAmount: 5000);
    expect(record.status, 'Receipt not confirmed');
    expect(record.heldAmount, 0);
  });

  test('partial receipt and completed settlement use confirmed amounts', () {
    const partial = SecurityDepositRecord(
        contractId: 'c',
        contractNumber: 'C1',
        requiredAmount: 5000,
        receivedAmount: 2000);
    expect(partial.status, 'Partially received');
    expect(partial.heldAmount, 2000);
    const settled = SecurityDepositRecord(
        contractId: 'c',
        contractNumber: 'C1',
        requiredAmount: 5000,
        receivedAmount: 5000,
        refundedAmount: 4000,
        deductions: 1000,
        settled: true);
    expect(settled.status, 'Settled');
    expect(settled.heldAmount, 0);
  });
}
