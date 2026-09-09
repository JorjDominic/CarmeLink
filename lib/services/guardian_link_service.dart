import '../core/config/supabase_config.dart';

class GuardianLinkService {
  const GuardianLinkService();

  Future<List<Map<String, dynamic>>> listLinks() async {
    final rows = await SupabaseConfig.client.from('guardian_tenant_links').select(
        'id, guardian_id, tenant_id, relationship, is_primary, created_at, '
        'guardian:profiles!guardian_tenant_links_guardian_id_fkey(full_name), '
        'tenant:profiles!guardian_tenant_links_tenant_id_fkey(full_name)');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listProfiles(String role) async {
    final rows = await SupabaseConfig.client
        .from('profiles')
        .select('id, full_name, phone')
        .eq('role', role)
        .order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createLink({
    required String guardianId,
    required String tenantId,
    required String relationship,
    required bool isPrimary,
  }) async {
    if (isPrimary) await _clearPrimary(tenantId);
    await SupabaseConfig.client.from('guardian_tenant_links').insert({
      'guardian_id': guardianId,
      'tenant_id': tenantId,
      'relationship': relationship.trim(),
      'is_primary': isPrimary,
    });
  }

  Future<void> updateLink({
    required String id,
    required String tenantId,
    required String relationship,
    required bool isPrimary,
  }) async {
    if (isPrimary) await _clearPrimary(tenantId, exceptId: id);
    await SupabaseConfig.client.from('guardian_tenant_links').update({
      'relationship': relationship.trim(),
      'is_primary': isPrimary,
    }).eq('id', id);
  }

  Future<void> _clearPrimary(String tenantId, {String? exceptId}) async {
    var query = SupabaseConfig.client
        .from('guardian_tenant_links')
        .update({'is_primary': false}).eq('tenant_id', tenantId);
    if (exceptId != null) query = query.neq('id', exceptId);
    await query;
  }

  Future<void> deleteLink(String id) =>
      SupabaseConfig.client.from('guardian_tenant_links').delete().eq('id', id);
}
