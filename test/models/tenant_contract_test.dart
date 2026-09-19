import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TenantContract parses a joined Supabase row', () {
    final contract = TenantContract.fromRow({
      'id': 'contract-1',
      'tenant_id': 'tenant-1',
      'contract_number': 'CTR-2026-001',
      'starts_on': '2026-09-01',
      'ends_on': '2027-08-31',
      'monthly_rent': 4000,
      'security_deposit': 4000.50,
      'status': 'active',
      'notes': 'Annual agreement',
      'created_at': '2026-09-19T00:00:00Z',
      'updated_at': '2026-09-19T00:00:00Z',
      'profiles': {'full_name': 'Maria Santos'},
    });

    expect(contract.tenantName, 'Maria Santos');
    expect(contract.monthlyRent, 4000);
    expect(contract.securityDeposit, 4000.50);
    expect(contract.isActive, isTrue);
    expect(contract.endsOn, DateTime(2027, 8, 31));
  });

  test('copyWith preserves identity and updates editable contract fields', () {
    final now = DateTime(2026, 9, 19);
    final original = TenantContract(
      id: 'contract-1',
      tenantId: 'tenant-1',
      tenantName: 'Maria Santos',
      contractNumber: 'CTR-001',
      startsOn: now,
      endsOn: DateTime(2027, 9, 18),
      monthlyRent: 4000,
      securityDeposit: 4000,
      status: 'draft',
      createdAt: now,
      updatedAt: now,
    );

    final updated = original.copyWith(status: 'active', monthlyRent: 4500);
    expect(updated.id, original.id);
    expect(updated.status, 'active');
    expect(updated.monthlyRent, 4500);
    expect(updated.contractNumber, 'CTR-001');
  });
}
