import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

class ContractOnboardingService {
  const ContractOnboardingService();

  static const _bucket = 'contract-documents';
  SupabaseClient get _client => SupabaseConfig.client;

  /// Returns the signed-in tenant's newest Draft or Active contract.
  Future<TenantContract?> getMyContract() async {
    final row = await _client.rpc('get_my_contract');
    if (row == null) return null;
    final data = Map<String, dynamic>.from(row as Map);
    return data.isEmpty ? null : TenantContract.fromRow(data);
  }

  Future<List<ContractRequirement>> listRequirements(String contractId) async {
    final rows = await _client
        .from('contract_requirements')
        .select()
        .eq('contract_id', contractId)
        .order('requirement_type');
    return rows.map(ContractRequirement.fromRow).toList();
  }

  Future<List<ContractSigner>> listSigners(String contractId) async {
    final rows = await _client
        .from('contract_signers')
        .select()
        .eq('contract_id', contractId)
        .order('signer_role');
    return rows.map(ContractSigner.fromRow).toList();
  }

  Future<Uint8List> downloadRequirement(String storagePath) =>
      _client.storage.from(_bucket).download(storagePath);

  Future<ContractRequirement> submitRequirement({
    required ContractRequirement requirement,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
    bool physicalCopyReceived = false,
    int signatureCount = 0,
  }) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw Exception('Document must be 10 MB or smaller.');
    }
    const allowed = {'application/pdf', 'image/jpeg', 'image/png'};
    if (!allowed.contains(mimeType)) {
      throw Exception('Upload a PDF, JPG, or PNG document.');
    }
    final extension = switch (mimeType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      _ => 'jpg',
    };
    final path = '${requirement.contractId}/requirements/${requirement.type}-'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.$extension';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    try {
      final row = await _client.rpc('submit_contract_requirement', params: {
        'p_requirement_id': requirement.id,
        'p_storage_path': path,
        'p_original_filename': filename,
        'p_mime_type': mimeType,
        'p_size_bytes': bytes.length,
        'p_sha256': sha256.convert(bytes).toString(),
        'p_physical_copy_received': physicalCopyReceived,
        'p_signature_count': signatureCount,
      });
      return ContractRequirement.fromRow(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      await _client.storage.from(_bucket).remove([path]);
      rethrow;
    }
  }

  Future<ContractRequirement> reviewRequirement({
    required String requirementId,
    required bool approve,
    required String notes,
  }) async {
    final row = await _client.rpc('review_contract_requirement', params: {
      'p_requirement_id': requirementId,
      'p_approve': approve,
      'p_notes': notes.trim(),
    });
    return ContractRequirement.fromRow(Map<String, dynamic>.from(row as Map));
  }

  Future<ContractRequirement> setGuardianRequired({
    required String requirementId,
    required bool required,
  }) async {
    final row = await _client.rpc('set_contract_requirement_required', params: {
      'p_requirement_id': requirementId,
      'p_required': required,
    });
    return ContractRequirement.fromRow(Map<String, dynamic>.from(row as Map));
  }

  Future<ContractSigner> updateSigner({
    required ContractSigner signer,
    required String status,
    String? signerName,
    String? notes,
    bool? required,
  }) async {
    final row = await _client.rpc('update_contract_signer', params: {
      'p_signer_id': signer.id,
      'p_status': status,
      'p_signer_name': signerName,
      'p_signature_method': 'physical_upload',
      'p_notes': notes,
      'p_required': required,
    });
    return ContractSigner.fromRow(Map<String, dynamic>.from(row as Map));
  }

  /// Uploads the authenticated tenant's drawn signature and records an
  /// immutable evidence reference for owner verification.
  Future<ContractSigner> submitElectronicSignature({
    required String contractId,
    required Uint8List signatureBytes,
  }) async {
    if (signatureBytes.isEmpty || signatureBytes.length > 2 * 1024 * 1024) {
      throw Exception('Signature image must be 2 MB or smaller.');
    }
    final path = '$contractId/signatures/tenant-'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.png';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          signatureBytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: false,
          ),
        );
    try {
      final row = await _client.rpc(
        'submit_tenant_electronic_signature',
        params: {
          'p_contract_id': contractId,
          'p_storage_path': path,
          'p_size_bytes': signatureBytes.length,
          'p_sha256': sha256.convert(signatureBytes).toString(),
        },
      );
      return ContractSigner.fromRow(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      await _client.storage.from(_bucket).remove([path]);
      rethrow;
    }
  }
}
