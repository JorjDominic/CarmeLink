import '../core/config/supabase_config.dart';

class SecurityDepositRecord {
  const SecurityDepositRecord({
    required this.contractId,
    required this.contractNumber,
    required this.requiredAmount,
    this.receivedAmount = 0,
    this.receivedOn,
    this.method = '',
    this.reference = '',
    this.refundedAmount = 0,
    this.deductions = 0,
    this.settled = false,
    this.unassignedReceipts = const [],
    this.tenantName = '',
  });

  final String contractId, contractNumber, method, reference;
  final String tenantName;
  final double requiredAmount, receivedAmount, refundedAmount, deductions;
  final DateTime? receivedOn;
  final bool settled;
  final List<Map<String, dynamic>> unassignedReceipts;

  double get heldAmount => settled
      ? (receivedAmount - refundedAmount - deductions)
          .clamp(0, double.infinity)
          .toDouble()
      : receivedAmount;

  String get status => settled
      ? 'Settled'
      : receivedAmount <= 0
          ? requiredAmount <= 0
              ? 'No deposit required'
              : 'Receipt not confirmed'
          : receivedAmount < requiredAmount
              ? 'Partially received'
              : 'Received';
}

class SecurityDepositService {
  const SecurityDepositService();

  /// Contract receipts for the staff overview, including settled history.
  Future<List<SecurityDepositRecord>> listStaffRecords() async {
    final client = SupabaseConfig.client;
    final records = <SecurityDepositRecord>[];
    for (var offset = 0;; offset += 200) {
      final rows = await client
          .from('tenant_contracts')
          .select(
            'id, contract_number, security_deposit, starts_on, '
            'profiles!tenant_contracts_tenant_id_fkey(full_name), security_deposit_receipts(*)',
          )
          .order('starts_on', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      for (final row in rows) {
        final raw = row['security_deposit_receipts'];
        final receipt = raw is Map
            ? raw
            : raw is List && raw.isNotEmpty
                ? raw.first as Map
                : <String, dynamic>{};
        final profile = row['profiles'];
        records.add(SecurityDepositRecord(
          contractId: row['id'] as String,
          contractNumber: row['contract_number'] as String,
          tenantName:
              profile is Map ? profile['full_name'] as String? ?? '' : '',
          requiredAmount: (row['security_deposit'] as num).toDouble(),
          receivedAmount: (receipt['received_amount'] as num?)?.toDouble() ?? 0,
          receivedOn:
              DateTime.tryParse(receipt['received_on']?.toString() ?? ''),
          method: receipt['method']?.toString() ?? '',
          reference: receipt['reference']?.toString() ?? '',
          refundedAmount: (receipt['refunded_amount'] as num?)?.toDouble() ?? 0,
          deductions: (receipt['approved_deductions'] as num?)?.toDouble() ?? 0,
          settled: receipt['settled_at'] != null,
        ));
      }
      if (rows.length < 200) break;
    }
    return records;
  }

  Future<SecurityDepositRecord?> load(
      {String? contractId, String? tenantId}) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null || client.auth.currentUser == null) return null;
    var query = client.from('tenant_contracts').select(
          'id, tenant_id, contract_number, status, security_deposit, security_deposit_receipts(*)',
        );
    query = contractId == null
        ? query.eq('tenant_id', tenantId ?? client.auth.currentUser!.id)
        : query.eq('id', contractId);
    final rows = await query.order('starts_on', ascending: false).limit(50);
    if (rows.isEmpty) return null;
    final contract = rows.firstWhere((row) => row['status'] == 'active',
        orElse: () => rows.first);
    final raw = contract['security_deposit_receipts'];
    final receipt = raw is Map
        ? Map<String, dynamic>.from(raw)
        : raw is List && raw.isNotEmpty
            ? Map<String, dynamic>.from(raw.first as Map)
            : <String, dynamic>{};
    final unassigned = await client.rpc('get_unassigned_security_deposits',
        params: {'p_tenant_id': contract['tenant_id']});
    return SecurityDepositRecord(
      contractId: contract['id'] as String,
      contractNumber: contract['contract_number'] as String,
      requiredAmount: (contract['security_deposit'] as num).toDouble(),
      receivedAmount: (receipt['received_amount'] as num?)?.toDouble() ?? 0,
      receivedOn: DateTime.tryParse(receipt['received_on']?.toString() ?? ''),
      method: receipt['method']?.toString() ?? '',
      reference: receipt['reference']?.toString() ?? '',
      refundedAmount: (receipt['refunded_amount'] as num?)?.toDouble() ?? 0,
      deductions: (receipt['approved_deductions'] as num?)?.toDouble() ?? 0,
      settled: receipt['settled_at'] != null,
      unassignedReceipts: List<Map<String, dynamic>>.from(unassigned as List),
    );
  }

  Future<void> linkLegacy(String chargeId, String contractId) async {
    await SupabaseConfig.client.rpc('link_legacy_security_deposit', params: {
      'p_charge_id': chargeId,
      'p_contract_id': contractId,
    });
  }

  Future<void> record({
    required String contractId,
    required double amount,
    required DateTime receivedOn,
    required String method,
    required String reference,
    required String reason,
  }) async {
    await SupabaseConfig.client.rpc('record_security_deposit_receipt', params: {
      'p_contract_id': contractId,
      'p_amount': amount,
      'p_received_on': receivedOn.toIso8601String().substring(0, 10),
      'p_method': method.trim(),
      'p_reference': reference.trim(),
      'p_reason': reason.trim(),
    });
  }
}
