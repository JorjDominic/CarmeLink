import '../core/config/supabase_config.dart';
import '../models/models.dart';

class ContractService {
  const ContractService();

  static const _selection =
      'id, tenant_id, contract_number, starts_on, ends_on, monthly_rent, '
      'security_deposit, status, notes, created_at, updated_at, '
      'profiles!tenant_contracts_tenant_id_fkey(full_name)';

  Future<List<TenantContract>> listContracts() async {
    final rows = await SupabaseConfig.client
        .from('tenant_contracts')
        .select(_selection)
        .order('starts_on', ascending: false);
    return rows.map(TenantContract.fromRow).toList();
  }

  Future<TenantContract> createContract({
    required String tenantId,
    required String contractNumber,
    required DateTime startsOn,
    required DateTime endsOn,
    required double monthlyRent,
    required double securityDeposit,
    required String status,
    String? notes,
  }) async {
    final row = await SupabaseConfig.client
        .from('tenant_contracts')
        .insert({
          'tenant_id': tenantId,
          'contract_number': contractNumber.trim(),
          'starts_on': _date(startsOn),
          'ends_on': _date(endsOn),
          'monthly_rent': monthlyRent,
          'security_deposit': securityDeposit,
          'status': status,
          'notes': _nullable(notes),
        })
        .select(_selection)
        .single();
    return TenantContract.fromRow(row);
  }

  Future<TenantContract> updateContract(TenantContract contract) async {
    final row = await SupabaseConfig.client
        .from('tenant_contracts')
        .update({
          'tenant_id': contract.tenantId,
          'contract_number': contract.contractNumber.trim(),
          'starts_on': _date(contract.startsOn),
          'ends_on': _date(contract.endsOn),
          'monthly_rent': contract.monthlyRent,
          'security_deposit': contract.securityDeposit,
          'status': contract.status,
          'notes': _nullable(contract.notes),
        })
        .eq('id', contract.id)
        .select(_selection)
        .single();
    return TenantContract.fromRow(row);
  }

  Future<void> deleteContract(String id) async {
    await SupabaseConfig.client.from('tenant_contracts').delete().eq('id', id);
  }

  String _date(DateTime value) => value.toIso8601String().split('T').first;
  String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
