import '../core/config/supabase_config.dart';

class ProfileService {
  const ProfileService();

  Future<String> tenantRoomAssignment(String tenantId) async {
    final rows = await SupabaseConfig.client
        .from('tenant_assignments')
        .select('bed_spaces(label, rooms(room_number))')
        .eq('tenant_id', tenantId)
        .eq('status', 'active')
        .limit(1);
    if (rows.isEmpty) return 'No active room assignment';
    final bed = rows.first['bed_spaces'] as Map<String, dynamic>?;
    final room = bed?['rooms'] as Map<String, dynamic>?;
    return 'Room ${room?['room_number'] ?? '—'} • Bed ${bed?['label'] ?? '—'}';
  }

  Future<String> guardianLinkedTenant(String guardianId) async {
    final rows = await SupabaseConfig.client
        .from('guardian_tenant_links')
        .select(
            'tenant_id, relationship, profiles!guardian_tenant_links_tenant_id_fkey(full_name)')
        .eq('guardian_id', guardianId)
        .order('is_primary', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 'No linked tenant';
    final row = rows.first;
    final profile = row['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] as String? ?? 'Linked tenant';
    final room = await tenantRoomAssignment(row['tenant_id'] as String);
    return '$name • $room';
  }
}
