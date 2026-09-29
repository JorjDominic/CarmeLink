import 'package:carmelitas_dormitory_system/core/utils/billing_management_policy.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Payment payment({
  required String id,
  required String category,
  required String status,
  double amount = 100,
  double? remaining,
  DateTime? dueDate,
  String tenant = 'Anna Resident',
}) {
  return Payment(
    id: id,
    tenantId: 'tenant-$id',
    tenantName: tenant,
    label: '$category charge',
    category: category,
    amount: amount,
    remainingBalance: remaining,
    dueDate: dueDate ?? DateTime.now().subtract(const Duration(days: 1)),
    status: status,
  );
}

void main() {
  test('classifies rent utilities and manually approved other charges', () {
    final rent = payment(id: 'r', category: 'rent', status: 'Due');
    final water = payment(id: 'w', category: 'water', status: 'Due');
    final damage = payment(id: 'd', category: 'damage', status: 'Due');

    expect(BillingManagementPolicy.matchesBucket(rent, BillingBucket.rent),
        isTrue);
    expect(
        BillingManagementPolicy.matchesBucket(water, BillingBucket.utilities),
        isTrue);
    expect(BillingManagementPolicy.matchesBucket(damage, BillingBucket.other),
        isTrue);
  });

  test('deposit records never contribute to tenant-payable summary totals', () {
    final deposit = payment(
      id: 'deposit',
      category: 'deposit',
      status: 'Due',
      amount: 4000,
      remaining: 4000,
    );
    final utility = payment(
      id: 'utility',
      category: 'electricity',
      status: 'Due',
      amount: 650,
      remaining: 650,
    );

    expect(
      BillingManagementPolicy.outstandingNow([deposit, utility]),
      650,
    );
    expect(
      BillingManagementPolicy.utilityOutstanding([deposit, utility]),
      650,
    );
  });

  test('search and status filters keep matching records reachable', () {
    final overdue = payment(
      id: 'a',
      category: 'water',
      status: 'Due',
      tenant: 'Maria Santos',
    );
    final verified = payment(
      id: 'b',
      category: 'water',
      status: 'Verified',
      tenant: 'Lea Cruz',
    );

    final result = BillingManagementPolicy.filter(
      [overdue, verified],
      query: 'maria',
      bucket: BillingBucket.utilities,
      status: BillingStatusFilter.overdue,
    );

    expect(result, [overdue]);
  });
}
