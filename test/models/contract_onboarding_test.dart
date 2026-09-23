import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('required contract document is satisfied only after verification', () {
    final item = ContractRequirement.fromRow({
      'id': 'requirement-1',
      'contract_id': 'contract-1',
      'requirement_type': 'signed_photocopies',
      'is_required': true,
      'status': 'verified',
      'physical_copy_received': true,
      'signature_count': 3,
      'storage_path': 'contract-1/requirements/copy.pdf',
      'original_filename': 'copy.pdf',
      'submitted_at': '2026-09-24T01:00:00Z',
      'reviewed_at': '2026-09-24T02:00:00Z',
      'review_notes': 'Physical copy and three signatures confirmed',
    });

    expect(item.label, 'Three-signature photocopies');
    expect(item.isVerified, isTrue);
    expect(item.isSatisfied, isTrue);
    expect(item.signatureCount, 3);
  });

  test('optional guardian requirement does not block completion', () {
    final item = ContractRequirement.fromRow({
      'id': 'requirement-2',
      'contract_id': 'contract-1',
      'requirement_type': 'guardian_identity',
      'is_required': false,
      'status': 'waived',
      'physical_copy_received': false,
      'signature_count': 0,
    });

    expect(item.label, 'Parent/guardian valid ID');
    expect(item.isSatisfied, isTrue);
  });

  test('required signer remains incomplete until independently verified', () {
    final pending = ContractSigner.fromRow({
      'id': 'signer-1',
      'contract_id': 'contract-1',
      'signer_role': 'tenant',
      'is_required': true,
      'status': 'signed',
      'signer_name': 'Sample Tenant',
      'signature_method': 'physical_upload',
      'signed_at': '2026-09-24T01:00:00Z',
    });

    expect(pending.label, 'Lessee / tenant');
    expect(pending.isVerified, isFalse);
    expect(pending.isSatisfied, isFalse);
  });

  test('optional witness may be waived', () {
    final witness = ContractSigner.fromRow({
      'id': 'signer-2',
      'contract_id': 'contract-1',
      'signer_role': 'witness',
      'is_required': false,
      'status': 'waived',
    });

    expect(witness.isConfigurable, isTrue);
    expect(witness.isSatisfied, isTrue);
  });
}
