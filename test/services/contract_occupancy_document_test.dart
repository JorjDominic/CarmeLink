import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/contract_document_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'individual contracts print snapshot room, bed, shares and roommate names',
      () async {
    final snapshot = <String, dynamic>{
      'mode': 'shared',
      'room_id': 'room',
      'room_number': 'Custom-201',
      'capacity': 3,
      'total_rent_cents': 10000,
      'members': [
        {
          'tenant_id': 'a',
          'name': 'Alice',
          'bed_label': 'Bed A',
          'rent_cents': 3334
        },
        {
          'tenant_id': 'b',
          'name': 'Bea',
          'bed_label': 'Bed B',
          'rent_cents': 3333
        },
        {
          'tenant_id': 'c',
          'name': 'Cara',
          'bed_label': 'Bed C',
          'rent_cents': 3333
        }
      ]
    };
    final contract = TenantContract.fromRow({
      'id': 'contract',
      'tenant_id': 'a',
      'profiles': {'full_name': 'Alice'},
      'contract_number': 'CTR-2026-TEST',
      'starts_on': '2026-10-13',
      'ends_on': '2027-10-12',
      'monthly_rent': 33.34,
      'security_deposit': 1500,
      'status': 'draft',
      'created_at': '2026-10-13T00:00:00Z',
      'updated_at': '2026-10-13T00:00:00Z',
      'occupancy_id': 'group',
      'occupancy_snapshot': snapshot
    });
    final rows =
        const ContractDocumentService().occupancyDocumentRows(contract);
    expect(rows['Occupancy arrangement'], 'Shared');
    expect(rows['Total agreed monthly room rental'], 'PHP 100.00');
    expect(rows['Individual monthly rental obligation'], 'PHP 33.34');
    expect(rows['Assigned bed'], 'Bed A');
    expect(rows['Registered roommates'], 'Bea, Cara');
    expect(rows['Contracted occupants'], '3');
    expect(contract.copyWith(status: 'active').occupancySnapshot, snapshot);
    final bytes = await const ContractDocumentService()
        .buildPdfBytes(contract, 1, roomNumber: 'Other room');
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
    final solo = contract.copyWith();
    solo.occupancySnapshot!['mode'] = 'solo';
    solo.occupancySnapshot!['members'] = [(snapshot['members'] as List).first];
    expect(
        const ContractDocumentService()
            .occupancyDocumentRows(solo)
            .containsKey('Registered roommates'),
        isFalse);
  });
}
