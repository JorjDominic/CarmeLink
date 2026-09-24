import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/contract_document_service.dart';

void main() {
  test('official lease content generates a paginated PDF', () async {
    final now = DateTime(2026, 9, 24);
    final contract = TenantContract(
      id: 'contract-id',
      tenantId: 'tenant-id',
      tenantName: 'Test Tenant',
      contractNumber: 'CL-2026-001',
      startsOn: DateTime(2026, 10, 1),
      endsOn: DateTime(2027, 9, 30),
      monthlyRent: 2500,
      securityDeposit: 2500,
      status: 'draft',
      notes: 'Guardian documents may be completed after initial registration.',
      createdAt: now,
      updatedAt: now,
    );

    final bytes = await const ContractDocumentService().buildPdfBytes(
      contract,
      1,
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
